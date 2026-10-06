// تنفيذ مستودع عمليات نقطة البيع (MADAR SHOP POS Repository Implementation)
// Pure Dart — Zero Flutter / Firebase SDK Dependencies

import '../../../domain/pos/entities/customer_ledger_entry.dart';
import '../../../domain/pos/entities/inventory_movement_intent.dart';
import '../../../domain/pos/entities/receipt_snapshot.dart';
import '../../../domain/pos/entities/sale.dart';
import '../../../domain/pos/services/i_shop_pos_repository.dart';

class ShopPosRepositoryImpl implements IShopPosRepository {
  final Map<String, Sale> _salesStore = {};
  final Map<String, CustomerLedgerEntry> _ledgerStore = {};
  final List<InventoryMovementIntent> _intentsStore = [];
  final Map<String, ReceiptSnapshot> _receiptStore = {};

  @override
  Future<void> saveSale(Sale sale) async {
    _salesStore[sale.id] = sale;
  }

  @override
  Future<Sale?> getSaleById({
    required String businessId,
    required String branchId,
    required String saleId,
  }) async {
    final sale = _salesStore[saleId];
    if (sale == null) return null;
    if (sale.businessId != businessId || sale.branchId != branchId) {
      return null;
    }
    return sale;
  }

  @override
  Future<void> recordCustomerLedgerEntry(CustomerLedgerEntry entry) async {
    _ledgerStore[entry.entryId] = entry;
  }

  @override
  Future<void> recordInventoryMovementIntent(InventoryMovementIntent intent) async {
    _intentsStore.add(intent);
  }

  @override
  Future<void> saveReceiptSnapshot(ReceiptSnapshot receipt) async {
    _receiptStore[receipt.saleId] = receipt;
  }

  @override
  Future<List<Sale>> getSalesForSession({
    required String businessId,
    required String branchId,
    required String sessionId,
  }) async {
    return _salesStore.values
        .where((s) =>
            s.businessId == businessId &&
            s.branchId == branchId &&
            s.sessionId == sessionId)
        .toList();
  }

  @override
  Future<List<Sale>> getSales({
    required String businessId,
    String? branchId,
    DateTime? from,
    DateTime? to,
  }) async {
    return _salesStore.values.where((s) {
      if (s.businessId != businessId) return false;
      if (branchId != null && s.branchId != branchId) return false;
      if (from != null && s.createdAt.isBefore(from)) return false;
      if (to != null && s.createdAt.isAfter(to)) return false;
      return true;
    }).toList();
  }

  // ميثودات مساعدة للاختبارات والمزامنة
  List<CustomerLedgerEntry> get ledgerEntries => List.unmodifiable(_ledgerStore.values);
  List<InventoryMovementIntent> get inventoryIntents => List.unmodifiable(_intentsStore);
  List<ReceiptSnapshot> get receipts => List.unmodifiable(_receiptStore.values);
}
