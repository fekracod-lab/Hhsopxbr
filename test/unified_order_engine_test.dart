import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/orders/domain/enums/order_enums.dart';
import 'package:dalal_alqaim/core/orders/domain/entities/order_item.dart';
import 'package:dalal_alqaim/core/orders/domain/entities/order_pricing.dart';
import 'package:dalal_alqaim/core/orders/domain/entities/inventory_reservation.dart';
import 'package:dalal_alqaim/core/orders/domain/entities/unified_order.dart';
import 'package:dalal_alqaim/core/orders/domain/entities/order_creation_result.dart';
import 'package:dalal_alqaim/core/orders/domain/services/order_state_machine.dart';
import 'package:dalal_alqaim/core/orders/domain/services/order_pricing_validator.dart';
import 'package:dalal_alqaim/core/orders/domain/services/inventory_reservation_service.dart';
import 'package:dalal_alqaim/core/orders/domain/services/order_validation_service.dart';
import 'package:dalal_alqaim/core/orders/domain/repositories/i_order_repository.dart';
import 'package:dalal_alqaim/core/orders/application/unified_order_engine.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

class MockOrderRepository implements IOrderRepository {
  final Map<String, UnifiedOrder> orders = {};
  final Map<String, int> productStock = {};
  final List<InventoryReservation> reservations = [];
  final Set<String> usedIdempotencyKeys = {};

  @override
  Future<UnifiedOrder?> getOrder(String orderId) async {
    return orders[orderId];
  }

  @override
  Future<OrderCreationResult> placeOrderAtomic(UnifiedOrder order) async {
    OrderValidationService.validateOrder(order);

    if (usedIdempotencyKeys.contains(order.idempotencyKey)) {
      final existing = orders[order.orderId];
      if (existing != null) {
        return OrderCreationResult.success(order: existing, idempotencyKey: order.idempotencyKey);
      }
      return OrderCreationResult.failure(errorMessage: 'Duplicate request', idempotencyKey: order.idempotencyKey);
    }
    usedIdempotencyKeys.add(order.idempotencyKey);

    // Stock verification and lock
    if (order.merchantId != null && order.orderType == OrderType.store) {
      for (final item in order.items) {
        final currentStock = productStock[item.id] ?? 10;
        final remaining = InventoryReservationService.computeRemainingStock(
          productId: item.id,
          availableStock: currentStock,
          requestedQuantity: item.quantity,
        );
        productStock[item.id] = remaining;

        final res = InventoryReservationService.createReservation(
          orderId: order.orderId,
          storeId: order.merchantId!,
          productId: item.id,
          quantity: item.quantity,
        );
        reservations.add(res);
      }
    }

    orders[order.orderId] = order;
    return OrderCreationResult.success(order: order, idempotencyKey: order.idempotencyKey);
  }

  @override
  Future<bool> updateOrderStatus(
    String orderId,
    UnifiedOrderStatus nextStatus, {
    String? driverId,
    String? driverName,
  }) async {
    final order = orders[orderId];
    if (order == null) return false;

    OrderStateMachine.assertValidTransition(order.status, nextStatus);

    orders[orderId] = order.copyWith(
      status: nextStatus,
      driverId: driverId,
      driverName: driverName,
      updatedAt: DateTime.now(),
    );
    return true;
  }

  @override
  Future<bool> cancelOrder(
    String orderId, {
    required String reason,
    required String actorId,
  }) async {
    final order = orders[orderId];
    if (order == null) return false;

    if (!OrderStateMachine.canCancelOrder(order.status)) {
      throw SecurityViolationException(
        'Cannot cancel order in state ${order.status.key}',
        type: SecurityViolationType.unauthorizedFinancialMutation,
      );
    }

    orders[orderId] = order.copyWith(
      status: UnifiedOrderStatus.cancelled,
      updatedAt: DateTime.now(),
    );

    // Release stock
    if (order.merchantId != null && order.orderType == OrderType.store) {
      for (final item in order.items) {
        productStock[item.id] = (productStock[item.id] ?? 0) + item.quantity;
      }
    }
    return true;
  }

  @override
  Future<bool> verifyIdempotencyKey(String idempotencyKey) async {
    if (usedIdempotencyKeys.contains(idempotencyKey)) {
      return false;
    }
    usedIdempotencyKeys.add(idempotencyKey);
    return true;
  }

  @override
  Future<List<InventoryReservation>> getOrderReservations(String orderId) async {
    return reservations.where((r) => r.orderId == orderId).toList();
  }
}

void main() {
  group('Unified Order Engine & Atomic Inventory Lock Comprehensive Tests', () {
    // 1. Entities & Invariants
    test('1. OrderItem minor units & totalItemPrice calculation', () {
      const item = OrderItem(
        id: 'prod_1',
        name: 'برغر لحم دبل',
        price: 7500,
        quantity: 2,
      );

      expect(item.totalItemPrice, equals(15000));
      final map = item.toMap();
      expect(map['price'], equals(7500));
      expect(map['quantity'], equals(2));
    });

    test('2. OrderPricing calculation and finalTotal invariant', () {
      const pricing = OrderPricing(
        subtotal: 20000,
        deliveryFee: 3000,
        couponDiscount: 2000,
        pointsDiscount: 1000,
        walletDiscount: 0,
        pointsUsed: 10,
        pointsEarned: 20,
      );

      expect(pricing.totalDiscount, equals(3000));
      expect(pricing.finalTotal, equals(20000)); // 20,000 + 3,000 - 3,000 = 20,000
    });

    test('3. InventoryReservation creation and expiration check', () {
      final now = DateTime.now();
      final reservation = InventoryReservation(
        reservationId: 'res_1',
        orderId: 'ord_1',
        storeId: 'store_1',
        productId: 'prod_1',
        quantity: 3,
        status: ReservationStatus.reserved,
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 15)),
      );

      expect(reservation.quantity, equals(3));
      expect(reservation.isExpired, isFalse);
    });

    // 2. OrderStateMachine
    test('4. OrderStateMachine enforces full legal progression', () {
      expect(OrderStateMachine.canTransition(UnifiedOrderStatus.pending, UnifiedOrderStatus.confirmed), isTrue);
      expect(OrderStateMachine.canTransition(UnifiedOrderStatus.confirmed, UnifiedOrderStatus.preparing), isTrue);
      expect(OrderStateMachine.canTransition(UnifiedOrderStatus.preparing, UnifiedOrderStatus.ready), isTrue);
      expect(OrderStateMachine.canTransition(UnifiedOrderStatus.ready, UnifiedOrderStatus.assigned), isTrue);
      expect(OrderStateMachine.canTransition(UnifiedOrderStatus.assigned, UnifiedOrderStatus.delivering), isTrue);
      expect(OrderStateMachine.canTransition(UnifiedOrderStatus.delivering, UnifiedOrderStatus.pickedUp), isTrue);
      expect(OrderStateMachine.canTransition(UnifiedOrderStatus.pickedUp, UnifiedOrderStatus.completed), isTrue);
    });

    test('5. OrderStateMachine strictly blocks illegal transitions', () {
      // Completed -> Pending (Blocked!)
      expect(
        () => OrderStateMachine.assertValidTransition(
          UnifiedOrderStatus.completed,
          UnifiedOrderStatus.pending,
        ),
        throwsA(isA<SecurityViolationException>()),
      );

      // Cancelled -> Delivering (Blocked!)
      expect(
        () => OrderStateMachine.assertValidTransition(
          UnifiedOrderStatus.cancelled,
          UnifiedOrderStatus.delivering,
        ),
        throwsA(isA<SecurityViolationException>()),
      );

      // Delivering -> Preparing (Blocked!)
      expect(
        () => OrderStateMachine.assertValidTransition(
          UnifiedOrderStatus.delivering,
          UnifiedOrderStatus.preparing,
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('6. OrderStateMachine cancellation eligibility check', () {
      expect(OrderStateMachine.canCancelOrder(UnifiedOrderStatus.pending), isTrue);
      expect(OrderStateMachine.canCancelOrder(UnifiedOrderStatus.confirmed), isTrue);
      expect(OrderStateMachine.canCancelOrder(UnifiedOrderStatus.delivering), isFalse);
      expect(OrderStateMachine.canCancelOrder(UnifiedOrderStatus.pickedUp), isFalse);
      expect(OrderStateMachine.canCancelOrder(UnifiedOrderStatus.completed), isFalse);
    });

    // 3. Pricing Validator
    test('7. OrderPricingValidator validates matched subtotal and finalTotal', () {
      const items = [
        OrderItem(id: 'i1', name: 'Item 1', price: 5000, quantity: 2), // 10,000
        OrderItem(id: 'i2', name: 'Item 2', price: 4000, quantity: 1), // 4,000
      ];
      const pricing = OrderPricing(
        subtotal: 14000,
        deliveryFee: 2000,
        couponDiscount: 1000,
      );

      expect(
        () => OrderPricingValidator.validatePricing(items: items, pricing: pricing),
        returnsNormally,
      );
    });

    test('8. OrderPricingValidator rejects forged or unmatched subtotal', () {
      const items = [
        OrderItem(id: 'i1', name: 'Item 1', price: 5000, quantity: 2), // 10,000
      ];
      const forgedPricing = OrderPricing(
        subtotal: 6000, // Forged! (should be 10,000)
        deliveryFee: 2000,
      );

      expect(
        () => OrderPricingValidator.validatePricing(items: items, pricing: forgedPricing),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    // 4. Inventory Reservation Service
    test('9. InventoryReservationService calculates remaining stock safely', () {
      final remaining = InventoryReservationService.computeRemainingStock(
        productId: 'prod_apple',
        availableStock: 10,
        requestedQuantity: 3,
      );
      expect(remaining, equals(7));
    });

    test('10. InventoryReservationService blocks overselling (requested > available)', () {
      expect(
        () => InventoryReservationService.computeRemainingStock(
          productId: 'prod_apple',
          availableStock: 2,
          requestedQuantity: 5, // Overselling attempt!
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    // 5. Order Validation Service
    test('11. OrderValidationService validates required customer fields', () {
      final invalidOrder = UnifiedOrder(
        orderId: 'ord_bad',
        orderType: OrderType.food,
        customerId: '', // Empty!
        customerName: 'علي',
        customerPhone: '0770000000',
        deliveryAddress: 'حي الزهور',
        items: const [OrderItem(id: 'i1', name: 'وجبة', price: 5000, quantity: 1)],
        pricing: const OrderPricing(subtotal: 5000),
        idempotencyKey: 'idemp_key_12345',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () => OrderValidationService.validateOrder(invalidOrder),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    // 6. UnifiedOrderEngine Orchestration & Concurrency Lock
    test('12. UnifiedOrderEngine creates atomic order with stock deduction', () async {
      final mockRepo = MockOrderRepository();
      mockRepo.productStock['prod_lock_1'] = 5;

      final engine = UnifiedOrderEngine(repository: mockRepo);

      final order = UnifiedOrder(
        orderId: 'ord_atomic_1',
        orderType: OrderType.store,
        customerId: 'cus_1',
        customerName: 'محمد أحمد',
        customerPhone: '0780000000',
        deliveryAddress: 'شارع فلسطين',
        merchantId: 'store_1',
        items: const [
          OrderItem(id: 'prod_lock_1', name: 'شاي عراقي', price: 3000, quantity: 2),
        ],
        pricing: const OrderPricing(subtotal: 6000, deliveryFee: 1500),
        idempotencyKey: 'idemp_atomic_100',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await engine.createOrder(order: order);

      expect(result.isSuccess, isTrue);
      expect(mockRepo.productStock['prod_lock_1'], equals(3)); // 5 - 2 = 3
      expect(mockRepo.reservations.length, equals(1));
    });

    test('13. Concurrency Protection: Stock = 1, Customer A succeeds, Customer B fails (Out of Stock)', () async {
      final mockRepo = MockOrderRepository();
      mockRepo.productStock['prod_limited'] = 1; // Only 1 available!

      final engine = UnifiedOrderEngine(repository: mockRepo);

      final orderA = UnifiedOrder(
        orderId: 'ord_A',
        orderType: OrderType.store,
        customerId: 'cus_A',
        customerName: 'زبون أ',
        customerPhone: '0780111111',
        deliveryAddress: 'الكرادة',
        merchantId: 'store_1',
        items: const [OrderItem(id: 'prod_limited', name: 'قطعة فريدة', price: 10000, quantity: 1)],
        pricing: const OrderPricing(subtotal: 10000),
        idempotencyKey: 'idemp_ord_A',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final orderB = UnifiedOrder(
        orderId: 'ord_B',
        orderType: OrderType.store,
        customerId: 'cus_B',
        customerName: 'زبون ب',
        customerPhone: '0780222222',
        deliveryAddress: 'المنصور',
        merchantId: 'store_1',
        items: const [OrderItem(id: 'prod_limited', name: 'قطعة فريدة', price: 10000, quantity: 1)],
        pricing: const OrderPricing(subtotal: 10000),
        idempotencyKey: 'idemp_ord_B',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Customer A buys the last item
      final resA = await engine.createOrder(order: orderA);
      expect(resA.isSuccess, isTrue);
      expect(mockRepo.productStock['prod_limited'], equals(0));

      // Customer B attempts to buy the same item -> Throws SecurityViolationException / Out-of-Stock!
      expect(
        () => engine.createOrder(order: orderB),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('14. Idempotency: Duplicate order request returns original order without double reservation', () async {
      final mockRepo = MockOrderRepository();
      mockRepo.productStock['prod_idemp'] = 10;

      final engine = UnifiedOrderEngine(repository: mockRepo);

      final order = UnifiedOrder(
        orderId: 'ord_idemp_test',
        orderType: OrderType.store,
        customerId: 'cus_idemp',
        customerName: 'حسين',
        customerPhone: '0780333333',
        deliveryAddress: 'الجادرية',
        merchantId: 'store_1',
        items: const [OrderItem(id: 'prod_idemp', name: 'عصير', price: 2000, quantity: 2)],
        pricing: const OrderPricing(subtotal: 4000),
        idempotencyKey: 'fixed_idemp_key_999',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final res1 = await engine.createOrder(order: order);
      expect(res1.isSuccess, isTrue);
      expect(mockRepo.productStock['prod_idemp'], equals(8));

      // Duplicate submission
      final res2 = await engine.createOrder(order: order);
      expect(res2.isSuccess, isTrue);
      // Stock must NOT be deducted again!
      expect(mockRepo.productStock['prod_idemp'], equals(8));
    });

    test('15. Order cancellation releases reserved stock', () async {
      final mockRepo = MockOrderRepository();
      mockRepo.productStock['prod_cancel'] = 5;

      final engine = UnifiedOrderEngine(repository: mockRepo);

      final order = UnifiedOrder(
        orderId: 'ord_to_cancel',
        orderType: OrderType.store,
        customerId: 'cus_c',
        customerName: 'عمر',
        customerPhone: '0780444444',
        deliveryAddress: 'الأعظمية',
        merchantId: 'store_1',
        status: UnifiedOrderStatus.pending,
        items: const [OrderItem(id: 'prod_cancel', name: 'حليب', price: 2500, quantity: 2)],
        pricing: const OrderPricing(subtotal: 5000),
        idempotencyKey: 'idemp_cancel_1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await engine.createOrder(order: order);
      expect(mockRepo.productStock['prod_cancel'], equals(3)); // 5 - 2 = 3

      // Cancel the order
      final cancelled = await engine.cancelOrder(
        orderId: 'ord_to_cancel',
        reason: 'تغيير الرأي',
        actorId: 'cus_c',
      );

      expect(cancelled, isTrue);
      expect(mockRepo.orders['ord_to_cancel']!.status, equals(UnifiedOrderStatus.cancelled));
      // Stock restored
      expect(mockRepo.productStock['prod_cancel'], equals(5));
    });

    test('16. Order cancellation blocked once delivering or completed', () async {
      final mockRepo = MockOrderRepository();
      final engine = UnifiedOrderEngine(repository: mockRepo);

      final deliveringOrder = UnifiedOrder(
        orderId: 'ord_delivering',
        orderType: OrderType.food,
        customerId: 'cus_d',
        customerName: 'سامر',
        customerPhone: '0780555555',
        deliveryAddress: 'الدورة',
        status: UnifiedOrderStatus.delivering,
        items: const [OrderItem(id: 'food_1', name: 'شاورما', price: 4000, quantity: 1)],
        pricing: const OrderPricing(subtotal: 4000),
        idempotencyKey: 'idemp_deliv_1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      mockRepo.orders['ord_delivering'] = deliveringOrder;

      expect(
        () => engine.cancelOrder(
          orderId: 'ord_delivering',
          reason: 'إلغاء متأخر',
          actorId: 'cus_d',
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });
  });
}
