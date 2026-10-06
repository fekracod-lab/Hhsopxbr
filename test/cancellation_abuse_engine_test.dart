import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/risk/domain/enums/risk_enums.dart';
import 'package:dalal_alqaim/core/risk/domain/services/cancellation_abuse_engine.dart';

void main() {
  group('Cancellation Abuse Engine Dedicated Tests', () {
    test('1. Normal sporadic cancellations do not trigger abuse signal', () {
      final engine = CancellationAbuseEngine();
      final sig = engine.recordCancellation(
        subjectId: 'cust_1',
        subjectType: RiskSubjectType.customer,
      );
      expect(sig, isNull);
    });

    test('2. Repeated cancellations exceeding 5 per hour trigger cancellationSpam signal', () {
      final engine = CancellationAbuseEngine();
      final now = DateTime.now();

      for (int i = 0; i < 5; i++) {
        final sig = engine.recordCancellation(
          subjectId: 'cust_spam',
          subjectType: RiskSubjectType.customer,
          maxCancellationsPerHour: 5,
          now: now.add(Duration(minutes: i * 5)),
        );
        expect(sig, isNull);
      }

      // 6th cancellation in 1 hour
      final sig6 = engine.recordCancellation(
        subjectId: 'cust_spam',
        subjectType: RiskSubjectType.customer,
        maxCancellationsPerHour: 5,
        now: now.add(const Duration(minutes: 30)),
      );

      expect(sig6, isNotNull);
      expect(sig6!.type, equals(RiskSignalType.cancellationSpam));
      expect(sig6.weight, equals(20));
    });
  });
}
