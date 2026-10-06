// مخزن عدم التكرار للعمليات المالية في الذاكرة (MADAR SHOP Memory Finance Idempotency Store)
// Pure Dart — Zero UI Dependencies

import '../../../domain/finance/repositories/i_finance_idempotency_store.dart';

class MemoryFinanceIdempotencyStore implements IFinanceIdempotencyStore {
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
