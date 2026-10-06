import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/pages/restaurants_page.dart';
import 'package:dalal_alqaim/features/restaurants/application/restaurant_controller.dart';
import 'package:dalal_alqaim/features/restaurants/application/group_cart_controller.dart';
import 'package:dalal_alqaim/features/restaurants/data/repositories/restaurant_repository.dart';
import 'package:dalal_alqaim/features/restaurants/data/datasources/restaurant_remote_datasource.dart';

class _FakeRestaurantRemoteDatasource extends RestaurantRemoteDatasource {
  final List<Map<String, dynamic>> _mockRestaurants = [
    {
      'id': 'rest_fake_1',
      'name': 'مطعم دجلة والفرات',
      'imageUrl': '',
      'isOpen': true,
      'category': 'المطاعم',
      'deliveryFee': 0,
      'rating': 4.9,
    }
  ];

  @override
  Future<List<Map<String, dynamic>>> fetchRestaurants() async {
    return _mockRestaurants;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPopularMeals() async {
    return [];
  }

  @override
  Stream<List<Map<String, dynamic>>> watchCartItems(String effectiveCartId) {
    return Stream.value([
      {
        'id': 'c1',
        'name': 'وجبة برجر',
        'price': 6000.0,
        'quantity': 2,
        'restaurantId': 'rest_fake_1',
      }
    ]);
  }

  @override
  Stream<List<Map<String, dynamic>>> watchUserOrders(String uid) {
    return Stream.value([
      {
        'id': 'ord_1',
        'status': 'accepted',
        'restaurantName': 'مطعم دجلة والفرات',
        'totalPrice': 12000.0,
      }
    ]);
  }

  @override
  Stream<Map<String, dynamic>?> watchGroupCart(String code) {
    return Stream.value(null);
  }

  @override
  Future<Map<String, dynamic>?> fetchLatestOrder(String uid) async {
    return {
      'id': 'ord_last',
      'restaurantName': 'مطعم دجلة والفرات',
      'totalPrice': 12000.0,
      'status': 'completed',
    };
  }
}

Widget _wrapPage(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (context, _) => MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RestaurantsPage Coordinator Unit & Widget Tests', () {
    late RestaurantRepository repository;
    late RestaurantController restaurantController;
    late GroupCartController groupCartController;

    setUp(() {
      repository = RestaurantRepository(
        remoteDatasource: _FakeRestaurantRemoteDatasource(),
      );
      restaurantController = RestaurantController(repository: repository);
      groupCartController = GroupCartController(repository: repository);
    });

    tearDown(() {
      restaurantController.dispose();
      groupCartController.dispose();
    });

    testWidgets('RestaurantsPage initializes controllers and renders header and widgets', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrapPage(
          RestaurantsPage(
            customRestaurantController: restaurantController,
            customGroupCartController: groupCartController,
            initialUid: 'user_123',
            initialUserName: 'عمر',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('دوّر على أطيب أكلة أو مطعم...'), findsOneWidget);
      expect(find.text('توصيل بلاش'), findsOneWidget);
      expect(find.text('فاتح هسة'), findsOneWidget);
      expect(find.text('أعلى تقييم'), findsOneWidget);
      expect(find.text('كل المطاعم'), findsOneWidget);
    });

    testWidgets('Tapping filter chips toggles controller filter state', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrapPage(
          RestaurantsPage(
            customRestaurantController: restaurantController,
            customGroupCartController: groupCartController,
            initialUid: 'user_123',
            initialUserName: 'عمر',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(restaurantController.onlyFreeDelivery, isFalse);
      await tester.tap(find.text('توصيل بلاش'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(restaurantController.onlyFreeDelivery, isTrue);

      expect(restaurantController.onlyOpen, isFalse);
      await tester.tap(find.text('فاتح هسة'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(restaurantController.onlyOpen, isTrue);
    });

    testWidgets('Pull-to-refresh calls restaurant controller refresh without errors', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrapPage(
          RestaurantsPage(
            customRestaurantController: restaurantController,
            customGroupCartController: groupCartController,
            initialUid: 'user_123',
            initialUserName: 'عمر',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await restaurantController.refreshRestaurants();
      await tester.pump(const Duration(milliseconds: 300));

      expect(restaurantController.isReady, isTrue);
    });
  });
}
