import 'package:flutter/foundation.dart';

/// مصدر ونوع طلب التوصيل (Normalized Delivery Source)
enum OrderDeliverySource {
  restaurant,
  store,
  mersal;

  String get key {
    switch (this) {
      case OrderDeliverySource.restaurant:
        return 'food_order';
      case OrderDeliverySource.store:
        return 'store_order';
      case OrderDeliverySource.mersal:
        return 'mersal_request';
    }
  }

  static OrderDeliverySource fromString(String? val) {
    if (val == null) return OrderDeliverySource.restaurant;
    final lower = val.toLowerCase().trim();
    if (lower.contains('store') || lower.contains('market') || lower.contains('shop')) {
      return OrderDeliverySource.store;
    }
    if (lower.contains('mersal') || lower.contains('parcel') || lower.contains('delegate')) {
      return OrderDeliverySource.mersal;
    }
    return OrderDeliverySource.restaurant;
  }
}

/// حالات مسار التوصيل الميداني (Strict Delivery Execution Statuses)
enum DeliveryExecutionStatus {
  pending,
  accepted,
  headingToPickup,
  arrivedAtPickup,
  pickedUp,
  headingToCustomer,
  arrivedAtCustomer,
  delivered,
  cancelled;

  String get value {
    switch (this) {
      case DeliveryExecutionStatus.pending:
        return 'pending';
      case DeliveryExecutionStatus.accepted:
        return 'accepted';
      case DeliveryExecutionStatus.headingToPickup:
        return 'heading_to_pickup';
      case DeliveryExecutionStatus.arrivedAtPickup:
        return 'arrived_at_pickup';
      case DeliveryExecutionStatus.pickedUp:
        return 'picked_up';
      case DeliveryExecutionStatus.headingToCustomer:
        return 'heading_to_customer';
      case DeliveryExecutionStatus.arrivedAtCustomer:
        return 'arrived_at_customer';
      case DeliveryExecutionStatus.delivered:
        return 'delivered';
      case DeliveryExecutionStatus.cancelled:
        return 'cancelled';
    }
  }

  static DeliveryExecutionStatus fromString(String? val) {
    if (val == null) return DeliveryExecutionStatus.pending;
    final lower = val.toLowerCase().trim();
    switch (lower) {
      case 'accepted':
      case 'preparing':
      case 'قيد التجهيز':
      case 'ready':
      case 'جاهز للتوصيل':
        return DeliveryExecutionStatus.accepted;
      case 'heading_to_pickup':
      case 'delivering':
      case 'جاري التحرك للمحل':
        return DeliveryExecutionStatus.headingToPickup;
      case 'arrived_at_pickup':
      case 'وصل للمحل':
        return DeliveryExecutionStatus.arrivedAtPickup;
      case 'picked_up':
      case 'on_the_way':
      case 'تم الاستلام':
        return DeliveryExecutionStatus.pickedUp;
      case 'heading_to_customer':
      case 'بالطريق للزبون':
        return DeliveryExecutionStatus.headingToCustomer;
      case 'arrived_at_customer':
      case 'وصل للزبون':
        return DeliveryExecutionStatus.arrivedAtCustomer;
      case 'delivered':
      case 'completed':
      case 'مكتمل':
      case 'تم التسليم':
        return DeliveryExecutionStatus.delivered;
      case 'cancelled':
      case 'rejected':
      case 'ملغي':
        return DeliveryExecutionStatus.cancelled;
      default:
        return DeliveryExecutionStatus.pending;
    }
  }
}

/// موقع جغرافي ومعلومات النقطة (Pickup or Dropoff Point)
@immutable
class DeliveryPoint {
  final double latitude;
  final double longitude;
  final String name;
  final String address;
  final String phone;
  final String instructions;

  const DeliveryPoint({
    required this.latitude,
    required this.longitude,
    this.name = '',
    this.address = '',
    this.phone = '',
    this.instructions = '',
  });

  bool get isValid => latitude != 0.0 && longitude != 0.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryPoint &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          name == other.name &&
          address == other.address;

  @override
  int get hashCode => Object.hash(latitude, longitude, name, address);
}

/// قراءة حية لموقع الكابتن (Live Driver Location Entity)
@immutable
class DeliveryLocationEntity {
  final double latitude;
  final double longitude;
  final double heading;
  final double speed;
  final double accuracy;
  final DateTime? timestamp;

  const DeliveryLocationEntity({
    required this.latitude,
    required this.longitude,
    this.heading = 0.0,
    this.speed = 0.0,
    this.accuracy = 0.0,
    this.timestamp,
  });

  bool get isValid => latitude != 0.0 && longitude != 0.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryLocationEntity &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          heading == other.heading;

  @override
  int get hashCode => Object.hash(latitude, longitude, heading);
}

/// خطوة ملاحة مفصلة (Navigation Route Step)
@immutable
class DeliveryRouteStepEntity {
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final double durationSeconds;
  final String instruction;
  final String maneuverType;

  const DeliveryRouteStepEntity({
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.durationSeconds,
    this.instruction = '',
    this.maneuverType = '',
  });
}

/// مسار الملاحة الكامل (Active Driving Route Entity)
@immutable
class DeliveryRouteEntity {
  final List<DeliveryLocationEntity> polylinePoints;
  final List<DeliveryRouteStepEntity> steps;
  final double totalDistanceMeters;
  final double totalDurationSeconds;
  final DateTime calculatedAt;

  const DeliveryRouteEntity({
    required this.polylinePoints,
    this.steps = const [],
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.calculatedAt,
  });

  static DeliveryRouteEntity empty() => DeliveryRouteEntity(
        polylinePoints: const [],
        steps: const [],
        totalDistanceMeters: 0.0,
        totalDurationSeconds: 0.0,
        calculatedAt: DateTime.now(),
      );

  bool get isEmpty => polylinePoints.isEmpty;
  bool get isNotEmpty => polylinePoints.isNotEmpty;

  double get distanceKm => totalDistanceMeters / 1000.0;
  int get durationMinutes => (totalDurationSeconds / 60.0).ceil();
}

/// عنصر داخل الطلب (Order Item)
@immutable
class DeliveryOrderItem {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final String imageUrl;
  final String notes;

  const DeliveryOrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    this.imageUrl = '',
    this.notes = '',
  });

  double get total => price * quantity;
}

/// معلومات السائق المكلف
@immutable
class DeliveryDriverInfo {
  final String id;
  final String name;
  final String phone;
  final String imageUrl;
  final String vehicleType;
  final String vehiclePlate;
  final double rating;

  const DeliveryDriverInfo({
    required this.id,
    this.name = 'كابتن مدار',
    this.phone = '',
    this.imageUrl = '',
    this.vehicleType = 'دراجة نارية',
    this.vehiclePlate = '',
    this.rating = 5.0,
  });
}

/// كيان تنفيذ التوصيل الميداني الكامل (Full Delivery Execution Entity)
@immutable
class DeliveryExecutionEntity {
  final String orderId;
  final OrderDeliverySource source;
  final String merchantId;
  final String merchantName;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final DeliveryExecutionStatus status;
  final DeliveryPoint pickupPoint;
  final DeliveryPoint dropoffPoint;
  final List<DeliveryOrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double grandTotal;
  final String paymentMethod; // 'cash_on_delivery', 'paid_wallet', 'card'
  final bool isPaid;
  final DeliveryDriverInfo? driverInfo;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final String cancelReason;
  final String notes;
  final String? voiceUrl;

  const DeliveryExecutionEntity({
    required this.orderId,
    required this.source,
    required this.merchantId,
    this.merchantName = '',
    required this.customerId,
    this.customerName = '',
    this.customerPhone = '',
    required this.status,
    required this.pickupPoint,
    required this.dropoffPoint,
    this.items = const [],
    this.subtotal = 0.0,
    this.deliveryFee = 0.0,
    this.discount = 0.0,
    this.grandTotal = 0.0,
    this.paymentMethod = 'cash_on_delivery',
    this.isPaid = false,
    this.driverInfo,
    this.createdAt,
    this.acceptedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.cancelledAt,
    this.cancelReason = '',
    this.notes = '',
    this.voiceUrl,
  });

  bool get isAssigned => driverInfo != null && driverInfo!.id.isNotEmpty;
  bool get isCustomerMasked =>
      status == DeliveryExecutionStatus.pending ||
      status == DeliveryExecutionStatus.accepted ||
      status == DeliveryExecutionStatus.headingToPickup ||
      status == DeliveryExecutionStatus.arrivedAtPickup;

  bool get isTerminal =>
      status == DeliveryExecutionStatus.delivered ||
      status == DeliveryExecutionStatus.cancelled;

  DeliveryPoint get activeTargetPoint {
    if (status == DeliveryExecutionStatus.pending ||
        status == DeliveryExecutionStatus.accepted ||
        status == DeliveryExecutionStatus.headingToPickup ||
        status == DeliveryExecutionStatus.arrivedAtPickup) {
      return pickupPoint;
    }
    return dropoffPoint;
  }

  DeliveryExecutionEntity copyWith({
    String? orderId,
    OrderDeliverySource? source,
    String? merchantId,
    String? merchantName,
    String? customerId,
    String? customerName,
    String? customerPhone,
    DeliveryExecutionStatus? status,
    DeliveryPoint? pickupPoint,
    DeliveryPoint? dropoffPoint,
    List<DeliveryOrderItem>? items,
    double? subtotal,
    double? deliveryFee,
    double? discount,
    double? grandTotal,
    String? paymentMethod,
    bool? isPaid,
    DeliveryDriverInfo? driverInfo,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
    DateTime? cancelledAt,
    String? cancelReason,
    String? notes,
    String? voiceUrl,
  }) {
    return DeliveryExecutionEntity(
      orderId: orderId ?? this.orderId,
      source: source ?? this.source,
      merchantId: merchantId ?? this.merchantId,
      merchantName: merchantName ?? this.merchantName,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      status: status ?? this.status,
      pickupPoint: pickupPoint ?? this.pickupPoint,
      dropoffPoint: dropoffPoint ?? this.dropoffPoint,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      discount: discount ?? this.discount,
      grandTotal: grandTotal ?? this.grandTotal,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPaid: isPaid ?? this.isPaid,
      driverInfo: driverInfo ?? this.driverInfo,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelReason: cancelReason ?? this.cancelReason,
      notes: notes ?? this.notes,
      voiceUrl: voiceUrl ?? this.voiceUrl,
    );
  }
}

/// المقاييس المحاسبية والتشغيلية للتوصيل (Execution Metrics)
@immutable
class DeliveryExecutionMetrics {
  final double captainEarnings;
  final double platformCommission;
  final double cashToCollect;
  final double merchantSettlement;
  final int customerPointsEarned;

  const DeliveryExecutionMetrics({
    required this.captainEarnings,
    required this.platformCommission,
    required this.cashToCollect,
    required this.merchantSettlement,
    required this.customerPointsEarned,
  });
}
