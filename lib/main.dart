import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dalal_alqaim/firebase_options.dart';
import 'package:dalal_alqaim/core/app_initializer.dart';
import 'package:dalal_alqaim/core/app_globals.dart';
import 'package:dalal_alqaim/core/app_router.dart';
import 'package:dalal_alqaim/pages/welcome_page.dart';
import 'package:dalal_alqaim/features/home/pages/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/services/notification_service.dart';
import 'package:dalal_alqaim/services/ringtone_manager.dart';
import 'package:dalal_alqaim/services/onesignal_service.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/driver_dashboard_page.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/pages/restaurant_dashboard_page.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/driver_registration_status_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/delivery_dashboard_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/delivery_registration_status_page.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/store_dashboard_page.dart';
import 'package:dalal_alqaim/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:dalal_alqaim/features/admin/presentation/pages/admin_web_only_notice_page.dart';
import 'package:dalal_alqaim/features/admin_web/pages/admin_web_portal_page.dart';
import 'package:dalal_alqaim/features/real_estate/presentation/pages/real_estate_page.dart';
import 'package:dalal_alqaim/services/user_service.dart';
import 'package:dalal_alqaim/core/observability/observability.dart';

/// Background FCM handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint(" Background Firebase initialize error: $e");
  }

  final data = message.data;
  final type =
      data['type']?.toString() ?? data['notification_type']?.toString();

  // 0. التحقق الدفاعي من المستلم ومنع إسقاط الإشعارات المستهدفة من السيرفر
  try {
    final prefs = await SharedPreferences.getInstance();
    final cachedRole = prefs.getString('currentUserRole') ?? 'customer';
    final cachedUserId = prefs.getString('currentUserId');

    // إذا كان الإشعار موجهاً من السيرفر مباشرة لتوكن هذا الجهاز، أو كان نداء طوارئ، لا نسقطه بسبب كاش الدور المحلي
    final isCriticalOrSos = type == 'emergency_sos' || type == 'security_alert';
    final isDriverPayload =
        type == 'new_ride' ||
        type == 'ride_request' ||
        type == 'taxi_request' ||
        type == 'mersal_request' ||
        type == 'delegate_request' ||
        type == 'food_order';

    bool shouldShow = true;
    if (!isCriticalOrSos && !isDriverPayload) {
      try {
        shouldShow = NotificationService.shouldDisplayNotification(
          data: data,
          currentRole: cachedRole,
          currentUid: cachedUserId,
        );
      } catch (e) {
        debugPrint(' Error in shouldDisplayNotification in background: $e');
      }
    }

    if (!shouldShow) {
      debugPrint(
        ' Background: Filter suppressed non-targeted notification (Role: $cachedRole)',
      );
      return;
    }
  } catch (e) {
    debugPrint(' Background Prefs/Filter Error: $e');
  }

  final requestId =
      data['rideId'] ??
      data['ride_id'] ??
      data['requestId'] ??
      data['request_id'] ??
      data['orderId'] ??
      data['order_id'] ??
      data['id'] ??
      message.messageId ??
      'unknown_request';

  // 1. تشغيل الرنة للطلبات الجديدة في الخلفية باستخدام RingtoneManager
  final isRequest =
      type == 'new_ride' ||
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
      type == 'taxi_broadcast' ||
      type == 'emergency_sos';

  if (isRequest) {
    await RingtoneManager.startAlarm(requestId.toString());
  }

  // 2. إيقاف الرنة وإلغاء الإشعار في حال وصول تحديث أو قبول أو إلغاء للرحلة
  if (type == 'ride_update' ||
      type == 'trip_cancelled' ||
      type == 'ride_cancelled' ||
      type == 'ride_accepted') {
    debugPrint(" FCM Update received ($type). Stopping ringtone.");
    await RingtoneManager.stopAlarm(requestId.toString());
  }

  // 3. منع الازدواجية: إذا كان الإشعار يحتوي notification block فإن نظام أندرويد يعرضه تلقائياً
  // نقوم بعرض local notification فقط في حال كانت الرسالة data-only لتجنب ظهور إشعارين لنفس الحدث
  if (message.notification == null &&
      (data['title'] != null || data['body'] != null)) {
    final FlutterLocalNotificationsPlugin localNotif =
        FlutterLocalNotificationsPlugin();
    try {
      await localNotif.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      final isUrgentRequest =
          type == 'new_ride' ||
          type == 'ride_request' ||
          type == 'taxi_request' ||
          type == 'emergency_sos';

      final channelId =
          type == 'emergency_sos'
              ? 'madar_sos_v1'
              : (type == 'security_alert'
                  ? 'madar_security_v1'
                  : 'madar_urgent_alerts_v1');

      await localNotif.show(
        id: requestId.hashCode,
        title: data['title']?.toString(),
        body: data['body']?.toString(),
        payload: jsonEncode(data),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'طلبات مدار العاجلة',
            channelDescription: 'إشعارات الطلبات والرحلات الجديدة العاجلة',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            fullScreenIntent: isUrgentRequest,
            category: isUrgentRequest ? AndroidNotificationCategory.call : null,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            vibrationPattern: Int64List.fromList([
              0,
              1000,
              500,
              1000,
              500,
              1000,
              500,
              1000,
            ]),
          ),
        ),
      );
    } catch (e) {
      debugPrint(" Background Local Notification show error: $e");
    }
  }
}

Future<void> main() async {
  debugPrint('--- MAIN: Starting main() ---');
  PerformanceTracker.startTrace('startup_total');
  PerformanceTracker.startTrace('time_to_first_frame');
  PerformanceTracker.startTrace('time_to_usable_ui');

  // التقاط الأخطاء في إطار فلاتر
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint("FlutterError: ${details.exception}");
    AppLogger.recordFlutterFatalError(details);
  };

  // التقاط الأخطاء غير المتوقعة واللا متزامنة قبل بناء الـ Widgets
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint("PlatformDispatcher Error: $error");
    AppLogger.recordError(error, stack, fatal: true);
    return true;
  };

  try {
    WidgetsFlutterBinding.ensureInitialized();

    /// تهيئة الخدمات الحرجة السريعة (Critical Fast Path) — تضمن استقرار Firebase قبل أي خدمة
    await AppInitializer.initCritical();

    /// تسجيل Background FCM Handler بعد اكتمال تهيئة Firebase (فقط على المنصات المدعومة)
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    runApp(const DalilAlqaimApp());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      PerformanceTracker.stopTrace('time_to_first_frame');
      final firstFrame = PerformanceTracker.getDuration('time_to_first_frame');
      debugPrint('[Madar Benchmark] TIME_TO_FIRST_FRAME: ${firstFrame}ms');
    });

    /// تشغيل الخدمات المؤجلة بعد رسم أول إطار (Deferred Post-Frame Init)
    AppInitializer.postFrameInit();
  } catch (e, stackTrace) {
    debugPrint(" Fatal App Init Error: $e\n$stackTrace");
    AppLogger.recordError(
      e,
      stackTrace,
      reason: "Fatal App Init Error",
      fatal: true,
    );
    runApp(
      ErrorScreenApp(
        errorMessage: e.toString(),
        stackTrace: stackTrace.toString(),
      ),
    );
  }
}

class ErrorScreenApp extends StatelessWidget {
  final String errorMessage;
  final String stackTrace;

  const ErrorScreenApp({
    super.key,
    required this.errorMessage,
    required this.stackTrace,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('خطأ في تهيئة التطبيق'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.rtl,
            children: [
              const Text(
                'للأسف، حدث خطأ أثناء بدء التطبيق. يرجى أخذ لقطة شاشة للخطأ للمساعدة في تتبعه وإصلاحه:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(8.0),
                color: Colors.red.withValues(alpha: 0.1),
                width: double.infinity,
                child: SelectableText(
                  errorMessage,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Stack Trace:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8.0),
                color: Colors.grey.withValues(alpha: 0.1),
                width: double.infinity,
                child: SelectableText(
                  stackTrace,
                  style: const TextStyle(fontSize: 12),
                  textDirection: TextDirection.ltr,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DalilAlqaimApp extends StatelessWidget {
  const DalilAlqaimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          navigatorObservers: [appRouteObserver],
          debugShowCheckedModeBanner: false,
          title: 'Dalal Alqaim',
          locale: const Locale('ar', 'IQ'),
          supportedLocales: const [
            Locale('ar', 'IQ'),
            Locale('ar'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          scrollBehavior: const MadarSmoothScrollBehavior(),
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, widget) {
            // التقاط أخطاء الـ widgets وعرض واجهة خطأ بدلاً من شاشة رمادية في نسخة الإصدار (Release)
            ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
              return Scaffold(
                appBar: AppBar(title: const Text("خطأ في الواجهة")),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'حدث خطأ أثناء عرض هذه الصفحة:',
                        style: TextStyle(color: Colors.red, fontSize: 18),
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        errorDetails.exceptionAsString(),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                ),
              );
            };

            final mediaQuery = MediaQuery.of(context);

            // نستخدم designSize ثابتة 375x812 دائماً لكل المنصات
            // هذا يضمن إن عناصر .w و .h و .sp تبقى بأحجام طبيعية
            // التطبيق يتمدد على كامل عرض الشاشة بدون إطار أو قيود
            const Size designSize = Size(375, 812);

            Widget appWidget = ScreenUtilInit(
              designSize: designSize,
              minTextAdapt: true,
              splitScreenMode: true,
              useInheritedMediaQuery: true,
              builder: (context, child) {
                ScreenUtil.init(
                  context,
                  designSize: designSize,
                  minTextAdapt: true,
                  splitScreenMode: true,
                );
                return widget ?? const SizedBox();
              },
            );

            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: const TextScaler.linear(1.0),
              ),
              child: appWidget,
            );
          },

          /// الصفحة الأولى تعتمد على حالة تسجيل الدخول عبر AuthWrapper الموحد
          home: const AuthWrapper(),

          /// استخدام AppRouter للمسارات
          routes: AppRouter.getRoutes(isDark),
          onGenerateRoute: AppRouter.onGenerateRoute,
        );
      },
    );
  }
}

/// غلاف (Wrapper) للتحقق الدائم من حالة تسجيل الدخول وتوجيه المستخدم حسب دوره
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        // 1. Logged In: Route based on User Role from Firestore / SharedPreferences
        final User? user = snapshot.data ?? FirebaseAuth.instance.currentUser;
        if (user != null) {
          return RoleBasedRouter(user: user);
        }

        // 2. Loading state (Still initializing Firebase Auth)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: app_colors.darkBackground,
            body: Center(
              child: CircularProgressIndicator(color: app_colors.primaryColor),
            ),
          );
        }

        // 3. Not Logged In: Go to WelcomePage
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (PerformanceTracker.getDuration('time_to_usable_ui') == null) {
            PerformanceTracker.stopTrace('time_to_usable_ui');
            final usableUi = PerformanceTracker.getDuration(
              'time_to_usable_ui',
            );
            debugPrint(
              '[Madar Benchmark] TIME_TO_USABLE_UI: ${usableUi}ms (WelcomePage)',
            );
            PerformanceTracker.stopTrace('startup_total');
            final startupTotal = PerformanceTracker.getDuration(
              'startup_total',
            );
            debugPrint('[Madar Benchmark] STARTUP_TOTAL: ${startupTotal}ms');
          }
        });
        return const WelcomePage();
      },
    );
  }
}

/// موجه ديناميكي يحدد صفحة الوجهة حسب دور المستخدم وحالة الحساب بكل أمان
class RoleBasedRouter extends StatefulWidget {
  final User user;
  const RoleBasedRouter({super.key, required this.user});

  @override
  State<RoleBasedRouter> createState() => _RoleBasedRouterState();
}

class _RoleBasedRouterState extends State<RoleBasedRouter> {
  String? _role;
  String _status = 'active';
  bool _isApproved = true;
  bool _isLoading = true;
  bool _isBannedOrRejected = false;
  bool _isMissingProfile = false;
  String _securityMessage = '';
  bool _adminContinueAsCustomer = false;

  @override
  void initState() {
    super.initState();
    _determineRoleAndSecurity();
  }

  Future<void> _determineRoleAndSecurity() async {
    PerformanceTracker.startTrace('role_resolution');
    try {
      final prefs = await SharedPreferences.getInstance();
      // 1. Check local cache scoped to the current user UID — use as initial hint only
      final userRoleKey = 'currentUserRole_${widget.user.uid}';
      final cachedRole = prefs.getString(userRoleKey);
      if (cachedRole != null && cachedRole.isNotEmpty && mounted) {
        setState(() {
          _role = cachedRole;
          _isLoading = false;
        });
        PerformanceTracker.stopTrace(
          'role_resolution',
          details: 'From Cache: $cachedRole',
        );
        debugPrint(
          '[Madar Benchmark] ROLE_RESOLUTION: ${PerformanceTracker.getDuration('role_resolution')}ms',
        );
      }

      // 2. ALWAYS sync with Firestore to ensure role/approval is current
      // This prevents stale cache from sending store users to customer dashboard
      // or delivery users to verification loop after approval.
      await _syncSecurityCheck(prefs);
    } catch (e) {
      debugPrint(' Security/Role Router Error: $e');
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncSecurityCheck(SharedPreferences prefs) async {
    final userRoleKey = 'currentUserRole_${widget.user.uid}';
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.user.uid)
              .get();

      Map<String, dynamic>? data;
      if (doc.exists) {
        data = doc.data();
      }

      // If doc does not exist in users/{uid}, attempt cross-collection recovery
      if (data == null) {
        try {
          // Check restaurants
          final restCheck =
              await FirebaseFirestore.instance
                  .collection('restaurants')
                  .doc(widget.user.uid)
                  .get();
          if (restCheck.exists) {
            data = {
              'role': 'restaurant',
              'status': restCheck.data()?['status'] ?? 'active',
              'isApproved': restCheck.data()?['isApproved'] ?? true,
            };
            await FirebaseFirestore.instance
                .collection('users')
                .doc(widget.user.uid)
                .set(data, SetOptions(merge: true));
          } else {
            // Check stores
            final storeCheck =
                await FirebaseFirestore.instance
                    .collection('stores')
                    .doc(widget.user.uid)
                    .get();
            if (storeCheck.exists) {
              data = {
                'role': 'store',
                'status': storeCheck.data()?['status'] ?? 'active',
                'isApproved': storeCheck.data()?['isApproved'] ?? true,
              };
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.user.uid)
                  .set(data, SetOptions(merge: true));
            } else {
              // Check drivers
              final driverCheck =
                  await FirebaseFirestore.instance
                      .collection('drivers')
                      .doc(widget.user.uid)
                      .get();
              if (driverCheck.exists) {
                final isDeliv =
                    driverCheck.data()?['isDelivery'] == true ||
                    driverCheck.data()?['role'] == 'delivery';
                data = {
                  'role': isDeliv ? 'delivery' : 'captain',
                  'status': driverCheck.data()?['status'] ?? 'active',
                  'isApproved': driverCheck.data()?['isApproved'] ?? true,
                };
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.user.uid)
                    .set(data, SetOptions(merge: true));
              }
            }
          }
        } catch (_) {}
      }

      if (data == null) {
        // Document really does not exist
        await prefs.remove(userRoleKey);
        if (mounted) {
          setState(() {
            _isMissingProfile = true;
            _isLoading = false;
          });
        }
        return;
      }

      final rawRole = data['role']?.toString().toLowerCase();
      final subRole = data['subRole']?.toString().toLowerCase();
      final isDelivery = data['isDelivery'] == true;
      final isDriver = data['isDriver'] == true;

      String firestoreRole = rawRole ?? '';
      if (subRole == 'delivery' ||
          isDelivery ||
          rawRole == 'delivery' ||
          rawRole == 'delivery_boy' ||
          rawRole == 'delivery_captain') {
        firestoreRole = 'delivery';
      } else if (rawRole == 'restaurant' ||
          rawRole == 'restaurant_owner' ||
          subRole == 'restaurant') {
        firestoreRole = 'restaurant';
      } else if (rawRole == 'merchant') {
        try {
          final restDoc =
              await FirebaseFirestore.instance
                  .collection('restaurants')
                  .doc(widget.user.uid)
                  .get();
          if (restDoc.exists) {
            firestoreRole = 'restaurant';
            await FirebaseFirestore.instance
                .collection('users')
                .doc(widget.user.uid)
                .update({'role': 'restaurant'})
                .catchError((_) {});
          } else {
            firestoreRole = 'store';
          }
        } catch (_) {
          firestoreRole = 'restaurant';
        }
      } else if (rawRole == 'store' ||
          rawRole == 'store_owner' ||
          rawRole == 'market' ||
          subRole == 'store') {
        firestoreRole = 'store';
      } else if (rawRole == 'captain' ||
          rawRole == 'driver' ||
          rawRole == 'taxi_captain' ||
          rawRole == 'transport_captain' ||
          subRole == 'captain' ||
          subRole == 'driver' ||
          isDriver) {
        firestoreRole = 'captain';
      } else if (rawRole == 'admin' || rawRole == 'limited_admin') {
        firestoreRole = 'admin';
      } else if (rawRole == 'real_estate' || rawRole == 'property_owner') {
        firestoreRole = 'real_estate';
      } else {
        // Check if user is registered in specialized partner collections despite 'customer' role in users doc
        try {
          final storeDoc =
              await FirebaseFirestore.instance
                  .collection('stores')
                  .doc(widget.user.uid)
                  .get();
          if (storeDoc.exists) {
            firestoreRole = 'store';
          } else {
            final restDoc =
                await FirebaseFirestore.instance
                    .collection('restaurants')
                    .doc(widget.user.uid)
                    .get();
            if (restDoc.exists) {
              firestoreRole = 'restaurant';
            } else {
              final driverDoc =
                  await FirebaseFirestore.instance
                      .collection('drivers')
                      .doc(widget.user.uid)
                      .get();
              if (driverDoc.exists) {
                firestoreRole =
                    (driverDoc.data()?['isDelivery'] == true ||
                            driverDoc.data()?['role'] == 'delivery')
                        ? 'delivery'
                        : 'captain';
              } else {
                firestoreRole = 'customer';
              }
            }
          }
        } catch (_) {
          firestoreRole = 'customer';
        }
      }

      String statusStr = (data['status'] ?? 'active').toString().toLowerCase();
      bool isApprovedBool =
          data['isApproved'] as bool? ??
          (statusStr == 'active' || statusStr == 'approved');

      // ── Cross-Collection Approval Verification ──
      // Admins often approve accounts in their domain collection (restaurants, stores, drivers, etc.)
      // rather than users/{uid}. Verify domain collection so approval is never missed.
      if (firestoreRole == 'restaurant') {
        try {
          final restDoc =
              await FirebaseFirestore.instance
                  .collection('restaurants')
                  .doc(widget.user.uid)
                  .get();
          if (restDoc.exists) {
            final restData = restDoc.data();
            final restStatus =
                (restData?['status'] ?? '').toString().toLowerCase();
            final restApproved =
                restData?['isApproved'] == true ||
                (restData?['isSuspended'] == false &&
                    restStatus != 'pending') ||
                restStatus == 'active' ||
                restStatus == 'approved';

            if (restApproved) {
              statusStr = 'active';
              isApprovedBool = true;
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.user.uid)
                  .update({
                    'status': 'active',
                    'isApproved': true,
                    'role': 'restaurant',
                  })
                  .catchError((_) {});
            }
          }
        } catch (_) {}

        if (!isApprovedBool) {
          try {
            final reqSnap =
                await FirebaseFirestore.instance
                    .collection('restaurant_requests')
                    .where('uid', isEqualTo: widget.user.uid)
                    .limit(1)
                    .get();
            if (reqSnap.docs.isNotEmpty) {
              final reqStatus =
                  (reqSnap.docs.first.data()['status'] ?? '')
                      .toString()
                      .toLowerCase();
              if (reqStatus == 'approved' || reqStatus == 'active') {
                statusStr = 'active';
                isApprovedBool = true;
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.user.uid)
                    .update({
                      'status': 'active',
                      'isApproved': true,
                      'role': 'restaurant',
                    })
                    .catchError((_) {});
              }
            }
          } catch (_) {}
        }
      } else if (firestoreRole == 'store') {
        try {
          final storeDoc =
              await FirebaseFirestore.instance
                  .collection('stores')
                  .doc(widget.user.uid)
                  .get();
          if (storeDoc.exists) {
            final storeData = storeDoc.data();
            final stStatus =
                (storeData?['status'] ?? '').toString().toLowerCase();
            final stApproved =
                storeData?['isApproved'] == true ||
                stStatus == 'active' ||
                stStatus == 'approved';
            if (stApproved) {
              statusStr = 'active';
              isApprovedBool = true;
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.user.uid)
                  .update({
                    'status': 'active',
                    'isApproved': true,
                    'role': 'store',
                  })
                  .catchError((_) {});
            }
          }
        } catch (_) {}

        if (!isApprovedBool) {
          try {
            final reqSnap =
                await FirebaseFirestore.instance
                    .collection('store_requests')
                    .where('uid', isEqualTo: widget.user.uid)
                    .limit(1)
                    .get();
            if (reqSnap.docs.isNotEmpty) {
              final reqStatus =
                  (reqSnap.docs.first.data()['status'] ?? '')
                      .toString()
                      .toLowerCase();
              if (reqStatus == 'approved' || reqStatus == 'active') {
                statusStr = 'active';
                isApprovedBool = true;
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.user.uid)
                    .update({
                      'status': 'active',
                      'isApproved': true,
                      'role': 'store',
                    })
                    .catchError((_) {});
              }
            }
          } catch (_) {}
        }
      } else if (firestoreRole == 'captain') {
        try {
          final driverDoc =
              await FirebaseFirestore.instance
                  .collection('drivers')
                  .doc(widget.user.uid)
                  .get();
          if (driverDoc.exists) {
            final driverData = driverDoc.data();
            final drStatus =
                (driverData?['status'] ?? '').toString().toLowerCase();
            final drApproved =
                driverData?['isApproved'] == true ||
                drStatus == 'active' ||
                drStatus == 'approved';
            if (drApproved) {
              statusStr = 'active';
              isApprovedBool = true;
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.user.uid)
                  .update({
                    'status': 'active',
                    'isApproved': true,
                    'role': 'captain',
                  })
                  .catchError((_) {});
            }
          }
        } catch (_) {}

        if (!isApprovedBool) {
          try {
            final reqDoc =
                await FirebaseFirestore.instance
                    .collection('driver_requests')
                    .doc(widget.user.uid)
                    .get();
            if (reqDoc.exists) {
              final reqStatus =
                  (reqDoc.data()?['status'] ?? '').toString().toLowerCase();
              if (reqStatus == 'approved' || reqStatus == 'active') {
                statusStr = 'active';
                isApprovedBool = true;
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.user.uid)
                    .update({
                      'status': 'active',
                      'isApproved': true,
                      'role': 'captain',
                    })
                    .catchError((_) {});
              }
            }
          } catch (_) {}
        }
      } else if (firestoreRole == 'delivery') {
        try {
          final delivDoc =
              await FirebaseFirestore.instance
                  .collection('delivery_boys')
                  .doc(widget.user.uid)
                  .get();
          if (delivDoc.exists) {
            final delivData = delivDoc.data();
            final dlStatus =
                (delivData?['status'] ?? '').toString().toLowerCase();
            final dlApproved =
                delivData?['isApproved'] == true ||
                dlStatus == 'active' ||
                dlStatus == 'approved';
            if (dlApproved) {
              statusStr = 'active';
              isApprovedBool = true;
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.user.uid)
                  .update({
                    'status': 'active',
                    'isApproved': true,
                    'role': 'delivery',
                  })
                  .catchError((_) {});
            }
          }
        } catch (_) {}
      }

      // Check if account is banned or rejected
      if (statusStr == 'banned' ||
          statusStr == 'removed' ||
          data['isBanned'] == true) {
        await OneSignalService.logout();
        await UserService.signOut();
        await prefs.remove(userRoleKey);
        if (mounted) {
          setState(() {
            _isBannedOrRejected = true;
            _securityMessage = 'تم حظر هذا الحساب من قِبل إدارة التطبيق.';
            _isLoading = false;
          });
        }
        return;
      }

      if (statusStr == 'rejected') {
        await OneSignalService.logout();
        await UserService.signOut();
        await prefs.remove(userRoleKey);
        if (mounted) {
          setState(() {
            _isBannedOrRejected = true;
            _securityMessage =
                'تم رفض طلب هذا الحساب. يرجى التواصل مع الدعم الفني.';
            _isLoading = false;
          });
        }
        return;
      }

      if (firestoreRole.isNotEmpty) {
        if (mounted) {
          setState(() {
            _role = firestoreRole;
            _status = statusStr;
            _isApproved = isApprovedBool;
            _isLoading = false;
          });
        }
        await prefs.setString(userRoleKey, firestoreRole);
        await prefs.setString('currentUserRole', firestoreRole);
        await prefs.setString('currentUserId', widget.user.uid);
      } else {
        if (mounted) {
          setState(() {
            _role = rawRole ?? 'customer';
            _status = statusStr;
            _isApproved = isApprovedBool;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint(' Background Security Check Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hard security kick-out for banned/rejected accounts
    if (_isBannedOrRejected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_securityMessage.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _securityMessage,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
      return const WelcomePage();
    }

    if (_isMissingProfile) {
      return Scaffold(
        backgroundColor: app_colors.darkBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 72,
                  color: Colors.amber,
                ),
                const SizedBox(height: 16),
                const Text(
                  'تم تسجيل الدخول لكن ملف المستخدم غير مكتمل',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'معرّف الحساب (UID): ${widget.user.uid}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    await UserService.signOut();
                    if (context.mounted) {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/welcome', (route) => false);
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('تسجيل الخروج'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoading && _role == null) {
      return const Scaffold(
        backgroundColor: app_colors.darkBackground,
        body: Center(
          child: CircularProgressIndicator(color: app_colors.primaryColor),
        ),
      );
    }

    final role = (_role ?? '').toLowerCase();

    // Rejection of completely unknown role
    const knownRoles = [
      'customer',
      'user',
      'client',
      'delivery',
      'delivery_boy',
      'delivery_captain',
      'captain',
      'driver',
      'taxi_captain',
      'transport_captain',
      'restaurant',
      'restaurant_owner',
      'merchant',
      'store',
      'store_owner',
      'market',
      'admin',
      'limited_admin',
      'real_estate',
      'property_owner',
    ];

    if (role.isNotEmpty && !knownRoles.contains(role)) {
      return Scaffold(
        backgroundColor: app_colors.darkBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 72,
                  color: Colors.orangeAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  'نوع الحساب غير معروف: $role',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    await UserService.signOut();
                    if (context.mounted) {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/welcome', (route) => false);
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('تسجيل الخروج'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (PerformanceTracker.getDuration('time_to_usable_ui') == null) {
        PerformanceTracker.stopTrace('time_to_usable_ui');
        final usableUi = PerformanceTracker.getDuration('time_to_usable_ui');
        debugPrint(
          '[Madar Benchmark] TIME_TO_USABLE_UI: ${usableUi}ms (Role: $role)',
        );
        PerformanceTracker.stopTrace('startup_total');
        final startupTotal = PerformanceTracker.getDuration('startup_total');
        debugPrint('[Madar Benchmark] STARTUP_TOTAL: ${startupTotal}ms');
      }
    });

    final isNotApproved =
        !_isApproved ||
        _status == 'pending' ||
        _status == 'under_review' ||
        _status == 'waiting';

    // Admin Guard: Web Only! Restricted from Mobile App
    if (role == 'admin' || role == 'limited_admin') {
      if (kIsWeb) {
        return const PopScope(canPop: true, child: AdminWebPortalPage());
      } else {
        if (!_adminContinueAsCustomer) {
          return PopScope(
            canPop: true,
            child: AdminWebOnlyNoticePage(
              onContinueAsCustomer: () {
                setState(() {
                  _adminContinueAsCustomer = true;
                });
              },
            ),
          );
        }
      }
    }

    // Real Estate Guard
    if (role == 'real_estate' || role == 'property_owner') {
      return const PopScope(canPop: true, child: RealEstatePage());
    }

    // Delivery Boy / Delivery Captain Status Guard (Checked BEFORE Taxi Captain)
    if (role == 'delivery' ||
        role == 'delivery_boy' ||
        role == 'delivery_captain') {
      if (isNotApproved) {
        return const PopScope(
          canPop: true,
          child: DeliveryRegistrationStatusPage(),
        );
      }
      return const PopScope(canPop: true, child: DeliveryDashboardPage());
    }

    // Taxi Captain / Driver Status Guard
    if (role == 'captain' ||
        role == 'driver' ||
        role == 'taxi_captain' ||
        role == 'transport_captain') {
      if (isNotApproved) {
        return const PopScope(
          canPop: true,
          child: DriverRegistrationStatusPage(),
        );
      }
      return const PopScope(canPop: true, child: DriverDashboardPage());
    }

    // Restaurant Status Guard
    if (role == 'restaurant' ||
        role == 'restaurant_owner' ||
        role == 'merchant') {
      if (isNotApproved) {
        return const PopScope(
          canPop: true,
          child: DriverRegistrationStatusPage(),
        );
      }
      return const PopScope(canPop: true, child: RestaurantDashboardPage());
    }

    // Store Owner / Market Status Guard
    if (role == 'store' || role == 'store_owner' || role == 'market') {
      if (isNotApproved) {
        return const PopScope(
          canPop: true,
          child: DriverRegistrationStatusPage(),
        );
      }
      return PopScope(
        canPop: true,
        child: StoreDashboardPage(storeId: widget.user.uid),
      );
    }

    // Normal User (Customer) -> Directly to HomePage
    return const HomePage();
  }
}

/// سلوك تمرير ناعم وفائق السلاسة للأندرويد (60/120Hz Smooth Bouncing Physics)
class MadarSmoothScrollBehavior extends MaterialScrollBehavior {
  const MadarSmoothScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}
