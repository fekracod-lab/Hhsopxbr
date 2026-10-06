// تنفيذ مخزن منع تكرار المعاملات المالية (In-Memory POS Idempotency Store)
// Pure Dart — Zero Flutter / Firebase SDK Dependencies

import '../../../domain/pos/entities/sale.dart';
import '../../../domain/pos/services/i_sale_idempotency_store.dart';

class _IdempotencyRecord {
  final Sale sale;
  final DateTime expiresAt;

  const _IdempotencyRecord(this.sale, this.expiresAt);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class InMemorySaleIdempotencyStore implements ISaleIdempotencyStore {
  final Map<String, _IdempotencyRecord> _store = {};

  String _buildKey(String businessId, String branchId, String idempotencyKey) {
    return '$businessId:$branchId:$idempotencyKey';
  }

  @override
  Future<Sale?> getSaleByIdempotencyKey({
    required String businessId,
    required String branchId,
    required String idempotencyKey,
  }) async {
    final key = _buildKey(businessId, branchId, idempotencyKey);
    final record = _store[key];
    if (record == null) return null;
    if (record.isExpired) {
      _store.remove(key);
      return null;
    }
    return record.sale;
  }

  @override
  Future<void> recordIdempotentSale({
    required String businessId,
    required String branchId,
    required String idempotencyKey,
    required Sale sale,
    Duration ttl = const Duration(hours: 24),
  }) async {
    final key = _buildKey(businessId, branchId, idempotencyKey);
    _store[key] = _IdempotencyRecord(sale, DateTime.now().add(ttl));
  }

  void clear() {
    _store.clear();
  }
}
