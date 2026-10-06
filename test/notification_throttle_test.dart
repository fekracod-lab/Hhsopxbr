import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/notifications/domain/enums/notification_enums.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_policy.dart';
import 'package:dalal_alqaim/core/notifications/domain/services/notification_throttle_engine.dart';

void main() {
  group('Notification Throttle & Anti-Spam Engine Tests', () {
    test('1. Allows notifications within window capacity', () {
      final engine = NotificationThrottleEngine();
      const policy = NotificationPolicy(throttleWindowSeconds: 60, maxPerWindow: 3);

      final now = DateTime(2026, 8, 28, 12, 0, 0);

      expect(engine.shouldThrottle(userId: 'u1', priority: NotificationPriority.normal, policy: policy, now: now), isFalse);
      expect(engine.shouldThrottle(userId: 'u1', priority: NotificationPriority.normal, policy: policy, now: now.add(const Duration(seconds: 5))), isFalse);
      expect(engine.shouldThrottle(userId: 'u1', priority: NotificationPriority.normal, policy: policy, now: now.add(const Duration(seconds: 10))), isFalse);

      // 4th notification within 60s window exceeds maxPerWindow (3) -> Throttled!
      expect(engine.shouldThrottle(userId: 'u1', priority: NotificationPriority.normal, policy: policy, now: now.add(const Duration(seconds: 15))), isTrue);
    });

    test('2. NEVER throttles CRITICAL emergency/security notifications', () {
      final engine = NotificationThrottleEngine();
      const policy = NotificationPolicy(throttleWindowSeconds: 60, maxPerWindow: 1);

      final now = DateTime(2026, 8, 28, 12, 0, 0);

      // Normal gets throttled on 2nd attempt
      expect(engine.shouldThrottle(userId: 'u2', priority: NotificationPriority.normal, policy: policy, now: now), isFalse);
      expect(engine.shouldThrottle(userId: 'u2', priority: NotificationPriority.normal, policy: policy, now: now.add(const Duration(seconds: 2))), isTrue);

      // Critical (SOS / Security) bypasses throttle unconditionally!
      expect(engine.shouldThrottle(userId: 'u2', priority: NotificationPriority.critical, policy: policy, now: now.add(const Duration(seconds: 3))), isFalse);
    });

    test('3. Cleans up expired timestamps after window duration', () {
      final engine = NotificationThrottleEngine();
      const policy = NotificationPolicy(throttleWindowSeconds: 30, maxPerWindow: 1);

      final now = DateTime(2026, 8, 28, 12, 0, 0);

      expect(engine.shouldThrottle(userId: 'u3', priority: NotificationPriority.normal, policy: policy, now: now), isFalse);
      expect(engine.shouldThrottle(userId: 'u3', priority: NotificationPriority.normal, policy: policy, now: now.add(const Duration(seconds: 10))), isTrue);

      // 35 seconds later (> 30s window) -> Window reset, permitted!
      expect(engine.shouldThrottle(userId: 'u3', priority: NotificationPriority.normal, policy: policy, now: now.add(const Duration(seconds: 35))), isFalse);
    });
  });
}
