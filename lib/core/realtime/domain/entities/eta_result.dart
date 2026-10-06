import 'package:flutter/foundation.dart';

/// نتيجة احتساب الوقت المتوقع للوصول (ETA Estimation Result)
@immutable
class ETAResult {
  final int durationSeconds;
  final int distanceMeters;
  final double confidence; // 0.0 - 1.0
  final DateTime calculatedAt;
  final String source; // 'deterministic_model', 'traffic_engine', 'cached'

  const ETAResult({
    required this.durationSeconds,
    required this.distanceMeters,
    this.confidence = 1.0,
    required this.calculatedAt,
    this.source = 'deterministic_model',
  });

  /// مدة الوصول بالدقائق (تقريب لأقرب دقيقة مع حد أدنى دقيقة واحدة)
  int get durationMinutes => durationSeconds <= 0 ? 1 : ((durationSeconds + 30) ~/ 60);

  Map<String, dynamic> toMap() {
    return {
      'durationSeconds': durationSeconds,
      'distanceMeters': distanceMeters,
      'confidence': confidence,
      'calculatedAt': calculatedAt.toIso8601String(),
      'source': source,
    };
  }

  factory ETAResult.fromMap(Map<String, dynamic> map) {
    return ETAResult(
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      distanceMeters: (map['distanceMeters'] as num?)?.toInt() ?? 0,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
      calculatedAt: map['calculatedAt'] != null
          ? DateTime.tryParse(map['calculatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      source: map['source']?.toString() ?? 'deterministic_model',
    );
  }
}
