import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/features/trip/domain/entities/trip.dart';

class TripModel extends Trip {
  TripModel({
    required super.id,
    required super.userId,
    required super.userName,
    required super.userPhone,
    required super.pickupLat,
    required super.pickupLng,
    required super.dropoffLat,
    required super.dropoffLng,
    required super.pickupAddress,
    required super.dropoffAddress,
    required super.rideType,
    required super.price,
    required super.distance,
    required super.status,
    super.driverId,
    super.driverName,
    super.driverPhone,
    super.driverCar,
    super.driverImage,
    super.driverRating,
    super.driverCarColor,
    super.driverCarNumber,
    super.createdAt,
  });

  factory TripModel.fromMap(Map<String, dynamic> map, String id) {
    return TripModel(
      id: id,
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
      price: map['price']?.toString() ?? '',
      distance: map['distance']?.toDouble() ?? 0.0,
      status: TripStatusExtension.fromString(map['status'] ?? 'searching'),
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
      'status': status.name,
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
