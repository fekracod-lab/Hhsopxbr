// مستودع مهام الطباعة بالذاكرة (MADAR SHOP In-Memory Print Job Repository)
// Pure Dart — Zero UI Dependencies

import '../../../domain/printing/contracts/i_print_job_repository.dart';
import '../../../domain/printing/entities/print_job.dart';
import '../../../domain/printing/enums/print_job_status.dart';

class MemoryPrintJobRepository implements IPrintJobRepository {
  final Map<String, PrintJob> _storage = {};

  @override
  Future<void> saveJob(PrintJob job) async {
    _storage['${job.businessId}_${job.id}'] = job;
  }

  @override
  Future<PrintJob?> getJobById({
    required String businessId,
    required String jobId,
  }) async {
    return _storage['${businessId}_$jobId'];
  }

  @override
  Future<List<PrintJob>> getJobsForDocument({
    required String businessId,
    required String documentId,
  }) async {
    return _storage.values
        .where((j) => j.businessId == businessId && j.documentId == documentId)
        .toList();
  }

  @override
  Future<List<PrintJob>> getJobs({
    required String businessId,
    String? branchId,
    String? printerId,
    PrintJobStatus? status,
    int limit = 50,
  }) async {
    var list = _storage.values.where((j) => j.businessId == businessId);

    if (branchId != null) {
      list = list.where((j) => j.branchId == branchId);
    }
    if (printerId != null) {
      list = list.where((j) => j.printerId == printerId);
    }
    if (status != null) {
      list = list.where((j) => j.status == status);
    }

    final sorted = list.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sorted.take(limit).toList();
  }

  void clear() {
    _storage.clear();
  }
}
