import '../entities/store_analytics_models.dart';

/// محرك حسابات وتحليلات المتاجر المجرد (Pure Dart Store Analytics Calculator)
class StoreAnalyticsCalculator {
  const StoreAnalyticsCalculator._();

  /// استخراج القيمة المالية للطلب بأمان من مختلف الحقول المحتملة
  static double parseOrderPrice(dynamic priceField) {
    if (priceField == null) return 0.0;
    if (priceField is num) return priceField.toDouble();
    if (priceField is String) {
      return double.tryParse(priceField.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    }
    return 0.0;
  }

  /// حساب إجمالي مبيعات المتاجر من الطلبات المكتملة
  static double calculateTotalSalesRevenue(List<StoreOrderRecord> orders) {
    double total = 0.0;
    for (final order in orders) {
      if (order.isCompleted) {
        total += order.totalPrice;
      }
    }
    return total;
  }

  /// حساب عدد الطلبات المكتملة
  static int countCompletedOrders(List<StoreOrderRecord> orders) {
    int count = 0;
    for (final order in orders) {
      if (order.isCompleted) {
        count++;
      }
    }
    return count;
  }

  /// حساب عدد طلبات الانضمام بانتظار الموافقة
  static int countPendingRequests(List<StoreRecord> stores) {
    int count = 0;
    for (final store in stores) {
      if (store.isPending) {
        count++;
      }
    }
    return count;
  }

  /// فلترة قائمة المتاجر أو الطلبات حسب نص البحث (الاسم، المالك، الهاتف)
  static List<StoreRecord> filterStores(List<StoreRecord> stores, String searchQuery) {
    if (searchQuery.isEmpty) return stores;
    final query = searchQuery.trim().toLowerCase();

    return stores.where((store) {
      final name = store.storeName.toLowerCase();
      final owner = store.ownerName.toLowerCase();
      final phone = store.phone.toLowerCase();
      return name.contains(query) || owner.contains(query) || phone.contains(query);
    }).toList();
  }

  /// دمج ومعالجة ملخص الإحصائيات الشاملة
  static OverallStoreAnalyticsSummary calculateOverallSummary({
    required List<StoreRecord> allStores,
    required List<StoreOrderRecord> allOrders,
  }) {
    final pendingCount = countPendingRequests(allStores);
    final totalSales = calculateTotalSalesRevenue(allOrders);
    final completedCount = countCompletedOrders(allOrders);

    return OverallStoreAnalyticsSummary(
      pendingRequestsCount: pendingCount,
      totalRegisteredStoresCount: allStores.length,
      totalSalesRevenue: totalSales,
      completedOrdersCount: completedCount,
    );
  }

  /// حساب إحصائيات المبيعات لكل متجر على حدة وتجميعها
  static Map<String, ({double totalSales, int completedCount})> aggregateStoreSales(
    List<StoreOrderRecord> orders,
  ) {
    final Map<String, ({double totalSales, int completedCount})> map = {};

    for (final order in orders) {
      if (!order.isCompleted) continue;

      final current = map[order.storeId] ?? (totalSales: 0.0, completedCount: 0);
      map[order.storeId] = (
        totalSales: current.totalSales + order.totalPrice,
        completedCount: current.completedCount + 1,
      );
    }

    return map;
  }
}
