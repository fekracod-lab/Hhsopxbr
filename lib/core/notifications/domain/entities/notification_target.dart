import 'package:flutter/foundation.dart';

/// الهدف الموجه إليه الإشعار (Notification Target)
@immutable
class NotificationTarget {
  final List<String> targetUserIds;
  final String? targetRole; // e.g. 'taxi_captain', 'delivery_delegate', 'merchant', 'admin', 'customer'
  final String? topic; // Broadcast topic

  const NotificationTarget({
    this.targetUserIds = const [],
    this.targetRole,
    this.topic,
  });

  bool get isDirectUser => targetUserIds.isNotEmpty;
  bool get isRoleBased => targetRole != null && targetRole!.isNotEmpty;
  bool get isTopicBroadcast => topic != null && topic!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'targetUserIds': targetUserIds,
      'targetRole': targetRole,
      'topic': topic,
    };
  }

  factory NotificationTarget.fromMap(Map<String, dynamic> map) {
    return NotificationTarget(
      targetUserIds: (map['targetUserIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      targetRole: map['targetRole']?.toString(),
      topic: map['topic']?.toString(),
    );
  }
}
