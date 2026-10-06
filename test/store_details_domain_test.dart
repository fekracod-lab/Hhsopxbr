import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/stores/domain/entities/store_cart_item_entity.dart';
import 'package:dalal_alqaim/features/stores/domain/entities/store_checkout_models.dart';
import 'package:dalal_alqaim/features/stores/domain/services/store_details_calculator.dart';

void main() {
  group('Store Details Domain — Cart & Item Subtotal Tests', () {
    test('1. calculateItemSubtotal multiplies positive price and quantity', () {
      final item = StoreCartItemEntity(
        productId: 'prod_1',
        name: 'شاي عراقي فاخر',
        price: 3500.0,
        quantity: 3,
      );
      expect(StoreDetailsCalculator.calculateItemSubtotal(item), equals(10500.0));
      expect(item.itemSubtotal, equals(10500.0));
    });

    test('2. StoreCartItemEntity defensively normalizes negative price to 0.0', () {
      final item = StoreCartItemEntity(
        productId: 'prod_2',
        name: 'منتج غير صالح',
        price: -5000.0,
        quantity: 2,
      );
      expect(item.price, equals(0.0));
      expect(item.itemSubtotal, equals(0.0));
    });

    test('3. StoreCartItemEntity defensively normalizes 0 or negative quantity to 1', () {
      final itemZero = StoreCartItemEntity(
        productId: 'prod_3',
        name: 'سكر أبيض',
        price: 1500.0,
        quantity: 0,
      );
      final itemNeg = StoreCartItemEntity(
        productId: 'prod_4',
        name: 'أرز بسمتي',
        price: 2500.0,
        quantity: -5,
      );
      expect(itemZero.quantity, equals(1));
      expect(itemNeg.quantity, equals(1));
    });

    test('4. StoreCartItemEntity fromMap handles string prices and string quantities safely', () {
      final item = StoreCartItemEntity.fromMap({
        'productId': 'prod_5',
        'name': 'زيت زيتون 1 لتر',
        'price': '8500 د.ع',
        'quantity': '4',
        'category': 'زيوت',
      });
      expect(item.productId, equals('prod_5'));
      expect(item.name, equals('زيت زيتون 1 لتر'));
      expect(item.price, equals(8500.0));
      expect(item.quantity, equals(4));
      expect(item.itemSubtotal, equals(34000.0));
    });

    test('5. StoreCartItemEntity copyWith creates modified instance without mutating original', () {
      final original = StoreCartItemEntity(
        productId: 'prod_6',
        name: 'قهوة عربية',
        price: 4000.0,
        quantity: 1,
      );
      final updated = original.copyWith(quantity: 3, notes: 'بدون سكر');
      expect(original.quantity, equals(1));
      expect(updated.quantity, equals(3));
      expect(updated.notes, equals('بدون سكر'));
      expect(updated.itemSubtotal, equals(12000.0));
    });

    test('6. calculateCartSubtotal returns 0.0 for empty items list', () {
      expect(StoreDetailsCalculator.calculateCartSubtotal([]), equals(0.0));
    });

    test('7. calculateCartSubtotal aggregates multiple cart items accurately', () {
      final items = [
        StoreCartItemEntity(productId: '1', name: 'أرز', price: 2000.0, quantity: 2), // 4000
        StoreCartItemEntity(productId: '2', name: 'زيت', price: 3500.0, quantity: 1), // 3500
        StoreCartItemEntity(productId: '3', name: 'شاي', price: 1500.0, quantity: 4), // 6000
      ];
      expect(StoreDetailsCalculator.calculateCartSubtotal(items), equals(13500.0));
    });

    test('8. calculateCartSubtotal handles large quantities safely without overflow', () {
      final items = [
        StoreCartItemEntity(productId: 'bulk', name: 'طحين أكياس', price: 25000.0, quantity: 100),
      ];
      expect(StoreDetailsCalculator.calculateCartSubtotal(items), equals(2500000.0));
    });
  });

  group('Store Details Domain — Delivery Fee Tests', () {
    test('9. calculateDeliveryFee returns store-configured delivery fee when valid', () {
      final fee = StoreDetailsCalculator.calculateDeliveryFee(storeDeliveryFee: 2500.0);
      expect(fee, equals(2500.0));
    });

    test('10. calculateDeliveryFee returns default fallback (1500 IQD) when store fee is null', () {
      final fee = StoreDetailsCalculator.calculateDeliveryFee(storeDeliveryFee: null);
      expect(fee, equals(1500.0));
    });

    test('11. calculateDeliveryFee allows 0.0 (free delivery) when explicitly configured', () {
      final fee = StoreDetailsCalculator.calculateDeliveryFee(storeDeliveryFee: 0.0);
      expect(fee, equals(0.0));
    });

    test('12. calculateDeliveryFee clamps negative fee to default fallback', () {
      final fee = StoreDetailsCalculator.calculateDeliveryFee(storeDeliveryFee: -1000.0);
      expect(fee, equals(1500.0));
    });
  });

  group('Store Details Domain — Loyalty Points & Discount Tests', () {
    test('13. convertPointsToDiscount applies 100 pts = 1000 IQD rate', () {
      expect(StoreDetailsCalculator.convertPointsToDiscount(0), equals(0.0));
      expect(StoreDetailsCalculator.convertPointsToDiscount(100), equals(1000.0));
      expect(StoreDetailsCalculator.convertPointsToDiscount(250), equals(2500.0));
      expect(StoreDetailsCalculator.convertPointsToDiscount(500), equals(5000.0));
    });

    test('14. calculatePointsDiscount computes valid discount when points are within balance and total', () {
      final disc = StoreDetailsCalculator.calculatePointsDiscount(
        usedPoints: 200,
        availablePoints: 500,
        maxEligibleAmount: 10000.0,
      );
      expect(disc, equals(2000.0));
    });

    test('15. calculatePointsDiscount clamps points to availablePoints when requested exceeds balance', () {
      final disc = StoreDetailsCalculator.calculatePointsDiscount(
        usedPoints: 600,
        availablePoints: 400,
        maxEligibleAmount: 10000.0,
      );
      expect(disc, equals(4000.0)); // 400 pts * 10
    });

    test('16. calculatePointsDiscount clamps discount to maxEligibleAmount so discount never exceeds subtotal', () {
      final disc = StoreDetailsCalculator.calculatePointsDiscount(
        usedPoints: 1000, // 10,000 IQD
        availablePoints: 1000,
        maxEligibleAmount: 3500.0, // Subtotal is only 3500
      );
      expect(disc, equals(3500.0));
    });

    test('17. calculateMaxUsablePoints calculates boundary points eligible for cart amount', () {
      final maxPts = StoreDetailsCalculator.calculateMaxUsablePoints(
        availablePoints: 1000,
        maxEligibleAmount: 4200.0,
      );
      expect(maxPts, equals(420)); // 420 * 10 = 4200 IQD
    });

    test('18. calculatePointsDiscount returns 0.0 for negative or zero points', () {
      expect(
        StoreDetailsCalculator.calculatePointsDiscount(
          usedPoints: -50,
          availablePoints: 200,
          maxEligibleAmount: 5000.0,
        ),
        equals(0.0),
      );
    });
  });

  group('Store Details Domain — Wallet Payment & 5% Discount Tests', () {
    test('19. calculateWalletDiscount applies 5% discount when wallet payment is selected', () {
      final disc = StoreDetailsCalculator.calculateWalletDiscount(
        eligibleSubtotal: 20000.0,
        isWalletSelected: true,
      );
      expect(disc, equals(1000.0)); // 20000 * 0.05
    });

    test('20. calculateWalletDiscount returns 0.0 when cash is selected', () {
      final disc = StoreDetailsCalculator.calculateWalletDiscount(
        eligibleSubtotal: 20000.0,
        isWalletSelected: false,
      );
      expect(disc, equals(0.0));
    });

    test('21. calculateWalletDiscount applies 5% only on remaining subtotal after points discount', () {
      const subtotal = 20000.0;
      const pointsDisc = 4000.0; // Remaining = 16000
      final walletDisc = StoreDetailsCalculator.calculateWalletDiscount(
        eligibleSubtotal: subtotal - pointsDisc,
        isWalletSelected: true,
      );
      expect(walletDisc, equals(800.0)); // 16000 * 0.05
    });

    test('22. validateWalletPayment returns true when user balance >= finalTotal', () {
      expect(
        StoreDetailsCalculator.validateWalletPayment(
          userBalance: 25000.0,
          finalTotal: 21500.0,
        ),
        isTrue,
      );
      expect(
        StoreDetailsCalculator.validateWalletPayment(
          userBalance: 21500.0,
          finalTotal: 21500.0,
        ),
        isTrue,
      );
    });

    test('23. validateWalletPayment returns false when user balance is insufficient or negative', () {
      expect(
        StoreDetailsCalculator.validateWalletPayment(
          userBalance: 15000.0,
          finalTotal: 21500.0,
        ),
        isFalse,
      );
      expect(
        StoreDetailsCalculator.validateWalletPayment(
          userBalance: -500.0,
          finalTotal: 1000.0,
        ),
        isFalse,
      );
    });
  });

  group('Store Details Domain — Final Total & Earned Points Tests', () {
    test('24. calculateFinalTotal adds deliveryFee and deducts all discounts safely', () {
      final total = StoreDetailsCalculator.calculateFinalTotal(
        subtotal: 30000.0,
        deliveryFee: 1500.0,
        pointsDiscount: 2000.0,
        walletDiscount: 1400.0,
      );
      // 30000 + 1500 - 2000 - 1400 = 28100
      expect(total, equals(28100.0));
    });

    test('25. calculateFinalTotal clamps to 0.0 if discounts exceed subtotal + deliveryFee', () {
      final total = StoreDetailsCalculator.calculateFinalTotal(
        subtotal: 5000.0,
        deliveryFee: 1500.0,
        pointsDiscount: 10000.0,
        walletDiscount: 0.0,
      );
      expect(total, equals(0.0));
    });

    test('26. calculateEarnedPoints awards 1 pt per 1000 IQD of final total', () {
      expect(StoreDetailsCalculator.calculateEarnedPoints(12500.0), equals(12));
      expect(StoreDetailsCalculator.calculateEarnedPoints(999.0), equals(0));
      expect(StoreDetailsCalculator.calculateEarnedPoints(0.0), equals(0));
      expect(StoreDetailsCalculator.calculateEarnedPoints(150000.0), equals(150));
    });
  });

  group('Store Details Domain — Checkout Validation Tests', () {
    final validItems = [
      StoreCartItemEntity(productId: 'p1', name: 'تمر برحي', price: 5000.0, quantity: 2),
    ];

    test('27. validateCheckout rejects empty cart', () {
      final res = StoreDetailsCalculator.validateCheckout(
        items: [],
        customerName: 'علي جاسم',
        customerPhone: '07701234567',
        address: 'بغداد - الكرادة',
        paymentMethod: StorePaymentMethod.cash,
        userBalance: 0.0,
        finalTotal: 11500.0,
      );
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('EMPTY_CART'));
    });

    test('28. validateCheckout rejects empty recipient name', () {
      final res = StoreDetailsCalculator.validateCheckout(
        items: validItems,
        customerName: '   ',
        customerPhone: '07701234567',
        address: 'بغداد - الكرادة',
        paymentMethod: StorePaymentMethod.cash,
        userBalance: 0.0,
        finalTotal: 11500.0,
      );
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('EMPTY_NAME'));
    });

    test('29. validateCheckout rejects empty phone number', () {
      final res = StoreDetailsCalculator.validateCheckout(
        items: validItems,
        customerName: 'علي جاسم',
        customerPhone: '',
        address: 'بغداد - الكرادة',
        paymentMethod: StorePaymentMethod.cash,
        userBalance: 0.0,
        finalTotal: 11500.0,
      );
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('EMPTY_PHONE'));
    });

    test('30. validateCheckout rejects empty address', () {
      final res = StoreDetailsCalculator.validateCheckout(
        items: validItems,
        customerName: 'علي جاسم',
        customerPhone: '07701234567',
        address: '',
        paymentMethod: StorePaymentMethod.cash,
        userBalance: 0.0,
        finalTotal: 11500.0,
      );
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('EMPTY_ADDRESS'));
    });

    test('31. validateCheckout rejects wallet payment with insufficient balance', () {
      final res = StoreDetailsCalculator.validateCheckout(
        items: validItems,
        customerName: 'علي جاسم',
        customerPhone: '07701234567',
        address: 'بغداد - المنصور',
        paymentMethod: StorePaymentMethod.wallet,
        userBalance: 5000.0, // Insufficient for 11500
        finalTotal: 11500.0,
      );
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('INSUFFICIENT_WALLET_BALANCE'));
    });

    test('32. validateCheckout passes for valid cash and wallet checkouts', () {
      final cashRes = StoreDetailsCalculator.validateCheckout(
        items: validItems,
        customerName: 'علي جاسم',
        customerPhone: '07701234567',
        address: 'بغداد - المنصور',
        paymentMethod: StorePaymentMethod.cash,
        userBalance: 0.0,
        finalTotal: 11500.0,
      );
      expect(cashRes.isValid, isTrue);

      final walletRes = StoreDetailsCalculator.validateCheckout(
        items: validItems,
        customerName: 'علي جاسم',
        customerPhone: '07701234567',
        address: 'بغداد - المنصور',
        paymentMethod: StorePaymentMethod.wallet,
        userBalance: 20000.0,
        finalTotal: 11500.0,
      );
      expect(walletRes.isValid, isTrue);
    });
  });

  group('Store Details Domain — Summary & Snapshot Construction Tests', () {
    final items = [
      StoreCartItemEntity(productId: 'p1', name: 'لبن أربيل', price: 2000.0, quantity: 3), // 6000
      StoreCartItemEntity(productId: 'p2', name: 'جبن كيري', price: 4000.0, quantity: 1), // 4000
    ];

    test('33. buildCheckoutSummary builds accurate summary for Cash order with Points', () {
      final summary = StoreDetailsCalculator.buildCheckoutSummary(
        items: items,
        storeDeliveryFee: 1500.0,
        availablePoints: 300,
        requestedPoints: 200,
        usePoints: true,
        paymentMethod: StorePaymentMethod.cash,
        userBalance: 5000.0,
      );

      // Subtotal = 10000
      // Delivery = 1500
      // Points Disc = 200 * 10 = 2000
      // Wallet Disc = 0
      // Final Total = 10000 + 1500 - 2000 = 9500
      // Earned Pts = (9500 / 1000) = 9
      expect(summary.subtotal, equals(10000.0));
      expect(summary.deliveryFee, equals(1500.0));
      expect(summary.pointsUsed, equals(200));
      expect(summary.pointsDiscount, equals(2000.0));
      expect(summary.walletDiscount, equals(0.0));
      expect(summary.totalDiscount, equals(2000.0));
      expect(summary.finalTotal, equals(9500.0));
      expect(summary.pointsEarned, equals(9));
      expect(summary.paymentStatus, equals(StorePaymentStatus.cashOnDelivery));
    });

    test('34. buildCheckoutSummary builds accurate summary for Wallet order with 5% discount', () {
      final summary = StoreDetailsCalculator.buildCheckoutSummary(
        items: items,
        storeDeliveryFee: 1500.0,
        availablePoints: 300,
        requestedPoints: 200,
        usePoints: true,
        paymentMethod: StorePaymentMethod.wallet,
        userBalance: 50000.0,
      );

      // Subtotal = 10000
      // Points Disc = 2000 (Remaining Subtotal = 8000)
      // Wallet Disc = 8000 * 0.05 = 400
      // Total Disc = 2400
      // Final Total = 10000 + 1500 - 2400 = 9100
      // Earned Pts = (9100 / 1000) = 9
      expect(summary.subtotal, equals(10000.0));
      expect(summary.deliveryFee, equals(1500.0));
      expect(summary.pointsDiscount, equals(2000.0));
      expect(summary.walletDiscount, equals(400.0));
      expect(summary.totalDiscount, equals(2400.0));
      expect(summary.finalTotal, equals(9100.0));
      expect(summary.pointsEarned, equals(9));
      expect(summary.canPayWithWallet, isTrue);
      expect(summary.paymentStatus, equals(StorePaymentStatus.paidWallet));
    });

    test('35. buildFinancialSnapshot produces expected serializable database map', () {
      final summary = StoreDetailsCalculator.buildCheckoutSummary(
        items: items,
        storeDeliveryFee: 1500.0,
        availablePoints: 0,
        requestedPoints: 0,
        usePoints: false,
        paymentMethod: StorePaymentMethod.cash,
        userBalance: 0.0,
      );
      final snapshot = StoreDetailsCalculator.buildFinancialSnapshot(summary: summary);
      final map = snapshot.toMap();

      expect(map['subTotal'], equals(10000.0));
      expect(map['deliveryFee'], equals(1500.0));
      expect(map['total'], equals(11500.0));
      expect(map['discount'], equals(0.0));
      expect(map['pointsUsed'], equals(0));
      expect(map['pointsEarned'], equals(11));
      expect(map['paymentStatus'], equals('cash_on_delivery'));
    });
  });

  group('Store Details Domain — Determinism & Invariant Edge Cases', () {
    test('36. Pure determinism: identical inputs generate identical summary and hash code', () {
      final items = [
        StoreCartItemEntity(productId: 'det_1', name: 'شاي', price: 3000.0, quantity: 2),
      ];
      final summary1 = StoreDetailsCalculator.buildCheckoutSummary(
        items: items,
        storeDeliveryFee: 1500.0,
        availablePoints: 100,
        requestedPoints: 100,
        usePoints: true,
        paymentMethod: StorePaymentMethod.wallet,
        userBalance: 20000.0,
      );
      final summary2 = StoreDetailsCalculator.buildCheckoutSummary(
        items: items,
        storeDeliveryFee: 1500.0,
        availablePoints: 100,
        requestedPoints: 100,
        usePoints: true,
        paymentMethod: StorePaymentMethod.wallet,
        userBalance: 20000.0,
      );

      expect(summary1, equals(summary2));
      expect(summary1.hashCode, equals(summary2.hashCode));
    });

    test('37. StorePaymentMethod & StorePaymentStatus parse from/to string safely', () {
      expect(StorePaymentMethod.fromString('wallet'), equals(StorePaymentMethod.wallet));
      expect(StorePaymentMethod.fromString('paid_wallet'), equals(StorePaymentMethod.wallet));
      expect(StorePaymentMethod.fromString('cash'), equals(StorePaymentMethod.cash));
      expect(StorePaymentMethod.fromString(null), equals(StorePaymentMethod.cash));

      expect(StorePaymentStatus.fromString('paid_wallet'), equals(StorePaymentStatus.paidWallet));
      expect(StorePaymentStatus.fromString('cash_on_delivery'), equals(StorePaymentStatus.cashOnDelivery));
      expect(StorePaymentStatus.fromString('pending'), equals(StorePaymentStatus.pending));
      expect(StorePaymentStatus.fromString('invalid'), equals(StorePaymentStatus.unknown));
    });
  });
}
