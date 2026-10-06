import '../entities/security_models.dart';

/// حارس الصلاحيات والأدوار البرمجية (Role-Based Access Control Guard)
class PermissionGuard {
  const PermissionGuard();

  /// جدول الصلاحيات المسموحة لكل دور في مدار
  static final Map<MadarRole, Set<MadarPermission>> _rolePermissions = {
    MadarRole.customer: {
      MadarPermission.cancelOrder,
      MadarPermission.requestRefund,
    },
    MadarRole.driver: {
      MadarPermission.processWithdrawal,
      MadarPermission.broadcastEmergency,
    },
    MadarRole.taxiCaptain: {
      MadarPermission.processWithdrawal,
      MadarPermission.broadcastEmergency,
    },
    MadarRole.delivery: {
      MadarPermission.processWithdrawal,
      MadarPermission.broadcastEmergency,
    },
    MadarRole.deliveryCaptain: {
      MadarPermission.processWithdrawal,
      MadarPermission.broadcastEmergency,
    },
    MadarRole.restaurant: {
      MadarPermission.cancelOrder,
      MadarPermission.processWithdrawal,
    },
    MadarRole.store: {
      MadarPermission.cancelOrder,
      MadarPermission.processWithdrawal,
    },
    MadarRole.limitedAdmin: {
      MadarPermission.viewAuditLogs,
      MadarPermission.manageDrivers,
      MadarPermission.processRefund,
    },
    MadarRole.complaintsAdmin: {
      MadarPermission.viewAuditLogs,
      MadarPermission.processRefund,
    },
    MadarRole.admin: {
      MadarPermission.cancelOrder,
      MadarPermission.requestRefund,
      MadarPermission.processRefund,
      MadarPermission.viewAuditLogs,
      MadarPermission.manageDrivers,
      MadarPermission.modifyConfig,
      MadarPermission.processWithdrawal,
      MadarPermission.overridePrice,
      MadarPermission.broadcastEmergency,
      MadarPermission.directFinancialMutation,
    },
    MadarRole.superAdmin: {
      MadarPermission.cancelOrder,
      MadarPermission.requestRefund,
      MadarPermission.processRefund,
      MadarPermission.viewAuditLogs,
      MadarPermission.manageDrivers,
      MadarPermission.modifyConfig,
      MadarPermission.processWithdrawal,
      MadarPermission.overridePrice,
      MadarPermission.broadcastEmergency,
      MadarPermission.directFinancialMutation,
    },
    MadarRole.mainAdmin: {
      MadarPermission.cancelOrder,
      MadarPermission.requestRefund,
      MadarPermission.processRefund,
      MadarPermission.viewAuditLogs,
      MadarPermission.manageDrivers,
      MadarPermission.modifyConfig,
      MadarPermission.processWithdrawal,
      MadarPermission.overridePrice,
      MadarPermission.broadcastEmergency,
      MadarPermission.directFinancialMutation,
    },
  };

  /// هل يملك الدور هذه الصلاحية؟
  static bool hasPermission(MadarRole role, MadarPermission permission) {
    final perms = _rolePermissions[role];
    if (perms == null) return false;
    return perms.contains(permission);
  }

  /// التحقق من صلاحية إلغاء الطلب
  static bool canCancelOrder({
    required MadarRole role,
    required String orderStatus,
    required bool isOwner,
  }) {
    if (role.isAdmin) return true;
    if (!isOwner) return false;

    // لا يمكن للعميل إلغاء الطلب بعد تجهيزه أو تسليمه أو استلامه من المندوب
    const uncancelableStatuses = [
      'picked_up',
      'pickedUp',
      'heading_to_customer',
      'headingToCustomer',
      'arrived_at_customer',
      'arrivedAtCustomer',
      'delivered',
      'completed',
      'cancelled',
    ];

    return !uncancelableStatuses.contains(orderStatus);
  }

  /// التحقق من إمكانية رفع طلب استرداد مالي
  static bool canRequestRefund({
    required MadarRole role,
    required String paymentStatus,
    required String orderStatus,
  }) {
    if (role.isAdmin) return true;

    // يُسمح بطلب الاسترداد فقط إذا تم الدفع إلكترونياً/بالمحفظة وكان الطلب ملغياً أو واجه مشكلة
    final isPaidWallet = paymentStatus == 'paid_wallet' || paymentStatus == 'paid_online';
    final isCancelledOrFailed = orderStatus == 'cancelled' || orderStatus == 'failed' || orderStatus == 'refund_requested';

    return isPaidWallet && isCancelledOrFailed;
  }

  /// التحقق من الحظر التام للتعديل المالي المباشر من طرف العميل
  static bool canModifyFinancialFields(MadarRole role) {
    return role.isAdmin;
  }

  /// التحقق من صلاحية تغيير الدور
  static bool canChangeRole(MadarRole actorRole, MadarRole targetRole) {
    if (!actorRole.isAdmin) return false;
    if (targetRole == MadarRole.superAdmin || targetRole == MadarRole.mainAdmin) {
      return actorRole == MadarRole.superAdmin || actorRole == MadarRole.mainAdmin;
    }
    return true;
  }
}
