import 'package:cloud_firestore/cloud_firestore.dart';

class DelegateRequest {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String taskDescription;
  final int durationHours;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final String status; // pending, accepted, on_the_way, completed, cancelled
  final double price;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverImage;
  final DateTime createdAt;

  DelegateRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.taskDescription,
    required this.durationHours,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.status,
    required this.price,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverImage,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'taskDescription': taskDescription,
      'durationHours': durationHours,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'pickupAddress': pickupAddress,
      'status': status,
      'price': price,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'driverImage': driverImage,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static DelegateRequest fromMap(Map<String, dynamic> map, String id) {
    return DelegateRequest(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userPhone: map['userPhone'] ?? '',
      taskDescription: map['taskDescription'] ?? '',
      durationHours: map['durationHours'] ?? 1,
      pickupLat: (map['pickupLat'] ?? 0.0).toDouble(),
      pickupLng: (map['pickupLng'] ?? 0.0).toDouble(),
      pickupAddress: map['pickupAddress'] ?? '',
      status: map['status'] ?? 'pending',
      price: (map['price'] ?? 0.0).toDouble(),
      driverId: map['driverId'],
      driverName: map['driverName'],
      driverPhone: map['driverPhone'],
      driverImage: map['driverImage'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
