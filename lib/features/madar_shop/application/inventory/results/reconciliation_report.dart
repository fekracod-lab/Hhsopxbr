// تقرير المطابقة الجردية والتدقيق بين اللقطة ودفتر الأستاذ (MADAR SHOP Reconciliation Report)
// Pure Dart — Zero UI Dependencies

import '../../../domain/inventory/value_objects/stock_quantity.dart';

class ItemReconciliationFinding {
  final String productId;
  final String? variantId;
  final StockQuantity snapshotOnHand;
  final StockQuantity ledgerDerivedOnHand;
  final StockQuantity difference;
  final bool isBalanced;
  final String explanation;

  const ItemReconciliationFinding({
    required this.productId,
    this.variantId,
    required this.snapshotOnHand,
    required this.ledgerDerivedOnHand,
    required this.difference,
    required this.isBalanced,
    required this.explanation,
  });
}

class InventoryReconciliationReport {
  final String businessId;
  final String branchId;
  final DateTime auditedAt;
  final List<ItemReconciliationFinding> findings;
  final int totalItemsAudited;
  final int balancedItemsCount;
  final int corruptedItemsCount;

  const InventoryReconciliationReport({
    required this.businessId,
    required this.branchId,
    required this.auditedAt,
    required this.findings,
    required this.totalItemsAudited,
    required this.balancedItemsCount,
    required this.corruptedItemsCount,
  });

  bool get isEntirelyConsistent => corruptedItemsCount == 0;
}
