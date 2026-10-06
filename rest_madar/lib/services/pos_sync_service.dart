import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/database/local_database_service.dart';
import '../features/pos/domain/pos_order.dart';
import 'offline_auth_service.dart';

/// حالة المزامنة اللحظية
enum SyncState { idle, syncing, offline, error }

/// محرك مزامنة الكاشير التلقائي في الخلفية (Background POS Sync Engine)
/// يقوم برفع المعاملات والطلبات المحلية المحفوظة في SQLite فور توفر الإنترنت
class PosSyncService {
  static final PosSyncService instance = PosSyncService._internal();
  PosSyncService._internal();

  Timer? _syncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;

  final _syncStateController = StreamController<SyncState>.broadcast();
  final _pendingCountController = StreamController<int>.broadcast();

  Stream<SyncState> get syncStateStream => _syncStateController.stream;
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  SyncState _currentState = SyncState.idle;
  SyncState get currentState => _currentState;

  /// تشغيل خدمة المزامنة الخلفية الدورية ومراقبة الاتصال
  void start() {
    _syncTimer?.cancel();
    _connectivitySub?.cancel();

    // تشغيل فحص دوري كل 25 ثانية
    _syncTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      triggerSync();
    });

    // استماع لتغيرات شبكة الإنترنت
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected) {
        debugPrint('[PosSyncService] Network connection detected. Triggering sync...');
        triggerSync();
      } else {
        _updateState(SyncState.offline);
      }
    });

    // تشغيل مزامنة أولية
    triggerSync();
  }

  /// إيقاف المزامنة
  void stop() {
    _syncTimer?.cancel();
    _connectivitySub?.cancel();
    _syncTimer = null;
    _connectivitySub = null;
  }

  void _updateState(SyncState state) {
    _currentState = state;
    _syncStateController.add(state);
  }

  /// إطلاق فحص ومزامنة الطلبات المعلقة يدوياً أو آلياً
  Future<void> triggerSync() async {
    if (_isSyncing) return;

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult.any((r) => r != ConnectivityResult.none);
      if (!hasConnection) {
        _updateState(SyncState.offline);
        final pending = await LocalDatabaseService.instance.getPendingSyncCount();
        _pendingCountController.add(pending);
        return;
      }

      _isSyncing = true;
      _updateState(SyncState.syncing);

      await _syncOrders();
      await _syncAuditLogs();

      final remaining = await LocalDatabaseService.instance.getPendingSyncCount();
      _pendingCountController.add(remaining);

      _updateState(SyncState.idle);
    } catch (e) {
      debugPrint('[PosSyncService] Sync cycle error: $e');
      _updateState(SyncState.error);
    } finally {
      _isSyncing = false;
    }
  }

  /// مزامنة فواتير وطلبات الكاشير المحلية
  Future<void> _syncOrders() async {
    final pendingOrders = await LocalDatabaseService.instance.getPendingSyncOrders(limit: 30);
    if (pendingOrders.isEmpty) return;

    debugPrint('[PosSyncService] Found ${pendingOrders.length} local orders pending sync to Firebase.');

    final firestore = FirebaseFirestore.instance;

    for (final orderRow in pendingOrders) {
      final localId = orderRow['local_id'] as String;
      try {
        final itemsRaw = orderRow['items_json'] as String? ?? '[]';
        final itemsList = jsonDecode(itemsRaw);

        final firestoreData = <String, dynamic>{
          'orderId': localId,
          'restaurantId': orderRow['restaurant_id'],
          'orderType': orderRow['order_type'],
          'tableNumber': orderRow['table_number'],
          'customerName': orderRow['customer_name'],
          'customerPhone': orderRow['customer_phone'],
          'deliveryAddress': orderRow['delivery_address'],
          'items': itemsList,
          'subtotal': orderRow['subtotal'],
          'discountAmount': orderRow['discount_amount'],
          'taxOrService': orderRow['tax_or_service'],
          'totalAmount': orderRow['total_amount'],
          'paymentMethod': orderRow['payment_method'],
          'amountPaid': orderRow['amount_paid'],
          'changeAmount': orderRow['change_amount'],
          'status': orderRow['status'],
          'cashierName': orderRow['cashier_name'],
          'createdAt': PosOrder.parseDate(orderRow['created_at']),
          'syncedAt': FieldValue.serverTimestamp(),
          'source': 'pos_desktop_offline_synced',
        };

        // رفع الطلب إلى مجموعة orders الرئيسية لمدار
        await firestore.collection('orders').doc(localId).set(firestoreData, SetOptions(merge: true));

        // إذا كانت الطاولة محددة، نحدث حالة الطاولة
        final tableNum = orderRow['table_number']?.toString();
        final restId = orderRow['restaurant_id']?.toString();
        if (tableNum != null && tableNum.isNotEmpty && restId != null && restId.isNotEmpty) {
          await firestore
              .collection('restaurants')
              .doc(restId)
              .collection('tables')
              .doc(tableNum)
              .set({
            'tableNumber': tableNum,
            'status': 'occupied',
            'lastOrderId': localId,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).catchError((_) {});
        }

        // تسجيل إتمام المزامنة في SQLite
        await LocalDatabaseService.instance.markOrderSynced(localId: localId, remoteId: localId);
        debugPrint('[PosSyncService] Order $localId successfully synced to Firebase.');
      } catch (e) {
        debugPrint('[PosSyncService] Failed to sync order $localId: $e');
        await LocalDatabaseService.instance.recordSyncFailure(localId: localId, error: e.toString());
      }
    }
  }

  /// مزامنة سجلات التدقيق التجاري (Audit Logs)
  Future<void> _syncAuditLogs() async {
    final pendingLogs = await LocalDatabaseService.instance.getPendingAuditLogs(limit: 30);
    if (pendingLogs.isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    final syncedIds = <String>[];
    final currentUid = FirebaseAuth.instance.currentUser?.uid ??
        (OfflineAuthService.instance.currentUid.isNotEmpty
            ? OfflineAuthService.instance.currentUid
            : 'general_restaurant');

    for (final logRow in pendingLogs) {
      final logId = logRow['log_id'] as String;
      try {
        final beforeState = logRow['before_state'] != null ? jsonDecode(logRow['before_state']) : null;
        final afterState = logRow['after_state'] != null ? jsonDecode(logRow['after_state']) : null;

        await firestore
            .collection('restaurants')
            .doc(currentUid)
            .collection('audit_logs')
            .doc(logId)
            .set({
          'logId': logId,
          'terminalId': logRow['terminal_id'],
          'userId': logRow['user_id'],
          'userName': logRow['user_name'],
          'action': logRow['action'],
          'targetType': logRow['target_type'],
          'targetId': logRow['target_id'],
          'beforeState': beforeState,
          'afterState': afterState,
          'reason': logRow['reason'],
          'managerPinVerified': (logRow['manager_pin_verified'] == 1),
          'timestamp': DateTime.tryParse(logRow['timestamp'].toString()) ?? DateTime.now(),
          'syncedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        syncedIds.add(logId);
      } catch (e) {
        debugPrint('[PosSyncService] Failed to sync audit log $logId: $e');
      }
    }

    if (syncedIds.isNotEmpty) {
      await LocalDatabaseService.instance.markAuditLogsSynced(syncedIds);
    }
  }
}
