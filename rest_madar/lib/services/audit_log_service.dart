import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/database/local_database_service.dart';
import 'print_lock_service.dart';

/// أنواع الإجراءات الحساسة الخاضعة للتدقيق التجاري
class AuditLogAction {
  static const orderDeleted = 'order_deleted';
  static const itemRemoved = 'item_removed';
  static const priceOverridden = 'price_overridden';
  static const orderCancelled = 'order_cancelled';
  static const discountApplied = 'discount_applied';
  static const cashDrawerManualOpen = 'cash_drawer_manual_open';
  static const receiptReprinted = 'receipt_reprinted';
  static const printerSettingsChanged = 'printer_settings_changed';
  static const shiftOpened = 'shift_opened';
  static const shiftClosed = 'shift_closed';
  static const inventoryAdjusted = 'inventory_adjusted';
}

/// خدمة سجل التدقيق التجاري الشامل (Commercial Audit Log Service)
/// توثق: من قام بالإجراء، متى، أين، ماذا، القيمة السابقة واللاحقة، والسبب مع كود المدير
/// تدعم الحفظ المحلي الفوري في SQLite والمزامنة التلقائية مع Firestore
class AuditLogService {
  static final AuditLogService instance = AuditLogService._internal();
  AuditLogService._internal();

  static const _kManagerPinKey = 'madar_pos_manager_pin';
  static const _defaultPin = '1234';

  /// التحقق من صحة كود المدير
  Future<bool> verifyManagerPin(String inputPin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString(_kManagerPinKey) ?? _defaultPin;
    return inputPin.trim() == savedPin.trim();
  }

  /// تغيير كود المدير
  Future<void> updateManagerPin(String newPin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kManagerPinKey, newPin.trim());
  }

  /// ترجمة نوع الإجراء الحساس إلى نص عربي واضح ومفهوم
  static String actionToArabic(String action) {
    switch (action) {
      case AuditLogAction.orderDeleted:
        return 'حذف طلب نهائياً';
      case AuditLogAction.itemRemoved:
        return 'حذف صنف من الطلب';
      case AuditLogAction.priceOverridden:
        return 'تعديل السعر يدوياً';
      case AuditLogAction.orderCancelled:
        return 'إلغاء طلب مالي';
      case AuditLogAction.discountApplied:
        return 'تطبيق خصم مالي';
      case AuditLogAction.cashDrawerManualOpen:
        return 'فتح درج النقود يدوياً';
      case AuditLogAction.receiptReprinted:
        return 'إعادة طباعة إيصال';
      case AuditLogAction.printerSettingsChanged:
        return 'تعديل إعدادات الطابعة';
      case AuditLogAction.shiftOpened:
        return 'افتتاح وردية جديدة';
      case AuditLogAction.shiftClosed:
        return 'إغلاق وردية (Z-Report)';
      case AuditLogAction.inventoryAdjusted:
        return 'تعديل كمية المخزون';
      default:
        return action;
    }
  }

  /// تسجيل حركة حساسة في سجل التدقيق التجاري
  Future<void> log({
    required String action,
    required String targetType,
    required String targetId,
    dynamic beforeState,
    dynamic afterState,
    required String reason,
    bool managerPinVerified = false,
    String? customCashierName,
  }) async {
    try {
      final terminalId = await PrintLockService.instance.getTerminalId();
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'local_cashier';
      final userName = customCashierName ?? user?.displayName ?? 'كاشير المحطة';

      final logData = {
        'logId': const Uuid().v4(),
        'terminalId': terminalId,
        'userId': userId,
        'userName': userName,
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'beforeState': beforeState,
        'afterState': afterState,
        'reason': reason,
        'managerPinVerified': managerPinVerified,
        'timestamp': DateTime.now(),
      };

      // 1. الحفظ الفوري المضمون في SQLite المحلي
      await LocalDatabaseService.instance.insertAuditLog(logData);
      debugPrint('[AuditLogService] Action logged: $action for target $targetId by $userName');

      // 2. محاولة المزامنة الفورية مع السحابة في الخلفية
      unawaited(syncPendingLogsToCloud());
    } catch (e) {
      debugPrint('[AuditLogService] Failed to log audit event: $e');
    }
  }

  /// جلب سجلات التدقيق المحلية لعرضها في الشاشة
  Future<List<Map<String, dynamic>>> getLocalLogs({int limit = 100}) async {
    return await LocalDatabaseService.instance.getAllAuditLogs(limit: limit);
  }

  /// جلب سجل التدقيق الفعلي الخاص بطلب محدد (من SQLite المحلي وسحابة Firestore)
  Future<List<Map<String, dynamic>>> getLogsForOrder(String orderId) async {
    try {
      final localLogs = await LocalDatabaseService.instance.getAuditLogsForOrder(orderId);
      if (localLogs.isNotEmpty) return localLogs;

      // محاولة استرجاع السجلات من Firestore إذا لم توجد محلياً
      final rid = FirebaseAuth.instance.currentUser?.uid;
      if (rid != null && rid.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('merchant_audit_logs')
            .doc(rid)
            .collection('logs')
            .where('targetId', isEqualTo: orderId)
            .get();

        if (snap.docs.isNotEmpty) {
          return snap.docs.map((d) {
            final data = d.data();
            return {
              'log_id': data['logId'] ?? d.id,
              'user_name': data['userName'] ?? 'الكاشير',
              'action': data['action'] ?? '',
              'target_id': data['targetId'] ?? orderId,
              'reason': data['reason'] ?? '',
              'timestamp': data['timestamp'] != null
                  ? (data['timestamp'] is Timestamp
                      ? (data['timestamp'] as Timestamp).toDate().toIso8601String()
                      : data['timestamp'].toString())
                  : DateTime.now().toIso8601String(),
            };
          }).toList();
        }
      }
      return localLogs;
    } catch (e) {
      debugPrint('[AuditLogService] Error fetching logs for order $orderId: $e');
      return [];
    }
  }

  /// مزامنة السجلات المعلقة محلياً مع Firestore
  Future<int> syncPendingLogsToCloud({String? restaurantId}) async {
    try {
      final rid = restaurantId ?? FirebaseAuth.instance.currentUser?.uid;
      if (rid == null || rid.isEmpty) return 0;

      final pendingLogs =
          await LocalDatabaseService.instance.getPendingAuditLogs(limit: 50);
      if (pendingLogs.isEmpty) return 0;

      final batch = FirebaseFirestore.instance.batch();
      final List<String> syncedIds = [];

      final colRef = FirebaseFirestore.instance
          .collection('merchant_audit_logs')
          .doc(rid)
          .collection('logs');

      for (final log in pendingLogs) {
        final logId = log['log_id']?.toString() ?? const Uuid().v4();
        final docRef = colRef.doc(logId);

        batch.set(docRef, {
          'logId': logId,
          'terminalId': log['terminal_id'] ?? 'terminal_main',
          'userId': log['user_id'] ?? '',
          'userName': log['user_name'] ?? 'الكاشير',
          'action': log['action'] ?? '',
          'targetType': log['target_type'] ?? '',
          'targetId': log['target_id'] ?? '',
          'beforeState': log['before_state'],
          'afterState': log['after_state'],
          'reason': log['reason'] ?? '',
          'managerPinVerified': log['manager_pin_verified'] == 1,
          'timestamp': log['timestamp'] != null
              ? DateTime.tryParse(log['timestamp'].toString()) ?? DateTime.now()
              : FieldValue.serverTimestamp(),
          'syncedAt': FieldValue.serverTimestamp(),
        });

        syncedIds.add(logId);
      }

      await batch.commit();
      await LocalDatabaseService.instance.markAuditLogsSynced(syncedIds);
      debugPrint('[AuditLogService] Synced ${syncedIds.length} logs to cloud');
      return syncedIds.length;
    } catch (e) {
      debugPrint('[AuditLogService] Cloud sync error: $e');
      return 0;
    }
  }
}
