import 'package:flutter/foundation.dart';
import '../enums/notification_enums.dart';

/// محتوى رسالة الإشعار التفاعلية (Notification Message Content)
@immutable
class NotificationMessage {
  final String title;
  final String body;
  final String? sound;
  final String? deepLink;
  final int? badgeCount;
  final NotificationCategory category;
  final Map<String, dynamic> metadata;

  const NotificationMessage({
    required this.title,
    required this.body,
    this.sound,
    this.deepLink,
    this.badgeCount,
    this.category = NotificationCategory.system,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'sound': sound,
      'deepLink': deepLink,
      'badgeCount': badgeCount,
      'category': category.key,
      'metadata': metadata,
    };
  }

  factory NotificationMessage.fromMap(Map<String, dynamic> map) {
    return NotificationMessage(
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      sound: map['sound']?.toString(),
      deepLink: map['deepLink']?.toString(),
      badgeCount: (map['badgeCount'] as num?)?.toInt(),
      category: NotificationCategory.values.firstWhere(
        (c) => c.key == map['category']?.toString(),
        orElse: () => NotificationCategory.system,
      ),
      metadata: map['metadata'] is Map ? Map<String, dynamic>.from(map['metadata'] as Map) : {},
    );
  }
}
