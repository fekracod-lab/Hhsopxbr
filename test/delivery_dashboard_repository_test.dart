// 🧪 اختبارات مستودع بيانات لوحة تحكم المندوب (Delivery Dashboard Repository Tests)
// Unit & Defensive Mapping Tests — Pure Flutter Test (No Live Emulator Required)

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/features/delivery/domain/entities/delivery_dashboard_models.dart';
import 'package:dalal_alqaim/features/delivery/data/repositories/delivery_dashboard_repository.dart';
import 'package:dalal_alqaim/features/delivery/data/datasources/delivery_dashboard_remote_datasource.dart';

void main() {
  group('Delivery Dashboard Repository — Defensive Mapping Tests', () {
    test('1. mapMersalDocToEntity maps full valid document accurately', () {
      final docData = {
        'storeName': 'صيدلية النقاء',
        'dropoffAddress': 'حي الجماهير - شارع 14',
        'price': '3500',
        'status': 'pending',
        'estimatedCost': 15000,
        'userId': 'usr_123',
        'userName': 'أحمد علي',
        'userPhone': '07701234567',
        'driverId': 'drv_99',
        'driverName': 'سيف الدين',
        'createdAt': Timestamp.fromDate(DateTime(2026, 8, 27, 10, 0)),
        'acceptedAt': Timestamp.fromDate(DateTime(2026, 8, 27, 10, 5)),
        'completedAt': Timestamp.fromDate(DateTime(2026, 8, 27, 10, 30)),
      };

      final entity = DeliveryDashboardRepository.mapMersalDocToEntity(docData, 'req_001');

      expect(entity.id, 'req_001');
      expect(entity.source, DeliveryOrderSource.mersal);
      expect(entity.status, DeliveryOrderStatus.pending);
      expect(entity.sourceName, 'صيدلية النقاء');
      expect(entity.dropoffName, 'حي الجماهير - شارع 14');
      expect(entity.deliveryFee, 3500.0);
      expect(entity.isCustomPrice, isFalse);
      expect(entity.orderTotal, 15000.0);
      expect(entity.customerId, 'usr_123');
      expect(entity.customerName, 'أحمد علي');
      expect(entity.customerPhone, '07701234567');
      expect(entity.driverId, 'drv_99');
      expect(entity.driverName, 'سيف الدين');
      expect(entity.createdAt, equals(DateTime(2026, 8, 27, 10, 0)));
      expect(entity.acceptedAt, equals(DateTime(2026, 8, 27, 10, 5)));
      expect(entity.completedAt, equals(DateTime(2026, 8, 27, 10, 30)));
    });

    test('2. mapMersalDocToEntity flags isCustomPrice true when price is missing or zero', () {
      final docData = {
        'requestDescription': 'شراء مواد غذائية',
        'userAddress': 'شارع الكورنيش',
        'price': '0',
        'status': 'pending',
      };

      final entity = DeliveryDashboardRepository.mapMersalDocToEntity(docData, 'req_custom');

      expect(entity.id, 'req_custom');
      expect(entity.deliveryFee, 0.0);
      expect(entity.isCustomPrice, isTrue);
      expect(entity.sourceName, 'شراء مواد غذائية');
      expect(entity.dropoffName, 'شارع الكورنيش');
    });

    test('3. mapFoodDocToEntity maps restaurant orders with defensive fallbacks', () {
      final docData = {
        'restaurantName': 'شاورما على كيفك',
        'userAddress': 'حي المعلمين',
        'deliveryFee': 2500,
        'total': 18000,
        'status': 'ready',
        'customerId': 'cust_55',
        'customerName': 'عمر القائمي',
        'customerPhone': '07809988776',
        'createdAt': '2026-08-27T12:00:00Z',
      };

      final entity = DeliveryDashboardRepository.mapFoodDocToEntity(docData, 'food_001');

      expect(entity.id, 'food_001');
      expect(entity.source, DeliveryOrderSource.food);
      expect(entity.status, DeliveryOrderStatus.ready);
      expect(entity.sourceName, 'شاورما على كيفك');
      expect(entity.dropoffName, 'حي المعلمين');
      expect(entity.deliveryFee, 2500.0);
      expect(entity.orderTotal, 18000.0);
      expect(entity.customerId, 'cust_55');
      expect(entity.customerName, 'عمر القائمي');
      expect(entity.createdAt, equals(DateTime.parse('2026-08-27T12:00:00Z')));
    });

    test('4. mapStoreDocToEntity maps store orders and preserves storeId', () {
      final docData = {
        'storeName': 'ماركت السعادة',
        'deliveryAddress': 'حي السكك',
        'deliveryFee': 3000.0,
        'total': 45000.0,
        'status': 'delivering',
        'driverId': 'drv_1',
        'driverName': 'حسن',
      };

      final entity = DeliveryDashboardRepository.mapStoreDocToEntity(
        docData,
        'store_ord_99',
        storeId: 'store_al_saada',
      );

      expect(entity.id, 'store_ord_99');
      expect(entity.source, DeliveryOrderSource.store);
      expect(entity.status, DeliveryOrderStatus.delivering);
      expect(entity.sourceName, 'ماركت السعادة');
      expect(entity.dropoffName, 'حي السكك');
      expect(entity.deliveryFee, 3000.0);
      expect(entity.orderTotal, 45000.0);
      expect(entity.rawData['storeId'], 'store_al_saada');
    });

    test('5. Defensive null/empty document handling produces safe entities without crashing', () {
      final emptyMap = <String, dynamic>{};

      final mersalEntity = DeliveryDashboardRepository.mapMersalDocToEntity(emptyMap, 'm_empty');
      expect(mersalEntity.id, 'm_empty');
      expect(mersalEntity.source, DeliveryOrderSource.mersal);
      expect(mersalEntity.status, DeliveryOrderStatus.unknown);
      expect(mersalEntity.deliveryFee, 0.0);
      expect(mersalEntity.sourceName, 'طلب شراء / أمانة');

      final foodEntity = DeliveryDashboardRepository.mapFoodDocToEntity(emptyMap, 'f_empty');
      expect(foodEntity.id, 'f_empty');
      expect(foodEntity.source, DeliveryOrderSource.food);
      expect(foodEntity.status, DeliveryOrderStatus.unknown);
      expect(foodEntity.deliveryFee, 0.0);
      expect(foodEntity.sourceName, 'المطعم');

      final storeEntity = DeliveryDashboardRepository.mapStoreDocToEntity(emptyMap, 's_empty');
      expect(storeEntity.id, 's_empty');
      expect(storeEntity.source, DeliveryOrderSource.store);
      expect(storeEntity.status, DeliveryOrderStatus.unknown);
      expect(storeEntity.deliveryFee, 0.0);
      expect(storeEntity.sourceName, 'المتجر');
    });

    test('6. Numeric parsing handles string prices with non-numeric characters', () {
      final data = {
        'price': ' 4,500 د.ع ',
        'status': 'accepted',
      };
      final entity = DeliveryDashboardRepository.mapMersalDocToEntity(data, 'req_cleaned');
      expect(entity.deliveryFee, 4500.0);
    });

    test('7. Timestamp parsing handles int epoch milliseconds safely', () {
      final epochMs = DateTime(2026, 8, 27, 8, 0).millisecondsSinceEpoch;
      final data = {
        'createdAt': epochMs,
        'status': 'pending',
      };
      final entity = DeliveryDashboardRepository.mapFoodDocToEntity(data, 'f_epoch');
      expect(entity.createdAt, equals(DateTime(2026, 8, 27, 8, 0)));
    });
  });

  group('Delivery Dashboard Repository — Stream & Availability Integration Tests', () {
    late FakeDeliveryDashboardRemoteDatasource fakeDatasource;
    late DeliveryDashboardRepository repository;

    setUp(() {
      fakeDatasource = FakeDeliveryDashboardRemoteDatasource();
      repository = DeliveryDashboardRepository(datasource: fakeDatasource);
    });

    test('8. setDriverAvailability forwards correct string status to datasource', () async {
      await repository.setDriverAvailability(
        driverId: 'drv_test_1',
        availabilityState: DriverAvailabilityState.online,
      );

      expect(fakeDatasource.lastUpdatedDriverId, 'drv_test_1');
      expect(fakeDatasource.lastUpdatedStatus, 'online');

      await repository.setDriverAvailability(
        driverId: 'drv_test_1',
        availabilityState: DriverAvailabilityState.offline,
      );

      expect(fakeDatasource.lastUpdatedStatus, 'offline');
    });

    test('9. acceptMersalOrder delegates atomically to datasource', () async {
      final success = await repository.acceptMersalOrder(
        requestId: 'req_123',
        driverId: 'drv_77',
        driverData: {'name': 'كابتن أحمد'},
        agreedPrice: '4000',
      );

      expect(success, isTrue);
      expect(fakeDatasource.lastAcceptedMersalId, 'req_123');
      expect(fakeDatasource.lastAcceptedMersalPrice, '4000');
    });

    test('10. acceptFoodOrder delegates atomically to datasource', () async {
      final success = await repository.acceptFoodOrder(
        orderId: 'food_ord_55',
        driverId: 'drv_88',
        driverData: {'name': 'كابتن محمود'},
      );

      expect(success, isTrue);
      expect(fakeDatasource.lastAcceptedFoodId, 'food_ord_55');
    });

    test('11. acceptStoreOrder delegates atomically to datasource with storeId', () async {
      final success = await repository.acceptStoreOrder(
        storeId: 'store_999',
        orderId: 'store_ord_111',
        driverId: 'drv_44',
        driverData: {'name': 'كابتن علي'},
      );

      expect(success, isTrue);
      expect(fakeDatasource.lastAcceptedStoreId, 'store_999');
      expect(fakeDatasource.lastAcceptedStoreOrderId, 'store_ord_111');
    });

    test('12. mapFoodDocToEntity handles missing timestamps and null driver gracefully', () {
      final docData = {
        'restaurantName': 'مطعم البركة',
        'status': 'pending',
        'deliveryFee': null,
      };

      final entity = DeliveryDashboardRepository.mapFoodDocToEntity(docData, 'food_null_fee');
      expect(entity.deliveryFee, 0.0);
      expect(entity.driverId, isEmpty);
      expect(entity.createdAt, isNull);
      expect(entity.acceptedAt, isNull);
      expect(entity.completedAt, isNull);
    });

    test('13. mapStoreDocToEntity extracts storeId from path segments correctly', () {
      final docData = {
        'storeName': 'سوق الخضار',
        'status': 'ready',
      };

      final entity = DeliveryDashboardRepository.mapStoreDocToEntity(
        docData,
        'store_ord_5',
        storeId: 'store_central',
      );

      expect(entity.rawData['storeId'], 'store_central');
      expect(entity.source, DeliveryOrderSource.store);
    });

    test('14. mapMersalDocToEntity parses various status strings into domain enum', () {
      expect(DeliveryDashboardRepository.mapMersalDocToEntity({'status': 'pending'}, '1').status, DeliveryOrderStatus.pending);
      expect(DeliveryDashboardRepository.mapMersalDocToEntity({'status': 'accepted'}, '2').status, DeliveryOrderStatus.accepted);
      expect(DeliveryDashboardRepository.mapMersalDocToEntity({'status': 'on_the_way'}, '3').status, DeliveryOrderStatus.delivering);
      expect(DeliveryDashboardRepository.mapMersalDocToEntity({'status': 'delivered'}, '4').status, DeliveryOrderStatus.completed);
      expect(DeliveryDashboardRepository.mapMersalDocToEntity({'status': 'cancelled'}, '5').status, DeliveryOrderStatus.cancelled);
      expect(DeliveryDashboardRepository.mapMersalDocToEntity({'status': 'invalid_xyz'}, '6').status, DeliveryOrderStatus.unknown);
    });

    test('15. mapFoodDocToEntity parses various status strings into domain enum', () {
      expect(DeliveryDashboardRepository.mapFoodDocToEntity({'status': 'ready'}, '1').status, DeliveryOrderStatus.ready);
      expect(DeliveryDashboardRepository.mapFoodDocToEntity({'status': 'delivering'}, '2').status, DeliveryOrderStatus.delivering);
      expect(DeliveryDashboardRepository.mapFoodDocToEntity({'status': 'completed'}, '3').status, DeliveryOrderStatus.completed);
      expect(DeliveryDashboardRepository.mapFoodDocToEntity({'status': 'delivered'}, '4').status, DeliveryOrderStatus.completed);
      expect(DeliveryDashboardRepository.mapFoodDocToEntity({'status': 'cancelled'}, '5').status, DeliveryOrderStatus.cancelled);
      expect(DeliveryDashboardRepository.mapFoodDocToEntity({'status': null}, '6').status, DeliveryOrderStatus.unknown);
    });

    test('16. mapStoreDocToEntity parses various status strings into domain enum', () {
      expect(DeliveryDashboardRepository.mapStoreDocToEntity({'status': 'ready'}, '1').status, DeliveryOrderStatus.ready);
      expect(DeliveryDashboardRepository.mapStoreDocToEntity({'status': 'delivering'}, '2').status, DeliveryOrderStatus.delivering);
      expect(DeliveryDashboardRepository.mapStoreDocToEntity({'status': 'picked_up'}, '3').status, DeliveryOrderStatus.delivering);
      expect(DeliveryDashboardRepository.mapStoreDocToEntity({'status': 'completed'}, '4').status, DeliveryOrderStatus.completed);
    });

    test('17. Repository cleanly handles negative and zero numbers in financial fields', () {
      final data = {
        'deliveryFee': -500,
        'total': -1000,
        'estimatedCost': -2000,
      };

      final foodEntity = DeliveryDashboardRepository.mapFoodDocToEntity(data, 'f_neg');
      expect(foodEntity.deliveryFee, 0.0);
      expect(foodEntity.orderTotal, 0.0);

      final mersalEntity = DeliveryDashboardRepository.mapMersalDocToEntity(data, 'm_neg');
      expect(mersalEntity.deliveryFee, 0.0);
      expect(mersalEntity.orderTotal, 0.0);
    });

    test('18. Repository rawData holds complete original document for lossless fallback', () {
      final original = {
        'customFieldA': 'valueA',
        'customFieldB': 12345,
        'status': 'pending',
      };

      final entity = DeliveryDashboardRepository.mapFoodDocToEntity(original, 'raw_test');
      expect(entity.rawData['customFieldA'], 'valueA');
      expect(entity.rawData['customFieldB'], 12345);
    });

    test('19. Repository maps customer and driver contact info correctly across all sources', () {
      final data = {
        'customerName': 'سارة أحمد',
        'customerPhone': '07712345678',
        'driverName': 'كابتن حيدر',
        'driverPhone': '07812345678',
      };

      final food = DeliveryDashboardRepository.mapFoodDocToEntity(data, 'id1');
      expect(food.customerName, 'سارة أحمد');
      expect(food.customerPhone, '07712345678');
      expect(food.driverName, 'كابتن حيدر');

      final store = DeliveryDashboardRepository.mapStoreDocToEntity(data, 'id2');
      expect(store.customerName, 'سارة أحمد');
      expect(store.customerPhone, '07712345678');
      expect(store.driverName, 'كابتن حيدر');
    });

    test('20. Repository fallback for customerName uses userName if present', () {
      final data = {
        'userName': 'مصطفى كمال',
        'userPhone': '07501122334',
      };

      final mersal = DeliveryDashboardRepository.mapMersalDocToEntity(data, 'id3');
      expect(mersal.customerName, 'مصطفى كمال');
      expect(mersal.customerPhone, '07501122334');

      final food = DeliveryDashboardRepository.mapFoodDocToEntity(data, 'id4');
      expect(food.customerName, 'مصطفى كمال');
      expect(food.customerPhone, '07501122334');
    });
  });
}

/// 🧪 مزود بيانات اختباري محلي يحاكي سلوك DataSource دون الحاجة لمحاكي Firebase
class FakeDeliveryDashboardRemoteDatasource extends DeliveryDashboardRemoteDatasource {
  String? lastUpdatedDriverId;
  String? lastUpdatedStatus;

  String? lastAcceptedMersalId;
  String? lastAcceptedMersalPrice;

  String? lastAcceptedFoodId;

  String? lastAcceptedStoreId;
  String? lastAcceptedStoreOrderId;

  @override
  Future<void> setDriverAvailability({
    required String driverId,
    required String status,
  }) async {
    lastUpdatedDriverId = driverId;
    lastUpdatedStatus = status;
  }

  @override
  Future<bool> acceptMersalRequestAtomic({
    required String requestId,
    required String driverId,
    required Map<String, dynamic> driverData,
    required String agreedPrice,
  }) async {
    lastAcceptedMersalId = requestId;
    lastAcceptedMersalPrice = agreedPrice;
    return true;
  }

  @override
  Future<bool> acceptFoodOrderAtomic({
    required String orderId,
    required String driverId,
    required Map<String, dynamic> driverData,
  }) async {
    lastAcceptedFoodId = orderId;
    return true;
  }

  @override
  Future<bool> acceptStoreOrderAtomic({
    required String storeId,
    required String orderId,
    required String driverId,
    required Map<String, dynamic> driverData,
  }) async {
    lastAcceptedStoreId = storeId;
    lastAcceptedStoreOrderId = orderId;
    return true;
  }
}
