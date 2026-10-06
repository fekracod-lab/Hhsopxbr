// مخزن عدم التكرار لعمليات المرتجعات (MADAR SHOP Returns Idempotency Store Interface)
// Pure Dart — Zero UI Dependencies

abstract class IReturnsIdempotencyStore {
  Future<bool> hasKey(String key);
  Future<dynamic> getResult(String key);
  Future<void> saveResult(String key, dynamic result);
}
