import 'package:flutter/foundation.dart';
import '../enums/resilience_enums.dart';

/// سجل وحالة قاطع الدائرة لخدمة أو تبعية معينة (Circuit Breaker Record)
@immutable
class CircuitBreakerRecord {
  final String serviceKey;
  final CircuitState state;
  final int failureCount;
  final int successCount;
  final int failureThreshold;
  final Duration recoveryTimeout;
  final DateTime lastStateChangedAt;
  final DateTime? lastFailureAt;

  const CircuitBreakerRecord({
    required this.serviceKey,
    this.state = CircuitState.closed,
    this.failureCount = 0,
    this.successCount = 0,
    this.failureThreshold = 5,
    this.recoveryTimeout = const Duration(seconds: 30),
    required this.lastStateChangedAt,
    this.lastFailureAt,
  });

  CircuitBreakerRecord copyWith({
    String? serviceKey,
    CircuitState? state,
    int? failureCount,
    int? successCount,
    int? failureThreshold,
    Duration? recoveryTimeout,
    DateTime? lastStateChangedAt,
    DateTime? lastFailureAt,
  }) {
    return CircuitBreakerRecord(
      serviceKey: serviceKey ?? this.serviceKey,
      state: state ?? this.state,
      failureCount: failureCount ?? this.failureCount,
      successCount: successCount ?? this.successCount,
      failureThreshold: failureThreshold ?? this.failureThreshold,
      recoveryTimeout: recoveryTimeout ?? this.recoveryTimeout,
      lastStateChangedAt: lastStateChangedAt ?? this.lastStateChangedAt,
      lastFailureAt: lastFailureAt ?? this.lastFailureAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serviceKey': serviceKey,
      'state': state.key,
      'failureCount': failureCount,
      'successCount': successCount,
      'failureThreshold': failureThreshold,
      'recoveryTimeoutMs': recoveryTimeout.inMilliseconds,
      'lastStateChangedAt': lastStateChangedAt.toIso8601String(),
      'lastFailureAt': lastFailureAt?.toIso8601String(),
    };
  }

  factory CircuitBreakerRecord.fromMap(Map<String, dynamic> map, String docId) {
    return CircuitBreakerRecord(
      serviceKey: docId,
      state: CircuitState.fromString(map['state']?.toString()),
      failureCount: (map['failureCount'] as num?)?.toInt() ?? 0,
      successCount: (map['successCount'] as num?)?.toInt() ?? 0,
      failureThreshold: (map['failureThreshold'] as num?)?.toInt() ?? 5,
      recoveryTimeout: Duration(milliseconds: (map['recoveryTimeoutMs'] as num?)?.toInt() ?? 30000),
      lastStateChangedAt: map['lastStateChangedAt'] != null
          ? DateTime.tryParse(map['lastStateChangedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastFailureAt: map['lastFailureAt'] != null
          ? DateTime.tryParse(map['lastFailureAt'].toString())
          : null,
    );
  }
}
