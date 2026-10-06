// آلة الحالة الصارمة لدورة حياة طلبات المتجر مع دعم التوصيل والاستلام
// MADAR SHOP Order State Machine with Multi-Fulfillment Support
// Pure Dart — Zero UI Dependencies

import '../entities/shop_order_status.dart';

class OrderTransitionResult {
  final bool isAllowed;
  final String? rejectionMessage;

  const OrderTransitionResult.success()
      : isAllowed = true,
        rejectionMessage = null;

  const OrderTransitionResult.failure(this.rejectionMessage)
      : isAllowed = false;
}

class ShopOrderStateMachine {
  const ShopOrderStateMachine._();

  /// التحقق الصارم من صحة الانتقال بين حالات الطلب مع مراعاة طريقة الاستلام والمصدر
  static OrderTransitionResult validateTransition({
    required ShopOrderStatus currentStatus,
    required ShopOrderStatus targetStatus,
    required ShopOrderSource source,
    ShopOrderFulfillment fulfillment = ShopOrderFulfillment.delivery,
    String? reason,
  }) {
    // 1. لا يمكن الانتقال من حالة نهائية مغلقة
    if (currentStatus.isTerminal) {
      return OrderTransitionResult.failure(
        'لا يمكن تعديل الطلب لأنه في حالة نهائية (${currentStatus.displayNameAr}).',
      );
    }

    // 2. إذا كانت الحالة المستهدفة هي ذاتها الحالة الحالية
    if (currentStatus == targetStatus) {
      return const OrderTransitionResult.success();
    }

    // 3. التحقق من الإلغاء أو الرفض
    if (targetStatus == ShopOrderStatus.cancelled ||
        targetStatus == ShopOrderStatus.rejected) {
      if (reason == null || reason.trim().isEmpty) {
        return const OrderTransitionResult.failure(
          'يجب تقديم سبب واضح لإلغاء أو رفض الطلب.',
        );
      }
      return const OrderTransitionResult.success();
    }

    // 4. قواعد الانتقال لطلبات البيع المباشر في المحل (In-Store POS Walk-in)
    if (source == ShopOrderSource.pos) {
      // الكاشير يسجل ويقبض فوراً: مسموح من pending ➔ accepted ➔ completed
      if (currentStatus == ShopOrderStatus.pending &&
          (targetStatus == ShopOrderStatus.accepted ||
              targetStatus == ShopOrderStatus.completed)) {
        return const OrderTransitionResult.success();
      }
      if (currentStatus == ShopOrderStatus.accepted &&
          targetStatus == ShopOrderStatus.completed) {
        return const OrderTransitionResult.success();
      }
    }

    // 5. قواعد الانتقال للطلبات المنظمة (Marketplace, Delivery, InStorePickup)
    switch (currentStatus) {
      case ShopOrderStatus.pending:
        if (targetStatus == ShopOrderStatus.accepted) {
          return const OrderTransitionResult.success();
        }
        return OrderTransitionResult.failure(
          'الطلب بانتظار الموافقة أولاً؛ لا يمكن الانتقال مباشرة إلى ${targetStatus.displayNameAr}.',
        );

      case ShopOrderStatus.accepted:
        if (targetStatus == ShopOrderStatus.preparing) {
          return const OrderTransitionResult.success();
        }
        if (targetStatus == ShopOrderStatus.ready ||
            targetStatus == ShopOrderStatus.readyForPickup) {
          return const OrderTransitionResult.success();
        }
        return OrderTransitionResult.failure(
          'بعد القبول، يجب بدء التجهيز (${ShopOrderStatus.preparing.displayNameAr}) أو تحديد الجاهزية.',
        );

      case ShopOrderStatus.preparing:
        if (fulfillment == ShopOrderFulfillment.inStorePickup ||
            fulfillment == ShopOrderFulfillment.dineIn) {
          if (targetStatus == ShopOrderStatus.readyForPickup ||
              targetStatus == ShopOrderStatus.ready) {
            return const OrderTransitionResult.success();
          }
        } else {
          if (targetStatus == ShopOrderStatus.ready) {
            return const OrderTransitionResult.success();
          }
        }
        return OrderTransitionResult.failure(
          'الطلب قيد التجهيز؛ يجب تأكيد الجاهزية قبل المتابعة.',
        );

      case ShopOrderStatus.ready:
      case ShopOrderStatus.readyForPickup:
        // مسار التوصيل مع الكابتن
        if (targetStatus == ShopOrderStatus.delivering) {
          return const OrderTransitionResult.success();
        }
        // مسار الاستلام من المحل
        if (targetStatus == ShopOrderStatus.pickedUp ||
            targetStatus == ShopOrderStatus.completed) {
          return const OrderTransitionResult.success();
        }
        return OrderTransitionResult.failure(
          'الطلب جاهز؛ يمكن تسليمه للكابتن أو للزبون أو إتمامه.',
        );

      case ShopOrderStatus.pickedUp:
        if (targetStatus == ShopOrderStatus.completed) {
          return const OrderTransitionResult.success();
        }
        return OrderTransitionResult.failure(
          'تم استلام الطلب؛ الخطوة التالية هي الإتمام النهائي.',
        );

      case ShopOrderStatus.delivering:
        if (targetStatus == ShopOrderStatus.completed) {
          return const OrderTransitionResult.success();
        }
        return OrderTransitionResult.failure(
          'الطلب في طريق التوصيل؛ الخطوة التالية هي الإتمام والتسليم فقط.',
        );

      case ShopOrderStatus.completed:
      case ShopOrderStatus.rejected:
      case ShopOrderStatus.cancelled:
        return const OrderTransitionResult.failure(
          'الطلب مغلق ومكتمل بالفعل.',
        );
    }
  }

  /// تحديد قائمة الحالات المتاحة للانتقال إليها من الحالة الحالية
  static List<ShopOrderStatus> getAvailableNextStatuses({
    required ShopOrderStatus currentStatus,
    required ShopOrderSource source,
    ShopOrderFulfillment fulfillment = ShopOrderFulfillment.delivery,
  }) {
    if (currentStatus.isTerminal) return const [];

    final List<ShopOrderStatus> available = [];
    for (final status in ShopOrderStatus.values) {
      if (status == currentStatus) continue;
      final result = validateTransition(
        currentStatus: currentStatus,
        targetStatus: status,
        source: source,
        fulfillment: fulfillment,
        reason: 'check_validity',
      );
      if (result.isAllowed) {
        available.add(status);
      }
    }
    return available;
  }
}
