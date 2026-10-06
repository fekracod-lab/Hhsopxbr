import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/stores/application/store_details_controller.dart';
import 'package:dalal_alqaim/features/stores/data/repositories/store_details_repository.dart';
import 'package:dalal_alqaim/features/stores/data/datasources/store_details_remote_datasource.dart';
import 'package:dalal_alqaim/features/stores/domain/entities/store_cart_item_entity.dart';
import 'package:dalal_alqaim/features/stores/domain/entities/store_checkout_models.dart';

class _FakeStoreDetailsRemoteDatasource extends StoreDetailsRemoteDatasource {
  final StreamController<List<Map<String, dynamic>>> productsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> categoriesController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> bannersController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  Map<String, dynamic>? fakeStoreData;
  Map<String, dynamic>? fakeUserData;

  bool placeOrderCalled = false;
  int placeOrderCallCount = 0;

  @override
  Stream<List<Map<String, dynamic>>> watchProducts(String storeId) =>
      productsController.stream;

  @override
  Stream<List<Map<String, dynamic>>> watchCategories(String storeId) =>
      categoriesController.stream;

  @override
  Stream<List<Map<String, dynamic>>> watchBanners(String storeId) =>
      bannersController.stream;

  @override
  Future<Map<String, dynamic>?> getStore(String storeId) async => fakeStoreData;

  @override
  Future<Map<String, dynamic>?> getUserProfile(String userId) async => fakeUserData;

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
    required StoreCheckoutSummaryEntity summary,
  }) async {
    placeOrderCalled = true;
    placeOrderCallCount++;
    // Simulate slight async delay to test concurrency locks
    await Future.delayed(const Duration(milliseconds: 20));
    return true;
  }

  void dispose() {
    productsController.close();
    categoriesController.close();
    bannersController.close();
  }
}

void main() {
  group('StoreDetailsController — State & Cart Tests', () {
    late _FakeStoreDetailsRemoteDatasource fakeDatasource;
    late StoreDetailsRepository repository;
    late StoreDetailsController controller;

    setUp(() {
      fakeDatasource = _FakeStoreDetailsRemoteDatasource();
      fakeDatasource.fakeStoreData = {
        'id': 'store_ctrl_1',
        'name': 'متجر النور',
        'ownerId': 'owner_1',
        'deliveryFee': 1500.0,
      };
      fakeDatasource.fakeUserData = {
        'id': 'user_ctrl_1',
        'points': 500,
        'balance': 30000.0,
        'name': 'كرار علي',
        'phone': '07801234567',
        'address': 'بغداد - الزعفرانية',
      };

      repository = StoreDetailsRepository(remoteDatasource: fakeDatasource);
      controller = StoreDetailsController(
        storeId: 'store_ctrl_1',
        initialStoreData: {'deliveryFee': 1500.0, 'name': 'متجر النور'},
        repository: repository,
      );
    });

    tearDown(() {
      controller.dispose();
      fakeDatasource.dispose();
    });

    test('1. initialize fetches store and user profile, and subscribes to streams', () async {
      await controller.initialize(userId: 'user_ctrl_1');

      expect(controller.isInitialized, isTrue);
      expect(controller.isLoading, isFalse);
      expect(controller.store?.name, equals('متجر النور'));
      expect(controller.userPoints, equals(500));
      expect(controller.userBalance, equals(30000.0));

      fakeDatasource.productsController.add([
        {'id': 'p1', 'name': 'شاي أحمد', 'price': 3000.0, 'category': 'مشروبات'},
        {'id': 'p2', 'name': 'أرز محمود', 'price': 5000.0, 'category': 'حبوب'},
      ]);
      await Future.delayed(Duration.zero);

      expect(controller.products.length, equals(2));
    });

    test('2. Cart additions, increments, decrements, and removals update cart subtotal', () {
      final item1 = StoreCartItemEntity(productId: 'p1', name: 'شاي', price: 3000.0, quantity: 1);
      final item2 = StoreCartItemEntity(productId: 'p2', name: 'أرز', price: 5000.0, quantity: 2);

      controller.addToCart(item1);
      controller.addToCart(item2);

      expect(controller.cartItemCount, equals(3)); // 1 + 2
      expect(controller.cartSubtotal, equals(13000.0)); // 3000*1 + 5000*2

      // Increment p1
      controller.incrementCartItem('p1');
      expect(controller.cartSubtotal, equals(16000.0));

      // Decrement p2
      controller.decrementCartItem('p2');
      expect(controller.cartSubtotal, equals(11000.0));

      // Remove p1
      controller.removeFromCart('p1');
      expect(controller.cartItems.length, equals(1));
      expect(controller.cartSubtotal, equals(5000.0));

      // Clear
      controller.clearCart();
      expect(controller.cartItems.isEmpty, isTrue);
      expect(controller.cartSubtotal, equals(0.0));
    });

    test('3. Filtering products by category and search query filters filteredProducts list', () async {
      await controller.initialize(userId: 'user_ctrl_1');

      fakeDatasource.productsController.add([
        {'id': 'p1', 'name': 'شاي أحمد كلاسيك', 'price': 3000.0, 'category': 'مشروبات'},
        {'id': 'p2', 'name': 'قهوة تركية', 'price': 4000.0, 'category': 'مشروبات'},
        {'id': 'p3', 'name': 'أرز بسمتي', 'price': 5000.0, 'category': 'حبوب'},
      ]);
      await Future.delayed(Duration.zero);

      expect(controller.filteredProducts.length, equals(3));

      // Category filter
      controller.setSelectedCategory('مشروبات');
      expect(controller.filteredProducts.length, equals(2));

      // Search filter
      controller.setSearchQuery('تركي');
      expect(controller.filteredProducts.length, equals(1));
      expect(controller.filteredProducts.first.name, equals('قهوة تركية'));
    });

    test('4. Points and Wallet payment settings update checkoutSummary correctly', () async {
      await controller.initialize(userId: 'user_ctrl_1');

      controller.addToCart(
        StoreCartItemEntity(productId: 'p1', name: 'زيت', price: 10000.0, quantity: 2), // 20000
      );

      // Default: Cash, No Points
      var summary = controller.checkoutSummary;
      expect(summary.subtotal, equals(20000.0));
      expect(summary.deliveryFee, equals(1500.0));
      expect(summary.finalTotal, equals(21500.0));

      // Enable Points (User has 500 pts = 5000 IQD)
      controller.setUsePoints(true);
      summary = controller.checkoutSummary;
      expect(summary.pointsDiscount, equals(5000.0));
      expect(summary.finalTotal, equals(16500.0)); // 20000 + 1500 - 5000

      // Enable Wallet Payment (5% discount on remaining subtotal = 15000 * 0.05 = 750)
      controller.setPaymentMethod(StorePaymentMethod.wallet);
      summary = controller.checkoutSummary;
      expect(summary.walletDiscount, equals(750.0));
      expect(summary.finalTotal, equals(15750.0)); // 20000 + 1500 - 5000 - 750
      expect(summary.canPayWithWallet, isTrue); // User balance is 30000
    });

    test('5. Successful checkout clears cart, resets points, and delegates to repository', () async {
      await controller.initialize(userId: 'user_ctrl_1');

      controller.addToCart(
        StoreCartItemEntity(productId: 'p1', name: 'شاي', price: 3000.0, quantity: 2),
      );

      final result = await controller.checkout(
        userId: 'user_ctrl_1',
        customerName: 'كرار علي',
        customerPhone: '07801234567',
        address: 'بغداد - الزعفرانية',
        notes: 'ملاحظة خاصة',
      );

      expect(result.isValid, isTrue);
      expect(fakeDatasource.placeOrderCalled, isTrue);
      expect(controller.cartItems.isEmpty, isTrue);
      expect(controller.isCheckoutProcessing, isFalse);
    });

    test('6. Double-checkout protection blocks concurrent checkout requests', () async {
      await controller.initialize(userId: 'user_ctrl_1');

      controller.addToCart(
        StoreCartItemEntity(productId: 'p1', name: 'شاي', price: 3000.0, quantity: 2),
      );

      // Launch two concurrent checkout operations
      final future1 = controller.checkout(
        userId: 'user_ctrl_1',
        customerName: 'كرار علي',
        customerPhone: '07801234567',
        address: 'بغداد',
        notes: '',
      );

      final future2 = controller.checkout(
        userId: 'user_ctrl_1',
        customerName: 'كرار علي',
        customerPhone: '07801234567',
        address: 'بغداد',
        notes: '',
      );

      final results = await Future.wait([future1, future2]);

      expect(results[0].isValid, isTrue);
      expect(results[1].isValid, isFalse);
      expect(results[1].errorCode, equals('CHECKOUT_ALREADY_IN_PROGRESS'));
      expect(fakeDatasource.placeOrderCallCount, equals(1));
    });

    test('7. Checkout rejects empty cart and insufficient wallet balance cleanly', () async {
      await controller.initialize(userId: 'user_ctrl_1');

      // Empty cart
      final emptyRes = await controller.checkout(
        userId: 'user_ctrl_1',
        customerName: 'كرار',
        customerPhone: '0780',
        address: 'بغداد',
        notes: '',
      );
      expect(emptyRes.isValid, isFalse);
      expect(emptyRes.errorCode, equals('EMPTY_CART'));

      // Insufficient wallet
      controller.addToCart(
        StoreCartItemEntity(productId: 'p1', name: 'جهاز غالي', price: 50000.0, quantity: 1),
      );
      controller.setPaymentMethod(StorePaymentMethod.wallet); // Balance is 30000

      final walletRes = await controller.checkout(
        userId: 'user_ctrl_1',
        customerName: 'كرار',
        customerPhone: '0780',
        address: 'بغداد',
        notes: '',
      );
      expect(walletRes.isValid, isFalse);
      expect(walletRes.errorCode, equals('INSUFFICIENT_WALLET_BALANCE'));
    });

    test('8. Safe disposal cancels streams and prevents stale notifications', () async {
      await controller.initialize(userId: 'user_ctrl_1');
      controller.dispose();

      expect(controller.isDisposed, isTrue);
      // Adding events after dispose should not throw or notify listeners
      fakeDatasource.productsController.add([]);
      await Future.delayed(Duration.zero);
    });
  });
}
