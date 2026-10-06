import 'package:flutter/foundation.dart';
import '../enums/dispatch_enums.dart';

/// طلب التوزيع المركزي (Unified Dispatch Request)
@immutable
class DispatchRequest {
  final String dispatchId;
  final String orderId;
  final DispatchType dispatchType;
  final double pickupLatitude;
  final double pickupLongitude;
  final String pickupAddress;
  final double dropoffLatitude;
  final double dropoffLongitude;
  final String dropoffAddress;
  final int orderTotal;
  final String idempotencyKey;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const DispatchRequest({
    required this.dispatchId,
    required this.orderId,
    required this.dispatchType,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.pickupAddress,
    required this.dropoffLatitude,
    required this.dropoffLongitude,
    required this.dropoffAddress,
    this.orderTotal = 0,
    required this.idempotencyKey,
    required this.createdAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'dispatchId': dispatchId,
      'orderId': orderId,
      'dispatchType': dispatchType.key,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'pickupAddress': pickupAddress,
      'dropoffLatitude': dropoffLatitude,
      'dropoffLongitude': dropoffLongitude,
      'dropoffAddress': dropoffAddress,
      'orderTotal': orderTotal,
      'idempotencyKey': idempotencyKey,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory DispatchRequest.fromMap(Map<String, dynamic> map, String docId) {
    return DispatchRequest(
      dispatchId: docId,
      orderId: map['orderId']?.toString() ?? '',
      dispatchType: DispatchType.fromString(map['dispatchType']?.toString()),
      pickupLatitude: (map['pickupLatitude'] as num?)?.toDouble() ?? 0.0,
      pickupLongitude: (map['pickupLongitude'] as num?)?.toDouble() ?? 0.0,
      pickupAddress: map['pickupAddress']?.toString() ?? '',
      dropoffLatitude: (map['dropoffLatitude'] as num?)?.toDouble() ?? 0.0,
      dropoffLongitude: (map['dropoffLongitude'] as num?)?.toDouble() ?? 0.0,
      dropoffAddress: map['dropoffAddress']?.toString() ?? '',
      orderTotal: (map['orderTotal'] as num?)?.toInt() ?? 0,
      idempotencyKey: map['idempotencyKey']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      metadata: map['metadata'] is Map ? Map<String, dynamic>.from(map['metadata'] as Map) : {},
    );
  }
}
