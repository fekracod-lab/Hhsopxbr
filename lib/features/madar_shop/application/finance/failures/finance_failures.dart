// إخفاقات واستثناءات النظام المالي وتكلفة المخزون (MADAR SHOP Finance Domain Failures)
// Pure Dart — Zero UI Dependencies

abstract class FinanceFailure implements Exception {
  final String message;
  final String code;

  const FinanceFailure(this.message, this.code);

  @override
  String toString() => '$runtimeType: $message ($code)';
}

class CostLayerNotFoundFailure extends FinanceFailure {
  const CostLayerNotFoundFailure([String message = 'طبقة تكلفة المخزون غير متوفرة لهذا الصنف.'])
      : super(message, 'COST_LAYER_NOT_FOUND');
}

class InsufficientCostLayersFailure extends FinanceFailure {
  const InsufficientCostLayersFailure([String message = 'طبقات تكلفة المخزون المتاحة غير كافية لتغطية الكمية المصروفة.'])
      : super(message, 'INSUFFICIENT_COST_LAYERS');
}

class InvalidFinancialAmountFailure extends FinanceFailure {
  const InvalidFinancialAmountFailure([String message = 'المبلغ المالي للقيد غير صالح (يجب ألا يكون سالباً).'])
      : super(message, 'INVALID_FINANCIAL_AMOUNT');
}

class FinancialPeriodInvalidFailure extends FinanceFailure {
  const FinancialPeriodInvalidFailure([String message = 'النطاق الزمني المحدد للفترة المالية غير صالح (تاريخ البداية بعد النهاية).'])
      : super(message, 'FINANCIAL_PERIOD_INVALID');
}

class FinancePermissionDeniedFailure extends FinanceFailure {
  const FinancePermissionDeniedFailure([String message = 'المستخدم لا يملك الصلاحية للعمليات المالية.'])
      : super(message, 'FINANCE_PERMISSION_DENIED');
}

class FinanceBranchMismatchFailure extends FinanceFailure {
  const FinanceBranchMismatchFailure([String message = 'تعارض في الفرع المحدد للعملية المالية.'])
      : super(message, 'FINANCE_BRANCH_MISMATCH');
}

class FinanceBusinessMismatchFailure extends FinanceFailure {
  const FinanceBusinessMismatchFailure([String message = 'محاولة الوصول إلى بيانات مالية لمتجر آخر محظورة.'])
      : super(message, 'FINANCE_BUSINESS_MISMATCH');
}
