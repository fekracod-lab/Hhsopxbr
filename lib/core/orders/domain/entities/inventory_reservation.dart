import 'package:flutter/foundation.dart';
import '../enums/order_enums.dart';

/// سجل حجز المخزون الذري (Atomic Inventory Reservation Record)
@immutable
class InventoryReservation {
  final String reservationId;
  final String orderId;
  final String storeId;
  final String productId;
  final int quantity;
  final ReservationStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;

  const InventoryReservation({
    required this.reservationId,
    required this.orderId,
    required this.storeId,
    required this.productId,
    required this.quantity,
    this.status = ReservationStatus.reserved,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toMap() {
    return {
      'reservationId': reservationId,
      'orderId': orderId,
      'storeId': storeId,
      'productId': productId,
      'quantity': quantity,
      'status': status.key,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  factory InventoryReservation.fromMap(Map<String, dynamic> map, String docId) {
    return InventoryReservation(
      reservationId: docId,
      orderId: map['orderId']?.toString() ?? '',
      storeId: map['storeId']?.toString() ?? '',
      productId: map['productId']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      status: ReservationStatus.fromString(map['status']?.toString()),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: map['expiresAt'] != null
          ? DateTime.tryParse(map['expiresAt'].toString()) ?? DateTime.now().add(const Duration(minutes: 15))
          : DateTime.now().add(const Duration(minutes: 15)),
    );
  }
}
