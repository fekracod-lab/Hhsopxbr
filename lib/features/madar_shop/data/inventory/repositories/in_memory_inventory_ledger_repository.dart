// تنفيذ مستودع دفتر أستاذ المخزون التراكمي في الذاكرة (In-Memory Inventory Ledger Repository)
// Pure Dart — Zero Flutter / Firebase SDK Dependencies — Append-Only

import '../../../domain/inventory/entities/inventory_ledger_entry.dart';
import '../../../domain/inventory/enums/inventory_movement_type.dart';
import '../../../domain/inventory/repositories/i_inventory_ledger_repository.dart';

class InMemoryInventoryLedgerRepository implements IInventoryLedgerRepository {
  final List<InventoryLedgerEntry> _entries = [];

  @override
  Future<void> appendLedgerEntry(InventoryLedgerEntry entry) async {
    // التحقق من أن القيد غير موجود مسبقاً (دفتر الأستاذ غير قابل للتعديل أو الاستبدال)
    if (_entries.any((e) => e.id == entry.id)) {
      throw StateError('يمنع تعديل أو إعادة كتابة قيد دفتر الأستاذ رقم ${entry.id} (Append-Only Invariant).');
    }
    _entries.add(entry);
  }

  @override
  Future<List<InventoryLedgerEntry>> getLedgerEntriesForItem({
    required String businessId,
    required String branchId,
    required String productId,
    String? variantId,
    int limit = 100,
  }) async {
    return _entries
        .where((e) =>
            e.businessId == businessId &&
            e.branchId == branchId &&
            e.productId == productId &&
            e.variantId == variantId)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<InventoryLedgerEntry>> getLedgerEntriesForReference({
    required String referenceType,
    required String referenceId,
  }) async {
    return _entries
        .where((e) => e.referenceType == referenceType && e.referenceId == referenceId)
        .toList(growable: false);
  }

  @override
  Future<List<InventoryLedgerEntry>> getLedgerEntries({
    required String businessId,
    String? branchId,
    InventoryMovementType? movementType,
    DateTime? from,
    DateTime? to,
  }) async {
    return _entries.where((e) {
      if (e.businessId != businessId) return false;
      if (branchId != null && e.branchId != branchId) return false;
      if (movementType != null && e.movementType != movementType) return false;
      if (from != null && e.createdAt.isBefore(from)) return false;
      if (to != null && e.createdAt.isAfter(to)) return false;
      return true;
    }).toList(growable: false);
  }

  List<InventoryLedgerEntry> get allEntries => List.unmodifiable(_entries);

  void clear() {
    _entries.clear();
  }
}
