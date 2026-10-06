import 'package:flutter/foundation.dart';
import '../enums/resilience_enums.dart';

/// عنصر طابور العمليات غير المتصلة الدائم (Durable Offline Queue Item)
@immutable
class OfflineQueueItem {
  final String queueId;
  final String idempotencyKey;
  final String operationType;
  final Map<String, dynamic> payload;
  final int priority; // 10 = High (Financial/Payment), 5 = Normal (Orders/Rides), 1 = Low
  final String traceId;
  final String correlationId;
  final int attemptCount;
  final int maxAttempts;
  final DateTime nextRetryAt;
  final QueueItemStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastError;

  const OfflineQueueItem({
    required this.queueId,
    required this.idempotencyKey,
    required this.operationType,
    required this.payload,
    this.priority = 5,
    required this.traceId,
    required this.correlationId,
    this.attemptCount = 0,
    this.maxAttempts = 5,
    required this.nextRetryAt,
    this.status = QueueItemStatus.pending,
    required this.createdAt,
    required this.updatedAt,
    this.lastError,
  });

  OfflineQueueItem copyWith({
    String? queueId,
    String? idempotencyKey,
    String? operationType,
    Map<String, dynamic>? payload,
    int? priority,
    String? traceId,
    String? correlationId,
    int? attemptCount,
    int? maxAttempts,
    DateTime? nextRetryAt,
    QueueItemStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastError,
  }) {
    return OfflineQueueItem(
      queueId: queueId ?? this.queueId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      operationType: operationType ?? this.operationType,
      payload: payload ?? this.payload,
      priority: priority ?? this.priority,
      traceId: traceId ?? this.traceId,
      correlationId: correlationId ?? this.correlationId,
      attemptCount: attemptCount ?? this.attemptCount,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'queueId': queueId,
      'idempotencyKey': idempotencyKey,
      'operationType': operationType,
      'payload': payload,
      'priority': priority,
      'traceId': traceId,
      'correlationId': correlationId,
      'attemptCount': attemptCount,
      'maxAttempts': maxAttempts,
      'nextRetryAt': nextRetryAt.toIso8601String(),
      'status': status.key,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastError': lastError,
    };
  }

  factory OfflineQueueItem.fromMap(Map<String, dynamic> map, String docId) {
    return OfflineQueueItem(
      queueId: docId,
      idempotencyKey: map['idempotencyKey']?.toString() ?? '',
      operationType: map['operationType']?.toString() ?? '',
      payload: map['payload'] is Map ? Map<String, dynamic>.from(map['payload'] as Map) : {},
      priority: (map['priority'] as num?)?.toInt() ?? 5,
      traceId: map['traceId']?.toString() ?? '',
      correlationId: map['correlationId']?.toString() ?? '',
      attemptCount: (map['attemptCount'] as num?)?.toInt() ?? 0,
      maxAttempts: (map['maxAttempts'] as num?)?.toInt() ?? 5,
      nextRetryAt: map['nextRetryAt'] != null
          ? DateTime.tryParse(map['nextRetryAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: QueueItemStatus.fromString(map['status']?.toString()),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastError: map['lastError']?.toString(),
    );
  }
}
