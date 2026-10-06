// أخطاء وإخفاقات محرك نقطة البيع المعرفة برمجياً (MADAR SHOP Typed POS Failures)
// Pure Dart — Zero UI Dependencies

abstract class PosFailure implements Exception {
  final String message;
  final String? code;

  const PosFailure(this.message, [this.code]);

  @override
  String toString() => message;
}

class InvalidCartFailure extends PosFailure {
  const InvalidCartFailure(super.message, [super.code = 'INVALID_CART']);
}

class ProductNotFoundFailure extends PosFailure {
  const ProductNotFoundFailure(super.message, [super.code = 'PRODUCT_NOT_FOUND']);
}

class ProductUnavailableFailure extends PosFailure {
  const ProductUnavailableFailure(super.message, [super.code = 'PRODUCT_UNAVAILABLE']);
}

class InsufficientStockFailure extends PosFailure {
  const InsufficientStockFailure(super.message, [super.code = 'INSUFFICIENT_STOCK']);
}

class InvalidQuantityFailure extends PosFailure {
  const InvalidQuantityFailure(super.message, [super.code = 'INVALID_QUANTITY']);
}

class InvalidDiscountFailure extends PosFailure {
  const InvalidDiscountFailure(super.message, [super.code = 'INVALID_DISCOUNT']);
}

class InvalidPaymentFailure extends PosFailure {
  const InvalidPaymentFailure(super.message, [super.code = 'INVALID_PAYMENT']);
}

class PaymentMismatchFailure extends PosFailure {
  const PaymentMismatchFailure(super.message, [super.code = 'PAYMENT_MISMATCH']);
}

class CreditCustomerRequiredFailure extends PosFailure {
  const CreditCustomerRequiredFailure(super.message, [super.code = 'CREDIT_CUSTOMER_REQUIRED']);
}

class SessionExpiredFailure extends PosFailure {
  const SessionExpiredFailure(super.message, [super.code = 'SESSION_EXPIRED']);
}

class UnauthorizedTerminalFailure extends PosFailure {
  const UnauthorizedTerminalFailure(super.message, [super.code = 'UNAUTHORIZED_TERMINAL']);
}

class BranchMismatchFailure extends PosFailure {
  const BranchMismatchFailure(super.message, [super.code = 'BRANCH_MISMATCH']);
}

class UnauthorizedCashierFailure extends PosFailure {
  const UnauthorizedCashierFailure(super.message, [super.code = 'UNAUTHORIZED_CASHIER']);
}

class DuplicateCheckoutFailure extends PosFailure {
  const DuplicateCheckoutFailure(super.message, [super.code = 'DUPLICATE_CHECKOUT']);
}

class TransactionConflictFailure extends PosFailure {
  const TransactionConflictFailure(super.message, [super.code = 'TRANSACTION_CONFLICT']);
}
