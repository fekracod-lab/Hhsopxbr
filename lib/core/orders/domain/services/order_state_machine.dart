import '../enums/order_enums.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

/// آلة حالات الطلبات الموحدة في مدار (Unified Order State Machine)
class OrderStateMachine {
  const OrderStateMachine();

  /// جدول الانتقالات القانونية الصارمة لكل حالة
  static const Map<UnifiedOrderStatus, Set<UnifiedOrderStatus>> _legalTransitions = {
    UnifiedOrderStatus.pending: {
      UnifiedOrderStatus.confirmed,
      UnifiedOrderStatus.preparing,
      UnifiedOrderStatus.cancelled,
      UnifiedOrderStatus.failed,
    },
    UnifiedOrderStatus.confirmed: {
      UnifiedOrderStatus.preparing,
      UnifiedOrderStatus.ready,
      UnifiedOrderStatus.cancelled,
      UnifiedOrderStatus.failed,
    },
    UnifiedOrderStatus.preparing: {
      UnifiedOrderStatus.ready,
      UnifiedOrderStatus.assigned,
      UnifiedOrderStatus.delivering,
      UnifiedOrderStatus.cancelled,
      UnifiedOrderStatus.failed,
    },
    UnifiedOrderStatus.ready: {
      UnifiedOrderStatus.assigned,
      UnifiedOrderStatus.delivering,
      UnifiedOrderStatus.pickedUp,
      UnifiedOrderStatus.cancelled,
    },
    UnifiedOrderStatus.assigned: {
      UnifiedOrderStatus.delivering,
      UnifiedOrderStatus.pickedUp,
      UnifiedOrderStatus.cancelled,
      UnifiedOrderStatus.failed,
    },
    UnifiedOrderStatus.delivering: {
      UnifiedOrderStatus.pickedUp,
      UnifiedOrderStatus.completed,
      UnifiedOrderStatus.failed,
    },
    UnifiedOrderStatus.pickedUp: {
      UnifiedOrderStatus.delivering,
      UnifiedOrderStatus.completed,
      UnifiedOrderStatus.failed,
    },
    UnifiedOrderStatus.completed: {}, // حالة نهائية لا تقبل أي انتقال
    UnifiedOrderStatus.cancelled: {}, // حالة نهائية لا تقبل أي انتقال
    UnifiedOrderStatus.failed: {}, // حالة نهائية لا تقبل أي انتقال
  };

  /// التحقق من قانونية الانتقال بين حالتين
  static bool canTransition(UnifiedOrderStatus current, UnifiedOrderStatus next) {
    if (current == next) return true; // نفس الحالة مقبولة (Idempotent)
    final allowed = _legalTransitions[current];
    return allowed != null && allowed.contains(next);
  }

  /// التحقق الصارم مع رمي استثناء عند محاولة تجاوز المسار القانوني
  static void assertValidTransition(UnifiedOrderStatus current, UnifiedOrderStatus next) {
    if (!canTransition(current, next)) {
      throw SecurityViolationException(
        'انتقال غير قانوني في حالة الطلب من (${current.key}) إلى (${next.key})',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'status',
      );
    }
  }

  /// هل الطلب في حالة قابلة للإلغاء من قبل العميل؟
  static bool canCancelOrder(UnifiedOrderStatus status) {
    switch (status) {
      case UnifiedOrderStatus.pending:
      case UnifiedOrderStatus.confirmed:
        return true;
      case UnifiedOrderStatus.preparing:
      case UnifiedOrderStatus.ready:
      case UnifiedOrderStatus.assigned:
      case UnifiedOrderStatus.delivering:
      case UnifiedOrderStatus.pickedUp:
      case UnifiedOrderStatus.completed:
      case UnifiedOrderStatus.cancelled:
      case UnifiedOrderStatus.failed:
        return false;
    }
  }
}
