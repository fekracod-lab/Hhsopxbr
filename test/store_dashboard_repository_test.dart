import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/stores/data/datasources/store_remote_datasource.dart';
import 'package:dalal_alqaim/features/stores/data/repositories/store_repository.dart';
import 'package:dalal_alqaim/features/stores/domain/entities/store_dashboard_models.dart';

class FakeStoreRemoteDatasource extends StoreRemoteDatasource {
  final StreamController<List<Map<String, dynamic>>> pendingOrdersStream =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> allOrdersStream =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> ordersStream =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> productsStream =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> categoriesStream =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> bannersStream =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<Map<String, dynamic>?> storeStream =
      StreamController<Map<String, dynamic>?>.broadcast();

  bool migrateCalled = false;
  bool markOrderReadCalled = false;
  String? lastReadOrderId;
  bool updateOrderStatusCalled = false;
  String? lastUpdatedStatus;
  bool createProductCalled = false;
  Map<String, dynamic>? lastProductData;
  bool updateProductCalled = false;
  bool deleteProductCalled = false;
  bool createCategoryCalled = false;
  String? lastCategoryName;
  bool deleteCategoryCalled = false;
  bool createBannerCalled = false;
  bool deleteBannerCalled = false;
  bool updateStoreProfileCalled = false;
  Map<String, dynamic>? lastProfileData;
  bool transferOwnershipCalled = false;
  String? lastTargetEmail;
  bool transferOwnershipResult = true;
  Map<String, dynamic>? stubStoreData;

  @override
  Future<void> migrateOldData(String storeId) async {
    migrateCalled = true;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchPendingOrders(String storeId) =>
      pendingOrdersStream.stream;

  @override
  Stream<List<Map<String, dynamic>>> watchAllOrders(String storeId) =>
      allOrdersStream.stream;

  @override
  Stream<List<Map<String, dynamic>>> watchOrders(String storeId) =>
      ordersStream.stream;

  @override
  Future<void> markOrderAsRead({
    required String storeId,
    required String orderId,
  }) async {
    markOrderReadCalled = true;
    lastReadOrderId = orderId;
  }

  @override
  Future<void> updateOrderStatus({
    required String storeId,
    required String orderId,
    required String nextStatus,
  }) async {
    updateOrderStatusCalled = true;
    lastUpdatedStatus = nextStatus;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchProducts(String storeId) =>
      productsStream.stream;

  @override
  Future<void> createProduct({
    required String storeId,
    required Map<String, dynamic> productData,
  }) async {
    createProductCalled = true;
    lastProductData = productData;
  }

  @override
  Future<void> updateProduct({
    required String storeId,
    required String productId,
    required Map<String, dynamic> productData,
  }) async {
    updateProductCalled = true;
    lastProductData = productData;
  }

  @override
  Future<void> deleteProduct({
    required String storeId,
    required String productId,
  }) async {
    deleteProductCalled = true;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchCategories(String storeId) =>
      categoriesStream.stream;

  @override
  Future<void> createCategory({
    required String storeId,
    required String name,
    int iconCode = 0xe148,
    int colorValue = 0xFFF5F5F5,
  }) async {
    createCategoryCalled = true;
    lastCategoryName = name;
  }

  @override
  Future<void> deleteCategory({
    required String storeId,
    required String categoryId,
  }) async {
    deleteCategoryCalled = true;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchBanners(String storeId) =>
      bannersStream.stream;

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
  Future<Map<String, dynamic>?> getStoreById(String storeId) async => stubStoreData;

  @override
  Stream<Map<String, dynamic>?> watchStore(String storeId) => storeStream.stream;

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
    lastProfileData = {
      'name': name,
      'logoUrl': logoUrl,
      'coverUrl': coverUrl,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }

  @override
  Future<bool> transferStoreOwnership({
    required String storeId,
    required String targetEmail,
  }) async {
    transferOwnershipCalled = true;
    lastTargetEmail = targetEmail;
    return transferOwnershipResult;
  }

  void dispose() {
    pendingOrdersStream.close();
    allOrdersStream.close();
    ordersStream.close();
    productsStream.close();
    categoriesStream.close();
    bannersStream.close();
    storeStream.close();
  }
}

void main() {
  late FakeStoreRemoteDatasource fakeDatasource;
  late StoreRepository repository;

  setUp(() {
    fakeDatasource = FakeStoreRemoteDatasource();
    repository = StoreRepository(remoteDatasource: fakeDatasource);
  });

  tearDown(() {
    fakeDatasource.dispose();
  });

  group('StoreRepository — Data Mapping & Entity Construction', () {
    test('1. Maps Store Dashboard entity with all fields and timestamps', () async {
      final now = DateTime(2026, 8, 27, 12, 0);
      fakeDatasource.stubStoreData = {
        'id': 's_001',
        'name': 'متجر القائم الذهبي',
        'logoUrl': 'https://example.com/logo.png',
        'coverUrl': 'https://example.com/cover.png',
        'latitude': 33.3152,
        'longitude': 44.3661,
        'address': 'شارع الرشيد',
        'ownerId': 'owner_123',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': now.toIso8601String(),
      };

      final store = await repository.getStoreById('s_001');

      expect(store, isNotNull);
      expect(store!.storeId, equals('s_001'));
      expect(store.name, equals('متجر القائم الذهبي'));
      expect(store.latitude, equals(33.3152));
      expect(store.longitude, equals(44.3661));
      expect(store.ownerId, equals('owner_123'));
      expect(store.createdAt, equals(now));
      expect(store.updatedAt, equals(now));
    });

    test('2. Maps Store Order entity and nested items with defensive fallbacks', () async {
      final streamFuture = repository.watchOrders('s_001').first;

      fakeDatasource.ordersStream.add([
        {
          'id': 'ord_99',
          'status': 'accepted',
          'customerId': 'cust_456',
          'customerName': 'أحمد العراقي',
          'phone': '07700000000',
          'address': 'حي المعلمين',
          'totalPrice': 25000,
          'pointsEarned': 25,
          'pointsUsed': 10,
          'paymentStatus': 'paid_wallet',
          'readByStore': true,
          'items': [
            {
              'id': 'item_1',
              'name': 'رز بسمتي',
              'price': 5000,
              'quantity': 2,
              'imageUrl': 'https://example.com/rice.png',
              'size': 'كبير',
            },
            {
              'itemId': 'item_2',
              'name': 'زيت طعام',
              'price': 15000,
              'quantity': 1,
            },
          ],
        },
      ]);

      final orders = await streamFuture;
      expect(orders.length, equals(1));

      final order = orders.first;
      expect(order.orderId, equals('ord_99'));
      expect(order.status, equals('accepted'));
      expect(order.orderStatus, equals(StoreOrderStatus.accepted));
      expect(order.customerId, equals('cust_456'));
      expect(order.customerName, equals('أحمد العراقي'));
      expect(order.customerPhone, equals('07700000000'));
      expect(order.total, equals(25000.0));
      expect(order.pointsEarned, equals(25));
      expect(order.pointsUsed, equals(10));
      expect(order.isPaidWithWallet, isTrue);
      expect(order.readByStore, isTrue);

      expect(order.items.length, equals(2));
      expect(order.items[0].itemId, equals('item_1'));
      expect(order.items[0].name, equals('رز بسمتي'));
      expect(order.items[0].totalPrice, equals(10000.0));
      expect(order.items[0].size, equals('كبير'));

      expect(order.items[1].itemId, equals('item_2'));
      expect(order.items[1].totalPrice, equals(15000.0));
    });

    test('3. Maps Store Product entity with availability and categories', () async {
      final streamFuture = repository.watchProducts('s_001').first;

      fakeDatasource.productsStream.add([
        {
          'id': 'prod_1',
          'name': 'جبنة بيضاء',
          'price': 2500.0,
          'description': 'جبنة بلدية طازجة',
          'category': 'ألبان',
          'imageUrl': 'https://example.com/cheese.png',
          'isAvailable': true,
        },
        {
          'id': 'prod_2',
          'name': 'منتج غير متوفر',
          'price': 4000,
          'isAvailable': false,
        },
      ]);

      final products = await streamFuture;
      expect(products.length, equals(2));

      expect(products[0].productId, equals('prod_1'));
      expect(products[0].name, equals('جبنة بيضاء'));
      expect(products[0].price, equals(2500.0));
      expect(products[0].category, equals('ألبان'));
      expect(products[0].isAvailable, isTrue);

      expect(products[1].productId, equals('prod_2'));
      expect(products[1].category, equals('عام'));
      expect(products[1].isAvailable, isFalse);
    });

    test('4. Maps Store Category and Banner entities correctly', () async {
      final catFuture = repository.watchCategories('s_001').first;
      final bannerFuture = repository.watchBanners('s_001').first;

      fakeDatasource.categoriesStream.add([
        {
          'id': 'cat_1',
          'name': 'معلبات',
          'iconCode': 0xe148,
          'colorValue': 0xFFEEEEEE,
        },
      ]);

      fakeDatasource.bannersStream.add([
        {
          'id': 'ban_1',
          'title': 'عروض الأسبوع',
          'subtitle': 'خصومات تصل إلى 30%',
          'imageUrl': 'https://example.com/banner.png',
        },
      ]);

      final categories = await catFuture;
      final banners = await bannerFuture;

      expect(categories.length, equals(1));
      expect(categories.first.categoryId, equals('cat_1'));
      expect(categories.first.name, equals('معلبات'));
      expect(categories.first.iconCode, equals(0xe148));

      expect(banners.length, equals(1));
      expect(banners.first.bannerId, equals('ban_1'));
      expect(banners.first.title, equals('عروض الأسبوع'));
      expect(banners.first.subtitle, equals('خصومات تصل إلى 30%'));
      expect(banners.first.imageUrl, equals('https://example.com/banner.png'));
    });
  });

  group('StoreRepository — Delegation & Mutation Contracts', () {
    test('5. Delegates migration and order status updates correctly', () async {
      await repository.migrateOldData('s_001');
      expect(fakeDatasource.migrateCalled, isTrue);

      await repository.markOrderAsRead(storeId: 's_001', orderId: 'ord_123');
      expect(fakeDatasource.markOrderReadCalled, isTrue);
      expect(fakeDatasource.lastReadOrderId, equals('ord_123'));

      await repository.updateOrderStatus(
        storeId: 's_001',
        orderId: 'ord_123',
        nextStatus: 'ready',
      );
      expect(fakeDatasource.updateOrderStatusCalled, isTrue);
      expect(fakeDatasource.lastUpdatedStatus, equals('ready'));
    });

    test('6. Delegates product CRUD operations with sanitized payloads', () async {
      await repository.createProduct(
        storeId: 's_001',
        name: 'عسل طبيعي ',
        price: -100.0, // Should be clamped to 0.0
        description: 'عسل سدر ',
        category: '', // Should fallback to 'عام'
        imageUrl: ' https://example.com/honey.png ',
        isAvailable: true,
      );

      expect(fakeDatasource.createProductCalled, isTrue);
      expect(fakeDatasource.lastProductData?['name'], equals('عسل طبيعي'));
      expect(fakeDatasource.lastProductData?['price'], equals(0.0));
      expect(fakeDatasource.lastProductData?['description'], equals('عسل سدر'));
      expect(fakeDatasource.lastProductData?['category'], equals('عام'));
      expect(fakeDatasource.lastProductData?['imageUrl'], equals('https://example.com/honey.png'));

      await repository.deleteProduct(storeId: 's_001', productId: 'p_99');
      expect(fakeDatasource.deleteProductCalled, isTrue);
    });

    test('7. Delegates category and banner CRUD operations', () async {
      await repository.createCategory(storeId: 's_001', name: 'مجمدات');
      expect(fakeDatasource.createCategoryCalled, isTrue);
      expect(fakeDatasource.lastCategoryName, equals('مجمدات'));

      await repository.deleteCategory(storeId: 's_001', categoryId: 'c_99');
      expect(fakeDatasource.deleteCategoryCalled, isTrue);

      await repository.createBanner(
        storeId: 's_001',
        title: 'تخفيضات العيد',
        imageUrl: 'https://example.com/eid.png',
      );
      expect(fakeDatasource.createBannerCalled, isTrue);

      await repository.deleteBanner(storeId: 's_001', bannerId: 'b_99');
      expect(fakeDatasource.deleteBannerCalled, isTrue);
    });

    test('8. Delegates store profile update and ownership transfer', () async {
      await repository.updateStoreProfile(
        storeId: 's_001',
        name: 'سوبرماركت المدينة',
        latitude: 33.3,
        longitude: 44.4,
        address: 'شارع فلسطين',
      );

      expect(fakeDatasource.updateStoreProfileCalled, isTrue);
      expect(fakeDatasource.lastProfileData?['name'], equals('سوبرماركت المدينة'));
      expect(fakeDatasource.lastProfileData?['latitude'], equals(33.3));
      expect(fakeDatasource.lastProfileData?['address'], equals('شارع فلسطين'));

      final success = await repository.transferStoreOwnership(
        storeId: 's_001',
        targetEmail: 'new_merchant@madar.iq',
      );

      expect(fakeDatasource.transferOwnershipCalled, isTrue);
      expect(fakeDatasource.lastTargetEmail, equals('new_merchant@madar.iq'));
      expect(success, isTrue);
    });
  });
}
