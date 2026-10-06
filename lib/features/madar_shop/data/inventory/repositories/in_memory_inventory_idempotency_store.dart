// تنفيذ مخزن منع تكرار حركات المخزون في الذاكرة (In-Memory Inventory Idempotency Store)
// Pure Dart — Zero Flutter / Firebase SDK Dependencies

import '../../../domain/inventory/repositories/i_inventory_idempotency_store.dart';

class _InventoryIdempotencyRecord {
  final String resultSummary;
  final DateTime expiresAt;

  const _InventoryIdempotencyRecord(this.resultSummary, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class InMemoryInventoryIdempotencyStore implements IInventoryIdempotencyStore {
  final Map<String, _InventoryIdempotencyRecord> _store = {};

  String _buildKey(String businessId, String branchId, String idempotencyKey) {
    return '$businessId:$branchId:$idempotencyKey';
  }

  @override
  Future<bool> hasProcessed({
    required String businessId,
    required String branchId,
    required String idempotencyKey,
  }) async {
    final key = _buildKey(businessId, branchId, idempotencyKey);
    final record = _store[key];
    if (record == null) return false;
    if (record.isExpired) {
      _store.remove(key);
      return false;
    }
    return true;
  }

  @override
  Future<void> recordProcessed({
    required String businessId,
    required String branchId,
    required String idempotencyKey,
    required String resultSummary,
    Duration ttl = const Duration(hours: 24),
  }) async {
    final key = _buildKey(businessId, branchId, idempotencyKey);
    _store[key] = _InventoryIdempotencyRecord(resultSummary, DateTime.now().add(ttl));
  }

  void clear() {
    _store.clear();
  }
}
