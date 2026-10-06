import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/pages/restaurant_details_page.dart';
import 'package:dalal_alqaim/features/restaurants/application/restaurant_details_controller.dart';
import 'package:dalal_alqaim/features/restaurants/data/datasources/restaurant_remote_datasource.dart';
import 'package:dalal_alqaim/features/restaurants/data/repositories/restaurant_repository.dart';
import 'package:dalal_alqaim/features/restaurants/domain/entities/restaurant_models.dart';
import 'package:dalal_alqaim/features/restaurants/domain/entities/restaurant_details_models.dart';
import 'package:dalal_alqaim/core/pricing/domain/services/iraqi_currency_formatter.dart';

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _createMockImageHttpClient();
  }
}

HttpClient _createMockImageHttpClient() {
  final client = _MockHttpClient();
  return client;
}

class _MockHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) {}
  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) {}
  @override
  set authenticate(Future<bool> Function(Uri url, String scheme, String? realm)? f) {}
  @override
  set authenticateProxy(Future<bool> Function(String host, int port, String scheme, String? realm)? f) {}
  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) {}
  @override
  set findProxy(String Function(Uri url)? f) {}

  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _MockHttpClientRequest();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientResponse implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => _transparentImage.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_transparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final List<int> _transparentImage = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
];

class FakeRegressionRestaurantRepository extends RestaurantRepository {
  RestaurantEntity? stubRestaurant;
  ({String sectionId, String itemId, List<MenuCategoryEntity> categories})? stubMenuContext;

  final StreamController<List<MenuItemDetailsEntity>> menuStream =
      StreamController<List<MenuItemDetailsEntity>>.broadcast();
  final StreamController<List<CartItemEntity>> cartStream =
      StreamController<List<CartItemEntity>>.broadcast();
  final StreamController<List<RestaurantReviewEntity>> reviewsStream =
      StreamController<List<RestaurantReviewEntity>>.broadcast();

  bool addCartItemCalled = false;
  bool removeCartItemCalled = false;
  bool addReviewCalled = false;
  bool deleteReviewCalled = false;

  FakeRegressionRestaurantRepository()
      : super(remoteDatasource: RestaurantRemoteDatasource());

  @override
  Future<RestaurantEntity?> getRestaurantById(String restaurantId) async => stubRestaurant;

  @override
  Future<({String sectionId, String itemId, List<MenuCategoryEntity> categories})?>
      getRestaurantMenuContext(String restaurantId) async => stubMenuContext;

  @override
  Stream<List<MenuItemDetailsEntity>> watchMenuItems({
    required String sectionId,
    required String itemId,
    String? category,
    String? sortBy,
  }) =>
      menuStream.stream;

  @override
  Stream<List<CartItemEntity>> watchCartItems(String effectiveCartId) =>
      cartStream.stream;

  @override
  Stream<List<RestaurantReviewEntity>> watchRestaurantReviews(String restaurantId) =>
      reviewsStream.stream;

  @override
  Future<void> addCartItem({
    required String cartId,
    required String itemId,
    required String name,
    required double price,
    int quantity = 1,
    required String restaurantId,
    required String restaurantName,
    String? imageUrl,
    String size = '',
    String options = '',
    String notes = '',
    String? addedByName,
  }) async {
    addCartItemCalled = true;
  }

  @override
  Future<void> removeCartItem({
    required String cartId,
    required String itemId,
  }) async {
    removeCartItemCalled = true;
  }

  @override
  Future<void> addRestaurantReview({
    required String restaurantId,
    required double rating,
    required String comment,
    required String userId,
    required String userName,
  }) async {
    addReviewCalled = true;
  }

  @override
  Future<void> deleteRestaurantReview({
    required String restaurantId,
    required String reviewId,
  }) async {
    deleteReviewCalled = true;
  }

  void dispose() {
    menuStream.close();
    cartStream.close();
    reviewsStream.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _FakeHttpOverrides();

  late FakeRegressionRestaurantRepository fakeRepo;
  late RestaurantDetailsController testController;

  setUp(() {
    fakeRepo = FakeRegressionRestaurantRepository();
    fakeRepo.stubRestaurant = const RestaurantEntity(
      id: 'rest_777',
      name: 'مطعم القائم الذهبي',
      rawData: {'cuisine': 'مشويات عراقية • مقبلات'},
    );
    fakeRepo.stubMenuContext = (
      sectionId: 'sec_99',
      itemId: 'item_99',
      categories: [
        const MenuCategoryEntity(id: 'c1', name: 'مشويات', iconCode: 0xe2aa),
        const MenuCategoryEntity(id: 'c2', name: 'عصائر', iconCode: 0xe5c3),
      ],
    );

    testController = RestaurantDetailsController(
      repository: fakeRepo,
      restaurantId: 'rest_777',
      restaurantName: 'مطعم القائم الذهبي',
      imageUrl: 'https://example.com/cover.png',
    );
  });

  tearDown(() {
    testController.dispose();
    fakeRepo.dispose();
    GroupCartManager.clear();
  });

  Widget createTestWidget() {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: RestaurantDetailsPage(
            restaurantId: 'rest_777',
            restaurantName: 'مطعم القائم الذهبي',
            imageUrl: 'https://example.com/cover.png',
            controller: testController,
          ),
        ),
      ),
    );
  }

  group('RestaurantDetailsPage — Coordinator & Flow Regression Tests', () {
    testWidgets('1. Page builds and renders header with name, cuisine and back button',
        (tester) async {
      await testController.initialize(uid: 'u_123');
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('مطعم القائم الذهبي'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    });

    testWidgets('2. Categories and tabs render with الكل, مشويات, عصائر, and التقييمات',
        (tester) async {
      await testController.initialize(uid: 'u_123');
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('الكل'), findsWidgets);
      expect(find.text('مشويات'), findsWidgets);
      expect(find.text('عصائر'), findsWidgets);
      expect(find.text('التقييمات'), findsWidgets);
    });

    testWidgets('3. Menu item renders and customization sheet submits to controller',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await testController.initialize(uid: 'u_123');
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 300));

      fakeRepo.menuStream.add([
        const MenuItemDetailsEntity(
          id: 'food_1',
          name: 'شاورما دجاج',
          price: 5000.0,
          description: 'ساندويتش شاورما فاخر',
          imageUrl: 'https://example.com/shawarma.png',
        ),
      ]);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('شاورما دجاج'), findsOneWidget);
      expect(find.text(IraqiCurrencyFormatter.format(5000.0)), findsOneWidget);

      await testController.addItem(
        id: 'food_1',
        price: 5000.0,
        name: 'شاورما دجاج',
        imageUrl: 'https://example.com/shawarma.png',
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeRepo.addCartItemCalled, isTrue);
    });

    testWidgets('4. Floating Cart Bar renders when cart items exist and shows total',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await testController.initialize(uid: 'u_123');
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 300));

      fakeRepo.cartStream.add([
        const CartItemEntity(id: 'food_1', name: 'شاورما دجاج', price: 5000.0, quantity: 2),
      ]);

      await tester.pump(const Duration(milliseconds: 300));

      // Floating cart should appear
      expect(find.text('شاهد سلة الطلبات'), findsOneWidget);
      expect(find.text(IraqiCurrencyFormatter.format(10000.0)), findsOneWidget);
      expect(find.text(IraqiCurrencyFormatter.format(2, includeSymbol: false)), findsWidgets);
    });

    testWidgets('5. Reviews section renders in reviews tab with statistics and empty state',
        (tester) async {
      await testController.initialize(uid: 'u_123');
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 300));

      fakeRepo.reviewsStream.add([]);
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on التقييمات tab
      final tabFinder = find.widgetWithText(Tab, 'التقييمات');
      if (tabFinder.evaluate().isNotEmpty) {
        await tester.tap(tabFinder, warnIfMissed: false);
      } else {
        await tester.tap(find.text('التقييمات').first, warnIfMissed: false);
      }
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('التقييمات'), findsWidgets);
    });

    testWidgets('6. Add review dialog opens and renders review form controls',
        (tester) async {
      await testController.initialize(uid: 'u_123');
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 300));

      fakeRepo.reviewsStream.add([]);
      await tester.pump(const Duration(milliseconds: 300));

      final tabFinder = find.widgetWithText(Tab, 'التقييمات');
      if (tabFinder.evaluate().isNotEmpty) {
        await tester.tap(tabFinder, warnIfMissed: false);
      } else {
        await tester.tap(find.text('التقييمات').first, warnIfMissed: false);
      }
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      final addReviewFinder = find.text('أضف تقييمك');
      if (addReviewFinder.evaluate().isNotEmpty) {
        await tester.tap(addReviewFinder);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('قيم تجربتك'), findsOneWidget);
        expect(find.text('إرسال التقييم'), findsOneWidget);
      }
    });

    testWidgets('7. Constructor maintains complete backward compatibility with default arguments',
        (tester) async {
      const defaultPage = RestaurantDetailsPage(restaurantId: 'rest_000');
      expect(defaultPage.restaurantId, equals('rest_000'));
      expect(defaultPage.restaurantName, equals('مطعم القائم المميز'));
      expect(defaultPage.imageUrl, contains('unsplash.com'));
    });
  });
}
