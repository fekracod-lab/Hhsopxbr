import 'package:flutter/foundation.dart';
import '../enums/notification_enums.dart';

/// تفضيلات وقنوات الإشعارات الخاصة بالمستخدم (User Notification Preferences)
@immutable
class NotificationPreference {
  final String userId;
  final bool ordersEnabled;
  final bool ridesEnabled;
  final bool financialEnabled;
  final bool marketingEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool badgeEnabled;

  const NotificationPreference({
    required this.userId,
    this.ordersEnabled = true,
    this.ridesEnabled = true,
    this.financialEnabled = true,
    this.marketingEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.badgeEnabled = true,
  });

  /// التحقق مما إذا كانت الفئة مفعلة لدى المستخدم
  /// ملاحظة أمنية: إشعارات الأمان والطوارئ (Security & Emergency) لا يمكن تعطيلها أبداً
  bool isCategoryEnabled(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.security:
      case NotificationCategory.emergency:
        return true; // غير قابلة للإلغاء إطلاقاً
      case NotificationCategory.orders:
        return ordersEnabled;
      case NotificationCategory.rides:
        return ridesEnabled;
      case NotificationCategory.financial:
        return financialEnabled;
      case NotificationCategory.marketing:
        return marketingEnabled;
      case NotificationCategory.messages:
      case NotificationCategory.system:
        return true;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'ordersEnabled': ordersEnabled,
      'ridesEnabled': ridesEnabled,
      'financialEnabled': financialEnabled,
      'marketingEnabled': marketingEnabled,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'badgeEnabled': badgeEnabled,
    };
  }

  factory NotificationPreference.fromMap(Map<String, dynamic> map, String docId) {
    return NotificationPreference(
      userId: docId,
      ordersEnabled: map['ordersEnabled'] != false,
      ridesEnabled: map['ridesEnabled'] != false,
      financialEnabled: map['financialEnabled'] != false,
      marketingEnabled: map['marketingEnabled'] != false,
      soundEnabled: map['soundEnabled'] != false,
      vibrationEnabled: map['vibrationEnabled'] != false,
      badgeEnabled: map['badgeEnabled'] != false,
    );
  }
}
