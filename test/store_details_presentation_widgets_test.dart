import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/features/stores/domain/entities/store_dashboard_models.dart';
import 'package:dalal_alqaim/features/stores/domain/entities/store_cart_item_entity.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_details_header.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_promo_banner.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_circle_categories.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_product_grid_card.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_cart_bottom_sheet.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_checkout_details_sheet.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_order_success_dialog.dart';
import 'package:dalal_alqaim/features/stores/presentation/widgets/store_customer_settings_sheet.dart';

Widget _buildTestApp(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    builder: (context, _) => MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Store Details Presentation Widgets — UI & Interaction Tests', () {
    testWidgets('1. StoreDetailsHeader displays store name and handles search/back callbacks', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      final searchCtrl = TextEditingController();
      bool backPressed = false;
      String query = '';

      await tester.pumpWidget(
        _buildTestApp(
          CustomScrollView(
            slivers: [
              StoreDetailsHeader(
                storeName: 'سوبرماركت الرشيد',
                searchController: searchCtrl,
                onBack: () => backPressed = true,
                onSearchChanged: (v) => query = v,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('سوبرماركت الرشيد'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(backPressed, isTrue);

      await tester.enterText(find.byType(TextField), 'أرز');
      await tester.pumpAndSettle();
      expect(query, equals('أرز'));
    });

    testWidgets('2. StorePromoBanner shows fallback welcome banner when banners list is empty', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(
        _buildTestApp(
          const StorePromoBanner(
            banners: [],
            storeName: 'متجر الرافدين',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('أهلاً بك في متجر الرافدين'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
    });

    testWidgets('3. StoreCircleCategories renders categories and triggers selection callback', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      String selected = 'الكل';
      final categories = [
        const StoreCategoryEntity(categoryId: 'c1', name: 'ألبان', iconCode: 0xe148, colorValue: 0xFFF5F5F5),
        const StoreCategoryEntity(categoryId: 'c2', name: 'مشروبات', iconCode: 0xe148, colorValue: 0xFFF5F5F5),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          Directionality(
            textDirection: TextDirection.rtl,
            child: StoreCircleCategories(
              categories: categories,
              selectedCategory: selected,
              onCategorySelected: (cat) => selected = cat,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الكل'), findsOneWidget);
      expect(find.text('ألبان'), findsOneWidget);

      final albanFinder = find.text('ألبان');
      await tester.ensureVisible(albanFinder);
      await tester.tap(albanFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(selected, equals('ألبان'));
    });

    testWidgets('4. StoreProductGridCard displays product info and triggers add/delete callbacks', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      bool added = false;
      bool deleted = false;
      const product = StoreProductEntity(
        productId: 'p_100',
        name: 'لبن عراقي 500 مل',
        price: 1500.0,
        category: 'ألبان',
        imageUrl: '',
      );

      await tester.pumpWidget(
        _buildTestApp(
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 0.72,
            children: [
              StoreProductGridCard(
                product: product,
                isAdmin: true,
                onTap: () {},
                onAddToCart: () => added = true,
                onDelete: () => deleted = true,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لبن عراقي 500 مل'), findsOneWidget);
      expect(find.text('1500 د.ع'), findsOneWidget);
      expect(find.text('ألبان'), findsOneWidget);

      // Add to cart tap
      await tester.tap(find.byIcon(Icons.add_shopping_cart_rounded));
      await tester.pumpAndSettle();
      expect(added, isTrue);

      // Delete tap
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });

    testWidgets('5. StoreCartBottomSheet displays items and handles checkout button tap', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      bool checkoutPressed = false;
      String removedId = '';
      final items = [
        StoreCartItemEntity(productId: 'cart_1', name: 'شاي ممتاز', price: 3000.0, quantity: 2),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: ctx,
                  isScrollControlled: true,
                  builder: (_) => StoreCartBottomSheet(
                    items: items,
                    subtotal: 6000.0,
                    onRemoveItem: (id) => removedId = id,
                    onCheckoutTap: () => checkoutPressed = true,
                  ),
                );
              },
              child: const Text('Open Cart'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Cart'));
      await tester.pumpAndSettle();

      expect(find.text('سلة التسوق'), findsOneWidget);
      expect(find.text('شاي ممتاز'), findsOneWidget);
      expect(find.text('3000 د.ع × 2'), findsOneWidget);
      expect(find.text('6000 د.ع'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      expect(removedId, equals('cart_1'));

      final checkoutBtn = find.text('أكمل');
      await tester.ensureVisible(checkoutBtn);
      await tester.tap(checkoutBtn);
      await tester.pumpAndSettle();
      expect(checkoutPressed, isTrue);
    });

    testWidgets('6. StoreCheckoutDetailsSheet validates inputs and fires onConfirmOrder', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      bool orderConfirmed = false;

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: ctx,
                  isScrollControlled: true,
                  builder: (_) => StoreCheckoutDetailsSheet(
                    initialName: 'حيدر الكرخي',
                    initialPhone: '07709876543',
                    initialAddress: 'بغداد - المنصور',
                    subtotal: 10000.0,
                    deliveryFee: 1500.0,
                    userPoints: 300,
                    userBalance: 25000.0,
                    onConfirmOrder: ({
                      required String name,
                      required String phone,
                      required String address,
                      required String notes,
                      required bool usePoints,
                      required bool useWallet,
                    }) {
                      orderConfirmed = true;
                    },
                  ),
                );
              },
              child: const Text('Open Checkout'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Checkout'));
      await tester.pumpAndSettle();

      expect(find.text('إتمام وتأكيد الطلب'), findsOneWidget);
      expect(find.text('حيدر الكرخي'), findsOneWidget);

      final submitFinder = find.byType(ElevatedButton).last;
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();
      expect(orderConfirmed, isTrue);
    });

    testWidgets('7. StoreOrderSuccessDialog displays order ID and action buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      bool whatsAppTapped = false;
      bool myOrdersTapped = false;

      await tester.pumpWidget(
        _buildTestApp(
          StoreOrderSuccessDialog(
            orderId: 'ORD-12345',
            storeName: 'سوبرماركت السلام',
            onWhatsAppTap: () => whatsAppTapped = true,
            onMyOrdersTap: () => myOrdersTapped = true,
            onBackToStoreTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تم إرسال طلبك بنجاح!'), findsOneWidget);
      expect(find.text('رقم الطلب: #ORD-12345'), findsOneWidget);

      final whatsAppFinder = find.text('تأكيد عبر واتساب');
      await tester.ensureVisible(whatsAppFinder);
      await tester.tap(whatsAppFinder);
      await tester.pumpAndSettle();
      expect(whatsAppTapped, isTrue);

      final myOrdersFinder = find.text('متابعة في طلباتي');
      await tester.ensureVisible(myOrdersFinder);
      await tester.tap(myOrdersFinder);
      await tester.pumpAndSettle();
      expect(myOrdersTapped, isTrue);
    });

    testWidgets('8. StoreCustomerSettingsSheet renders settings tiles and triggers callbacks', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      bool myOrdersClicked = false;
      bool changePhoneClicked = false;

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: ctx,
                  isScrollControlled: true,
                  builder: (_) => StoreCustomerSettingsSheet(
                    onMyOrdersTap: () => myOrdersClicked = true,
                    onChangePhoneTap: () => changePhoneClicked = true,
                  ),
                );
              },
              child: const Text('Open Settings'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.text('الإعدادات'), findsOneWidget);
      expect(find.text('الإشعارات'), findsOneWidget);
      expect(find.text('طلباتي'), findsOneWidget);
      expect(find.text('تغيير رقم الهاتف'), findsOneWidget);

      final myOrdersFinder = find.text('طلباتي');
      await tester.ensureVisible(myOrdersFinder);
      await tester.tap(myOrdersFinder);
      await tester.pumpAndSettle();
      expect(myOrdersClicked, isTrue);

      final changePhoneFinder = find.text('تغيير رقم الهاتف');
      await tester.ensureVisible(changePhoneFinder);
      await tester.tap(changePhoneFinder);
      await tester.pumpAndSettle();
      expect(changePhoneClicked, isTrue);
    });
  });
}
