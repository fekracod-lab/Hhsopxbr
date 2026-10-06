import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/error/shop_crash_guard.dart';
import 'core/database/local_database_service.dart';
import 'features/auth/data/services/store_auth_service.dart';
import 'features/shifts/data/services/shift_service.dart';
import 'features/online_orders/data/services/online_orders_service.dart';
import 'features/auth/presentation/pages/store_selector_page.dart';
import 'features/shell/presentation/shop_shell_page.dart';

/// تجاوز فحوصات الشهادات المحلية على منصة سطح المكتب لتفادي أخطاء CERTIFICATE_VERIFY_FAILED
class MadarShopHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // تجاوز قيود الشهادات على ويندوز
    try {
      HttpOverrides.global = MadarShopHttpOverrides();
    } catch (_) {}

    // تهيئة حارس الأخطاء
    ShopCrashGuard.init();

    // 1. تهيئة مظهر المتجر واللغة
    await ShopThemeController.instance.load();

    // 2. تهيئة الاتصال السحابي بمشروع مدار الرئيسي (dala-alqaim)
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e, st) {
      ShopCrashGuard.reportUnhandledError(e, st, '[FirebaseInit]');
    }

    // 3. تهيئة قاعدة البيانات المحلية التراكمية
    try {
      await LocalDatabaseService.instance.database;
    } catch (e, st) {
      ShopCrashGuard.reportUnhandledError(e, st, '[SQLiteInit]');
    }

    // 4. استعادة بيانات المتجر والوردية النشطة
    await StoreAuthService.instance.init();
    await ShiftService.instance.init();

    runApp(const MadarShopApp());
  }, (error, stack) {
    ShopCrashGuard.reportUnhandledError(error, stack, '[RootZoneError]');
  });
}

class MadarShopApp extends StatefulWidget {
  const MadarShopApp({super.key});

  @override
  State<MadarShopApp> createState() => _MadarShopAppState();
}

class _MadarShopAppState extends State<MadarShopApp> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: StoreAuthService.instance),
        ChangeNotifierProvider.value(value: ShiftService.instance),
        ChangeNotifierProvider.value(value: OnlineOrdersService.instance),
      ],
      child: ListenableBuilder(
        listenable: ShopThemeController.instance,
        builder: (context, _) {
          final isDark = ShopThemeController.instance.isDark;

          return ScreenUtilInit(
            designSize: const Size(1440, 900),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) {
              return MaterialApp(
                navigatorKey: ShopCrashGuard.navigatorKey,
                builder: (ctx, child) => ShopCrashGuard.appBuilder(ctx, child),
                title: 'نظام كاشير المتاجر — مدار',
                debugShowCheckedModeBanner: false,
                theme: ShopTheme.buildTheme(isDark: false),
                darkTheme: ShopTheme.buildTheme(isDark: true),
                themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                home: ListenableBuilder(
                  listenable: StoreAuthService.instance,
                  builder: (context, _) {
                    final currentStore = StoreAuthService.instance.currentStore;
                    if (currentStore != null) {
                      return ShopShellPage(
                        store: currentStore,
                        onSwitchStore: () => setState(() {}),
                      );
                    }
                    return StoreSelectorPage(
                      onStoreSelected: (store) => setState(() {}),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
