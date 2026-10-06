import 'package:cloud_firestore/cloud_firestore.dart';

class MersalRequest {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String requestDescription;
  final String? storeName;
  final double dropoffLat;
  final double dropoffLng;
  final String dropoffAddress;
  final String status; // pending, accepted, on_the_way, delivered, cancelled
  final String? price;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverImage;
  final String? deliveryPhotoUrl;
  final String? deliverySignatureUrl;
  final String? category;
  final String? voiceUrl;
  final String? prescriptionPhotoUrl;
  final DateTime? scheduledTime;
  final DateTime? createdAt;

  MersalRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.requestDescription,
    this.storeName,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.dropoffAddress,
    required this.status,
    this.price,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverImage,
    this.deliveryPhotoUrl,
    this.deliverySignatureUrl,
    this.category,
    this.voiceUrl,
    this.prescriptionPhotoUrl,
    this.scheduledTime,
    this.createdAt,
  });

  factory MersalRequest.fromMap(Map<String, dynamic> map, String docId) {
    return MersalRequest(
      id: docId,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userPhone: map['userPhone'] ?? '',
      requestDescription: map['requestDescription'] ?? '',
      storeName: map['storeName'],
      dropoffLat: map['dropoffLat']?.toDouble() ?? 0.0,
      dropoffLng: map['dropoffLng']?.toDouble() ?? 0.0,
      dropoffAddress: map['dropoffAddress'] ?? '',
      status: map['status'] ?? 'pending',
      price: map['price']?.toString(),
      driverId: map['driverId'],
      driverName: map['driverName'],
      driverPhone: map['driverPhone'],
      driverImage: map['driverImage'],
      deliveryPhotoUrl: map['deliveryPhotoUrl'],
      deliverySignatureUrl: map['deliverySignatureUrl'],
      category: map['category'],
      voiceUrl: map['voiceUrl'],
      prescriptionPhotoUrl: map['prescriptionPhotoUrl'],
      scheduledTime: map['scheduledTime'] != null ? (map['scheduledTime'] as Timestamp).toDate() : null,
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'requestDescription': requestDescription,
      'storeName': storeName,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
      'dropoffAddress': dropoffAddress,
      'status': status,
      'price': price,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'driverImage': driverImage,
      'deliveryPhotoUrl': deliveryPhotoUrl,
      'deliverySignatureUrl': deliverySignatureUrl,
      'category': category,
      'voiceUrl': voiceUrl,
      'prescriptionPhotoUrl': prescriptionPhotoUrl,
      'scheduledTime': scheduledTime != null ? Timestamp.fromDate(scheduledTime!) : null,
      'createdAt':
          createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
