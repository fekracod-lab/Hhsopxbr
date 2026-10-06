import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/shared/app_colors.dart';
import 'package:intl/intl.dart' hide TextDirection;

class TransportDashboardPage extends StatefulWidget {
  const TransportDashboardPage({super.key});

  @override
  State<TransportDashboardPage> createState() => _TransportDashboardPageState();
}

class _TransportDashboardPageState extends State<TransportDashboardPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? darkBackground : backgroundColor;
    final card = isDark ? darkCard : cardColor;
    final txt = isDark ? darkText : textColor;
    final sub = isDark ? darkSubText : subTextColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: isDark ? darkSurface : primaryColor,
          elevation: 0,
          title: const Text(
            'لوحة سيارة النقل',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('transport_orders')
              .where('driverId', isEqualTo: _uid)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primaryColor));
            }

            final orders = snapshot.data?.docs ?? [];

            // Calculate stats
            int completedCount = 0;
            int pendingCount = 0;
            double totalEarnings = 0;

            for (var doc in orders) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? 'pending';
              final price = ((data['price'] ?? data['total'] ?? 0) as num).toDouble();

              if (status == 'completed' || status == 'finished') {
                completedCount++;
                totalEarnings += price;
              } else if (status == 'pending' || status == 'accepted') {
                pendingCount++;
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Cards
                  Row(
                    children: [
                      _buildStatCard(
                        'الطلبات المكتملة',
                        completedCount.toString(),
                        Icons.check_circle_rounded,
                        Colors.green,
                        isDark,
                        card,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'الطلبات الجارية',
                        pendingCount.toString(),
                        Icons.hourglass_empty_rounded,
                        Colors.orange,
                        isDark,
                        card,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatCard(
                        'إجمالي الأرباح',
                        '${totalEarnings.toStringAsFixed(0)} د.ع',
                        Icons.monetization_on_rounded,
                        primaryColor,
                        isDark,
                        card,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'إجمالي الطلبات',
                        orders.length.toString(),
                        Icons.local_shipping_rounded,
                        Colors.blue,
                        isDark,
                        card,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'آخر الطلبات',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: txt),
                  ),
                  const SizedBox(height: 12),

                  if (orders.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.inbox_rounded, size: 60, color: sub.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text(
                              'ماكو طلبات حالياً',
                              style: TextStyle(color: sub),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...orders.take(20).map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'] ?? 'pending';
                      final price = data['price'] ?? data['total'] ?? 0;
                      final customerName = data['customerName'] ?? data['senderName'] ?? 'عميل';
                      final timestamp = data['createdAt'] as Timestamp?;
                      final dateStr = timestamp != null
                          ? DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate())
                          : '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.local_shipping, color: _statusColor(status), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customerName,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: txt),
                                  ),
                                  Text(dateStr, style: TextStyle(fontSize: 11, color: sub)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$price د.ع',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                                ),
                                Text(
                                  _statusLabel(status),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _statusColor(status)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDark, Color card) {
    return Expanded(
      child: Container(
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
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? darkText : textColor),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? darkSubText : subTextColor),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
      case 'finished':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
      case 'finished':
        return 'مكتمل';
      case 'pending':
        return 'قيد الانتظار';
      case 'accepted':
        return 'مقبول';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }
}
