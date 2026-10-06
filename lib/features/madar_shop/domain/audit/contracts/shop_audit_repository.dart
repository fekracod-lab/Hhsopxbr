// عقود مستودع سجل التدقيق والحوكمة (MADAR SHOP Audit Repository Contract)
// Pure Dart — Zero UI Dependencies

import '../entities/shop_audit_entry.dart';

abstract class IShopAuditRepository {
  /// تسجيل حدث تدقيق غير قابل للتعديل (Append-Only)
  Future<void> recordAuditEntry(ShopAuditEntry entry);

  /// استرجاع سجلات التدقيق لفرع معين مع إمكانية الفلترة
  Future<List<ShopAuditEntry>> getAuditEntries({
    required String businessId,
    required String branchId,
    ShopAuditAction? actionFilter,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  });
}
