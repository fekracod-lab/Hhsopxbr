import '../entities/risk_signal.dart';
import '../enums/risk_enums.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/driver_location.dart';
import 'package:dalal_alqaim/core/realtime/domain/enums/realtime_enums.dart';

/// محرك رصد التلاعب بالموقع الجغرافي والـ GPS المزيف (Fake Location Risk Engine)
class FakeLocationRiskEngine {
  const FakeLocationRiskEngine();

  /// فحص مؤشرات الـ GPS القادمة من محرك الـ Realtime
  static RiskSignal? evaluateLocation(DriverLocation location, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    if (location.confidence == LocationConfidence.rejected) {
      return RiskSignal(
        signalId: 'sig-gps-rej-${location.driverId}-${currentTime.millisecondsSinceEpoch}',
        type: RiskSignalType.fakeLocationDetected,
        source: RiskSource.realtimeEngine,
        subjectId: location.driverId,
        severity: FraudCaseSeverity.high,
        confidence: 0.95,
        weight: 35,
        timestamp: currentTime,
        metadata: {
          'driverId': location.driverId,
          'latitude': location.latitude,
          'longitude': location.longitude,
          'accuracy': location.accuracy,
          'reason': 'GPS rejected due to invalid bounds or abnormal error',
        },
      );
    }

    if (location.confidence == LocationConfidence.suspicious) {
      return RiskSignal(
        signalId: 'sig-gps-sus-${location.driverId}-${currentTime.millisecondsSinceEpoch}',
        type: RiskSignalType.gpsTeleportation,
        source: RiskSource.realtimeEngine,
        subjectId: location.driverId,
        severity: FraudCaseSeverity.medium,
        confidence: 0.85,
        weight: 20,
        timestamp: currentTime,
        metadata: {
          'driverId': location.driverId,
          'speed': location.speed,
          'reason': 'Impossible velocity or sudden location jump detected',
        },
      );
    }

    return null;
  }
}
