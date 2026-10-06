import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:dalal_alqaim/services/ringtone_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dalal_alqaim/firebase_options.dart';

/// معرّف قناة حالة الخدمة (اولوية منخفضة لتجنب الإزعاج)
const String _kServiceChannelId = 'service_channel';
const String _kServiceChannelName = 'حالة اتصال التطبيق';

/// معرّف قناة التنبيهات (اولوية عالية للطلبات والاشعارات الهامة)
const String _kAlertChannelId = 'ride_channel';
const String _kAlertChannelName = 'تنبيهات الرحلات';
const String _kAlertChannelDesc = 'تنبيهات طلبات الرحلات وتحديثات الحالة';

Map<String, dynamic> _sanitizeMap(Map<String, dynamic>? raw) {
  if (raw == null) return {};
  final sanitized = <String, dynamic>{};
  raw.forEach((key, value) {
    sanitized[key] = _sanitizeValue(value);
  });
  return sanitized;
}

dynamic _sanitizeValue(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate().toIso8601String();
  if (value is DateTime) return value.toIso8601String();
  if (value is GeoPoint) return {'latitude': value.latitude, 'longitude': value.longitude};
  if (value is DocumentReference) return value.path;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _sanitizeValue(v)));
  }
  if (value is List) {
    return value.map((v) => _sanitizeValue(v)).toList();
  }
  if (value is num || value is bool || value is String) {
    return value;
  }
  return value.toString();
}

String _safeJsonEncode(Object? object) {
  if (object == null) return '{}';
  try {
    if (object is Map<String, dynamic>) {
      return jsonEncode(_sanitizeMap(object));
    }
    return jsonEncode(_sanitizeValue(object));
  } catch (e) {
    debugPrint('[TaxiBgService] Safe jsonEncode error: $e');
    return '{}';
  }
}

// ─────────────────────────────────────────────────────────────────────
// الدالة المعزولة — يجب أن تكون خارج الكلاس لكي تعمل في Release mode
// ─────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[TaxiBgService] Background Firebase initialize error: $e');
  }

  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

  try {
    await notificationsPlugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  } catch (e) {
    debugPrint('[TaxiBgService] Background Local Notification initialize error: $e');
  }

  String? currentRole;
  String? currentToken;
  String? currentOneSignalId;
  String? currentUserId;

  StreamSubscription? rideRequestsSub;
  StreamSubscription? activeRideSub;
  final Map<String, String> lastRiderStatus = {};

  // ─── إيقاف كل شيء ───
  void cleanupListeners() {
    rideRequestsSub?.cancel();
    activeRideSub?.cancel();
    rideRequestsSub = null;
    activeRideSub = null;
    try {
      RingtoneManager.stopAll();
    } catch (_) {}
  }

  // ─── بدء مراقبة الطلبات وتحديثات الرحلات (للسائق) ───
  void startDriverListeners() {
    rideRequestsSub?.cancel();
    activeRideSub?.cancel();
    debugPrint('[TaxiBgService] Starting Driver Firestore Listeners for UID: $currentUserId');

    // 1. مراقبة الطلبات الجديدة المتاحة في المنطقة
    rideRequestsSub = FirebaseFirestore.instance
        .collection('ride_requests')
        .where('status', whereIn: ['searching', 'pending'])
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;
          data['rideId'] = change.doc.id;

          // تصفية الطلبات القديمة والمرفوضة والملغاة (Uber / Careem Smart Filter)
          final status = data['status'] as String? ?? '';
          if (status != 'searching' && status != 'pending') continue;

          final rejectedDrivers = (data['rejectedDrivers'] as List?) ?? [];
          if (currentUserId != null && rejectedDrivers.contains(currentUserId)) {
            continue;
          }

          final rawCreated = data['createdAt'];
          DateTime? createdAt;
          if (rawCreated is Timestamp) createdAt = rawCreated.toDate();
          if (rawCreated is DateTime) createdAt = rawCreated;
          if (rawCreated is String) createdAt = DateTime.tryParse(rawCreated);

          if (createdAt == null) continue; // تجاهل أي وثيقة بدون وقت إنشاء حقيقي
          final diff = DateTime.now().difference(createdAt).inSeconds;
          if (diff > 90 || diff < -60) {
            continue;
          }

          debugPrint('[TaxiBgService] New valid ride request detected: ${change.doc.id}');

          // تشغيل صوت التنبيه وتفعيل الإيقاف التلقائي المركزي مع تصفية المكررات
          RingtoneManager.startAlarm(change.doc.id);

          final pickup = data['pickupAddress'] ?? data['pickup']?['address'] ?? data['address'] ?? 'غير معروف';
          final dropoff = data['dropoffAddress'] ?? data['dropoff']?['address'] ?? 'غير محدد';
          final price = data['price']?.toString() ?? 'غير محدد';
          final customerName = data['userName'] ?? data['customerName'] ?? 'زبون مدار';
          final rideType = data['rideType'] ?? 'تاكسي مدار';

          String notificationBody = 'العميل: $customerName\n'
              'من: $pickup\n'
              'إلى: $dropoff\n'
              'السعر: $price د.ع | النوع: $rideType';

          _showNotification(
            notificationsPlugin,
            id: change.doc.id.hashCode,
            title: 'طلب درب تكسي جديد ($rideType)',
            body: notificationBody,
            payload: _safeJsonEncode(data),
          );

          // بث للواجهة إذا كانت مفتوحة بعد تنظيف الحقول لتكون متوافقة مع JSON MethodChannel
          final sanitizedData = _sanitizeMap(data);
          service.invoke('new_request', sanitizedData);
          service.invoke('serverMessage', {'type': 'new_request', ...sanitizedData});
        }
      }
    });

    // 2. مراقبة الرحلات المسندة للكابتن وحالات الإلغاء
    if (currentUserId != null && currentUserId!.isNotEmpty) {
      activeRideSub = FirebaseFirestore.instance
          .collection('ride_requests')
          .where('driverId', isEqualTo: currentUserId)
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          final data = change.doc.data();
          if (data == null) continue;
          final status = data['status'] as String?;
          final rideId = change.doc.id;
          final oldStatus = lastRiderStatus[rideId];

          if (status != null && oldStatus != status) {
            lastRiderStatus[rideId] = status;

            // في حال تم إلغاء الرحلة من قبل الزبون
            if (status == 'cancelled' || status == 'cancelled_by_user' || status == 'rejected') {
              RingtoneManager.stopAlarm(rideId);
              _showNotification(
                notificationsPlugin,
                id: rideId.hashCode,
                title: 'تم إلغاء الرحلة',
                body: 'قام الزبون بإلغاء طلب التاكسي',
              );
            }
          }
        }
      });
    }
  }

  // ─── بدء مراقبة تحديثات الرحلة (للزبون) ───
  void startRiderListeners() {
    activeRideSub?.cancel();
    if (currentUserId == null) return;

    debugPrint('[TaxiBgService] Starting Rider Firestore Listener for UID: $currentUserId');
    activeRideSub = FirebaseFirestore.instance
        .collection('ride_requests')
        .where('userId', isEqualTo: currentUserId)
        .where('status', whereIn: ['accepted', 'arrived', 'in_progress'])
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;
        final status = data['status'] as String?;
        if (status == null) continue;

        data['rideId'] = change.doc.id;
        final sanitizedData = _sanitizeMap(data);
        service.invoke('rideUpdate', sanitizedData);
        service.invoke('serverMessage', {'type': 'ride_update', ...sanitizedData});

        // إشعارات الحالة (فقط عند تغيير الحالة الفعلية)
        final oldStatus = lastRiderStatus[change.doc.id];
        if (oldStatus != status) {
          lastRiderStatus[change.doc.id] = status;
          switch (status) {
            case 'accepted':
              try {
                FlutterRingtonePlayer().playNotification();
              } catch (e) {
                debugPrint('[TaxiBgService] Error playing accepted sound: $e');
              }
              _showNotification(
                notificationsPlugin,
                id: 888,
                title: 'تم قبول طلبك!',
                body: 'كابتن مدار قبل رحلتك وسيصل قريباً.',
              );
              break;
            case 'arrived':
              try {
                FlutterRingtonePlayer().playNotification();
              } catch (e) {
                debugPrint('[TaxiBgService] Error playing arrived sound: $e');
              }
              _showNotification(
                notificationsPlugin,
                id: 889,
                title: 'الكابتن بالباب!',
                body: 'وصل الكابتن إلى موقعك، يرجى الخروج الآن.',
              );
              break;
          }
        }
      }
    });
  }

  service.on('startListening').listen((event) {
    if (event == null) return;

    final newRole = event['role'] as String?;
    final newToken = event['token'] as String?;
    final newOneSignalId = event['oneSignalId'] as String?;
    final newUserId = event['userId'] as String?;

    if (newRole == currentRole &&
        newToken == currentToken &&
        newOneSignalId == currentOneSignalId &&
        newUserId == currentUserId) {
      return;
    }

    currentRole = newRole;
    currentToken = newToken;
    currentOneSignalId = newOneSignalId;
    currentUserId = newUserId;

    cleanupListeners();

    if (service is AndroidServiceInstance) {
      final statusText = currentRole == 'driver' ? 'أنت متصل (أونلاين)' : 'الخدمة نشطة';
      service.setForegroundNotificationInfo(title: 'مدار', content: statusText);
    }

    if (currentRole == 'driver') {
      startDriverListeners();
    } else {
      startRiderListeners();
    }
  });

  service.on('sendUpdate').listen((event) {
    // التحديثات الآن ترسل مباشرة لـ Firestore من الواجهة
  });

  service.on('sendMessage').listen((event) {
    // الرسائل الآن ترسل مباشرة لـ Firestore من الواجهة
  });

  // ─── Monitoring Handlers Removed (Not used) ───

  service.on('stopRingtone').listen((event) {
    debugPrint('[TaxiBgService] Explicit ringtone stop requested');
    RingtoneManager.stopAll();
  });

  service.on('stop').listen((event) {
    RingtoneManager.stopAll();
    cleanupListeners();
    service.stopSelf();
  });
}

/// إظهار إشعار فوري (v20.x named params)
void _showNotification(
  FlutterLocalNotificationsPlugin plugin, {
  required int id,
  required String title,
  required String body,
  String? payload,
}) {
  try {
    plugin.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _kAlertChannelId,
          _kAlertChannelName,
          channelDescription: _kAlertChannelDesc,
          icon: '@mipmap/ic_launcher',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.call,
          audioAttributesUsage: AudioAttributesUsage.alarm, // Bypass DND behavior
          vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]),
        ),
      ),
    );
  } catch (e) {
    debugPrint('[TaxiBgService] Error showing local notification: $e');
  }
}

// ═══════════════════════════════════════════════════════════════════
// الكلاس الرئيسي — واجهة عامة للتطبيق
// ═══════════════════════════════════════════════════════════════════
class TaxiBackgroundService {
  TaxiBackgroundService._();

  static bool _isInitialized = false;

  /// تهيئة الخدمة — يُستدعى عند الحاجة فقط
  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    final service = FlutterBackgroundService();

    // إنشاء قناة حالة الخدمة (Importance.low)
    const serviceChannel = AndroidNotificationChannel(
      _kServiceChannelId,
      _kServiceChannelName,
      description: 'تبقي التطبيق متصلاً في الخلفية بشكل صامت',
      importance: Importance.defaultImportance, // Corrected from Importance.default
    );

    // إنشاء قناة التنبيهات (Importance.high)
    const alertChannel = AndroidNotificationChannel(
      _kAlertChannelId,
      _kAlertChannelName,
      description: _kAlertChannelDesc,
      importance: Importance.high,
      playSound: true,
    );

    final notificationsPlugin = FlutterLocalNotificationsPlugin();
    final androidPlugin =
        notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(serviceChannel);
      await androidPlugin.createNotificationChannel(alertChannel);
    }

    // Permissions are handled in AppInitializer or on-demand
    // Removing blocking request from here to prevent main thread hangs
    /*
    await notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    */

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _kServiceChannelId,
        initialNotificationTitle: 'مدار',
        initialNotificationContent: 'جاري الاتصال...',
        foregroundServiceNotificationId: 1991, 
      ),
      iosConfiguration: IosConfiguration(autoStart: false, onForeground: onStart),
    );
  }

  // ─── Driver Online Mode ───
  /// يُستدعى عندما يضغط السائق "أنا متاح"
  static Future<void> startDriverOnline({
    required String serverUrl,
    required String token,
    String? oneSignalId,
    String? userId,
  }) async {
    final service = FlutterBackgroundService();
    
    // Ensure service is initialized/configured
    if (!await service.isRunning()) {
      await initialize();
    }
    
    await service.startService();
    service.invoke('startListening', {
      'role': 'driver',
      'token': token,
      'oneSignalId': oneSignalId,
      'userId': userId ?? FirebaseAuth.instance.currentUser?.uid,
    });
  }

  /// ─── Rider Ride Mode ───
  /// يبدأ اتصال الخدمة للزبون أثناء الرحلة
  static Future<void> startRiderMode({
    required String serverUrl,
    required String token,
    String? oneSignalId,
  }) async {
    final service = FlutterBackgroundService();
    
    // Ensure service is initialized/configured
    if (!await service.isRunning()) {
      await initialize();
    }
    
    await service.startService();
    service.invoke('startListening', {
      'role': 'rider',
      'token': token,
      'oneSignalId': oneSignalId,
      'userId': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  // ─── Monitoring Drivers (Rider) ───
  static Future<void> startMonitoringDrivers({required double lat, required double lng}) async {
    FlutterBackgroundService().invoke('startMonitoring', {'lat': lat, 'lng': lng});
  }

  static Future<void> stopMonitoringDrivers() async {
    FlutterBackgroundService().invoke('stopMonitoring');
  }

  /// بث تحديثات السائقين القريبين (UI listens to this)
  static Stream<List<Map<String, dynamic>>> get driversNearbyStream {
    return FlutterBackgroundService().on('drivers_nearby').map((event) {
      if (event == null || event['drivers'] == null) {
        debugPrint(" TaxiBgService: Received empty driver event");
        return [];
      }
      final drivers = List<Map<String, dynamic>>.from(event['drivers']);
      debugPrint(" TaxiBgService: Stream received ${drivers.length} drivers");
      return drivers;
    });
  }

  /// إرسال تحديث حالة رحلة إلى السيرفر
  static void sendRideUpdate({required String rideId, required String status}) {
    FlutterBackgroundService().invoke('sendUpdate', {
      'type': 'ride_update',
      'rideId': rideId,
      'status': status,
    });
  }

  /// إرسال رسالة مخصصة إلى السيرفر (مثل accept_ride, create_ride, cancel_ride)
  static void sendMessage(Map<String, dynamic> message) {
    FlutterBackgroundService().invoke('sendMessage', message);
  }

  /// إيقاف الخدمة يدوياً
  static void stop() {
    FlutterBackgroundService().invoke('stop');
  }

  static void stopRingtone() {
    FlutterBackgroundService().invoke('stopRingtone');
  }
}
