import '../entities/refund_ledger_record.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

/// حاسبة الاسترداد المالي ومنع الإفراط (Server-Authoritative Refund Calculator)
class RefundCalculator {
  const RefundCalculator();

  /// التحقق من صحة مبلغ الاسترداد ومنع الاسترداد المزدوج أو الزائد
  static RefundLedgerRecord calculateValidRefund({
    required String refundRequestId,
    required String orderId,
    required String orderSource,
    required String customerId,
    required int requestedRefundAmount,
    required int requestedRefundPoints,
    required int originalOrderAmount,
    required int totalPreviouslyRefundedAmount,
    required String reason,
    required String idempotencyKey,
  }) {
    if (originalOrderAmount <= 0) {
      throw const SecurityViolationException(
        'قيمة الطلب الأصلية غير صالحة للاسترداد',
        type: SecurityViolationType.unauthorizedFinancialMutation,
      );
    }

    if (requestedRefundAmount < 0 || requestedRefundPoints < 0) {
      throw const SecurityViolationException(
        'مبالغ الاسترداد لا يمكن أن تكون سالبة',
        type: SecurityViolationType.unauthorizedFinancialMutation,
      );
    }

    if (requestedRefundAmount == 0 && requestedRefundPoints == 0) {
      throw const SecurityViolationException(
        'يجب تحديد مبلغ أو نقاط للاسترداد',
        type: SecurityViolationType.unauthorizedFinancialMutation,
      );
    }

    final maxRemainingRefundable = originalOrderAmount - totalPreviouslyRefundedAmount;

    if (maxRemainingRefundable <= 0) {
      throw const SecurityViolationException(
        'تم استرداد كامل قيمة هذا الطلب مسبقاً',
        type: SecurityViolationType.unauthorizedFinancialMutation,
      );
    }

    if (requestedRefundAmount > maxRemainingRefundable) {
      throw SecurityViolationException(
        'مبلغ الاسترداد المطلوب ($requestedRefundAmount د.ع) يتجاوز الحد المتبقي القابل للاسترداد ($maxRemainingRefundable د.ع)',
        type: SecurityViolationType.unauthorizedFinancialMutation,
      );
    }

    return RefundLedgerRecord(
      id: 'ref-rec-$orderId-${DateTime.now().millisecondsSinceEpoch}',
      refundRequestId: refundRequestId,
      orderId: orderId,
      orderSource: orderSource,
      customerId: customerId,
      refundAmount: requestedRefundAmount,
      refundPoints: requestedRefundPoints,
      originalOrderAmount: originalOrderAmount,
      reason: reason,
      idempotencyKey: idempotencyKey,
      processedAt: DateTime.now(),
    );
  }
}
