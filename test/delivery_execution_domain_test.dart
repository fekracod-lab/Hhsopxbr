import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/delivery_execution/domain/entities/delivery_execution_models.dart';
import 'package:dalal_alqaim/features/delivery_execution/domain/services/delivery_status_machine.dart';
import 'package:dalal_alqaim/features/delivery_execution/domain/services/delivery_execution_calculator.dart';
import 'package:dalal_alqaim/features/delivery_execution/domain/services/delivery_route_engine.dart';

void main() {
  group('OrderDeliverySource & DeliveryExecutionStatus Enums Tests', () {
    test('OrderDeliverySource keys and fromString normalization', () {
      expect(OrderDeliverySource.restaurant.key, 'food_order');
      expect(OrderDeliverySource.store.key, 'store_order');
      expect(OrderDeliverySource.mersal.key, 'mersal_request');

      expect(OrderDeliverySource.fromString('food'), OrderDeliverySource.restaurant);
      expect(OrderDeliverySource.fromString('restaurant_order'), OrderDeliverySource.restaurant);
      expect(OrderDeliverySource.fromString('store_order'), OrderDeliverySource.store);
      expect(OrderDeliverySource.fromString('market'), OrderDeliverySource.store);
      expect(OrderDeliverySource.fromString('shop'), OrderDeliverySource.store);
      expect(OrderDeliverySource.fromString('mersal'), OrderDeliverySource.mersal);
      expect(OrderDeliverySource.fromString('parcel'), OrderDeliverySource.mersal);
      expect(OrderDeliverySource.fromString('delegate'), OrderDeliverySource.mersal);
      expect(OrderDeliverySource.fromString(null), OrderDeliverySource.restaurant);
      expect(OrderDeliverySource.fromString('unknown_source'), OrderDeliverySource.restaurant);
    });

    test('DeliveryExecutionStatus fromString Arabic & English mapping', () {
      expect(DeliveryExecutionStatus.fromString('pending'), DeliveryExecutionStatus.pending);
      expect(DeliveryExecutionStatus.fromString('accepted'), DeliveryExecutionStatus.accepted);
      expect(DeliveryExecutionStatus.fromString('preparing'), DeliveryExecutionStatus.accepted);
      expect(DeliveryExecutionStatus.fromString('قيد التجهيز'), DeliveryExecutionStatus.accepted);
      expect(DeliveryExecutionStatus.fromString('ready'), DeliveryExecutionStatus.accepted);
      expect(DeliveryExecutionStatus.fromString('جاهز للتوصيل'), DeliveryExecutionStatus.accepted);
      expect(DeliveryExecutionStatus.fromString('heading_to_pickup'), DeliveryExecutionStatus.headingToPickup);
      expect(DeliveryExecutionStatus.fromString('delivering'), DeliveryExecutionStatus.headingToPickup);
      expect(DeliveryExecutionStatus.fromString('جاري التحرك للمحل'), DeliveryExecutionStatus.headingToPickup);
      expect(DeliveryExecutionStatus.fromString('arrived_at_pickup'), DeliveryExecutionStatus.arrivedAtPickup);
      expect(DeliveryExecutionStatus.fromString('وصل للمحل'), DeliveryExecutionStatus.arrivedAtPickup);
      expect(DeliveryExecutionStatus.fromString('picked_up'), DeliveryExecutionStatus.pickedUp);
      expect(DeliveryExecutionStatus.fromString('on_the_way'), DeliveryExecutionStatus.pickedUp);
      expect(DeliveryExecutionStatus.fromString('تم الاستلام'), DeliveryExecutionStatus.pickedUp);
      expect(DeliveryExecutionStatus.fromString('heading_to_customer'), DeliveryExecutionStatus.headingToCustomer);
      expect(DeliveryExecutionStatus.fromString('بالطريق للزبون'), DeliveryExecutionStatus.headingToCustomer);
      expect(DeliveryExecutionStatus.fromString('arrived_at_customer'), DeliveryExecutionStatus.arrivedAtCustomer);
      expect(DeliveryExecutionStatus.fromString('وصل للزبون'), DeliveryExecutionStatus.arrivedAtCustomer);
      expect(DeliveryExecutionStatus.fromString('delivered'), DeliveryExecutionStatus.delivered);
      expect(DeliveryExecutionStatus.fromString('completed'), DeliveryExecutionStatus.delivered);
      expect(DeliveryExecutionStatus.fromString('مكتمل'), DeliveryExecutionStatus.delivered);
      expect(DeliveryExecutionStatus.fromString('تم التسليم'), DeliveryExecutionStatus.delivered);
      expect(DeliveryExecutionStatus.fromString('cancelled'), DeliveryExecutionStatus.cancelled);
      expect(DeliveryExecutionStatus.fromString('rejected'), DeliveryExecutionStatus.cancelled);
      expect(DeliveryExecutionStatus.fromString('ملغي'), DeliveryExecutionStatus.cancelled);
      expect(DeliveryExecutionStatus.fromString(null), DeliveryExecutionStatus.pending);
      expect(DeliveryExecutionStatus.fromString('unknown_status'), DeliveryExecutionStatus.pending);
    });

    test('DeliveryExecutionStatus values match expected Firestore contract strings', () {
      expect(DeliveryExecutionStatus.pending.value, 'pending');
      expect(DeliveryExecutionStatus.accepted.value, 'accepted');
      expect(DeliveryExecutionStatus.headingToPickup.value, 'heading_to_pickup');
      expect(DeliveryExecutionStatus.arrivedAtPickup.value, 'arrived_at_pickup');
      expect(DeliveryExecutionStatus.pickedUp.value, 'picked_up');
      expect(DeliveryExecutionStatus.headingToCustomer.value, 'heading_to_customer');
      expect(DeliveryExecutionStatus.arrivedAtCustomer.value, 'arrived_at_customer');
      expect(DeliveryExecutionStatus.delivered.value, 'delivered');
      expect(DeliveryExecutionStatus.cancelled.value, 'cancelled');
    });
  });

  group('DeliveryStatusMachine Pure Rules & Invariants Tests', () {
    test('Legal transition sequences', () {
      expect(DeliveryStatusMachine.canTransition(DeliveryExecutionStatus.pending, DeliveryExecutionStatus.accepted), isTrue);
      expect(DeliveryStatusMachine.canTransition(DeliveryExecutionStatus.accepted, DeliveryExecutionStatus.headingToPickup), isTrue);
      expect(DeliveryStatusMachine.canTransition(DeliveryExecutionStatus.accepted, DeliveryExecutionStatus.arrivedAtPickup), isTrue);
      expect(DeliveryStatusMachine.canTransition(DeliveryExecutionStatus.headingToPickup, DeliveryExecutionStatus.arrivedAtPickup), isTrue);
      expect(DeliveryStatusMachine.canTransition(DeliveryExecutionStatus.arrivedAtPickup, DeliveryExecutionStatus.pickedUp), isTrue);
      expect(DeliveryStatusMachine.canTransition(DeliveryExecutionStatus.pickedUp, DeliveryExecutionStatus.headingToCustomer), isTrue);
      expect(DeliveryStatusMachine.canTransition(DeliveryExecutionStatus.headingToCustomer, DeliveryExecutionStatus.arrivedAtCustomer), isTrue);
      expect(DeliveryStatusMachine.canTransition(DeliveryExecutionStatus.arrivedAtCustomer, DeliveryExecutionStatus.delivered), isTrue);
    });

    test('Illegal status transitions must be rejected', () {
      expect(DeliveryStatusMachine.canTransition(DeliveryExecutionStatus.pending, DeliveryExecutionStatus.delivered), isFalse);
      expect(DeliveryStatusMachine.canTransition(DeliveryExecutionStatus.pending, DeliveryExecutionStatus.pickedUp), isFalse);
      expect(DeliveryStatusMachine.canTransition(DeliveryExecutionStatus.delivered, DeliveryExecutionStatus.pending), isFalse);
      expect(DeliveryStatusMachine.canTransition(DeliveryExecutionStatus.delivered, DeliveryExecutionStatus.accepted), isFalse);
      expect(DeliveryStatusMachine.canTransition(DeliveryExecutionStatus.pickedUp, DeliveryExecutionStatus.accepted), isFalse);
      expect(DeliveryStatusMachine.canTransition(DeliveryExecutionStatus.accepted, DeliveryExecutionStatus.accepted), isFalse);
      expect(DeliveryStatusMachine.canTransition(DeliveryExecutionStatus.delivered, DeliveryExecutionStatus.cancelled), isFalse);
      expect(DeliveryStatusMachine.canTransition(DeliveryExecutionStatus.cancelled, DeliveryExecutionStatus.accepted), isFalse);
      expect(DeliveryStatusMachine.canTransition(DeliveryExecutionStatus.cancelled, DeliveryExecutionStatus.delivered), isFalse);
    });

    test('getNextAction returns correct deterministic next step across all statuses', () {
      expect(DeliveryStatusMachine.getNextAction(DeliveryExecutionStatus.pending), isNull);
      expect(DeliveryStatusMachine.getNextAction(DeliveryExecutionStatus.accepted), DeliveryExecutionStatus.headingToPickup);
      expect(DeliveryStatusMachine.getNextAction(DeliveryExecutionStatus.headingToPickup), DeliveryExecutionStatus.arrivedAtPickup);
      expect(DeliveryStatusMachine.getNextAction(DeliveryExecutionStatus.arrivedAtPickup), DeliveryExecutionStatus.pickedUp);
      expect(DeliveryStatusMachine.getNextAction(DeliveryExecutionStatus.pickedUp), DeliveryExecutionStatus.headingToCustomer);
      expect(DeliveryStatusMachine.getNextAction(DeliveryExecutionStatus.headingToCustomer), DeliveryExecutionStatus.arrivedAtCustomer);
      expect(DeliveryStatusMachine.getNextAction(DeliveryExecutionStatus.arrivedAtCustomer), DeliveryExecutionStatus.delivered);
      expect(DeliveryStatusMachine.getNextAction(DeliveryExecutionStatus.delivered), isNull);
      expect(DeliveryStatusMachine.getNextAction(DeliveryExecutionStatus.cancelled), isNull);
    });

    test('canCancel checks terminal and non-terminal conditions', () {
      expect(DeliveryStatusMachine.canCancel(DeliveryExecutionStatus.pending), isTrue);
      expect(DeliveryStatusMachine.canCancel(DeliveryExecutionStatus.accepted), isTrue);
      expect(DeliveryStatusMachine.canCancel(DeliveryExecutionStatus.headingToPickup), isTrue);
      expect(DeliveryStatusMachine.canCancel(DeliveryExecutionStatus.arrivedAtPickup), isTrue);
      expect(DeliveryStatusMachine.canCancel(DeliveryExecutionStatus.pickedUp), isTrue);
      expect(DeliveryStatusMachine.canCancel(DeliveryExecutionStatus.headingToCustomer), isTrue);
      expect(DeliveryStatusMachine.canCancel(DeliveryExecutionStatus.arrivedAtCustomer), isTrue);
      expect(DeliveryStatusMachine.canCancel(DeliveryExecutionStatus.delivered), isFalse);
      expect(DeliveryStatusMachine.canCancel(DeliveryExecutionStatus.cancelled), isFalse);
    });

    test('Labels, colors, and step indexes for UI rendering', () {
      expect(DeliveryStatusMachine.getStepIndex(DeliveryExecutionStatus.pending), 0);
      expect(DeliveryStatusMachine.getStepIndex(DeliveryExecutionStatus.accepted), 1);
      expect(DeliveryStatusMachine.getStepIndex(DeliveryExecutionStatus.headingToPickup), 1);
      expect(DeliveryStatusMachine.getStepIndex(DeliveryExecutionStatus.arrivedAtPickup), 2);
      expect(DeliveryStatusMachine.getStepIndex(DeliveryExecutionStatus.pickedUp), 2);
      expect(DeliveryStatusMachine.getStepIndex(DeliveryExecutionStatus.headingToCustomer), 3);
      expect(DeliveryStatusMachine.getStepIndex(DeliveryExecutionStatus.arrivedAtCustomer), 3);
      expect(DeliveryStatusMachine.getStepIndex(DeliveryExecutionStatus.delivered), 4);
      expect(DeliveryStatusMachine.getStepIndex(DeliveryExecutionStatus.cancelled), 0);

      expect(DeliveryStatusMachine.getCustomerStatusLabel(DeliveryExecutionStatus.pending), contains('بانتظار'));
      expect(DeliveryStatusMachine.getCustomerStatusLabel(DeliveryExecutionStatus.accepted), contains('تم تعيين'));
      expect(DeliveryStatusMachine.getCustomerStatusLabel(DeliveryExecutionStatus.headingToPickup), contains('في الطريق للمحل'));
      expect(DeliveryStatusMachine.getCustomerStatusLabel(DeliveryExecutionStatus.arrivedAtPickup), contains('وصل لنقطة الاستلام'));
      expect(DeliveryStatusMachine.getCustomerStatusLabel(DeliveryExecutionStatus.pickedUp), contains('في الطريق إليك'));
      expect(DeliveryStatusMachine.getCustomerStatusLabel(DeliveryExecutionStatus.headingToCustomer), contains('متوجه إليك'));
      expect(DeliveryStatusMachine.getCustomerStatusLabel(DeliveryExecutionStatus.arrivedAtCustomer), contains('وصل عند موقعك'));
      expect(DeliveryStatusMachine.getCustomerStatusLabel(DeliveryExecutionStatus.delivered), contains('تم تسليم'));
      expect(DeliveryStatusMachine.getCustomerStatusLabel(DeliveryExecutionStatus.cancelled), contains('تم إلغاء'));

      expect(DeliveryStatusMachine.getStatusColor(DeliveryExecutionStatus.delivered).toARGB32(), 0xFF10B981);
      expect(DeliveryStatusMachine.getStatusColor(DeliveryExecutionStatus.cancelled).toARGB32(), 0xFFEF4444);
    });
  });

  group('DeliveryExecutionCalculator Extensive Tests', () {
    test('Haversine distance calculation is accurate across different geographies', () {
      final distance = DeliveryExecutionCalculator.calculateDistanceMeters(
        33.3152, 44.3661, // Baghdad
        34.3333, 41.0167, // Al-Qaim
      );
      expect(distance, greaterThan(320000));
      expect(distance, lessThan(350000));

      expect(DeliveryExecutionCalculator.calculateDistanceMeters(34.0, 41.0, 34.0, 41.0), 0.0);
      expect(DeliveryExecutionCalculator.calculateDistanceMeters(0.0, 0.0, 34.0, 41.0), 0.0);
      expect(DeliveryExecutionCalculator.calculateDistanceMeters(34.0, 41.0, 0.0, 0.0), 0.0);
    });

    test('Geofence isWithinArrivalRadius logic with various thresholds', () {
      const targetLat = 34.3333;
      const targetLng = 41.0167;

      expect(
        DeliveryExecutionCalculator.isWithinArrivalRadius(
          driverLat: 34.3335,
          driverLng: 41.0167,
          targetLat: targetLat,
          targetLng: targetLng,
          radiusMeters: 75.0,
        ),
        isTrue,
      );

      expect(
        DeliveryExecutionCalculator.isWithinArrivalRadius(
          driverLat: 34.3380,
          driverLng: 41.0167,
          targetLat: targetLat,
          targetLng: targetLng,
          radiusMeters: 75.0,
        ),
        isFalse,
      );

      // Edge case: invalid 0.0 coordinate
      expect(
        DeliveryExecutionCalculator.isWithinArrivalRadius(
          driverLat: 0.0,
          driverLng: 0.0,
          targetLat: targetLat,
          targetLng: targetLng,
        ),
        isFalse,
      );
    });

    test('estimateDurationMinutes calculates ETA with speed adjustments', () {
      expect(DeliveryExecutionCalculator.estimateDurationMinutes(distanceMeters: 15000, averageSpeedKmH: 30), 30);
      expect(DeliveryExecutionCalculator.estimateDurationMinutes(distanceMeters: 30000, averageSpeedKmH: 60), 30);
      expect(DeliveryExecutionCalculator.estimateDurationMinutes(distanceMeters: 0), 1);
      expect(DeliveryExecutionCalculator.estimateDurationMinutes(distanceMeters: -500), 1);
    });

    test('calculateMetrics financial settlement across all payment modes', () {
      // 1. Cash on delivery
      final metricsCash = DeliveryExecutionCalculator.calculateMetrics(
        deliveryFee: 3000,
        orderTotal: 15000,
        paymentMethod: 'cash_on_delivery',
        isPaid: false,
      );
      expect(metricsCash.platformCommission, 500.0);
      expect(metricsCash.captainEarnings, 2500.0);
      expect(metricsCash.cashToCollect, 18000.0);
      expect(metricsCash.merchantSettlement, 15000.0);
      expect(metricsCash.customerPointsEarned, 15);

      // 2. Electronic wallet payment
      final metricsElectronic = DeliveryExecutionCalculator.calculateMetrics(
        deliveryFee: 2000,
        orderTotal: 25000,
        paymentMethod: 'paid_wallet',
        isPaid: true,
      );
      expect(metricsElectronic.platformCommission, 500.0);
      expect(metricsElectronic.captainEarnings, 1500.0);
      expect(metricsElectronic.cashToCollect, 0.0);
      expect(metricsElectronic.merchantSettlement, 0.0);
      expect(metricsElectronic.customerPointsEarned, 25);

      // 3. Minimum fee fallback
      final metricsMin = DeliveryExecutionCalculator.calculateMetrics(
        deliveryFee: 0,
        orderTotal: 5000,
        paymentMethod: 'cash',
        isPaid: false,
      );
      expect(metricsMin.captainEarnings, 500.0); // 1000 min fee - 500 commission
      expect(metricsMin.cashToCollect, 6000.0);
    });
  });

  group('DeliveryRouteEngine Comprehensive Tests', () {
    test('shouldRecalculateRoute triggers on initial empty route', () {
      final driverLoc = DeliveryLocationEntity(latitude: 34.1, longitude: 41.1, timestamp: DateTime.now());
      const destination = DeliveryPoint(latitude: 34.2, longitude: 41.2);

      expect(
        DeliveryRouteEngine.shouldRecalculateRoute(
          currentDriverLocation: driverLoc,
          targetDestination: destination,
          existingRoute: null,
        ),
        isTrue,
      );
    });

    test('shouldRecalculateRoute suppresses rapid frequent calls within interval', () {
      final now = DateTime.now();
      final driverLoc = DeliveryLocationEntity(latitude: 34.1, longitude: 41.1, timestamp: now);
      const destination = DeliveryPoint(latitude: 34.2, longitude: 41.2);

      final existingRoute = DeliveryRouteEntity(
        polylinePoints: [driverLoc, DeliveryLocationEntity(latitude: 34.2, longitude: 41.2, timestamp: now)],
        totalDistanceMeters: 1000,
        totalDurationSeconds: 120,
        calculatedAt: now.subtract(const Duration(seconds: 3)),
      );

      expect(
        DeliveryRouteEngine.shouldRecalculateRoute(
          currentDriverLocation: driverLoc,
          targetDestination: destination,
          existingRoute: existingRoute,
          lastCalculatedDriverLocation: driverLoc,
          lastCalculatedDestination: destination,
          now: now,
        ),
        isFalse,
      );
    });

    test('shouldRecalculateRoute triggers on destination change', () {
      final now = DateTime.now();
      final driverLoc = DeliveryLocationEntity(latitude: 34.1, longitude: 41.1, timestamp: now);
      const oldDestination = DeliveryPoint(latitude: 34.2, longitude: 41.2);
      const newDestination = DeliveryPoint(latitude: 34.3, longitude: 41.3);

      final existingRoute = DeliveryRouteEntity(
        polylinePoints: [driverLoc],
        totalDistanceMeters: 1000,
        totalDurationSeconds: 120,
        calculatedAt: now.subtract(const Duration(seconds: 30)),
      );

      expect(
        DeliveryRouteEngine.shouldRecalculateRoute(
          currentDriverLocation: driverLoc,
          targetDestination: newDestination,
          existingRoute: existingRoute,
          lastCalculatedDriverLocation: driverLoc,
          lastCalculatedDestination: oldDestination,
          now: now,
        ),
        isTrue,
      );
    });

    test('calculateMinDistanceToPolyline returns accurate point distance', () {
      final polyline = [
        const DeliveryLocationEntity(latitude: 34.0, longitude: 41.0),
        const DeliveryLocationEntity(latitude: 34.0, longitude: 41.1),
      ];

      final onTrack = DeliveryLocationEntity(latitude: 34.0, longitude: 41.05, timestamp: DateTime.now());
      expect(DeliveryRouteEngine.calculateMinDistanceToPolyline(onTrack, polyline), lessThan(5.0));

      // Empty polyline returns infinity
      expect(DeliveryRouteEngine.calculateMinDistanceToPolyline(onTrack, const []), double.infinity);
    });
  });

  group('DeliveryExecutionEntity Immutability & Invariants Tests', () {
    test('Entity properties, privacy masking and copyWith', () {
      final entity = DeliveryExecutionEntity(
        orderId: 'ord_123',
        source: OrderDeliverySource.restaurant,
        merchantId: 'rest_1',
        merchantName: 'مطعم القائم',
        customerId: 'cust_1',
        customerName: 'علي حميد',
        customerPhone: '07700000000',
        status: DeliveryExecutionStatus.accepted,
        pickupPoint: const DeliveryPoint(latitude: 34.1, longitude: 41.1, name: 'المطعم'),
        dropoffPoint: const DeliveryPoint(latitude: 34.2, longitude: 41.2, name: 'البيت'),
        subtotal: 10000,
        deliveryFee: 2000,
        grandTotal: 12000,
      );

      expect(entity.orderId, 'ord_123');
      expect(entity.isCustomerMasked, isTrue);
      expect(entity.activeTargetPoint, entity.pickupPoint);
      expect(entity.isTerminal, isFalse);

      final pickedUpEntity = entity.copyWith(status: DeliveryExecutionStatus.pickedUp);
      expect(pickedUpEntity.isCustomerMasked, isFalse);
      expect(pickedUpEntity.activeTargetPoint, entity.dropoffPoint);

      final deliveredEntity = pickedUpEntity.copyWith(status: DeliveryExecutionStatus.delivered);
      expect(deliveredEntity.isTerminal, isTrue);

      final cancelledEntity = entity.copyWith(
        status: DeliveryExecutionStatus.cancelled,
        cancelReason: 'العميل لا يجيب',
      );
      expect(cancelledEntity.isTerminal, isTrue);
      expect(cancelledEntity.cancelReason, 'العميل لا يجيب');
    });

    test('DeliveryPoint, DeliveryLocationEntity and DeliveryOrderItem equality', () {
      const p1 = DeliveryPoint(latitude: 34.1, longitude: 41.1, name: 'موقع');
      const p2 = DeliveryPoint(latitude: 34.1, longitude: 41.1, name: 'موقع');
      const p3 = DeliveryPoint(latitude: 34.2, longitude: 41.2, name: 'موقع آخر');

      expect(p1 == p2, isTrue);
      expect(p1 == p3, isFalse);
      expect(p1.hashCode == p2.hashCode, isTrue);
      expect(p1.isValid, isTrue);

      const invalidPoint = DeliveryPoint(latitude: 0.0, longitude: 0.0);
      expect(invalidPoint.isValid, isFalse);

      const item = DeliveryOrderItem(id: 'i1', name: 'وجبة', quantity: 3, price: 5000);
      expect(item.total, 15000.0);
    });
  });
}
