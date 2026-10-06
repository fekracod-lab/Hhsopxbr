// قواعد وضوابط محرك المشتريات والمدفوعات (MADAR SHOP Purchasing Business Rules)
// Pure Dart — Zero UI Dependencies

import '../../inventory/value_objects/stock_quantity.dart';
import '../../pos/value_objects/money.dart';
import '../entities/supplier.dart';
import '../enums/over_receiving_policy.dart';
import '../enums/supplier_overpayment_policy.dart';

class PurchasingRuleValidation {
  final bool isAllowed;
  final String? rejectionReason;

  const PurchasingRuleValidation.allowed()
      : isAllowed = true,
        rejectionReason = null;

  const PurchasingRuleValidation.rejected(this.rejectionReason)
      : isAllowed = false;
}

class PurchasingRules {
  const PurchasingRules._();

  /// التحقق من صلاحية المورد للتعامل التجاري
  static PurchasingRuleValidation validateSupplierEligibility(Supplier supplier) {
    if (supplier.isBlocked) {
      return const PurchasingRuleValidation.rejected(
        'المورد محظور (BLOCKED)؛ لا يمكن إنشاء أو اعتماد أو استلام أوامر شراء له.',
      );
    }
    if (supplier.isInactive) {
      return const PurchasingRuleValidation.rejected(
        'المورد غير نشط (INACTIVE)؛ لا يمكن الشراء منه حتى إعادة تفعيله.',
      );
    }
    return const PurchasingRuleValidation.allowed();
  }

  /// التحقق من كمية الاستلام مقابل المتبقي وفقاً لسياسة الاستلام الزائد
  static PurchasingRuleValidation validateReceivingQuantity({
    required StockQuantity requestedQuantity,
    required StockQuantity remainingQuantity,
    required OverReceivingPolicy policy,
    bool hasApproval = false,
  }) {
    if (requestedQuantity.isZero || requestedQuantity.isNegative) {
      return const PurchasingRuleValidation.rejected(
        'كمية الاستلام يجب أن تكون أكبر من الصفر.',
      );
    }

    if (requestedQuantity <= remainingQuantity) {
      return const PurchasingRuleValidation.allowed();
    }

    // هناك استلام زائد (Over-receiving)
    switch (policy) {
      case OverReceivingPolicy.block:
        return PurchasingRuleValidation.rejected(
          'الكمية المستلمة ($requestedQuantity) تتجاوز الكمية المتبقية بأمر الشراء ($remainingQuantity). الاستلام الزائد محظور.',
        );

      case OverReceivingPolicy.allowWithApproval:
        if (!hasApproval) {
          return PurchasingRuleValidation.rejected(
            'الاستلام الزائد يتطلب موافقة صريحة من مسؤول المخازن أو المدير.',
          );
        }
        return const PurchasingRuleValidation.allowed();

      case OverReceivingPolicy.allow:
        return const PurchasingRuleValidation.allowed();
    }
  }

  /// التحقق من مبلغ سداد المورد مقابل الرصيد المستحق وفقاً لسياسة السداد الزائد
  static PurchasingRuleValidation validateSupplierPayment({
    required Money paymentAmount,
    required Money currentPayableBalance,
    required SupplierOverpaymentPolicy policy,
    bool hasApproval = false,
  }) {
    if (paymentAmount.isZero || paymentAmount.isNegative) {
      return const PurchasingRuleValidation.rejected(
        'مبلغ السداد يجب أن يكون أكبر من الصفر.',
      );
    }

    if (paymentAmount <= currentPayableBalance) {
      return const PurchasingRuleValidation.allowed();
    }

    // هناك سداد زائد يتجاوز الالتزام المالي المستحق للمورد
    switch (policy) {
      case SupplierOverpaymentPolicy.block:
        return PurchasingRuleValidation.rejected(
          'مبلغ السداد ($paymentAmount) يتجاوز الرصيد المستحق للمورد ($currentPayableBalance). السداد الزائد محظور.',
        );

      case SupplierOverpaymentPolicy.creditBalance:
        // مسموح وينتج عنه رصيد دائن لصالح المتجر (سلفة مورد)
        return const PurchasingRuleValidation.allowed();

      case SupplierOverpaymentPolicy.allowWithApproval:
        if (!hasApproval) {
          return PurchasingRuleValidation.rejected(
            'السداد الزائد يتطلب موافقة مالية معتمدة.',
          );
        }
        return const PurchasingRuleValidation.allowed();
    }
  }
}
