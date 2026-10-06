import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:google_fonts/google_fonts.dart';

// --- Palette (teal/turquoise theme matching Dalal Alqaim) ---
const Color _primary = Color(0xFF26A69A);
const Color _darkBg = Color(0xFF07191A);
const Color _darkCard = Color(0xFF113033);
const Color _darkText = Color(0xFFE0F2F1);
const Color _darkSub = Color(0xFF80CBC4);


class RestaurantAnalyticsPage extends StatefulWidget {
  const RestaurantAnalyticsPage({super.key});

  @override
  State<RestaurantAnalyticsPage> createState() => _RestaurantAnalyticsPageState();
}

class _RestaurantAnalyticsPageState extends State<RestaurantAnalyticsPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String? _restaurantId;

  @override
  void initState() {
    super.initState();
    _restaurantId = _uid;
    _fetchRestaurantId();
  }

  Future<void> _fetchRestaurantId() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _restaurantId = doc.data()?['restaurantId'] ?? doc.data()?['uid'] ?? _uid;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: ThemeData.dark().copyWith(
          textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(ThemeData.dark().textTheme),
        ),
        child: Scaffold(
          backgroundColor: _darkBg,
          appBar: AppBar(
            backgroundColor: _darkCard,
            elevation: 0,
            title: Text(
              'إحصائيات وتحليلات مطعمي',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            centerTitle: true,
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('restaurantId', isEqualTo: _restaurantId ?? _uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _primary));
              }

              final orders = snapshot.data?.docs ?? [];
              double totalRevenue = 0;
              int completedCount = 0;
              int pendingCount = 0;
              int preparingCount = 0;

              for (var doc in orders) {
                final data = doc.data() as Map<String, dynamic>;
                final price = ((data['total'] ?? data['totalPrice'] ?? data['grandTotal']) as num?)?.toDouble() ?? 0.0;
                final status = data['status'] ?? 'pending';

                if (status == 'completed') {
                  completedCount++;
                  totalRevenue += price;
                } else if (status == 'pending') {
                  pendingCount++;
                } else if (status == 'preparing' || status == 'accepted' || status == 'approved') {
                  preparingCount++;
                }
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ملخص الأداء المالي والعمليات',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _darkText,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Metrics Grid
                    Row(
                      children: [
                        _buildStatCard(
                          'إجمالي المبيعات',
                          '${totalRevenue.toStringAsFixed(0)} د.ع',
                          Icons.monetization_on_rounded,
                          Colors.green,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          'الطلبات المكتملة',
                          completedCount.toString(),
                          Icons.done_all_rounded,
                          Colors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatCard(
                          'قيد التحضير',
                          preparingCount.toString(),
                          Icons.restaurant_rounded,
                          Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          'قيد الانتظار',
                          pendingCount.toString(),
                          Icons.hourglass_empty_rounded,
                          Colors.purple,
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),
                    Text(
                      'سجل المبيعات الأخيرة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _darkText,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (orders.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            'ماكو عمليات حالياً بيع مسجلة بعد',
                            style: GoogleFonts.ibmPlexSansArabic(color: _darkSub.withValues(alpha: 0.5)),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: orders.length > 10 ? 10 : orders.length,
                        itemBuilder: (context, index) {
                          final doc = orders[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final buyerName = data['customerName'] ?? data['buyerName'] ?? 'زبون مدار';
                          final price = data['total'] ?? data['totalPrice'] ?? data['grandTotal'] ?? 0;
                          final status = data['status'] ?? 'pending';
                          final timestamp = data['createdAt'] as Timestamp?;
                          final dateStr = timestamp != null
                              ? DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate())
                              : '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _darkCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      buyerName,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontWeight: FontWeight.bold,
                                        color: _darkText,
                                      ),
                                    ),
                                    Text(
                                      dateStr,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        color: _darkSub.withValues(alpha: 0.5),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '$price د.ع',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        color: _primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      status == 'completed' ? 'مكتمل' : 'قيد الانتظار',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        color: status == 'completed' ? Colors.green : Colors.orange,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
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
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _darkText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _darkSub.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
