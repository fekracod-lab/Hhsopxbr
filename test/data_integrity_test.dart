import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/resilience/services/data_integrity_engine.dart';
import 'package:dalal_alqaim/core/resilience/enums/resilience_enums.dart';

void main() {
  group('Data Integrity Engine Dedicated Tests', () {
    const engine = DataIntegrityEngine();

    test('1. Audits wallet balances and flags negative balance violations', () {
      final balances = {
        'wallet_valid': 15000,
        'wallet_empty': 0,
        'wallet_corrupted': -3500,
      };

      final violations = engine.auditWalletBalances(balances);
      expect(violations.length, equals(1));
      expect(violations.first.type, equals(IntegrityViolationType.negativeBalance));
      expect(violations.first.entityId, equals('wallet_corrupted'));
    });

    test('2. Detects orphan child records missing valid parent entities', () {
      final childOrderIds = ['ord_1', 'ord_2', 'ord_orphan_99'];
      final parentStoreIds = ['ord_1', 'ord_2'];

      final violations = engine.auditOrphanRecords(
        childEntityIds: childOrderIds,
        parentEntityIds: parentStoreIds,
        childType: 'OrderItem',
        parentType: 'Order',
      );

      expect(violations.length, equals(1));
      expect(violations.first.type, equals(IntegrityViolationType.orphanRecord));
      expect(violations.first.entityId, equals('ord_orphan_99'));
    });

    test('3. Detects tampered evidence or broken SHA-256 hashes', () {
      final records = [
        ('rec_1', 'Valid Payload Data', '3e3d93ec72d9f7a26955e69e208b0676b5c922579dfd9e26ff03b5b6cb2b6e51'), // invalid hash
      ];

      final violations = engine.auditTamperProofHashes(
        records: records,
        recordType: 'AuditLog',
      );

      expect(violations.length, equals(1));
      expect(violations.first.type, equals(IntegrityViolationType.brokenAuditHash));
      expect(violations.first.entityId, equals('rec_1'));
    });

    test('4. Detects mismatched order calculation totals', () {
      final violations = engine.auditOrderTotals(
        orderId: 'ord_bad_math',
        subtotalMinor: 10000,
        deliveryFeeMinor: 2000,
        discountMinor: 1000,
        finalTotalMinor: 15000, // Should be 11000!
      );

      expect(violations.length, equals(1));
      expect(violations.first.type, equals(IntegrityViolationType.mismatchedTotal));
      expect(violations.first.details, contains('11000'));
    });
  });
}
