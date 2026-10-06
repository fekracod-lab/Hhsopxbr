// مخزن عدم التكرار للمرتجعات في الذاكرة (MADAR SHOP Memory Returns Idempotency Store)
// Pure Dart — Zero UI Dependencies

import '../../../domain/returns/repositories/i_returns_idempotency_store.dart';

class MemoryReturnsIdempotencyStore implements IReturnsIdempotencyStore {
  final Map<String, dynamic> _cache = {};

  @override
  Future<bool> hasKey(String key) async => _cache.containsKey(key);

  @override
  Future<dynamic> getResult(String key) async => _cache[key];

  @override
  Future<void> saveResult(String key, dynamic result) async {
    _cache[key] = result;
  }

  void clear() => _cache.clear();
}
