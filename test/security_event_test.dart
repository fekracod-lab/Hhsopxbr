import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/security/security.dart';

void main() {
  group('Security Event & Threat Monitoring Engine Dedicated Tests', () {
    late SecurityEventEngine engine;

    setUp(() {
      engine = SecurityEventEngine();
    });

    test('1. Records security events and stores in event history', () async {
      final now = DateTime(2026, 8, 29, 12, 0, 0);
      final event = await engine.recordSecurityEvent(
        eventType: SecurityEventType.unauthorizedAccess,
        severity: ThreatSeverity.high,
        actorUserId: 'usr_attacker_99',
        description: 'Attempted to access /admin/users without credentials',
        now: now,
      );

      expect(engine.events.length, equals(1));
      expect(event.actorUserId, equals('usr_attacker_99'));
      expect(event.severity, equals(ThreatSeverity.high));
    });

    test('2. Detects anomalous burst of security violations for an actor', () async {
      final now = DateTime(2026, 8, 29, 12, 0, 0);

      // Record 3 high-severity violations within 2 minutes
      for (var i = 0; i < 3; i++) {
        await engine.recordSecurityEvent(
          eventType: SecurityEventType.permissionDenied,
          severity: ThreatSeverity.high,
          actorUserId: 'bad_actor',
          description: 'Permission violation #$i',
          now: now.add(Duration(seconds: i * 10)),
        );
      }

      final threat = engine.evaluateActorActivity(
        actorUserId: 'bad_actor',
        window: const Duration(minutes: 10),
        maxViolationsThreshold: 3,
        now: now.add(const Duration(minutes: 1)),
      );

      expect(threat.isThreatDetected, isTrue);
      expect(threat.shouldBlockRequest, isTrue);
      expect(threat.severity, equals(ThreatSeverity.critical));
    });
  });
}
