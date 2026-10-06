// تقرير المطابقة والتسوية لمحرك المشتريات والمخزون والموردين (MADAR SHOP Purchasing Reconciliation Report)
// Pure Dart — Zero UI Dependencies

import '../../../domain/inventory/value_objects/stock_quantity.dart';
import '../../../domain/pos/value_objects/money.dart';

class InventoryPurchaseDiscrepancy {
  final String productId;
  final String? variantId;
  final StockQuantity receivedQuantityInPurchasing;
  final StockQuantity recordedQuantityInInventory;
  final StockQuantity difference;

  const InventoryPurchaseDiscrepancy({
    required this.productId,
    this.variantId,
    required this.receivedQuantityInPurchasing,
    required this.recordedQuantityInInventory,
    required this.difference,
  });

  bool get hasDiscrepancy => !difference.isZero;
}

class SupplierLedgerDiscrepancy {
  final String supplierId;
  final Money accountCurrentBalance;
  final Money ledgerCalculatedBalance;
  final Money discrepancy;

  const SupplierLedgerDiscrepancy({
    required this.supplierId,
    required this.accountCurrentBalance,
    required this.ledgerCalculatedBalance,
    required this.discrepancy,
  });

  bool get hasDiscrepancy => !discrepancy.isZero;
}

class PurchasingReconciliationReport {
  final String businessId;
  final DateTime auditedAt;
  final bool isInventoryBalanced;
  final bool isSupplierLedgerBalanced;
  final List<InventoryPurchaseDiscrepancy> inventoryDiscrepancies;
  final List<SupplierLedgerDiscrepancy> supplierDiscrepancies;

  const PurchasingReconciliationReport({
    required this.businessId,
    required this.auditedAt,
    required this.isInventoryBalanced,
    required this.isSupplierLedgerBalanced,
    this.inventoryDiscrepancies = const [],
    this.supplierDiscrepancies = const [],
  });

  bool get isFullyBalanced => isInventoryBalanced && isSupplierLedgerBalanced;
}
