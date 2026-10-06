import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';
import 'package:dalal_alqaim/core/security/domain/services/permission_guard.dart';
import 'package:dalal_alqaim/core/security/domain/services/financial_operation_guard.dart';
import 'package:dalal_alqaim/core/security/domain/services/tamper_detector.dart';
import 'package:dalal_alqaim/core/security/domain/repositories/i_security_repository.dart';
import 'package:dalal_alqaim/core/security/application/security_engine.dart';

class MockSecurityRepository implements ISecurityRepository {
  final List<RefundRequestEntity> refundRequests = [];
  final List<SecurityViolation> loggedViolations = [];
  final Set<String> usedIdempotencyKeys = {};

  @override
  Future<RefundRequestEntity> submitRefundRequest(RefundRequestEntity request) async {
    final entity = RefundRequestEntity(
      id: 'ref_${refundRequests.length + 1}',
      orderId: request.orderId,
      orderSource: request.orderSource,
      userId: request.userId,
      amount: request.amount,
      points: request.points,
      reason: request.reason,
      status: request.status,
      idempotencyKey: request.idempotencyKey,
      createdAt: request.createdAt,
    );
    refundRequests.add(entity);
    return entity;
  }

  @override
  Future<List<RefundRequestEntity>> getUserRefundRequests(String userId) async {
    return refundRequests.where((r) => r.userId == userId).toList();
  }

  @override
  Future<void> logSecurityViolation(SecurityViolation violation) async {
    loggedViolations.add(violation);
  }

  @override
  Future<bool> verifyIdempotencyKey(String idempotencyKey) async {
    if (usedIdempotencyKeys.contains(idempotencyKey)) {
      return false;
    }
    usedIdempotencyKeys.add(idempotencyKey);
    return true;
  }
}

void main() {
  group('MADAR Security Engine & RBAC Comprehensive Tests', () {
    test('1. MadarRole normalization and admin/captain flags', () {
      expect(MadarRole.fromString('admin').isAdmin, isTrue);
      expect(MadarRole.fromString('super_admin').isAdmin, isTrue);
      expect(MadarRole.fromString('main_admin').isAdmin, isTrue);
      expect(MadarRole.fromString('customer').isAdmin, isFalse);
      expect(MadarRole.fromString('driver').isCaptain, isTrue);
      expect(MadarRole.fromString('delivery').isCaptain, isTrue);
      expect(MadarRole.fromString('unknown_role'), equals(MadarRole.customer));
    });

    test('2. PermissionGuard enforces strict role-based permission matrix', () {
      expect(PermissionGuard.hasPermission(MadarRole.admin, MadarPermission.directFinancialMutation), isTrue);
      expect(PermissionGuard.hasPermission(MadarRole.customer, MadarPermission.directFinancialMutation), isFalse);
      expect(PermissionGuard.hasPermission(MadarRole.customer, MadarPermission.requestRefund), isTrue);
      expect(PermissionGuard.hasPermission(MadarRole.customer, MadarPermission.modifyConfig), isFalse);
      expect(PermissionGuard.hasPermission(MadarRole.driver, MadarPermission.broadcastEmergency), isTrue);
      expect(PermissionGuard.hasPermission(MadarRole.driver, MadarPermission.viewAuditLogs), isFalse);
    });

    test('3. PermissionGuard.canCancelOrder respects terminal and in-flight delivery states', () {
      // Customer owner
      expect(
        PermissionGuard.canCancelOrder(
          role: MadarRole.customer,
          orderStatus: 'placed',
          isOwner: true,
        ),
        isTrue,
      );

      // Customer trying to cancel once picked up by driver -> REJECTED
      expect(
        PermissionGuard.canCancelOrder(
          role: MadarRole.customer,
          orderStatus: 'picked_up',
          isOwner: true,
        ),
        isFalse,
      );

      // Customer trying to cancel delivered order -> REJECTED
      expect(
        PermissionGuard.canCancelOrder(
          role: MadarRole.customer,
          orderStatus: 'delivered',
          isOwner: true,
        ),
        isFalse,
      );

      // Non-owner customer -> REJECTED
      expect(
        PermissionGuard.canCancelOrder(
          role: MadarRole.customer,
          orderStatus: 'placed',
          isOwner: false,
        ),
        isFalse,
      );

      // Admin -> Always can cancel
      expect(
        PermissionGuard.canCancelOrder(
          role: MadarRole.admin,
          orderStatus: 'picked_up',
          isOwner: false,
        ),
        isTrue,
      );
    });

    test('4. PermissionGuard.canRequestRefund requires wallet payment and cancelled/failed status', () {
      expect(
        PermissionGuard.canRequestRefund(
          role: MadarRole.customer,
          paymentStatus: 'paid_wallet',
          orderStatus: 'cancelled',
        ),
        isTrue,
      );

      // Cash payment cannot request automated wallet refund
      expect(
        PermissionGuard.canRequestRefund(
          role: MadarRole.customer,
          paymentStatus: 'cash_on_delivery',
          orderStatus: 'cancelled',
        ),
        isFalse,
      );

      // Active completed order cannot request refund without dispute
      expect(
        PermissionGuard.canRequestRefund(
          role: MadarRole.customer,
          paymentStatus: 'paid_wallet',
          orderStatus: 'delivered',
        ),
        isFalse,
      );
    });

    test('5. FinancialOperationGuard validates amount numbers and rejects anomalies', () {
      final validPayload = FinancialOperationPayload(
        operationType: FinancialOperationType.orderPayment,
        amount: 15000,
        sourceUserId: 'usr_1',
        idempotencyKey: 'idemp_key_12345',
        timestamp: DateTime.now(),
      );
      expect(() => FinancialOperationGuard.validatePayload(validPayload), returnsNormally);

      // NaN amount
      final nanPayload = FinancialOperationPayload(
        operationType: FinancialOperationType.orderPayment,
        amount: double.nan,
        sourceUserId: 'usr_1',
        idempotencyKey: 'idemp_key_12345',
        timestamp: DateTime.now(),
      );
      expect(() => FinancialOperationGuard.validatePayload(nanPayload), throwsA(isA<SecurityViolationException>()));

      // Negative amount
      final negativePayload = FinancialOperationPayload(
        operationType: FinancialOperationType.orderPayment,
        amount: -500,
        sourceUserId: 'usr_1',
        idempotencyKey: 'idemp_key_12345',
        timestamp: DateTime.now(),
      );
      expect(() => FinancialOperationGuard.validatePayload(negativePayload), throwsA(isA<SecurityViolationException>()));

      // Excessively large amount exceeding 50,000,000 IQD limit
      final overflowPayload = FinancialOperationPayload(
        operationType: FinancialOperationType.orderPayment,
        amount: 99999999999.0,
        sourceUserId: 'usr_1',
        idempotencyKey: 'idemp_key_12345',
        timestamp: DateTime.now(),
      );
      expect(() => FinancialOperationGuard.validatePayload(overflowPayload), throwsA(isA<SecurityViolationException>()));

      // Short / empty idempotency key
      final shortKeyPayload = FinancialOperationPayload(
        operationType: FinancialOperationType.orderPayment,
        amount: 5000,
        sourceUserId: 'usr_1',
        idempotencyKey: '123',
        timestamp: DateTime.now(),
      );
      expect(() => FinancialOperationGuard.validatePayload(shortKeyPayload), throwsA(isA<SecurityViolationException>()));
    });

    test('6. TamperDetector detects client-side attempts to mutate balance and privileges', () {
      final maliciousPayload = {
        'name': 'Ali',
        'balance': 500000.0,
        'role': 'super_admin',
      };

      final violations = TamperDetector.detectUserPayloadTampering(
        maliciousPayload,
        actorRole: MadarRole.customer,
      );

      expect(violations, contains('balance'));
      expect(violations, contains('role'));
      expect(
        () => TamperDetector.assertUserPayloadSafe(maliciousPayload, actorRole: MadarRole.customer),
        throwsA(isA<SecurityViolationException>()),
      );

      // Admin payload should pass
      expect(
        () => TamperDetector.assertUserPayloadSafe(maliciousPayload, actorRole: MadarRole.admin),
        returnsNormally,
      );
    });

    test('7. SecurityEngine generates cryptographically strong idempotency keys', () {
      final engine = SecurityEngine();
      final key1 = engine.generateIdempotencyKey(prefix: 'ref');
      final key2 = engine.generateIdempotencyKey(prefix: 'ref');

      expect(key1, isNotEmpty);
      expect(key1.startsWith('ref-'), isTrue);
      expect(key1, isNot(equals(key2)));
      expect(key1.length, greaterThan(25));
    });

    test('8. SecurityEngine.submitOrderRefundRequest completes full pipeline with idempotency', () async {
      final mockRepo = MockSecurityRepository();
      final engine = SecurityEngine(repository: mockRepo);

      final refund = await engine.submitOrderRefundRequest(
        orderId: 'ord_999',
        orderSource: 'store',
        userId: 'usr_123',
        amount: 25000,
        points: 50,
        reason: 'إلغاء الطلب قبل التجهيز',
      );

      expect(refund.id, equals('ref_1'));
      expect(refund.orderId, equals('ord_999'));
      expect(refund.amount, equals(25000));
      expect(refund.points, equals(50));
      expect(mockRepo.refundRequests.length, equals(1));

      // Attempting to reuse the exact same idempotency key must throw exception
      expect(
        () => engine.submitOrderRefundRequest(
          orderId: 'ord_999',
          orderSource: 'store',
          userId: 'usr_123',
          amount: 25000,
          points: 50,
          reason: 'إلغاء الطلب مكرر',
          idempotencyKey: refund.idempotencyKey,
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('9. SecurityEngine logs security violations accurately', () async {
      final mockRepo = MockSecurityRepository();
      final engine = SecurityEngine(repository: mockRepo);

      await engine.logViolation(
        type: SecurityViolationType.unauthorizedFinancialMutation,
        userId: 'usr_attacker',
        actionAttempted: 'Direct balance increment attempted in client',
        reason: 'Field balance in update payload',
        severity: 'CRITICAL',
      );

      expect(mockRepo.loggedViolations.length, equals(1));
      final logged = mockRepo.loggedViolations.first;
      expect(logged.userId, equals('usr_attacker'));
      expect(logged.type, equals(SecurityViolationType.unauthorizedFinancialMutation));
      expect(logged.severity, equals('CRITICAL'));
    });

    test('10. SecurityEngine.guardPermission throws on unauthorized escalation', () {
      final engine = SecurityEngine();
      expect(
        () => engine.guardPermission(MadarRole.customer, MadarPermission.directFinancialMutation),
        throwsA(isA<SecurityViolationException>()),
      );
      expect(
        () => engine.guardPermission(MadarRole.admin, MadarPermission.directFinancialMutation),
        returnsNormally,
      );
    });
  });
}
