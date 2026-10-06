// خدمة مطابقة وتدقيق المخزون (MADAR SHOP Inventory Reconciliation Service)
// Pure Dart — Zero UI Dependencies

import '../../../domain/inventory/entities/inventory_item.dart';
import '../../../domain/inventory/repositories/i_inventory_ledger_repository.dart';
import '../../../domain/inventory/repositories/i_inventory_repository.dart';
import '../../../domain/inventory/value_objects/stock_quantity.dart';
import '../results/reconciliation_report.dart';

class InventoryReconciliationService {
  final IInventoryRepository _inventoryRepository;
  final IInventoryLedgerRepository _ledgerRepository;

  const InventoryReconciliationService({
    required IInventoryRepository inventoryRepository,
    required IInventoryLedgerRepository ledgerRepository,
  })  : _inventoryRepository = inventoryRepository,
        _ledgerRepository = ledgerRepository;

  /// مطابقة وتدقيق صنف مخزون واحد عبر مقارنة اللقطة الحالية مع مجموع قيود دفتر الأستاذ
  Future<ItemReconciliationFinding> reconcileItem({
    required String businessId,
    required String branchId,
    required String productId,
    String? variantId,
  }) async {
    final InventoryItem? item = await _inventoryRepository.getInventoryItem(
      businessId: businessId,
      branchId: branchId,
      productId: productId,
      variantId: variantId,
    );

    final entries = await _ledgerRepository.getLedgerEntriesForItem(
      businessId: businessId,
      branchId: branchId,
      productId: productId,
      variantId: variantId,
      limit: 1000,
    );

    if (item == null) {
      if (entries.isEmpty) {
        return ItemReconciliationFinding(
          productId: productId,
          variantId: variantId,
          snapshotOnHand: StockQuantity.zero(),
          ledgerDerivedOnHand: StockQuantity.zero(),
          difference: StockQuantity.zero(),
          isBalanced: true,
          explanation: 'الصنف غير موجود ولا توجد له أي حركات سابقة.',
        );
      } else {
        final unit = entries.first.unit;
        var derivedMilliUnits = 0;
        for (final entry in entries) {
          derivedMilliUnits += entry.quantityDelta.milliUnits;
        }
        final derivedOnHand = StockQuantity.fromMilliUnits(derivedMilliUnits, unit);
        return ItemReconciliationFinding(
          productId: productId,
          variantId: variantId,
          snapshotOnHand: StockQuantity.zero(unit),
          ledgerDerivedOnHand: derivedOnHand,
          difference: -derivedOnHand,
          isBalanced: false,
          explanation: 'اللقطة غير موجودة لكن يوجد قيود في دفتر الأستاذ (بيانات مشوهة / Corrupted).',
        );
      }
    }

    final unit = item.unit;
    var derivedMilliUnits = 0;
    for (final entry in entries) {
      derivedMilliUnits += entry.quantityDelta.milliUnits;
    }
    final derivedOnHand = StockQuantity.fromMilliUnits(derivedMilliUnits, unit);

    final isBalanced = item.onHand == derivedOnHand;
    final diff = item.onHand - derivedOnHand;

    return ItemReconciliationFinding(
      productId: productId,
      variantId: variantId,
      snapshotOnHand: item.onHand,
      ledgerDerivedOnHand: derivedOnHand,
      difference: diff,
      isBalanced: isBalanced,
      explanation: isBalanced
          ? 'اللقطة مطابقة تماماً لمجموع قيود دفتر الأستاذ.'
          : 'يوجد عدم تطابق بين اللقطة ودفتر الأستاذ بفارق قدره $diff.',
    );
  }

  /// مطابقة وتدقيق شامل لجميع أصناف الفرع
  Future<InventoryReconciliationReport> reconcileBranch({
    required String businessId,
    required String branchId,
  }) async {
    final items = await _inventoryRepository.listBranchInventory(
      businessId: businessId,
      branchId: branchId,
    );

    final findings = <ItemReconciliationFinding>[];
    var balancedCount = 0;
    var corruptedCount = 0;

    for (final item in items) {
      final finding = await reconcileItem(
        businessId: businessId,
        branchId: branchId,
        productId: item.productId,
        variantId: item.variantId,
      );
      findings.add(finding);
      if (finding.isBalanced) {
        balancedCount++;
      } else {
        corruptedCount++;
      }
    }

    return InventoryReconciliationReport(
      businessId: businessId,
      branchId: branchId,
      auditedAt: DateTime.now(),
      findings: findings,
      totalItemsAudited: items.length,
      balancedItemsCount: balancedCount,
      corruptedItemsCount: corruptedCount,
    );
  }
}
