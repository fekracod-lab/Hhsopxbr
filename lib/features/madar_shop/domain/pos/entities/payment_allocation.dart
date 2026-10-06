// كيان توزيع وتخصيص الدفعات المالية لنقطة البيع (MADAR SHOP Payment Allocation Entity)
// Pure Dart — Zero UI Dependencies

import '../enums/payment_method.dart';
import '../value_objects/money.dart';
import 'payment.dart';

class PaymentAllocation {
  final Money grandTotal;
  final List<Payment> payments;

  const PaymentAllocation({
    required this.grandTotal,
    this.payments = const [],
  });

  /// إجمالي المبالغ المدفوعة (بما فيها الآجل إن وجد)
  Money get paidTotal {
    if (payments.isEmpty) return Money.zero(grandTotal.currency);
    return payments.fold(
      Money.zero(grandTotal.currency),
      (sum, p) => sum + p.amount,
    );
  }

  /// إجمالي الدفعات النقدية والبنكية والرقمية (بدون الآجل)
  Money get immediatePaidTotal {
    if (payments.isEmpty) return Money.zero(grandTotal.currency);
    return payments
        .where((p) => p.method != PaymentMethod.credit)
        .fold(Money.zero(grandTotal.currency), (sum, p) => sum + p.amount);
  }

  /// إجمالي المبلغ الآجل (على الحساب)
  Money get creditAmountTotal {
    if (payments.isEmpty) return Money.zero(grandTotal.currency);
    return payments
        .where((p) => p.method == PaymentMethod.credit)
        .fold(Money.zero(grandTotal.currency), (sum, p) => sum + p.amount);
  }

  /// المبلغ المتبقي غير المغطى
  Money get remainingTotal {
    if (paidTotal >= grandTotal) return Money.zero(grandTotal.currency);
    return grandTotal - paidTotal;
  }

  /// باقي العميل المسترجع عند الدفع النقدي الزائد
  Money get changeTotal {
    if (paidTotal <= grandTotal) return Money.zero(grandTotal.currency);
    // باقي الصرف يحسب فقط من الزيادة في الدفع النقدي
    return paidTotal - grandTotal;
  }

  /// هل تمت تغطية قيمة الفاتورة بالكامل (سواء كاش، بطاقة، أو آجل مسجل)
  bool get isFullyAllocated => paidTotal >= grandTotal;

  /// هل تتضمن المعاملة بيعاً آجلاً
  bool get hasCredit => payments.any((p) => p.method == PaymentMethod.credit);

  PaymentAllocation addPayment(Payment payment) {
    if (payment.amount <= Money.zero(grandTotal.currency)) {
      throw ArgumentError('يجب أن تكون قيمة الدفعة أكبر من صفر.');
    }
    return PaymentAllocation(
      grandTotal: grandTotal,
      payments: [...payments, payment],
    );
  }
}
