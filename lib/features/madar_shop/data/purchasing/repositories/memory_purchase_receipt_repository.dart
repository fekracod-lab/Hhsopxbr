// مستودع إيصالات استلام بضاعة المشتريات في الذاكرة (MADAR SHOP Memory Purchase Receipt Repository)
// Pure Dart — Zero UI Dependencies

import '../../../domain/purchasing/entities/purchase_receipt.dart';
import '../../../domain/purchasing/repositories/i_purchase_receipt_repository.dart';

class MemoryPurchaseReceiptRepository implements IPurchaseReceiptRepository {
  final Map<String, PurchaseReceipt> _receipts = {};

  String _key(String businessId, String id) => '$businessId:$id';

  @override
  Future<void> saveReceipt(PurchaseReceipt receipt) async {
    _receipts[_key(receipt.businessId, receipt.id)] = receipt;
  }

  @override
  Future<PurchaseReceipt?> getReceiptById({
    required String businessId,
    required String receiptId,
  }) async {
    return _receipts[_key(businessId, receiptId)];
  }

  @override
  Future<List<PurchaseReceipt>> getReceiptsForPurchaseOrder({
    required String businessId,
    required String purchaseOrderId,
  }) async {
    return _receipts.values
        .where((r) => r.businessId == businessId && r.purchaseOrderId == purchaseOrderId)
        .toList();
  }

  @override
  Future<List<PurchaseReceipt>> getReceipts({
    required String businessId,
    String? branchId,
    String? supplierId,
  }) async {
    return _receipts.values.where((r) {
      if (r.businessId != businessId) return false;
      if (branchId != null && r.branchId != branchId) return false;
      if (supplierId != null && r.supplierId != supplierId) return false;
      return true;
    }).toList();
  }

  void clear() {
    _receipts.clear();
  }
}
