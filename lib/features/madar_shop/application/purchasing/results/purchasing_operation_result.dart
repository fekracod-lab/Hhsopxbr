// نتائج عمليات ومخرجات محرك المشتريات (MADAR SHOP Purchasing Operation Results)
// Pure Dart — Zero UI Dependencies

import '../../../domain/purchasing/entities/purchase_order.dart';
import '../../../domain/purchasing/entities/purchase_receipt.dart';
import '../../../domain/purchasing/entities/supplier.dart';
import '../../../domain/purchasing/entities/supplier_account.dart';
import '../../../domain/purchasing/entities/supplier_ledger_entry.dart';
import '../../../domain/purchasing/entities/supplier_payment.dart';

class SupplierOperationResult {
  final bool isSuccess;
  final Supplier? supplier;
  final SupplierAccount? account;
  final String? message;

  const SupplierOperationResult({
    required this.isSuccess,
    this.supplier,
    this.account,
    this.message,
  });
}

class PurchaseOrderOperationResult {
  final bool isSuccess;
  final PurchaseOrder? order;
  final String? message;

  const PurchaseOrderOperationResult({
    required this.isSuccess,
    this.order,
    this.message,
  });
}

class ReceiveGoodsOperationResult {
  final bool isSuccess;
  final PurchaseOrder order;
  final PurchaseReceipt receipt;
  final SupplierLedgerEntry? ledgerEntry;
  final String? message;

  const ReceiveGoodsOperationResult({
    required this.isSuccess,
    required this.order,
    required this.receipt,
    this.ledgerEntry,
    this.message,
  });
}

class SupplierPaymentOperationResult {
  final bool isSuccess;
  final SupplierPayment payment;
  final SupplierLedgerEntry ledgerEntry;
  final SupplierAccount updatedAccount;
  final String? message;

  const SupplierPaymentOperationResult({
    required this.isSuccess,
    required this.payment,
    required this.ledgerEntry,
    required this.updatedAccount,
    this.message,
  });
}
