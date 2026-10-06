// واجهة مستودع إيصالات استلام بضاعة المشتريات (MADAR SHOP Purchase Receipt Repository Contract)
// Pure Dart — Zero UI Dependencies

import '../entities/purchase_receipt.dart';

abstract class IPurchaseReceiptRepository {
  Future<void> saveReceipt(PurchaseReceipt receipt);

  Future<PurchaseReceipt?> getReceiptById({
    required String businessId,
    required String receiptId,
  });

  Future<List<PurchaseReceipt>> getReceiptsForPurchaseOrder({
    required String businessId,
    required String purchaseOrderId,
  });

  Future<List<PurchaseReceipt>> getReceipts({
    required String businessId,
    String? branchId,
    String? supplierId,
  });
}
