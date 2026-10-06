import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/pricing/domain/services/iraqi_currency_formatter.dart';
import 'package:dalal_alqaim/features/restaurants/domain/entities/restaurant_details_models.dart';
import 'package:dalal_alqaim/features/restaurants/presentation/widgets/restaurant_details_header.dart';
import 'package:dalal_alqaim/features/restaurants/presentation/widgets/restaurant_menu_category_tabs.dart';
import 'package:dalal_alqaim/features/restaurants/presentation/widgets/restaurant_menu_item_card.dart';
import 'package:dalal_alqaim/features/restaurants/presentation/widgets/restaurant_item_customization_sheet.dart';
import 'package:dalal_alqaim/features/restaurants/presentation/widgets/restaurant_reviews_section.dart';

void main() {
  Widget wrapRtl(Widget widget) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: widget),
        ),
      ),
    );
  }

  group('RestaurantDetailsHeader Tests', () {
    testWidgets('Header renders restaurant name and cuisine', (tester) async {
      await tester.pumpWidget(
        wrapRtl(
          const CustomScrollView(
            slivers: [
              RestaurantDetailsHeader(
                restaurantName: 'مطعم القائم الذهبي',
                imageUrl: 'https://example.com/logo.png',
                cuisine: 'مشويات • مقبلات عراقية',
                isDark: false,
              ),
            ],
          ),
        ),
      );

      expect(find.text('مطعم القائم الذهبي'), findsOneWidget);
      expect(find.text('مشويات • مقبلات عراقية'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    });
  });

  group('RestaurantMenuCategoryTabs Tests', () {
    testWidgets('Category tabs render categories and handle tab taps', (tester) async {
      int tappedIndex = -1;
      const categories = [
        MenuCategoryEntity(name: 'الكل', iconCode: 0xe5c3),
        MenuCategoryEntity(name: 'مشويات', iconCode: 0xe2aa),
        MenuCategoryEntity(name: 'التقييمات', iconCode: 0xe56c),
      ];

      await tester.pumpWidget(
        wrapRtl(
          DefaultTabController(
            length: categories.length,
            child: Builder(
              builder: (context) {
                return RestaurantMenuCategoryTabs(
                  controller: DefaultTabController.of(context),
                  categories: categories,
                  isDark: false,
                  onTap: (idx) => tappedIndex = idx,
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('الكل'), findsOneWidget);
      expect(find.text('مشويات'), findsOneWidget);
      expect(find.text('التقييمات'), findsOneWidget);

      await tester.tap(find.text('مشويات'));
      await tester.pumpAndSettle();
      expect(tappedIndex, equals(1));
    });
  });

  group('RestaurantMenuItemCard Tests', () {
    const item = MenuItemDetailsEntity(
      id: 'item_1',
      name: 'كباب عراقي فاخر',
      price: 12000.0,
      description: 'أسياخ كباب غنم مع طماطم مشوية وخبز حار',
      imageUrl: '',
    );

    testWidgets('Menu item renders name, price, description and handles add/remove callbacks',
        (tester) async {
      bool addCalled = false;
      bool removeCalled = false;
      bool customizeCalled = false;

      await tester.pumpWidget(
        wrapRtl(
          RestaurantMenuItemCard(
            item: item,
            quantity: 2,
            isDark: false,
            onAdd: () => addCalled = true,
            onRemove: () => removeCalled = true,
            onCustomize: () => customizeCalled = true,
          ),
        ),
      );

      expect(find.text('كباب عراقي فاخر'), findsOneWidget);
      expect(find.text(IraqiCurrencyFormatter.format(12000.0)), findsOneWidget);
      expect(find.text(IraqiCurrencyFormatter.format(2, includeSymbol: false)), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      expect(addCalled, isTrue);

      await tester.tap(find.byIcon(Icons.remove));
      expect(removeCalled, isTrue);

      await tester.tap(find.text('كباب عراقي فاخر'));
      expect(customizeCalled, isTrue);
    });

    testWidgets('Menu item renders customization button when quantity is 0', (tester) async {
      bool customizeCalled = false;

      await tester.pumpWidget(
        wrapRtl(
          RestaurantMenuItemCard(
            item: item,
            quantity: 0,
            isDark: false,
            onAdd: () {},
            onRemove: () {},
            onCustomize: () => customizeCalled = true,
          ),
        ),
      );

      expect(find.text('تخصيص'), findsOneWidget);
      await tester.tap(find.text('تخصيص'));
      expect(customizeCalled, isTrue);
    });
  });

  group('RestaurantItemCustomizationSheet Tests', () {
    testWidgets('Customization sheet renders sizes, addons, calculates price, and handles onAdd',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      double addedFinalPrice = 0.0;
      String addedSize = '';
      String addedOptions = '';
      int addedQuantity = 0;

      await tester.pumpWidget(
        wrapRtl(
          RestaurantItemCustomizationSheet(
            id: 'm1',
            name: 'برجر لحم فاخر',
            basePrice: 8000.0,
            isDark: false,
            onAdd: (price, size, options, notes, qty) {
              addedFinalPrice = price;
              addedSize = size;
              addedOptions = options;
              addedQuantity = qty;
            },
          ),
        ),
      );

      expect(find.text('برجر لحم فاخر'), findsOneWidget);
      expect(find.text('اختر الحجم'), findsOneWidget);
      expect(find.text('عادي (وسط)'), findsOneWidget);
      expect(find.text('كبير'), findsOneWidget);
      expect(find.text('جبن إضافي ذائب'), findsOneWidget);

      // Select size 'كبير' (+1500)
      await tester.tap(find.text('كبير'));
      await tester.pumpAndSettle();

      // Check 'جبن إضافي ذائب' (+1000)
      await tester.tap(find.text('جبن إضافي ذائب'));
      await tester.pumpAndSettle();

      // Add quantity (+1 -> 2)
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text(IraqiCurrencyFormatter.format(2, includeSymbol: false)), findsOneWidget);

      // Total should be (8000 + 1500 + 1000) * 2 = 10500 * 2 = 21000
      final submitText = 'إضافة للسلة (${IraqiCurrencyFormatter.format(21000.0)})';
      expect(find.text(submitText), findsOneWidget);

      await tester.tap(find.text(submitText));
      await tester.pumpAndSettle();

      expect(addedFinalPrice, equals(10500.0));
      expect(addedSize, equals('كبير'));
      expect(addedOptions, contains('جبن إضافي ذائب'));
      expect(addedQuantity, equals(2));
    });
  });

  group('RestaurantReviewsSection Tests', () {
    final reviews = [
      RestaurantReviewEntity(
        id: 'rev_1',
        rating: 5.0,
        comment: 'أكل ممتاز ونظيف جداً',
        userId: 'u_1',
        userName: 'أحمد',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      RestaurantReviewEntity(
        id: 'rev_2',
        rating: 4.0,
        comment: 'توصيل سريع وخدمة ممتازة',
        userId: 'u_2',
        userName: 'سارة',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    const stats = ReviewStatisticsEntity(
      averageRating: 4.5,
      totalReviews: 2,
      starCounts: {5: 1, 4: 1, 3: 0, 2: 0, 1: 0},
    );

    testWidgets('Reviews section renders statistics, list, and delete button for owner',
        (tester) async {
      String deletedId = '';

      await tester.pumpWidget(
        wrapRtl(
          SingleChildScrollView(
            child: RestaurantReviewsSection(
              reviews: reviews,
              statistics: stats,
              isDark: false,
              isLoading: false,
              currentUserId: 'u_1',
              onAddReview: () {},
              onDeleteReview: (id) => deletedId = id,
            ),
          ),
        ),
      );

      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('2 تقييم'), findsOneWidget);
      expect(find.text('أكل ممتاز ونظيف جداً'), findsOneWidget);
      expect(find.text('توصيل سريع وخدمة ممتازة'), findsOneWidget);

      // Owner 'u_1' should see delete button for their review
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      expect(deletedId, equals('rev_1'));
    });

    testWidgets('Reviews section renders empty state when no reviews exist', (tester) async {
      await tester.pumpWidget(
        wrapRtl(
          RestaurantReviewsSection(
            reviews: const [],
            statistics: ReviewStatisticsEntity.empty(),
            isDark: false,
            isLoading: false,
            currentUserId: null,
            onAddReview: () {},
            onDeleteReview: (_) {},
          ),
        ),
      );

      expect(find.text('لا توجد مراجعات حتى الآن، كن أول من يشارك رأيه!'), findsOneWidget);
    });

    testWidgets('Reviews section renders loading indicator when isLoading is true',
        (tester) async {
      await tester.pumpWidget(
        wrapRtl(
          RestaurantReviewsSection(
            reviews: const [],
            statistics: ReviewStatisticsEntity.empty(),
            isDark: false,
            isLoading: true,
            currentUserId: null,
            onAddReview: () {},
            onDeleteReview: (_) {},
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
