/// تصنيف أنواع أحداث الإشعارات الموحدة في مدار
enum NotificationEventType {
  // Orders (Food, Store, Mersal)
  orderCreated('order.created'),
  orderConfirmed('order.confirmed'),
  orderPreparing('order.preparing'),
  orderReady('order.ready'),
  orderAssigned('order.assigned'),
  orderPickedUp('order.picked_up'),
  orderDelivered('order.delivered'),
  orderCancelled('order.cancelled'),

  // Rides (Taxi)
  rideRequested('ride.requested'),
  rideAccepted('ride.accepted'),
  rideDriverArriving('ride.driver_arriving'),
  rideStarted('ride.started'),
  rideCompleted('ride.completed'),
  rideCancelled('ride.cancelled'),

  // Driver & Captain Offers
  driverNewOffer('driver.new_offer'),
  driverOfferExpired('driver.offer_expired'),
  driverOfferRejected('driver.offer_rejected'),

  // Financial & Wallet
  paymentCompleted('payment.completed'),
  paymentFailed('payment.failed'),
  refundRequested('refund.requested'),
  refundCompleted('refund.completed'),
  walletDeposit('wallet.deposit'),
  walletWithdrawal('wallet.withdrawal'),

  // Security & Emergency
  securityViolation('security.violation'),
  emergencySos('emergency.sos'),

  // Chat & Communication
  chatMessage('chat.message'),
  systemBroadcast('system.broadcast'),
  marketing('marketing.promotion');

  final String key;
  const NotificationEventType(this.key);

  static NotificationEventType fromString(String? val) {
    if (val == null || val.isEmpty) return NotificationEventType.orderCreated;
    final normalized = val.trim().toLowerCase().replaceAll('_', '.');
    for (final type in NotificationEventType.values) {
      if (type.key == normalized || type.name.toLowerCase() == normalized.replaceAll('.', '')) {
        return type;
      }
    }
    return NotificationEventType.orderCreated;
  }
}

/// مستوى أولوية الإشعار (Notification Priority)
enum NotificationPriority {
  critical(100), // SOS, Security violations (لا يتم خنقه أو كتمه إطلاقاً)
  high(75), // عروض التكسي والتوصيل للكباتن، تغييرات السائق الحساسة
  normal(50), // تحديثات حالة الطلب والرسائل
  low(25), // الترويجات والإشعارات التسويقية
  background(10); // المزامنة الصامتة وتحديث البيانات الخلفية

  final int weight;
  const NotificationPriority(this.weight);

  bool get isCritical => this == NotificationPriority.critical;
  bool get isHighOrAbove => weight >= NotificationPriority.high.weight;
}

/// قنوات تسليم الإشعارات (Notification Channels)
enum NotificationChannel {
  push('push'),
  local('local'),
  inApp('in_app'),
  sound('sound'),
  badge('badge'),
  sms('sms'),
  whatsapp('whatsapp');

  final String key;
  const NotificationChannel(this.key);
}

/// حالات تسليم الإشعار (Delivery Status State Machine)
enum DeliveryStatus {
  pending('pending'),
  queued('queued'),
  sending('sending'),
  sent('sent'),
  delivered('delivered'),
  read('read'),
  failed('failed'),
  retrying('retrying'),
  expired('expired'),
  suppressed('suppressed');

  final String key;
  const DeliveryStatus(this.key);

  static DeliveryStatus fromString(String? val) {
    if (val == null || val.isEmpty) return DeliveryStatus.pending;
    final normalized = val.trim().toLowerCase();
    for (final status in DeliveryStatus.values) {
      if (status.key == normalized) return status;
    }
    return DeliveryStatus.pending;
  }
}

/// تصنيف فئة الإشعار (Notification Category)
enum NotificationCategory {
  orders('orders'),
  rides('rides'),
  financial('financial'),
  security('security'),
  emergency('emergency'),
  messages('messages'),
  marketing('marketing'),
  system('system');

  final String key;
  const NotificationCategory(this.key);
}
