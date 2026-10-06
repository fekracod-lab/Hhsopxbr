// عقد مخزن عدم التكرار لمهام الطباعة (MADAR SHOP Printing Idempotency Store Interface)
// Pure Dart — Zero UI Dependencies

abstract class IPrintingIdempotencyStore {
  /// التحقق من وجود مفتاح عدم التكرار وتسجيله
  Future<bool> hasKey({
    required String businessId,
    required String idempotencyKey,
  });

  /// حفظ ربط مفتاح عدم التكرار برقم المهمة المنفذة
  Future<void> recordKey({
    required String businessId,
    required String idempotencyKey,
    required String jobId,
    Duration expiration = const Duration(hours: 24),
  });

  /// استرجاع رقم المهمة المرتبطة بمفتاح عدم التكرار
  Future<String?> getJobIdForKey({
    required String businessId,
    required String idempotencyKey,
  });

  /// التحقق من تنفيذ الطباعة التلقائية لوثيقة معينة مسبقاً
  Future<bool> hasAutoPrintExecuted({
    required String businessId,
    required String documentId,
  });

  /// تسجيل إتمام أو جدولة طباعة تلقائية لوثيقة لمنع التكرار
  Future<void> recordAutoPrint({
    required String businessId,
    required String documentId,
    required String jobId,
  });
}
