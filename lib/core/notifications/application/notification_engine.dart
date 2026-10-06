import '../domain/entities/notification_event.dart';
import '../domain/entities/notification_message.dart';
import '../domain/entities/notification_target.dart';
import '../domain/entities/notification_delivery.dart';
import '../domain/entities/notification_audit_record.dart';
import '../domain/enums/notification_enums.dart';
import '../domain/services/notification_priority_engine.dart';
import '../domain/services/notification_deduplication_engine.dart';
import '../domain/services/notification_throttle_engine.dart';
import '../domain/services/notification_grouping_engine.dart';
import '../domain/services/notification_retry_engine.dart';
import '../domain/repositories/i_notification_repository.dart';
import '../data/repositories/notification_repository.dart';

/// المحرك المركزي لإدارة وتوجيه الإشعارات الذكية (Notification Intelligence Engine)
class NotificationEngine {
  static NotificationEngine? _instance;
  static NotificationEngine get instance => _instance ??= NotificationEngine();

  final INotificationRepository _repository;
  final NotificationDeduplicationEngine _dedupEngine;
  final NotificationThrottleEngine _throttleEngine;
  final NotificationGroupingEngine _groupingEngine;

  NotificationEngine({
    INotificationRepository? repository,
    NotificationDeduplicationEngine? dedupEngine,
    NotificationThrottleEngine? throttleEngine,
    NotificationGroupingEngine? groupingEngine,
  }) : _repository = repository ?? NotificationRepository(),
        _dedupEngine = dedupEngine ?? NotificationDeduplicationEngine(),
        _throttleEngine = throttleEngine ?? NotificationThrottleEngine(),
        _groupingEngine = groupingEngine ?? NotificationGroupingEngine();

  /// معالجة وتوجيه حدث الإشعار عبر خط الأنابيب الذكي الكامل (Full Pipeline Dispatch)
  Future<List<NotificationDelivery>> dispatchEvent(NotificationEvent event) async {
    // 1. فحص التكرار (Deduplication)
    if (_dedupEngine.isDuplicate(event.idempotencyKey)) {
      return []; // تم تجاهل الحدث المكرر
    }
    _dedupEngine.markProcessed(event.idempotencyKey);

    // 2. حفظ الحدث
    await _repository.saveEvent(event);

    // 3. جلب سياسة الإشعارات
    final policy = await _repository.getPolicy();

    final deliveries = <NotificationDelivery>[];
    final targetUsers = event.target.targetUserIds;

    // في حال كان الإشعار موجه لأشخاص محددين
    for (final userId in targetUsers) {
      final deliveryId = 'del-${event.eventId}-$userId';
      var delivery = NotificationDelivery(
        deliveryId: deliveryId,
        eventId: event.eventId,
        userId: userId,
        channel: NotificationChannel.push,
        status: DeliveryStatus.pending,
        createdAt: DateTime.now(),
      );

      // 4. فحص تفضيلات المستخدم (Preferences)
      final preference = await _repository.getPreference(userId);
      if (!preference.isCategoryEnabled(event.message.category)) {
        delivery = delivery.copyWith(status: DeliveryStatus.suppressed);
        await _repository.saveDelivery(delivery);
        await _audit(event, userId, DeliveryStatus.suppressed, 'تم كتم الإشعار بناءً على تفضيلات المستخدم');
        deliveries.add(delivery);
        continue;
      }

      // 5. فحص الخنق وحماية منع الإغراق (Throttling)
      if (_throttleEngine.shouldThrottle(
        userId: userId,
        priority: event.priority,
        policy: policy,
      )) {
        delivery = delivery.copyWith(status: DeliveryStatus.suppressed);
        await _repository.saveDelivery(delivery);
        await _audit(event, userId, DeliveryStatus.suppressed, 'تم كتم الإشعار لحماية المستخدم من الإغراق (Throttled)');
        deliveries.add(delivery);
        continue;
      }

      // 6. فحص التجميع (Grouping)
      if (_groupingEngine.shouldGroup(
        event: event,
        targetUserId: userId,
        policy: policy,
      )) {
        delivery = delivery.copyWith(status: DeliveryStatus.queued);
        await _repository.saveDelivery(delivery);
        await _audit(event, userId, DeliveryStatus.queued, 'تم إدراج الإشعار ضمن دفعة تجميعية (Grouped)');
        deliveries.add(delivery);
        continue;
      }

      // 7. تسليم الإشعار عبر القناة (Delivery Execution)
      delivery = delivery.copyWith(status: DeliveryStatus.sending, sentAt: DateTime.now());
      final success = await _repository.deliverViaChannel(
        delivery: delivery,
        message: event.message,
      );

      if (success) {
        delivery = delivery.copyWith(
          status: DeliveryStatus.delivered,
          deliveredAt: DateTime.now(),
        );
        await _audit(event, userId, DeliveryStatus.delivered, 'تم تسليم الإشعار بنجاح');
      } else {
        // إدارة حاول مرة ثانية
        if (NotificationRetryEngine.canRetry(delivery.retryCount, policy.maxRetries)) {
          delivery = delivery.copyWith(
            status: DeliveryStatus.retrying,
            retryCount: delivery.retryCount + 1,
            failureReason: 'فشل التسليم الأولي - جاري حاول مرة ثانية',
          );
          await _audit(event, userId, DeliveryStatus.retrying, 'جاري حاول مرة ثانية بعد تعذر التسليم');
        } else {
          delivery = delivery.copyWith(
            status: DeliveryStatus.failed,
            failureReason: 'استنفاد كافة محاولات التسليم',
          );
          await _audit(event, userId, DeliveryStatus.failed, 'فشل نهائي بعد استنفاد المحاولات');
        }
      }

      await _repository.saveDelivery(delivery);
      deliveries.add(delivery);
    }

    return deliveries;
  }

  /// إرسال إشعار فوري سريع
  Future<List<NotificationDelivery>> emitQuickNotification({
    required NotificationEventType eventType,
    required String entityId,
    required String targetUserId,
    required String title,
    required String body,
    NotificationCategory category = NotificationCategory.system,
    Map<String, dynamic> metadata = const {},
  }) async {
    final priority = NotificationPriorityEngine.resolvePriority(eventType);
    final event = NotificationEvent(
      eventId: 'evt-${DateTime.now().millisecondsSinceEpoch}',
      eventType: eventType,
      entityId: entityId,
      actorId: 'system',
      target: NotificationTarget(targetUserIds: [targetUserId]),
      priority: priority,
      message: NotificationMessage(
        title: title,
        body: body,
        category: category,
        metadata: metadata,
      ),
      idempotencyKey: 'idemp_${eventType.key}_${entityId}_${targetUserId}_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    );

    return await dispatchEvent(event);
  }

  Future<void> _audit(
    NotificationEvent event,
    String userId,
    DeliveryStatus status,
    String reason,
  ) async {
    final record = NotificationAuditRecord(
      auditId: 'aud-${event.eventId}-$userId-${DateTime.now().millisecondsSinceEpoch}',
      eventId: event.eventId,
      userId: userId,
      eventType: event.eventType,
      priority: event.priority,
      channel: NotificationChannel.push,
      status: status,
      reason: reason,
      timestamp: DateTime.now(),
    );
    await _repository.saveAuditRecord(record);
  }
}
