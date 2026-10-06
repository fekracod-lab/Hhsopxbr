// عقد مستودع مهام الطباعة (MADAR SHOP Print Job Repository Interface)
// Pure Dart — Zero UI Dependencies

import '../entities/print_job.dart';
import '../enums/print_job_status.dart';

abstract class IPrintJobRepository {
  Future<void> saveJob(PrintJob job);

  Future<PrintJob?> getJobById({
    required String businessId,
    required String jobId,
  });

  Future<List<PrintJob>> getJobsForDocument({
    required String businessId,
    required String documentId,
  });

  Future<List<PrintJob>> getJobs({
    required String businessId,
    String? branchId,
    String? printerId,
    PrintJobStatus? status,
    int limit = 50,
  });
}
