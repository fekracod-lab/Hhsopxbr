import 'package:flutter/foundation.dart';

/// سياق المعاملة الموحد وغير القابل للتعديل (Transaction Context)
@immutable
class TransactionContext {
  final String transactionId;
  final String operationId;
  final String idempotencyKey;
  final String actorId;
  final String actorRole;
  final String serviceType; // 'food', 'store', 'mersal', 'taxi'
  final String orderId;
  final String? rideId;
  final String requestHash;
  final String correlationId;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const TransactionContext({
    required this.transactionId,
    required this.operationId,
    required this.idempotencyKey,
    required this.actorId,
    required this.actorRole,
    required this.serviceType,
    required this.orderId,
    this.rideId,
    required this.requestHash,
    required this.correlationId,
    required this.createdAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'operationId': operationId,
      'idempotencyKey': idempotencyKey,
      'actorId': actorId,
      'actorRole': actorRole,
      'serviceType': serviceType,
      'orderId': orderId,
      'rideId': rideId,
      'requestHash': requestHash,
      'correlationId': correlationId,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory TransactionContext.fromMap(Map<String, dynamic> map, String docId) {
    return TransactionContext(
      transactionId: docId,
      operationId: map['operationId']?.toString() ?? '',
      idempotencyKey: map['idempotencyKey']?.toString() ?? '',
      actorId: map['actorId']?.toString() ?? '',
      actorRole: map['actorRole']?.toString() ?? 'customer',
      serviceType: map['serviceType']?.toString() ?? 'food',
      orderId: map['orderId']?.toString() ?? '',
      rideId: map['rideId']?.toString(),
      requestHash: map['requestHash']?.toString() ?? '',
      correlationId: map['correlationId']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      metadata: map['metadata'] is Map ? Map<String, dynamic>.from(map['metadata'] as Map) : {},
    );
  }
}
