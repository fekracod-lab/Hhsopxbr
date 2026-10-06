import '../entities/notification_event.dart';
import '../entities/notification_message.dart';
import '../entities/notification_policy.dart';
import '../enums/notification_enums.dart';

/// محرك تجميع ودمج الإشعارات المتتابعة (Notification Grouping Engine)
class NotificationGroupingEngine {
  final Map<String, List<NotificationEvent>> _groupedEvents = {};

  NotificationGroupingEngine();

  /// توليد مفتاح التجميع الحتمي
  static String generateGroupKey(NotificationEvent event, String targetUserId) {
    return 'grp_${targetUserId}_${event.entityId}_${event.eventType.key.split('.').first}';
  }

  /// التحقق مما إذا كان الحدث يستوجب التجميع
  /// قاعدة أمنية: لا يتم تجميع إشعارات الطوارئ والأمان أو العروض الحرجة
  bool shouldGroup({
    required NotificationEvent event,
    required String targetUserId,
    required NotificationPolicy policy,
  }) {
    if (event.priority.isCritical || event.priority == NotificationPriority.high) {
      return false; // إشعارات عالية الأهمية ترسل فوراً دون تجميع
    }

    final key = generateGroupKey(event, targetUserId);
    final group = _groupedEvents.putIfAbsent(key, () => []);
    group.add(event);

    return group.length >= policy.groupingThreshold;
  }

  /// إنشاء رسالة مجمعة بديلة
  NotificationMessage createGroupedMessage({
    required String targetUserId,
    required String entityId,
    required String categoryPrefix,
    required int count,
  }) {
    return NotificationMessage(
      title: 'تحديثات متعددة على $categoryPrefix',
      body: 'لديك $count تحديثات جديدة متتابعة على طلبك ($entityId)',
      category: NotificationCategory.orders,
      metadata: {
        'entityId': entityId,
        'groupedCount': count,
      },
    );
  }

  /// جلب الأحداث المجمعة وتفريغها
  List<NotificationEvent> flushGroup(String key) {
    return _groupedEvents.remove(key) ?? [];
  }

  void clear() {
    _groupedEvents.clear();
  }
}
