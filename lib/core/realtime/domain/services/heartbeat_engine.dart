import '../entities/heartbeat_record.dart';
import '../enums/realtime_enums.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

/// محرك فحص ومعالجة نبضات الاتصال للسائقين (Heartbeat Engine)
class HeartbeatEngine {
  final Set<String> _processedHeartbeatIds = {};
  final Map<String, int> _driverLastSequence = {};

  HeartbeatEngine();

  /// أقصى انحراف مسموح به للتوقيت المستقبلي (30 ثانية)
  static const Duration maxFutureDrift = Duration(seconds: 30);

  /// أقصى عمر لنبض الاتصال قبل اعتباره قديماً (5 دقائق)
  static const Duration maxStaleAge = Duration(minutes: 5);

  /// معالجة وتدقيق نبضة الاتصال
  HeartbeatRecord processHeartbeat({
    required String heartbeatId,
    required String driverId,
    required String sessionId,
    required DateTime clientTimestamp,
    required int sequenceNumber,
    DateTime? serverTimestampOverride,
  }) {
    final serverTimestamp = serverTimestampOverride ?? DateTime.now();

    // 1. كشف التكرار (Duplicate Heartbeat Detection)
    if (_processedHeartbeatIds.contains(heartbeatId)) {
      return HeartbeatRecord(
        heartbeatId: heartbeatId,
        driverId: driverId,
        sessionId: sessionId,
        status: HeartbeatStatus.rejected,
        clientTimestamp: clientTimestamp,
        serverTimestamp: serverTimestamp,
        sequenceNumber: sequenceNumber,
      );
    }
    _processedHeartbeatIds.add(heartbeatId);

    // 2. فحص التوقيت المستقبلي المزيف (Future Drift Abuse)
    if (clientTimestamp.isAfter(serverTimestamp.add(maxFutureDrift))) {
      throw const SecurityViolationException(
        'تم رصد توقيت مستقبلي غير صالح في نبض الاتصال',
        type: SecurityViolationType.tamperedPayload,
        fieldName: 'clientTimestamp',
      );
    }

    // 3. فحص الترتيب والتسلسل (Sequence Replay Detection)
    final lastSeq = _driverLastSequence[driverId] ?? -1;
    if (sequenceNumber <= lastSeq && lastSeq != -1) {
      // نبضة متأخرة أو مكررة التسلسل
      return HeartbeatRecord(
        heartbeatId: heartbeatId,
        driverId: driverId,
        sessionId: sessionId,
        status: HeartbeatStatus.delayed,
        clientTimestamp: clientTimestamp,
        serverTimestamp: serverTimestamp,
        sequenceNumber: sequenceNumber,
      );
    }
    _driverLastSequence[driverId] = sequenceNumber;

    // 4. فحص عمر النبضة
    final age = serverTimestamp.difference(clientTimestamp).abs();
    HeartbeatStatus status = HeartbeatStatus.healthy;
    if (age > const Duration(seconds: 45)) {
      status = HeartbeatStatus.delayed;
    }
    if (age > maxStaleAge) {
      status = HeartbeatStatus.stale;
    }

    return HeartbeatRecord(
      heartbeatId: heartbeatId,
      driverId: driverId,
      sessionId: sessionId,
      status: status,
      clientTimestamp: clientTimestamp,
      serverTimestamp: serverTimestamp,
      sequenceNumber: sequenceNumber,
    );
  }

  void clear() {
    _processedHeartbeatIds.clear();
    _driverLastSequence.clear();
  }
}
