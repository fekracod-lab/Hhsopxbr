/// حالة كابتن التكسي وتوافره
enum DriverAvailability {
  online,
  offline,
  onTrip;

  static DriverAvailability fromString(String? status) {
    switch (status?.toLowerCase().trim()) {
      case 'online':
        return DriverAvailability.online;
      case 'on_trip':
      case 'ontrip':
        return DriverAvailability.onTrip;
      default:
        return DriverAvailability.offline;
    }
  }

  String toDbString() {
    switch (this) {
      case DriverAvailability.online:
        return 'online';
      case DriverAvailability.onTrip:
        return 'on_trip';
      case DriverAvailability.offline:
        return 'offline';
    }
  }
}

/// سجل بروفايل الكابتن المجرد (Driver Profile Entity)
class DriverProfileEntity {
  final String uid;
  final String name;
  final String phone;
  final String carNumber;
  final String carType;
  final String carModel;
  final String carColor;
  final String? photoUrl;
  final DriverAvailability availability;
  final bool available;
  final double rating;
  final int totalTrips;
  final double walletBalance;
  final double debtAmount;
  final Map<String, dynamic> rawData;

  const DriverProfileEntity({
    required this.uid,
    required this.name,
    required this.phone,
    this.carNumber = '',
    this.carType = '',
    this.carModel = '',
    this.carColor = '',
    this.photoUrl,
    this.availability = DriverAvailability.offline,
    this.available = false,
    this.rating = 5.0,
    this.totalTrips = 0,
    this.walletBalance = 0.0,
    this.debtAmount = 0.0,
    this.rawData = const {},
  });

  bool get isOnline => availability == DriverAvailability.online;
  bool get isOnTrip => availability == DriverAvailability.onTrip;
  bool get isOffline => availability == DriverAvailability.offline;
}

/// حالة الرحلة
enum RideStatus {
  searching,
  pending,
  accepted,
  arrived,
  inProgress,
  completed,
  cancelled,
  unknown;

  static RideStatus fromString(String? status) {
    switch (status?.toLowerCase().trim()) {
      case 'searching':
        return RideStatus.searching;
      case 'pending':
        return RideStatus.pending;
      case 'accepted':
        return RideStatus.accepted;
      case 'arrived':
        return RideStatus.arrived;
      case 'in_progress':
      case 'inprogress':
        return RideStatus.inProgress;
      case 'completed':
        return RideStatus.completed;
      case 'cancelled':
      case 'canceled':
        return RideStatus.cancelled;
      default:
        return RideStatus.unknown;
    }
  }

  String toDbString() {
    switch (this) {
      case RideStatus.searching:
        return 'searching';
      case RideStatus.pending:
        return 'pending';
      case RideStatus.accepted:
        return 'accepted';
      case RideStatus.arrived:
        return 'arrived';
      case RideStatus.inProgress:
        return 'in_progress';
      case RideStatus.completed:
        return 'completed';
      case RideStatus.cancelled:
        return 'cancelled';
      case RideStatus.unknown:
        return 'unknown';
    }
  }
}

/// سجل طلب الرحلة المجرد (Ride Request Entity)
class RideRequestEntity {
  final String id;
  final String? passengerId;
  final String passengerName;
  final String passengerPhone;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String destinationAddress;
  final double destinationLat;
  final double destinationLng;
  final double estimatedFare;
  final double distanceKm;
  final RideStatus status;
  final String? driverId;
  final DateTime? createdAt;
  final List<String> rejectedDrivers;
  final Map<String, dynamic> rawData;

  const RideRequestEntity({
    required this.id,
    this.passengerId,
    required this.passengerName,
    required this.passengerPhone,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.estimatedFare,
    this.distanceKm = 0.0,
    required this.status,
    this.driverId,
    this.createdAt,
    this.rejectedDrivers = const [],
    this.rawData = const {},
  });

  /// التحقق من صلاحية الطلب زمنياً (أقل من 30 ثانية)
  bool isFresh({Duration maxAge = const Duration(seconds: 30), DateTime? now}) {
    if (createdAt == null) return true;
    final current = now ?? DateTime.now();
    return current.difference(createdAt!) <= maxAge;
  }
}

/// إحصائيات وأرباح الكابتن (Driver Stats & Bonus Entity)
class DriverStatsEntity {
  final List<double> weeklyEarnings;
  final int totalTripsCount;
  final String cancellationRate;
  final int todayCompletedTrips;
  final double todayEarningsTotal;
  final int dailyTargetTrips;

  const DriverStatsEntity({
    required this.weeklyEarnings,
    required this.totalTripsCount,
    required this.cancellationRate,
    required this.todayCompletedTrips,
    required this.todayEarningsTotal,
    this.dailyTargetTrips = 5,
  });

  factory DriverStatsEntity.empty() => DriverStatsEntity(
        weeklyEarnings: List.filled(7, 0.0),
        totalTripsCount: 0,
        cancellationRate: '0%',
        todayCompletedTrips: 0,
        todayEarningsTotal: 0.0,
      );

  double get bonusProgressPercentage {
    if (dailyTargetTrips <= 0) return 0.0;
    final progress = todayCompletedTrips / dailyTargetTrips;
    return progress > 1.0 ? 1.0 : progress;
  }
}
