import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/observability/domain/enums/observability_enums.dart';
import 'package:dalal_alqaim/core/observability/domain/services/audit_trail_engine.dart';

void main() {
  group('Audit Trail Engine Dedicated Tests', () {
    test('1. Creates immutable audit record with valid SHA-256 integrity hash', () {
      final now = DateTime.now();

      final record = AuditTrailEngine.createAuditRecord(
        actorId: 'admin_1',
        actorRole: 'SuperAdmin',
        action: AuditActionType.blockDriver,
        targetEntityId: 'drv_suspicious_99',
        targetEntityType: 'Driver',
        reason: 'Repeated GPS teleportation signals exceeding risk score 85',
        riskScore: 88,
        traceId: 'trace_audit_100',
        beforeState: {'status': 'active', 'blocked': false},
        afterState: {'status': 'blocked', 'blocked': true},
        now: now,
      );

      expect(record.auditId.isNotEmpty, isTrue);
      expect(record.actorId, equals('admin_1'));
      expect(record.action, equals(AuditActionType.blockDriver));
      expect(record.riskScore, equals(88));
      expect(record.immutableHash.isNotEmpty, isTrue);
      expect(record.immutableHash.length, equals(64)); // SHA-256 64 hex characters
    });

    test('2. Two distinct audit entries produce distinct cryptographic hashes', () {
      final now = DateTime.now();

      final rec1 = AuditTrailEngine.createAuditRecord(
        actorId: 'admin_1',
        actorRole: 'Admin',
        action: AuditActionType.refundTransaction,
        targetEntityId: 'tx_101',
        targetEntityType: 'Transaction',
        reason: 'Customer dispute resolved',
        traceId: 'trace_1',
        now: now,
      );

      final rec2 = AuditTrailEngine.createAuditRecord(
        actorId: 'admin_2',
        actorRole: 'Admin',
        action: AuditActionType.forceCancelOrder,
        targetEntityId: 'ord_202',
        targetEntityType: 'Order',
        reason: 'Store closed unexpectedly',
        traceId: 'trace_2',
        now: now,
      );

      expect(rec1.immutableHash, isNot(equals(rec2.immutableHash)));
    });
  });
}
