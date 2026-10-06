// واجهة مخزن منع تكرار المعاملات المالية (MADAR SHOP Idempotency Store Interface)
// Pure Dart — Zero UI Dependencies

import '../entities/sale.dart';

abstract class ISaleIdempotencyStore {
  /// استرجاع معاملة بيع سابقة مسجلة بنفس مفتاح عدم التكرار
  Future<Sale?> getSaleByIdempotencyKey({
    required String businessId,
    required String branchId,
    required String idempotencyKey,
  });

  /// حفظ معاملة البيع وربطها بمفتاح عدم التكرار
  Future<void> recordIdempotentSale({
    required String businessId,
    required String branchId,
    required String idempotencyKey,
    required Sale sale,
    Duration ttl = const Duration(hours: 24),
  });
}
