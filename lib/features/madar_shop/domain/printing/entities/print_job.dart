// كيان مهمة الطباعة في قائمة الانتظار (MADAR SHOP Print Job Entity)
// Pure Dart — Zero UI Dependencies

import '../enums/print_document_type.dart';
import '../enums/print_job_status.dart';
import '../enums/print_trigger_type.dart';

class PrintJob {
  final String jobId;
  final String documentId;
  final PrintDocumentType documentType;
  final String businessId;
  final String branchId;
  final String printerId;
  final PrintJobStatus status;
  final PrintTriggerType triggerType;
  final String actorId;
  final int copies;
  final String? paperProfile;
  final String? reprintReason;
  final int attemptCount;
  final int maxAttempts;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? lastError;
  final String idempotencyKey;
  final Map<String, dynamic> metadata;

  PrintJob({
    String? id,
    String? jobId,
    required this.documentId,
    dynamic documentType,
    required this.businessId,
    required this.branchId,
    required this.printerId,
    this.status = PrintJobStatus.queued,
    this.triggerType = PrintTriggerType.autoPrint,
    String? actorId,
    this.copies = 1,
    this.paperProfile,
    this.reprintReason,
    this.attemptCount = 0,
    this.maxAttempts = 3,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.lastError,
    required this.idempotencyKey,
    this.metadata = const {},
  })  : jobId = jobId ?? id ?? 'JOB-${DateTime.now().millisecondsSinceEpoch}',
        actorId = actorId ?? 'SYSTEM',
        documentType = documentType is PrintDocumentType
            ? documentType
            : (documentType is String
                ? PrintDocumentType.values.firstWhere(
                    (e) => e.name == documentType,
                    orElse: () => PrintDocumentType.saleReceipt,
                  )
                : PrintDocumentType.saleReceipt);

  String get id => jobId;
  bool get isTerminal => status.isTerminal;
  bool get canRetry => attemptCount < maxAttempts && !isTerminal;

  PrintJob transitionTo(
    PrintJobStatus nextStatus, {
    DateTime? startedAt,
    DateTime? completedAt,
    int? attemptCount,
    String? error,
  }) {
    return copyWith(
      status: nextStatus,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: error ?? lastError,
    );
  }

  PrintJob markStarted() {
    return copyWith(
      status: PrintJobStatus.printing,
      startedAt: DateTime.now(),
      attemptCount: attemptCount + 1,
    );
  }

  PrintJob markCompleted() {
    return copyWith(
      status: PrintJobStatus.completed,
      completedAt: DateTime.now(),
    );
  }

  PrintJob markFailed(String error) {
    return copyWith(
      status: PrintJobStatus.failed,
      completedAt: DateTime.now(),
      lastError: error,
    );
  }

  PrintJob markCancelled(String reason) {
    return copyWith(
      status: PrintJobStatus.cancelled,
      completedAt: DateTime.now(),
      lastError: 'Cancelled: $reason',
    );
  }

  PrintJob markUnknownRequiresConfirmation(String error) {
    return copyWith(
      status: PrintJobStatus.unknownRequiresConfirmation,
      lastError: error,
    );
  }

  PrintJob copyWith({
    PrintJobStatus? status,
    int? copies,
    String? paperProfile,
    int? attemptCount,
    int? maxAttempts,
    DateTime? startedAt,
    DateTime? completedAt,
    String? lastError,
    String? reprintReason,
    Map<String, dynamic>? metadata,
  }) {
    return PrintJob(
      jobId: jobId,
      documentId: documentId,
      documentType: documentType,
      businessId: businessId,
      branchId: branchId,
      printerId: printerId,
      status: status ?? this.status,
      triggerType: triggerType,
      actorId: actorId,
      copies: copies ?? this.copies,
      paperProfile: paperProfile ?? this.paperProfile,
      reprintReason: reprintReason ?? this.reprintReason,
      attemptCount: attemptCount ?? this.attemptCount,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      lastError: lastError ?? this.lastError,
      idempotencyKey: idempotencyKey,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrintJob &&
          runtimeType == other.runtimeType &&
          jobId == other.jobId &&
          businessId == other.businessId;

  @override
  int get hashCode => jobId.hashCode ^ businessId.hashCode;

  @override
  String toString() =>
      'PrintJob(id: $jobId, doc: $documentId, status: $status, attempts: $attemptCount/$maxAttempts)';
}
