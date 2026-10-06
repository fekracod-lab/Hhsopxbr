import '../entities/delivery_accounting_models.dart';

/// محرك الحسابات المالية المجرد لمنظومة المحاسبة الأسبوعية (Pure Dart Accounting Calculator)
/// خالي تماماً من أي تبعيات لواجهة المستخدم أو قواعد البيانات أو الطباعة.
class AccountingCalculator {
  const AccountingCalculator._();

  /// حساب بداية الأسبوع المعتمد للمنصة (يبدأ الأسبوع يوم السبت Saturday)
  static DateTime startOfWeek(DateTime date) {
    int diff = date.weekday - DateTime.saturday;
    if (diff < 0) diff += 7;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: diff));
  }

  /// حساب نهاية الأسبوع المعتمد (الجمعة 23:59:59)
  static DateTime endOfWeek(DateTime weekStart) {
    return weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  }

  /// استخراج القيمة المالية الإجمالية للطلب بأمان من مختلف الحقول المحتملة
  static double parseOrderTotal(dynamic totalField) {
    if (totalField == null) return 0.0;
    if (totalField is num) return totalField.toDouble();
    if (totalField is String) {
      return double.tryParse(totalField.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    }
    return 0.0;
  }

  /// استخراج أجور التوصيل للطلب بأمان
  static double parseDeliveryFee(dynamic feeField) {
    if (feeField == null) return 0.0;
    if (feeField is num) return feeField.toDouble();
    if (feeField is String) {
      return double.tryParse(feeField.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    }
    return 0.0;
  }

  /// حساب عمولة التطبيق لطلب واحد للكابتن
  static double calculateDriverOrderCommission(DeliveryOrderType type) {
    if (type == DeliveryOrderType.foodOrder || type == DeliveryOrderType.storeOrder) {
      return 500.0;
    }
    return 0.0;
  }

  /// تجميع الطلبات في أسابيع محاسبية مرتبة تنازلياً من الأحدث إلى الأقدم
  static List<WeeklySummaryEntity> groupOrdersByWeek(List<DeliveryOrderRecord> orders) {
    if (orders.isEmpty) return const [];

    final Map<DateTime, List<DeliveryOrderRecord>> grouped = {};
    for (final order in orders) {
      final weekStart = startOfWeek(order.createdAt);
      grouped.putIfAbsent(weekStart, () => []).add(order);
    }

    final List<WeeklySummaryEntity> summaries = [];
    grouped.forEach((weekStart, weekOrders) {
      summaries.add(WeeklySummaryEntity(
        weekStart: weekStart,
        weekEnd: endOfWeek(weekStart),
        orders: List.unmodifiable(weekOrders),
      ));
    });

    summaries.sort((a, b) => b.weekStart.compareTo(a.weekStart));
    return List.unmodifiable(summaries);
  }

  /// حساب أرباح كابتن محدد من مجموعة طلبات
  static ({double totalDeliveryFees, double platformCommission, double netEarnings}) calculateDriverEarnings(
    List<DeliveryOrderRecord> orders,
  ) {
    double totalDeliveryFees = 0.0;
    double platformCommission = 0.0;

    for (final order in orders) {
      totalDeliveryFees += order.deliveryFee;
      platformCommission += calculateDriverOrderCommission(order.type);
    }

    final netEarnings = totalDeliveryFees - platformCommission;
    return (
      totalDeliveryFees: totalDeliveryFees,
      platformCommission: platformCommission,
      netEarnings: netEarnings,
    );
  }

  /// حساب أرباح ومبيعات منشأة (مطعم أو متجر)
  static ({double totalSales, double platformCommission, double netPayout}) calculateMerchantEarnings(
    List<DeliveryOrderRecord> orders,
  ) {
    double totalSales = 0.0;
    for (final order in orders) {
      totalSales += order.totalAmount;
    }

    final platformCommission = totalSales * 0.10;
    final netPayout = totalSales - platformCommission;

    return (
      totalSales: totalSales,
      platformCommission: platformCommission,
      netPayout: netPayout,
    );
  }
}
