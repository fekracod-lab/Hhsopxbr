import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/features/stores/application/store_dashboard_controller.dart';
import 'package:dalal_alqaim/features/stores/data/repositories/store_repository.dart';
import 'package:dalal_alqaim/features/stores/data/datasources/store_remote_datasource.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/store_dashboard_page.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_order_card.dart';

/// Fake Datasource for coordinator integration and regression tests
class _FakeStoreRemoteDatasource extends StoreRemoteDatasource {
  final StreamController<Map<String, dynamic>?> storeController =
      StreamController<Map<String, dynamic>?>.broadcast();
  final StreamController<List<Map<String, dynamic>>> pendingOrdersController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> allOrdersController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> ordersController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> productsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> categoriesController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> bannersController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  Map<String, dynamic>? currentStore;
  List<Map<String, dynamic>> currentOrders = [];
  List<Map<String, dynamic>> currentPendingOrders = [];
  List<Map<String, dynamic>> currentAllOrders = [];
  List<Map<String, dynamic>> currentProducts = [];
  List<Map<String, dynamic>> currentCategories = [];
  List<Map<String, dynamic>> currentBanners = [];

  bool updateOrderStatusCalled = false;
  String? lastUpdatedOrderId;
  String? lastUpdatedStatus;

  bool createProductCalled = false;
  bool updateProductCalled = false;
  bool deleteProductCalled = false;
  bool createCategoryCalled = false;
  bool deleteCategoryCalled = false;
  bool createBannerCalled = false;
  bool deleteBannerCalled = false;
  bool updateStoreProfileCalled = false;
  bool transferOwnershipCalled = false;

  @override
  Stream<Map<String, dynamic>?> watchStore(String storeId) async* {
    yield currentStore;
    yield* storeController.stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchPendingOrders(String storeId) async* {
    yield currentPendingOrders;
    yield* pendingOrdersController.stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchAllOrders(String storeId) async* {
    yield currentAllOrders;
    yield* allOrdersController.stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchOrders(String storeId) async* {
    yield currentOrders;
    yield* ordersController.stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchProducts(String storeId) async* {
    yield currentProducts;
    yield* productsController.stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchCategories(String storeId) async* {
    yield currentCategories;
    yield* categoriesController.stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchBanners(String storeId) async* {
    yield currentBanners;
    yield* bannersController.stream;
  }

  @override
  Future<void> updateOrderStatus({
    required String storeId,
    required String orderId,
    required String nextStatus,
  }) async {
    updateOrderStatusCalled = true;
    lastUpdatedOrderId = orderId;
    lastUpdatedStatus = nextStatus;
  }

  @override
  Future<void> markOrderAsRead({
    required String storeId,
    required String orderId,
  }) async {}

  @override
  Future<void> createProduct({
    required String storeId,
    required Map<String, dynamic> productData,
  }) async {
    createProductCalled = true;
  }

  @override
  Future<void> updateProduct({
    required String storeId,
    required String productId,
    required Map<String, dynamic> productData,
  }) async {
    updateProductCalled = true;
  }

  @override
  Future<void> deleteProduct({
    required String storeId,
    required String productId,
  }) async {
    deleteProductCalled = true;
  }

  @override
  Future<void> createCategory({
    required String storeId,
    required String name,
    int iconCode = 0xe148,
    int colorValue = 0xFFF5F5F5,
  }) async {
    createCategoryCalled = true;
  }

  @override
  Future<void> deleteCategory({
    required String storeId,
    required String categoryId,
  }) async {
    deleteCategoryCalled = true;
  }

  @override
  Future<void> createBanner({
    required String storeId,
    required String title,
    String subtitle = '',
    required String imageUrl,
  }) async {
    createBannerCalled = true;
  }

  @override
  Future<void> deleteBanner({
    required String storeId,
    required String bannerId,
  }) async {
    deleteBannerCalled = true;
  }

  @override
  Future<void> updateStoreProfile({
    required String storeId,
    required String name,
    String? logoUrl,
    String? coverUrl,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    updateStoreProfileCalled = true;
  }

  @override
  Future<bool> transferStoreOwnership({
    required String storeId,
    required String targetEmail,
  }) async {
    transferOwnershipCalled = true;
    return true;
  }

  @override
  Future<void> migrateOldData(String storeId) async {}

  void dispose() {
    storeController.close();
    pendingOrdersController.close();
    allOrdersController.close();
    ordersController.close();
    productsController.close();
    categoriesController.close();
    bannersController.close();
  }
}

Widget _wrapPage(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    builder: (context, _) => MaterialApp(
      home: child,
    ),
  );
}

void main() {
  group('StoreDashboardPage — Coordinator Regression & Integration Tests', () {
    late _FakeStoreRemoteDatasource fakeDatasource;
    late StoreRepository repository;
    late StoreDashboardController controller;

    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(1080, 2400);
      binding.platformDispatcher.views.first.devicePixelRatio = 2.0;

      fakeDatasource = _FakeStoreRemoteDatasource();
      fakeDatasource.currentStore = {
        'name': 'متجر الرافدين النموذجي',
        'logoUrl': 'https://example.com/logo.jpg',
        'coverUrl': 'https://example.com/cover.jpg',
      };
      fakeDatasource.currentOrders = [
        {
          'id': 'ord_1',
          'orderId': 'ord_1',
          'status': 'pending',
          'customerName': 'حيدر الكرخي',
          'total': 12000.0,
          'items': [
            {'name': 'شاي فاخر', 'price': 3000.0, 'quantity': 4},
          ],
        },
      ];
      fakeDatasource.currentPendingOrders = [
        {
          'id': 'ord_1',
          'orderId': 'ord_1',
          'status': 'pending',
        },
      ];
      fakeDatasource.currentAllOrders = [
        {
          'id': 'ord_1',
          'orderId': 'ord_1',
          'status': 'pending',
          'total': 12000.0,
        },
      ];
      fakeDatasource.currentProducts = [
        {
          'id': 'prod_1',
          'productId': 'prod_1',
          'name': 'زيت زيتون بكر',
          'price': 8500.0,
          'category': 'زيوت',
        },
      ];
      fakeDatasource.currentCategories = [
        {
          'id': 'cat_1',
          'categoryId': 'cat_1',
          'name': 'زيوت',
        },
      ];
      fakeDatasource.currentBanners = [
        {
          'id': 'ban_1',
          'bannerId': 'ban_1',
          'title': 'عروض رمضان المبارك',
          'imageUrl': 'https://example.com/banner.jpg',
        },
      ];

      repository = StoreRepository(remoteDatasource: fakeDatasource);
      controller = StoreDashboardController(
        storeId: 'store_reg_1',
        repository: repository,
      );
      controller.initialize();
    });

    tearDown(() {
      controller.dispose();
      fakeDatasource.dispose();
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    testWidgets('1. Constructor compatibility & fallback rendering with injected controller', (tester) async {
      final page = StoreDashboardPage(
        storeId: 'store_reg_1',
        storeData: const {
          'name': 'متجر الرافدين',
          'logoUrl': 'https://example.com/logo.png',
        },
        controller: controller,
      );

      await tester.pumpWidget(_wrapPage(page));
      await tester.pumpAndSettle();

      expect(find.text('متجر الرافدين النموذجي'), findsOneWidget);
      expect(find.text('نظرة عامة'), findsOneWidget);
      expect(find.text('الطلبات'), findsOneWidget);
      expect(find.text('المنتجات'), findsWidgets);
      expect(find.text('الأقسام'), findsOneWidget);
      expect(find.text('البانرات'), findsOneWidget);
      expect(find.text('الإعدادات'), findsOneWidget);
    });

    testWidgets('2. TabController switches across all 6 tabs safely without throwing', (tester) async {
      final page = StoreDashboardPage(
        storeId: 'store_reg_1',
        controller: controller,
      );

      await tester.pumpWidget(_wrapPage(page));
      await tester.pumpAndSettle();

      // Tab 0: Overview
      expect(find.text('أرباح اليوم'), findsOneWidget);

      // Tap Tab 1: Orders
      await tester.tap(find.text('الطلبات'));
      await tester.pumpAndSettle();
      expect(find.text('حيدر الكرخي'), findsOneWidget);

      // Tap Tab 2: Products
      await tester.tap(find.widgetWithText(Tab, 'المنتجات'));
      await tester.pumpAndSettle();
      expect(find.text('زيت زيتون بكر'), findsOneWidget);

      // Tap Tab 3: Categories
      await tester.tap(find.text('الأقسام'));
      await tester.pumpAndSettle();
      expect(find.text('زيوت'), findsOneWidget);

      // Tap Tab 4: Banners
      await tester.tap(find.text('البانرات'));
      await tester.pumpAndSettle();
      expect(find.text('عروض رمضان المبارك'), findsOneWidget);

      // Tap Tab 5: Settings
      await tester.tap(find.text('الإعدادات'));
      await tester.pumpAndSettle();
      expect(find.text('إدارة المتجر'), findsOneWidget);
    });

    testWidgets('3. Pending orders count badge correctly reflects in tab bar', (tester) async {
      final page = StoreDashboardPage(
        storeId: 'store_reg_1',
        controller: controller,
      );

      await tester.pumpWidget(_wrapPage(page));
      await tester.pumpAndSettle();

      expect(controller.pendingOrderCount, equals(1));
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('4. Order status action in Orders Tab delegates to controller and datasource', (tester) async {
      final page = StoreDashboardPage(
        storeId: 'store_reg_1',
        controller: controller,
      );

      await tester.pumpWidget(_wrapPage(page));
      await tester.pumpAndSettle();

      // Switch to Orders Tab
      await tester.tap(find.text('الطلبات'));
      await tester.pumpAndSettle();

      expect(find.text('حيدر الكرخي'), findsOneWidget);
      expect(find.byType(StoreOrderCard), findsOneWidget);

      final orderCard = tester.widget<StoreOrderCard>(find.byType(StoreOrderCard));
      orderCard.onStatusChange('ord_1', 'accepted');
      await tester.pumpAndSettle();

      expect(fakeDatasource.updateOrderStatusCalled, isTrue);
      expect(fakeDatasource.lastUpdatedOrderId, equals('ord_1'));
      expect(fakeDatasource.lastUpdatedStatus, equals('accepted'));
    });

    testWidgets('5. Multiple rebuilds do not duplicate stream listeners or crash coordinator', (tester) async {
      final page = StoreDashboardPage(
        storeId: 'store_reg_1',
        controller: controller,
      );

      await tester.pumpWidget(_wrapPage(page));
      await tester.pumpAndSettle();

      // Trigger re-pumps simulating parent rebuilds
      await tester.pumpWidget(_wrapPage(page));
      await tester.pumpWidget(_wrapPage(page));
      await tester.pumpAndSettle();

      expect(find.text('متجر الرافدين النموذجي'), findsOneWidget);
      expect(controller.products.length, equals(1));
    });
  });
}
