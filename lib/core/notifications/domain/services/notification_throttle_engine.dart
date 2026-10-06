import '../entities/notification_policy.dart';
import '../enums/notification_enums.dart';

/// محرك خنق وتحديد معدل الإشعارات وحماية منع الإغراق (Notification Throttle Engine)
class NotificationThrottleEngine {
  final Map<String, List<DateTime>> _userSendTimestamps = {};

  NotificationThrottleEngine();

  /// فحص هل يجب خنق/كتم الإشعار لحماية المستخدم من الإغراق (Spam / Burst Protection)
  /// قاعدة أمنية قطعية: إشعارات الطوارئ والأمان (Critical Priority) لا يتم خنقها إطلاقاً
  bool shouldThrottle({
    required String userId,
    required NotificationPriority priority,
    required NotificationPolicy policy,
    DateTime? now,
  }) {
    if (priority.isCritical) {
      return false; // طوارئ وأمان: لا تخنق أبداً!
    }

    if (userId.isEmpty) return false;

    final currentTime = now ?? DateTime.now();
    final windowCutoff = currentTime.subtract(Duration(seconds: policy.throttleWindowSeconds));

    final history = _userSendTimestamps.putIfAbsent(userId, () => []);
    // إزالة التواريخ التي خرجت من النافذة الزمنية
    history.removeWhere((timestamp) => timestamp.isBefore(windowCutoff));

    if (history.length >= policy.maxPerWindow) {
      return true; // تجاوز الحد الأقصى للإشعارات في النافذة
    }

    // تسجيل الإرسال الجديد
    history.add(currentTime);
    return false;
  }

  void resetUser(String userId) {
    _userSendTimestamps.remove(userId);
  }

  void clear() {
    _userSendTimestamps.clear();
  }
}
