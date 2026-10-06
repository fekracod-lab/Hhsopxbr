import '../entities/store_dashboard_models.dart';

/// حاسبة العمليات المالية والإحصائية للوحة تحكم المتجر (Store Financial & Statistics Calculator)
/// Pure Dart — Zero Flutter / Firebase Dependencies
class StoreFinancialCalculator {
  const StoreFinancialCalculator._();

  /// 1. حساب إيراد طلب مفرد (فقط إذا كان مكتملاً)
  static double calculateOrderRevenue(StoreOrderEntity order) {
    if (order.orderStatus != StoreOrderStatus.completed) {
      return 0.0;
    }
    final total = order.total;
    if (total.isNaN || total.isInfinite || total < 0.0) {
      return 0.0;
    }
    return total;
  }

  /// 2. حساب إجمالي الإيرادات لكافة الطلبات المكتملة
  static double calculateTotalRevenue(List<StoreOrderEntity> orders) {
    double sum = 0.0;
    for (final order in orders) {
      sum += calculateOrderRevenue(order);
    }
    return sum;
  }

  /// 3. حساب إيراد اليوم لطلبات المتجر المكتملة بناءً على تاريخ مرجعي محدد (Deterministic)
  static double calculateTodayRevenue(
    List<StoreOrderEntity> orders, {
    required DateTime referenceDate,
  }) {
    double sum = 0.0;
    final refYear = referenceDate.year;
    final refMonth = referenceDate.month;
    final refDay = referenceDate.day;

    for (final order in orders) {
      if (order.orderStatus == StoreOrderStatus.completed && order.createdAt != null) {
        final d = order.createdAt!;
        if (d.year == refYear && d.month == refMonth && d.day == refDay) {
          final total = order.total;
          if (!total.isNaN && !total.isInfinite && total > 0.0) {
            sum += total;
          }
        }
      }
    }
    return sum;
  }

  /// 4. حساب إحصائيات الطلبات وتوزيع الحالات والإيرادات
  static StoreOrderStatisticsEntity calculateOrderStatistics(
    List<StoreOrderEntity> orders, {
    DateTime? referenceDate,
  }) {
    if (orders.isEmpty) {
      return StoreOrderStatisticsEntity.empty;
    }

    int pending = 0;
    int accepted = 0;
    int ready = 0;
    int delivering = 0;
    int pickedUp = 0;
    int completed = 0;
    int cancelled = 0;
    double totalRev = 0.0;

    final ref = referenceDate ?? DateTime.now();
    final refYear = ref.year;
    final refMonth = ref.month;
    final refDay = ref.day;
    double todayRev = 0.0;

    for (final order in orders) {
      switch (order.orderStatus) {
        case StoreOrderStatus.pending:
          pending++;
          break;
        case StoreOrderStatus.accepted:
          accepted++;
          break;
        case StoreOrderStatus.ready:
          ready++;
          break;
        case StoreOrderStatus.delivering:
          delivering++;
          break;
        case StoreOrderStatus.pickedUp:
          pickedUp++;
          break;
        case StoreOrderStatus.completed:
          completed++;
          final total = order.total;
          if (!total.isNaN && !total.isInfinite && total > 0.0) {
            totalRev += total;
            if (order.createdAt != null) {
              final d = order.createdAt!;
              if (d.year == refYear && d.month == refMonth && d.day == refDay) {
                todayRev += total;
              }
            }
          }
          break;
        case StoreOrderStatus.cancelled:
          cancelled++;
          break;
        case StoreOrderStatus.unknown:
          break;
      }
    }

    return StoreOrderStatisticsEntity(
      totalOrders: orders.length,
      pendingOrders: pending,
      acceptedOrders: accepted,
      readyOrders: ready,
      deliveringOrders: delivering,
      pickedUpOrders: pickedUp,
      completedOrders: completed,
      cancelledOrders: cancelled,
      totalRevenue: totalRev,
      todayRevenue: todayRev,
    );
  }

  /// 5. حساب الأثر المالي لنقاط مدار ورصيد المحفظة عند تغيير حالة الطلب
  static StoreOrderFinancialEffect calculateOrderFinancialEffect({
    required StoreOrderEntity order,
    required StoreOrderStatus nextStatus,
  }) {
    final oldStatus = order.orderStatus;
    if (oldStatus == nextStatus) {
      return StoreOrderFinancialEffect.none;
    }

    final customerId = order.customerId;
    if (customerId.trim().isEmpty) {
      return StoreOrderFinancialEffect.none;
    }

    // 1. عند إكمال الطلب: منح النقاط المكتسبة
    if (nextStatus == StoreOrderStatus.completed && oldStatus != StoreOrderStatus.completed) {
      final pointsEarned = order.pointsEarned < 0 ? 0 : order.pointsEarned;
      return StoreOrderFinancialEffect(
        customerId: customerId,
        pointsDelta: pointsEarned,
        walletBalanceDelta: 0.0,
        isPointsAwarded: pointsEarned > 0,
      );
    }

    // 2. عند إلغاء الطلب: استرجاع النقاط المستخدمة ورصيد المحفظة إن كان الدفع بالمحفظة
    if (nextStatus == StoreOrderStatus.cancelled && oldStatus != StoreOrderStatus.cancelled) {
      final pointsUsed = order.pointsUsed < 0 ? 0 : order.pointsUsed;
      final safeTotal = order.total < 0.0 || order.total.isNaN ? 0.0 : order.total;
      final isWallet = order.isPaidWithWallet && safeTotal > 0.0;

      return StoreOrderFinancialEffect(
        customerId: customerId,
        pointsDelta: pointsUsed,
        walletBalanceDelta: isWallet ? safeTotal : 0.0,
        isPointsRefunded: pointsUsed > 0,
        isWalletRefunded: isWallet,
      );
    }

    return StoreOrderFinancialEffect.none;
  }

  /// 6. التحقق من صحة وقانونية الانتقال بين حالات الطلب (State Machine Validation)
  static bool canTransitionOrderStatus({
    required StoreOrderStatus currentStatus,
    required StoreOrderStatus nextStatus,
  }) {
    if (currentStatus == nextStatus) return false;

    switch (currentStatus) {
      case StoreOrderStatus.pending:
        return nextStatus == StoreOrderStatus.accepted ||
            nextStatus == StoreOrderStatus.cancelled;

      case StoreOrderStatus.accepted:
        return nextStatus == StoreOrderStatus.ready ||
            nextStatus == StoreOrderStatus.cancelled;

      case StoreOrderStatus.ready:
        return nextStatus == StoreOrderStatus.delivering ||
            nextStatus == StoreOrderStatus.pickedUp ||
            nextStatus == StoreOrderStatus.completed ||
            nextStatus == StoreOrderStatus.cancelled;

      case StoreOrderStatus.delivering:
      case StoreOrderStatus.pickedUp:
        return nextStatus == StoreOrderStatus.completed ||
            nextStatus == StoreOrderStatus.cancelled;

      case StoreOrderStatus.completed:
      case StoreOrderStatus.cancelled:
        return false; // Terminal states

      case StoreOrderStatus.unknown:
        return nextStatus == StoreOrderStatus.cancelled ||
            nextStatus == StoreOrderStatus.pending;
    }
  }

  /// 7. حساب أعداد المنتجات لكل تصنيف (Pure in-memory counting)
  static Map<String, int> calculateCategoryProductCounts({
    required List<StoreCategoryEntity> categories,
    required List<StoreProductEntity> products,
  }) {
    final Map<String, int> counts = {};
    for (final cat in categories) {
      counts[cat.name] = 0;
    }

    for (final prod in products) {
      final cat = prod.category;
      if (counts.containsKey(cat)) {
        counts[cat] = (counts[cat] ?? 0) + 1;
      } else {
        counts[cat] = 1;
      }
    }

    return counts;
  }
}
