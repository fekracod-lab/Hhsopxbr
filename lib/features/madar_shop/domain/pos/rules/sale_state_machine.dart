// آلة الحالة الصارمة لمعاملات البيع (MADAR SHOP POS Sale State Machine)
// Pure Dart — Zero UI Dependencies

import '../enums/sale_status.dart';

class SaleTransitionResult {
  final bool isAllowed;
  final String? rejectionReason;

  const SaleTransitionResult.success()
      : isAllowed = true,
        rejectionReason = null;

  const SaleTransitionResult.failure(this.rejectionReason) : isAllowed = false;
}

class SaleStateMachine {
  const SaleStateMachine._();

  /// التحقق الصارم من الانتقال القانوني بين حالات عملية البيع
  static SaleTransitionResult validateTransition({
    required SaleStatus currentStatus,
    required SaleStatus targetStatus,
    String? reason,
  }) {
    // 1. إذا كانت الحالة الحالية نهائية مغلقة
    if (currentStatus.isTerminal) {
      return SaleTransitionResult.failure(
        'لا يمكن تعديل المعاملة لأنها في حالة نهائية مغلقة (${currentStatus.displayNameAr}).',
      );
    }

    // 2. إذا كانت نفس الحالة
    if (currentStatus == targetStatus) {
      return const SaleTransitionResult.success();
    }

    // 3. مسار الإلغاء أو الفشل
    if (targetStatus == SaleStatus.cancelled || targetStatus == SaleStatus.failed) {
      if (reason == null || reason.trim().isEmpty) {
        return const SaleTransitionResult.failure('يجب تقديم سبب واضح لإلغاء أو فشل المعاملة.');
      }
      return const SaleTransitionResult.success();
    }

    // 4. الانتقالات القانونية خطوة بخطوة
    switch (currentStatus) {
      case SaleStatus.draft:
        // من المسودة يمكن الانتقال لانتظار الدفع أو الإتمام المباشر عند السداد الفوري
        if (targetStatus == SaleStatus.paymentPending || targetStatus == SaleStatus.completed) {
          return const SaleTransitionResult.success();
        }
        return SaleTransitionResult.failure(
          'لا يمكن الانتقال من ${currentStatus.displayNameAr} إلى ${targetStatus.displayNameAr}.',
        );

      case SaleStatus.paymentPending:
        // بعد انتظار الدفع يمكن الإتمام فقط
        if (targetStatus == SaleStatus.completed) {
          return const SaleTransitionResult.success();
        }
        return SaleTransitionResult.failure(
          'المعاملة بانتظار استلام الدفعات؛ لا يمكن الانتقال إلى ${targetStatus.displayNameAr}.',
        );

      case SaleStatus.completed:
      case SaleStatus.cancelled:
      case SaleStatus.failed:
        return const SaleTransitionResult.failure('المعاملة مكتملة ومغلقة نهائياً.');
    }
  }
}
