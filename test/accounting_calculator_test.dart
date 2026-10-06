import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/delivery/domain/entities/delivery_accounting_models.dart';
import 'package:dalal_alqaim/features/delivery/domain/services/accounting_calculator.dart';

void main() {
  group('AccountingCalculator Financial & Date Unit Tests', () {
    test('startOfWeek should accurately align to Saturday', () {
      // 2026-08-26 is Wednesday
      final wednesday = DateTime(2026, 8, 26, 14, 30);
      final saturday = AccountingCalculator.startOfWeek(wednesday);

      expect(saturday.year, equals(2026));
      expect(saturday.month, equals(8));
      expect(saturday.day, equals(22)); // Previous Saturday was August 22
      expect(saturday.weekday, equals(DateTime.saturday));

      // Test on a Saturday itself
      final sat = DateTime(2026, 8, 22, 10, 0);
      expect(AccountingCalculator.startOfWeek(sat).day, equals(22));

      // Test on a Friday (last day of week)
      final fri = DateTime(2026, 8, 28, 23, 59);
      expect(AccountingCalculator.startOfWeek(fri).day, equals(22));
    });

    test('endOfWeek should be Friday 23:59:59', () {
      final sat = DateTime(2026, 8, 22);
      final end = AccountingCalculator.endOfWeek(sat);

      expect(end.year, equals(2026));
      expect(end.month, equals(8));
      expect(end.day, equals(28));
      expect(end.hour, equals(23));
      expect(end.minute, equals(59));
      expect(end.second, equals(59));
    });

    test('parseOrderTotal and parseDeliveryFee should handle numbers and malformed strings', () {
      expect(AccountingCalculator.parseOrderTotal(15000), equals(15000.0));
      expect(AccountingCalculator.parseOrderTotal('15,000 د.ع'), equals(15000.0));
      expect(AccountingCalculator.parseOrderTotal(null), equals(0.0));
      expect(AccountingCalculator.parseOrderTotal('invalid'), equals(0.0));

      expect(AccountingCalculator.parseDeliveryFee(3000), equals(3000.0));
      expect(AccountingCalculator.parseDeliveryFee('3000.5'), equals(3000.5));
      expect(AccountingCalculator.parseDeliveryFee(null), equals(0.0));
    });

    test('Single delivery commission behavior', () {
      expect(AccountingCalculator.calculateDriverOrderCommission(DeliveryOrderType.foodOrder), equals(500.0));
      expect(AccountingCalculator.calculateDriverOrderCommission(DeliveryOrderType.storeOrder), equals(500.0));
      expect(AccountingCalculator.calculateDriverOrderCommission(DeliveryOrderType.rideDelivery), equals(0.0));
      expect(AccountingCalculator.calculateDriverOrderCommission(DeliveryOrderType.unknown), equals(0.0));
    });

    test('Multiple deliveries driver earnings and platform commission', () {
      final orders = [
        DeliveryOrderRecord(
          id: 'ord-1',
          type: DeliveryOrderType.foodOrder,
          totalAmount: 25000,
          deliveryFee: 3000,
          createdAt: DateTime(2026, 8, 23),
        ),
        DeliveryOrderRecord(
          id: 'ord-2',
          type: DeliveryOrderType.storeOrder,
          totalAmount: 50000,
          deliveryFee: 4000,
          createdAt: DateTime(2026, 8, 24),
        ),
        DeliveryOrderRecord(
          id: 'ord-3',
          type: DeliveryOrderType.rideDelivery,
          totalAmount: 5000,
          deliveryFee: 5000,
          createdAt: DateTime(2026, 8, 25),
        ),
      ];

      final calc = AccountingCalculator.calculateDriverEarnings(orders);
      // Total delivery fees: 3000 + 4000 + 5000 = 12000
      expect(calc.totalDeliveryFees, equals(12000.0));
      // Platform commission: 500 (food) + 500 (store) + 0 (ride) = 1000
      expect(calc.platformCommission, equals(1000.0));
      // Net earnings: 12000 - 1000 = 11000
      expect(calc.netEarnings, equals(11000.0));
    });

    test('Merchant earnings and 10% platform commission', () {
      final orders = [
        DeliveryOrderRecord(
          id: 'ord-1',
          type: DeliveryOrderType.foodOrder,
          totalAmount: 20000,
          deliveryFee: 3000,
          createdAt: DateTime(2026, 8, 23),
        ),
        DeliveryOrderRecord(
          id: 'ord-2',
          type: DeliveryOrderType.foodOrder,
          totalAmount: 30000,
          deliveryFee: 3000,
          createdAt: DateTime(2026, 8, 24),
        ),
      ];

      final merchantCalc = AccountingCalculator.calculateMerchantEarnings(orders);
      // Total sales: 20000 + 30000 = 50000
      expect(merchantCalc.totalSales, equals(50000.0));
      // 10% commission: 50000 * 0.10 = 5000
      expect(merchantCalc.platformCommission, equals(5000.0));
      // Net payout: 50000 - 5000 = 45000
      expect(merchantCalc.netPayout, equals(45000.0));
    });

    test('groupOrdersByWeek should group orders into chronological weekly summaries', () {
      final orders = [
        // Week 1 (Aug 22 to Aug 28, 2026)
        DeliveryOrderRecord(
          id: 'w1-1',
          type: DeliveryOrderType.foodOrder,
          totalAmount: 10000,
          deliveryFee: 3000,
          createdAt: DateTime(2026, 8, 23),
        ),
        // Week 2 (Aug 15 to Aug 21, 2026)
        DeliveryOrderRecord(
          id: 'w2-1',
          type: DeliveryOrderType.foodOrder,
          totalAmount: 12000,
          deliveryFee: 3000,
          createdAt: DateTime(2026, 8, 16),
        ),
      ];

      final summaries = AccountingCalculator.groupOrdersByWeek(orders);
      expect(summaries.length, equals(2));
      // Sorted descending: newest first
      expect(summaries.first.weekStart.day, equals(22));
      expect(summaries.last.weekStart.day, equals(15));
      expect(summaries.first.orders.length, equals(1));
      expect(summaries.last.orders.length, equals(1));
    });

    test('Empty orders dataset returns empty summaries', () {
      final summaries = AccountingCalculator.groupOrdersByWeek([]);
      expect(summaries, isEmpty);
    });
  });
}
