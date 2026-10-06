import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/pos/domain/pos_order.dart';
import 'audio_alert_service.dart';
import 'printer_settings_service.dart';
import 'print_lock_service.dart';
import 'print_queue_service.dart';

/// حالة أو إشعار الطباعة التلقائية
class AutoPrintEvent {
  final String orderId;
  final String customerName;
  final double totalAmount;
  final bool printSuccess;
  final String message;
  final DateTime timestamp;

  AutoPrintEvent({
    required this.orderId,
    required this.customerName,
    required this.totalAmount,
    required this.printSuccess,
    required this.message,
    required this.timestamp,
  });
}

/// خدمة مراقبة واستماع الطلبات الواردة وطباعتها حرارياً بشكل تلقائي ومباشر
class AutoPrintOrderService {
  static final AutoPrintOrderService instance = AutoPrintOrderService._internal();
  AutoPrintOrderService._internal();

  StreamSubscription<QuerySnapshot>? _ordersSubscription;
  final Set<String> _printedOrderIds = {};
  bool _isInitialLoad = true;
  String _restaurantName = 'مطعم مدار';

  // تيار أحداث الطباعة لإشعار واجهة المستخدم (Banners / Snackbars)
  final _eventController = StreamController<AutoPrintEvent>.broadcast();
  Stream<AutoPrintEvent> get events => _eventController.stream;

  static const _kPrintedOrdersKey = 'madar_printed_order_ids';

  /// بدء الاستماع للطلبات الواردة في خلفية التطبيق
  Future<void> startListening({String restaurantName = 'مطعم مدار'}) async {
    _restaurantName = restaurantName;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      debugPrint('[AutoPrintOrderService] No authenticated user. Cannot listen for orders.');
      return;
    }

    // استرجاع سجل الطلبات المطبوعة سابقاً لتجنب التكرار
    await _loadPrintedOrderIds();

    String? effectiveId;
    try {
      final udoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (udoc.exists && udoc.data() != null) {
        final restId = udoc.data()!['restaurantId'] ?? udoc.data()!['merchantId'] ?? udoc.data()!['storeId'];
        if (restId != null && restId.toString().trim().isNotEmpty) {
          effectiveId = restId.toString().trim();
        }
      }
    } catch (_) {}

    final ids = [uid, if (effectiveId != null && effectiveId.isNotEmpty && effectiveId != uid) effectiveId];

    _ordersSubscription?.cancel();
    _isInitialLoad = true;

    debugPrint('[AutoPrintOrderService] Started listening for pending orders of restaurant: $ids');

    Query<Map<String, dynamic>> ordersQuery = FirebaseFirestore.instance.collection('orders');
    if (ids.length == 1) {
      ordersQuery = ordersQuery.where('restaurantId', isEqualTo: ids.first);
    } else {
      ordersQuery = ordersQuery.where('restaurantId', whereIn: ids);
    }
    ordersQuery = ordersQuery.where('status', isEqualTo: 'pending');

    _ordersSubscription = ordersQuery
        .snapshots()
        .listen(
          (snapshot) => _handleSnapshot(snapshot, uid),
          onError: (error) {
            debugPrint('[AutoPrintOrderService] Snapshot error: $error');
          },
        );
  }

  /// إيقاف الاستماع
  void stopListening() {
    _ordersSubscription?.cancel();
    _ordersSubscription = null;
    debugPrint('[AutoPrintOrderService] Stopped listening.');
  }

  /// معالجة التغييرات والطلبات الواردة
  Future<void> _handleSnapshot(QuerySnapshot snapshot, String uid) async {
    if (_isInitialLoad) {
      // عند فتح التطبيق لأول مرة نسجل الموجود لمنع طباعة الطلبات القديمة دفعة واحدة
      for (final doc in snapshot.docs) {
        _printedOrderIds.add(doc.id);
      }
      _isInitialLoad = false;
      await _savePrintedOrderIds();
      return;
    }

    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final doc = change.doc;
        final orderId = doc.id;

        if (!_printedOrderIds.contains(orderId)) {
          _printedOrderIds.add(orderId);
          await _savePrintedOrderIds();

          final data = doc.data() as Map<String, dynamic>? ?? {};
          await _processIncomingOrder(orderId, data);
        }
      }
    }
  }

  /// معالجة وطباعة الطلب الجديد الوارد
  Future<void> _processIncomingOrder(String orderId, Map<String, dynamic> data) async {
    final settings = PrinterSettingsService.instance;
    await settings.init();

    // 1. تشغيل تنبيه صوتي للطلب الجديد
    if (settings.soundAlert) {
      AudioAlertService.playOrderAlarm(durationSeconds: 20);
    }

    final customerName = (data['customerName'] ?? data['buyerName'] ?? 'زبون مدار').toString();
    final total = (data['total'] ?? data['totalPrice'] ?? 0).toDouble();

    // 2. التحقق من تفعيل الطباعة التلقائية
    if (!settings.autoPrintEnabled) {
      debugPrint('[AutoPrintOrderService] Auto-print is disabled in settings. Skipping print for order #$orderId');
      _eventController.add(AutoPrintEvent(
        orderId: orderId,
        customerName: customerName,
        totalAmount: total,
        printSuccess: false,
        message: 'وصل طلب جديد #$orderId (الطباعة التلقائية معطلة)',
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      // 3. حيازة قفل الطباعة الموزع لمنع Race Condition وتكرار الطباعة بين الكاشيرات
      final claimResult = await PrintLockService.instance.claimOrderPrint(orderId);
      if (!claimResult.isSuccess) {
        debugPrint('[AutoPrintOrderService] Order #$orderId print skipped: ${claimResult.message}');
        return;
      }

      // تحويل بيانات الطلب إلى PosOrder
      final posOrder = PosOrder.fromMap(data, orderId);

      // جلب اسم المطعم الفعلي إذا وُجد
      final restName = data['restaurantName']?.toString().isNotEmpty == true
          ? data['restaurantName'].toString()
          : _restaurantName;

      debugPrint('[AutoPrintOrderService] Auto-printing receipt for incoming order #$orderId via PrintQueueService...');

      // تنفيذ الطباعة عبر طابور الطباعة المتين (Print Queue State Machine)
      final success = await PrintQueueService.instance.enqueueAndPrint(
        order: posOrder,
        restaurantName: restName,
        restaurantPhone: data['restaurantPhone']?.toString() ?? '',
        restaurantAddress: data['restaurantAddress']?.toString() ?? '',
      );

      // تأكيد حالة القفل الموزع على السيرفر
      await PrintLockService.instance.completeOrderPrint(orderId, success: success);

      final printer = await settings.getTargetPrinter();
      final printerName = printer?.name ?? 'الطابعة الافتراضية';

      final message = success
          ? 'تمت طباعة طلب #$orderId تلقائياً على ($printerName) 🖨️'
          : 'فشلت الطباعة التلقائية للطلب #$orderId - تم حفظ الفاتورة في طابور الطباعة';

      _eventController.add(AutoPrintEvent(
        orderId: orderId,
        customerName: customerName,
        totalAmount: total,
        printSuccess: success,
        message: message,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      debugPrint('[AutoPrintOrderService] Error auto-printing order: $e');
      _eventController.add(AutoPrintEvent(
        orderId: orderId,
        customerName: customerName,
        totalAmount: total,
        printSuccess: false,
        message: 'خطأ أثناء محاولة طباعة الطلب #$orderId: $e',
        timestamp: DateTime.now(),
      ));
    }
  }

  /// تحميل معرفات الطلبات المطبوعة
  Future<void> _loadPrintedOrderIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kPrintedOrdersKey) ?? [];
      _printedOrderIds.addAll(list);
    } catch (_) {}
  }

  /// حفظ معرفات الطلبات المطبوعة
  Future<void> _savePrintedOrderIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // نحتفظ بآخر 150 طلب فقط لتوفير الذاكرة
      final list = _printedOrderIds.toList();
      final toSave = list.length > 150 ? list.sublist(list.length - 150) : list;
      await prefs.setStringList(_kPrintedOrdersKey, toSave);
    } catch (_) {}
  }
}
