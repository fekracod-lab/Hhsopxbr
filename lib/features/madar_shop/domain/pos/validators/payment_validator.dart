// مدقق صحة الدفعات المالية والتخصيص (MADAR SHOP Payment Validator)
// Pure Dart — Zero UI Dependencies

import '../entities/payment.dart';
import '../entities/payment_allocation.dart';
import '../enums/payment_method.dart';
import '../value_objects/money.dart';

class PaymentValidationResult {
  final bool isValid;
  final String? errorMessage;

  const PaymentValidationResult.success()
      : isValid = true,
        errorMessage = null;

  const PaymentValidationResult.failure(this.errorMessage) : isValid = false;
}

class PaymentValidator {
  const PaymentValidator._();

  static PaymentValidationResult validate({
    required PaymentAllocation allocation,
    required String? customerId,
  }) {
    final currency = allocation.grandTotal.currency;

    // 1. التحقق من وجود دفعات إذا كان الإجمالي أكبر من صفر
    if (allocation.grandTotal.isPositive && allocation.payments.isEmpty) {
      return const PaymentValidationResult.failure('لم يتم تقديم أي دفعة لتسديد الفاتورة.');
    }

    // 2. التحقق من كل دفعة على حدة
    final Set<String> seenIds = {};
    for (final payment in allocation.payments) {
      if (payment.amount.currency != currency) {
        return PaymentValidationResult.failure(
          'عملة الدفعة (${payment.amount.currency.code}) لا تطابق عملة الفاتورة (${currency.code}).',
        );
      }
      if (payment.amount <= Money.zero(currency)) {
        return const PaymentValidationResult.failure('مبلغ الدفعة يجب أن يكون أكبر من صفر.');
      }
      if (seenIds.contains(payment.id)) {
        return const PaymentValidationResult.failure('توجد دفعة مكررة بنفس المعرف.');
      }
      seenIds.add(payment.id);
    }

    // 3. التحقق الصارم من البيع الآجل (Credit Sale Invariant)
    if (allocation.hasCredit) {
      if (customerId == null || customerId.trim().isEmpty) {
        return const PaymentValidationResult.failure(
          'لا يمكن إجراء بيع آجل أو تسجيل ذمة بدون تحديد حساب العميل.',
        );
      }
    }

    // 4. التحقق من تغطية كامل المبلغ المطلوب
    if (!allocation.isFullyAllocated) {
      return PaymentValidationResult.failure(
        'المبلغ المدفوع غير كافٍ. المتبقي: ${allocation.remainingTotal}',
      );
    }

    // 5. التحقق من أن الزيادة في الدفع (الـ Change) ناتجة فقط عن الدفع النقدي
    if (allocation.paidTotal > allocation.grandTotal) {
      final nonCashTotal = allocation.payments
          .where((p) => p.method != PaymentMethod.cash)
          .fold(Money.zero(currency), (sum, p) => sum + p.amount);

      if (nonCashTotal > allocation.grandTotal) {
        return const PaymentValidationResult.failure(
          'لا يمكن زيادة الدفع في العمليات غير النقدية (البطاقات أو الذمم).',
        );
      }
    }

    return const PaymentValidationResult.success();
  }
}
