// سياسة العمل بدون اتصال وقواعد السماح والمنع المحافظة (MADAR SHOP Offline Policy)
// Pure Dart — Zero UI Dependencies

import '../enums/offline_operation_permission.dart';

class OfflinePolicy {
  final OfflineOperationPermission cashSale;
  final OfflineOperationPermission creditSale;
  final OfflineOperationPermission customerReturn;
  final OfflineOperationPermission refundPayout;
  final OfflineOperationPermission purchaseReceiving;
  final OfflineOperationPermission supplierPayment;
  final OfflineOperationPermission inventoryAdjustment;
  final OfflineOperationPermission branchTransfer;
  final OfflineOperationPermission productEdit;
  final OfflineOperationPermission priceEdit;

  final double offlineStockAllowanceRatio; // نسبة المخزون المسموح بيعه أوفلاين (افتراضياً 80%)
  final int maxOfflineCreditAmountMinorUnits; // سقف المبيعات الآجلة أوفلاين
  final bool allowNegativeStock; // ممنوع منعاً باتاً (دائماً false)

  const OfflinePolicy({
    this.cashSale = OfflineOperationPermission.allow,
    this.creditSale = OfflineOperationPermission.block,
    this.customerReturn = OfflineOperationPermission.allowWithWarning,
    this.refundPayout = OfflineOperationPermission.block,
    this.purchaseReceiving = OfflineOperationPermission.allowWithWarning,
    this.supplierPayment = OfflineOperationPermission.block,
    this.inventoryAdjustment = OfflineOperationPermission.block,
    this.branchTransfer = OfflineOperationPermission.block,
    this.productEdit = OfflineOperationPermission.block,
    this.priceEdit = OfflineOperationPermission.block,
    this.offlineStockAllowanceRatio = 0.8,
    this.maxOfflineCreditAmountMinorUnits = 0,
    this.allowNegativeStock = false,
  });

  /// سياسة متشددة للمتاجر القياسية لمنع أي مخاطر مالية أو نفاد مخزون
  factory OfflinePolicy.conservative() => const OfflinePolicy();

  /// سياسة مرنة للمعارض الميدانية أو نقاط البيع المتنقلة
  factory OfflinePolicy.flexible({
    int maxOfflineCreditMinorUnits = 5000000, // 50,000 IQD
    double stockAllowance = 0.9,
  }) {
    return OfflinePolicy(
      cashSale: OfflineOperationPermission.allow,
      creditSale: OfflineOperationPermission.allowWithWarning,
      customerReturn: OfflineOperationPermission.allowWithWarning,
      refundPayout: OfflineOperationPermission.block,
      purchaseReceiving: OfflineOperationPermission.allowWithWarning,
      supplierPayment: OfflineOperationPermission.block,
      inventoryAdjustment: OfflineOperationPermission.block,
      branchTransfer: OfflineOperationPermission.block,
      productEdit: OfflineOperationPermission.block,
      priceEdit: OfflineOperationPermission.block,
      offlineStockAllowanceRatio: stockAllowance,
      maxOfflineCreditAmountMinorUnits: maxOfflineCreditMinorUnits,
      allowNegativeStock: false,
    );
  }

  OfflineOperationPermission getPermissionFor(String operationKey) {
    switch (operationKey) {
      case 'cashSale':
        return cashSale;
      case 'creditSale':
        return creditSale;
      case 'return':
      case 'customerReturn':
        return customerReturn;
      case 'refund':
      case 'refundPayout':
        return refundPayout;
      case 'purchase':
      case 'purchaseReceiving':
        return purchaseReceiving;
      case 'supplierPayment':
        return supplierPayment;
      case 'inventoryAdjustment':
        return inventoryAdjustment;
      case 'transfer':
      case 'branchTransfer':
        return branchTransfer;
      case 'productEdit':
        return productEdit;
      case 'priceEdit':
        return priceEdit;
      default:
        return OfflineOperationPermission.block;
    }
  }

  Map<String, dynamic> toJson() => {
        'cashSale': cashSale.name,
        'creditSale': creditSale.name,
        'customerReturn': customerReturn.name,
        'refundPayout': refundPayout.name,
        'purchaseReceiving': purchaseReceiving.name,
        'supplierPayment': supplierPayment.name,
        'inventoryAdjustment': inventoryAdjustment.name,
        'branchTransfer': branchTransfer.name,
        'productEdit': productEdit.name,
        'priceEdit': priceEdit.name,
        'offlineStockAllowanceRatio': offlineStockAllowanceRatio,
        'maxOfflineCreditAmountMinorUnits': maxOfflineCreditAmountMinorUnits,
        'allowNegativeStock': allowNegativeStock,
      };
}
