// متجر تفادي التكرار في الذاكرة لمحرك المشتريات (MADAR SHOP Memory Purchasing Idempotency Store)
// Pure Dart — Zero UI Dependencies

import '../../../domain/purchasing/repositories/i_purchasing_idempotency_store.dart';

class MemoryPurchasingIdempotencyStore implements IPurchasingIdempotencyStore {
  final Map<String, dynamic> _store = {};

  @override
  Future<bool> hasKey(String idempotencyKey) async {
    return _store.containsKey(idempotencyKey);
  }

  @override
  Future<dynamic> getResult(String idempotencyKey) async {
    return _store[idempotencyKey];
  }

  @override
  Future<void> recordKey({
    required String idempotencyKey,
    required dynamic result,
    Duration? ttl,
  }) async {
    _store[idempotencyKey] = result;
  }

  void clear() {
    _store.clear();
  }
}
