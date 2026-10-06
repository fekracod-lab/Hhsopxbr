import 'package:flutter/material.dart';
import '../../domain/entities/store_analytics_models.dart';
import 'store_details_dialog.dart';

/// ويدجت قائمة طلبات انضمام المتاجر المعلقة
class StorePendingRequestsList extends StatelessWidget {
  final List<StoreRecord> pendingItems;
  final Future<void> Function(StoreRecord store) onApprove;
  final Future<void> Function(StoreRecord store) onReject;

  const StorePendingRequestsList({
    super.key,
    required this.pendingItems,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: const Column(
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 60, color: Color(0xFF10B981)),
            SizedBox(height: 12),
            Text(
              'لا يوجد طلبات انضمام جديدة بانتظار الموافقة حالياً',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'طلبات الانضمام الجدد للمتاجر بانتظار الموافقة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Text(
                    '${pendingItems.length} طلب بانتظار القرار',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF334155)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pendingItems.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF334155)),
            itemBuilder: (context, index) {
              final store = pendingItems[index];
              final image = store.logoUrl;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: image != null && image.isNotEmpty
                      ? Image.network(
                          image,
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 54,
                            height: 54,
                            color: const Color(0xFF00BFA5).withValues(alpha: 0.2),
                            child: const Icon(Icons.storefront_rounded, color: Color(0xFF00BFA5)),
                          ),
                        )
                      : Container(
                          width: 54,
                          height: 54,
                          color: const Color(0xFF00BFA5).withValues(alpha: 0.2),
                          child: const Icon(Icons.storefront_rounded, color: Color(0xFF00BFA5)),
                        ),
                ),
                title: Text(
                  store.storeName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المالك: ${store.ownerName} | هاتف: ${store.phone}',
                        style: const TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                      Text(
                        'التخصص: ${store.category} | الموقع: ${store.governorateName} ${store.regionName}',
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    // View Full Details Button
                    OutlinedButton.icon(
                      onPressed: () => StoreDetailsDialog.show(
                        context,
                        store,
                        onApprove: () => onApprove(store),
                      ),
                      icon: const Icon(Icons.visibility_rounded, size: 16, color: Colors.white),
                      label: const Text('عرض كافة التفاصيل', style: TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF334155)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),

                    // Approve Button
                    ElevatedButton.icon(
                      onPressed: () => onApprove(store),
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('موافقة واعتماد', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),

                    // Reject Button
                    ElevatedButton.icon(
                      onPressed: () => onReject(store),
                      icon: const Icon(Icons.cancel_rounded, size: 16),
                      label: const Text('رفض الطلب', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                        foregroundColor: Colors.redAccent,
                        elevation: 0,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
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
