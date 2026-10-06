import 'package:flutter/foundation.dart';
import '../enums/dispatch_enums.dart';

/// عرض الطلب الموجه للسائق (Dispatch Offer)
@immutable
class DispatchOffer {
  final String offerId;
  final String dispatchId;
  final String orderId;
  final String driverId;
  final String driverName;
  final String driverPhone;
  final int attemptNumber;
  final DispatchOfferStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;

  const DispatchOffer({
    required this.offerId,
    required this.dispatchId,
    required this.orderId,
    required this.driverId,
    required this.driverName,
    required this.driverPhone,
    required this.attemptNumber,
    this.status = DispatchOfferStatus.created,
    required this.createdAt,
    required this.expiresAt,
  });

  /// هل العرض منتهي الصلاحية؟
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  DispatchOffer copyWith({
    String? offerId,
    String? dispatchId,
    String? orderId,
    String? driverId,
    String? driverName,
    String? driverPhone,
    int? attemptNumber,
    DispatchOfferStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return DispatchOffer(
      offerId: offerId ?? this.offerId,
      dispatchId: dispatchId ?? this.dispatchId,
      orderId: orderId ?? this.orderId,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      attemptNumber: attemptNumber ?? this.attemptNumber,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'offerId': offerId,
      'dispatchId': dispatchId,
      'orderId': orderId,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'attemptNumber': attemptNumber,
      'status': status.key,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  factory DispatchOffer.fromMap(Map<String, dynamic> map, String docId) {
    return DispatchOffer(
      offerId: docId,
      dispatchId: map['dispatchId']?.toString() ?? '',
      orderId: map['orderId']?.toString() ?? '',
      driverId: map['driverId']?.toString() ?? '',
      driverName: map['driverName']?.toString() ?? '',
      driverPhone: map['driverPhone']?.toString() ?? '',
      attemptNumber: (map['attemptNumber'] as num?)?.toInt() ?? 1,
      status: DispatchOfferStatus.fromString(map['status']?.toString()),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: map['expiresAt'] != null
          ? DateTime.tryParse(map['expiresAt'].toString()) ?? DateTime.now().add(const Duration(seconds: 30))
          : DateTime.now().add(const Duration(seconds: 30)),
    );
  }
}
