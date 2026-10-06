// كيانات طبقة النطاق للوحة تحكم مندوب التوصيل (Delivery Dashboard Domain Entities)
// Pure Dart — Zero Flutter / Firebase Dependencies

/// مصدر ونوع طلب التوصيل (Delivery Order Source)
enum DeliveryOrderSource {
  food,
  store,
  mersal,
  unknown;

  static DeliveryOrderSource fromString(String? source) {
    if (source == null) return DeliveryOrderSource.unknown;
    switch (source.trim().toLowerCase()) {
      case 'food':
      case 'restaurant':
      case 'food_order':
        return DeliveryOrderSource.food;
      case 'store':
      case 'store_order':
      case 'supermarket':
      case 'grocery':
        return DeliveryOrderSource.store;
      case 'mersal':
      case 'mersal_order':
      case 'courier':
      case 'custom':
        return DeliveryOrderSource.mersal;
      default:
        return DeliveryOrderSource.unknown;
    }
  }

  String toDbString() {
    switch (this) {
      case DeliveryOrderSource.food:
        return 'food';
      case DeliveryOrderSource.store:
        return 'store_order';
      case DeliveryOrderSource.mersal:
        return 'mersal';
      case DeliveryOrderSource.unknown:
        return 'unknown';
    }
  }

  String get displayNameArabic {
    switch (this) {
      case DeliveryOrderSource.food:
        return 'وجبة مطعم';
      case DeliveryOrderSource.store:
        return 'مسواك متجر';
      case DeliveryOrderSource.mersal:
        return 'طلب مرسال';
      case DeliveryOrderSource.unknown:
        return 'طلب توصيل';
    }
  }
}

/// حالات طلب التوصيل (Delivery Order Status)
enum DeliveryOrderStatus {
  pending,
  ready,
  accepted,
  delivering,
  completed,
  cancelled,
  unknown;

  static DeliveryOrderStatus fromString(String? status) {
    if (status == null) return DeliveryOrderStatus.unknown;
    switch (status.trim().toLowerCase()) {
      case 'pending':
      case 'new':
      case 'waiting':
        return DeliveryOrderStatus.pending;
      case 'ready':
      case 'ready_for_pickup':
      case 'prepared':
        return DeliveryOrderStatus.ready;
      case 'accepted':
      case 'assigned':
      case 'driver_assigned':
        return DeliveryOrderStatus.accepted;
      case 'delivering':
      case 'on_the_way':
      case 'on_delivery':
      case 'picked_up':
      case 'pickedup':
        return DeliveryOrderStatus.delivering;
      case 'completed':
      case 'delivered':
      case 'done':
      case 'finished':
        return DeliveryOrderStatus.completed;
      case 'cancelled':
      case 'canceled':
      case 'rejected':
        return DeliveryOrderStatus.cancelled;
      default:
        return DeliveryOrderStatus.unknown;
    }
  }

  String toDbString() {
    switch (this) {
      case DeliveryOrderStatus.pending:
        return 'pending';
      case DeliveryOrderStatus.ready:
        return 'ready_for_pickup';
      case DeliveryOrderStatus.accepted:
        return 'accepted';
      case DeliveryOrderStatus.delivering:
        return 'delivering';
      case DeliveryOrderStatus.completed:
        return 'completed';
      case DeliveryOrderStatus.cancelled:
        return 'cancelled';
      case DeliveryOrderStatus.unknown:
        return 'unknown';
    }
  }

  bool get isAvailableForPickup =>
      this == DeliveryOrderStatus.pending || this == DeliveryOrderStatus.ready;

  bool get isActive =>
      this == DeliveryOrderStatus.accepted || this == DeliveryOrderStatus.delivering;

  bool get isCompleted => this == DeliveryOrderStatus.completed;

  bool get isCancelled => this == DeliveryOrderStatus.cancelled;

  bool get isTerminal => isCompleted || isCancelled;
}

/// حالة توفر واتصال المندوب للعمل (Driver Availability State)
enum DriverAvailabilityState {
  online,
  offline,
  onTrip,
  unknown;

  static DriverAvailabilityState fromString(String? state) {
    if (state == null) return DriverAvailabilityState.unknown;
    switch (state.trim().toLowerCase()) {
      case 'online':
      case 'available':
      case 'active':
        return DriverAvailabilityState.online;
      case 'offline':
      case 'inactive':
      case 'disabled':
        return DriverAvailabilityState.offline;
      case 'on_trip':
      case 'busy':
      case 'delivering':
        return DriverAvailabilityState.onTrip;
      default:
        return DriverAvailabilityState.unknown;
    }
  }

  String toDbString() {
    switch (this) {
      case DriverAvailabilityState.online:
        return 'online';
      case DriverAvailabilityState.offline:
        return 'offline';
      case DriverAvailabilityState.onTrip:
        return 'on_trip';
      case DriverAvailabilityState.unknown:
        return 'unknown';
    }
  }

  bool get isWorking =>
      this == DriverAvailabilityState.online || this == DriverAvailabilityState.onTrip;
}

/// نوع فلترة الطلبات في لوحة المندوب (Delivery Filter Type)
enum DeliveryFilterType {
  all,
  food,
  mersal,
  store;

  static DeliveryFilterType fromString(String? filter) {
    if (filter == null) return DeliveryFilterType.all;
    switch (filter.trim().toLowerCase()) {
      case 'food':
        return DeliveryFilterType.food;
      case 'mersal':
        return DeliveryFilterType.mersal;
      case 'store':
        return DeliveryFilterType.store;
      case 'all':
      default:
        return DeliveryFilterType.all;
    }
  }
}

/// كيان طلب التوصيل الموحد لجميع المصادر (Delivery Order Unified Entity)
class DeliveryOrderEntity {
  final String id;
  final DeliveryOrderSource source;
  final DeliveryOrderStatus status;
  final String sourceName;
  final String dropoffName;
  final double deliveryFee;
  final bool isCustomPrice;
  final double orderTotal;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String driverId;
  final String driverName;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final Map<String, dynamic> rawData;

  const DeliveryOrderEntity({
    required this.id,
    required this.source,
    required this.status,
    required this.sourceName,
    required this.dropoffName,
    this.deliveryFee = 3000.0,
    this.isCustomPrice = false,
    this.orderTotal = 0.0,
    this.customerId = '',
    this.customerName = '',
    this.customerPhone = '',
    this.driverId = '',
    this.driverName = '',
    this.createdAt,
    this.acceptedAt,
    this.completedAt,
    this.rawData = const {},
  });

  DeliveryOrderEntity copyWith({
    String? id,
    DeliveryOrderSource? source,
    DeliveryOrderStatus? status,
    String? sourceName,
    String? dropoffName,
    double? deliveryFee,
    bool? isCustomPrice,
    double? orderTotal,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? driverId,
    String? driverName,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
    Map<String, dynamic>? rawData,
  }) {
    return DeliveryOrderEntity(
      id: id ?? this.id,
      source: source ?? this.source,
      status: status ?? this.status,
      sourceName: sourceName ?? this.sourceName,
      dropoffName: dropoffName ?? this.dropoffName,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      isCustomPrice: isCustomPrice ?? this.isCustomPrice,
      orderTotal: orderTotal ?? this.orderTotal,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      rawData: rawData ?? this.rawData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryOrderEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          source == other.source &&
          status == other.status &&
          deliveryFee == other.deliveryFee;

  @override
  int get hashCode => Object.hash(id, source, status, deliveryFee);
}

/// تقدم تحدي الهدف اليومي للمندوب (Delivery Daily Quest Progress)
class DeliveryQuestProgress {
  final int targetTrips;
  final int completedTrips;
  final double progress;
  final int progressPercentage;
  final double bonusAmount;
  final bool isCompleted;
  final int remainingTrips;

  const DeliveryQuestProgress({
    required this.targetTrips,
    required this.completedTrips,
    required this.progress,
    required this.progressPercentage,
    required this.bonusAmount,
    required this.isCompleted,
    required this.remainingTrips,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryQuestProgress &&
          runtimeType == other.runtimeType &&
          targetTrips == other.targetTrips &&
          completedTrips == other.completedTrips &&
          progress == other.progress &&
          bonusAmount == other.bonusAmount;

  @override
  int get hashCode =>
      Object.hash(targetTrips, completedTrips, progress, bonusAmount);
}

/// الإحصائيات الشاملة للوحة تحكم المندوب (Delivery Dashboard Statistics)
class DeliveryDashboardStatistics {
  final int totalOrders;
  final int completedOrders;
  final int activeOrders;
  final int pendingOrders;
  final int cancelledOrders;
  final double totalEarnings;
  final double todayEarnings;
  final int todayCompletedCount;
  final double completionRate;
  final double appDebt;
  final DeliveryQuestProgress questProgress;

  const DeliveryDashboardStatistics({
    required this.totalOrders,
    required this.completedOrders,
    required this.activeOrders,
    required this.pendingOrders,
    required this.cancelledOrders,
    required this.totalEarnings,
    required this.todayEarnings,
    required this.todayCompletedCount,
    required this.completionRate,
    required this.appDebt,
    required this.questProgress,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryDashboardStatistics &&
          runtimeType == other.runtimeType &&
          totalOrders == other.totalOrders &&
          completedOrders == other.completedOrders &&
          totalEarnings == other.totalEarnings &&
          todayEarnings == other.todayEarnings &&
          appDebt == other.appDebt;

  @override
  int get hashCode => Object.hash(
        totalOrders,
        completedOrders,
        totalEarnings,
        todayEarnings,
        appDebt,
      );
}
