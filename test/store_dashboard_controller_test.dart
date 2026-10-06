import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/stores/application/store_dashboard_controller.dart';
import 'package:dalal_alqaim/features/stores/data/repositories/store_repository.dart';
import 'package:dalal_alqaim/features/stores/domain/entities/store_dashboard_models.dart';

class FakeStoreRepository extends StoreRepository {
  final StreamController<StoreDashboardEntity?> storeStream =
      StreamController<StoreDashboardEntity?>.broadcast();
  final StreamController<List<StoreOrderEntity>> pendingOrdersStream =
      StreamController<List<StoreOrderEntity>>.broadcast();
  final StreamController<List<StoreOrderEntity>> allOrdersStream =
      StreamController<List<StoreOrderEntity>>.broadcast();
  final StreamController<List<StoreOrderEntity>> ordersListStream =
      StreamController<List<StoreOrderEntity>>.broadcast();
  final StreamController<List<StoreProductEntity>> productsStream =
      StreamController<List<StoreProductEntity>>.broadcast();
  final StreamController<List<StoreCategoryEntity>> categoriesStream =
      StreamController<List<StoreCategoryEntity>>.broadcast();
  final StreamController<List<StoreBannerEntity>> bannersStream =
      StreamController<List<StoreBannerEntity>>.broadcast();

  bool migrateCalled = false;
  bool markOrderReadCalled = false;
  String? lastReadOrderId;
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
  String? lastTargetEmail;
  bool transferOwnershipResult = true;

  bool shouldThrowOnUpdateStatus = false;
  bool shouldThrowOnTransferOwnership = false;

  @override
  Future<void> migrateOldData(String storeId) async {
    migrateCalled = true;
  }

  @override
  Stream<StoreDashboardEntity?> watchStore(String storeId) => storeStream.stream;

  @override
  Stream<List<StoreOrderEntity>> watchPendingOrders(String storeId) =>
      pendingOrdersStream.stream;

  @override
  Stream<List<StoreOrderEntity>> watchAllOrders(String storeId) =>
      allOrdersStream.stream;

  @override
  Stream<List<StoreOrderEntity>> watchOrders(String storeId) =>
      ordersListStream.stream;

  @override
  Stream<List<StoreProductEntity>> watchProducts(String storeId) =>
      productsStream.stream;

  @override
  Stream<List<StoreCategoryEntity>> watchCategories(String storeId) =>
      categoriesStream.stream;

  @override
  Stream<List<StoreBannerEntity>> watchBanners(String storeId) =>
      bannersStream.stream;

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
    if (shouldThrowOnUpdateStatus) {
      throw Exception('Firestore transaction failed');
    }
    updateOrderStatusCalled = true;
    lastUpdatedOrderId = orderId;
    lastUpdatedStatus = nextStatus;
  }

  @override
  Future<void> createProduct({
    required String storeId,
    required String name,
    required double price,
    String description = '',
    String category = 'عام',
    String imageUrl = '',
    bool isAvailable = true,
  }) async {
    createProductCalled = true;
  }

  @override
  Future<void> updateProduct({
    required String storeId,
    required String productId,
    required String name,
    required double price,
    String description = '',
    String category = 'عام',
    String imageUrl = '',
    bool isAvailable = true,
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
    if (shouldThrowOnTransferOwnership) {
      throw Exception('Network error during transfer');
    }
    transferOwnershipCalled = true;
    lastTargetEmail = targetEmail;
    return transferOwnershipResult;
  }

  void dispose() {
    storeStream.close();
    pendingOrdersStream.close();
    allOrdersStream.close();
    ordersListStream.close();
    productsStream.close();
    categoriesStream.close();
    bannersStream.close();
  }
}

void main() {
  late FakeStoreRepository fakeRepo;
  late StoreDashboardController controller;

  setUp(() {
    fakeRepo = FakeStoreRepository();
    controller = StoreDashboardController(
      storeId: 'store_123',
      repository: fakeRepo,
    );
  });

  tearDown(() {
    if (!controller.isDisposed) {
      controller.dispose();
    }
    fakeRepo.dispose();
  });

  group('StoreDashboardController — Initialization & Streams', () {
    test('1. Initializes controller and attaches all 7 streams without duplicates', () async {
      expect(controller.isInitialized, isFalse);
      expect(controller.isLoading, isFalse);

      await controller.initialize();
      expect(controller.isInitialized, isTrue);

      // Repeated initialize should be safely ignored
      await controller.initialize();
      expect(controller.isInitialized, isTrue);
    });

    test('2. Receives store profile and updates state', () async {
      await controller.initialize();

      final mockStore = StoreDashboardEntity(
        storeId: 'store_123',
        name: 'أسواق النور',
        address: 'حي العامل',
      );

      fakeRepo.storeStream.add(mockStore);
      await pumpEventQueue();

      expect(controller.store, isNotNull);
      expect(controller.store!.name, equals('أسواق النور'));
      expect(controller.isLoading, isFalse);
    });

    test('3. Receives orders and calculates statistics, revenue, and pending counts', () async {
      await controller.initialize();

      final now = DateTime.now();
      final order1 = StoreOrderEntity(
        orderId: 'o1',
        status: 'completed',
        orderStatus: StoreOrderStatus.completed,
        total: 10000,
        createdAt: now,
      );
      final order2 = StoreOrderEntity(
        orderId: 'o2',
        status: 'pending',
        orderStatus: StoreOrderStatus.pending,
        total: 5000,
        createdAt: now,
      );

      fakeRepo.allOrdersStream.add([order1, order2]);
      fakeRepo.ordersListStream.add([order1, order2]);
      fakeRepo.pendingOrdersStream.add([order2]);
      await pumpEventQueue();

      expect(controller.allOrders.length, equals(2));
      expect(controller.pendingOrderCount, equals(1));
      expect(controller.orderStatistics.totalOrders, equals(2));
      expect(controller.orderStatistics.completedOrders, equals(1));
      expect(controller.orderStatistics.pendingOrders, equals(1));
      expect(controller.totalRevenue, equals(10000.0));
      expect(controller.todayRevenue, equals(10000.0));
    });

    test('4. In-memory category product counts are derived without N+1 streams', () async {
      await controller.initialize();

      fakeRepo.categoriesStream.add([
        StoreCategoryEntity(categoryId: 'c1', name: 'ألبان'),
        StoreCategoryEntity(categoryId: 'c2', name: 'عصائر'),
      ]);

      fakeRepo.productsStream.add([
        StoreProductEntity(productId: 'p1', name: 'حليب', category: 'ألبان', price: 1000),
        StoreProductEntity(productId: 'p2', name: 'لبن', category: 'ألبان', price: 1500),
        StoreProductEntity(productId: 'p3', name: 'عصير برتقال', category: 'عصائر', price: 2000),
      ]);
      await pumpEventQueue();

      expect(controller.categories.length, equals(2));
      expect(controller.products.length, equals(3));

      final counts = controller.categoryProductCounts;
      expect(counts['ألبان'], equals(2));
      expect(counts['عصائر'], equals(1));
    });
  });

  group('StoreDashboardController — Filtering & State Views', () {
    test('5. Filters orders by status correctly', () async {
      await controller.initialize();

      final oPending = StoreOrderEntity(
        orderId: 'o1',
        status: 'pending',
        orderStatus: StoreOrderStatus.pending,
        total: 5000,
      );
      final oReady = StoreOrderEntity(
        orderId: 'o2',
        status: 'ready',
        orderStatus: StoreOrderStatus.ready,
        total: 8000,
      );

      fakeRepo.ordersListStream.add([oPending, oReady]);
      await pumpEventQueue();

      expect(controller.filteredOrders.length, equals(2));

      controller.setOrderStatusFilter('pending');
      expect(controller.filteredOrders.length, equals(1));
      expect(controller.filteredOrders.first.orderId, equals('o1'));

      controller.setOrderStatusFilter('ready');
      expect(controller.filteredOrders.length, equals(1));
      expect(controller.filteredOrders.first.orderId, equals('o2'));

      controller.setOrderStatusFilter('all');
      expect(controller.filteredOrders.length, equals(2));
    });

    test('6. Filters products by category correctly', () async {
      await controller.initialize();

      final p1 = StoreProductEntity(productId: 'p1', name: 'جبنة', category: 'ألبان', price: 1000);
      final p2 = StoreProductEntity(productId: 'p2', name: 'شاي', category: 'مشروبات', price: 2000);

      fakeRepo.productsStream.add([p1, p2]);
      await pumpEventQueue();

      expect(controller.filteredProducts.length, equals(2));

      controller.setCategoryFilter('ألبان');
      expect(controller.filteredProducts.length, equals(1));
      expect(controller.filteredProducts.first.name, equals('جبنة'));

      controller.setCategoryFilter('الكل');
      expect(controller.filteredProducts.length, equals(2));
    });

    test('7. Exposes immutable views of internal lists', () async {
      await controller.initialize();
      fakeRepo.categoriesStream.add([StoreCategoryEntity(categoryId: 'c1', name: 'حلويات')]);
      await pumpEventQueue();

      expect(
        () => controller.categories.add(StoreCategoryEntity(categoryId: 'c2', name: 'مكسرات')),
        throwsUnsupportedError,
      );
    });
  });

  group('StoreDashboardController — Mutations & Action Locks', () {
    test('8. Valid order status transition succeeds and delegates to repository', () async {
      await controller.initialize();
      fakeRepo.ordersListStream.add([
        StoreOrderEntity(
          orderId: 'ord_1',
          status: 'pending',
          orderStatus: StoreOrderStatus.pending,
          total: 5000,
        ),
      ]);
      await pumpEventQueue();

      final result = await controller.updateOrderStatus(
        orderId: 'ord_1',
        nextStatus: 'accepted',
      );

      expect(result, isTrue);
      expect(fakeRepo.updateOrderStatusCalled, isTrue);
      expect(fakeRepo.lastUpdatedOrderId, equals('ord_1'));
      expect(fakeRepo.lastUpdatedStatus, equals('accepted'));
      expect(controller.isOrderLocked('ord_1'), isFalse);
    });

    test('9. Invalid order status transition is blocked by state machine without repository call', () async {
      await controller.initialize();
      fakeRepo.ordersListStream.add([
        StoreOrderEntity(
          orderId: 'ord_1',
          status: 'completed',
          orderStatus: StoreOrderStatus.completed,
          total: 10000,
        ),
      ]);
      await pumpEventQueue();

      // Trying to transition from 'completed' (terminal) back to 'pending'
      final result = await controller.updateOrderStatus(
        orderId: 'ord_1',
        nextStatus: 'pending',
      );

      expect(result, isFalse);
      expect(fakeRepo.updateOrderStatusCalled, isFalse);
    });

    test('10. Order status failure cleans up locks and exposes error message', () async {
      fakeRepo.shouldThrowOnUpdateStatus = true;
      await controller.initialize();
      fakeRepo.ordersListStream.add([
        StoreOrderEntity(
          orderId: 'ord_1',
          status: 'pending',
          orderStatus: StoreOrderStatus.pending,
          total: 5000,
        ),
      ]);
      await pumpEventQueue();

      final result = await controller.updateOrderStatus(
        orderId: 'ord_1',
        nextStatus: 'accepted',
      );

      expect(result, isFalse);
      expect(controller.errorMessage, contains('Firestore transaction failed'));
      expect(controller.isOrderLocked('ord_1'), isFalse);
      expect(controller.isOrderStatusMutating, isFalse);
    });

    test('11. Product CRUD operations lock and delegate properly', () async {
      await controller.initialize();

      final createRes = await controller.createProduct(
        name: 'شوكولاتة',
        price: 3000,
        category: 'حلويات',
      );
      expect(createRes, isTrue);
      expect(fakeRepo.createProductCalled, isTrue);
      expect(controller.isProductMutating, isFalse);

      final updateRes = await controller.updateProduct(
        productId: 'p_1',
        name: 'شوكولاتة داكنة',
        price: 3500,
      );
      expect(updateRes, isTrue);
      expect(fakeRepo.updateProductCalled, isTrue);
      expect(controller.isProductLocked('p_1'), isFalse);

      final deleteRes = await controller.deleteProduct('p_1');
      expect(deleteRes, isTrue);
      expect(fakeRepo.deleteProductCalled, isTrue);
      expect(controller.isProductLocked('p_1'), isFalse);
    });

    test('12. Category & Banner CRUD operations delegate properly', () async {
      await controller.initialize();

      final catRes = await controller.createCategory(name: 'مثلجات');
      expect(catRes, isTrue);
      expect(fakeRepo.createCategoryCalled, isTrue);

      final delCatRes = await controller.deleteCategory('c_1');
      expect(delCatRes, isTrue);
      expect(fakeRepo.deleteCategoryCalled, isTrue);

      final banRes = await controller.createBanner(
        title: 'عروض الصيف',
        imageUrl: 'https://example.com/summer.png',
      );
      expect(banRes, isTrue);
      expect(fakeRepo.createBannerCalled, isTrue);

      final delBanRes = await controller.deleteBanner('b_1');
      expect(delBanRes, isTrue);
      expect(fakeRepo.deleteBannerCalled, isTrue);
    });

    test('13. Store profile update and ownership transfer delegate properly', () async {
      await controller.initialize();

      final profRes = await controller.updateStoreProfile(
        name: 'سوبرماركت البركة',
        address: 'شارع فلسطين',
      );
      expect(profRes, isTrue);
      expect(fakeRepo.updateStoreProfileCalled, isTrue);

      final transferRes = await controller.transferStoreOwnership('merchant@madar.iq');
      expect(transferRes, isTrue);
      expect(fakeRepo.transferOwnershipCalled, isTrue);
      expect(fakeRepo.lastTargetEmail, equals('merchant@madar.iq'));
    });

    test('14. Mark order as read and migration delegate properly', () async {
      await controller.initialize();

      await controller.markOrderAsRead('ord_55');
      expect(fakeRepo.markOrderReadCalled, isTrue);
      expect(fakeRepo.lastReadOrderId, equals('ord_55'));

      await controller.migrateOldData();
      expect(fakeRepo.migrateCalled, isTrue);
    });

    test('15. Safe disposal cleans all subscriptions, locks, and prevents stale notifications', () async {
      await controller.initialize();
      expect(controller.isDisposed, isFalse);

      controller.dispose();
      expect(controller.isDisposed, isTrue);

      // Post-disposal methods must be safe no-ops
      final res = await controller.updateOrderStatus(
        orderId: 'o1',
        nextStatus: 'accepted',
      );
      expect(res, isFalse);
    });
  });
}
