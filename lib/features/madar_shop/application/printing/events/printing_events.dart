// أحداث وسجلات تدقيق محرك الطباعة (MADAR SHOP Printing Events & Observability)
// Pure Dart — Zero UI Dependencies

/// النوع الأساسي لجميع أحداث الطباعة
abstract class PrintingEvent {
  final String eventName;
  final String businessId;
  final String branchId;
  final DateTime timestamp;

  const PrintingEvent({
    required this.eventName,
    required this.businessId,
    required this.branchId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap();
}

class PrintQueuedEvent extends PrintingEvent {
  final String jobId;
  final String documentId;
  final String documentType;
  final String printerId;
  final String triggerType;
  final int copies;

  const PrintQueuedEvent({
    required super.businessId,
    required super.branchId,
    required super.timestamp,
    required this.jobId,
    required this.documentId,
    required this.documentType,
    required this.printerId,
    required this.triggerType,
    required this.copies,
  }) : super(eventName: 'print_queued');

  @override
  Map<String, dynamic> toMap() => {
        'event': eventName,
        'businessId': businessId,
        'branchId': branchId,
        'jobId': jobId,
        'documentId': documentId,
        'documentType': documentType,
        'printerId': printerId,
        'triggerType': triggerType,
        'copies': copies,
        'timestamp': timestamp.toIso8601String(),
      };
}

class PrintStartedEvent extends PrintingEvent {
  final String jobId;
  final String documentId;
  final String printerId;
  final int attemptNumber;

  const PrintStartedEvent({
    required super.businessId,
    required super.branchId,
    required super.timestamp,
    required this.jobId,
    required this.documentId,
    required this.printerId,
    required this.attemptNumber,
  }) : super(eventName: 'print_started');

  @override
  Map<String, dynamic> toMap() => {
        'event': eventName,
        'businessId': businessId,
        'branchId': branchId,
        'jobId': jobId,
        'documentId': documentId,
        'printerId': printerId,
        'attemptNumber': attemptNumber,
        'timestamp': timestamp.toIso8601String(),
      };
}

class PrintCompletedEvent extends PrintingEvent {
  final String jobId;
  final String documentId;
  final String printerId;
  final Duration duration;

  const PrintCompletedEvent({
    required super.businessId,
    required super.branchId,
    required super.timestamp,
    required this.jobId,
    required this.documentId,
    required this.printerId,
    required this.duration,
  }) : super(eventName: 'print_completed');

  @override
  Map<String, dynamic> toMap() => {
        'event': eventName,
        'businessId': businessId,
        'branchId': branchId,
        'jobId': jobId,
        'documentId': documentId,
        'printerId': printerId,
        'durationMs': duration.inMilliseconds,
        'timestamp': timestamp.toIso8601String(),
      };
}

class PrintFailedEvent extends PrintingEvent {
  final String jobId;
  final String documentId;
  final String printerId;
  final String errorMessage;
  final int attemptsMade;

  const PrintFailedEvent({
    required super.businessId,
    required super.branchId,
    required super.timestamp,
    required this.jobId,
    required this.documentId,
    required this.printerId,
    required this.errorMessage,
    required this.attemptsMade,
  }) : super(eventName: 'print_failed');

  @override
  Map<String, dynamic> toMap() => {
        'event': eventName,
        'businessId': businessId,
        'branchId': branchId,
        'jobId': jobId,
        'documentId': documentId,
        'printerId': printerId,
        'errorMessage': errorMessage,
        'attemptsMade': attemptsMade,
        'timestamp': timestamp.toIso8601String(),
      };
}

class UnknownPrintStateEvent extends PrintingEvent {
  final String jobId;
  final String documentId;
  final String printerId;
  final String reason;

  const UnknownPrintStateEvent({
    required super.businessId,
    required super.branchId,
    required super.timestamp,
    required this.jobId,
    required this.documentId,
    required this.printerId,
    required this.reason,
  }) : super(eventName: 'unknown_print_state');

  @override
  Map<String, dynamic> toMap() => {
        'event': eventName,
        'businessId': businessId,
        'branchId': branchId,
        'jobId': jobId,
        'documentId': documentId,
        'printerId': printerId,
        'reason': reason,
        'timestamp': timestamp.toIso8601String(),
      };
}

class ReprintRequestedEvent extends PrintingEvent {
  final String jobId;
  final String documentId;
  final String requestedBy;
  final String reason;
  final int copies;

  const ReprintRequestedEvent({
    required super.businessId,
    required super.branchId,
    required super.timestamp,
    required this.jobId,
    required this.documentId,
    required this.requestedBy,
    required this.reason,
    required this.copies,
  }) : super(eventName: 'reprint_requested');

  @override
  Map<String, dynamic> toMap() => {
        'event': eventName,
        'businessId': businessId,
        'branchId': branchId,
        'jobId': jobId,
        'documentId': documentId,
        'requestedBy': requestedBy,
        'reason': reason,
        'copies': copies,
        'timestamp': timestamp.toIso8601String(),
      };
}

class PrinterDiscoveredEvent extends PrintingEvent {
  final String printerId;
  final String printerName;
  final String connectionType;

  const PrinterDiscoveredEvent({
    required super.businessId,
    required super.branchId,
    required super.timestamp,
    required this.printerId,
    required this.printerName,
    required this.connectionType,
  }) : super(eventName: 'printer_discovered');

  @override
  Map<String, dynamic> toMap() => {
        'event': eventName,
        'businessId': businessId,
        'branchId': branchId,
        'printerId': printerId,
        'printerName': printerName,
        'connectionType': connectionType,
        'timestamp': timestamp.toIso8601String(),
      };
}

class PrinterOfflineEvent extends PrintingEvent {
  final String printerId;
  final String reason;

  const PrinterOfflineEvent({
    required super.businessId,
    required super.branchId,
    required super.timestamp,
    required this.printerId,
    required this.reason,
  }) : super(eventName: 'printer_offline');

  @override
  Map<String, dynamic> toMap() => {
        'event': eventName,
        'businessId': businessId,
        'branchId': branchId,
        'printerId': printerId,
        'reason': reason,
        'timestamp': timestamp.toIso8601String(),
      };
}

class PrinterReconnectedEvent extends PrintingEvent {
  final String printerId;

  const PrinterReconnectedEvent({
    required super.businessId,
    required super.branchId,
    required super.timestamp,
    required this.printerId,
  }) : super(eventName: 'printer_reconnected');

  @override
  Map<String, dynamic> toMap() => {
        'event': eventName,
        'businessId': businessId,
        'branchId': branchId,
        'printerId': printerId,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// سجل تدقيق لعمليات الطباعة الأمنة (Audit Log Entry)
class PrintingAuditRecord {
  final String action;
  final String businessId;
  final String branchId;
  final String actor;
  final String documentId;
  final String? printerId;
  final String? jobId;
  final String? reason;
  final DateTime timestamp;
  final Map<String, dynamic> safeMetadata;

  const PrintingAuditRecord({
    required this.action,
    required this.businessId,
    required this.branchId,
    required this.actor,
    required this.documentId,
    this.printerId,
    this.jobId,
    this.reason,
    required this.timestamp,
    this.safeMetadata = const {},
  });

  Map<String, dynamic> toMap() => {
        'action': action,
        'businessId': businessId,
        'branchId': branchId,
        'actor': actor,
        'documentId': documentId,
        'printerId': printerId,
        'jobId': jobId,
        'reason': reason,
        'timestamp': timestamp.toIso8601String(),
        'metadata': safeMetadata,
      };
}
