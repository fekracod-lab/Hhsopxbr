import '../entities/security_models.dart';

/// حارس العمليات المالية الموثقة (Financial Operation Guard)
class FinancialOperationGuard {
  const FinancialOperationGuard();

  /// الحد الأقصى لأي معاملة مالية فردية (50 مليون دينار عراقي كإجراء حماية من الفائض)
  static const double maxSingleTransactionLimit = 50000000.0;

  /// التحقق الصارم من سلامة حمولة المعاملة المالية
  static void validatePayload(FinancialOperationPayload payload) {
    // 1. فحص صحة المبلغ
    if (payload.amount.isNaN || payload.amount.isInfinite) {
      throw const SecurityViolationException(
        'المبلغ المالي غير صالح (NaN أو Infinite)',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'amount',
      );
    }

    if (payload.amount <= 0) {
      throw const SecurityViolationException(
        'المبلغ المالي يجب أن يكون أكبر من الصفر',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'amount',
      );
    }

    if (payload.amount > maxSingleTransactionLimit) {
      throw const SecurityViolationException(
        'المبلغ المالي يتجاوز الحد الأقصى المسموح به للمعاملة الواحدة',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'amount',
      );
    }

    // 2. فحص معرّف عدم التكرار (Idempotency Key)
    if (payload.idempotencyKey.trim().length < 8) {
      throw const SecurityViolationException(
        'مفتاح المعاملة الفريد (Idempotency Key) غير صالح أو قصير جداً',
        type: SecurityViolationType.invalidIdempotency,
        fieldName: 'idempotencyKey',
      );
    }

    // 3. فحص معرّف صاحب الحساب
    if (payload.sourceUserId.trim().isEmpty) {
      throw const SecurityViolationException(
        'معرّف صاحب الحساب المالي مفقود',
        type: SecurityViolationType.tamperedPayload,
        fieldName: 'sourceUserId',
      );
    }
  }

  /// التحقق من سلامة طلب الاسترداد المالي
  static void validateRefundRequest({
    required String orderId,
    required String userId,
    required double amount,
    required int points,
    required String idempotencyKey,
  }) {
    if (orderId.trim().isEmpty) {
      throw const SecurityViolationException(
        'معرّف الطلب المراد استرداده مفقود',
        type: SecurityViolationType.tamperedPayload,
        fieldName: 'orderId',
      );
    }

    if (userId.trim().isEmpty) {
      throw const SecurityViolationException(
        'معرّف المستخدم صاحب الاسترداد مفقود',
        type: SecurityViolationType.tamperedPayload,
        fieldName: 'userId',
      );
    }

    if (amount < 0 || amount.isNaN || amount.isInfinite) {
      throw const SecurityViolationException(
        'مبلغ الاسترداد المالي غير صالح',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'amount',
      );
    }

    if (points < 0) {
      throw const SecurityViolationException(
        'عدد نقاط الاسترداد غير صالح',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'points',
      );
    }

    if (amount == 0 && points == 0) {
      throw const SecurityViolationException(
        'لا يوجد مبلغ أو نقاط للاسترداد',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'amount/points',
      );
    }

    if (idempotencyKey.trim().length < 8) {
      throw const SecurityViolationException(
        'مفتاح الاسترداد الفريد غير صالح',
        type: SecurityViolationType.invalidIdempotency,
        fieldName: 'idempotencyKey',
      );
    }
  }
}
