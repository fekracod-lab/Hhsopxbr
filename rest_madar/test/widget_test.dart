// اختبارات دخان لنظام مدار POS — هوية مزدوجة (فاتح/داكن) والمكونات الأساسية
// تغطي: متحكم المظهر (الحفظ/التبديل) + بناء الثيم + مكون الحالة
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rest_madar/core/localization/pos_language_controller.dart';
import 'package:rest_madar/core/theme/app_theme.dart';
import 'package:rest_madar/core/widgets/pos_status_chip.dart';
import 'package:rest_madar/core/constants/pos_constants.dart';
import 'package:rest_madar/features/pos/application/pos_provider.dart';
import 'package:rest_madar/services/offline_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // منع جلب الخطوط من الإنترنت داخل بيئة الاختبار (تستخدم الـ fallback)
  GoogleFonts.config.allowRuntimeFetching = false;

  group('PosThemeController — الهوية المزدوجة', () {
    test('يحمل الوضع المحفوظ (فاتح) من التخزين المحلي', () async {
      SharedPreferences.setMockInitialValues({'madar_pos_theme_mode': 'light'});
      final controller = PosThemeController.instance;
      await controller.load();
      expect(controller.isLoaded, isTrue);
      expect(controller.isDark, isFalse);
      expect(controller.themeMode, ThemeMode.light);
    });

    test('التبديل يحفظ الوضع الداكن في التخزين المحلي', () async {
      SharedPreferences.setMockInitialValues({'madar_pos_theme_mode': 'light'});
      final controller = PosThemeController.instance;
      await controller.load();
      await controller.setDark(true);
      expect(controller.isDark, isTrue);
      expect(controller.themeMode, ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('madar_pos_theme_mode'), 'dark');
    });

    test('الألوان الدلالية تتغير حسب الوضع عبر posColors', () async {
      SharedPreferences.setMockInitialValues({'madar_pos_theme_mode': 'dark'});
      final controller = PosThemeController.instance;
      await controller.load();
      expect(controller.isDark, isTrue);
      expect(PosPalette.dark.background, isNot(PosPalette.light.background));
    });

    test('تغيير لون البراند يحفظ الاختيار في التخزين المحلي ويحدث currentColors', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = PosThemeController.instance;
      await controller.load();
      await controller.setBrandColor(MadarBrandColors.blue);
      expect(controller.brandColor.id, 'blue');
      expect(controller.currentColors.primary, MadarBrandColors.blue.primary);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('madar_pos_brand_color'), 'blue');
    });
  });

  group('PosPalette — ألوان الهوية المزدوجة', () {
    test('لوحة داكنة ولوحة فاتحة مختلفتان في الأسطح والنصوص', () {
      expect(PosPalette.dark.background, isNot(PosPalette.light.background));
      expect(PosPalette.dark.surface, isNot(PosPalette.light.surface));
      expect(PosPalette.dark.card, isNot(PosPalette.light.card));
      expect(PosPalette.dark.textPrimary, isNot(PosPalette.light.textPrimary));
    });

    test('ألوان القائمة الجانبية كلها متطابقة في الوضعين (هوية موحّدة)', () {
      expect(PosPalette.dark.sidebar, PosPalette.light.sidebar);
      expect(PosPalette.dark.sidebarText, PosPalette.light.sidebarText);
      expect(PosPalette.dark.sidebarMuted, PosPalette.light.sidebarMuted);
      expect(PosPalette.dark.sidebarSelected, PosPalette.light.sidebarSelected);
    });
  });

  group('PosStatusChip — المكون الأساسي', () {
    testWidgets('يعرض التسمية والأيقونة', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PosStatusChip(
                label: 'مكتمل',
                icon: Icons.check_circle_rounded,
                color: Colors.green,
              ),
            ),
          ),
        ),
      );

      expect(find.text('مكتمل'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });

  group('PosLanguageController — دعم اللغة والشعار', () {
    test('الوضع الافتراضي هو الإنجليزية مع اتجاه LTR وحفظ التفضيل', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = PosLanguageController.instance;
      await controller.load(force: true);
      expect(controller.isEnglish, isTrue);
      expect(controller.isArabic, isFalse);
      expect(controller.textDirection, TextDirection.ltr);
      expect(controller.languageCode, 'en');
    });

    test('التبديل إلى العربية يغير الاتجاه إلى RTL ويحفظ القيمة', () async {
      SharedPreferences.setMockInitialValues({'madar_pos_app_language': 'en'});
      final controller = PosLanguageController.instance;
      await controller.load(force: true);
      await controller.toggle();
      expect(controller.isEnglish, isFalse);
      expect(controller.isArabic, isTrue);
      expect(controller.textDirection, TextDirection.rtl);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('madar_pos_app_language'), 'ar');
    });

    test('التعيين المباشر للغة يعمل بدقة', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = PosLanguageController.instance;
      await controller.load(force: true);
      await controller.setLanguage('ar');
      expect(controller.languageCode, 'ar');
      await controller.setLanguage('en');
      expect(controller.languageCode, 'en');
      expect(controller.isEnglish, isTrue);
    });

    test('PosLocale يتغير ديناميكياً مع تغير لغة الـ Controller', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = PosLanguageController.instance;
      await controller.setLanguage('en');
      expect(PosLocale.cart, 'Cashier Cart');
      expect(PosLocale.dineIn, 'Dine-In');
      expect(PosLocale.checkout, 'Checkout & Pay');

      await controller.setLanguage('ar');
      expect(PosLocale.cart, 'سلة الكاشير');
      expect(PosLocale.dineIn, 'صالة');
      expect(PosLocale.checkout, 'إتمام الطلب والدفع');
    });

    test('PosLocale الثوابت المباشرة En و Ar تعمل بدقة ومطابقة', () {
      expect(PosLocale.addMealEn, 'Add Meal');
      expect(PosLocale.addMealAr, 'إضافة وجبة');
      expect(PosLocale.occupiedEn, 'Occupied');
      expect(PosLocale.occupiedAr, 'مشغولة');
      expect(PosLocale.vacantEn, 'Available');
      expect(PosLocale.vacantAr, 'شاغرة');
      expect(PosLocale.cashEn, 'Cash');
      expect(PosLocale.cashAr, 'نقداً (كاش)');
    });
  });

  group('PosProvider — بيع التوصيل وبيانات العميل', () {
    test('تسجيل بيانات التوصيل (الاسم، الهاتف، العنوان، الملاحظات) وتثبيتها بنجاح', () {
      final pos = PosProvider();
      pos.setOrderType(PosConstants.orderTypeDelivery);
      expect(pos.orderType, 'delivery');

      pos.setCustomerInfo(
        name: 'حيدر الكرخي',
        phone: '07701234567',
        address: 'بغداد - الكرخ - شارع الرشيد',
        notes: 'الطابق الثاني - الاتصال عند الوصول',
      );

      expect(pos.customerName, 'حيدر الكرخي');
      expect(pos.customerPhone, '07701234567');
      expect(pos.deliveryAddress, 'بغداد - الكرخ - شارع الرشيد');
      expect(pos.orderNotes, 'الطابق الثاني - الاتصال عند الوصول');
    });

    test('تعليق واسترجاع طلب توصيل يحافظ على بيانات العميل والعنوان بدقة', () {
      final pos = PosProvider();
      pos.setOrderType(PosConstants.orderTypeDelivery);
      pos.addToCart(
        mealId: 'm1',
        name: 'برغر لحم دبل',
        unitPrice: 7500,
      );
      pos.setCustomerInfo(
        name: 'سارة أحمد',
        phone: '07809876543',
        address: 'المنصور - مجاور مول المنصور',
      );

      expect(pos.holdCurrentOrder(), isTrue);
      expect(pos.isCartEmpty, isTrue);

      expect(pos.heldOrders.length, 1);
      final held = pos.heldOrders.first;
      expect(held.orderType, 'delivery');
      expect(held.customerName, 'سارة أحمد');
      expect(held.customerPhone, '07809876543');
      expect(held.deliveryAddress, 'المنصور - مجاور مول المنصور');

      pos.restoreHeldOrder(held.id);
      expect(pos.orderType, 'delivery');
      expect(pos.customerName, 'سارة أحمد');
      expect(pos.customerPhone, '07809876543');
      expect(pos.deliveryAddress, 'المنصور - مجاور مول المنصور');
      expect(pos.cartItems.length, 1);
    });
  });

  group('OfflineAuthService — تسجيل الدخول والعمل بدون إنترنت (Offline-First)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('تشفير القيم بواسطة SHA-256 محكم وثابت', () {
      final hash1 = OfflineAuthService.hashValue('123456');
      final hash2 = OfflineAuthService.hashValue('123456');
      final hash3 = OfflineAuthService.hashValue('0000');

      expect(hash1, equals(hash2));
      expect(hash1, isNot(equals(hash3)));
      expect(hash1.length, equals(64)); // 256 bits = 64 hex characters
    });

    test('حفظ بيانات الدخول المسبقة والتحقق منها بنجاح في وضع الأوفلاين', () async {
      final auth = OfflineAuthService.instance;
      await auth.init();

      await auth.cacheOnlineCredentials(
        uid: 'rest_alqaim_101',
        email: 'restaurant@alqaim.pos',
        password: 'SecretPassword123',
        restaurantName: 'مشاوي القائم الكبرى',
        ownerName: 'أبو فهد',
        city: 'القائم',
      );

      expect(auth.hasAnyCachedMerchant, isTrue);
      expect(auth.isMerchantCached('rest_alqaim_101'), isTrue);
      expect(auth.cachedRestaurantName, 'مشاوي القائم الكبرى');

      // تجربة كلمة مرور خاطئة
      final failResult = await auth.authenticateOffline(
        email: 'restaurant@alqaim.pos',
        password: 'WrongPassword',
      );
      expect(failResult.success, isFalse);

      // تجربة كلمة مرور صحيحة
      final successResult = await auth.authenticateOffline(
        email: 'restaurant@alqaim.pos',
        password: 'SecretPassword123',
      );
      expect(successResult.success, isTrue);
      expect(auth.isOfflineSession, isTrue);
      expect(auth.currentUid, 'rest_alqaim_101');
      expect(auth.cachedOwnerName, 'أبو فهد');
    });

    test('تسجيل دخول الكاشير السريع برمز PIN الافتراضي والمخصص أوفلاين', () async {
      final auth = OfflineAuthService.instance;
      await auth.init();

      await auth.cacheOnlineCredentials(
        uid: 'rest_pin_test',
        email: 'pin@madar.pos',
        password: 'pass',
        restaurantName: 'مطعم الكاشير السريع',
        ownerName: 'كاشير الصالة',
        pin: '1234',
      );

      // تجربة PIN خاطئ
      final badPin = await auth.authenticateWithPin('9999');
      expect(badPin.success, isFalse);

      // تجربة PIN المخصص الصحيح
      final goodPin = await auth.authenticateWithPin('1234');
      expect(goodPin.success, isTrue);
      expect(auth.currentUid, 'rest_pin_test');
    });

    test('تأسيس مطعم محلي بدون إنترنت نهائياً بنجاح', () async {
      final auth = OfflineAuthService.instance;
      await auth.init();

      final result = await auth.createLocalOfflineRestaurant(
        restaurantName: 'مطعم وادي الفرات',
        ownerName: 'حسين علي',
        city: 'راوة',
        pin: '5555',
      );

      expect(result.success, isTrue);
      expect(auth.isOfflineSession, isTrue);
      expect(auth.currentProfile?.isLocalOnly, isTrue);
      expect(auth.cachedRestaurantName, 'مطعم وادي الفرات');
      expect(auth.cachedOwnerName, 'حسين علي');
      expect(auth.currentUid, startsWith('local_rest_'));

      // التحقق من فحص الجلسة النشطة
      final hasSession = await auth.hasActiveOfflineSession();
      expect(hasSession, isTrue);

      // تسجيل الخروج ينهي الجلسة
      await auth.signOutOffline();
      final afterSignOut = await auth.hasActiveOfflineSession();
      expect(afterSignOut, isFalse);
    });
  });
}