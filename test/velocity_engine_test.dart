import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/risk/domain/enums/risk_enums.dart';
import 'package:dalal_alqaim/core/risk/domain/services/velocity_engine.dart';

void main() {
  group('Velocity Engine Dedicated Tests', () {
    test('1. Tracks sliding window operations and triggers signal when limit exceeded', () {
      final engine = VelocityEngine();
      final now = DateTime(2026, 8, 28, 12, 0, 0);

      // 5 requests within limit (limit = 5)
      for (int i = 0; i < 5; i++) {
        final (rec, sig) = engine.recordAndEvaluate(
          subjectId: 'user_1',
          actionType: 'create_order',
          limit: 5,
          now: now.add(Duration(minutes: i * 2)),
        );
        expect(rec.exceeded, isFalse);
        expect(sig, isNull);
      }

      // 6th request exceeds limit!
      final (recExceeded, sigExceeded) = engine.recordAndEvaluate(
        subjectId: 'user_1',
        actionType: 'create_order',
        limit: 5,
        now: now.add(const Duration(minutes: 15)),
      );

      expect(recExceeded.exceeded, isTrue);
      expect(sigExceeded, isNotNull);
      expect(sigExceeded!.type, equals(RiskSignalType.velocityLimitExceeded));
      expect(sigExceeded.weight, equals(25));
    });

    test('2. Purges events older than sliding window', () {
      final engine = VelocityEngine();
      final t0 = DateTime(2026, 8, 28, 12, 0, 0);

      // 3 events at t0
      for (int i = 0; i < 3; i++) {
        engine.recordAndEvaluate(
          subjectId: 'user_2',
          actionType: 'login_attempt',
          window: VelocityWindow.oneHour,
          limit: 3,
          now: t0,
        );
      }

      // After 2 hours (past 1 hour window)
      final t2 = t0.add(const Duration(hours: 2));
      final (rec, sig) = engine.recordAndEvaluate(
        subjectId: 'user_2',
        actionType: 'login_attempt',
        window: VelocityWindow.oneHour,
        limit: 3,
        now: t2,
      );

      expect(rec.count, equals(1)); // Old events purged
      expect(rec.exceeded, isFalse);
      expect(sig, isNull);
    });
  });
}
