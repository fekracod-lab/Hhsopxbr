import 'package:flutter/foundation.dart';
import '../enums/notification_enums.dart';

/// سجل تسليم الإشعار للمستخدم (Notification Delivery Record)
@immutable
class NotificationDelivery {
  final String deliveryId;
  final String eventId;
  final String userId;
  final NotificationChannel channel;
  final DeliveryStatus status;
  final int retryCount;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  const NotificationDelivery({
    required this.deliveryId,
    required this.eventId,
    required this.userId,
    required this.channel,
    this.status = DeliveryStatus.pending,
    this.retryCount = 0,
    this.failureReason,
    required this.createdAt,
    this.sentAt,
    this.deliveredAt,
    this.readAt,
  });

  NotificationDelivery copyWith({
    String? deliveryId,
    String? eventId,
    String? userId,
    NotificationChannel? channel,
    DeliveryStatus? status,
    int? retryCount,
    String? failureReason,
    DateTime? createdAt,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? readAt,
  }) {
    return NotificationDelivery(
      deliveryId: deliveryId ?? this.deliveryId,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      channel: channel ?? this.channel,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      failureReason: failureReason ?? this.failureReason,
      createdAt: createdAt ?? this.createdAt,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deliveryId': deliveryId,
      'eventId': eventId,
      'userId': userId,
      'channel': channel.key,
      'status': status.key,
      'retryCount': retryCount,
      'failureReason': failureReason,
      'createdAt': createdAt.toIso8601String(),
      'sentAt': sentAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
    };
  }

  factory NotificationDelivery.fromMap(Map<String, dynamic> map, String docId) {
    return NotificationDelivery(
      deliveryId: docId,
      eventId: map['eventId']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      channel: NotificationChannel.values.firstWhere(
        (c) => c.key == map['channel']?.toString(),
        orElse: () => NotificationChannel.push,
      ),
      status: DeliveryStatus.fromString(map['status']?.toString()),
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
      failureReason: map['failureReason']?.toString(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sentAt: map['sentAt'] != null ? DateTime.tryParse(map['sentAt'].toString()) : null,
      deliveredAt: map['deliveredAt'] != null ? DateTime.tryParse(map['deliveredAt'].toString()) : null,
      readAt: map['readAt'] != null ? DateTime.tryParse(map['readAt'].toString()) : null,
    );
  }
}
