// مخزن عدم التكرار للعمليات المالية (MADAR SHOP Finance Idempotency Store Interface)
// Pure Dart — Zero UI Dependencies

abstract class IFinanceIdempotencyStore {
  Future<bool> hasKey(String key);
  Future<dynamic> getResult(String key);
  Future<void> saveResult(String key, dynamic result);
}
