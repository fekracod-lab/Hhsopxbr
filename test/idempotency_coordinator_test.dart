import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/orchestration/domain/services/idempotency_coordinator.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

void main() {
  group('Idempotency Coordinator & Request Hash Tests', () {
    test('1. Computes deterministic request hash for same inputs', () {
      final hash1 = IdempotencyCoordinator.computeRequestHash(
        actorId: 'usr_1',
        serviceType: 'food',
        orderId: 'ord_1',
        amount: 15000,
      );

      final hash2 = IdempotencyCoordinator.computeRequestHash(
        actorId: 'usr_1',
        serviceType: 'food',
        orderId: 'ord_1',
        amount: 15000,
      );

      expect(hash1, equals(hash2));
    });

    test('2. Throws SecurityViolationException on tampered payload with same idempotency key', () {
      final coordinator = IdempotencyCoordinator();

      final originalHash = IdempotencyCoordinator.computeRequestHash(
        actorId: 'usr_1',
        serviceType: 'food',
        orderId: 'ord_1',
        amount: 15000,
      );

      final tamperedHash = IdempotencyCoordinator.computeRequestHash(
        actorId: 'usr_1',
        serviceType: 'food',
        orderId: 'ord_1',
        amount: 500, // Attacker altered amount!
      );

      // Register original
      expect(
        coordinator.checkAndRegister(idempotencyKey: 'key_100', requestHash: originalHash),
        isTrue,
      );

      // Attempt second request with same key but different tampered amount
      expect(
        () => coordinator.checkAndRegister(idempotencyKey: 'key_100', requestHash: tamperedHash),
        throwsA(isA<SecurityViolationException>()),
      );
    });
  });
}
