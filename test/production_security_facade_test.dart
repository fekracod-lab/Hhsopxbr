import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/security/security.dart';
import 'helpers/security_test_helper.dart';

void main() {
  group('Production Security Engine Master Facade Tests', () {
    late ProductionSecurityEngine facade;
    late InMemorySecurityRepository repository;

    setUp(() {
      repository = InMemorySecurityRepository();
      facade = ProductionSecurityEngine(repository: repository);
    });

    test('1. Facade authorizes valid request and coordinates zero-trust evaluation', () {
      const context = AuthorizationContext(
        subjectUserId: 'user_1',
        role: MadarRole.customer,
        action: 'orders.read',
        resourceType: 'orders',
        resourceOwnerId: 'user_1',
      );

      final allowed = facade.authorizeRequest(context);
      expect(allowed, isTrue);
    });

    test('2. Facade logs security violations to repository and in-memory event stream', () async {
      await facade.logSecurityViolation(
        eventType: SecurityEventType.unauthorizedAccess,
        severity: ThreatSeverity.high,
        actorUserId: 'bad_actor',
        description: 'Failed access attempt to /system_security',
      );

      final recent = await repository.getRecentSecurityEvents();
      expect(recent.length, equals(1));
      expect(recent.first.actorUserId, equals('bad_actor'));
    });

    test('3. Facade executes and persists Production Security Readiness Gate Audit', () async {
      final scores = {for (var c in SecurityGateCategory.values) c: 100.0};
      final blockers = {for (var c in SecurityGateCategory.values) c: <String>[]};

      final result = await facade.runSecurityReadinessAudit(
        categoryScores: scores,
        categoryBlockers: blockers,
      );

      expect(result.gateStatus, equals(SecurityGateStatus.securityReady));

      final stored = await repository.getLatestReadinessAudit();
      expect(stored, isNotNull);
      expect(stored!.overallSecurityScore, equals(100.0));
    });
  });
}
