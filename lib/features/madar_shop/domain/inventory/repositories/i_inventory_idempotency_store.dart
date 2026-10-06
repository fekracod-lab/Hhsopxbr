// واجهة مخزن منع تكرار حركات المخزون (MADAR SHOP Inventory Idempotency Store Interface)
// Pure Dart — Zero UI Dependencies

abstract class IInventoryIdempotencyStore {
  /// التحقق مما إذا تمت معالجة هذا المفتاح مسبقاً
  Future<bool> hasProcessed({
    required String businessId,
    required String branchId,
    required String idempotencyKey,
  });

  /// تسجيل إتمام معالجة المفتاح بنجاح
  Future<void> recordProcessed({
    required String businessId,
    required String branchId,
    required String idempotencyKey,
    required String resultSummary,
    Duration ttl = const Duration(hours: 24),
  });
}
