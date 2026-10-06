import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:dalal_alqaim/features/restaurant/presentation/widgets/kitchen_ticket_card.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/widgets/restaurant_metrics_bar.dart';

class RestaurantOrdersTab extends StatefulWidget {
  final String restaurantId;
  final VoidCallback onNavigateToMenu;
  final VoidCallback onNavigateToOffers;

  const RestaurantOrdersTab({
    super.key,
    required this.restaurantId,
    required this.onNavigateToMenu,
    required this.onNavigateToOffers,
  });

  @override
  State<RestaurantOrdersTab> createState() => _RestaurantOrdersTabState();
}

class _RestaurantOrdersTabState extends State<RestaurantOrdersTab> {
  String _selectedSubTab = 'الكل'; // 'الكل', 'جديد', 'تحضير', 'جاهز', 'مكتمل'

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('restaurantId', isEqualTo: widget.restaurantId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'حدث خطأ في تحميل الطلبات: ${snapshot.error}',
              style: GoogleFonts.ibmPlexSansArabic(color: Colors.redAccent),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: app_colors.primaryColor),
          );
        }

        final allDocs = snapshot.data!.docs;

        // Calculate KPI Counts & Financials
        int pendingCount = 0;
        int preparingCount = 0;
        int readyCount = 0;
        int completedCount = 0;
        double todayRevenue = 0.0;

        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day);

        for (var doc in allDocs) {
          final d = doc.data() as Map<String, dynamic>;
          final status = (d['status'] ?? 'pending').toString().toLowerCase();
          final amount = ((d['total'] ?? d['totalPrice'] ?? d['grandTotal']) as num?)?.toDouble() ?? 0.0;

          if (status == 'pending') {
            pendingCount++;
          } else if (status == 'accepted' || status == 'preparing') {
            preparingCount++;
          } else if (status == 'ready') {
            readyCount++;
          } else if (status == 'completed') {
            completedCount++;
          }

          // Check if order is today
          DateTime? orderDate;
          if (d['createdAt'] is Timestamp) {
            orderDate = (d['createdAt'] as Timestamp).toDate();
          }
          if (orderDate != null && orderDate.isAfter(startOfToday) && status == 'completed') {
            todayRevenue += amount;
          }
        }

        // Filter documents according to selected sub-tab
        final filteredDocs = allDocs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final status = (d['status'] ?? 'pending').toString().toLowerCase();

          if (_selectedSubTab == 'الكل') return true;
          if (_selectedSubTab == 'جديد') return status == 'pending';
          if (_selectedSubTab == 'تحضير') return status == 'accepted' || status == 'preparing';
          if (_selectedSubTab == 'جاهز') return status == 'ready' || status == 'delivering' || status == 'on_way';
          if (_selectedSubTab == 'مكتمل') return status == 'completed' || status == 'rejected' || status == 'cancelled';
          return true;
        }).toList();

        // Sort: pending first, then by createdAt desc
        filteredDocs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final statusA = (dataA['status'] ?? 'pending').toString().toLowerCase();
          final statusB = (dataB['status'] ?? 'pending').toString().toLowerCase();

          if (statusA == 'pending' && statusB != 'pending') return -1;
          if (statusA != 'pending' && statusB == 'pending') return 1;

          final timeA = dataA['createdAt'] as Timestamp?;
          final timeB = dataB['createdAt'] as Timestamp?;
          if (timeA != null && timeB != null) {
            return timeB.compareTo(timeA);
          }
          return 0;
        });

        return ListView(
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          children: [
            // 1. Live Metrics Strip
            RestaurantMetricsBar(
              pendingCount: pendingCount,
              preparingCount: preparingCount,
              readyCount: readyCount,
              todayRevenue: todayRevenue,
            ),

            // 2. Filter Capsules Bar
            _buildSubTabCapsules(
              totalCount: allDocs.length,
              pendingCount: pendingCount,
              preparingCount: preparingCount,
              readyCount: readyCount,
              completedCount: completedCount,
              isDark: isDark,
            ),

            // 3. Tickets Feed or Empty State
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: filteredDocs.isEmpty
                  ? _buildEmptyState(isDark: isDark)
                  : Column(
                      children: filteredDocs.map((doc) {
                        return KitchenTicketCard(
                          orderId: doc.id,
                          data: doc.data() as Map<String, dynamic>,
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }

  Widget _buildSubTabCapsules({
    required int totalCount,
    required int pendingCount,
    required int preparingCount,
    required int readyCount,
    required int completedCount,
    required bool isDark,
  }) {
    final tabs = [
      {'key': 'الكل', 'label': 'كل الطلبيات', 'count': totalCount, 'color': app_colors.primaryColor},
      {'key': 'جديد', 'label': 'واصل جديد', 'count': pendingCount, 'color': const Color(0xFFFFB830)},
      {'key': 'تحضير', 'label': 'جاي نحضّر', 'count': preparingCount, 'color': const Color(0xFFFF7043)},
      {'key': 'جاهز', 'label': 'جاهز للتسليم', 'count': readyCount, 'color': app_colors.primaryColor},
      {'key': 'مكتمل', 'label': 'مسلّم وخالص', 'count': completedCount, 'color': const Color(0xFF00E676)},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _selectedSubTab == tab['key'];
          final color = tab['color'] as Color;
          final count = tab['count'] as int;

          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedSubTab = tab['key'] as String);
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color
                      : (isDark ? app_colors.darkCard : Colors.white).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? color
                        : (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.5),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tab['label'] as String,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? app_colors.darkText : app_colors.textColor),
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          count.toString(),
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? Colors.white : color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState({required bool isDark}) {
    final textSecondary = isDark ? app_colors.darkSubText : app_colors.subTextColor;
    final textPrimary = isDark ? app_colors.darkText : app_colors.textColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: (isDark ? app_colors.darkCard : Colors.white).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: app_colors.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: app_colors.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ماكو أي طلبيات بهالقسم حالياً',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'أول ما يدز الزبون طلبية جديدة، راح تدگ الشاشة وتسمع جرس المطبخ مباشرة!',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12,
              color: textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
