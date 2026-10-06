import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/stores/data/datasources/store_details_remote_datasource.dart';
import 'package:dalal_alqaim/features/stores/data/repositories/store_details_repository.dart';
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
  bool createProductCalled = false;
  bool deleteProductCalled = false;
  bool createCategoryCalled = false;
  bool deleteCategoryCalled = false;
  bool migrateCategoriesCalled = false;
  bool uploadImageCalled = false;

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
    return true;
  }

  @override
  Future<void> createProduct({
    required String storeId,
    required Map<String, dynamic> productData,
  }) async {
    createProductCalled = true;
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
  Future<void> migrateOldCategories(String storeId) async {
    migrateCategoriesCalled = true;
  }

  @override
  Future<String?> uploadImageToCloudinary({
    required String filePath,
    String cloudName = 'dprr2bcq5',
    String uploadPreset = 'madar_app',
  }) async {
    uploadImageCalled = true;
    return 'https://res.cloudinary.com/demo/image/upload/sample.jpg';
  }

  @override
  Future<Map<String, dynamic>?> getCurrentLocationAndAddress() async {
    return {
      'latitude': 33.3152,
      'longitude': 44.3661,
      'address': 'بغداد - الكرادة',
    };
  }

  void dispose() {
    productsController.close();
    categoriesController.close();
    bannersController.close();
  }
}

void main() {
  group('StoreDetailsRepository — Data Layer Unit Tests', () {
    late _FakeStoreDetailsRemoteDatasource fakeDatasource;
    late StoreDetailsRepository repository;

    setUp(() {
      fakeDatasource = _FakeStoreDetailsRemoteDatasource();
      repository = StoreDetailsRepository(remoteDatasource: fakeDatasource);
    });

    tearDown(() {
      fakeDatasource.dispose();
    });

    test('1. watchProducts maps raw map stream to StoreProductEntity list defensively', () async {
      final stream = repository.watchProducts('store_1');

      final expectation = expectLater(
        stream,
        emits([
          predicate<dynamic>((item) {
            return item.productId == 'prod_10' &&
                item.name == 'حليب المراعي 1 لتر' &&
                item.price == 2500.0 &&
                item.category == 'ألبان' &&
                item.isAvailable == true;
          }),
        ]),
      );

      fakeDatasource.productsController.add([
        {
          'id': 'prod_10',
          'name': 'حليب المراعي 1 لتر',
          'price': '2500 د.ع',
          'category': 'ألبان',
          'isAvailable': true,
        },
      ]);

      await expectation;
    });

    test('2. watchCategories maps raw categories map stream accurately', () async {
      final stream = repository.watchCategories('store_1');

      final expectation = expectLater(
        stream,
        emits([
          predicate<dynamic>((item) {
            return item.categoryId == 'cat_1' &&
                item.name == 'مشروبات غازية' &&
                item.iconCode == 0xe148;
          }),
        ]),
      );

      fakeDatasource.categoriesController.add([
        {
          'id': 'cat_1',
          'name': 'مشروبات غازية',
          'iconCode': 0xe148,
          'colorValue': 0xFFEEEEEE,
        },
      ]);

      await expectation;
    });

    test('3. watchBanners maps raw banners map stream accurately', () async {
      final stream = repository.watchBanners('store_1');

      final expectation = expectLater(
        stream,
        emits([
          predicate<dynamic>((item) {
            return item.bannerId == 'ban_1' &&
                item.title == 'خصم الجمعة البيضاء' &&
                item.imageUrl == 'https://example.com/banner.jpg';
          }),
        ]),
      );

      fakeDatasource.bannersController.add([
        {
          'id': 'ban_1',
          'title': 'خصم الجمعة البيضاء',
          'imageUrl': 'https://example.com/banner.jpg',
        },
      ]);

      await expectation;
    });

    test('4. getStore maps raw store map to StoreDashboardEntity accurately', () async {
      fakeDatasource.fakeStoreData = {
        'id': 'store_1',
        'name': 'سوبرماركت البركة',
        'ownerId': 'user_owner_99',
        'phone': '07701234567',
        'address': 'بغداد - المنصور',
        'deliveryFee': 2000.0,
      };

      final store = await repository.getStore('store_1');
      expect(store, isNotNull);
      expect(store!.name, equals('سوبرماركت البركة'));
      expect(store.ownerId, equals('user_owner_99'));
      expect(store.address, equals('بغداد - المنصور'));
    });

    test('5. getUserProfile returns user raw data map accurately', () async {
      fakeDatasource.fakeUserData = {
        'id': 'user_123',
        'points': 450,
        'balance': 35000.0,
        'address': 'بغداد - المنصور',
      };

      final profile = await repository.getUserProfile('user_123');
      expect(profile, isNotNull);
      expect(profile!['points'], equals(450));
      expect(profile['balance'], equals(35000.0));
      expect(profile['address'], equals('بغداد - المنصور'));
    });

    test('6. placeOrderAtomic delegates atomic order placement to datasource', () async {
      const summary = StoreCheckoutSummaryEntity(
        subtotal: 10000.0,
        deliveryFee: 1500.0,
        pointsUsed: 100,
        pointsDiscount: 1000.0,
        walletDiscount: 450.0,
        totalDiscount: 1450.0,
        finalTotal: 10050.0,
        pointsEarned: 10,
        paymentMethod: StorePaymentMethod.wallet,
        paymentStatus: StorePaymentStatus.paidWallet,
        userBalance: 50000.0,
        userPoints: 500,
        canPayWithWallet: true,
      );

      final success = await repository.placeOrderAtomic(
        storeId: 'store_1',
        userId: 'user_1',
        orderId: 'ORD-98765',
        customerName: 'حيدر',
        customerPhone: '07701234567',
        address: 'بغداد',
        notes: 'قرب الجامع',
        storeData: const {'name': 'متجر النور'},
        items: [
          StoreCartItemEntity(productId: 'p1', name: 'شاي', price: 2000.0, quantity: 5),
        ],
        summary: summary,
      );

      expect(success, isTrue);
      expect(fakeDatasource.placeOrderCalled, isTrue);
    });

    test('7. Admin in-UI operations delegate to datasource methods', () async {
      await repository.createProduct(storeId: 's1', productData: {'name': 'زيت'});
      expect(fakeDatasource.createProductCalled, isTrue);

      await repository.deleteProduct(storeId: 's1', productId: 'p1');
      expect(fakeDatasource.deleteProductCalled, isTrue);

      await repository.createCategory(storeId: 's1', name: 'زيوت');
      expect(fakeDatasource.createCategoryCalled, isTrue);

      await repository.deleteCategory(storeId: 's1', categoryId: 'c1');
      expect(fakeDatasource.deleteCategoryCalled, isTrue);

      await repository.migrateOldCategories('s1');
      expect(fakeDatasource.migrateCategoriesCalled, isTrue);
    });

    test('8. Cloudinary and Geolocation service methods delegate cleanly', () async {
      final uploadUrl = await repository.uploadImageToCloudinary(filePath: '/mock/img.jpg');
      expect(fakeDatasource.uploadImageCalled, isTrue);
      expect(uploadUrl, contains('cloudinary.com'));

      final location = await repository.getCurrentLocationAndAddress();
      expect(location, isNotNull);
      expect(location!['address'], equals('بغداد - الكرادة'));
    });
  });
}
