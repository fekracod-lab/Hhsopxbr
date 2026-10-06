// إخفاقات واستثناءات نظام المرتجعات (MADAR SHOP Returns Domain Failures)
// Pure Dart — Zero UI Dependencies

abstract class ReturnsFailure implements Exception {
  final String message;
  final String code;

  const ReturnsFailure(this.message, this.code);

  @override
  String toString() => '$runtimeType: $message ($code)';
}

class ReturnOrderNotFoundFailure extends ReturnsFailure {
  const ReturnOrderNotFoundFailure([String message = 'أمر المرتجع غير موجود أو تم حذفه.'])
      : super(message, 'RETURN_ORDER_NOT_FOUND');
}

class OriginalSaleNotFoundFailure extends ReturnsFailure {
  const OriginalSaleNotFoundFailure([String message = 'الفاتورة الأصلية للمرتجع غير موجودة أو لم تكتمل بنجاح.'])
      : super(message, 'ORIGINAL_SALE_NOT_FOUND');
}

class InvalidReturnQuantityFailure extends ReturnsFailure {
  const InvalidReturnQuantityFailure([String message = 'كمية المرتجع غير صالحة أو تتجاوز الكمية المباعة المتبقية.'])
      : super(message, 'INVALID_RETURN_QUANTITY');
}

class InvalidReturnStateTransitionFailure extends ReturnsFailure {
  const InvalidReturnStateTransitionFailure([String message = 'حالة أمر المرتجع الحالية لا تسمح بهذا الإجراء.'])
      : super(message, 'INVALID_RETURN_STATE_TRANSITION');
}

class RefundProcessingFailure extends ReturnsFailure {
  const RefundProcessingFailure([String message = 'فشلت معالجة استرداد المبلغ المالي.'])
      : super(message, 'REFUND_PROCESSING_FAILURE');
}

class RefundAmountMismatchFailure extends ReturnsFailure {
  const RefundAmountMismatchFailure([String message = 'مبلغ الاسترداد لا يطابق إجمالي المرتجع المعتمد.'])
      : super(message, 'REFUND_AMOUNT_MISMATCH');
}

class SupplierReturnNotFoundFailure extends ReturnsFailure {
  const SupplierReturnNotFoundFailure([String message = 'أمر مرتجع المشتريات للمورد غير موجود.'])
      : super(message, 'SUPPLIER_RETURN_NOT_FOUND');
}

typedef OriginalPurchaseReceiptNotFoundFailure = SupplierReturnNotFoundFailure;

class InvalidSupplierReturnQuantityFailure extends ReturnsFailure {
  const InvalidSupplierReturnQuantityFailure([String message = 'كمية مرتجع المورد تتجاوز الكمية المستلمة في إيصال الشراء.'])
      : super(message, 'INVALID_SUPPLIER_RETURN_QUANTITY');
}

class ReturnsPermissionDeniedFailure extends ReturnsFailure {
  const ReturnsPermissionDeniedFailure([String message = 'المستخدم لا يملك الصلاحية الكافية لتنفيذ هذا الإجراء على المرتجع.'])
      : super(message, 'RETURNS_PERMISSION_DENIED');
}

class ReturnsBranchMismatchFailure extends ReturnsFailure {
  const ReturnsBranchMismatchFailure([String message = 'لا يمكن تنفيذ المرتجع على فرع مختلف عن الفرع المسند إليه.'])
      : super(message, 'RETURNS_BRANCH_MISMATCH');
}

class ReturnsBusinessMismatchFailure extends ReturnsFailure {
  const ReturnsBusinessMismatchFailure([String message = 'محاولة الوصول إلى بيانات مرتجعات متجر آخر محظورة.'])
      : super(message, 'RETURNS_BUSINESS_MISMATCH');
}
