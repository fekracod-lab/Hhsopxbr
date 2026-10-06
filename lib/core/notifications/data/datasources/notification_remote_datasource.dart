import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/notification_event.dart';
import '../../domain/entities/notification_message.dart';
import '../../domain/entities/notification_delivery.dart';
import '../../domain/entities/notification_preference.dart';
import '../../domain/entities/notification_policy.dart';
import '../../domain/entities/notification_audit_record.dart';
import '../../domain/enums/notification_enums.dart';

/// مصدر البيانات البعيد للإشعارات الموحدة (Notification Remote Datasource)
class NotificationRemoteDatasource {
  final FirebaseFirestore? _customFirestore;

  NotificationRemoteDatasource({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  /// حفظ حدث الإشعار
  Future<NotificationEvent> saveEvent(NotificationEvent event) async {
    final docRef = _firestore.collection('notification_events').doc(event.eventId);
    await docRef.set(event.toMap());
    return event;
  }

  /// حفظ وتحديث سجل التسليم
  Future<NotificationDelivery> saveDelivery(NotificationDelivery delivery) async {
    final docRef = _firestore.collection('notification_deliveries').doc(delivery.deliveryId);
    await docRef.set(delivery.toMap());
    return delivery;
  }

  /// جلب سجل التسليم
  Future<NotificationDelivery?> getDelivery(String deliveryId) async {
    final doc = await _firestore.collection('notification_deliveries').doc(deliveryId).get();
    if (!doc.exists || doc.data() == null) return null;
    return NotificationDelivery.fromMap(doc.data()!, doc.id);
  }

  /// جلب تفضيلات المستخدم
  Future<NotificationPreference> getPreference(String userId) async {
    try {
      final doc = await _firestore.collection('notification_preferences').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return NotificationPreference.fromMap(doc.data()!, doc.id);
      }
    } catch (_) {}
    return NotificationPreference(userId: userId);
  }

  /// حفظ تفضيلات المستخدم
  Future<void> savePreference(NotificationPreference preference) async {
    final docRef = _firestore.collection('notification_preferences').doc(preference.userId);
    await docRef.set(preference.toMap());
  }

  /// جلب سياسة الإشعارات النشطة
  Future<NotificationPolicy> getPolicy() async {
    try {
      final doc = await _firestore.collection('notification_policies').doc('active').get();
      if (doc.exists && doc.data() != null) {
        return NotificationPolicy.fromMap(doc.data()!);
      }
    } catch (_) {}
    return const NotificationPolicy();
  }

  /// حفظ سجل تدقيق للإشعار (Append-only audit)
  Future<void> saveAuditRecord(NotificationAuditRecord record) async {
    final docRef = _firestore.collection('notification_audit').doc(record.auditId);
    await docRef.set(record.toMap());
  }

  /// التحقق من مفتاح عدم التكرار
  Future<bool> verifyIdempotencyKey(String idempotencyKey) async {
    final docRef = _firestore.collection('idempotency_keys').doc(idempotencyKey);
    final doc = await docRef.get();
    if (doc.exists) {
      return false;
    }
    await docRef.set({
      'key': idempotencyKey,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  /// تسليم الإشعار عبر القناة المناسبة
  Future<bool> deliverViaChannel({
    required NotificationDelivery delivery,
    required NotificationMessage message,
  }) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? delivery.userId;
      final stringifiedMetadata = message.metadata.map((k, v) => MapEntry(k, v?.toString() ?? ''));

      // 1. كتابة في notification_requests لمعالجة الـ FCM السحابي مع كامل الحقول المطلوبة وقواعد الحماية
      await _firestore.collection('notification_requests').add({
        'notificationId': delivery.deliveryId,
        'eventId': delivery.eventId,
        'type': 'user_notification',
        'senderId': currentUid,
        'targetUserId': delivery.userId,
        'userId': delivery.userId,
        'title': message.title,
        'body': message.body,
        'channelId': delivery.channel == NotificationChannel.sms ? 'madar_general_v1' : 'madar_urgent_alerts_v1',
        'priority': 'high',
        'payload': {
          'userId': delivery.userId,
          'title': message.title,
          'body': message.body,
          ...stringifiedMetadata,
        },
        'data': stringifiedMetadata,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'QUEUED',
      });

      // 2. كتابة في سجل الإشعارات للمستخدم notifications لعرضها داخل التطبيق
      await _firestore.collection('notifications').add({
        'userId': delivery.userId,
        'senderId': currentUid,
        'title': message.title,
        'body': message.body,
        'type': message.category.key,
        'isRead': false,
        'data': stringifiedMetadata,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint(' [NotificationRemoteDatasource] deliverViaChannel failed: $e');
      return false;
    }
  }
}
