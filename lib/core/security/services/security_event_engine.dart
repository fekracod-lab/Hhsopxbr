import '../entities/security_event.dart';
import '../entities/threat_detection_result.dart';
import '../enums/security_enums.dart';
import '../../orchestration/domain/entities/domain_event.dart';
import '../../orchestration/domain/services/domain_event_bus.dart';

/// محرك رصد وتسجيل الأحداث والتهديدات الأمنية (Security Event & Threat Monitoring Engine)
class SecurityEventEngine {
  final List<SecurityEventRecord> _events = [];
  final DomainEventBus? eventBus;

  SecurityEventEngine({
    this.eventBus,
  });

  List<SecurityEventRecord> get events => List.unmodifiable(_events);

  /// تسجيل حدث أمني وبثه عبر DomainEventBus وربطه بـ Observability
  Future<SecurityEventRecord> recordSecurityEvent({
    required SecurityEventType eventType,
    required ThreatSeverity severity,
    required String actorUserId,
    required String description,
    String? resource,
    String? traceId,
    String? correlationId,
    Map<String, dynamic> metadata = const {},
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final eventId = 'sec_evt_${timestamp.millisecondsSinceEpoch}_${_events.length + 1}';

    final record = SecurityEventRecord(
      eventId: eventId,
      eventType: eventType,
      severity: severity,
      actorUserId: actorUserId,
      description: description,
      resource: resource,
      traceId: traceId,
      correlationId: correlationId,
      timestamp: timestamp,
      metadata: metadata,
    );

    _events.add(record);

    // نشر الحدث عبر ناقل الأحداث المركزي للربط مع التنبيهات ونظام الرصد (Observability & Incidents)
    if (eventBus != null && severity.requiresImmediateAlert) {
      await eventBus!.publish(
        DomainEvent(
          eventId: eventId,
          eventType: 'security.${eventType.key}',
          aggregateId: actorUserId.isNotEmpty ? actorUserId : eventId,
          aggregateType: 'security_event',
          transactionId: traceId ?? 'tr_$eventId',
          correlationId: correlationId ?? 'c_$eventId',
          occurredAt: timestamp,
          payload: record.toMap(),
        ),
      );
    }

    return record;
  }

  /// كشف الأنماط المشبوهة وتكرار المحاولات الفاشلة
  ThreatDetectionResult evaluateActorActivity({
    required String actorUserId,
    Duration window = const Duration(minutes: 10),
    int maxViolationsThreshold = 3,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final windowStart = currentTime.subtract(window);

    final recentViolations = _events.where((e) =>
        e.actorUserId == actorUserId &&
        !e.timestamp.isBefore(windowStart) &&
        (e.severity == ThreatSeverity.high || e.severity == ThreatSeverity.critical || e.eventType == SecurityEventType.permissionDenied || e.eventType == SecurityEventType.unauthorizedAccess)
    ).toList();

    if (recentViolations.length >= maxViolationsThreshold) {
      return ThreatDetectionResult.threat(
        eventType: SecurityEventType.suspiciousLogin,
        severity: ThreatSeverity.critical,
        subjectId: actorUserId,
        reason: 'Detected anomalous burst of ${recentViolations.length} high-severity security violations in window',
        block: true,
      );
    }

    return ThreatDetectionResult.safe();
  }

  void clear() => _events.clear();
}
