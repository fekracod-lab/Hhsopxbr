import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/unified_order.dart';
import '../../domain/entities/inventory_reservation.dart';
import '../../domain/entities/order_creation_result.dart';
import '../../domain/enums/order_enums.dart';
import '../../domain/services/order_validation_service.dart';
import '../../domain/services/order_state_machine.dart';
import '../../domain/services/inventory_reservation_service.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';
import 'package:dalal_alqaim/core/finance/application/financial_engine.dart';

/// مصدر البيانات البعيد للطلبات الموحدة وحجز المخزون (Unified Order Remote Datasource)
class UnifiedOrderRemoteDatasource {
  final FirebaseFirestore? _customFirestore;
  final FinancialEngine? _customFinancialEngine;

  UnifiedOrderRemoteDatasource({
    FirebaseFirestore? firestore,
    FinancialEngine? financialEngine,
  }) : _customFirestore = firestore,
        _customFinancialEngine = financialEngine;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  FinancialEngine get _financialEngine => _customFinancialEngine ?? FinancialEngine.instance;

  /// جلب طلب موحد
  Future<UnifiedOrder?> getOrder(String orderId) async {
    final doc = await _firestore.collection('orders').doc(orderId).get();
    if (doc.exists && doc.data() != null) {
      return UnifiedOrder.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  /// إنشاء طلب ذرياً مع قفل المخزون
  Future<OrderCreationResult> placeOrderAtomic(UnifiedOrder order) async {
    // 1. تدقيق صحة الطلب والتسعير
    OrderValidationService.validateOrder(order);

    // 2. فحص عدم التكرار (Idempotency Key)
    final isUnique = await verifyIdempotencyKey(order.idempotencyKey);
    if (!isUnique) {
      final existingOrder = await getOrder(order.orderId);
      if (existingOrder != null) {
        return OrderCreationResult.success(
          order: existingOrder,
          idempotencyKey: order.idempotencyKey,
        );
      }
      return OrderCreationResult.failure(
        errorMessage: 'تم إرسال هذا الطلب مسبقاً بنفس المفتاح',
        idempotencyKey: order.idempotencyKey,
      );
    }

    String? financialTxId;

    // 3. التنفيذ الذري لحجز المخزون وتوثيق الطلب
    await _firestore.runTransaction((tx) async {
      // أ. التحقق من المخزون وحجزه (إذا كان الطلب لمتجر ولديه merchantId)
      if (order.merchantId != null && order.orderType == OrderType.store) {
        for (final item in order.items) {
          final productRef = _firestore
              .collection('stores')
              .doc(order.merchantId!)
              .collection('products')
              .doc(item.id);

          final productSnap = await tx.get(productRef);
          if (productSnap.exists && productSnap.data() != null) {
            final data = productSnap.data()!;
            final currentStock = (data['stock'] as num?)?.toInt() ?? 9999;
            final remainingStock = InventoryReservationService.computeRemainingStock(
              productId: item.id,
              availableStock: currentStock,
              requestedQuantity: item.quantity,
            );

            // تحديث المخزون داخل الـ Transaction
            tx.update(productRef, {'stock': remainingStock});

            // تسجيل وثيقة الحجز
            final reservation = InventoryReservationService.createReservation(
              orderId: order.orderId,
              storeId: order.merchantId!,
              productId: item.id,
              quantity: item.quantity,
            );
            final resRef = _firestore.collection('inventory_reservations').doc(reservation.reservationId);
            tx.set(resRef, reservation.toMap());
          }
        }
      }

      // ب. كتابة وثيقة الطلب الرئيسية في /orders
      final orderRef = _firestore.collection('orders').doc(order.orderId);
      tx.set(orderRef, order.toMap());

      // ج. كتابة مرآة في سجل طلبات العميل
      final customerOrderRef = _firestore
          .collection('madar_orders')
          .doc(order.customerId)
          .collection('orders')
          .doc(order.orderId);
      tx.set(customerOrderRef, order.toMap());

      // د. كتابة مرآة في سجل المتجر/المطعم إن وجد
      if (order.merchantId != null) {
        final collectionName = order.orderType == OrderType.store ? 'stores' : 'restaurants';
        final merchantOrderRef = _firestore
            .collection(collectionName)
            .doc(order.merchantId!)
            .collection('orders')
            .doc(order.orderId);
        tx.set(merchantOrderRef, order.toMap());
      }
    });

    // 4. إذا كان الدفع بالمحفظة، يتم تنفيذ الخصم عبر المحرك المالي
    if (order.paymentMethod == OrderPaymentMethod.wallet && order.pricing.finalTotal > 0) {
      try {
        final finTx = await _financialEngine.executeOrderPayment(
          orderId: order.orderId,
          orderSource: order.orderType.key,
          customerId: order.customerId,
          amount: order.pricing.finalTotal,
          idempotencyKey: 'pay-${order.idempotencyKey}',
        );
        financialTxId = finTx.id;
      } catch (e) {
        // في حال فشل الدفع، يتم تعليم الطلب كـ Failed
        await updateOrderStatus(order.orderId, UnifiedOrderStatus.failed);
        return OrderCreationResult.failure(
          errorMessage: 'فشل في خصم قيمة الطلب من المحفظة: $e',
          idempotencyKey: order.idempotencyKey,
        );
      }
    }

    return OrderCreationResult.success(
      order: order,
      idempotencyKey: order.idempotencyKey,
      financialTxId: financialTxId,
    );
  }

  /// تحديث حالة الطلب وفق آلة الحالات
  Future<bool> updateOrderStatus(
    String orderId,
    UnifiedOrderStatus nextStatus, {
    String? driverId,
    String? driverName,
  }) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    final snap = await orderRef.get();
    if (!snap.exists || snap.data() == null) return false;

    final currentOrder = UnifiedOrder.fromMap(snap.data()!, snap.id);
    OrderStateMachine.assertValidTransition(currentOrder.status, nextStatus);

    final updates = <String, dynamic>{
      'status': nextStatus.key,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (driverId != null) updates['driverId'] = driverId;
    if (driverName != null) updates['driverName'] = driverName;

    await orderRef.update(updates);

    // تحديث المرآة في سجل العميل
    await _firestore
        .collection('madar_orders')
        .doc(currentOrder.customerId)
        .collection('orders')
        .doc(orderId)
        .update(updates)
        .catchError((_) {});

    return true;
  }

  /// إلغاء الطلب وتحرير الحجز
  Future<bool> cancelOrder(
    String orderId, {
    required String reason,
    required String actorId,
  }) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    final snap = await orderRef.get();
    if (!snap.exists || snap.data() == null) return false;

    final order = UnifiedOrder.fromMap(snap.data()!, snap.id);
    if (!OrderStateMachine.canCancelOrder(order.status)) {
      throw SecurityViolationException(
        'لا يمكن إلغاء الطلب في حالته الحالية (${order.status.key})',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'status',
      );
    }

    await orderRef.update({
      'status': UnifiedOrderStatus.cancelled.key,
      'cancelReason': reason,
      'cancelledBy': actorId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // تحرير حجوزات المخزون إن وجدت
    if (order.merchantId != null && order.orderType == OrderType.store) {
      for (final item in order.items) {
        final productRef = _firestore
            .collection('stores')
            .doc(order.merchantId!)
            .collection('products')
            .doc(item.id);
        await productRef.update({'stock': FieldValue.increment(item.quantity)}).catchError((_) {});
      }
    }

    return true;
  }

  /// التحقق من مفتاح عدم التكرار
  Future<bool> verifyIdempotencyKey(String idempotencyKey) async {
    final docRef = _firestore.collection('idempotency_keys').doc(idempotencyKey);
    final doc = await docRef.get();
    if (doc.exists) {
      return false;
    }
    await docRef.set({
      'key': idempotencyKey,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  /// جلب حجوزات المخزون لطلب
  Future<List<InventoryReservation>> getOrderReservations(String orderId) async {
    final snap = await _firestore
        .collection('inventory_reservations')
        .where('orderId', isEqualTo: orderId)
        .get();

    return snap.docs.map((d) => InventoryReservation.fromMap(d.data(), d.id)).toList();
  }
}
