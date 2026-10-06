// آلة حالات دورة حياة أمر الشراء (MADAR SHOP Purchase Order State Machine)
// Pure Dart — Zero UI Dependencies

import '../enums/purchase_order_status.dart';

class PurchaseOrderStateValidation {
  final bool isAllowed;
  final String? rejectionReason;

  const PurchaseOrderStateValidation.allowed()
      : isAllowed = true,
        rejectionReason = null;

  const PurchaseOrderStateValidation.rejected(this.rejectionReason)
      : isAllowed = false;
}

class PurchaseOrderStateMachine {
  const PurchaseOrderStateMachine._();

  /// التحقق من صحة وقانونية الانتقال بين حالات أمر الشراء
  static PurchaseOrderStateValidation validateTransition({
    required PurchaseOrderStatus currentStatus,
    required PurchaseOrderStatus nextStatus,
    bool hasReceivedItems = false,
  }) {
    if (currentStatus == nextStatus) {
      return const PurchaseOrderStateValidation.allowed();
    }

    // الحالات النهائية المغلقة والملغاة لا يمكن تغييرها
    if (currentStatus.isTerminal) {
      return PurchaseOrderStateValidation.rejected(
        'لا يمكن تعديل حالة أمر شراء بحالة نهائية (${currentStatus.name}).',
      );
    }

    switch (currentStatus) {
      case PurchaseOrderStatus.draft:
        if (nextStatus == PurchaseOrderStatus.submitted ||
            nextStatus == PurchaseOrderStatus.cancelled) {
          return const PurchaseOrderStateValidation.allowed();
        }
        return PurchaseOrderStateValidation.rejected(
          'أمر الشراء بحالة مسودة يمكن فقط إرساله للاعتماد (SUBMITTED) أو إلغاؤه (CANCELLED).',
        );

      case PurchaseOrderStatus.submitted:
        if (nextStatus == PurchaseOrderStatus.approved ||
            nextStatus == PurchaseOrderStatus.cancelled ||
            nextStatus == PurchaseOrderStatus.draft) {
          return const PurchaseOrderStateValidation.allowed();
        }
        return PurchaseOrderStateValidation.rejected(
          'أمر الشراء المقدم للاعتماد يمكن اعتماده (APPROVED)، إرجاعه لمسودة، أو إلغاؤه (CANCELLED).',
        );

      case PurchaseOrderStatus.approved:
        if (nextStatus == PurchaseOrderStatus.partiallyReceived ||
            nextStatus == PurchaseOrderStatus.received) {
          return const PurchaseOrderStateValidation.allowed();
        }
        if (nextStatus == PurchaseOrderStatus.cancelled) {
          if (hasReceivedItems) {
            return const PurchaseOrderStateValidation.rejected(
              'لا يمكن إلغاء أمر شراء معتمد تم استلام جزء من بضاعته؛ يجب إغلاقه أو إلغاء الكمية المتبقية فقط.',
            );
          }
          return const PurchaseOrderStateValidation.allowed();
        }
        return PurchaseOrderStateValidation.rejected(
          'أمر الشراء المعتمد ينتقل فقط إلى استلام جزئي أو كلي أو إلغاء قبل الاستلام.',
        );

      case PurchaseOrderStatus.partiallyReceived:
        if (nextStatus == PurchaseOrderStatus.partiallyReceived ||
            nextStatus == PurchaseOrderStatus.received ||
            nextStatus == PurchaseOrderStatus.closed) {
          return const PurchaseOrderStateValidation.allowed();
        }
        return PurchaseOrderStateValidation.rejected(
          'أمر الشراء المستلم جزئياً ينتقل إلى استلام إضافي أو مكتمل أو إغلاق للكميات المتبقية.',
        );

      case PurchaseOrderStatus.received:
        if (nextStatus == PurchaseOrderStatus.closed) {
          return const PurchaseOrderStateValidation.allowed();
        }
        return PurchaseOrderStateValidation.rejected(
          'أمر الشراء المستلم بالكامل يمكن فقط إغلاقه نهائياً (CLOSED).',
        );

      case PurchaseOrderStatus.closed:
      case PurchaseOrderStatus.cancelled:
        return PurchaseOrderStateValidation.rejected(
          'أمر الشراء في حالة نهائية مغلقة ولا يقبل أي تعديل.',
        );
    }
  }
}
