import 'package:flutter/foundation.dart';
import '../enums/resilience_enums.dart';

/// نموذج حقن الأعطال الخاضع للتحكم (Failure Injection Model - Dev/Test Only)
@immutable
class FailureInjection {
  final String injectionId;
  final FailureInjectionType type;
  final String targetService;
  final double probability; // 0.0 .. 1.0
  final int latencyMs;
  final bool enabled;
  final Map<String, dynamic> errorPayload;

  const FailureInjection({
    required this.injectionId,
    required this.type,
    required this.targetService,
    this.probability = 1.0,
    this.latencyMs = 0,
    this.enabled = true,
    this.errorPayload = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'injectionId': injectionId,
      'type': type.key,
      'targetService': targetService,
      'probability': probability,
      'latencyMs': latencyMs,
      'enabled': enabled,
      'errorPayload': errorPayload,
    };
  }

  factory FailureInjection.fromMap(Map<String, dynamic> map, String docId) {
    return FailureInjection(
      injectionId: docId,
      type: FailureInjectionType.fromString(map['type']?.toString()),
      targetService: map['targetService']?.toString() ?? '',
      probability: (map['probability'] as num?)?.toDouble() ?? 1.0,
      latencyMs: (map['latencyMs'] as num?)?.toInt() ?? 0,
      enabled: map['enabled'] == true,
      errorPayload: map['errorPayload'] is Map ? Map<String, dynamic>.from(map['errorPayload'] as Map) : {},
    );
  }
}
