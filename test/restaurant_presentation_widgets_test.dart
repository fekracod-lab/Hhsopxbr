import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/restaurants/domain/entities/restaurant_models.dart';
import 'package:dalal_alqaim/features/restaurants/presentation/widgets/confetti_overlay_widget.dart';
import 'package:dalal_alqaim/features/restaurants/presentation/widgets/restaurant_card.dart';
import 'package:dalal_alqaim/features/restaurants/presentation/widgets/restaurant_filters_bar.dart';
import 'package:dalal_alqaim/features/restaurants/presentation/widgets/restaurant_floating_cart_strip.dart';
import 'package:dalal_alqaim/features/restaurants/presentation/widgets/restaurant_active_order_tracker.dart';
import 'package:dalal_alqaim/features/restaurants/presentation/widgets/group_cart_dialogs.dart';

Widget _wrapWithScreenUtil(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, _) => MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Restaurant Presentation Widgets Unit & Widget Tests', () {
    testWidgets('ConfettiOverlayWidget should be empty initially and paint on trigger', (tester) async {
      final key = GlobalKey<ConfettiOverlayWidgetState>();
      await tester.pumpWidget(
        _wrapWithScreenUtil(
          ConfettiOverlayWidget(key: key),
        ),
      );

      // Initially empty (SizedBox)
      expect(find.descendant(of: find.byType(ConfettiOverlayWidget), matching: find.byType(CustomPaint)), findsNothing);

      // Trigger confetti
      key.currentState?.trigger();
      await tester.pump();
      expect(find.descendant(of: find.byType(ConfettiOverlayWidget), matching: find.byType(CustomPaint)), findsOneWidget);
    });

    testWidgets('RestaurantCard should display name, open badge, and trigger callbacks', (tester) async {
      bool tapped = false;
      bool favToggled = false;

      final restaurant = const RestaurantEntity(
        id: 'rest_1',
        name: 'مطعم القائم التجريبي',
        imageUrl: '',
        isOpen: true,
        category: 'المطاعم',
        deliveryFee: 0,
        rating: 4.9,
      );

      await tester.pumpWidget(
        _wrapWithScreenUtil(
          RestaurantCard(
            restaurant: restaurant,
            isFavorite: false,
            isDark: false,
            onTap: () => tapped = true,
            onFavoriteToggle: () => favToggled = true,
          ),
        ),
      );

      expect(find.text('مطعم القائم التجريبي'), findsOneWidget);
      expect(find.text('مفتوح'), findsOneWidget);

      await tester.tap(find.text('مطعم القائم التجريبي'));
      expect(tapped, isTrue);

      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      expect(favToggled, isTrue);
    });

    testWidgets('RestaurantFiltersBar should display filter chips and trigger callbacks', (tester) async {
      bool freeDelToggled = false;
      bool openToggled = false;

      await tester.pumpWidget(
        _wrapWithScreenUtil(
          RestaurantFiltersBar(
            onlyFreeDelivery: false,
            onlyOpen: true,
            sortByRating: false,
            sortByDeliveryTime: false,
            isDark: false,
            onToggleFreeDelivery: () => freeDelToggled = true,
            onToggleOnlyOpen: () => openToggled = true,
            onToggleSortByRating: () {},
            onToggleSortByDeliveryTime: () {},
          ),
        ),
      );

      expect(find.text('توصيل بلاش'), findsOneWidget);
      expect(find.text('فاتح هسة'), findsOneWidget);

      await tester.tap(find.text('توصيل بلاش'));
      expect(freeDelToggled, isTrue);

      await tester.tap(find.text('فاتح هسة'));
      expect(openToggled, isTrue);
    });

    testWidgets('RestaurantFloatingCartStrip should display formatted price and item count', (tester) async {
      bool cartTapped = false;

      await tester.pumpWidget(
        _wrapWithScreenUtil(
          Stack(
            children: [
              RestaurantFloatingCartStrip(
                itemCount: 3,
                totalPrice: 15000,
                onTap: () => cartTapped = true,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(find.textContaining('15,000 د.ع'), findsOneWidget);

      await tester.tap(find.text('شوف السلة'));
      expect(cartTapped, isTrue);
    });

    testWidgets('RestaurantActiveOrderTracker should display order status and step indicator', (tester) async {
      bool trackTapped = false;

      final order = ActiveOrderEntity(
        id: 'ord_123',
        status: 'accepted',
        restaurantName: 'مشاوي دجلة',
        totalPrice: 24000,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _wrapWithScreenUtil(
          RestaurantActiveOrderTracker(
            activeOrder: order,
            isDark: false,
            onTrackOrderTap: () => trackTapped = true,
          ),
        ),
      );

      expect(find.text('مشاوي دجلة'), findsOneWidget);
      expect(find.text('جاي يجهزون أكلك'), findsOneWidget);

      await tester.tap(find.text('تتبع الطلب'));
      expect(trackTapped, isTrue);
    });

    testWidgets('GroupCartBannerWidget should show host banner and group cart code', (tester) async {
      await tester.pumpWidget(
        _wrapWithScreenUtil(
          GroupCartBannerWidget(
            groupCartCode: '98765',
            hostName: 'أحمد',
            isHost: true,
            isDark: false,
            onLeaveOrEnd: () {},
          ),
        ),
      );

      expect(find.text('سلة الربع مالتك مشتغلة هسة'), findsOneWidget);
      expect(find.text('98765'), findsOneWidget);
      expect(find.byIcon(Icons.power_settings_new_rounded), findsOneWidget);
    });
  });
}
