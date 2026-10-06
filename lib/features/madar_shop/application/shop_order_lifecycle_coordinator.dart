// منسق دورة حياة الطلبات والتنبيهات الصوتية (MADAR SHOP Order Lifecycle Coordinator)
// Application Layer — Decoupled State & Orchestration

import '../domain/audit/contracts/shop_audit_repository.dart';
import '../domain/audit/entities/shop_audit_entry.dart';
import '../domain/identity/rbac/shop_permission.dart';
import '../domain/notifications/contracts/shop_alert_audio_bridge.dart';
import '../domain/orders/entities/shop_order.dart';
import '../domain/orders/entities/shop_order_status.dart';
import '../domain/orders/lifecycle/shop_order_state_machine.dart';
import 'shop_identity_coordinator.dart';

class OrderTransitionException implements Exception {
  final String message;
  const OrderTransitionException(this.message);
  @override
  String toString() => message;
}

class ShopOrderLifecycleCoordinator {
  final ShopIdentityCoordinator _identityCoordinator;
  final IShopAlertAudioBridge _audioBridge;
  final IShopAuditRepository _auditRepository;

  ShopOrderLifecycleCoordinator({
    required ShopIdentityCoordinator identityCoordinator,
    required IShopAlertAudioBridge audioBridge,
    required IShopAuditRepository auditRepository,
  })  : _identityCoordinator = identityCoordinator,
        _audioBridge = audioBridge,
        _auditRepository = auditRepository;

  /// معالجة انتقال حالة الطلب مع التحقق الصارم من الصلاحيات والتسجيل في سجل التدقيق
  Future<ShopOrder> transitionOrder({
    required ShopOrder currentOrder,
    required ShopOrderStatus targetStatus,
    String? reason,
  }) async {
    // 1. التحقق من صلاحيات المستخدم الحالي
    _validateUserPermissionForTransition(targetStatus);

    // 2. التحقق من آلة الحالة الصارمة مع مراعاة طريقة الاستلام
    final validation = ShopOrderStateMachine.validateTransition(
      currentStatus: currentOrder.status,
      targetStatus: targetStatus,
      source: currentOrder.source,
      fulfillment: currentOrder.fulfillment,
      reason: reason,
    );

    if (!validation.isAllowed) {
      throw OrderTransitionException(
        validation.rejectionMessage ?? 'انتقال حالة الطلب غير مسموح به.',
      );
    }

    // 3. إدارة التنبيه الصوتي
    if (targetStatus == ShopOrderStatus.accepted ||
        targetStatus == ShopOrderStatus.rejected ||
        targetStatus == ShopOrderStatus.cancelled) {
      // إيقاف رنين الإشعار المتكرر فور تفاعل الكاشير
      await _audioBridge.stopOrderIncomingLoop(orderId: currentOrder.orderId);
    }

    // 4. بناء الكيان بعد التحديث وزيادة رقم الإصدار
    final updatedOrder = currentOrder.copyWith(
      status: targetStatus,
      version: currentOrder.version + 1,
      cancelOrRejectReason: reason ?? currentOrder.cancelOrRejectReason,
      updatedAt: DateTime.now(),
    );

    // 5. تسجيل العمليات الحساسة (إلغاء / رفض) في سجل التدقيق غير القابل للتعديل
    if (targetStatus == ShopOrderStatus.cancelled ||
        targetStatus == ShopOrderStatus.rejected) {
      final user = _identityCoordinator.currentUser;
      final session = _identityCoordinator.currentSession;

      await _auditRepository.recordAuditEntry(
        ShopAuditEntry(
          auditId: 'AUDIT-${DateTime.now().millisecondsSinceEpoch}',
          businessId: currentOrder.businessId,
          branchId: currentOrder.branchId,
          userId: user?.userId ?? 'SYSTEM',
          userName: user?.fullName ?? 'System Automated',
          terminalId: session?.terminalId ?? 'SERVER',
          action: ShopAuditAction.orderVoided,
          referenceId: currentOrder.orderId,
          beforeState: {'status': currentOrder.status.toDbString()},
          afterState: {'status': targetStatus.toDbString()},
          reason: reason,
          timestamp: DateTime.now(),
        ),
      );
    }

    return updatedOrder;
  }

  /// تنبيه وصول طلب ماركت بليس جديد (تشغيل الرنين الصاخب المتكرر)
  Future<void> handleNewIncomingMarketplaceOrder(ShopOrder order) async {
    if (order.source == ShopOrderSource.marketplace &&
        order.status == ShopOrderStatus.pending) {
      await _audioBridge.startOrderIncomingLoop(orderId: order.orderId);
    }
  }

  void _validateUserPermissionForTransition(ShopOrderStatus targetStatus) {
    if (!_identityCoordinator.isAuthenticated) {
      throw const OrderTransitionException('يجب تسجيل الدخول أولاً لتعديل حالة الطلب.');
    }

    switch (targetStatus) {
      case ShopOrderStatus.accepted:
        if (!_identityCoordinator.hasPermission(ShopPermission.acceptOrder)) {
          throw const OrderTransitionException('ليس لديك صلاحية قبول الطلبات.');
        }
        break;
      case ShopOrderStatus.rejected:
        if (!_identityCoordinator.hasPermission(ShopPermission.rejectOrder)) {
          throw const OrderTransitionException('ليس لديك صلاحية رفض الطلبات.');
        }
        break;
      case ShopOrderStatus.ready:
      case ShopOrderStatus.readyForPickup:
        if (!_identityCoordinator.hasPermission(ShopPermission.markOrderReady)) {
          throw const OrderTransitionException('ليس لديك صلاحية تأكيد جاهزية الطلب.');
        }
        break;
      case ShopOrderStatus.delivering:
      case ShopOrderStatus.pickedUp:
        if (!_identityCoordinator.hasPermission(ShopPermission.dispatchOrder)) {
          throw const OrderTransitionException('ليس لديك صلاحية تسليم الطلب.');
        }
        break;
      case ShopOrderStatus.cancelled:
        if (!_identityCoordinator.hasPermission(ShopPermission.cancelActiveOrder)) {
          throw const OrderTransitionException('ليس لديك صلاحية إلغاء الطلبات النشطة.');
        }
        break;
      default:
        break;
    }
  }
}
