import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// نتيجة محاولة حيازة قفل الطباعة
enum PrintClaimStatus {
  acquired,        // تم الحجز بنجاح للجهاز الحالي
  alreadyPrinted,  // طُبعت بالفعل سابقاً
  claimedByOther,  // محجوزة حالياً بواسطة كاشير آخر
  error,           // خطأ في الاتصال أو المعاملة
}

class PrintClaimResult {
  final PrintClaimStatus status;
  final String? claimedByTerminal;
  final String? message;

  PrintClaimResult({
    required this.status,
    this.claimedByTerminal,
    this.message,
  });

  bool get isSuccess => status == PrintClaimStatus.acquired;
}

/// خدمة القفل الموزع لمنع Race Condition وطباعة الفواتير مرتين (Distributed Print Lock)
/// تضمن أمان تعدد الكاشيرات وتنافس الأجهزة على نفس الطلب الوارد عبر Firestore Transactions
class PrintLockService {
  static final PrintLockService instance = PrintLockService._internal();
  PrintLockService._internal();

  String? _cachedTerminalId;
  static const _kTerminalIdKey = 'madar_pos_terminal_unique_id';

  /// الحصول على معرف الطرفية الفريد للجهاز الحالي (Terminal ID)
  Future<String> getTerminalId() async {
    if (_cachedTerminalId != null) return _cachedTerminalId!;

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kTerminalIdKey);
    if (id == null || id.isEmpty) {
      id = 'POS-WIN-${const Uuid().v4().substring(0, 8).toUpperCase()}';
      await prefs.setString(_kTerminalIdKey, id);
    }
    _cachedTerminalId = id;
    return id;
  }

  /// محاولة حيازة ملكية طباعة الطلب ذرياً عبر Firestore Transaction
  Future<PrintClaimResult> claimOrderPrint(String orderId) async {
    final terminalId = await getTerminalId();
    final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);

    try {
      return await FirebaseFirestore.instance.runTransaction<PrintClaimResult>(
        (transaction) async {
          final doc = await transaction.get(orderRef);
          if (!doc.exists) {
            return PrintClaimResult(
              status: PrintClaimStatus.error,
              message: 'الطلب غير موجود في السيرفر',
            );
          }

          final data = doc.data() ?? {};
          final bool autoPrinted = data['autoPrinted'] == true;
          final printJob = data['printJob'] as Map<String, dynamic>?;

          // 1. فحص إذا كانت الفاتورة مطبوعة بالفعل
          if (autoPrinted || printJob?['status'] == 'printed') {
            return PrintClaimResult(
              status: PrintClaimStatus.alreadyPrinted,
              message: 'الفاتورة مطبوعة بالفعل',
            );
          }

          // 2. فحص إذا كان هناك كاشير آخر يحجزها حالياً
          if (printJob != null && printJob['claimedBy'] != null) {
            final claimedBy = printJob['claimedBy'].toString();
            final claimedAt = (printJob['claimedAt'] as Timestamp?)?.toDate();

            if (claimedBy != terminalId && claimedAt != null) {
              final secondsSinceClaim = DateTime.now().difference(claimedAt).inSeconds;
              // عقد الحجز صالح لمدة 60 ثانية؛ إذا لم تنتهِ المدة، يُمنع الجهاز الآخر
              if (secondsSinceClaim < 60) {
                return PrintClaimResult(
                  status: PrintClaimStatus.claimedByOther,
                  claimedByTerminal: claimedBy,
                  message: 'الطلب قيد الطباعة حالياً بواسطة كاشير ($claimedBy)',
                );
              }
            }
          }

          // 3. منح الحجز الحصري للجهاز الحالي
          final currentAttempts = (printJob?['attemptCount'] ?? 0) as int;
          transaction.update(orderRef, {
            'printJob': {
              'claimedBy': terminalId,
              'claimedAt': FieldValue.serverTimestamp(),
              'status': 'printing',
              'attemptCount': currentAttempts + 1,
            }
          });

          return PrintClaimResult(
            status: PrintClaimStatus.acquired,
            claimedByTerminal: terminalId,
            message: 'تم حجز الطلب للطباعة بنجاح',
          );
        },
        timeout: const Duration(seconds: 8),
      );
    } catch (e) {
      debugPrint('[PrintLockService] Transaction claim failed for order $orderId: $e');
      return PrintClaimResult(
        status: PrintClaimStatus.error,
        message: 'تعذر التحقق من حجز الطباعة: $e',
      );
    }
  }

  /// تحرير أو تأكيد نجاح الطباعة على السيرفر
  Future<void> completeOrderPrint(String orderId, {required bool success, String? error}) async {
    final terminalId = await getTerminalId();
    final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);

    try {
      if (success) {
        await orderRef.set({
          'autoPrinted': true,
          'printedAt': FieldValue.serverTimestamp(),
          'printJob': {
            'claimedBy': terminalId,
            'status': 'printed',
            'completedAt': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
      } else {
        await orderRef.set({
          'printJob': {
            'status': 'failed',
            'lastError': error ?? 'Failed during thermal print execution',
            'failedAt': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[PrintLockService] Error completing print status for order $orderId: $e');
    }
  }
}
