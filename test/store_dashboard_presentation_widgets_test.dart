import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/features/stores/domain/entities/store_dashboard_models.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_dashboard_header.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_overview_section.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_orders_section.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_order_card.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_products_section.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_product_card.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_categories_section.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_banners_section.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_settings_section.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_product_editor_sheet.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_info_editor_sheet.dart';

Widget _wrapWithScreenUtil(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    builder: (context, _) => MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Store Dashboard Presentation Widgets Unit & Widget Tests', () {
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(1080, 2400);
      binding.platformDispatcher.views.first.devicePixelRatio = 2.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });
    testWidgets('1. StoreDashboardHeader renders store name and active status badge', (tester) async {
      const store = StoreDashboardEntity(
        storeId: 's1',
        name: 'سوبرماركت المدينة',
      );

      await tester.pumpWidget(_wrapWithScreenUtil(
        const StoreDashboardHeader(
          store: store,
          isDark: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('سوبرماركت المدينة'), findsOneWidget);
      expect(find.text('متجر نشط'), findsOneWidget);
    });

    testWidgets('2. StoreOverviewSection renders revenue and order statistics', (tester) async {
      const stats = StoreOrderStatisticsEntity(
        totalOrders: 15,
        pendingOrders: 3,
        acceptedOrders: 4,
        deliveringOrders: 2,
        completedOrders: 5,
        cancelledOrders: 1,
        totalRevenue: 50000.0,
        todayRevenue: 25000.0,
      );

      bool addProductTapped = false;
      bool madarPointsTapped = false;
      bool editStoreTapped = false;

      await tester.pumpWidget(_wrapWithScreenUtil(
        StoreOverviewSection(
          todayRevenue: 25000.0,
          totalRevenue: 50000.0,
          totalOrders: 15,
          productCount: 42,
          orderStatistics: stats,
          isDark: false,
          onAddProduct: () => addProductTapped = true,
          onMadarPoints: () => madarPointsTapped = true,
          onEditStore: () => editStoreTapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('أرباح اليوم'), findsOneWidget);
      expect(find.text('25000 د.ع'), findsOneWidget);
      expect(find.text('إجمالي الأرباح'), findsOneWidget);
      expect(find.text('50000 د.ع'), findsOneWidget);
      expect(find.text('إجمالي الطلبات'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);

      await tester.tap(find.text('إضافة منتج'));
      expect(addProductTapped, isTrue);

      await tester.tap(find.text('نقاط مدار'));
      expect(madarPointsTapped, isTrue);

      await tester.tap(find.text('تعديل المتجر'));
      expect(editStoreTapped, isTrue);
    });

    testWidgets('3. StoreOrderCard renders customer info, total, and triggers callbacks', (tester) async {
      final order = StoreOrderEntity(
        orderId: 'ord_123',
        status: 'pending',
        orderStatus: StoreOrderStatus.pending,
        customerName: 'محمد علي',
        customerPhone: '07712345678',
        address: 'حي الكرادة',
        total: 18000.0,
        items: [
          const StoreOrderItemEntity(itemId: 'i1', name: 'شاي عراقي', price: 3000, quantity: 2),
        ],
      );

      String? transitionedId;
      String? nextStatusTarget;
      String? calledPhone;

      await tester.pumpWidget(_wrapWithScreenUtil(
        StoreOrderCard(
          order: order,
          isDark: false,
          onStatusChange: (id, status) {
            transitionedId = id;
            nextStatusTarget = status;
          },
          onCallCustomer: (phone) => calledPhone = phone,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('#ord_123'), findsOneWidget);
      expect(find.text('محمد علي'), findsOneWidget);
      expect(find.text('حي الكرادة'), findsOneWidget);
      expect(find.text('18000 د.ع'), findsOneWidget);
      expect(find.text('شاي عراقي'), findsOneWidget);

      // Tap Accept
      await tester.tap(find.text('قبول'));
      expect(transitionedId, equals('ord_123'));
      expect(nextStatusTarget, equals('accepted'));

      // Tap Reject
      await tester.tap(find.text('رفض'));
      expect(nextStatusTarget, equals('cancelled'));

      // Tap Call
      await tester.tap(find.byIcon(Icons.call_rounded));
      expect(calledPhone, equals('07712345678'));
    });

    testWidgets('4. StoreOrdersSection renders filter chips and handles filter changes', (tester) async {
      String selected = 'all';

      await tester.pumpWidget(_wrapWithScreenUtil(
        StoreOrdersSection(
          orders: [
            StoreOrderEntity(
              orderId: 'o1',
              status: 'pending',
              orderStatus: StoreOrderStatus.pending,
              total: 5000,
            ),
          ],
          selectedFilter: selected,
          isDark: false,
          onFilterChanged: (f) => selected = f,
          onStatusChange: (_, __) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('الكل'), findsOneWidget);
      expect(find.text('بانتظار'), findsOneWidget);

      await tester.tap(find.text('بانتظار'));
      expect(selected, equals('pending'));
    });

    testWidgets('5. StoreProductCard renders product information and actions', (tester) async {
      const product = StoreProductEntity(
        productId: 'p1',
        name: 'لبن أربيل',
        price: 1500.0,
        category: 'ألبان',
      );

      bool editTapped = false;
      bool deleteTapped = false;

      await tester.pumpWidget(_wrapWithScreenUtil(
        StoreProductCard(
          product: product,
          isDark: false,
          onEdit: () => editTapped = true,
          onDelete: () => deleteTapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('لبن أربيل'), findsOneWidget);
      expect(find.text('1500 د.ع'), findsOneWidget);
      expect(find.text('ألبان'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_rounded));
      expect(editTapped, isTrue);

      await tester.tap(find.byIcon(Icons.delete_rounded));
      expect(deleteTapped, isTrue);
    });

    testWidgets('6. StoreProductsSection renders add button and product cards', (tester) async {
      bool addProductTapped = false;

      await tester.pumpWidget(_wrapWithScreenUtil(
        StoreProductsSection(
          products: const [
            StoreProductEntity(productId: 'p1', name: 'عصير تفاح', price: 1000),
          ],
          isDark: false,
          onAddProduct: () => addProductTapped = true,
          onEditProduct: (_) {},
          onDeleteProduct: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('إضافة منتج جديد'), findsOneWidget);
      expect(find.text('عصير تفاح'), findsOneWidget);

      await tester.tap(find.text('إضافة منتج جديد'));
      expect(addProductTapped, isTrue);
    });

    testWidgets('7. StoreCategoriesSection renders categories and in-memory product counts', (tester) async {
      bool addCategoryTapped = false;
      String? deletedId;

      await tester.pumpWidget(_wrapWithScreenUtil(
        StoreCategoriesSection(
          categories: const [
            StoreCategoryEntity(categoryId: 'c1', name: 'مشروبات'),
          ],
          productCounts: const {'مشروبات': 12},
          isDark: false,
          onAddCategory: () => addCategoryTapped = true,
          onDeleteCategory: (id) => deletedId = id,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('إضافة قسم جديد'), findsOneWidget);
      expect(find.text('مشروبات'), findsOneWidget);
      expect(find.text('12 منتج'), findsOneWidget);

      await tester.tap(find.text('إضافة قسم جديد'));
      expect(addCategoryTapped, isTrue);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      expect(deletedId, equals('c1'));
    });

    testWidgets('8. StoreBannersSection renders banners and triggers callbacks', (tester) async {
      bool addBannerTapped = false;
      String? deletedBannerId;

      await tester.pumpWidget(_wrapWithScreenUtil(
        StoreBannersSection(
          banners: const [
            StoreBannerEntity(
              bannerId: 'b1',
              title: 'تخفيضات كبرى',
              subtitle: 'خصم 50% على المنظفات',
              imageUrl: 'https://example.com/banner.png',
            ),
          ],
          isDark: false,
          onAddBanner: () => addBannerTapped = true,
          onDeleteBanner: (id) => deletedBannerId = id,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('تخفيضات كبرى'), findsOneWidget);
      expect(find.text('خصم 50% على المنظفات'), findsOneWidget);
      expect(find.text('إضافة بانر'), findsOneWidget);

      await tester.tap(find.text('إضافة بانر'));
      expect(addBannerTapped, isTrue);

      await tester.tap(find.byIcon(Icons.delete_forever_rounded));
      expect(deletedBannerId, equals('b1'));
    });

    testWidgets('9. StoreSettingsSection renders settings items and invokes callbacks', (tester) async {
      bool editStoreTapped = false;
      bool transferTapped = false;
      bool helpTapped = false;

      await tester.pumpWidget(_wrapWithScreenUtil(
        StoreSettingsSection(
          isDark: false,
          onEditStoreInfo: () => editStoreTapped = true,
          onTransferOwnership: () => transferTapped = true,
          onHelpCenter: () => helpTapped = true,
          onAboutStore: () {},
          onDeleteStore: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('إدارة المتجر'), findsOneWidget);
      expect(find.text('تعديل بيانات المتجر'), findsOneWidget);
      expect(find.text('نقل ملكية المتجر'), findsOneWidget);
      expect(find.text('مركز المساعدة'), findsOneWidget);

      await tester.tap(find.text('تعديل بيانات المتجر'));
      expect(editStoreTapped, isTrue);

      await tester.tap(find.text('نقل ملكية المتجر'));
      expect(transferTapped, isTrue);

      await tester.tap(find.text('مركز المساعدة'));
      expect(helpTapped, isTrue);
    });

    testWidgets('10. StoreProductEditorSheet collects form data and triggers onSave', (tester) async {
      String? savedName;
      double? savedPrice;

      await tester.pumpWidget(_wrapWithScreenUtil(
        StoreProductEditorSheet(
          categories: const [StoreCategoryEntity(categoryId: 'c1', name: 'ألبان')],
          isDark: false,
          onSave: ({
            required String name,
            required double price,
            required String description,
            required String category,
            required String imageUrl,
            required bool isAvailable,
          }) {
            savedName = name;
            savedPrice = price;
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('إضافة منتج جديد'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'اسم المنتج'), 'حليب طازج');
      await tester.enterText(find.widgetWithText(TextField, 'السعر (د.ع)'), '2000');
      await tester.pumpAndSettle();

      await tester.tap(find.text('إضافة المنتج'));
      expect(savedName, equals('حليب طازج'));
      expect(savedPrice, equals(2000.0));
    });

    testWidgets('11. StoreInfoEditorSheet collects store details and triggers onSave', (tester) async {
      String? updatedName;

      await tester.pumpWidget(_wrapWithScreenUtil(
        StoreInfoEditorSheet(
          fallbackName: 'متجر الأنوار',
          isDark: false,
          onSave: ({
            required String name,
            String? logoUrl,
            String? coverUrl,
            double? latitude,
            double? longitude,
            String? address,
          }) {
            updatedName = name;
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('تعديل بيانات المتجر'), findsOneWidget);
      expect(find.text('متجر الأنوار'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'اسم المتجر'), 'متجر الأنوار الجديد');
      await tester.pumpAndSettle();

      await tester.tap(find.text('حفظ التغييرات'));
      expect(updatedName, equals('متجر الأنوار الجديد'));
    });
  });
}
