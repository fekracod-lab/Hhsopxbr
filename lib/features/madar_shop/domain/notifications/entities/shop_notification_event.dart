// كيان أحداث التنبيهات وإشعارات المتجر (MADAR SHOP Notification Event Entity)
// Pure Dart — Zero UI Dependencies

enum ShopNotificationEventType {
  newMarketplaceOrder,       // ورود طلب جديد من تطبيق مدار يحتاج قبولاً فورياً
  orderCancelledByCustomer,  // قام الزبون بإلغاء الطلب
  lowStockWarning,           // وصول منتج إلى حد الخطر في المخزون
  outOfStockAlert,           // نفاد منتج تماماً
  shiftClosedSummary,        // إغلاق الوردية وتصفير الصندوق
  systemSecurityAlert;       // تنبيه أمني / دخول من جهاز غير معتمد

  bool get isHighPriorityAlert =>
      this == ShopNotificationEventType.newMarketplaceOrder ||
      this == ShopNotificationEventType.orderCancelledByCustomer;
}

class ShopNotificationEvent {
  final String eventId;
  final String businessId;
  final String branchId;
  final ShopNotificationEventType type;
  final String title;
  final String message;
  final String? referenceId; // e.g. orderId, productId
  final bool requiresAudioAlert;
  final bool isAcknowledged;
  final DateTime createdAt;

  const ShopNotificationEvent({
    required this.eventId,
    required this.businessId,
    required this.branchId,
    required this.type,
    required this.title,
    required this.message,
    this.referenceId,
    this.requiresAudioAlert = false,
    this.isAcknowledged = false,
    required this.createdAt,
  });

  ShopNotificationEvent copyWith({
    String? eventId,
    String? businessId,
    String? branchId,
    ShopNotificationEventType? type,
    String? title,
    String? message,
    String? referenceId,
    bool? requiresAudioAlert,
    bool? isAcknowledged,
    DateTime? createdAt,
  }) {
    return ShopNotificationEvent(
      eventId: eventId ?? this.eventId,
      businessId: businessId ?? this.businessId,
      branchId: branchId ?? this.branchId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      referenceId: referenceId ?? this.referenceId,
      requiresAudioAlert: requiresAudioAlert ?? this.requiresAudioAlert,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
