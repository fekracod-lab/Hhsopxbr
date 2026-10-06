import 'package:cloud_firestore/cloud_firestore.dart';

class ParcelDeliveryRequest {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String dropoffAddress;
  final String itemDescription;
  final String itemSize;
  final String vehicleType;
  final String recipientName;
  final String recipientPhone;
  final String status;
  final double price;
  final int estimatedTime;
  final double distance;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? deliveryPhotoUrl;
  final String? deliverySignatureUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  ParcelDeliveryRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.dropoffAddress,
    required this.itemDescription,
    required this.itemSize,
    required this.vehicleType,
    required this.recipientName,
    required this.recipientPhone,
    required this.status,
    required this.price,
    required this.estimatedTime,
    required this.distance,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.deliveryPhotoUrl,
    this.deliverySignatureUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'pickupAddress': pickupAddress,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
      'dropoffAddress': dropoffAddress,
      'itemDescription': itemDescription,
      'itemSize': itemSize,
      'vehicleType': vehicleType,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'status': status,
      'price': price,
      'estimatedTime': estimatedTime,
      'distance': distance,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'deliveryPhotoUrl': deliveryPhotoUrl,
      'deliverySignatureUrl': deliverySignatureUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static ParcelDeliveryRequest fromMap(Map<String, dynamic> map, String id) {
    return ParcelDeliveryRequest(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userPhone: map['userPhone'] ?? '',
      pickupLat: (map['pickupLat'] ?? 0.0).toDouble(),
      pickupLng: (map['pickupLng'] ?? 0.0).toDouble(),
      pickupAddress: map['pickupAddress'] ?? '',
      dropoffLat: (map['dropoffLat'] ?? 0.0).toDouble(),
      dropoffLng: (map['dropoffLng'] ?? 0.0).toDouble(),
      dropoffAddress: map['dropoffAddress'] ?? '',
      itemDescription: map['itemDescription'] ?? '',
      itemSize: map['itemSize'] ?? 'Medium',
      vehicleType: map['vehicleType'] ?? 'motorcycle',
      recipientName: map['recipientName'] ?? '',
      recipientPhone: map['recipientPhone'] ?? '',
      status: map['status'] ?? 'pending',
      price: (map['price'] ?? 0.0).toDouble(),
      estimatedTime: map['estimatedTime'] ?? 30,
      distance: (map['distance'] ?? 0.0).toDouble(),
      driverId: map['driverId'],
      driverName: map['driverName'],
      driverPhone: map['driverPhone'],
      deliveryPhotoUrl: map['deliveryPhotoUrl'],
      deliverySignatureUrl: map['deliverySignatureUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  ParcelDeliveryRequest copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userPhone,
    double? pickupLat,
    double? pickupLng,
    String? pickupAddress,
    double? dropoffLat,
    double? dropoffLng,
    String? dropoffAddress,
    String? itemDescription,
    String? itemSize,
    String? vehicleType,
    String? recipientName,
    String? recipientPhone,
    String? status,
    double? price,
    int? estimatedTime,
    double? distance,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? deliveryPhotoUrl,
    String? deliverySignatureUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ParcelDeliveryRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      itemDescription: itemDescription ?? this.itemDescription,
      itemSize: itemSize ?? this.itemSize,
      vehicleType: vehicleType ?? this.vehicleType,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      status: status ?? this.status,
      price: price ?? this.price,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      distance: distance ?? this.distance,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      deliveryPhotoUrl: deliveryPhotoUrl ?? this.deliveryPhotoUrl,
      deliverySignatureUrl: deliverySignatureUrl ?? this.deliverySignatureUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
