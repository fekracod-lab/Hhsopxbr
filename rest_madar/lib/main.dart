import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'core/database/local_database_service.dart';
import 'core/error/madar_crash_guard.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/pos_language_controller.dart';
import 'features/auth/presentation/pages/restaurant_login_page.dart';
import 'features/auth/presentation/pages/restaurant_welcome_page.dart';
import 'features/shell/presentation/desktop_shell_page.dart';
import 'features/pos/application/pos_provider.dart';
import 'services/pos_sync_service.dart';
import 'services/print_queue_service.dart';
import 'services/shift_service.dart';
import 'services/offline_auth_service.dart';

/// تجاوز فحوصات الشهادات المحلية على منصة سطح المكتب لتفادي أخطاء CERTIFICATE_VERIFY_FAILED
/// الناتجة عن عدم مزامنة شهادات الجذر الخاصة بنظام Windows مع Dart HttpClient
class MadarHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // السماح بتحميل الصور والوسائط السحابية دون تعطل الشهادات في بيئة Windows
    try {
      HttpOverrides.global = MadarHttpOverrides();
    } catch (_) {}

    // تفعيل حارس النظام لمنع الانهيارات والتقاط وتحليل كل المشاكل برمز تشخيصي
    MadarCrashGuard.init();

    // 0. تهيئة بيانات تواريخ اللغة العربية (يوميات وشهور) لاستخدامها في كل الشاشات
    try {
      await initializeDateFormatting('ar');
    } catch (e, st) {
      MadarCrashGuard.reportUnhandledError(e, st, '[DateFormatInit]');
    }

    // 0.1 تحميل وضع المظهر المحفوظ (هوية مزدوجة: فاتح/داكن)
    try {
      await PosThemeController.instance.load();
      await PosLanguageController.instance.load();
    } catch (e, st) {
      MadarCrashGuard.reportUnhandledError(e, st, '[ThemeAndLangLoad]');
    }

    // 1. Initialize Firebase with shared dalal_alqaim options
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e, st) {
      MadarCrashGuard.reportUnhandledError(e, st, '[FirebaseInit]');
    }

    // 2. Initialize local SQLite Database for Offline POS transactions (< 15ms commits)
    try {
      await LocalDatabaseService.instance.database;
    } catch (e, st) {
      MadarCrashGuard.reportUnhandledError(e, st, '[SQLiteInit]');
    }

    // 3. Start background sync engine and print queue state machine
    try {
      PosSyncService.instance.start();
      PrintQueueService.instance.start();
    } catch (e, st) {
      MadarCrashGuard.reportUnhandledError(e, st, '[BackgroundServices]');
    }

    // 4. Check whether welcome onboarding has been completed
    bool hasSeenWelcome = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      hasSeenWelcome = prefs.getBool('madar_welcome_seen') ?? false;
    } catch (_) {}

    // 5. تهيئة خدمة الدخول بدون إنترنت (Offline Auth Service) وفحص الجلسة النشطة
    bool hasOfflineSession = false;
    try {
      await OfflineAuthService.instance.init();
      hasOfflineSession = await OfflineAuthService.instance.hasActiveOfflineSession();
    } catch (e, st) {
      MadarCrashGuard.reportUnhandledError(e, st, '[OfflineAuthInit]');
    }

    runApp(RestaurantApp(
      hasSeenWelcome: hasSeenWelcome,
      hasOfflineSession: hasOfflineSession,
    ));
  }, (error, stack) {
    MadarCrashGuard.reportUnhandledError(error, stack, '[RootZoneAsyncError]');
  });
}

class RestaurantApp extends StatelessWidget {
  final bool hasSeenWelcome;
  final bool hasOfflineSession;
  const RestaurantApp({
    super.key,
    this.hasSeenWelcome = false,
    this.hasOfflineSession = false,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the initial screen depending on authentication state (Online Firebase or Offline Local)
    final user = FirebaseAuth.instance.currentUser;
    final isAuthenticated = user != null || hasOfflineSession;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PosProvider()),
        ChangeNotifierProvider(create: (_) => ShiftService()),
      ],
      child: ListenableBuilder(
        listenable: Listenable.merge([
          PosThemeController.instance,
          PosLanguageController.instance,
        ]),
        builder: (context, _) {
          final isEn = PosLanguageController.instance.isEnglish;

          return MaterialApp(
            navigatorKey: MadarCrashGuard.navigatorKey,
            builder: (ctx, child) => MadarCrashGuard.appBuilder(ctx, child),
            title: isEn ? 'Madar POS System' : 'منظومة مدار للمطاعم',
            locale: Locale(PosLanguageController.instance.languageCode),
            debugShowCheckedModeBanner: false,
            theme: buildPosTheme(isDark: false),
            darkTheme: buildPosTheme(isDark: true),
            themeMode: PosThemeController.instance.themeMode,
            home: isAuthenticated
                ? const DesktopShellPage()
                : (hasSeenWelcome
                    ? const RestaurantLoginPage()
                    : const RestaurantWelcomePage()),
            routes: {
              '/welcome': (_) => const RestaurantWelcomePage(),
              '/login': (_) => const RestaurantLoginPage(),
              '/dashboard': (_) => const DesktopShellPage(),
            },
          );
        },
      ),
    );
  }
}