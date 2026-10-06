import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../domain/entities/delivery_accounting_models.dart';
import 'accounting_transactions_sheet.dart';

/// ويدجت تفصيل مبيعات المنشآت (المطاعم والمتاجر) للأسبوع
class AccountingEntityBreakdown extends StatelessWidget {
  final WeeklySummaryEntity summary;
  final bool isDark;
  final String tabName; // 'restaurants' | 'stores'
  final Map<String, String> entityNamesMap;
  final String? govName;

  const AccountingEntityBreakdown({
    super.key,
    required this.summary,
    required this.isDark,
    required this.tabName,
    required this.entityNamesMap,
    this.govName,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'د.ع', decimalDigits: 0, locale: 'ar');

    final entityWeeklyOrders = <String, List<DeliveryOrderRecord>>{};
    for (final order in summary.orders) {
      final eId = tabName == 'restaurants' ? order.restaurantId : order.storeId;
      if (eId != null && eId.isNotEmpty) {
        entityWeeklyOrders.putIfAbsent(eId, () => []).add(order);
      }
    }

    final entityIds = entityWeeklyOrders.keys.toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entityIds.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final eId = entityIds[index];
        final orders = entityWeeklyOrders[eId] ?? [];

        String entityName = 'منشأة غير معرفة';
        if (tabName == 'restaurants') {
          entityName = entityNamesMap[eId] ?? 'مطعم';
        } else {
          entityName = entityNamesMap[eId] ?? 'متجر';
        }

        double salesSum = 0.0;
        for (final order in orders) {
          salesSum += order.totalAmount;
        }

        final firstChar = entityName.trim().isNotEmpty ? entityName.trim().substring(0, 1) : 'م';

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.05),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            onTap: () => AccountingTransactionsSheet.show(
              context: context,
              title: 'كشف عمليات: $entityName',
              orders: orders,
              tabName: tabName,
              govName: govName,
              restaurantNamesMap: tabName == 'restaurants' ? entityNamesMap : const {},
              storeNamesMap: tabName == 'stores' ? entityNamesMap : const {},
            ),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: (tabName == 'restaurants' ? Colors.orange : Colors.purple).withValues(alpha: 0.12),
              child: Text(
                firstChar,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: tabName == 'restaurants' ? Colors.orange : Colors.purple,
                ),
              ),
            ),
            title: Text(
              entityName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              'العمليات المكتملة: ${orders.length}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currencyFormat.format(salesSum),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF00BFA5) : const Color(0xFF00897B),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
