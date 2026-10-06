enum TripStatus { searching, accepted, arrived, started, completed, cancelled }

extension TripStatusExtension on TripStatus {
  String get name {
    switch (this) {
      case TripStatus.searching:
        return 'searching';
      case TripStatus.accepted:
        return 'accepted';
      case TripStatus.arrived:
        return 'arrived';
      case TripStatus.started:
        return 'started';
      case TripStatus.completed:
        return 'completed';
      case TripStatus.cancelled:
        return 'cancelled';
    }
  }

  static TripStatus fromString(String status) {
    // Handle 'pending' as alias for 'searching' (taxi_controller uses 'pending')
    if (status == 'pending') return TripStatus.searching;
    return TripStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => TripStatus.searching,
    );
  }
}

class Trip {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final String pickupAddress;
  final String dropoffAddress;
  final String rideType;
  final String price;
  final double distance;
  final TripStatus status;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverCar;
  final String? driverImage;
  final double? driverRating;
  final String? driverCarColor;
  final String? driverCarNumber;
  final DateTime? createdAt;

  Trip({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.rideType,
    required this.price,
    required this.distance,
    required this.status,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverCar,
    this.driverImage,
    this.driverRating,
    this.driverCarColor,
    this.driverCarNumber,
    this.createdAt,
  });

  Trip copyWith({
    TripStatus? status,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? driverCar,
    String? driverImage,
    double? driverRating,
    String? driverCarColor,
    String? driverCarNumber,
  }) {
    return Trip(
      id: id,
      userId: userId,
      userName: userName,
      userPhone: userPhone,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      rideType: rideType,
      price: price,
      distance: distance,
      status: status ?? this.status,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverCar: driverCar ?? this.driverCar,
      driverImage: driverImage ?? this.driverImage,
      driverRating: driverRating ?? this.driverRating,
      driverCarColor: driverCarColor ?? this.driverCarColor,
      driverCarNumber: driverCarNumber ?? this.driverCarNumber,
      createdAt: createdAt,
    );
  }
}
