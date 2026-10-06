import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../domain/entities/store_analytics_models.dart';
import 'store_details_dialog.dart';

/// ويدجت جدول المتاجر المعتمدة وتحليلات المبيعات
class StoreSalesTable extends StatelessWidget {
  final List<StoreRecord> stores;
  final ({double totalSales, int completedCount}) Function(String storeId) getStoreSales;
  final Future<void> Function(StoreRecord store, bool isApproved) onToggleStatus;

  const StoreSalesTable({
    super.key,
    required this.stores,
    required this.getStoreSales,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'د.ع', decimalDigits: 0, locale: 'ar');

    if (stores.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          children: [
            Icon(Icons.storefront_outlined, size: 60, color: Colors.white30),
            SizedBox(height: 12),
            Text(
              'لا يوجد متاجر مطابقة للبحث حالياً',
              style: TextStyle(fontSize: 16, color: Colors.white60),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'قائمة المتاجر المعتمدة وإحصائيات مبيعات كل متجر',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF334155)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stores.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF334155)),
            itemBuilder: (context, index) {
              final store = stores[index];
              final sales = getStoreSales(store.id);
              final image = store.logoUrl;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: image != null && image.isNotEmpty
                      ? Image.network(
                          image,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 50,
                            height: 50,
                            color: const Color(0xFF00BFA5).withValues(alpha: 0.2),
                            child: const Icon(Icons.storefront_rounded, color: Color(0xFF00BFA5)),
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          color: const Color(0xFF00BFA5).withValues(alpha: 0.2),
                          child: const Icon(Icons.storefront_rounded, color: Color(0xFF00BFA5)),
                        ),
                ),
                title: Text(
                  store.storeName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
                subtitle: Text(
                  'المالك: ${store.ownerName} | هاتف: ${store.phone}',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
                trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 14,
                  children: [
                    // View Full Details Button
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded, color: Colors.white70),
                      tooltip: 'عرض تفاصيل المتجر',
                      onPressed: () => StoreDetailsDialog.show(context, store),
                    ),

                    // Sales Amount Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('إجمالي المبيعات', style: TextStyle(fontSize: 10, color: Colors.white60)),
                          Text(
                            currencyFormat.format(sales.totalSales),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),

                    // Completed Orders Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${sales.completedCount} طلب مكتمل',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                    ),

                    // Approval Toggle Switch
                    Switch(
                      value: store.isApproved,
                      activeTrackColor: const Color(0xFF00BFA5),
                      onChanged: (val) => onToggleStatus(store, val),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
