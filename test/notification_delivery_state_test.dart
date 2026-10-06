import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/notifications/domain/enums/notification_enums.dart';
import 'package:dalal_alqaim/core/notifications/domain/services/notification_delivery_state_machine.dart';
import 'package:dalal_alqaim/core/notifications/domain/services/notification_retry_engine.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

void main() {
  group('Notification Delivery State Machine & Retry Engine Tests', () {
    test('1. Validates legal state transitions', () {
      expect(NotificationDeliveryStateMachine.canTransition(DeliveryStatus.pending, DeliveryStatus.queued), isTrue);
      expect(NotificationDeliveryStateMachine.canTransition(DeliveryStatus.queued, DeliveryStatus.sending), isTrue);
      expect(NotificationDeliveryStateMachine.canTransition(DeliveryStatus.sending, DeliveryStatus.delivered), isTrue);
      expect(NotificationDeliveryStateMachine.canTransition(DeliveryStatus.delivered, DeliveryStatus.read), isTrue);
      expect(NotificationDeliveryStateMachine.canTransition(DeliveryStatus.sending, DeliveryStatus.retrying), isTrue);
    });

    test('2. Rejects illegal state transitions with SecurityViolationException', () {
      expect(
        () => NotificationDeliveryStateMachine.assertValidTransition(
          DeliveryStatus.delivered,
          DeliveryStatus.pending, // Illegal reverse transition!
        ),
        throwsA(isA<SecurityViolationException>()),
      );

      expect(
        () => NotificationDeliveryStateMachine.assertValidTransition(
          DeliveryStatus.read,
          DeliveryStatus.sending, // Terminal state cannot transition
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('3. NotificationRetryEngine calculates exponential backoff and limits', () {
      expect(NotificationRetryEngine.canRetry(0, 3), isTrue);
      expect(NotificationRetryEngine.canRetry(2, 3), isTrue);
      expect(NotificationRetryEngine.canRetry(3, 3), isFalse);

      expect(NotificationRetryEngine.computeBackoff(retryCount: 0, baseBackoffSeconds: 10), equals(const Duration(seconds: 10)));
      expect(NotificationRetryEngine.computeBackoff(retryCount: 1, baseBackoffSeconds: 10), equals(const Duration(seconds: 20)));
      expect(NotificationRetryEngine.computeBackoff(retryCount: 2, baseBackoffSeconds: 10), equals(const Duration(seconds: 40)));
      expect(NotificationRetryEngine.computeBackoff(retryCount: 3, baseBackoffSeconds: 10), equals(const Duration(seconds: 80)));
    });
  });
}
