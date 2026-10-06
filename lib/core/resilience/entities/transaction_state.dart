import 'package:flutter/foundation.dart';

/// حالة المعاملة الصريحة ومسار تقدمها (Explicit Transaction State Entity)
@immutable
class TransactionState {
  final String transactionId;
  final String domainType;
  final String currentState;
  final String? previousState;
  final int version;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  const TransactionState({
    required this.transactionId,
    required this.domainType,
    required this.currentState,
    this.previousState,
    this.version = 1,
    required this.updatedAt,
    this.metadata = const {},
  });

  TransactionState copyWith({
    String? transactionId,
    String? domainType,
    String? currentState,
    String? previousState,
    int? version,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return TransactionState(
      transactionId: transactionId ?? this.transactionId,
      domainType: domainType ?? this.domainType,
      currentState: currentState ?? this.currentState,
      previousState: previousState ?? this.previousState,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'domainType': domainType,
      'currentState': currentState,
      'previousState': previousState,
      'version': version,
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory TransactionState.fromMap(Map<String, dynamic> map, String docId) {
    return TransactionState(
      transactionId: docId,
      domainType: map['domainType']?.toString() ?? '',
      currentState: map['currentState']?.toString() ?? '',
      previousState: map['previousState']?.toString(),
      version: (map['version'] as num?)?.toInt() ?? 1,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      metadata: map['metadata'] is Map ? Map<String, dynamic>.from(map['metadata'] as Map) : {},
    );
  }
}
