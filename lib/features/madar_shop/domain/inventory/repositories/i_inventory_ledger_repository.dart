// واجهة مستودع دفتر أستاذ المخزون التراكمي الإضافي فقط (MADAR SHOP Inventory Ledger Repository Interface)
// Pure Dart — Zero UI Dependencies

import '../entities/inventory_ledger_entry.dart';
import '../enums/inventory_movement_type.dart';

abstract class IInventoryLedgerRepository {
  /// إضافة قيد جديد في دفتر الأستاذ (Append-Only حصراً؛ يمنع التعديل أو الحذف)
  Future<void> appendLedgerEntry(InventoryLedgerEntry entry);

  /// جلب القيود التاريخية لصنف محدد
  Future<List<InventoryLedgerEntry>> getLedgerEntriesForItem({
    required String businessId,
    required String branchId,
    required String productId,
    String? variantId,
    int limit = 100,
  });

  /// جلب القيود المرتبطة بمرجع معين (مثل رقم الفاتورة أو رقم التوريد)
  Future<List<InventoryLedgerEntry>> getLedgerEntriesForReference({
    required String referenceType,
    required String referenceId,
  });

  /// جلب قيود دفتر أستاذ المخزون مع إمكانية الفلترة
  Future<List<InventoryLedgerEntry>> getLedgerEntries({
    required String businessId,
    String? branchId,
    InventoryMovementType? movementType,
    DateTime? from,
    DateTime? to,
  });
}
