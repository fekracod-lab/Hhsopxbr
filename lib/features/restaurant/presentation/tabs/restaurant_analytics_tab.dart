import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class RestaurantAnalyticsTab extends StatefulWidget {
  final String restaurantId;

  const RestaurantAnalyticsTab({
    super.key,
    required this.restaurantId,
  });

  @override
  State<RestaurantAnalyticsTab> createState() => _RestaurantAnalyticsTabState();
}

class _RestaurantAnalyticsTabState extends State<RestaurantAnalyticsTab> {
  String _timeRange = 'today'; // 'today', 'week', 'month', 'all'

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? app_colors.darkCard : Colors.white;
    final textPrimary = isDark ? app_colors.darkText : app_colors.textColor;
    final textSecondary = isDark ? app_colors.darkSubText : app_colors.subTextColor;
    final currencyFormatter = NumberFormat('#,###', 'ar_IQ');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('restaurantId', isEqualTo: widget.restaurantId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: app_colors.primaryColor),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];

        // Filter orders based on selected time range
        final now = DateTime.now();
        final filteredDocs = allDocs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          if (d['createdAt'] is! Timestamp) return true;
          final orderDate = (d['createdAt'] as Timestamp).toDate();

          if (_timeRange == 'today') {
            return orderDate.year == now.year &&
                orderDate.month == now.month &&
                orderDate.day == now.day;
          } else if (_timeRange == 'week') {
            final weekAgo = now.subtract(const Duration(days: 7));
            return orderDate.isAfter(weekAgo);
          } else if (_timeRange == 'month') {
            final monthAgo = now.subtract(const Duration(days: 30));
            return orderDate.isAfter(monthAgo);
          }
          return true; // 'all'
        }).toList();

        // Calculate KPIs
        double totalSales = 0;
        int completedCount = 0;
        int cancelledCount = 0;
        int cashCount = 0;
        int onlinePaymentCount = 0;
        int deliveryCount = 0;
        int pickupCount = 0;

        final Map<String, int> bestSellersQty = {};
        final Map<String, double> bestSellersRevenue = {};
        final Map<String, int> timeOfDayDistribution = {
          'الظهر (12-4م)': 0,
          'العصر (4-8م)': 0,
          'الليل (8-12ص)': 0,
          'الفجر (12-6ص)': 0,
          'الصبح (6-12ظ)': 0,
        };

        for (var doc in filteredDocs) {
          final d = doc.data() as Map<String, dynamic>;
          final status = (d['status'] ?? 'pending').toString().toLowerCase();
          final price = ((d['total'] ?? d['totalPrice'] ?? d['grandTotal']) as num?)?.toDouble() ?? 0.0;
          final payMethod = (d['paymentMethod'] ?? 'cash').toString().toLowerCase();
          final isPickup = d['isPickup'] == true || d['orderType'] == 'pickup';

          if (status == 'completed' || status == 'delivered') {
            completedCount++;
            totalSales += price;

            // Payment method
            if (payMethod.contains('cash') || payMethod.contains('كاش')) {
              cashCount++;
            } else {
              onlinePaymentCount++;
            }

            // Order type
            if (isPickup) {
              pickupCount++;
            } else {
              deliveryCount++;
            }

            // Items count
            final items = d['items'] as List<dynamic>? ?? [];
            for (var item in items) {
              if (item is Map<String, dynamic>) {
                final name = item['name'] ?? item['title'] ?? item['mealName'] ?? 'أكلة طيبة';
                final qty = (item['quantity'] ?? item['qty'] ?? 1) as int;
                final itemPrice = ((item['price'] ?? 0) as num).toDouble() * qty;

                bestSellersQty[name.toString()] = (bestSellersQty[name.toString()] ?? 0) + qty;
                bestSellersRevenue[name.toString()] = (bestSellersRevenue[name.toString()] ?? 0) + itemPrice;
              }
            }

            // Time distribution
            if (d['createdAt'] is Timestamp) {
              final hour = (d['createdAt'] as Timestamp).toDate().hour;
              if (hour >= 12 && hour < 16) {
                timeOfDayDistribution['الظهر (12-4م)'] = (timeOfDayDistribution['الظهر (12-4م)'] ?? 0) + 1;
              } else if (hour >= 16 && hour < 20) {
                timeOfDayDistribution['العصر (4-8م)'] = (timeOfDayDistribution['العصر (4-8م)'] ?? 0) + 1;
              } else if (hour >= 20 || hour < 0) {
                timeOfDayDistribution['الليل (8-12ص)'] = (timeOfDayDistribution['الليل (8-12ص)'] ?? 0) + 1;
              } else if (hour >= 0 && hour < 6) {
                timeOfDayDistribution['الفجر (12-6ص)'] = (timeOfDayDistribution['الفجر (12-6ص)'] ?? 0) + 1;
              } else {
                timeOfDayDistribution['الصبح (6-12ظ)'] = (timeOfDayDistribution['الصبح (6-12ظ)'] ?? 0) + 1;
              }
            }
          } else if (status == 'cancelled' || status == 'rejected') {
            cancelledCount++;
          }
        }

        final averageOrder = completedCount > 0 ? (totalSales / completedCount) : 0.0;
        final totalOrders = completedCount + cancelledCount;
        final successRate = totalOrders > 0 ? ((completedCount / totalOrders) * 100) : 100.0;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            children: [
              const SizedBox(height: 10),

              // 1. Time Range Capsule Selector
              _buildTimeRangeSelector(isDark, textPrimary),
              const SizedBox(height: 14),

              // 2. Main Executive Financial Revenue Card (Hero Gradient)
              _buildExecutiveRevenueCard(totalSales, completedCount, currencyFormatter),
              const SizedBox(height: 14),

              // 3. Quick Performance KPI Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      title: 'معدل صرف الزبون',
                      value: '${currencyFormatter.format(averageOrder.toInt())} د.ع',
                      subtitle: 'متوسط قيمة الطلبية',
                      icon: Icons.pie_chart_outline_rounded,
                      accentColor: Colors.blueAccent,
                      cardBg: cardBg,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      title: 'نسبة نجاح الطلبيات',
                      value: '${successRate.toStringAsFixed(0)}%',
                      subtitle: '$completedCount منفذة • $cancelledCount ملغية',
                      icon: Icons.verified_rounded,
                      accentColor: const Color(0xFF00E676),
                      cardBg: cardBg,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      title: 'طريقة الدفع',
                      value: '$cashCount كاش',
                      subtitle: '$onlinePaymentCount دفع إلكتروني',
                      icon: Icons.account_balance_wallet_rounded,
                      accentColor: app_colors.goldAccent,
                      cardBg: cardBg,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      title: 'نوع الاستلام',
                      value: '$deliveryCount توصيل',
                      subtitle: '$pickupCount استلام سفري',
                      icon: Icons.moped_rounded,
                      accentColor: const Color(0xFFFF7043),
                      cardBg: cardBg,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 4. Best Selling Meals Leaderboard
              _buildBestSellersSection(bestSellersQty, bestSellersRevenue, currencyFormatter, cardBg, textPrimary, textSecondary, isDark),
              const SizedBox(height: 20),

              // 5. Peak Hours & Rush Time Analysis
              _buildPeakHoursSection(timeOfDayDistribution, completedCount, cardBg, textPrimary, textSecondary, isDark),
              const SizedBox(height: 20),

              // 6. Customer Reviews & Ratings Stream
              _buildCustomerReviewsSection(cardBg, textPrimary, textSecondary, isDark),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeRangeSelector(bool isDark, Color textPrimary) {
    final filters = [
      {'key': 'today', 'label': 'اليوم'},
      {'key': 'week', 'label': 'آخر 7 أيام'},
      {'key': 'month', 'label': 'هذا الشهر'},
      {'key': 'all', 'label': 'كل الوقت'},
    ];

    return Row(
      children: filters.map((f) {
        final isSelected = _timeRange == f['key'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _timeRange = f['key']!);
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? app_colors.primaryColor
                      : (isDark ? app_colors.darkCard : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? app_colors.primaryColor
                        : (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.5),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: app_colors.primaryColor.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  f['label']!,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExecutiveRevenueCard(double totalSales, int completedCount, NumberFormat currencyFormatter) {
    String periodText = 'وارد اليوم الفعلي';
    if (_timeRange == 'week') periodText = 'مجموع وارد آخر 7 أيام';
    if (_timeRange == 'month') periodText = 'مجموع وارد هذا الشهر';
    if (_timeRange == 'all') periodText = 'إجمالي الوارد الكلي للمطعم';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00796B), app_colors.primaryColor],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: app_colors.primaryColor.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: app_colors.goldAccent, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    periodText,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: app_colors.goldAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$completedCount طلبية منفذة ',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${currencyFormatter.format(totalSales.toInt())} د.ع',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'المبلغ الصافي من طلبيات الطعام المكتملة والمسلّمة للزبائن',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 10,
              color: textSecondary.withValues(alpha: 0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBestSellersSection(
    Map<String, int> bestSellersQty,
    Map<String, double> bestSellersRevenue,
    NumberFormat currencyFormatter,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final sortedList = (bestSellersQty.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: app_colors.goldAccent, size: 22),
              const SizedBox(width: 8),
              Text(
                'أكثر الأكلات طلباً ومبيعاً بالمنيو',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sortedList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  'راح تظهر إحصائيات أكثر الأكلات طلباً فور اكتمال أولى طلبيات المطبخ',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...sortedList.asMap().entries.map((item) {
              final rank = item.key + 1;
              final entry = item.value;
              final revenue = bestSellersRevenue[entry.key] ?? 0.0;

              Color badgeColor = app_colors.goldAccent;
              if (rank == 2) badgeColor = Colors.grey.shade400;
              if (rank == 3) badgeColor = Colors.brown.shade300;
              if (rank > 3) badgeColor = app_colors.primaryColor;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF4F8F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '#$rank',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: badgeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (revenue > 0)
                            Text(
                              'وارد الأكلة: ${currencyFormatter.format(revenue.toInt())} د.ع',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 10,
                                color: textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: app_colors.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.value} وجبة ',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: app_colors.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPeakHoursSection(
    Map<String, int> timeOfDayDistribution,
    int totalCompleted,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_filled_rounded, color: Colors.blueAccent, size: 22),
              const SizedBox(width: 8),
              Text(
                'أوقات الذروة والضغط على المطبخ',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...timeOfDayDistribution.entries.map((entry) {
            final count = entry.value;
            final percent = totalCompleted > 0 ? (count / totalCompleted) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        '$count طلبيات (${(percent * 100).toStringAsFixed(0)}%)',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percent.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: isDark ? Colors.black26 : const Color(0xFFE8F0EE),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percent > 0.4 ? Colors.orangeAccent : app_colors.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCustomerReviewsSection(Color cardBg, Color textPrimary, Color textSecondary, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final reviews = snapshot.data?.docs ?? [];

        double avgRating = 5.0;
        if (reviews.isNotEmpty) {
          final sum = reviews.fold<double>(0, (prev, d) {
            final val = (d.data() as Map<String, dynamic>)['rating'];
            return prev + (val is num ? val.toDouble() : 5.0);
          });
          avgRating = sum / reviews.length;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: app_colors.goldAccent, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'تقييمات وآراء الزبائن',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: app_colors.goldAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(
                          avgRating.toStringAsFixed(1),
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.star, size: 14, color: app_colors.goldAccent),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (reviews.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(
                      'ماكو أي تقييمات مسجلة بعد. تقييمات الزبائن راح تنزل هنا مباشرة',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ...reviews.take(4).map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final author = data['authorName'] ?? data['userName'] ?? 'زبون المطعم';
                  final rating = ((data['rating'] ?? 5) as num).toDouble();
                  final comment = data['comment'] ?? data['review'] ?? 'الأكل كلش طيب والتوصيل سريع وعاشت إيدكم!';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF4F8F7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              author.toString(),
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            Row(
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  i < rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                                  size: 14,
                                  color: app_colors.goldAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          comment.toString(),
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
