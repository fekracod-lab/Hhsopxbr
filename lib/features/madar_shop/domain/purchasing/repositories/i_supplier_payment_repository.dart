// واجهة مستودع مدفوعات الموردين (MADAR SHOP Supplier Payment Repository Contract)
// Pure Dart — Zero UI Dependencies

import '../entities/supplier_payment.dart';

abstract class ISupplierPaymentRepository {
  Future<void> savePayment(SupplierPayment payment);

  Future<SupplierPayment?> getPaymentById({
    required String businessId,
    required String paymentId,
  });

  Future<List<SupplierPayment>> getPaymentsForSupplier({
    required String businessId,
    required String supplierId,
  });

  Future<List<SupplierPayment>> getPaymentsForPurchaseOrder({
    required String businessId,
    required String purchaseOrderId,
  });
}
