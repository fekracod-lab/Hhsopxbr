// اختبارات دورة حياة الطلبات وآلة الحالة والتنبيهات لمنظومة MADAR SHOP
// Unit & Domain Tests — Zero Mocks

import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/madar_shop/madar_shop.dart';

// Fake implementations for Lifecycle Coordinator tests
class FakeAlertAudioBridge implements IShopAlertAudioBridge {
  bool isPlaying = false;
  String? activeOrderId;
  int oneShotCalls = 0;

  @override
  bool get isAudioAlertPlaying => isPlaying;

  @override
  Future<void> startOrderIncomingLoop({
    required String orderId,
    String? soundAssetPath,
  }) async {
    isPlaying = true;
    activeOrderId = orderId;
  }

  @override
  Future<void> stopOrderIncomingLoop({required String orderId}) async {
    isPlaying = false;
    activeOrderId = null;
  }

  @override
  Future<void> playOneShotChime({String? soundAssetPath}) async {
    oneShotCalls++;
  }
}

class FakeAuditRepository implements IShopAuditRepository {
  final List<ShopAuditEntry> recordedEntries = [];

  @override
  Future<void> recordAuditEntry(ShopAuditEntry entry) async {
    recordedEntries.add(entry);
  }

  @override
  Future<List<ShopAuditEntry>> getAuditEntries({
    required String businessId,
    required String branchId,
    ShopAuditAction? actionFilter,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    return recordedEntries;
  }
}

void main() {
  group('MADAR SHOP Phase S1 — Order Core & Lifecycle Tests', () {
    test('1. ShopOrderItem subtotal, discount, and profit margin calculation', () {
      final item = const ShopOrderItem(
        itemId: 'ITEM-01',
        productId: 'PROD-01',
        productName: 'علبة شوكولاتة فاخرة',
        sku: 'SKU-CHOC-01',
        unitPrice: 10000.0,
        unitCostPrice: 7000.0,
        quantity: 3.0,
        discountAmount: 2000.0, // 2000 IQD discount on the line
      );

      // Subtotal = 10000 * 3 = 30000
      expect(item.lineSubtotal, 30000.0);
      // Net Line Total = 30000 - 2000 = 28000
      expect(item.lineTotal, 28000.0);
      // Cost = 7000 * 3 = 21000
      expect(item.totalCost, 21000.0);
      // Net Profit = 28000 - 21000 = 7000 IQD
      expect(item.netProfit, 7000.0);
    });

    test('2. ShopOrder grand total, taxes, delivery fee, and net profit', () {
      final item1 = const ShopOrderItem(
        itemId: 'ITM-1',
        productId: 'P1',
        productName: 'سلعة 1',
        sku: 'SKU-1',
        unitPrice: 10000.0,
        unitCostPrice: 6000.0,
        quantity: 2.0,
      ); // Total: 20000, Cost: 12000

      final item2 = const ShopOrderItem(
        itemId: 'ITM-2',
        productId: 'P2',
        productName: 'سلعة 2',
        sku: 'SKU-2',
        unitPrice: 5000.0,
        unitCostPrice: 3000.0,
        quantity: 1.0,
      ); // Total: 5000, Cost: 3000

      final order = ShopOrder(
        orderId: 'ORD-1001',
        orderNumber: 'ORD-1001',
        businessId: 'BIZ-01',
        branchId: 'BR-01',
        source: ShopOrderSource.marketplace,
        channel: ShopOrderChannel.mobileApp,
        fulfillment: ShopOrderFulfillment.delivery,
        status: ShopOrderStatus.pending,
        customerName: 'زيد محمد',
        customerPhone: '07701234567',
        items: [item1, item2],
        cartDiscountAmount: 3000.0, // General voucher/discount
        deliveryFee: 2500.0,        // Delivery fee
        taxAmount: 500.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // itemsSubtotal = 20000 + 5000 = 25000
      expect(order.itemsSubtotal, 25000.0);
      // grandTotal = 25000 - 3000 + 2500 + 500 = 25000
      expect(order.grandTotal, 25000.0);
      // totalOrderCost = 12000 + 3000 = 15000
      expect(order.totalOrderCost, 15000.0);
      // netProfit = (25000 - 3000) - 15000 = 7000
      expect(order.netProfit, 7000.0);
      // totalUnitsCount = 2 + 1 = 3 units
      expect(order.totalUnitsCount, 3.0);
    });

    test('3. ShopOrderStateMachine allows POS Walk-in direct completion', () {
      final validPosTransition = ShopOrderStateMachine.validateTransition(
        currentStatus: ShopOrderStatus.pending,
        targetStatus: ShopOrderStatus.completed,
        source: ShopOrderSource.pos,
      );
      expect(validPosTransition.isAllowed, isTrue);
    });

    test('4. ShopOrderStateMachine strictly enforces Delivery progression', () {
      // 1. Pending -> Accepted: Allowed
      final step1 = ShopOrderStateMachine.validateTransition(
        currentStatus: ShopOrderStatus.pending,
        targetStatus: ShopOrderStatus.accepted,
        source: ShopOrderSource.marketplace,
        fulfillment: ShopOrderFulfillment.delivery,
      );
      expect(step1.isAllowed, isTrue);

      // 2. Pending -> Completed: Strictly Rejected for Marketplace
      final invalidJump = ShopOrderStateMachine.validateTransition(
        currentStatus: ShopOrderStatus.pending,
        targetStatus: ShopOrderStatus.completed,
        source: ShopOrderSource.marketplace,
        fulfillment: ShopOrderFulfillment.delivery,
      );
      expect(invalidJump.isAllowed, isFalse);

      // 3. Accepted -> Preparing: Allowed
      final step2 = ShopOrderStateMachine.validateTransition(
        currentStatus: ShopOrderStatus.accepted,
        targetStatus: ShopOrderStatus.preparing,
        source: ShopOrderSource.marketplace,
        fulfillment: ShopOrderFulfillment.delivery,
      );
      expect(step2.isAllowed, isTrue);

      // 4. Preparing -> Ready: Allowed
      final step3 = ShopOrderStateMachine.validateTransition(
        currentStatus: ShopOrderStatus.preparing,
        targetStatus: ShopOrderStatus.ready,
        source: ShopOrderSource.marketplace,
        fulfillment: ShopOrderFulfillment.delivery,
      );
      expect(step3.isAllowed, isTrue);

      // 5. Ready -> Delivering: Allowed
      final step4 = ShopOrderStateMachine.validateTransition(
        currentStatus: ShopOrderStatus.ready,
        targetStatus: ShopOrderStatus.delivering,
        source: ShopOrderSource.marketplace,
        fulfillment: ShopOrderFulfillment.delivery,
      );
      expect(step4.isAllowed, isTrue);

      // 6. Delivering -> Completed: Allowed
      final step5 = ShopOrderStateMachine.validateTransition(
        currentStatus: ShopOrderStatus.delivering,
        targetStatus: ShopOrderStatus.completed,
        source: ShopOrderSource.marketplace,
        fulfillment: ShopOrderFulfillment.delivery,
      );
      expect(step5.isAllowed, isTrue);

      // 7. Cannot transition after Completed
      final afterCompleted = ShopOrderStateMachine.validateTransition(
        currentStatus: ShopOrderStatus.completed,
        targetStatus: ShopOrderStatus.ready,
        source: ShopOrderSource.marketplace,
        fulfillment: ShopOrderFulfillment.delivery,
      );
      expect(afterCompleted.isAllowed, isFalse);
    });

    test('5. ShopOrderStateMachine supports In-Store Pickup lifecycle', () {
      // Pending -> Accepted -> Preparing -> ReadyForPickup -> PickedUp -> Completed
      expect(
        ShopOrderStateMachine.validateTransition(
          currentStatus: ShopOrderStatus.accepted,
          targetStatus: ShopOrderStatus.preparing,
          source: ShopOrderSource.marketplace,
          fulfillment: ShopOrderFulfillment.inStorePickup,
        ).isAllowed,
        isTrue,
      );

      expect(
        ShopOrderStateMachine.validateTransition(
          currentStatus: ShopOrderStatus.preparing,
          targetStatus: ShopOrderStatus.readyForPickup,
          source: ShopOrderSource.marketplace,
          fulfillment: ShopOrderFulfillment.inStorePickup,
        ).isAllowed,
        isTrue,
      );

      expect(
        ShopOrderStateMachine.validateTransition(
          currentStatus: ShopOrderStatus.readyForPickup,
          targetStatus: ShopOrderStatus.pickedUp,
          source: ShopOrderSource.marketplace,
          fulfillment: ShopOrderFulfillment.inStorePickup,
        ).isAllowed,
        isTrue,
      );

      expect(
        ShopOrderStateMachine.validateTransition(
          currentStatus: ShopOrderStatus.pickedUp,
          targetStatus: ShopOrderStatus.completed,
          source: ShopOrderSource.marketplace,
          fulfillment: ShopOrderFulfillment.inStorePickup,
        ).isAllowed,
        isTrue,
      );
    });

    test('6. Rejection and Cancellation require mandatory reason', () {
      final rejectNoReason = ShopOrderStateMachine.validateTransition(
        currentStatus: ShopOrderStatus.pending,
        targetStatus: ShopOrderStatus.rejected,
        source: ShopOrderSource.marketplace,
        reason: null,
      );
      expect(rejectNoReason.isAllowed, isFalse);
      expect(rejectNoReason.rejectionMessage, contains('سبب'));

      final rejectWithReason = ShopOrderStateMachine.validateTransition(
        currentStatus: ShopOrderStatus.pending,
        targetStatus: ShopOrderStatus.rejected,
        source: ShopOrderSource.marketplace,
        reason: 'نفاد الكمية المطلوبة من المخزن',
      );
      expect(rejectWithReason.isAllowed, isTrue);
    });

    test('7. ShopOrderLifecycleCoordinator enforces permissions, audio, versioning and audit', () async {
      final identityCoordinator = ShopIdentityCoordinator();
      final audioBridge = FakeAlertAudioBridge();
      final auditRepository = FakeAuditRepository();

      final lifecycleCoordinator = ShopOrderLifecycleCoordinator(
        identityCoordinator: identityCoordinator,
        audioBridge: audioBridge,
        auditRepository: auditRepository,
      );

      final order = ShopOrder(
        orderId: 'ORD-999',
        orderNumber: 'ORD-999',
        businessId: 'BIZ-01',
        branchId: 'BR-01',
        source: ShopOrderSource.marketplace,
        channel: ShopOrderChannel.mobileApp,
        fulfillment: ShopOrderFulfillment.delivery,
        status: ShopOrderStatus.pending,
        version: 1,
        idempotencyKey: 'IDEM-999',
        customerName: 'سارة',
        customerPhone: '07700000000',
        items: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Test incoming chime trigger
      await lifecycleCoordinator.handleNewIncomingMarketplaceOrder(order);
      expect(audioBridge.isPlaying, isTrue);
      expect(audioBridge.activeOrderId, 'ORD-999');

      // Attempt transition without auth -> throws
      expect(
        () => lifecycleCoordinator.transitionOrder(
          currentOrder: order,
          targetStatus: ShopOrderStatus.accepted,
        ),
        throwsA(isA<OrderTransitionException>()),
      );

      // Login as Cashier (has acceptOrder permission)
      final cashier = ShopUser(
        userId: 'U-CASHIER-1',
        businessId: 'BIZ-01',
        fullName: 'سامر الكاشير',
        phone: '07701111111',
        email: 'samer@madar.iq',
        role: ShopRole.cashier,
        createdAt: DateTime.now(),
      );
      final session = ShopSession(
        sessionId: 'S1',
        installationId: 'INST-01',
        terminalId: 'POS-01',
        userId: 'U-CASHIER-1',
        businessId: 'BIZ-01',
        activeBranchId: 'BR-01',
        startedAt: DateTime.now(),
        lastHeartbeatAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      identityCoordinator.setSession(user: cashier, session: session);

      // Accept order -> should succeed, stop audio alert and increment version
      final acceptedOrder = await lifecycleCoordinator.transitionOrder(
        currentOrder: order,
        targetStatus: ShopOrderStatus.accepted,
      );
      expect(acceptedOrder.status, ShopOrderStatus.accepted);
      expect(acceptedOrder.version, 2);
      expect(audioBridge.isPlaying, isFalse);

      // Cancel active order by cashier -> cashier doesn't have cancelActiveOrder by default
      expect(
        () => lifecycleCoordinator.transitionOrder(
          currentOrder: acceptedOrder,
          targetStatus: ShopOrderStatus.cancelled,
          reason: 'طلب الإلغاء',
        ),
        throwsA(isA<OrderTransitionException>()),
      );

      // Login as Manager (has cancelActiveOrder permission)
      final manager = ShopUser(
        userId: 'U-MGR-1',
        businessId: 'BIZ-01',
        fullName: 'المدير العام',
        phone: '07702222222',
        email: 'manager@madar.iq',
        role: ShopRole.generalManager,
        createdAt: DateTime.now(),
      );
      identityCoordinator.setSession(user: manager, session: session);

      // Cancel with reason -> should succeed, increment version and record audit entry
      final cancelledOrder = await lifecycleCoordinator.transitionOrder(
        currentOrder: acceptedOrder,
        targetStatus: ShopOrderStatus.cancelled,
        reason: 'طلب الزبون إلغاء الطلب بعد الاتصال',
      );
      expect(cancelledOrder.status, ShopOrderStatus.cancelled);
      expect(cancelledOrder.version, 3);
      expect(auditRepository.recordedEntries.length, 1);
      expect(auditRepository.recordedEntries.first.action, ShopAuditAction.orderVoided);
      expect(auditRepository.recordedEntries.first.userId, 'U-MGR-1');
      expect(auditRepository.recordedEntries.first.reason, contains('إلغاء الطلب'));
    });
  });
}
