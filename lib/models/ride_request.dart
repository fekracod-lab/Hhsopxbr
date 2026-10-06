import 'package:cloud_firestore/cloud_firestore.dart';

class RideRequest {
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
  final String status;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverCar;
  final String? driverImage;
  final double? driverRating;
  final String? driverCarColor;
  final String? driverCarNumber;
  final DateTime? createdAt;

  RideRequest({
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

  factory RideRequest.fromMap(Map<String, dynamic> map) {
    return RideRequest(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userPhone: map['userPhone'] ?? '',
      pickupLat: map['pickupLat']?.toDouble() ?? 0.0,
      pickupLng: map['pickupLng']?.toDouble() ?? 0.0,
      dropoffLat: map['dropoffLat']?.toDouble() ?? 0.0,
      dropoffLng: map['dropoffLng']?.toDouble() ?? 0.0,
      pickupAddress: map['pickupAddress'] ?? '',
      dropoffAddress: map['dropoffAddress'] ?? '',
      rideType: map['rideType'] ?? '',
      price: map['price'] != null ? map['price'].toString() : '',
      distance: map['distance']?.toDouble() ?? 0.0,
      status: map['status'] ?? 'pending',
      driverId: map['driverId'],
      driverName: map['driverName'],
      driverPhone: map['driverPhone'],
      driverCar: map['driverCar'],
      driverImage: map['driverImage'],
      driverRating: map['driverRating']?.toDouble(),
      driverCarColor: map['driverCarColor'],
      driverCarNumber: map['driverCarNumber'],
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
      'pickupAddress': pickupAddress,
      'dropoffAddress': dropoffAddress,
      'rideType': rideType,
      'price': price,
      'distance': distance,
      'status': status,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'driverCar': driverCar,
      'driverImage': driverImage,
      'driverRating': driverRating,
      'driverCarColor': driverCarColor,
      'driverCarNumber': driverCarNumber,
      'createdAt':
          createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
