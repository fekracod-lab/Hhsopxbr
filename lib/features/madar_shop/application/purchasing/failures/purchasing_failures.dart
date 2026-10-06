// إخفاقات واستثناءات محرك المشتريات والموردين (MADAR SHOP Purchasing Failures)
// Pure Dart — Zero UI Dependencies

abstract class PurchasingFailure implements Exception {
  final String message;
  final String? code;

  const PurchasingFailure(this.message, [this.code]);

  @override
  String toString() => '$runtimeType: $message (${code ?? "NO_CODE"})';
}

class SupplierNotFoundFailure extends PurchasingFailure {
  const SupplierNotFoundFailure([String message = 'المورد المطلوب غير موجود في النظام.'])
      : super(message, 'SUPPLIER_NOT_FOUND');
}

class SupplierBlockedFailure extends PurchasingFailure {
  const SupplierBlockedFailure([String message = 'المورد محظور من التعامل التجاري.'])
      : super(message, 'SUPPLIER_BLOCKED');
}

class SupplierInactiveFailure extends PurchasingFailure {
  const SupplierInactiveFailure([String message = 'المورد غير نشط حالياً.'])
      : super(message, 'SUPPLIER_INACTIVE');
}

class PurchaseOrderNotFoundFailure extends PurchasingFailure {
  const PurchaseOrderNotFoundFailure([String message = 'أمر الشراء المطلوب غير موجود.'])
      : super(message, 'PURCHASE_ORDER_NOT_FOUND');
}

class InvalidPurchaseStateTransitionFailure extends PurchasingFailure {
  const InvalidPurchaseStateTransitionFailure(String message)
      : super(message, 'INVALID_PURCHASE_STATE_TRANSITION');
}

class OverReceivingBlockedFailure extends PurchasingFailure {
  const OverReceivingBlockedFailure(String message)
      : super(message, 'OVER_RECEIVING_BLOCKED');
}

class SupplierOverpaymentBlockedFailure extends PurchasingFailure {
  const SupplierOverpaymentBlockedFailure(String message)
      : super(message, 'SUPPLIER_OVERPAYMENT_BLOCKED');
}

class UnauthorizedPurchasingOperationFailure extends PurchasingFailure {
  const UnauthorizedPurchasingOperationFailure(String message)
      : super(message, 'UNAUTHORIZED_PURCHASING_OPERATION');
}

class PurchasingBranchMismatchFailure extends PurchasingFailure {
  const PurchasingBranchMismatchFailure(String message)
      : super(message, 'PURCHASING_BRANCH_MISMATCH');
}

class PurchasingBusinessMismatchFailure extends PurchasingFailure {
  const PurchasingBusinessMismatchFailure(String message)
      : super(message, 'PURCHASING_BUSINESS_MISMATCH');
}

class DuplicatePurchasingCommandFailure extends PurchasingFailure {
  const DuplicatePurchasingCommandFailure([String message = 'تم تنفيذ هذا الأمر مسبقاً (Replay detected).'])
      : super(message, 'DUPLICATE_PURCHASING_COMMAND');
}

class PurchasingConflictFailure extends PurchasingFailure {
  const PurchasingConflictFailure(String message)
      : super(message, 'PURCHASING_CONCURRENCY_CONFLICT');
}

class InvalidPurchaseQuantityFailure extends PurchasingFailure {
  const InvalidPurchaseQuantityFailure(String message)
      : super(message, 'INVALID_PURCHASE_QUANTITY');
}

class InvalidPurchaseCostFailure extends PurchasingFailure {
  const InvalidPurchaseCostFailure(String message)
      : super(message, 'INVALID_PURCHASE_COST');
}
