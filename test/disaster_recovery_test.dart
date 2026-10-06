import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/resilience/services/disaster_recovery_engine.dart';

void main() {
  group('Disaster Recovery (DR) & RPO/RTO Policies Dedicated Tests', () {
    final engine = DisasterRecoveryEngine();

    test('1. Validates strict RPO and RTO domain policies', () {
      final paymentPolicy = engine.getPolicyForDomain('payments');
      final ridePolicy = engine.getPolicyForDomain('rides');
      final analyticsPolicy = engine.getPolicyForDomain('analytics');

      expect(paymentPolicy.$1, equals(0));  // RPO near-zero for financial payments
      expect(paymentPolicy.$2, equals(10)); // RTO = 10s

      expect(ridePolicy.$1, equals(5));     // RPO = 5s
      expect(ridePolicy.$2, equals(30));    // RTO = 30s

      expect(analyticsPolicy.$1, equals(300)); // RPO = 300s
      expect(analyticsPolicy.$2, equals(600)); // RTO = 600s
    });

    test('2. Creates and verifies Disaster Recovery snapshot with SHA-256 checksum', () {
      final now = DateTime(2026, 8, 29, 12, 0, 0);
      final records = [
        {'txId': 'tx_1', 'amount': 15000, 'status': 'completed'},
        {'txId': 'tx_2', 'amount': 8000, 'status': 'completed'},
      ];

      final snapshot = engine.createSnapshot(
        domain: 'payments',
        records: records,
        now: now,
      );

      expect(snapshot.domain, equals('payments'));
      expect(snapshot.recordsCount, equals(2));
      expect(snapshot.integrityChecksum.length, equals(64));

      // Verify integrity with identical records -> True
      expect(engine.verifySnapshotIntegrity(snapshot: snapshot, records: records), isTrue);

      // Verify with altered records -> False (Tampering detected!)
      final altered = [
        {'txId': 'tx_1', 'amount': 99999, 'status': 'completed'},
      ];
      expect(engine.verifySnapshotIntegrity(snapshot: snapshot, records: altered), isFalse);
    });
  });
}
