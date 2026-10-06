// مخزن عدم التكرار بالذاكرة (MADAR SHOP In-Memory Printing Idempotency Store)
// Pure Dart — Zero UI Dependencies

import '../../../domain/printing/contracts/i_printing_idempotency_store.dart';

class MemoryPrintingIdempotencyStore implements IPrintingIdempotencyStore {
  final Map<String, String> _keysToJobId = {};
  final Set<String> _autoPrintedDocs = {};

  @override
  Future<bool> hasKey({
    required String businessId,
    required String idempotencyKey,
  }) async {
    return _keysToJobId.containsKey('${businessId}_$idempotencyKey');
  }

  @override
  Future<void> recordKey({
    required String businessId,
    required String idempotencyKey,
    required String jobId,
    Duration expiration = const Duration(hours: 24),
  }) async {
    _keysToJobId['${businessId}_$idempotencyKey'] = jobId;
  }

  @override
  Future<String?> getJobIdForKey({
    required String businessId,
    required String idempotencyKey,
  }) async {
    return _keysToJobId['${businessId}_$idempotencyKey'];
  }

  @override
  Future<bool> hasAutoPrintExecuted({
    required String businessId,
    required String documentId,
  }) async {
    return _autoPrintedDocs.contains('${businessId}_$documentId');
  }

  @override
  Future<void> recordAutoPrint({
    required String businessId,
    required String documentId,
    required String jobId,
  }) async {
    _autoPrintedDocs.add('${businessId}_$documentId');
  }

  void clear() {
    _keysToJobId.clear();
    _autoPrintedDocs.clear();
  }
}
