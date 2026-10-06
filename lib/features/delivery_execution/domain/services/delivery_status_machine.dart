import 'package:flutter/material.dart';
import '../entities/delivery_execution_models.dart';

/// آلة الحالات الصارمة لمسار التوصيل الميداني (Pure Domain State Machine)
class DeliveryStatusMachine {
  static const Map<DeliveryExecutionStatus, List<DeliveryExecutionStatus>> _allowedTransitions = {
    DeliveryExecutionStatus.pending: [
      DeliveryExecutionStatus.accepted,
      DeliveryExecutionStatus.cancelled,
    ],
    DeliveryExecutionStatus.accepted: [
      DeliveryExecutionStatus.headingToPickup,
      DeliveryExecutionStatus.arrivedAtPickup, // Shortcut for fast arrival
      DeliveryExecutionStatus.cancelled,
    ],
    DeliveryExecutionStatus.headingToPickup: [
      DeliveryExecutionStatus.arrivedAtPickup,
      DeliveryExecutionStatus.cancelled,
    ],
    DeliveryExecutionStatus.arrivedAtPickup: [
      DeliveryExecutionStatus.pickedUp,
      DeliveryExecutionStatus.cancelled,
    ],
    DeliveryExecutionStatus.pickedUp: [
      DeliveryExecutionStatus.headingToCustomer,
      DeliveryExecutionStatus.arrivedAtCustomer,
      DeliveryExecutionStatus.delivered,
      DeliveryExecutionStatus.cancelled, // exceptional cancel
    ],
    DeliveryExecutionStatus.headingToCustomer: [
      DeliveryExecutionStatus.arrivedAtCustomer,
      DeliveryExecutionStatus.delivered,
      DeliveryExecutionStatus.cancelled,
    ],
    DeliveryExecutionStatus.arrivedAtCustomer: [
      DeliveryExecutionStatus.delivered,
      DeliveryExecutionStatus.cancelled,
    ],
    DeliveryExecutionStatus.delivered: [],
    DeliveryExecutionStatus.cancelled: [],
  };

  /// التحقق مما إذا كان الانتقال مسموحاً وقانونياً
  static bool canTransition(DeliveryExecutionStatus current, DeliveryExecutionStatus next) {
    if (current == next) return false;
    final allowed = _allowedTransitions[current] ?? const [];
    return allowed.contains(next);
  }

  /// الإجراء التالي التلقائي للكابتن أثناء القيادة
  static DeliveryExecutionStatus? getNextAction(DeliveryExecutionStatus current) {
    switch (current) {
      case DeliveryExecutionStatus.accepted:
        return DeliveryExecutionStatus.headingToPickup;
      case DeliveryExecutionStatus.headingToPickup:
        return DeliveryExecutionStatus.arrivedAtPickup;
      case DeliveryExecutionStatus.arrivedAtPickup:
        return DeliveryExecutionStatus.pickedUp;
      case DeliveryExecutionStatus.pickedUp:
        return DeliveryExecutionStatus.headingToCustomer;
      case DeliveryExecutionStatus.headingToCustomer:
        return DeliveryExecutionStatus.arrivedAtCustomer;
      case DeliveryExecutionStatus.arrivedAtCustomer:
        return DeliveryExecutionStatus.delivered;
      default:
        return null;
    }
  }

  /// هل يمكن إلغاء الطلب في هذه الحالة؟
  static bool canCancel(DeliveryExecutionStatus status) {
    return status != DeliveryExecutionStatus.delivered &&
           status != DeliveryExecutionStatus.cancelled;
  }

  /// عنوان الزر الأساسي للكابتن
  static String getDriverActionButtonLabel(DeliveryExecutionStatus status) {
    switch (status) {
      case DeliveryExecutionStatus.pending:
        return 'قبول طلب التوصيل';
      case DeliveryExecutionStatus.accepted:
        return 'بدء التحرك لنقطة الاستلام';
      case DeliveryExecutionStatus.headingToPickup:
        return 'تأكيد الوصول لنقطة الاستلام';
      case DeliveryExecutionStatus.arrivedAtPickup:
        return 'تم استلام الشحنة وبدء التوصيل';
      case DeliveryExecutionStatus.pickedUp:
        return 'الانطلاق نحو الزبون';
      case DeliveryExecutionStatus.headingToCustomer:
        return 'تأكيد الوصول لعنوان الزبون';
      case DeliveryExecutionStatus.arrivedAtCustomer:
        return 'تأكيد تسليم الطلب واستلام المبلغ';
      case DeliveryExecutionStatus.delivered:
        return 'تم إكمال التوصيل بنجاح';
      case DeliveryExecutionStatus.cancelled:
        return 'الطلب ملغي';
    }
  }

  /// وصف الحالة باللغة العربية للزبون
  static String getCustomerStatusLabel(DeliveryExecutionStatus status) {
    switch (status) {
      case DeliveryExecutionStatus.pending:
        return 'بانتظار قبول المندوب';
      case DeliveryExecutionStatus.accepted:
        return 'تم تعيين المندوب وقبول الطلب';
      case DeliveryExecutionStatus.headingToPickup:
        return 'المندوب في الطريق للمحل/نقطة الاستلام';
      case DeliveryExecutionStatus.arrivedAtPickup:
        return 'المندوب وصل لنقطة الاستلام ويجهز الطلب';
      case DeliveryExecutionStatus.pickedUp:
        return 'تم استلام طلبك وهو في الطريق إليك!';
      case DeliveryExecutionStatus.headingToCustomer:
        return 'المندوب متوجه إليك الآن';
      case DeliveryExecutionStatus.arrivedAtCustomer:
        return 'المندوب وصل عند موقعك!';
      case DeliveryExecutionStatus.delivered:
        return 'تم تسليم الطلب بنجاح';
      case DeliveryExecutionStatus.cancelled:
        return 'تم إلغاء الطلب';
    }
  }

  /// لون الحالة للتصميم
  static Color getStatusColor(DeliveryExecutionStatus status) {
    switch (status) {
      case DeliveryExecutionStatus.pending:
        return const Color(0xFFFFB300); // Amber
      case DeliveryExecutionStatus.accepted:
        return const Color(0xFF0284C7); // Blue
      case DeliveryExecutionStatus.headingToPickup:
      case DeliveryExecutionStatus.arrivedAtPickup:
        return const Color(0xFF8B5CF6); // Purple
      case DeliveryExecutionStatus.pickedUp:
      case DeliveryExecutionStatus.headingToCustomer:
        return const Color(0xFF00BFA5); // Teal
      case DeliveryExecutionStatus.arrivedAtCustomer:
        return const Color(0xFFF97316); // Orange
      case DeliveryExecutionStatus.delivered:
        return const Color(0xFF10B981); // Green
      case DeliveryExecutionStatus.cancelled:
        return const Color(0xFFEF4444); // Red
    }
  }

  /// رقم الخطوة الحالية للـ Stepper (من 0 إلى 4)
  static int getStepIndex(DeliveryExecutionStatus status) {
    switch (status) {
      case DeliveryExecutionStatus.pending:
        return 0;
      case DeliveryExecutionStatus.accepted:
      case DeliveryExecutionStatus.headingToPickup:
        return 1;
      case DeliveryExecutionStatus.arrivedAtPickup:
      case DeliveryExecutionStatus.pickedUp:
        return 2;
      case DeliveryExecutionStatus.headingToCustomer:
      case DeliveryExecutionStatus.arrivedAtCustomer:
        return 3;
      case DeliveryExecutionStatus.delivered:
        return 4;
      case DeliveryExecutionStatus.cancelled:
        return 0;
    }
  }
}
