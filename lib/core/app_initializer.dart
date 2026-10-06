import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/core/app_globals.dart';
import 'package:dalal_alqaim/firebase_options.dart';
import 'package:dalal_alqaim/services/user_service.dart';
import 'package:dalal_alqaim/services/app_location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── الحزم التي تعمل على الموبايل فقط ───
import 'package:dalal_alqaim/services/onesignal_service.dart';
import 'package:dalal_alqaim/services/notification_router.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dalal_alqaim/services/notification_service.dart';
import 'package:dalal_alqaim/services/ringtone_manager.dart';
import 'package:dalal_alqaim/core/automation/smart_assistant_config.dart';
import 'package:dalal_alqaim/core/observability/observability.dart';
import 'package:intl/date_symbol_data_local.dart';

/// إشعارات محلية — تُنشأ فقط على الموبايل
FlutterLocalNotificationsPlugin? _localNotif;

const AndroidNotificationChannel deliveryChannel = AndroidNotificationChannel(
  'madar_delivery_urgent_v2',
  'طلبات التوصيل والمرسال العاجلة',
  description: 'إشعارات طلبات مرسال، الطرود، والمطاعم بصوت مرتفع',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

final AndroidNotificationChannel alertsChannel = AndroidNotificationChannel(
  'madar_urgent_alerts_v1',
  'طلبات مدار العاجلة',
  description: 'إشعارات الطلبات والرحلات الجديدة العاجلة',
  importance: Importance.max,
  playSound: true,
  vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
);

const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
  'madar_general_v1',
  'إشعارات مدار العامة',
  description: 'تحديثات النظام والإعلانات والرسائل',
  importance: Importance.defaultImportance,
);

const AndroidNotificationChannel securityChannel = AndroidNotificationChannel(
  'madar_security_v1',
  'تنبيهات الأمان والحساب',
  description: 'تنبيهات أمان الحساب والعمليات الحساسة',
  importance: Importance.high,
  enableVibration: true,
);

final AndroidNotificationChannel sosChannel = AndroidNotificationChannel(
  'madar_sos_v1',
  'نداءات الطوارئ والاستغاثة (SOS)',
  description: 'نداءات الاستغاثة وحالات الطوارئ الميدانية العاجلة',
  importance: Importance.max,
  playSound: true,
  vibrationPattern: Int64List.fromList([0, 1500, 500, 1500, 500, 1500]),
);

/// معالجة الضغط على الإشعار المحلي
void _onNotificationTap(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;

  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    NotificationRouter.handleNotificationData(data);
  } catch (e) {
    AppLogger.warning('Notification tap parse/route error', tag: 'AppInit', error: e);
  }
}

/// منظومة التهيئة المركزية لمنصة مدار وفق تصنيف التبعيات (4-Tier Dependency Architecture):
///
/// 1. TIER A — CRITICAL (حرج وفوري): كل ما تحتاجه أول شاشة لرسم أول إطار بأمان.
/// 2. TIER B — USER-DEPENDENT (مشروط بهوية المستخدم): مزامنة التوكنات وتحديث الأدوار بعد تسجيل الدخول.
/// 3. TIER C — DEFERRED (مؤجل لما بعد أول إطار): تهيئة الخرائط ومستمعي الإشعارات في الخلفية.
/// 4. TIER D — LAZY (عند الطلب الفعلي فقط): خدمة التكسي وبث GPS المستمر عند دخول الميزة فقط.
class AppInitializer {
  static bool _isCriticalInitDone = false;
  static bool _isDeferredInitDone = false;

  /// TIER A: التهيئة الحرجة الخفيفة فقط (Critical Fast Path)
  /// تضمن توفر Firebase و Auth و Locale و User Cache قبل runApp()
  static Future<void> initCritical() async {
    if (_isCriticalInitDone) return;
    PerformanceTracker.startTrace('startup_bootstrap');

    WidgetsFlutterBinding.ensureInitialized();

    // 1. تهيئة Firebase الأساسية وتتبع الأخطاء أولاً (Critical Dependency Anchor)
    try {
      PerformanceTracker.startTrace('firebase_init');
      final firebaseSw = Stopwatch()..start();
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      firebaseSw.stop();
      PerformanceTracker.stopTrace('firebase_init', isSuccess: true);
      final fbDuration = PerformanceTracker.getDuration('firebase_init') ?? firebaseSw.elapsedMilliseconds;
      debugPrint('[Madar Benchmark] FIREBASE_INIT: ${fbDuration}ms');

      await AppLogger.init();
    } catch (e, stackTrace) {
      PerformanceTracker.stopTrace('firebase_init', isSuccess: false, details: e.toString());
      AppLogger.fatal('Firebase Init Failed in AppInitializer', error: e, stackTrace: stackTrace);
      return;
    }

    // 2. تهيئة اللغات وتنسيق التاريخ في الخلفية بدون حجب أول إطار
    initializeDateFormatting('ar_IQ', null).catchError((e) {
      debugPrint(' Date formatting ar_IQ non-fatal: $e');
    });
    initializeDateFormatting('ar', null).catchError((e) {
      debugPrint(' Date formatting ar non-fatal: $e');
    });

    // 3. تحميل الدور والمستخدم من الذاكرة المحلية والخدمة بأمان بعد تهيئة Firebase
    try {
      final prefs = await SharedPreferences.getInstance();
      currentUserRole = prefs.getString('currentUserRole');
      await UserService().init();

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null) {
        await AppLogger.setUserContext(
          userId: currentUid,
          role: currentUserRole,
        );
      }
    } catch (e) {
      debugPrint(' User/Prefs fast read error: $e');
    }

    // 4. تحميل كاش الموقع الجغرافي المخزن محلياً فقط (دون تفعيل GPS الحقيقي)
    try {
      await AppLocationService().init();
    } catch (e) {
      debugPrint(' AppLocationService fast cache read error: $e');
    }

    _isCriticalInitDone = true;
    PerformanceTracker.stopTrace('startup_bootstrap', isSuccess: true);
  }

  /// TIER C: التهيئة المؤجلة بعد رسم أول إطار (Post-Frame Deferred Init)
  static void postFrameInit() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_isDeferredInitDone) return;
      _isDeferredInitDone = true;

      // 1. إعداد مستمعي الإشعارات السريعة
      _setupFCMListeners();

      // 2. تشغيل المهام الثقيلة وغير الحرجة في الخلفية دون أي حجب للواجهة
      // تم إلغاء تهيئة الخرائط هنا؛ الخرائط تُهيأ فقط عند دخول شاشة تحتوي خريطة فعلياً
      Future.delayed(const Duration(milliseconds: 1500), () async {
        // طلب الأذونات ومزامنة التوكن في الخلفية
        await _initNotificationsAndAuthSync();

        // تهيئة إعدادات المساعد الذكي
        try {
          SmartAssistantConfig.loadApiKey();
        } catch (e) {
          debugPrint(' SmartAssistantConfig non-fatal: $e');
        }

        isAppStarting = false;
        debugPrint(' [Madar Benchmark] BACKGROUND_SERVICES_SYNC completed.');
        NotificationRouter.processPendingNotification();
      });
    });
  }

  static void _setupFCMListeners() {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return;
    }
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      final data = message.data;
      final type = data['type']?.toString() ?? data['notification_type']?.toString();

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      bool shouldShow = NotificationService.shouldDisplayNotification(
        data: data,
        currentRole: currentUserRole,
        currentUid: currentUid,
      );

      if (!shouldShow) return;

      final requestId = data['rideId'] ??
          data['ride_id'] ??
          data['requestId'] ??
          data['request_id'] ??
          data['orderId'] ??
          data['order_id'] ??
          data['id'] ??
          message.messageId ??
          'unknown_request';

      final isAlertRequest = type == 'new_ride' ||
          type == 'ride_request' ||
          type == 'taxi_request' ||
          type == 'new_request' ||
          type == 'mersal_request' ||
          type == 'delegate_request' ||
          type == 'parcel_request' ||
          type == 'food_order' ||
          type == 'new_store_order' ||
          type == 'store_order' ||
          type == 'restaurant_order' ||
          type == 'store_order_ready' ||
          type == 'food_order_ready' ||
          type == 'taxi_broadcast';

      final isUrgentRequest = type == 'new_ride' ||
          type == 'ride_request' ||
          type == 'taxi_request' ||
          type == 'mersal_request' ||
          type == 'new_mersal_request' ||
          type == 'delegate_request' ||
          type == 'parcel_request' ||
          type == 'new_store_order';

      if (isAlertRequest) {
        await RingtoneManager.startAlarm(requestId.toString());
      }

      final isCancellationOrAccept = type == 'ride_update' ||
          type == 'trip_cancelled' ||
          type == 'ride_cancelled' ||
          type == 'ride_accepted' ||
          type == 'mersal_accepted' ||
          type == 'mersal_cancelled' ||
          type == 'order_accepted' ||
          type == 'order_cancelled' ||
          type == 'store_order_cancelled' ||
          type == 'store_order_accepted';
      if (isCancellationOrAccept) {
        await RingtoneManager.stopAlarm(requestId.toString());
      }

      if (notification != null) {
        AndroidNotificationChannel channelToUse;
        if (type == 'emergency_sos') {
          channelToUse = sosChannel;
        } else if (type == 'security_alert') {
          channelToUse = securityChannel;
        } else if (isUrgentRequest) {
          channelToUse = alertsChannel;
        } else if (type == 'mersal_request' || type == 'delegate_request' || type == 'parcel_request' || type == 'food_order') {
          channelToUse = deliveryChannel;
        } else {
          channelToUse = generalChannel;
        }

        if (!kIsWeb && _localNotif != null) {
          try {
            await _localNotif!.show(
              id: requestId.hashCode,
              title: notification.title,
              body: notification.body,
              payload: jsonEncode(data, toEncodable: (nonEncodable) {
                if (nonEncodable is Timestamp) return nonEncodable.toDate().toIso8601String();
                if (nonEncodable is DateTime) return nonEncodable.toIso8601String();
                return nonEncodable.toString();
              }),
              notificationDetails: NotificationDetails(
                android: AndroidNotificationDetails(
                  channelToUse.id,
                  channelToUse.name,
                  channelDescription: channelToUse.description,
                  importance: Importance.max,
                  priority: Priority.high,
                  playSound: true,
                  enableVibration: true,
                  fullScreenIntent: isUrgentRequest,
                  category: isUrgentRequest ? AndroidNotificationCategory.call : null,
                  vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
                ),
              ),
            );
          } catch (e) {
            debugPrint(' Foreground Local Notification error: $e');
          }
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(' [FCM] Notification opened: ${message.data}');
      NotificationRouter.handleNotificationData(message.data);
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint(' [FCM] Cold-start notification opened: ${message.data}');
        NotificationRouter.handleNotificationData(message.data);
      }
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      syncFCMToken();
    });

    FirebaseAuth.instance.authStateChanges().listen((user) {
      syncFCMToken();
      if (user != null) {
        OneSignalService.syncUserRole(user.uid);
      }
    });
  }

  static Future<void> _initNotificationsAndAuthSync() async {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return;
    }
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notification_auth_status', settings.authorizationStatus.toString());

      if (!kIsWeb) {
        await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        _localNotif = FlutterLocalNotificationsPlugin();
        final androidPlugin =
            _localNotif!.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.createNotificationChannel(deliveryChannel);
        await androidPlugin?.createNotificationChannel(alertsChannel);
        await androidPlugin?.createNotificationChannel(generalChannel);
        await androidPlugin?.createNotificationChannel(securityChannel);
        await androidPlugin?.createNotificationChannel(sosChannel);

        await _localNotif!.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(),
          ),
          onDidReceiveNotificationResponse: _onNotificationTap,
        );

        try {
          await OneSignalService.initialize();
        } catch (e) {
          debugPrint(' OneSignal initialization non-fatal: $e');
        }
      }

      await syncFCMToken();
    } catch (e) {
      debugPrint('--- Notification Init Error: $e ---');
    }
  }

  /// الحصول على معرّف الجهاز الثابت للمنصة (Persistent Installation Device ID)
  static Future<String> getOrGenerateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('madar_device_installation_id');
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecondsSinceEpoch % 100000)}';
      await prefs.setString('madar_device_installation_id', deviceId);
    }
    return deviceId;
  }

  /// TIER B: مزامنة التوكنات وحالة المستخدم عند تسجيل الدخول أو التجديد مع دعم الأجهزة المتعددة
  static Future<void> syncFCMToken() async {
    try {
      final fcm = FirebaseMessaging.instance;
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final token = await fcm.getToken(vapidKey: kIsWeb ? 'BKagOny0KF_2pCJQ3m....lkQ' : null);

      if (token != null) {
        final deviceId = await getOrGenerateDeviceId();
        final batch = FirebaseFirestore.instance.batch();

        // 1. التوافق العكسي: حفظ التوكن القديم في users
        batch.set(FirebaseFirestore.instance.collection('users').doc(user.uid), {
          'fcmToken': token,
          'lastActive': FieldValue.serverTimestamp(),
          'isLoggedIn': true,
        }, SetOptions(merge: true));

        // 2. سجل الأجهزة المتعددة (Multi-Device Token Registry)
        final deviceDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notification_devices')
            .doc(deviceId);

        final prefs = await SharedPreferences.getInstance();
        currentUserRole = prefs.getString('currentUserRole') ?? currentUserRole ?? 'customer';
        final isDriver = currentUserRole == 'captain' || currentUserRole == 'driver' || currentUserRole == 'taxi_captain';
        if (isDriver) {
          batch.update(FirebaseFirestore.instance.collection('drivers').doc(user.uid), {
            'fcmToken': token,
          });
        }

        batch.set(deviceDocRef, {
          'deviceId': deviceId,
          'fcmToken': token,
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'appVersion': '1.0.0',
          'lastSeenAt': FieldValue.serverTimestamp(),
          'enabled': true,
          'role': currentUserRole ?? 'customer',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await prefs.setString('currentUserRole', currentUserRole ?? 'customer');
        if (user.uid.isNotEmpty) {
          await prefs.setString('currentUserId', user.uid);
        }

        await batch.commit();
        debugPrint(' FCM Multi-Device Token synced for device: $deviceId');
      }
    } catch (e) {
      debugPrint(' FCM Sync Error: $e ---');
    }
  }
}
