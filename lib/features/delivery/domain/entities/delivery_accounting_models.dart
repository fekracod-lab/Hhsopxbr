/// نوع العملية في سجلات التوصيل
enum DeliveryOrderType {
  foodOrder,
  storeOrder,
  rideDelivery,
  unknown;

  static DeliveryOrderType fromString(String? type) {
    switch (type) {
      case 'food_order':
        return DeliveryOrderType.foodOrder;
      case 'store_order':
        return DeliveryOrderType.storeOrder;
      case 'ride_delivery':
        return DeliveryOrderType.rideDelivery;
      default:
        return DeliveryOrderType.unknown;
    }
  }

  String toTypeString() {
    switch (this) {
      case DeliveryOrderType.foodOrder:
        return 'food_order';
      case DeliveryOrderType.storeOrder:
        return 'store_order';
      case DeliveryOrderType.rideDelivery:
        return 'ride_delivery';
      case DeliveryOrderType.unknown:
        return 'unknown';
    }
  }
}

/// سجل طلب التوصيل المجرد (Immutable Delivery Order Entity)
class DeliveryOrderRecord {
  final String id;
  final DeliveryOrderType type;
  final double totalAmount;
  final double deliveryFee;
  final DateTime createdAt;
  final String? customerName;
  final String? driverId;
  final String? restaurantId;
  final String? storeId;
  final Map<String, dynamic> rawData;

  const DeliveryOrderRecord({
    required this.id,
    required this.type,
    required this.totalAmount,
    required this.deliveryFee,
    required this.createdAt,
    this.customerName,
    this.driverId,
    this.restaurantId,
    this.storeId,
    this.rawData = const {},
  });
}

/// حالة التسوية والمحاسبة المالية للأسبوع
class PaymentStatusRecord {
  final String status; // 'paid' | 'unpaid' | 'postponed'
  final DateTime? postponedTo;
  final DateTime? updatedAt;

  const PaymentStatusRecord({
    required this.status,
    this.postponedTo,
    this.updatedAt,
  });

  bool get isPaid => status == 'paid';
  bool get isPostponed => status == 'postponed';
  bool get isUnpaid => status == 'unpaid';

  factory PaymentStatusRecord.unpaid() => const PaymentStatusRecord(status: 'unpaid');
}

/// ملخص المحاسبة الأسبوعية (Weekly Accounting Summary Entity)
class WeeklySummaryEntity {
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<DeliveryOrderRecord> orders;

  const WeeklySummaryEntity({
    required this.weekStart,
    required this.weekEnd,
    required this.orders,
  });

  /// إجمالي أجور التوصيل لجميع طلبات الأسبوع
  double get totalDeliveryFees {
    double sum = 0.0;
    for (final order in orders) {
      sum += order.deliveryFee;
    }
    return sum;
  }

  /// إجمالي مبيعات الطلبات
  double get totalOrdersAmount {
    double sum = 0.0;
    for (final order in orders) {
      sum += order.totalAmount;
    }
    return sum;
  }

  /// عمولة منصة مدار على الكباتن (500 د.ع لكل طلب مطعم أو متجر، و 0 على الدليفري المباشر)
  double get platformCommission {
    double sum = 0.0;
    for (final order in orders) {
      if (order.type == DeliveryOrderType.foodOrder || order.type == DeliveryOrderType.storeOrder) {
        sum += 500.0;
      }
    }
    return sum;
  }

  /// صافي أرباح ومستحقات الكباتن بعد استقطاع عمولة المنصة
  double get netEarnings => totalDeliveryFees - platformCommission;

  /// عمولة المنصة على المطاعم والمتاجر (10% من إجمالي المبيعات)
  double get merchantPlatformCommission => totalOrdersAmount * 0.10;

  /// صافي مستحقات المطاعم والمتاجر بعد استقطاع نسبة المنصة
  double get netMerchantPayout => totalOrdersAmount - merchantPlatformCommission;
}
