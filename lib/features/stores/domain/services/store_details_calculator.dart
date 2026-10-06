// حاسبة العمليات المالية وخصومات نقاط ومحفظة متجر مدار (Store Details & Checkout Calculator)
// Pure Dart — Zero Flutter / Firebase Dependencies

import '../entities/store_cart_item_entity.dart';
import '../entities/store_checkout_models.dart';

/// الحاسبة النقية لجميع العمليات الحسابية والمالية لسلة وتفاصيل المتجر وإتمام الطلب
class StoreDetailsCalculator {
  const StoreDetailsCalculator._();

  /// الأجرة الافتراضية للتوصيل (1,500 د.ع)
  static const double defaultDeliveryFee = 1500.0;

  /// نسبة خصم الدفع عبر المحفظة (5%)
  static const double walletDiscountRate = 0.05;

  /// سعر تحويل كل 100 نقطة إلى دينار (100 نقطة = 1000 د.ع أي 1 نقطة = 10 د.ع)
  static const double pointsToIqdRate = 10.0;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 1. حسابات السلة والأصناف (Cart Calculations) ───────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// حساب الإجمالي الفرعي لعنصر مفرد
  static double calculateItemSubtotal(StoreCartItemEntity item) {
    final price = item.price;
    final qty = item.quantity;
    if (price.isNaN || price.isInfinite || price < 0.0 || qty <= 0) {
      return 0.0;
    }
    return price * qty;
  }

  /// حساب الإجمالي الفرعي لكافة عناصر السلة
  static double calculateCartSubtotal(List<StoreCartItemEntity> items) {
    if (items.isEmpty) return 0.0;
    double sum = 0.0;
    for (final item in items) {
      sum += calculateItemSubtotal(item);
    }
    return sum;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 2. حسابات رسوم التوصيل (Delivery Fee) ──────────────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// حساب رسوم التوصيل مع مراعاة قيمة المتجر أو القيمة الافتراضية
  static double calculateDeliveryFee({
    double? storeDeliveryFee,
    double fallbackFee = defaultDeliveryFee,
  }) {
    if (storeDeliveryFee != null &&
        !storeDeliveryFee.isNaN &&
        !storeDeliveryFee.isInfinite &&
        storeDeliveryFee >= 0.0) {
      return storeDeliveryFee;
    }
    return fallbackFee >= 0.0 ? fallbackFee : defaultDeliveryFee;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 3. حسابات الخصومات ونقاط مدار (Discounts & Loyalty Points) ─────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// تحويل النقاط إلى قيمة مالية بالدينار العراقي (100 نقطة = 1,000 د.ع)
  static double convertPointsToDiscount(int points) {
    if (points <= 0) return 0.0;
    return (points / 100.0) * 1000.0;
  }

  /// حساب أقصى عدد نقاط يمكن استخدامها دون تجاوز قيمة المبلغ المستحق
  static int calculateMaxUsablePoints({
    required int availablePoints,
    required double maxEligibleAmount,
  }) {
    if (availablePoints <= 0 || maxEligibleAmount <= 0.0) return 0;
    final maxPtsForAmount = (maxEligibleAmount / pointsToIqdRate).floor();
    return availablePoints < maxPtsForAmount ? availablePoints : maxPtsForAmount;
  }

  /// حساب قيمة خصم النقاط الفعلي المطبق
  static double calculatePointsDiscount({
    required int usedPoints,
    required int availablePoints,
    required double maxEligibleAmount,
  }) {
    if (usedPoints <= 0 || availablePoints <= 0 || maxEligibleAmount <= 0.0) {
      return 0.0;
    }
    final safePoints = usedPoints > availablePoints ? availablePoints : usedPoints;
    final rawDiscount = convertPointsToDiscount(safePoints);
    return rawDiscount > maxEligibleAmount ? maxEligibleAmount : rawDiscount;
  }

  /// حساب خصم الدفع بالمحفظة (5% على المبلغ المتبقي بعد خصم النقاط)
  static double calculateWalletDiscount({
    required double eligibleSubtotal,
    required bool isWalletSelected,
    double rate = walletDiscountRate,
  }) {
    if (!isWalletSelected || eligibleSubtotal <= 0.0 || rate <= 0.0) {
      return 0.0;
    }
    return eligibleSubtotal * rate;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 4. الإجمالي النهائي والنقاط المكتسبة (Final Total & Points Earned) ──
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// حساب الإجمالي النهائي بعد كافة الخصومات ورسوم التوصيل
  static double calculateFinalTotal({
    required double subtotal,
    required double deliveryFee,
    required double pointsDiscount,
    required double walletDiscount,
  }) {
    final safeSubtotal = subtotal < 0.0 || subtotal.isNaN ? 0.0 : subtotal;
    final safeDelivery = deliveryFee < 0.0 || deliveryFee.isNaN ? 0.0 : deliveryFee;
    final safePointsDisc = pointsDiscount < 0.0 || pointsDiscount.isNaN ? 0.0 : pointsDiscount;
    final safeWalletDisc = walletDiscount < 0.0 || walletDiscount.isNaN ? 0.0 : walletDiscount;

    final totalBeforeDiscount = safeSubtotal + safeDelivery;
    final totalDiscounts = safePointsDisc + safeWalletDisc;
    final total = totalBeforeDiscount - totalDiscounts;

    return total < 0.0 ? 0.0 : total;
  }

  /// حساب النقاط المكتسبة من الطلب (1 نقطة لكل 1,000 د.ع من الإجمالي النهائي)
  static int calculateEarnedPoints(double finalTotal) {
    if (finalTotal.isNaN || finalTotal.isInfinite || finalTotal <= 0.0) {
      return 0;
    }
    return (finalTotal / 1000.0).floor();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 5. التحقق من صحة الدفع والطلب (Validations) ────────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// التحقق من كفاية رصيد المحفظة لتغطية الإجمالي المطلوب
  static bool validateWalletPayment({
    required double userBalance,
    required double finalTotal,
  }) {
    if (userBalance.isNaN || userBalance.isInfinite || userBalance < 0.0) {
      return false;
    }
    if (finalTotal.isNaN || finalTotal.isInfinite || finalTotal < 0.0) {
      return false;
    }
    return userBalance >= finalTotal;
  }

  /// التحقق الشامل من صحة بيانات إتمام الطلب
  static StoreCheckoutValidationResult validateCheckout({
    required List<StoreCartItemEntity> items,
    required String customerName,
    required String customerPhone,
    required String address,
    required StorePaymentMethod paymentMethod,
    required double userBalance,
    required double finalTotal,
  }) {
    if (items.isEmpty) {
      return StoreCheckoutValidationResult.invalid(
        message: 'سلة المشتريات فارغة',
        code: 'EMPTY_CART',
      );
    }

    if (customerName.trim().isEmpty) {
      return StoreCheckoutValidationResult.invalid(
        message: 'يرجى إدخال اسم المستلم',
        code: 'EMPTY_NAME',
      );
    }

    if (customerPhone.trim().isEmpty) {
      return StoreCheckoutValidationResult.invalid(
        message: 'يرجى إدخال رقم الهاتف للتواصل',
        code: 'EMPTY_PHONE',
      );
    }

    if (address.trim().isEmpty) {
      return StoreCheckoutValidationResult.invalid(
        message: 'يرجى تحديد عنوان التوصيل',
        code: 'EMPTY_ADDRESS',
      );
    }

    if (paymentMethod == StorePaymentMethod.wallet) {
      if (!validateWalletPayment(userBalance: userBalance, finalTotal: finalTotal)) {
        return StoreCheckoutValidationResult.invalid(
          message: 'رصيد المحفظة غير كافٍ لإتمام هذا الطلب',
          code: 'INSUFFICIENT_WALLET_BALANCE',
        );
      }
    }

    return StoreCheckoutValidationResult.valid;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 6. بناء الملخص واللقطة المالية (Summary & Snapshot Builders) ──────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// بناء الملخص المالي الشامل لشاشة إتمام الطلب (Checkout Summary)
  static StoreCheckoutSummaryEntity buildCheckoutSummary({
    required List<StoreCartItemEntity> items,
    double? storeDeliveryFee,
    required int availablePoints,
    required int requestedPoints,
    required bool usePoints,
    required StorePaymentMethod paymentMethod,
    required double userBalance,
  }) {
    final subtotal = calculateCartSubtotal(items);
    final deliveryFee = calculateDeliveryFee(storeDeliveryFee: storeDeliveryFee);

    final pointsDiscount = usePoints
        ? calculatePointsDiscount(
            usedPoints: requestedPoints,
            availablePoints: availablePoints,
            maxEligibleAmount: subtotal,
          )
        : 0.0;

    final actualPointsUsed = usePoints
        ? (pointsDiscount > 0 ? (pointsDiscount / pointsToIqdRate).round() : 0)
        : 0;

    final remainingSubtotal = (subtotal - pointsDiscount) < 0.0 ? 0.0 : (subtotal - pointsDiscount);
    final isWallet = paymentMethod == StorePaymentMethod.wallet;
    final walletDiscount = calculateWalletDiscount(
      eligibleSubtotal: remainingSubtotal,
      isWalletSelected: isWallet,
    );

    final totalDiscount = pointsDiscount + walletDiscount;
    final finalTotal = calculateFinalTotal(
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      pointsDiscount: pointsDiscount,
      walletDiscount: walletDiscount,
    );

    final pointsEarned = calculateEarnedPoints(finalTotal);
    final canPayWithWallet = validateWalletPayment(
      userBalance: userBalance,
      finalTotal: finalTotal,
    );

    final paymentStatus = isWallet
        ? StorePaymentStatus.paidWallet
        : StorePaymentStatus.cashOnDelivery;

    return StoreCheckoutSummaryEntity(
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      pointsUsed: actualPointsUsed,
      pointsDiscount: pointsDiscount,
      walletDiscount: walletDiscount,
      totalDiscount: totalDiscount,
      finalTotal: finalTotal,
      pointsEarned: pointsEarned,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      userBalance: userBalance,
      userPoints: availablePoints,
      canPayWithWallet: canPayWithWallet,
    );
  }

  /// بناء اللقطة المالية الصافية وغير القابلة للتعديل للحفظ في قاعدة البيانات
  static StoreOrderFinancialSnapshot buildFinancialSnapshot({
    required StoreCheckoutSummaryEntity summary,
  }) {
    return StoreOrderFinancialSnapshot(
      subtotal: summary.subtotal,
      deliveryFee: summary.deliveryFee,
      totalDiscount: summary.totalDiscount,
      pointsUsed: summary.pointsUsed,
      pointsDiscount: summary.pointsDiscount,
      walletDiscount: summary.walletDiscount,
      finalTotal: summary.finalTotal,
      pointsEarned: summary.pointsEarned,
      paymentStatus: summary.paymentStatus.toDbString(),
    );
  }
}
