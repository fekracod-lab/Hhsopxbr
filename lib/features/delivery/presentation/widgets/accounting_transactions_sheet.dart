import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../domain/entities/delivery_accounting_models.dart';
import '../../services/delivery_accounting_pdf_service.dart';

/// نافذة عرض تفاصيل العمليات وكشف الحساب الأسبوعي
class AccountingTransactionsSheet extends StatelessWidget {
  final String title;
  final List<DeliveryOrderRecord> orders;
  final String tabName;
  final String? govName;
  final Map<String, String> restaurantNamesMap;
  final Map<String, String> storeNamesMap;

  const AccountingTransactionsSheet({
    super.key,
    required this.title,
    required this.orders,
    required this.tabName,
    this.govName,
    this.restaurantNamesMap = const {},
    this.storeNamesMap = const {},
  });

  static void show({
    required BuildContext context,
    required String title,
    required List<DeliveryOrderRecord> orders,
    required String tabName,
    String? govName,
    Map<String, String> restaurantNamesMap = const {},
    Map<String, String> storeNamesMap = const {},
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      builder: (ctx) => AccountingTransactionsSheet(
        title: title,
        orders: orders,
        tabName: tabName,
        govName: govName,
        restaurantNamesMap: restaurantNamesMap,
        storeNamesMap: storeNamesMap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(symbol: 'د.ع', decimalDigits: 0, locale: 'ar');

    final sortedOrders = List<DeliveryOrderRecord>.from(orders);
    sortedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => DeliveryAccountingPdfService.printWeeklyAccountingReport(
                    title: title,
                    orders: sortedOrders,
                    tabName: tabName,
                    govName: govName,
                    restaurantNamesMap: restaurantNamesMap,
                    storeNamesMap: storeNamesMap,
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 18),
                  label: const Text(
                    'كشف PDF',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'عدد العمليات التفصيلي: ${orders.length} عملية بيع',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.separated(
                itemCount: sortedOrders.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final order = sortedOrders[index];
                  final id = order.id;
                  final total = order.totalAmount;
                  final date = order.createdAt;
                  final client = order.customerName ?? 'زبون';
                  final type = order.type;

                  String entityName = '';
                  if (type == DeliveryOrderType.foodOrder) {
                    final restId = order.restaurantId ?? '';
                    entityName = restaurantNamesMap[restId] ?? 'مطعم';
                  } else if (type == DeliveryOrderType.storeOrder) {
                    final storeId = order.storeId ?? '';
                    entityName = storeNamesMap[storeId] ?? 'متجر';
                  } else {
                    entityName = 'طلب دليفري';
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (type == DeliveryOrderType.foodOrder ? Colors.orange : Colors.purple).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            type == DeliveryOrderType.foodOrder ? Icons.restaurant_rounded : Icons.storefront_rounded,
                            color: type == DeliveryOrderType.foodOrder ? Colors.orange : Colors.purple,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$entityName - $client',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    '#${id.substring(0, id.length > 6 ? 6 : id.length).toUpperCase()}',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('yyyy/MM/dd hh:mm:ss a').format(date),
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          currencyFormat.format(total),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF00BFA5) : const Color(0xFF00897B),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
