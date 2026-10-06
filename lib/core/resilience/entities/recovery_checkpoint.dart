import 'package:flutter/foundation.dart';

/// نقطة تفتيش وحفظ الحالة التشغيلية للتعافي من الانهيار (Recovery Checkpoint)
@immutable
class RecoveryCheckpoint {
  final String checkpointId;
  final String operationId;
  final String domainType;
  final String state;
  final int version;
  final int lastKnownServerVersion;
  final DateTime checkpointTimestamp;
  final String correlationId;
  final String integrityHash;
  final Map<String, dynamic> payload;

  const RecoveryCheckpoint({
    required this.checkpointId,
    required this.operationId,
    required this.domainType,
    required this.state,
    this.version = 1,
    this.lastKnownServerVersion = 1,
    required this.checkpointTimestamp,
    required this.correlationId,
    required this.integrityHash,
    this.payload = const {},
  });

  RecoveryCheckpoint copyWith({
    String? checkpointId,
    String? operationId,
    String? domainType,
    String? state,
    int? version,
    int? lastKnownServerVersion,
    DateTime? checkpointTimestamp,
    String? correlationId,
    String? integrityHash,
    Map<String, dynamic>? payload,
  }) {
    return RecoveryCheckpoint(
      checkpointId: checkpointId ?? this.checkpointId,
      operationId: operationId ?? this.operationId,
      domainType: domainType ?? this.domainType,
      state: state ?? this.state,
      version: version ?? this.version,
      lastKnownServerVersion: lastKnownServerVersion ?? this.lastKnownServerVersion,
      checkpointTimestamp: checkpointTimestamp ?? this.checkpointTimestamp,
      correlationId: correlationId ?? this.correlationId,
      integrityHash: integrityHash ?? this.integrityHash,
      payload: payload ?? this.payload,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'checkpointId': checkpointId,
      'operationId': operationId,
      'domainType': domainType,
      'state': state,
      'version': version,
      'lastKnownServerVersion': lastKnownServerVersion,
      'checkpointTimestamp': checkpointTimestamp.toIso8601String(),
      'correlationId': correlationId,
      'integrityHash': integrityHash,
      'payload': payload,
    };
  }

  factory RecoveryCheckpoint.fromMap(Map<String, dynamic> map, String docId) {
    return RecoveryCheckpoint(
      checkpointId: docId,
      operationId: map['operationId']?.toString() ?? '',
      domainType: map['domainType']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      version: (map['version'] as num?)?.toInt() ?? 1,
      lastKnownServerVersion: (map['lastKnownServerVersion'] as num?)?.toInt() ?? 1,
      checkpointTimestamp: map['checkpointTimestamp'] != null
          ? DateTime.tryParse(map['checkpointTimestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      correlationId: map['correlationId']?.toString() ?? '',
      integrityHash: map['integrityHash']?.toString() ?? '',
      payload: map['payload'] is Map ? Map<String, dynamic>.from(map['payload'] as Map) : {},
    );
  }
}
