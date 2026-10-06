import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/stores_analytics/domain/entities/store_analytics_models.dart';
import 'package:dalal_alqaim/features/stores_analytics/domain/services/store_analytics_calculator.dart';

void main() {
  group('StoreAnalyticsCalculator Unit Tests', () {
    test('parseOrderPrice should safely parse numbers and formatted currency strings', () {
      expect(StoreAnalyticsCalculator.parseOrderPrice(25000), equals(25000.0));
      expect(StoreAnalyticsCalculator.parseOrderPrice('25,000 د.ع'), equals(25000.0));
      expect(StoreAnalyticsCalculator.parseOrderPrice('34.50'), equals(34.50));
      expect(StoreAnalyticsCalculator.parseOrderPrice(null), equals(0.0));
      expect(StoreAnalyticsCalculator.parseOrderPrice('unknown'), equals(0.0));
    });

    test('calculateTotalSalesRevenue should only sum completed and delivered orders', () {
      final orders = [
        const StoreOrderRecord(id: '1', storeId: 's1', totalPrice: 10000, status: 'completed'),
        const StoreOrderRecord(id: '2', storeId: 's1', totalPrice: 15000, status: 'delivered'),
        const StoreOrderRecord(id: '3', storeId: 's2', totalPrice: 20000, status: 'تم التسليم'),
        const StoreOrderRecord(id: '4', storeId: 's2', totalPrice: 50000, status: 'pending'),
        const StoreOrderRecord(id: '5', storeId: 's1', totalPrice: 30000, status: 'cancelled'),
      ];

      final total = StoreAnalyticsCalculator.calculateTotalSalesRevenue(orders);
      expect(total, equals(45000.0)); // 10000 + 15000 + 20000

      final completedCount = StoreAnalyticsCalculator.countCompletedOrders(orders);
      expect(completedCount, equals(3));
    });

    test('countPendingRequests should accurately count non-approved non-rejected stores', () {
      const stores = [
        StoreRecord(id: '1', storeName: 'S1', ownerName: 'O1', phone: '111', isApproved: false, status: 'pending'),
        StoreRecord(id: '2', storeName: 'S2', ownerName: 'O2', phone: '222', isApproved: true, status: 'active'),
        StoreRecord(id: '3', storeName: 'S3', ownerName: 'O3', phone: '333', isApproved: false, status: 'rejected'),
        StoreRecord(id: '4', storeName: 'S4', ownerName: 'O4', phone: '444', isApproved: false, status: ''),
      ];

      final pending = StoreAnalyticsCalculator.countPendingRequests(stores);
      expect(pending, equals(2)); // S1 (pending), S4 (unapproved & not rejected)
    });

    test('filterStores should filter by store name, owner, and phone number', () {
      const stores = [
        StoreRecord(id: '1', storeName: 'متجر السلام', ownerName: 'أحمد علي', phone: '07701234567', isApproved: true, status: 'active'),
        StoreRecord(id: '2', storeName: 'سوبرماركت الأمل', ownerName: 'حيدر كريم', phone: '07809876543', isApproved: true, status: 'active'),
        StoreRecord(id: '3', storeName: 'مخبز البركة', ownerName: 'عمر عثمان', phone: '07501112233', isApproved: true, status: 'active'),
      ];

      expect(StoreAnalyticsCalculator.filterStores(stores, 'السلام').length, equals(1));
      expect(StoreAnalyticsCalculator.filterStores(stores, 'حيدر').length, equals(1));
      expect(StoreAnalyticsCalculator.filterStores(stores, '0750').length, equals(1));
      expect(StoreAnalyticsCalculator.filterStores(stores, '').length, equals(3));
      expect(StoreAnalyticsCalculator.filterStores(stores, 'غير موجود').length, equals(0));
    });

    test('aggregateStoreSales should aggregate metrics per storeId', () {
      final orders = [
        const StoreOrderRecord(id: '1', storeId: 'store_a', totalPrice: 10000, status: 'completed'),
        const StoreOrderRecord(id: '2', storeId: 'store_a', totalPrice: 5000, status: 'completed'),
        const StoreOrderRecord(id: '3', storeId: 'store_b', totalPrice: 30000, status: 'completed'),
        const StoreOrderRecord(id: '4', storeId: 'store_b', totalPrice: 20000, status: 'cancelled'),
      ];

      final map = StoreAnalyticsCalculator.aggregateStoreSales(orders);
      expect(map['store_a']?.totalSales, equals(15000.0));
      expect(map['store_a']?.completedCount, equals(2));
      expect(map['store_b']?.totalSales, equals(30000.0));
      expect(map['store_b']?.completedCount, equals(1));
    });

    test('calculateOverallSummary handles empty and full datasets', () {
      final emptySummary = StoreAnalyticsCalculator.calculateOverallSummary(
        allStores: const [],
        allOrders: const [],
      );
      expect(emptySummary.totalRegisteredStoresCount, equals(0));
      expect(emptySummary.totalSalesRevenue, equals(0.0));
      expect(emptySummary.pendingRequestsCount, equals(0));
      expect(emptySummary.completedOrdersCount, equals(0));
    });
  });
}
