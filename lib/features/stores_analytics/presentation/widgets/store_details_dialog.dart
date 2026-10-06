import 'package:flutter/material.dart';
import '../../domain/entities/store_analytics_models.dart';

/// نافذة عرض كافة تفاصيل المتجر والطلب (Store Details Dialog)
class StoreDetailsDialog extends StatelessWidget {
  final StoreRecord store;
  final VoidCallback? onApprove;

  const StoreDetailsDialog({
    super.key,
    required this.store,
    this.onApprove,
  });

  static void show(BuildContext context, StoreRecord store, {VoidCallback? onApprove}) {
    showDialog(
      context: context,
      builder: (ctx) => StoreDetailsDialog(store: store, onApprove: onApprove),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = store.logoUrl;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.storefront_rounded, color: Color(0xFF00BFA5), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'تفاصيل طلب المتجر: ${store.storeName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (image != null && image.isNotEmpty) ...[
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(image, width: 120, height: 120, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildDetailRow('اسم المحل / المتجر :', store.storeName),
                _buildDetailRow('صاحب المتجر :', store.ownerName),
                _buildDetailRow('رقم الهاتف :', store.phone),
                _buildDetailRow('البريد الإلكتروني :', store.email),
                _buildDetailRow('الفئة والنشاط :', store.category),
                _buildDetailRow('المحافظة والمنطقة :', '${store.governorateName} - ${store.regionName}'),
                _buildDetailRow('العنوان التفصيلي :', store.address),
                _buildDetailRow('ساعات وأوقات العمل :', store.workingHours),
                _buildDetailRow('حالة الاعتماد :', store.isApproved ? 'معتمد ومفعل' : 'بانتظار الموافقة'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق', style: TextStyle(color: Colors.white70)),
          ),
          if (!store.isApproved && onApprove != null) ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onApprove!();
              },
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: const Text('موافقة واعتماد', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white60)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
