// مستودع مهام الطباعة المستدام في قاعدة البيانات المحلية (MADAR SHOP Persistent Print Job Repository)
// Pure Dart — Zero UI Dependencies — Integrates with S6 Printing Engine

import '../../../domain/printing/contracts/i_print_job_repository.dart';
import '../../../domain/printing/entities/print_job.dart';
import '../../../domain/printing/enums/print_document_type.dart';
import '../../../domain/printing/enums/print_job_status.dart';
import '../../../domain/printing/enums/print_trigger_type.dart';
import '../../../domain/sync/contracts/i_local_database.dart';

class PersistentPrintJobRepository implements IPrintJobRepository {
  static const String tableName = 'print_jobs';
  final ILocalDatabase _db;

  PersistentPrintJobRepository(this._db);

  @override
  Future<void> saveJob(PrintJob job) async {
    final existing = await getJobById(businessId: job.businessId, jobId: job.jobId);
    final row = {
      'jobId': job.jobId,
      'documentId': job.documentId,
      'documentType': job.documentType.name,
      'printerId': job.printerId,
      'businessId': job.businessId,
      'branchId': job.branchId,
      'status': job.status.name,
      'triggerType': job.triggerType.name,
      'createdAt': job.createdAt.toIso8601String(),
      'startedAt': job.startedAt?.toIso8601String(),
      'completedAt': job.completedAt?.toIso8601String(),
      'attemptCount': job.attemptCount,
      'maxAttempts': job.maxAttempts,
      'lastError': job.lastError,
      'idempotencyKey': job.idempotencyKey,
      'actorId': job.actorId,
      'reprintReason': job.reprintReason,
    };

    if (existing != null) {
      await _db.update(tableName, row, where: 'jobId = ?', whereArgs: [job.jobId]);
    } else {
      await _db.insert(tableName, row);
    }
  }

  @override
  Future<PrintJob?> getJobById({
    required String businessId,
    required String jobId,
  }) async {
    final row = await _db.findById(tableName, 'jobId', jobId);
    if (row == null || row['businessId'] != businessId) return null;
    return _mapToJob(row);
  }

  @override
  Future<List<PrintJob>> getJobsForDocument({
    required String businessId,
    required String documentId,
  }) async {
    final rows = await _db.query(
      tableName,
      where: 'businessId = ? AND documentId = ?',
      whereArgs: [businessId, documentId],
      orderBy: 'createdAt DESC',
    );
    return rows.map(_mapToJob).toList();
  }

  @override
  Future<List<PrintJob>> getJobs({
    required String businessId,
    String? branchId,
    String? printerId,
    PrintJobStatus? status,
    int limit = 50,
  }) async {
    var rows = await _db.query(
      tableName,
      where: 'businessId = ?',
      whereArgs: [businessId],
      orderBy: 'createdAt DESC',
      limit: limit,
    );

    var list = rows.map(_mapToJob).toList();
    if (branchId != null) {
      list = list.where((j) => j.branchId == branchId).toList();
    }
    if (printerId != null) {
      list = list.where((j) => j.printerId == printerId).toList();
    }
    if (status != null) {
      list = list.where((j) => j.status == status).toList();
    }

    return list;
  }

  PrintJob _mapToJob(Map<String, dynamic> row) {
    return PrintJob(
      jobId: row['jobId'] as String,
      documentId: row['documentId'] as String,
      documentType: row['documentType'] != null
          ? PrintDocumentType.values.byName(row['documentType'] as String)
          : PrintDocumentType.saleReceipt,
      printerId: row['printerId'] as String,
      businessId: row['businessId'] as String,
      branchId: row['branchId'] as String,
      status: PrintJobStatus.values.byName(row['status'] as String),
      triggerType: PrintTriggerType.values.byName(row['triggerType'] as String),
      createdAt: DateTime.parse(row['createdAt'] as String),
      startedAt: row['startedAt'] != null ? DateTime.parse(row['startedAt'] as String) : null,
      completedAt: row['completedAt'] != null ? DateTime.parse(row['completedAt'] as String) : null,
      attemptCount: (row['attemptCount'] as num?)?.toInt() ?? 0,
      maxAttempts: (row['maxAttempts'] as num?)?.toInt() ?? 3,
      lastError: row['lastError'] as String?,
      idempotencyKey: row['idempotencyKey'] as String? ?? 'idemp_${row['jobId']}',
      actorId: row['actorId'] as String? ?? 'system',
      reprintReason: row['reprintReason'] as String?,
    );
  }
}
