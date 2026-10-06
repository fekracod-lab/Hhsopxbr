// مستودع مدفوعات الموردين في الذاكرة (MADAR SHOP Memory Supplier Payment Repository)
// Pure Dart — Zero UI Dependencies

import '../../../domain/purchasing/entities/supplier_payment.dart';
import '../../../domain/purchasing/repositories/i_supplier_payment_repository.dart';

class MemorySupplierPaymentRepository implements ISupplierPaymentRepository {
  final Map<String, SupplierPayment> _payments = {};

  String _key(String businessId, String id) => '$businessId:$id';

  @override
  Future<void> savePayment(SupplierPayment payment) async {
    _payments[_key(payment.businessId, payment.id)] = payment;
  }

  @override
  Future<SupplierPayment?> getPaymentById({
    required String businessId,
    required String paymentId,
  }) async {
    return _payments[_key(businessId, paymentId)];
  }

  @override
  Future<List<SupplierPayment>> getPaymentsForSupplier({
    required String businessId,
    required String supplierId,
  }) async {
    return _payments.values
        .where((p) => p.businessId == businessId && p.supplierId == supplierId)
        .toList();
  }

  @override
  Future<List<SupplierPayment>> getPaymentsForPurchaseOrder({
    required String businessId,
    required String purchaseOrderId,
  }) async {
    return _payments.values
        .where((p) => p.businessId == businessId && p.purchaseOrderId == purchaseOrderId)
        .toList();
  }

  void clear() {
    _payments.clear();
  }
}
