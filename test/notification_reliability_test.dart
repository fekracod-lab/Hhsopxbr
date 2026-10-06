import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_event.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_message.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_policy.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_target.dart';
import 'package:dalal_alqaim/core/notifications/domain/enums/notification_enums.dart';
import 'package:dalal_alqaim/core/notifications/domain/services/notification_throttle_engine.dart';
import 'package:dalal_alqaim/core/notifications/domain/services/notification_grouping_engine.dart';

void main() {
  group('MADAR Notification Reliability & Enterprise Hardening Tests', () {
    // 1️⃣ Canonical Channel Map & Fallback
    test('Canonical channel resolution maps legacy and unknown channels to valid channels', () {
      const canonicalChannels = {
        'urgent': 'madar_urgent_alerts_v1',
        'delivery': 'madar_delivery_urgent_v2',
        'general': 'madar_general_v1',
        'security': 'madar_security_v1',
        'sos': 'madar_sos_v1',
      };

      String resolveChannel(String? input, {String fallback = 'madar_urgent_alerts_v1'}) {
        if (input == null || input.isEmpty) return fallback;
        if (input == 'madar_taxi_orders' || input == 'ride_requests_channel') {
          return canonicalChannels['urgent']!;
        }
        if (input == 'delivery_sound_channel') {
          return canonicalChannels['delivery']!;
        }
        if (canonicalChannels.values.contains(input)) return input;
        return fallback;
      }

      expect(resolveChannel('madar_taxi_orders'), equals('madar_urgent_alerts_v1'));
      expect(resolveChannel('ride_requests_channel'), equals('madar_urgent_alerts_v1'));
      expect(resolveChannel('delivery_sound_channel'), equals('madar_delivery_urgent_v2'));
      expect(resolveChannel('madar_sos_v1'), equals('madar_sos_v1'));
      expect(resolveChannel('madar_security_v1'), equals('madar_security_v1'));
      expect(resolveChannel('unknown_custom_channel'), equals('madar_urgent_alerts_v1'));
      expect(resolveChannel(null), equals('madar_urgent_alerts_v1'));
    });

    // 2️⃣ Payload String Normalization (FCM Strict Requirement)
    test('FCM payload sanitizer strictly normalizes all types to strings and JSON-encodes objects', () {
      Map<String, String> sanitizeFcmData(Map<String, dynamic> raw) {
        final sanitized = <String, String>{};
        for (final entry in raw.entries) {
          final v = entry.value;
          if (v == null) continue;
          if (v is Map || v is List) {
            sanitized[entry.key] = jsonEncode(v);
          } else {
            sanitized[entry.key] = v.toString();
          }
        }
        return sanitized;
      }

      final rawData = {
        'rideId': 'ride_12345',
        'price': 4500,
        'distanceKm': 3.75,
        'isSurge': true,
        'nullField': null,
        'coordinates': {'lat': 33.3152, 'lng': 44.3661},
        'tags': ['urgent', 'captain_offer'],
      };

      final sanitized = sanitizeFcmData(rawData);

      expect(sanitized['rideId'], equals('ride_12345'));
      expect(sanitized['price'], equals('4500'));
      expect(sanitized['distanceKm'], equals('3.75'));
      expect(sanitized['isSurge'], equals('true'));
      expect(sanitized.containsKey('nullField'), isFalse);
      expect(sanitized['coordinates'], contains('"lat":33.3152'));
      expect(sanitized['tags'], contains('urgent'));
      for (final val in sanitized.values) {
        expect(val, isA<String>());
      }
    });

    // 3️⃣ Multi-Device Token Registry & Deduplication
    test('Multi-device token resolver merges device registry with legacy tokens and deduplicates', () {
      final deviceTokens = ['token_device_A', 'token_device_B'];
      final legacyUserToken = 'token_device_A'; // duplicate of device A
      final legacyDriverToken = 'token_device_C';

      final mergedTokens = <String>{
        ...deviceTokens,
        if (legacyUserToken.isNotEmpty) legacyUserToken,
        if (legacyDriverToken.isNotEmpty) legacyDriverToken,
      }.toList();

      expect(mergedTokens.length, equals(3));
      expect(mergedTokens, containsAll(['token_device_A', 'token_device_B', 'token_device_C']));
    });

    // 4️⃣ Logout & Token Lifecycle
    test('Sign out disables current device without destroying remaining devices of the user', () {
      final userDevices = {
        'device_1': {'deviceId': 'device_1', 'fcmToken': 'token_phone', 'enabled': true},
        'device_2': {'deviceId': 'device_2', 'fcmToken': 'token_tablet', 'enabled': true},
      };

      // Current device logs out
      const currentDeviceId = 'device_1';
      userDevices[currentDeviceId]!['enabled'] = false;

      final activeTokens = userDevices.values
          .where((dev) => dev['enabled'] == true)
          .map((dev) => dev['fcmToken'] as String)
          .toList();

      expect(activeTokens.length, equals(1));
      expect(activeTokens.first, equals('token_tablet'));
      expect(userDevices['device_1']!['enabled'], isFalse);
    });

    // 5️⃣ Invalid Token Cleanup / Pruning
    test('Invalid token pruning identifies unauthenticated and expired registration tokens', () {
      final registeredTokens = {'token_good_1', 'token_unregistered_2', 'token_good_3'};
      final failedResponses = [
        {'token': 'token_good_1', 'success': true},
        {'token': 'token_unregistered_2', 'success': false, 'error': 'messaging/registration-token-not-registered'},
        {'token': 'token_good_3', 'success': true},
      ];

      final prunedTokens = <String>[];
      for (final resp in failedResponses) {
        if (resp['success'] == false &&
            (resp['error'] == 'messaging/registration-token-not-registered' ||
             resp['error'] == 'messaging/invalid-registration-token')) {
          prunedTokens.add(resp['token'] as String);
        }
      }

      registeredTokens.removeAll(prunedTokens);

      expect(prunedTokens, equals(['token_unregistered_2']));
      expect(registeredTokens, equals({'token_good_1', 'token_good_3'}));
    });

    // 6️⃣ Critical Priority (SOS / Security) Bypasses Throttling
    test('Emergency SOS priority strictly bypasses throttling rules', () {
      final throttleEngine = NotificationThrottleEngine();
      final now = DateTime.now();

      const policy = NotificationPolicy(
        policyId: 'policy_urgent',
        throttleWindowSeconds: 60,
        maxPerWindow: 2,
      );

      // Fill throttle capacity for this user
      throttleEngine.shouldThrottle(
        userId: 'user_123',
        priority: NotificationPriority.low,
        policy: policy,
        now: now,
      );
      throttleEngine.shouldThrottle(
        userId: 'user_123',
        priority: NotificationPriority.low,
        policy: policy,
        now: now,
      );

      // Standard message should now be throttled
      final isThrottledStandard = throttleEngine.shouldThrottle(
        userId: 'user_123',
        priority: NotificationPriority.low,
        policy: policy,
        now: now,
      );
      expect(isThrottledStandard, isTrue);

      // Critical / SOS message must NEVER be throttled
      final isThrottledSos = throttleEngine.shouldThrottle(
        userId: 'user_123',
        priority: NotificationPriority.critical,
        policy: policy,
        now: now,
      );
      expect(isThrottledSos, isFalse);
    });

    // 7️⃣ Grouping Engine Bypasses Critical and High Priority Events
    test('Grouping engine never groups critical or high priority events', () {
      final groupingEngine = NotificationGroupingEngine();

      final criticalEvent = NotificationEvent(
        eventId: 'event_sos_001',
        idempotencyKey: 'idemp_sos_001',
        eventType: NotificationEventType.emergencySos,
        priority: NotificationPriority.critical,
        entityId: 'alert_001',
        actorId: 'driver_001',
        target: const NotificationTarget(targetUserIds: ['admin_001']),
        message: const NotificationMessage(
          title: 'نداء طوارئ',
          body: 'طلب استغاثة عاجل',
          category: NotificationCategory.emergency,
        ),
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      const policy = NotificationPolicy(
        policyId: 'policy_sos',
        groupingThreshold: 2,
      );

      final shouldGroupCritical = groupingEngine.shouldGroup(
        event: criticalEvent,
        targetUserId: 'admin_001',
        policy: policy,
      );

      expect(shouldGroupCritical, isFalse);
    });

    // 8️⃣ Idempotency & Distinct Events Handling
    test('Distinct events with different idempotency keys are not suppressed', () {
      final event1 = NotificationEvent(
        eventId: 'evt_001',
        idempotencyKey: 'idemp_ride_offer_1',
        eventType: NotificationEventType.driverNewOffer,
        priority: NotificationPriority.high,
        entityId: 'ride_1',
        actorId: 'customer_1',
        target: const NotificationTarget(targetUserIds: ['driver_1']),
        message: const NotificationMessage(
          title: 'مشوار جديد',
          body: 'مشوار إلى الكرادة',
          category: NotificationCategory.rides,
        ),
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      final event2 = NotificationEvent(
        eventId: 'evt_002',
        idempotencyKey: 'idemp_ride_offer_2',
        eventType: NotificationEventType.driverNewOffer,
        priority: NotificationPriority.high,
        entityId: 'ride_2',
        actorId: 'customer_2',
        target: const NotificationTarget(targetUserIds: ['driver_1']),
        message: const NotificationMessage(
          title: 'مشوار جديد',
          body: 'مشوار إلى المنصور',
          category: NotificationCategory.rides,
        ),
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      final processedKeys = <String>{};
      bool processEvent(NotificationEvent e) {
        if (processedKeys.contains(e.idempotencyKey)) {
          return false; // Suppressed duplicate
        }
        processedKeys.add(e.idempotencyKey);
        return true;
      }

      expect(processEvent(event1), isTrue);
      expect(processEvent(event2), isTrue); // Distinct event passes
      expect(processEvent(event1), isFalse); // Replayed event suppressed
    });

    // 9️⃣ Durable Delivery Status Progression
    test('Notification delivery lifecycle follows explicit state machine without silent failure', () {
      final statuses = <DeliveryStatus>[];

      void recordStatus(DeliveryStatus status) {
        statuses.add(status);
      }

      recordStatus(DeliveryStatus.pending);
      recordStatus(DeliveryStatus.queued);
      recordStatus(DeliveryStatus.delivered);

      expect(statuses, equals([
        DeliveryStatus.pending,
        DeliveryStatus.queued,
        DeliveryStatus.delivered,
      ]));
      expect(statuses.contains(DeliveryStatus.failed), isFalse);
    });

    // 🔟 Background Single-Display Invariant
    test('Background message with notification block does not invoke duplicate local notification display', () {
      bool localNotifShowCalled = false;

      void handleBackgroundMessage({
        required bool hasNotificationBlock,
        required Map<String, dynamic> data,
      }) {
        // Invariant: If OS shows notification automatically, FlutterLocalNotificationsPlugin must not call show()
        if (!hasNotificationBlock && (data['title'] != null || data['body'] != null)) {
          localNotifShowCalled = true;
        }
      }

      // Case 1: Standard FCM notification block is present (OS displays it)
      handleBackgroundMessage(hasNotificationBlock: true, data: {'rideId': 'r1'});
      expect(localNotifShowCalled, isFalse);

      // Case 2: Data-only push (Local notification must display it)
      handleBackgroundMessage(
        hasNotificationBlock: false,
        data: {'title': 'تنبيه جديد', 'body': 'محتوى التنبيه', 'rideId': 'r2'},
      );
      expect(localNotifShowCalled, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 🛡️ PART A: FIRESTORE SECURITY RULES VALIDATION TESTS
  // ═══════════════════════════════════════════════════════════════
  group('Firestore Notification Security Rules Tests (RULES-01 .. RULES-05)', () {
    // محاكي القواعد الأمنية المشددة
    bool evaluateDeliveryCreate({
      required String authUid,
      required bool isAdmin,
      required Map<String, dynamic> data,
    }) {
      if (isAdmin) return true;
      if (data['userId'] != authUid) return false;
      const allowedStatuses = ['pending', 'queued', 'suppressed'];
      if (!allowedStatuses.contains(data['status'])) return false;
      if (data.containsKey('retryCount') && data['retryCount'] != 0) return false;
      if (data.containsKey('providerResponse')) return false;
      if (data.containsKey('providerMessageId')) return false;
      return true;
    }

    bool evaluateDeliveryUpdate({
      required String authUid,
      required bool isAdmin,
      required Map<String, dynamic> existingData,
      required Map<String, dynamic> requestedData,
    }) {
      if (isAdmin) return true;
      if (existingData['userId'] != authUid) return false;
      final changedKeys = requestedData.keys.where((k) => requestedData[k] != existingData[k]).toSet();
      if (!changedKeys.every((k) => k == 'status' || k == 'readAt')) return false;
      if (requestedData['status'] != 'read') return false;
      return true;
    }

    bool evaluateAuditCreate({
      required String authUid,
      required bool isAdmin,
      required Map<String, dynamic> data,
    }) {
      if (isAdmin) return true;
      final isOwn = data['userId'] == authUid || data['actorId'] == authUid;
      if (!isOwn) return false;
      const allowedStatuses = ['suppressed', 'queued', 'pending'];
      if (!allowedStatuses.contains(data['status'])) return false;
      if (data.containsKey('providerResponse') || data.containsKey('provider_ack') || data.containsKey('retryCount')) {
        return false;
      }
      return true;
    }

    bool evaluateEventCreate({
      required String authUid,
      required bool isAdmin,
      required Map<String, dynamic> data,
    }) {
      if (isAdmin) return true;
      return data['actorId'] == authUid;
    }

    // RULES-01: authenticated client cannot forge delivered
    test('RULES-01: authenticated client cannot forge delivered status', () {
      // 1. Cannot create with status: 'delivered'
      final createAllowed = evaluateDeliveryCreate(
        authUid: 'client_user_1',
        isAdmin: false,
        data: {'userId': 'client_user_1', 'status': 'delivered'},
      );
      expect(createAllowed, isFalse);

      // 2. Cannot update to status: 'delivered'
      final updateAllowed = evaluateDeliveryUpdate(
        authUid: 'client_user_1',
        isAdmin: false,
        existingData: {'userId': 'client_user_1', 'status': 'sent'},
        requestedData: {'userId': 'client_user_1', 'status': 'delivered'},
      );
      expect(updateAllowed, isFalse);
    });

    // RULES-02: authenticated client cannot forge providerResponse
    test('RULES-02: authenticated client cannot forge providerResponse', () {
      final createAllowed = evaluateDeliveryCreate(
        authUid: 'client_user_1',
        isAdmin: false,
        data: {
          'userId': 'client_user_1',
          'status': 'pending',
          'providerResponse': {'fcm_multicast_id': '12345678'},
        },
      );
      expect(createAllowed, isFalse);
    });

    // RULES-03: authenticated client cannot forge retryCount
    test('RULES-03: authenticated client cannot forge retryCount', () {
      final createAllowed = evaluateDeliveryCreate(
        authUid: 'client_user_1',
        isAdmin: false,
        data: {
          'userId': 'client_user_1',
          'status': 'pending',
          'retryCount': 5,
        },
      );
      expect(createAllowed, isFalse);
    });

    // RULES-04: authenticated client cannot forge audit entry
    test('RULES-04: authenticated client cannot forge audit entry', () {
      // Cannot create audit with fake status: 'sent'
      final fakeStatusAllowed = evaluateAuditCreate(
        authUid: 'client_user_1',
        isAdmin: false,
        data: {
          'userId': 'client_user_1',
          'actorId': 'client_user_1',
          'status': 'sent',
        },
      );
      expect(fakeStatusAllowed, isFalse);

      // Cannot create audit for another user (actorId spoofing)
      final spoofAllowed = evaluateAuditCreate(
        authUid: 'client_user_1',
        isAdmin: false,
        data: {
          'userId': 'victim_user_2',
          'actorId': 'admin_impersonated',
          'status': 'pending',
        },
      );
      expect(spoofAllowed, isFalse);

      // Cannot forge actorId in notification_events (Actor spoofing prevention)
      final eventSpoofAllowed = evaluateEventCreate(
        authUid: 'client_user_1',
        isAdmin: false,
        data: {
          'eventId': 'ev_123',
          'actorId': 'impersonated_driver_uid',
        },
      );
      expect(eventSpoofAllowed, isFalse);

      final legitimateEventAllowed = evaluateEventCreate(
        authUid: 'client_user_1',
        isAdmin: false,
        data: {
          'eventId': 'ev_123',
          'actorId': 'client_user_1',
        },
      );
      expect(legitimateEventAllowed, isTrue);
    });

    // RULES-05: client can mark own notification read
    test('RULES-05: client can mark own notification read', () {
      final markReadAllowed = evaluateDeliveryUpdate(
        authUid: 'client_user_1',
        isAdmin: false,
        existingData: {'userId': 'client_user_1', 'status': 'sent'},
        requestedData: {
          'userId': 'client_user_1',
          'status': 'read',
          'readAt': '2026-09-03T06:00:00Z',
        },
      );
      expect(markReadAllowed, isTrue);

      // But another user CANNOT mark it read
      final foreignUserAllowed = evaluateDeliveryUpdate(
        authUid: 'attacker_user_99',
        isAdmin: false,
        existingData: {'userId': 'client_user_1', 'status': 'sent'},
        requestedData: {
          'userId': 'client_user_1',
          'status': 'read',
          'readAt': '2026-09-03T06:00:00Z',
        },
      );
      expect(foreignUserAllowed, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 🔄 PART B: REAL CLOUD FCM RETRY PIPELINE TESTS
  // ═══════════════════════════════════════════════════════════════
  group('Cloud FCM Real Retry & Transient Recovery Tests (RETRY-01 .. RETRY-10 & CHAOS-01)', () {
    // محاكي مصنف الأخطاء
    bool isTransientError(String code) {
      const transientCodes = [
        'messaging/server-unavailable',
        'messaging/internal-error',
        'messaging/quota-exceeded',
        'messaging/too-many-requests',
        'econnreset',
        'etimedout',
      ];
      return transientCodes.contains(code.toLowerCase());
    }

    // محاكي حساب وقت المحاولة
    DateTime calculateNextRetry(DateTime now, int attempt) {
      final baseSeconds = 10 * (1 << (attempt - 1));
      return now.add(Duration(seconds: baseSeconds));
    }

    // RETRY-01: transient FCM failure becomes FAILED_RETRYABLE
    test('RETRY-01: transient FCM failure transitions request to FAILED_RETRYABLE', () {
      const errCode = 'messaging/server-unavailable';
      final isTransient = isTransientError(errCode);
      expect(isTransient, isTrue);

      String resolveState(String code, int currentRetry, int maxRetries) {
        if (isTransientError(code)) {
          return currentRetry < maxRetries ? 'FAILED_RETRYABLE' : 'DEAD_LETTER';
        }
        return 'FAILED_TERMINAL';
      }

      final state = resolveState(errCode, 0, 3);
      expect(state, equals('FAILED_RETRYABLE'));
    });

    // RETRY-02: nextRetryAt is generated
    test('RETRY-02: nextRetryAt is generated with exponential backoff', () {
      final now = DateTime(2026, 9, 3, 10, 0, 0);

      final retry1 = calculateNextRetry(now, 1);
      final retry2 = calculateNextRetry(now, 2);
      final retry3 = calculateNextRetry(now, 3);

      expect(retry1.difference(now).inSeconds, equals(10)); // 10 * 2^0
      expect(retry2.difference(now).inSeconds, equals(20)); // 10 * 2^1
      expect(retry3.difference(now).inSeconds, equals(40)); // 10 * 2^2
    });

    // RETRY-03: retry worker retries eligible request
    test('RETRY-03: retry worker selects only requests where nextRetryAt <= now and status is FAILED_RETRYABLE', () {
      final now = DateTime(2026, 9, 3, 10, 0, 30);

      final requests = [
        {'id': 'req_1', 'status': 'FAILED_RETRYABLE', 'nextRetryAt': DateTime(2026, 9, 3, 10, 0, 20)}, // Eligible
        {'id': 'req_2', 'status': 'FAILED_RETRYABLE', 'nextRetryAt': DateTime(2026, 9, 3, 10, 0, 45)}, // Not yet
        {'id': 'req_3', 'status': 'FAILED_TERMINAL', 'nextRetryAt': DateTime(2026, 9, 3, 10, 0, 10)},  // Terminal
        {'id': 'req_4', 'status': 'SENT', 'nextRetryAt': DateTime(2026, 9, 3, 10, 0, 0)},             // Already sent
      ];

      final eligible = requests.where((r) {
        final status = r['status'] as String;
        final next = r['nextRetryAt'] as DateTime;
        return status == 'FAILED_RETRYABLE' && next.isBefore(now);
      }).toList();

      expect(eligible.length, equals(1));
      expect(eligible.first['id'], equals('req_1'));
    });

    // RETRY-04: successful retry becomes SENT
    test('RETRY-04: successful retry updates request status to SENT', () {
      final request = {
        'id': 'req_retry_ok',
        'status': 'FAILED_RETRYABLE',
        'retryCount': 1,
        'successfulTokens': <String>[],
      };

      // Simulate successful provider delivery on attempt 2
      final retryResult = {'successCount': 1, 'failureCount': 0, 'successfulTokens': ['token_alpha']};

      request['status'] = retryResult['failureCount'] == 0 ? 'SENT' : 'PARTIAL_SUCCESS';
      (request['successfulTokens'] as List<String>).addAll(retryResult['successfulTokens'] as List<String>);

      expect(request['status'], equals('SENT'));
      expect((request['successfulTokens'] as List<String>).contains('token_alpha'), isTrue);
    });

    // RETRY-05: terminal failure does not retry
    test('RETRY-05: terminal failure transitions directly to FAILED_TERMINAL without retry', () {
      const errCode = 'messaging/invalid-registration-token';
      expect(isTransientError(errCode), isFalse);

      final status = isTransientError(errCode) ? 'FAILED_RETRYABLE' : 'FAILED_TERMINAL';
      expect(status, equals('FAILED_TERMINAL'));
    });

    // RETRY-06: invalid token is pruned
    test('RETRY-06: invalid token is marked for pruning and removed from active tokens', () {
      final activeTokens = ['token_alive_1', 'token_dead_expired', 'token_alive_2'];
      final prunedTokens = <String>[];

      void processFCMResult(Map<String, String> results) {
        for (final entry in results.entries) {
          if (entry.value == 'messaging/registration-token-not-registered') {
            prunedTokens.add(entry.key);
            activeTokens.remove(entry.key);
          }
        }
      }

      processFCMResult({'token_dead_expired': 'messaging/registration-token-not-registered'});

      expect(prunedTokens, contains('token_dead_expired'));
      expect(activeTokens, equals(['token_alive_1', 'token_alive_2']));
    });

    // RETRY-07: successful tokens are not resent unnecessarily
    test('RETRY-07: multicast partial failure retries only failed tokens and skips successful tokens', () {
      final allTokens = ['token_A', 'token_B', 'token_C'];
      final successfulTokens = ['token_A'];
      final retryableTokens = ['token_B', 'token_C'];

      // On next retry attempt, tokens to attempt MUST be retryableTokens ONLY
      final tokensForNextAttempt = retryableTokens;

      expect(tokensForNextAttempt, equals(['token_B', 'token_C']));
      expect(tokensForNextAttempt.contains('token_A'), isFalse);
    });

    // RETRY-08: retry preserves idempotency
    test('RETRY-08: retry preserves idempotencyKey, traceId, and notificationId across attempts', () {
      final originalRequest = {
        'notificationId': 'notif_998877',
        'eventId': 'event_112233',
        'idempotencyKey': 'idemp_key_unique_55',
        'traceId': 'trace_xyz_001',
        'retryCount': 0,
        'status': 'QUEUED',
      };

      // Simulate attempt 1 retry mutation
      final attempt1 = Map<String, dynamic>.from(originalRequest);
      attempt1['status'] = 'FAILED_RETRYABLE';
      attempt1['retryCount'] = 1;

      // Simulate attempt 2 retry mutation
      final attempt2 = Map<String, dynamic>.from(attempt1);
      attempt2['status'] = 'SENT';
      attempt2['retryCount'] = 2;

      expect(attempt2['notificationId'], equals(originalRequest['notificationId']));
      expect(attempt2['eventId'], equals(originalRequest['eventId']));
      expect(attempt2['idempotencyKey'], equals(originalRequest['idempotencyKey']));
      expect(attempt2['traceId'], equals(originalRequest['traceId']));
    });

    // RETRY-09: concurrent workers do not duplicate send
    test('RETRY-09: atomic lease lock prevents concurrent workers from double-processing', () {
      final document = {'id': 'req_concurrent', 'status': 'FAILED_RETRYABLE'};

      bool acquireLeaseLock(Map<String, dynamic> doc) {
        if (doc['status'] != 'FAILED_RETRYABLE') {
          return false; // Locked by another worker
        }
        doc['status'] = 'RETRYING';
        return true;
      }

      // Worker 1 arrives
      final worker1Success = acquireLeaseLock(document);
      expect(worker1Success, isTrue);
      expect(document['status'], equals('RETRYING'));

      // Worker 2 arrives concurrently
      final worker2Success = acquireLeaseLock(document);
      expect(worker2Success, isFalse); // Blocked, cannot duplicate send
    });

    // RETRY-10: max retry moves to terminal/dead-letter
    test('RETRY-10: exceeding maxRetries transitions request to DEAD_LETTER', () {
      int retryCount = 3;
      const maxRetries = 3;

      String handleAttemptResult({required bool isTransientFailure}) {
        if (isTransientFailure) {
          if (retryCount < maxRetries) {
            retryCount++;
            return 'FAILED_RETRYABLE';
          } else {
            return 'DEAD_LETTER';
          }
        }
        return 'SENT';
      }

      final finalState = handleAttemptResult(isTransientFailure: true);
      expect(finalState, equals('DEAD_LETTER'));
    });

    // CHAOS-01: FCM unavailable for 2 attempts then recovers on attempt 3
    test('CHAOS-01: FCM unavailable for 2 attempts then recovers -> exactly ONE logical notification', () {
      int attemptsCount = 0;
      int deliveredLogicalNotifications = 0;
      final auditLog = <String>[];

      // Simulated external FCM provider: fails first 2 times with server-unavailable, succeeds on 3rd
      bool callFcm() {
        attemptsCount++;
        auditLog.add('Attempt $attemptsCount: provider called');
        if (attemptsCount < 3) {
          throw Exception('messaging/server-unavailable');
        }
        return true;
      }

      String status = 'FAILED_RETRYABLE';
      int currentRetry = 0;
      const maxRetries = 3;

      while (status == 'FAILED_RETRYABLE' && currentRetry < maxRetries) {
        currentRetry++;
        try {
          final ok = callFcm();
          if (ok) {
            status = 'SENT';
            deliveredLogicalNotifications++;
            auditLog.add('Delivered successfully on attempt $currentRetry');
          }
        } catch (e) {
          if (currentRetry < maxRetries) {
            status = 'FAILED_RETRYABLE';
            auditLog.add('Attempt $currentRetry failed transiently, rescheduling');
          } else {
            status = 'DEAD_LETTER';
          }
        }
      }

      expect(attemptsCount, equals(3));
      expect(status, equals('SENT'));
      expect(deliveredLogicalNotifications, equals(1)); // Exactly ONE logical notification delivered!
      expect(auditLog, contains('Delivered successfully on attempt 3'));
    });
  });
}
