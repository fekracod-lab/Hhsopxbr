import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const double _orderEarningPerUnit = 500.0; // 500 د لكل طلب

class RestaurantTrackingPage extends StatelessWidget {
  final String restaurantId;
  final String? restaurantName;

  const RestaurantTrackingPage({super.key, required this.restaurantId, this.restaurantName});

  @override
  Widget build(BuildContext context) {
    final title = restaurantName != null && restaurantName!.isNotEmpty
        ? 'تتبع: ${restaurantName!}'
        : 'تتبع المطعم';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle()),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('restaurantId', isEqualTo: restaurantId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          final totalOrders = docs.length;
          final completedOrders = docs.where((d) {
            final s = (d.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() ?? '';
            return s == 'delivered' || s == 'completed' || s == 'done';
          }).toList();

          final completedCount = completedOrders.length;
          final earnings = completedCount * _orderEarningPerUnit;

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('الطلبات الكليّة', style: TextStyle()),
                            const SizedBox(height: 6),
                            Text('$totalOrders', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('الطلبات المكتملة', style: TextStyle()),
                            const SizedBox(height: 6),
                            Text('$completedCount', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('الأرباح', style: TextStyle()),
                            const SizedBox(height: 6),
                            Text('${earnings.toStringAsFixed(0)} د', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                            const SizedBox(height: 4),
                            Text('(${_orderEarningPerUnit.toStringAsFixed(0)} د لكل طلب)', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                const Text('قائمة الطلبات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                Expanded(
                  child: docs.isEmpty
                      ? Center(child: Text('ماكو طلبات حالياً حتى الآن', style: const TextStyle()))
                      : ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final d = docs[index];
                            final data = d.data() as Map<String, dynamic>;
                            final status = (data['status'] ?? 'unknown').toString();
                            final customer = (data['customerName'] ?? data['customer'] ?? 'زبون').toString();
                            final created = data['createdAt'];
                            String createdStr = '';
                            try {
                              if (created is Timestamp) {
                                final dt = created.toDate().toLocal();
                                createdStr = '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                              } else if (created is int) {
                                final dt = DateTime.fromMillisecondsSinceEpoch(created).toLocal();
                                createdStr = dt.toString();
                              }
                            } catch (_) {
                              createdStr = '';
                            }

                            return ListTile(
                              tileColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              title: Text('طلب #${d.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Text('الزبون: $customer', style: const TextStyle()),
                                  const SizedBox(height: 4),
                                  Text('المبلغ: ${_orderEarningPerUnit.toStringAsFixed(0)} د', style: const TextStyle()),
                                  if (createdStr.isNotEmpty) ...[const SizedBox(height: 4), Text('التاريخ: $createdStr', style: const TextStyle(fontSize: 12, color: Colors.black54))],
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Chip(
                                    backgroundColor: _statusColor(status),
                                    label: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                  const SizedBox(height: 6),
                                  IconButton(
                                    icon: const Icon(Icons.open_in_new_rounded),
                                    onPressed: () {
                                      // optional: open order detail in Firestore or another page
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('deliv') || s.contains('done') || s.contains('completed')) return Colors.green;
    if (s.contains('prepar') || s.contains('preparing')) return Colors.orange;
    if (s.contains('cancel') || s.contains('rejected')) return Colors.red;
    return Colors.blueGrey;
  }
}
