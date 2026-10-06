import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../domain/entities/store_analytics_models.dart';

/// بطاقات ملخص إحصائيات المتاجر والمبيعات والطلبات العلوية
class StoreAnalyticsSummaryCards extends StatelessWidget {
  final OverallStoreAnalyticsSummary summary;

  const StoreAnalyticsSummaryCards({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'د.ع', decimalDigits: 0, locale: 'ar');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        return GridView.count(
          crossAxisCount: isWide ? 4 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          childAspectRatio: isWide ? 2.2 : 1.6,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildMetricCard(
              'طلبات انضمام بانتظار الموافقة',
              '${summary.pendingRequestsCount} طلب جديد',
              Icons.pending_actions_rounded,
              const Color(0xFFF59E0B),
            ),
            _buildMetricCard(
              'إجمالي المتاجر المسجلة',
              '${summary.totalRegisteredStoresCount} متجر',
              Icons.storefront_rounded,
              const Color(0xFF00BFA5),
            ),
            _buildMetricCard(
              'إجمالي مبيعات المتاجر',
              currencyFormat.format(summary.totalSalesRevenue),
              Icons.payments_rounded,
              const Color(0xFF10B981),
            ),
            _buildMetricCard(
              'الطلبات المكتملة للمتاجر',
              '${summary.completedOrdersCount} طلب',
              Icons.task_alt_rounded,
              const Color(0xFF3B82F6),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
