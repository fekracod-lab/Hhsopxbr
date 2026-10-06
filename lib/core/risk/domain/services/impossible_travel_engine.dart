import '../entities/risk_signal.dart';
import '../enums/risk_enums.dart';
import 'package:dalal_alqaim/core/dispatch/domain/services/dispatch_distance_engine.dart';

/// محرك كشف السفر والتنقل المستحيل فيزيائياً (Impossible Travel Engine)
class ImpossibleTravelEngine {
  const ImpossibleTravelEngine();

  /// أقصى سرعة طيران تجاري معقولة (250 م/ث = 900 كم/ساعة)
  static const double maxPlausibleVelocityMps = 250.0;

  /// فحص هل الحركة بين موقعين مستحيلة فيزيائياً
  static RiskSignal? evaluateTravel({
    required String subjectId,
    required double lat1,
    required double lon1,
    required DateTime time1,
    required double lat2,
    required double lon2,
    required DateTime time2,
    DateTime? now,
  }) {
    final distanceMeters = DispatchDistanceEngine.computeDistanceMeters(
      lat1: lat1,
      lon1: lon1,
      lat2: lat2,
      lon2: lon2,
    );

    if (distanceMeters.isNaN || distanceMeters.isInfinite || distanceMeters <= 0) {
      return null;
    }

    final timeDiffSeconds = time2.difference(time1).inSeconds.abs();
    if (timeDiffSeconds == 0) {
      if (distanceMeters > 500.0) {
        // قطع 500 متر في 0 ثانية -> قفزة مستحيلة
        return RiskSignal(
          signalId: 'sig-travel-$subjectId-${(now ?? DateTime.now()).millisecondsSinceEpoch}',
          type: RiskSignalType.impossibleTravel,
          source: RiskSource.securityEngine,
          subjectId: subjectId,
          severity: FraudCaseSeverity.critical,
          confidence: 0.99,
          weight: 40,
          timestamp: now ?? DateTime.now(),
          metadata: {
            'distanceMeters': distanceMeters,
            'timeDiffSeconds': 0,
            'reason': 'Zero-second displacement of > 500m',
          },
        );
      }
      return null;
    }

    final velocityMps = distanceMeters / timeDiffSeconds;
    if (velocityMps > maxPlausibleVelocityMps) {
      return RiskSignal(
        signalId: 'sig-travel-$subjectId-${(now ?? DateTime.now()).millisecondsSinceEpoch}',
        type: RiskSignalType.impossibleTravel,
        source: RiskSource.securityEngine,
        subjectId: subjectId,
        severity: FraudCaseSeverity.high,
        confidence: 0.95,
        weight: 35,
        timestamp: now ?? DateTime.now(),
        metadata: {
          'distanceKm': (distanceMeters / 1000).round(),
          'timeDiffMinutes': (timeDiffSeconds / 60).round(),
          'velocityKmPerHour': (velocityMps * 3.6).round(),
          'reason': 'Velocity exceeds commercial flight speeds',
        },
      );
    }

    return null;
  }
}
