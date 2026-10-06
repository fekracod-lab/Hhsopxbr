import 'package:flutter/foundation.dart';

/// عينة مقياس تشغيلي نقطي (Metric Sample)
@immutable
class MetricSample {
  final String metricName;
  final double value;
  final String unit;
  final Map<String, String> dimensions;
  final DateTime timestamp;

  const MetricSample({
    required this.metricName,
    required this.value,
    this.unit = 'count',
    this.dimensions = const {},
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'metricName': metricName,
      'value': value,
      'unit': unit,
      'dimensions': dimensions,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory MetricSample.fromMap(Map<String, dynamic> map) {
    return MetricSample(
      metricName: map['metricName']?.toString() ?? '',
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit']?.toString() ?? 'count',
      dimensions: (map['dimensions'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {},
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
