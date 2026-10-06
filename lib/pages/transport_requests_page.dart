import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/shared/app_colors.dart';
import 'package:intl/intl.dart' hide TextDirection;

class TransportRequestsPage extends StatefulWidget {
  const TransportRequestsPage({super.key});

  @override
  State<TransportRequestsPage> createState() => _TransportRequestsPageState();
}

class _TransportRequestsPageState extends State<TransportRequestsPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? darkBackground : backgroundColor;
    final txt = isDark ? darkText : textColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: isDark ? darkSurface : primaryColor,
          elevation: 0,
          title: const Text(
            'طلبات سيارات النقل',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('transport_requests')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primaryColor));
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_shipping_rounded, size: 60, color: txt.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    Text(
                      'ماكو طلبات حالياً انضمام حالياً',
                      style: TextStyle(fontSize: 16, color: txt.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                return _buildRequestCard(doc.id, data, isDark);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildRequestCard(String docId, Map<String, dynamic> data, bool isDark) {
    final card = isDark ? darkCard : cardColor;
    final txt = isDark ? darkText : textColor;
    final sub = isDark ? darkSubText : subTextColor;
    final status = data['status'] ?? 'pending';
    final timestamp = data['createdAt'] as Timestamp?;
    final dateStr = timestamp != null ? DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate()) : '';

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusLabel = 'مقبول';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusLabel = 'مرفوض';
        break;
      default:
        statusColor = Colors.amber;
        statusLabel = 'قيد المراجعة';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_shipping, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? 'غير محدد',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: txt),
                    ),
                    Text(
                      data['phone'] ?? '',
                      style: TextStyle(fontSize: 13, color: sub),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInfoChip(Icons.directions_car, data['vehicleType'] ?? '-', isDark),
              const SizedBox(width: 12),
              _buildInfoChip(Icons.confirmation_number, data['plateNumber'] ?? '-', isDark),
              const Spacer(),
              Text(dateStr, style: TextStyle(fontSize: 10, color: sub)),
            ],
          ),
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus(docId, data['uid'], 'approved'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('قبول', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus(docId, data['uid'], 'rejected'),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('رفض', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: primaryColor),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: isDark ? darkSubText : subTextColor),
        ),
      ],
    );
  }

  Future<void> _updateStatus(String docId, String? uid, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('transport_requests').doc(docId).update({
        'status': newStatus,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      if (newStatus == 'approved' && uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'isTransportApproved': true,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'approved' ? 'تم قبول الطلب' : 'تم رفض الطلب',
              style: const TextStyle(),
            ),
            backgroundColor: newStatus == 'approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }
}
