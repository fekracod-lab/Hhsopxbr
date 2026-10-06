// غلاف أمر المزامنة المحلي الموحد (MADAR SHOP Sync Command Envelope)
// Pure Dart — Zero UI Dependencies

import '../enums/sync_command_status.dart';

class SyncCommandEnvelope {
  final String commandId;
  final String commandType; // e.g. "CHECKOUT", "APPLY_INVENTORY", "CREATE_RETURN"
  final String entityType;  // e.g. "SALE", "INVENTORY", "RETURN", "FINANCIAL_ENTRY", "PRINT_JOB"
  final String entityId;

  final String businessId;
  final String branchId;
  final String terminalId;
  final String sessionId;

  final DateTime createdAt;
  final DateTime clientTimestamp;
  final int sequence; // رقم تسلسلي متصاعد خاص بالجهاز Monotonic sequence (e.g. 1001, 1002...)
  final String idempotencyKey;

  final Map<String, dynamic> payload;
  final int version;

  final SyncCommandStatus status;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final String? lastError;

  const SyncCommandEnvelope({
    required this.commandId,
    required this.commandType,
    required this.entityType,
    required this.entityId,
    required this.businessId,
    required this.branchId,
    required this.terminalId,
    required this.sessionId,
    required this.createdAt,
    required this.clientTimestamp,
    required this.sequence,
    required this.idempotencyKey,
    required this.payload,
    this.version = 1,
    this.status = SyncCommandStatus.queued,
    this.retryCount = 0,
    this.lastAttemptAt,
    this.lastError,
  });

  SyncCommandEnvelope copyWith({
    SyncCommandStatus? status,
    int? retryCount,
    DateTime? lastAttemptAt,
    String? lastError,
    int? version,
  }) {
    return SyncCommandEnvelope(
      commandId: commandId,
      commandType: commandType,
      entityType: entityType,
      entityId: entityId,
      businessId: businessId,
      branchId: branchId,
      terminalId: terminalId,
      sessionId: sessionId,
      createdAt: createdAt,
      clientTimestamp: clientTimestamp,
      sequence: sequence,
      idempotencyKey: idempotencyKey,
      payload: payload,
      version: version ?? this.version,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() => {
        'commandId': commandId,
        'commandType': commandType,
        'entityType': entityType,
        'entityId': entityId,
        'businessId': businessId,
        'branchId': branchId,
        'terminalId': terminalId,
        'sessionId': sessionId,
        'createdAt': createdAt.toIso8601String(),
        'clientTimestamp': clientTimestamp.toIso8601String(),
        'sequence': sequence,
        'idempotencyKey': idempotencyKey,
        'payload': payload,
        'version': version,
        'status': status.name,
        'retryCount': retryCount,
        'lastAttemptAt': lastAttemptAt?.toIso8601String(),
        'lastError': lastError,
      };

  factory SyncCommandEnvelope.fromJson(Map<String, dynamic> json) {
    return SyncCommandEnvelope(
      commandId: json['commandId'] as String,
      commandType: json['commandType'] as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      businessId: json['businessId'] as String,
      branchId: json['branchId'] as String,
      terminalId: json['terminalId'] as String,
      sessionId: json['sessionId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      clientTimestamp: DateTime.parse(json['clientTimestamp'] as String),
      sequence: (json['sequence'] as num).toInt(),
      idempotencyKey: json['idempotencyKey'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      version: (json['version'] as num?)?.toInt() ?? 1,
      status: SyncCommandStatus.values.byName(json['status'] as String),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.parse(json['lastAttemptAt'] as String)
          : null,
      lastError: json['lastError'] as String?,
    );
  }
}
