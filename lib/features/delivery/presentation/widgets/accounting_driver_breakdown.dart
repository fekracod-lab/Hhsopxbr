import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/delivery_accounting_models.dart';
import '../../services/delivery_accounting_pdf_service.dart';
import 'accounting_transactions_sheet.dart';

/// ويدجت تفصيل أرباح وطلبات الكباتن للأسبوع
class AccountingDriverBreakdown extends StatelessWidget {
  final WeeklySummaryEntity summary;
  final bool isDark;
  final bool isManagerMode;
  final Map<String, Map<String, dynamic>> driversMap;
  final String? govName;

  const AccountingDriverBreakdown({
    super.key,
    required this.summary,
    required this.isDark,
    required this.isManagerMode,
    this.driversMap = const {},
    this.govName,
  });

  @override
  Widget build(BuildContext context) {
    if (!isManagerMode) {
      return _buildDriverSingleWeekBreakdown(context);
    }
    return _buildManagerMultiDriverBreakdown(context);
  }

  Widget _buildDriverSingleWeekBreakdown(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'د.ع', decimalDigits: 0, locale: 'ar');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: summary.orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final order = summary.orders[index];
        final type = order.type;
        final id = order.id;
        final fee = order.deliveryFee;
        final date = order.createdAt;

        String typeLabel = 'طلب مطعم';
        IconData typeIcon = Icons.restaurant_rounded;
        Color typeColor = Colors.orange;

        if (type == DeliveryOrderType.storeOrder) {
          typeLabel = 'طلب متجر';
          typeIcon = Icons.storefront_rounded;
          typeColor = Colors.purple;
        } else if (type == DeliveryOrderType.rideDelivery) {
          typeLabel = 'توصيل دليفري';
          typeIcon = Icons.delivery_dining_rounded;
          typeColor = Colors.blue;
        }

        final bool hasCommission = type == DeliveryOrderType.foodOrder || type == DeliveryOrderType.storeOrder;
        final double commission = hasCommission ? 500.0 : 0.0;
        final double net = fee - commission;

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
                  color: typeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(typeIcon, color: typeColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$typeLabel #${id.substring(0, id.length > 6 ? 6 : id.length).toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('yyyy/MM/dd hh:mm a').format(date),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'الربح: ${currencyFormat.format(net)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF00BFA5) : const Color(0xFF00897B),
                    ),
                  ),
                  if (hasCommission)
                    const Text(
                      'عمولة التطبيق: 500 د.ع',
                      style: TextStyle(fontSize: 9, color: Colors.redAccent),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildManagerMultiDriverBreakdown(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'د.ع', decimalDigits: 0, locale: 'ar');

    final driverWeeklyOrders = <String, List<DeliveryOrderRecord>>{};
    for (final order in summary.orders) {
      final dId = order.driverId;
      if (dId != null && dId.isNotEmpty) {
        driverWeeklyOrders.putIfAbsent(dId, () => []).add(order);
      }
    }

    final driverIds = driverWeeklyOrders.keys.toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: driverIds.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final dId = driverIds[index];
        final driverData = driversMap[dId] ?? {};
        final driverName = driverData['fullName'] ?? driverData['name'] ?? 'سائق غير معرف';
        final driverPhone = driverData['phone']?.toString() ?? '';
        final orders = driverWeeklyOrders[dId] ?? [];

        double feesSum = 0.0;
        double commissionSum = 0.0;
        for (final order in orders) {
          feesSum += order.deliveryFee;
          if (order.type == DeliveryOrderType.foodOrder || order.type == DeliveryOrderType.storeOrder) {
            commissionSum += 500.0;
          }
        }
        final netSum = feesSum - commissionSum;
        final firstChar = driverName.trim().isNotEmpty ? driverName.trim().substring(0, 1) : 'س';

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
              title: 'كشف عمليات: $driverName',
              orders: orders,
              tabName: 'drivers',
              govName: govName,
            ),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF00BFA5).withValues(alpha: 0.12),
              child: Text(
                firstChar,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF00897B),
                ),
              ),
            ),
            title: Text(
              driverName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Row(
              children: [
                Text(
                  'الطلبات: ${orders.length}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                if (driverPhone.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      final url = Uri.parse('tel:$driverPhone');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_rounded, color: Color(0xFF00BFA5), size: 12),
                        SizedBox(width: 2),
                        Text(
                          'اتصال',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF00897B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(netSum),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF00BFA5) : const Color(0xFF00897B),
                      ),
                    ),
                    Text(
                      'العمولة: ${currencyFormat.format(commissionSum)}',
                      style: const TextStyle(fontSize: 9, color: Colors.redAccent),
                    ),
                  ],
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
