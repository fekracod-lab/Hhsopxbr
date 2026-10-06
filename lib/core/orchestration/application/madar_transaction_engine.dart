import '../domain/entities/transaction_context.dart';
import '../domain/entities/transaction_result.dart';
import '../domain/entities/saga_execution.dart';
import '../domain/entities/domain_event.dart';
import '../domain/enums/orchestration_enums.dart';
import '../domain/services/transaction_state_machine.dart';
import '../domain/services/idempotency_coordinator.dart';
import '../domain/services/failure_classifier.dart';
import '../domain/services/compensation_engine.dart';
import '../domain/services/domain_event_bus.dart';
import '../domain/repositories/i_transaction_repository.dart';
import '../data/repositories/transaction_repository.dart';

import 'package:dalal_alqaim/core/security/application/security_engine.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';
import 'package:dalal_alqaim/core/pricing/application/pricing_engine.dart';
import 'package:dalal_alqaim/core/pricing/domain/entities/fare_request.dart';
import 'package:dalal_alqaim/core/pricing/domain/entities/pricing_snapshot.dart';
import 'package:dalal_alqaim/core/pricing/domain/enums/pricing_enums.dart';
import 'package:dalal_alqaim/core/orders/domain/services/inventory_reservation_service.dart';
import 'package:dalal_alqaim/core/orders/domain/entities/order_item.dart';
import 'package:dalal_alqaim/core/orders/domain/entities/inventory_reservation.dart';
import 'package:dalal_alqaim/core/finance/application/financial_engine.dart';
import 'package:dalal_alqaim/core/dispatch/application/dispatch_engine.dart';
import 'package:dalal_alqaim/core/dispatch/domain/entities/dispatch_request.dart';
import 'package:dalal_alqaim/core/dispatch/domain/enums/dispatch_enums.dart';
import 'package:dalal_alqaim/core/notifications/application/notification_engine.dart';
import 'package:dalal_alqaim/core/notifications/domain/enums/notification_enums.dart';

/// محرك تنسيق المعاملات الموزعة الشامل (MADAR Master Transaction Orchestrator)
class MadarTransactionEngine {
  static MadarTransactionEngine? _instance;
  static MadarTransactionEngine get instance => _instance ??= MadarTransactionEngine();

  final ITransactionRepository _repository;
  final IdempotencyCoordinator _idempotencyCoordinator;
  final DomainEventBus _eventBus;
  final SecurityEngine _securityEngine;
  final PricingEngine _pricingEngine;
  final FinancialEngine _financialEngine;
  final DispatchEngine _dispatchEngine;
  final NotificationEngine _notificationEngine;

  MadarTransactionEngine({
    ITransactionRepository? repository,
    IdempotencyCoordinator? idempotencyCoordinator,
    DomainEventBus? eventBus,
    SecurityEngine? securityEngine,
    PricingEngine? pricingEngine,
    FinancialEngine? financialEngine,
    DispatchEngine? dispatchEngine,
    NotificationEngine? notificationEngine,
  }) : _repository = repository ?? TransactionRepository(),
        _idempotencyCoordinator = idempotencyCoordinator ?? IdempotencyCoordinator(),
        _eventBus = eventBus ?? DomainEventBus.instance,
        _securityEngine = securityEngine ?? SecurityEngine.instance,
        _pricingEngine = pricingEngine ?? PricingEngine.instance,
        _financialEngine = financialEngine ?? FinancialEngine.instance,
        _dispatchEngine = dispatchEngine ?? DispatchEngine.instance,
        _notificationEngine = notificationEngine ?? NotificationEngine.instance;

  /// تنفيذ رحلة إنشاء وطلب متكاملة End-to-End منسقة عبر كافة المحركات
  Future<TransactionResult> executeOrderTransaction({
    required String customerId,
    required String orderId,
    required String serviceType,
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    required double distanceMeters,
    required List<OrderItem> items,
    required Map<String, int> storeInventoryStock,
    required String paymentMethod, // 'wallet' or 'cash'
    required String idempotencyKey,
  }) async {
    final transactionId = 'tx-$orderId';
    final requestHash = IdempotencyCoordinator.computeRequestHash(
      actorId: customerId,
      serviceType: serviceType,
      orderId: orderId,
      amount: items.fold(0, (sum, it) => sum + (it.price * it.quantity)),
      payload: {'itemsCount': items.length, 'paymentMethod': paymentMethod},
    );

    // 1. فحص عدم التكرار الشامل (Central Idempotency Check)
    final isNew = _idempotencyCoordinator.checkAndRegister(
      idempotencyKey: idempotencyKey,
      requestHash: requestHash,
    );
    if (!isNew) {
      final cachedResult = _idempotencyCoordinator.getExistingResult(idempotencyKey);
      if (cachedResult is TransactionResult) {
        return cachedResult;
      }
      return TransactionResult.success(
        transactionId: transactionId,
        orderId: orderId,
        metadata: {'cached': true},
      );
    }

    final context = TransactionContext(
      transactionId: transactionId,
      operationId: 'op-$orderId',
      idempotencyKey: idempotencyKey,
      actorId: customerId,
      actorRole: 'customer',
      serviceType: serviceType,
      orderId: orderId,
      requestHash: requestHash,
      correlationId: 'corr-$orderId',
      createdAt: DateTime.now(),
    );

    var currentState = TransactionState.created;
    var saga = SagaExecution(
      sagaId: 'saga-$transactionId',
      transactionId: transactionId,
      status: SagaStatus.inProgress,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    PricingSnapshot? pricingSnapshot;
    final reservations = <InventoryReservation>[];
    final originalStockSnapshots = <String, int>{};
    int itemsSubtotal = 0;
    int totalOrderFare = 0;

    try {
      // -------------------------------------------------------------
      // الخطوة 1: الفحص الأمني (Security Engine)
      // -------------------------------------------------------------
      currentState = TransactionState.validating;
      TransactionStateMachine.assertValidTransition(TransactionState.created, currentState);
      await _repository.saveTransactionContext(context, currentState);

      final actorRole = MadarRole.fromString(context.actorRole);
      if (actorRole != MadarRole.customer && !actorRole.isAdmin) {
        throw const SecurityViolationException(
          'غير مصرح لهذا الدور بإنشاء طلبات',
          type: SecurityViolationType.unauthorizedRoleEscalation,
        );
      }
      saga = saga.copyWith(completedSteps: [...saga.completedSteps, SagaStepType.securityValidation]);

      // -------------------------------------------------------------
      // الخطوة 2: احتساب الأجرة وتثبيت اللقطة (Dynamic Pricing Engine)
      // -------------------------------------------------------------
      currentState = TransactionState.pricing;
      TransactionStateMachine.assertValidTransition(TransactionState.validating, currentState);
      await _repository.updateTransactionState(transactionId, currentState);

      final pricingType = serviceType == 'taxi'
          ? PricingServiceType.taxi
          : serviceType == 'store'
              ? PricingServiceType.store
              : serviceType == 'mersal'
                  ? PricingServiceType.mersal
                  : PricingServiceType.food;

      pricingSnapshot = await _pricingEngine.createAndPersistSnapshot(
        orderId: orderId,
        request: FareRequest(
          serviceType: pricingType,
          distanceMeters: distanceMeters,
          requestedAt: DateTime.now(),
          idempotencyKey: 'idemp_prc_$orderId',
        ),
      );

      itemsSubtotal = items.fold(0, (sum, it) => sum + (it.price * it.quantity));
      totalOrderFare = itemsSubtotal + pricingSnapshot.finalFare;
      saga = saga.copyWith(completedSteps: [...saga.completedSteps, SagaStepType.fareCalculation]);

      // -------------------------------------------------------------
      // الخطوة 3: حجز المخزون الذري (Atomic Inventory Lock)
      // -------------------------------------------------------------
      if (items.isNotEmpty) {
        currentState = TransactionState.reserving;
        TransactionStateMachine.assertValidTransition(TransactionState.pricing, currentState);
        await _repository.updateTransactionState(transactionId, currentState);

        for (final item in items) {
          final currentAvailable = storeInventoryStock[item.id] ?? 0;
          originalStockSnapshots[item.id] = currentAvailable;

          final remaining = InventoryReservationService.computeRemainingStock(
            productId: item.id,
            availableStock: currentAvailable,
            requestedQuantity: item.quantity,
          );
          storeInventoryStock[item.id] = remaining;

          final res = InventoryReservationService.createReservation(
            orderId: orderId,
            storeId: 'store_central',
            productId: item.id,
            quantity: item.quantity,
          );
          reservations.add(res);
        }
        saga = saga.copyWith(completedSteps: [...saga.completedSteps, SagaStepType.inventoryReservation]);
      }

      // -------------------------------------------------------------
      // الخطوة 4: العملية المالية (Financial Engine)
      // -------------------------------------------------------------
      currentState = TransactionState.paymentAuthorizing;
      TransactionStateMachine.assertValidTransition(
        items.isNotEmpty ? TransactionState.reserving : TransactionState.pricing,
        currentState,
      );
      await _repository.updateTransactionState(transactionId, currentState);

      if (paymentMethod == 'wallet') {
        await _financialEngine.executeOrderPayment(
          orderId: orderId,
          orderSource: serviceType,
          customerId: customerId,
          amount: totalOrderFare,
          idempotencyKey: 'idemp_pay_$orderId',
        );
      }
      saga = saga.copyWith(completedSteps: [...saga.completedSteps, SagaStepType.paymentAuthorization]);

      // -------------------------------------------------------------
      // الخطوة 5: تثبيت وإنشاء الطلب (Order Creation Commit)
      // -------------------------------------------------------------
      currentState = TransactionState.orderCreating;
      TransactionStateMachine.assertValidTransition(TransactionState.paymentAuthorizing, currentState);
      await _repository.updateTransactionState(transactionId, currentState);
      saga = saga.copyWith(completedSteps: [...saga.completedSteps, SagaStepType.orderCreation]);

      // -------------------------------------------------------------
      // الخطوة 6: التوزيع الذكي للكباتن (Intelligent Dispatch Engine)
      // -------------------------------------------------------------
      currentState = TransactionState.dispatching;
      TransactionStateMachine.assertValidTransition(TransactionState.orderCreating, currentState);
      await _repository.updateTransactionState(transactionId, currentState);

      final dispatchRes = await _dispatchEngine.startDispatchSession(
        request: DispatchRequest(
          dispatchId: 'disp-$orderId',
          orderId: orderId,
          dispatchType: DispatchType.fromString(serviceType),
          pickupLatitude: pickupLat,
          pickupLongitude: pickupLng,
          pickupAddress: pickupAddress,
          dropoffLatitude: dropoffLat,
          dropoffLongitude: dropoffLng,
          dropoffAddress: dropoffAddress,
          orderTotal: totalOrderFare,
          idempotencyKey: 'idemp_dsp_$orderId',
          createdAt: DateTime.now(),
        ),
      );
      saga = saga.copyWith(completedSteps: [...saga.completedSteps, SagaStepType.driverDispatch]);

      // -------------------------------------------------------------
      // الخطوة 7: إرسال الإشعارات الذكية (Notification Engine)
      // -------------------------------------------------------------
      currentState = TransactionState.notifying;
      TransactionStateMachine.assertValidTransition(TransactionState.dispatching, currentState);
      await _repository.updateTransactionState(transactionId, currentState);

      await _notificationEngine.emitQuickNotification(
        eventType: NotificationEventType.orderCreated,
        entityId: orderId,
        targetUserId: customerId,
        title: 'تم استلام طلبك بنجاح',
        body: 'طلبك برقم $orderId قيد المعالجة والتوزيع',
        category: NotificationCategory.orders,
      );
      saga = saga.copyWith(completedSteps: [...saga.completedSteps, SagaStepType.notificationDispatch]);

      // -------------------------------------------------------------
      // الخطوة 8: إتمام المعاملة بنجاح (Transaction Completed)
      // -------------------------------------------------------------
      currentState = TransactionState.completed;
      TransactionStateMachine.assertValidTransition(TransactionState.notifying, currentState);
      await _repository.updateTransactionState(transactionId, currentState);

      saga = saga.copyWith(status: SagaStatus.completed);
      await _repository.saveSagaExecution(saga);

      // حفظ ونشر حدث النطاق (Durable Outbox Event Stream)
      final domainEvent = DomainEvent(
        eventId: 'evt-ord-created-$orderId',
        eventType: 'order.created',
        aggregateId: orderId,
        aggregateType: 'Order',
        transactionId: transactionId,
        correlationId: context.correlationId,
        occurredAt: DateTime.now(),
        payload: {
          'orderId': orderId,
          'customerId': customerId,
          'totalFare': totalOrderFare,
          'assignedDriverId': dispatchRes.assignedDriverId,
        },
      );
      await _repository.saveDomainEvent(domainEvent);
      await _eventBus.publish(domainEvent);

      final successResult = TransactionResult.success(
        transactionId: transactionId,
        orderId: orderId,
        sagaExecution: saga,
        metadata: {
          'totalFare': totalOrderFare,
          'assignedDriverId': dispatchRes.assignedDriverId,
        },
      );

      _idempotencyCoordinator.saveResult(idempotencyKey, successResult);
      return successResult;
    } catch (e) {
      // =============================================================
      // ملحمة التعويض العكسي عند الفشل (Saga Compensation)
      // =============================================================
      final (failureType, failureAction) = FailureClassifier.classify(e);
      currentState = TransactionState.compensating;
      await _repository.updateTransactionState(transactionId, currentState);

      final compensations = CompensationEngine.planCompensations(
        saga: saga,
        orderId: orderId,
        paymentAmount: totalOrderFare,
      );

      // تنفيذ التعويض العكسي خطوة بخطوة
      for (final comp in compensations) {
        if (comp.stepType == SagaStepType.inventoryReservation) {
          // استعادة الكميات المحجوزة للمخزون
          originalStockSnapshots.forEach((productId, originalQty) {
            storeInventoryStock[productId] = originalQty;
          });
        } else if (comp.stepType == SagaStepType.paymentAuthorization && paymentMethod == 'wallet') {
          // تقديم طلب استرداد رسمي عبر SecurityEngine
          await _securityEngine.submitOrderRefundRequest(
            orderId: orderId,
            orderSource: serviceType,
            userId: customerId,
            amount: totalOrderFare.toDouble(),
            reason: 'تعويض آلي نتيجة تعثر استكمال المعاملة الموزعة',
            idempotencyKey: 'idemp_comp_ref_$orderId',
          );
        }
      }

      saga = saga.copyWith(
        status: SagaStatus.compensated,
        failedStep: saga.completedSteps.isNotEmpty ? saga.completedSteps.last : null,
        compensations: compensations.map((c) => c.copyWith(isExecuted: true, executedAt: DateTime.now())).toList(),
      );
      await _repository.saveSagaExecution(saga);

      currentState = failureAction == FailureAction.retry
          ? TransactionState.recovered
          : TransactionState.failed;
      await _repository.updateTransactionState(transactionId, currentState);

      return TransactionResult.failed(
        transactionId: transactionId,
        orderId: orderId,
        state: currentState,
        failureType: failureType,
        errorMessage: e.toString(),
        sagaExecution: saga,
      );
    }
  }
}
