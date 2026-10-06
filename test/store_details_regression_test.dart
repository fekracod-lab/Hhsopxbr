import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/features/stores/domain/entities/store_cart_item_entity.dart';
import 'package:dalal_alqaim/features/stores/data/repositories/store_details_repository.dart';
import 'package:dalal_alqaim/features/stores/data/datasources/store_details_remote_datasource.dart';
import 'package:dalal_alqaim/features/stores/application/store_details_controller.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/store_details_page.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_details_header.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_promo_banner.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_circle_categories.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_product_grid_card.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_order_success_dialog.dart';

class MockStoreDetailsRemoteDatasource extends StoreDetailsRemoteDatasource {
  final StreamController<List<Map<String, dynamic>>> productsCtrl =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> categoriesCtrl =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> bannersCtrl =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  bool orderPlaced = false;
  bool productCreated = false;
  bool categoryCreated = false;
  bool bannerAdded = false;

  @override
  Stream<List<Map<String, dynamic>>> watchProducts(String storeId) =>
      productsCtrl.stream;

  @override
  Stream<List<Map<String, dynamic>>> watchCategories(String storeId) =>
      categoriesCtrl.stream;

  @override
  Stream<List<Map<String, dynamic>>> watchBanners(String storeId) =>
      bannersCtrl.stream;

  @override
  Future<Map<String, dynamic>?> getStore(String storeId) async {
    return {
      'name': 'سوبرماركت النور',
      'ownerId': 'owner_123',
      'phone': '07701234567',
      'deliveryFee': 2500,
    };
  }

  @override
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    return {
      'uid': userId,
      'fullName': 'أحمد العراقي',
      'phone': '07801234567',
      'address': 'شارع الزهور، القائم',
      'balance': 100000.0,
      'points': 500,
      'role': userId == 'owner_123' ? 'owner' : 'user',
    };
  }

  @override
  Future<bool> placeOrderAtomic({
    required String storeId,
    required String userId,
    required String orderId,
    required String customerName,
    required String customerPhone,
    required String address,
    required String notes,
    double? latitude,
    double? longitude,
    required Map<String, dynamic> storeData,
    required List<StoreCartItemEntity> items,
    required dynamic summary,
  }) async {
    orderPlaced = true;
    return true;
  }

  @override
  Future<void> createProduct({
    required String storeId,
    required Map<String, dynamic> productData,
  }) async {
    productCreated = true;
  }

  @override
  Future<void> createCategory({
    required String storeId,
    required String name,
    int iconCode = 0xe148,
    int colorValue = 0xFFF5F5F5,
  }) async {
    categoryCreated = true;
  }

  @override
  Future<void> addBanner({
    required String storeId,
    required String imageUrl,
  }) async {
    bannerAdded = true;
  }

  void dispose() {
    productsCtrl.close();
    categoriesCtrl.close();
    bannersCtrl.close();
  }
}

Widget buildTestablePage({
  required Widget child,
}) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    builder: (context, _) => MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockStoreDetailsRemoteDatasource mockDatasource;
  late StoreDetailsRepository repository;
  late StoreDetailsController controller;

  setUp(() {
    mockDatasource = MockStoreDetailsRemoteDatasource();
    repository = StoreDetailsRepository(remoteDatasource: mockDatasource);
    controller = StoreDetailsController(
      storeId: 'store_123',
      initialStoreData: {
        'name': 'سوبرماركت النور',
        'ownerId': 'owner_123',
        'deliveryFee': 2500,
      },
      repository: repository,
    );
  });

  tearDown(() {
    controller.dispose();
    mockDatasource.dispose();
  });

  group('StoreDetailsPage — End-to-End Architecture & Regression Tests', () {
    testWidgets('1. Page renders complete coordinator structure with Header, Banners, Categories, Products',
        (tester) async {
      await tester.pumpWidget(
        buildTestablePage(
          child: StoreDetailsPage(
            storeId: 'store_123',
            storeData: const {'name': 'سوبرماركت النور', 'deliveryFee': 2500},
            controller: controller,
          ),
        ),
      );

      await tester.pump();

      // Emit products and categories
      mockDatasource.categoriesCtrl.add([
        {'id': 'cat_1', 'name': 'مشروبات', 'iconCode': 0xe148, 'colorValue': 0xFFE3F2FD},
        {'id': 'cat_2', 'name': 'حلويات', 'iconCode': 0xe148, 'colorValue': 0xFFFFF3E0},
      ]);
      mockDatasource.productsCtrl.add([
        {'id': 'prod_1', 'name': 'عصير برتقال', 'price': 1500, 'category': 'مشروبات', 'imageUrl': ''},
        {'id': 'prod_2', 'name': 'شوكولاتة فاخرة', 'price': 3000, 'category': 'حلويات', 'imageUrl': ''},
      ]);

      await tester.pumpAndSettle();

      expect(find.byType(StoreDetailsHeader), findsOneWidget);
      expect(find.byType(StorePromoBanner), findsOneWidget);
      expect(find.byType(StoreCircleCategories), findsOneWidget);
      expect(find.byType(StoreProductGridCard), findsNWidgets(2));
      expect(find.text('عصير برتقال'), findsOneWidget);
      expect(find.text('شوكولاتة فاخرة'), findsOneWidget);
    });

    testWidgets('2. Search filtering filters products in real-time', (tester) async {
      await tester.pumpWidget(
        buildTestablePage(
          child: StoreDetailsPage(
            storeId: 'store_123',
            storeData: const {'name': 'سوبرماركت النور', 'deliveryFee': 2500},
            controller: controller,
          ),
        ),
      );

      mockDatasource.productsCtrl.add([
        {'id': 'prod_1', 'name': 'عصير برتقال', 'price': 1500, 'category': 'مشروبات', 'imageUrl': ''},
        {'id': 'prod_2', 'name': 'شوكولاتة فاخرة', 'price': 3000, 'category': 'حلويات', 'imageUrl': ''},
      ]);
      await tester.pumpAndSettle();

      controller.setSearchQuery('عصير');
      await tester.pumpAndSettle();

      expect(find.text('عصير برتقال'), findsOneWidget);
      expect(find.text('شوكولاتة فاخرة'), findsNothing);
    });

    testWidgets('3. Category selection filters products', (tester) async {
      await tester.pumpWidget(
        buildTestablePage(
          child: StoreDetailsPage(
            storeId: 'store_123',
            storeData: const {'name': 'سوبرماركت النور', 'deliveryFee': 2500},
            controller: controller,
          ),
        ),
      );

      mockDatasource.categoriesCtrl.add([
        {'id': 'cat_1', 'name': 'مشروبات', 'iconCode': 0xe148, 'colorValue': 0xFFE3F2FD},
        {'id': 'cat_2', 'name': 'حلويات', 'iconCode': 0xe148, 'colorValue': 0xFFFFF3E0},
      ]);
      mockDatasource.productsCtrl.add([
        {'id': 'prod_1', 'name': 'عصير برتقال', 'price': 1500, 'category': 'مشروبات', 'imageUrl': ''},
        {'id': 'prod_2', 'name': 'شوكولاتة فاخرة', 'price': 3000, 'category': 'حلويات', 'imageUrl': ''},
      ]);
      await tester.pumpAndSettle();

      controller.setSelectedCategory('حلويات');
      await tester.pumpAndSettle();

      expect(find.text('عصير برتقال'), findsNothing);
      expect(find.text('شوكولاتة فاخرة'), findsOneWidget);
    });

    testWidgets('4. Adding product to cart updates cart badge and quick bar', (tester) async {
      await tester.pumpWidget(
        buildTestablePage(
          child: StoreDetailsPage(
            storeId: 'store_123',
            storeData: const {'name': 'سوبرماركت النور', 'deliveryFee': 2500},
            controller: controller,
          ),
        ),
      );

      mockDatasource.productsCtrl.add([
        {'id': 'prod_1', 'name': 'عصير برتقال', 'price': 1500, 'category': 'مشروبات', 'imageUrl': ''},
      ]);
      await tester.pumpAndSettle();

      final addBtn = find.byKey(const ValueKey('add_to_cart_prod_1'));
      expect(addBtn, findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
      await tester.pumpAndSettle();

      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(controller.cartItemCount, 1);
      expect(controller.cartSubtotal, 1500.0);
      expect(find.text('عرض السلة (1)'), findsOneWidget);
    });

    testWidgets('5. Quick cart bar tap opens StoreCartBottomSheet', (tester) async {
      await tester.pumpWidget(
        buildTestablePage(
          child: StoreDetailsPage(
            storeId: 'store_123',
            storeData: const {'name': 'سوبرماركت النور', 'deliveryFee': 2500},
            controller: controller,
          ),
        ),
      );

      controller.addToCart(
        StoreCartItemEntity(
          productId: 'prod_1',
          name: 'عصير برتقال',
          price: 1500,
          quantity: 2,
        ),
      );
      await tester.pumpAndSettle();

      final cartButton = find.text('عرض السلة (2)');
      expect(cartButton, findsOneWidget);

      await tester.tap(cartButton);
      await tester.pumpAndSettle();

      expect(find.text('سلة التسوق'), findsOneWidget);
      expect(find.text('3000 د.ع'), findsWidgets);
    });

    testWidgets('6. Checkout execution calls placeOrderAtomic and triggers success dialog', (tester) async {
      await tester.pumpWidget(
        buildTestablePage(
          child: StoreDetailsPage(
            storeId: 'store_123',
            storeData: const {'name': 'سوبرماركت النور', 'deliveryFee': 2500},
            controller: controller,
          ),
        ),
      );

      controller.addToCart(
        StoreCartItemEntity(
          productId: 'prod_1',
          name: 'عصير برتقال',
          price: 1500,
          quantity: 1,
        ),
      );
      await tester.pumpAndSettle();

      // Trigger checkout directly via controller
      final result = await controller.placeOrder(
        customerName: 'أحمد العراقي',
        customerPhone: '07801234567',
        customerAddress: 'شارع الزهور',
        notes: 'يرجى التوصيل سريعاً',
        usePoints: false,
        useWallet: false,
      );

      expect(result.success, isTrue);
      expect(mockDatasource.orderPlaced, isTrue);
      expect(controller.cartItemCount, 0);
    });

    testWidgets('7. Admin tools are visible when user has admin role', (tester) async {
      final adminController = StoreDetailsController(
        storeId: 'store_123',
        initialStoreData: const {'name': 'سوبرماركت النور', 'ownerId': 'owner_123'},
        repository: repository,
      );

      await adminController.initialize(userId: 'owner_123');

      await tester.pumpWidget(
        buildTestablePage(
          child: StoreDetailsPage(
            storeId: 'store_123',
            storeData: const {'name': 'سوبرماركت النور', 'ownerId': 'owner_123'},
            controller: adminController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(adminController.hasAdminAccess, isTrue);
      expect(find.byTooltip('لوحة التحكم'), findsOneWidget);
      expect(find.byTooltip('إضافة منتج'), findsOneWidget);
      expect(find.byTooltip('إضافة إعلان'), findsOneWidget);

      adminController.dispose();
    });

    testWidgets('8. StoreOrderSuccessDialog renders with WhatsApp and My Orders buttons', (tester) async {
      await tester.pumpWidget(
        buildTestablePage(
          child: Scaffold(
            body: StoreOrderSuccessDialog(
              orderId: 'ORD-9876543',
              storeName: 'سوبرماركت النور',
              onWhatsAppTap: () {},
              onMyOrdersTap: () {},
              onBackToStoreTap: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('تم إرسال طلبك بنجاح!'), findsOneWidget);
      expect(find.text('رقم الطلب: #ORD-9876543'), findsOneWidget);
      expect(find.text('تأكيد عبر واتساب'), findsOneWidget);
      expect(find.text('متابعة في طلباتي'), findsOneWidget);
    });
  });
}
