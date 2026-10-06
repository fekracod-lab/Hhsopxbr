// نماذج وكينونات نطاق إدارة رحلات التكسي (Taxi Ride Management Domain Entities)
// Clean Architecture — Pure Dart Domain Layer (Zero Framework / Zero Firebase Dependencies)

/// كينونة النقطة الجغرافية المجردة (Pure Geo Point)
class PureGeoPoint {
  final double latitude;
  final double longitude;

  const PureGeoPoint({
    required this.latitude,
    required this.longitude,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PureGeoPoint &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() => 'PureGeoPoint($latitude, $longitude)';
}

/// حالات رحلة التكسي
enum RideStatusEnum {
  all,
  searching,
  accepted,
  arrived,
  // ignore: constant_identifier_names
  in_progress,
  completed,
  cancelled,
  unknown;

  static RideStatusEnum fromString(String? status) {
    if (status == null) return RideStatusEnum.unknown;
    switch (status.trim().toLowerCase()) {
      case 'all':
        return RideStatusEnum.all;
      case 'searching':
      case 'pending':
        return RideStatusEnum.searching;
      case 'accepted':
      case 'driver_accepted':
        return RideStatusEnum.accepted;
      case 'arrived':
        return RideStatusEnum.arrived;
      case 'in_progress':
      case 'delivering':
      case 'started':
        return RideStatusEnum.in_progress;
      case 'completed':
        return RideStatusEnum.completed;
      case 'cancelled':
      case 'canceled':
        return RideStatusEnum.cancelled;
      default:
        return RideStatusEnum.unknown;
    }
  }

  String toFirestoreString() {
    switch (this) {
      case RideStatusEnum.searching:
        return 'searching';
      case RideStatusEnum.accepted:
        return 'accepted';
      case RideStatusEnum.arrived:
        return 'arrived';
      case RideStatusEnum.in_progress:
        return 'in_progress';
      case RideStatusEnum.completed:
        return 'completed';
      case RideStatusEnum.cancelled:
        return 'cancelled';
      case RideStatusEnum.all:
      case RideStatusEnum.unknown:
        return 'all';
    }
  }

  String get arabicLabel {
    switch (this) {
      case RideStatusEnum.all:
        return 'الكل';
      case RideStatusEnum.searching:
        return 'بانتظار كابتن';
      case RideStatusEnum.accepted:
        return 'تم القبول';
      case RideStatusEnum.arrived:
        return 'وصل الكابتن';
      case RideStatusEnum.in_progress:
        return 'في الطريق';
      case RideStatusEnum.completed:
        return 'مكتملة';
      case RideStatusEnum.cancelled:
        return 'ملغاة';
      case RideStatusEnum.unknown:
        return 'غير محدد';
    }
  }
}

/// كينونة رحلة التكسي الإدارية (Ride Admin Entity)
class RideAdminEntity {
  final String id;
  final String passengerName;
  final String passengerPhone;
  final String? passengerId;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverCar;
  final String pickupAddress;
  final PureGeoPoint? pickupLocation;
  final String dropoffAddress;
  final PureGeoPoint? dropoffLocation;
  final double fare;
  final RideStatusEnum status;
  final String paymentMethod;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final bool assignedByAdmin;
  final Map<String, dynamic> rawData;

  const RideAdminEntity({
    required this.id,
    this.passengerName = 'زبون',
    this.passengerPhone = '',
    this.passengerId,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverCar,
    this.pickupAddress = 'الموقع الحالي',
    this.pickupLocation,
    this.dropoffAddress = 'الوجهة المحددة',
    this.dropoffLocation,
    this.fare = 0.0,
    this.status = RideStatusEnum.searching,
    this.paymentMethod = 'cash',
    this.notes,
    this.createdAt,
    this.acceptedAt,
    this.arrivedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.assignedByAdmin = false,
    this.rawData = const {},
  });

  bool get isActive =>
      status == RideStatusEnum.searching ||
      status == RideStatusEnum.accepted ||
      status == RideStatusEnum.arrived ||
      status == RideStatusEnum.in_progress;

  bool get isCompleted => status == RideStatusEnum.completed;
  bool get isCancelled => status == RideStatusEnum.cancelled;
  bool get hasDriverAssigned => driverId != null && driverId!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RideAdminEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          status == other.status &&
          driverId == other.driverId &&
          fare == other.fare;

  @override
  int get hashCode => id.hashCode ^ status.hashCode ^ (driverId?.hashCode ?? 0);
}

/// كينونة كابتن التكسي الإدارية (Taxi Driver Admin Entity)
class TaxiDriverAdminEntity {
  final String id;
  final String name;
  final String phone;
  final String carModel;
  final String carNumber;
  final String carColor;
  final String status; // 'active', 'inactive', 'suspended', etc.
  final bool isOnline;
  final double appDebt;
  final double commissionLimit;
  final bool allowCommissionException;
  final int totalRides;
  final double rating;
  final PureGeoPoint? location;
  final Map<String, dynamic> rawData;

  const TaxiDriverAdminEntity({
    required this.id,
    this.name = 'كابتن تكسي',
    this.phone = '',
    this.carModel = 'غير محدد',
    this.carNumber = '',
    this.carColor = '',
    this.status = 'active',
    this.isOnline = false,
    this.appDebt = 0.0,
    this.commissionLimit = 10000.0,
    this.allowCommissionException = false,
    this.totalRides = 0,
    this.rating = 5.0,
    this.location,
    this.rawData = const {},
  });

  bool get isBlockedByDebt =>
      !allowCommissionException && appDebt >= commissionLimit;

  double get debtRatio =>
      commissionLimit > 0 ? (appDebt / commissionLimit).clamp(0.0, 1.0) : 1.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxiDriverAdminEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          status == other.status &&
          appDebt == other.appDebt &&
          allowCommissionException == other.allowCommissionException;

  @override
  int get hashCode =>
      id.hashCode ^
      status.hashCode ^
      appDebt.hashCode ^
      allowCommissionException.hashCode;
}

/// كينونة تقييم ورأي الكابتن الإدارية (Driver Review Admin Entity)
class DriverReviewAdminEntity {
  final String id;
  final String driverId;
  final String driverName;
  final String customerId;
  final String customerName;
  final double rating;
  final String comment;
  final String rideId;
  final DateTime? createdAt;
  final Map<String, dynamic> rawData;

  const DriverReviewAdminEntity({
    required this.id,
    required this.driverId,
    this.driverName = 'كابتن',
    this.customerId = '',
    this.customerName = 'زبون',
    this.rating = 5.0,
    this.comment = '',
    this.rideId = '',
    this.createdAt,
    this.rawData = const {},
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DriverReviewAdminEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          rating == other.rating;

  @override
  int get hashCode => id.hashCode ^ rating.hashCode;
}

/// مؤشرات الأداء الحية (Live KPI Metrics)
class RideManagementKpiMetrics {
  final int onlineDriversCount;
  final int activeTripsCount;
  final int searchingTripsCount;
  final int todayCompletedTripsCount;

  const RideManagementKpiMetrics({
    this.onlineDriversCount = 0,
    this.activeTripsCount = 0,
    this.searchingTripsCount = 0,
    this.todayCompletedTripsCount = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RideManagementKpiMetrics &&
          runtimeType == other.runtimeType &&
          onlineDriversCount == other.onlineDriversCount &&
          activeTripsCount == other.activeTripsCount &&
          searchingTripsCount == other.searchingTripsCount &&
          todayCompletedTripsCount == other.todayCompletedTripsCount;

  @override
  int get hashCode =>
      onlineDriversCount.hashCode ^
      activeTripsCount.hashCode ^
      searchingTripsCount.hashCode ^
      todayCompletedTripsCount.hashCode;
}

/// مؤشرات التحليلات التاريخية (Historical Analytics Metrics)
class RideHistoryAnalyticsMetrics {
  final int totalCompletedRides;
  final double totalGmv;
  final double totalPlatformCommission;
  final double averageFare;

  const RideHistoryAnalyticsMetrics({
    this.totalCompletedRides = 0,
    this.totalGmv = 0.0,
    this.totalPlatformCommission = 0.0,
    this.averageFare = 0.0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RideHistoryAnalyticsMetrics &&
          runtimeType == other.runtimeType &&
          totalCompletedRides == other.totalCompletedRides &&
          totalGmv == other.totalGmv &&
          totalPlatformCommission == other.totalPlatformCommission &&
          averageFare == other.averageFare;

  @override
  int get hashCode =>
      totalCompletedRides.hashCode ^
      totalGmv.hashCode ^
      totalPlatformCommission.hashCode ^
      averageFare.hashCode;
}
