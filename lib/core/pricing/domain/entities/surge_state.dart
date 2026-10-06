import 'package:flutter/foundation.dart';
import '../enums/pricing_enums.dart';

/// حالة زيادة الطلب اللحظية (Dynamic Surge State)
@immutable
class SurgeState {
  final SurgeLevel level;
  final double multiplier;
  final String reason;
  final double supplyDemandRatio;
  final DateTime calculatedAt;

  const SurgeState({
    this.level = SurgeLevel.normal,
    this.multiplier = 1.0,
    required this.reason,
    this.supplyDemandRatio = 1.0,
    required this.calculatedAt,
  });

  bool get hasSurge => multiplier > 1.05;

  Map<String, dynamic> toMap() {
    return {
      'level': level.key,
      'multiplier': multiplier,
      'reason': reason,
      'supplyDemandRatio': supplyDemandRatio,
      'calculatedAt': calculatedAt.toIso8601String(),
    };
  }

  factory SurgeState.fromMap(Map<String, dynamic> map) {
    return SurgeState(
      level: SurgeLevel.values.firstWhere(
        (l) => l.key == map['level']?.toString(),
        orElse: () => SurgeLevel.normal,
      ),
      multiplier: (map['multiplier'] as num?)?.toDouble() ?? 1.0,
      reason: map['reason']?.toString() ?? 'تسعير قياسي',
      supplyDemandRatio: (map['supplyDemandRatio'] as num?)?.toDouble() ?? 1.0,
      calculatedAt: map['calculatedAt'] != null
          ? DateTime.tryParse(map['calculatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
