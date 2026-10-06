import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/constants/pos_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pos_empty_state.dart';
import '../../../../core/widgets/pos_kpi_card.dart';
import '../../../../core/widgets/pos_page_header.dart';
import '../../../../core/widgets/pos_status_chip.dart';
import '../../../../core/widgets/pos_section_title.dart';
import '../../../../services/thermal_printer_service.dart';

/// شاشة تقارير المبيعات الشاملة وتحليلات القنوات المتعددة
class RestaurantAnalyticsPage extends StatefulWidget {
  const RestaurantAnalyticsPage({super.key});

  @override
  State<RestaurantAnalyticsPage> createState() =>
      _RestaurantAnalyticsPageState();
}

class _RestaurantAnalyticsPageState extends State<RestaurantAnalyticsPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String? _restaurantId;
  String _restaurantName = 'مطعم مدار';

  // الفلاتر
  String _selectedChannel = 'all'; // 'all' | 'madar' | 'takeaway' | 'dine_in' | 'delivery'
  String _selectedPeriod = 'today'; // 'today' | 'yesterday' | 'week' | 'month' | 'all'
  String _searchQuery = '';

  bool _isPrintingReport = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _restaurantId = _uid;
    _fetchRestaurantData();
  }

  Future<void> _fetchRestaurantData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _restaurantId = doc.data()?['restaurantId'] ?? doc.data()?['uid'] ?? _uid;
          _restaurantName = doc.data()?['restaurantName'] ?? doc.data()?['fullName'] ?? 'مطعم مدار';
        });
      }
    } catch (_) {}
  }

  bool _matchesPeriod(DateTime? date) {
    if (date == null) return true;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    switch (_selectedPeriod) {
      case 'today':
        return date.isAfter(todayStart);
      case 'yesterday':
        return date.isAfter(yesterdayStart) && date.isBefore(todayStart);
      case 'week':
        return date.isAfter(todayStart.subtract(const Duration(days: 7)));
      case 'month':
        return date.isAfter(todayStart.subtract(const Duration(days: 30)));
      case 'all':
      default:
        return true;
    }
  }

  bool _matchesChannel(Map<String, dynamic> data) {
    if (_selectedChannel == 'all') return true;
    final orderType = (data['orderType'] ?? data['type'] ?? '').toString().toLowerCase();
    final source = (data['source'] ?? '').toString().toLowerCase();
    final hasTable = data['tableNumber'] != null && data['tableNumber'].toString().isNotEmpty;

    switch (_selectedChannel) {
      case 'madar':
        return source.contains('madar') || source.contains('app') || data['isAppOrder'] == true;
      case 'takeaway':
        return orderType == PosConstants.orderTypeTakeaway || orderType == 'takeaway' || (!hasTable && orderType != 'delivery');
      case 'dine_in':
        return orderType == PosConstants.orderTypeDineIn || hasTable || orderType == 'dine_in';
      case 'delivery':
        return orderType == PosConstants.orderTypeDelivery || orderType == 'delivery';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.background,
        body: Column(
          children: [
            // رأس الصفحة مع زر طباعة التقرير الحراري
            PosPageHeader(
              icon: Icons.analytics_rounded,
              title: 'التقارير الشاملة وتحليلات المبيعات',
              subtitle: 'تقارير تفصيلية لتطبيق مدار • السفري • الصالة والطاولات • طرق الدفع',
              actions: [
                // زر تصدير PDF
                OutlinedButton.icon(
                  onPressed: _isExporting ? null : _exportPdfReport,
                  icon: _isExporting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.picture_as_pdf_rounded, size: 17),
                  label: Text('تصدير PDF', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.primary,
                    side: BorderSide(color: c.primary.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                // زر تصدير CSV
                OutlinedButton.icon(
                  onPressed: _isExporting ? null : _exportCsvReport,
                  icon: const Icon(Icons.table_chart_rounded, size: 17),
                  label: Text('تصدير CSV', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0x6610B981)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                // زر الطباعة الحرارية
                ElevatedButton.icon(
                  onPressed: _isPrintingReport ? null : _printReportNow,
                  icon: _isPrintingReport
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.print_rounded, size: 18),
                  label: Text(
                    _isPrintingReport ? 'جاري الطباعة...' : 'طباعة تقرير الوردية (Z-Report) 🖨️',
                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),

            // شريط الفلاتر السريعة (الفترة الزمنية + تصنيف القنوات)
            _buildFiltersBar(c),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: () {
                  final ids = {_uid, if (_restaurantId != null && _restaurantId!.isNotEmpty) _restaurantId!}.toList();
                  if (ids.isEmpty) return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
                  if (ids.length == 1) {
                    return FirebaseFirestore.instance
                        .collection('orders')
                        .where('restaurantId', isEqualTo: ids.first)
                        .snapshots();
                  }
                  return FirebaseFirestore.instance
                      .collection('orders')
                      .where('restaurantId', whereIn: ids)
                      .snapshots();
                }(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: c.primary,
                        strokeWidth: 3,
                      ),
                    );
                  }

                  final allDocs = snapshot.data?.docs ?? [];

                  // تصفية حسب الفترة الزمنية والبحث والقناة
                  final filteredDocs = allDocs.where((doc) {
                    final data = doc.data();
                    final ts = data['createdAt'] as Timestamp?;
                    final date = ts?.toDate();
                    if (!_matchesPeriod(date)) return false;
                    if (!_matchesChannel(data)) return false;

                    if (_searchQuery.isNotEmpty) {
                      final customer = (data['customerName'] ?? '').toString().toLowerCase();
                      final orderId = (data['id'] ?? doc.id).toString().toLowerCase();
                      if (!customer.contains(_searchQuery) && !orderId.contains(_searchQuery)) {
                        return false;
                      }
                    }
                    return true;
                  }).toList();

                  // حساب المجاميع
                  double totalRevenue = 0;
                  int completedCount = 0;
                  int pendingCount = 0;
                  int preparingCount = 0;

                  double madarSales = 0;
                  int madarCount = 0;
                  double takeawaySales = 0;
                  int takeawayCount = 0;
                  double dineInSales = 0;
                  int dineInCount = 0;
                  double deliverySales = 0;
                  int deliveryCount = 0;

                  double cashTotal = 0;
                  double zainCashTotal = 0;
                  double qiCardTotal = 0;

                  final Map<String, Map<String, dynamic>> itemAggregates = {};

                  for (var doc in filteredDocs) {
                    final d = doc.data();
                    final price = ((d['total'] ?? d['totalPrice'] ?? d['grandTotal'] ?? d['totalAmount']) as num?)?.toDouble() ?? 0.0;
                    final status = (d['status'] ?? 'pending').toString();
                    final pMethod = (d['paymentMethod'] ?? 'cash').toString().toLowerCase();
                    final orderType = (d['orderType'] ?? '').toString().toLowerCase();
                    final source = (d['source'] ?? '').toString().toLowerCase();
                    final hasTable = d['tableNumber'] != null && d['tableNumber'].toString().isNotEmpty;

                    if (status == 'completed' || status == 'delivered') {
                      completedCount++;
                      totalRevenue += price;

                      // توزيع القنوات
                      if (source.contains('madar') || source.contains('app') || d['isAppOrder'] == true) {
                        madarSales += price;
                        madarCount++;
                      } else if (orderType == 'dine_in' || hasTable) {
                        dineInSales += price;
                        dineInCount++;
                      } else if (orderType == 'delivery') {
                        deliverySales += price;
                        deliveryCount++;
                      } else {
                        takeawaySales += price;
                        takeawayCount++;
                      }

                      // طرق الدفع
                      if (pMethod.contains('zain') || pMethod.contains('wallet')) {
                        zainCashTotal += price;
                      } else if (pMethod.contains('card') || pMethod.contains('qi') || pMethod.contains('visa')) {
                        qiCardTotal += price;
                      } else {
                        cashTotal += price;
                      }

                      // حصر الأصناف الأكثر مبيعاً
                      if (d['items'] is List) {
                        for (var it in d['items']) {
                          if (it is Map) {
                            final name = it['name'] ?? it['title'] ?? 'وجبة';
                            final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                            final itPrice = ((it['price'] as num?)?.toDouble() ?? 0.0) * qty;

                            if (!itemAggregates.containsKey(name)) {
                              itemAggregates[name] = {'name': name, 'quantity': 0, 'revenue': 0.0};
                            }
                            itemAggregates[name]!['quantity'] = (itemAggregates[name]!['quantity'] as int) + qty;
                            itemAggregates[name]!['revenue'] = (itemAggregates[name]!['revenue'] as double) + itPrice;
                          }
                        }
                      }
                    } else if (status == 'pending') {
                      pendingCount++;
                    } else if (status == 'preparing' || status == 'accepted') {
                      preparingCount++;
                    }
                  }

                  final topItems = itemAggregates.values.toList()
                    ..sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));

                  final avgTicket = completedCount > 0 ? (totalRevenue / completedCount) : 0.0;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // كروت المؤشرات المالية الكبرى
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cardWidth = constraints.maxWidth > 920
                                ? (constraints.maxWidth - 36) / 4
                                : (constraints.maxWidth - 12) / 2;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: cardWidth,
                                  child: PosKpiCard(
                                    label: 'إجمالي المبيعات المحققة',
                                    value: '${totalRevenue.toStringAsFixed(0)} د.ع',
                                    icon: Icons.monetization_on_rounded,
                                    color: c.gold,
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: PosKpiCard(
                                    label: 'الفواتير المكتملة',
                                    value: completedCount.toString(),
                                    icon: Icons.done_all_rounded,
                                    color: c.success,
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: PosKpiCard(
                                    label: 'متوسط الفاتورة (AOV)',
                                    value: '${avgTicket.toStringAsFixed(0)} د.ع',
                                    icon: Icons.receipt_long_rounded,
                                    color: c.accent,
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: PosKpiCard(
                                    label: 'طلبات قيد المعالجة',
                                    value: '${pendingCount + preparingCount}',
                                    icon: Icons.hourglass_top_rounded,
                                    color: c.warning,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // تفصيل القنوات التشغيلية وطرق الدفع جنباً إلى جنب
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 800;
                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildChannelsBreakdownCard(c, madarSales, madarCount, takeawaySales, takeawayCount, dineInSales, dineInCount, deliverySales, deliveryCount, totalRevenue)),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildPaymentsBreakdownCard(c, cashTotal, zainCashTotal, qiCardTotal, totalRevenue)),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                _buildChannelsBreakdownCard(c, madarSales, madarCount, takeawaySales, takeawayCount, dineInSales, dineInCount, deliverySales, deliveryCount, totalRevenue),
                                const SizedBox(height: 16),
                                _buildPaymentsBreakdownCard(c, cashTotal, zainCashTotal, qiCardTotal, totalRevenue),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // الأصناف الأكثر مبيعاً
                        if (topItems.isNotEmpty) ...[
                          PosSectionTitle(
                            title: 'الأصناف الأكثر طلباً ومبيعاً',
                            icon: Icons.star_rounded,
                            trailing: Text(
                              'أفضل ${topItems.length > 5 ? 5 : topItems.length} وجبات',
                              style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 11.5),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildTopItemsCard(c, topItems),
                          const SizedBox(height: 24),
                        ],

                        // سجل الفواتير المفصل
                        PosSectionTitle(
                          title: 'سجل الطلبات والفواتير الأخيرة',
                          icon: Icons.receipt_rounded,
                          trailing: Text(
                            'إجمالي ${filteredDocs.length} طلب',
                            style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 11.5),
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (filteredDocs.isEmpty)
                          PosEmptyState(
                            icon: Icons.receipt_long_rounded,
                            title: 'لا توجد فواتير مطابقة لهذا الفلتر',
                            subtitle: 'جرب تغيير الفترة الزمنية أو القناة التشغيلية المختارة',
                          )
                        else
                          ...filteredDocs.take(15).map((doc) => _buildOrderRow(c, doc)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────── شريط الفلاتر ────────────────────────────

  Widget _buildFiltersBar(PosColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // فلاتر الفترات الزمنية
              Text(
                'الفترة:',
                style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              _buildPeriodChip(c, 'اليوم', 'today'),
              const SizedBox(width: 6),
              _buildPeriodChip(c, 'البارحة', 'yesterday'),
              const SizedBox(width: 6),
              _buildPeriodChip(c, 'آخر 7 أيام', 'week'),
              const SizedBox(width: 6),
              _buildPeriodChip(c, 'هذا الشهر', 'month'),
              const SizedBox(width: 6),
              _buildPeriodChip(c, 'كل الفترات', 'all'),

              const Spacer(),

              // حقل البحث في الفواتير
              SizedBox(
                width: 220,
                height: 36,
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'بحث باسم الزبون أو #الطلب...',
                    hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textDisabled),
                    prefixIcon: Icon(Icons.search_rounded, size: 16, color: c.textMuted),
                    filled: true,
                    fillColor: c.background,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // فلاتر القنوات التشغيلية
          Row(
            children: [
              Text(
                'القناة:',
                style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              _buildChannelChip(c, 'الكل', 'all', Icons.grid_view_rounded),
              const SizedBox(width: 6),
              _buildChannelChip(c, '📱 تطبيق مدار', 'madar', Icons.mobile_screen_share_rounded),
              const SizedBox(width: 6),
              _buildChannelChip(c, '🥡 سفري (POS)', 'takeaway', Icons.takeout_dining_rounded),
              const SizedBox(width: 6),
              _buildChannelChip(c, '🍽️ الصالة والطاولات', 'dine_in', Icons.table_restaurant_rounded),
              const SizedBox(width: 6),
              _buildChannelChip(c, '🛵 الدليفري', 'delivery', Icons.delivery_dining_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(PosColors c, String label, String key) {
    final isSelected = _selectedPeriod == key;
    return InkWell(
      onTap: () => setState(() => _selectedPeriod = key),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? c.primary : c.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? c.primary : c.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            color: isSelected ? Colors.white : c.textMuted,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildChannelChip(PosColors c, String label, String key, IconData icon) {
    final isSelected = _selectedChannel == key;
    return InkWell(
      onTap: () => setState(() => _selectedChannel = key),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? c.accent.withValues(alpha: 0.18) : c.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? c.accent : c.border,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? c.accent : c.textMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                color: isSelected ? c.accent : c.textPrimary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────── بطاقات التفصيل ────────────────────────────

  Widget _buildChannelsBreakdownCard(
    PosColors c,
    double madarSales, int madarCount,
    double takeawaySales, int takeawayCount,
    double dineInSales, int dineInCount,
    double deliverySales, int deliveryCount,
    double totalSales,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: c.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'توزيع المبيعات حسب القناة',
                style: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildChannelProgressBar(c, '📱 تطبيق مدار', madarCount, madarSales, totalSales, c.primary),
          const SizedBox(height: 10),
          _buildChannelProgressBar(c, '🥡 مبيعات السفري (POS)', takeawayCount, takeawaySales, totalSales, c.gold),
          const SizedBox(height: 10),
          _buildChannelProgressBar(c, '🍽️ الصالة والطاولات', dineInCount, dineInSales, totalSales, c.accent),
          const SizedBox(height: 10),
          _buildChannelProgressBar(c, '🛵 طلبات التوصيل', deliveryCount, deliverySales, totalSales, c.info),
        ],
      ),
    );
  }

  Widget _buildChannelProgressBar(PosColors c, String label, int count, double sales, double total, Color barColor) {
    final pct = total > 0 ? (sales / total) : 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$label ($count طلب)', style: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary, fontSize: 11.5)),
            Text('${sales.toStringAsFixed(0)} د.ع (${(pct * 100).toStringAsFixed(1)}%)',
                style: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 11.5)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            backgroundColor: c.background,
            color: barColor,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentsBreakdownCard(
    PosColors c,
    double cashTotal,
    double zainCashTotal,
    double qiCardTotal,
    double totalRevenue,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: c.gold, size: 18),
              const SizedBox(width: 8),
              Text(
                'توزيع الإيراد حسب طريقة الدفع',
                style: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildPaymentRow(c, '💵 نقد في الدرج (Cash)', cashTotal, totalRevenue, c.success),
          const SizedBox(height: 10),
          _buildPaymentRow(c, '📱 محفظة زين كاش (ZainCash)', zainCashTotal, totalRevenue, c.accent),
          const SizedBox(height: 10),
          _buildPaymentRow(c, '💳 كي كارد وبطاقات مصرفية', qiCardTotal, totalRevenue, c.info),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(PosColors c, String label, double amount, double total, Color color) {
    final pct = total > 0 ? (amount / total) : 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary, fontSize: 11.5)),
            Text('${amount.toStringAsFixed(0)} د.ع (${(pct * 100).toStringAsFixed(1)}%)',
                style: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 11.5)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            backgroundColor: c.background,
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildTopItemsCard(PosColors c, List<Map<String, dynamic>> items) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        children: items.take(6).map((it) {
          final name = it['name'] ?? '';
          final qty = it['quantity'] ?? 0;
          final rev = (it['revenue'] as num?)?.toDouble() ?? 0.0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$qty×', style: GoogleFonts.ibmPlexSansArabic(color: c.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('${rev.toStringAsFixed(0)} د.ع', style: GoogleFonts.ibmPlexSansArabic(color: c.gold, fontSize: 11)),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrderRow(PosColors c, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final buyerName = d['customerName'] ?? d['buyerName'] ?? 'زبون مباشر';
    final price = ((d['total'] ?? d['totalPrice'] ?? d['grandTotal'] ?? d['totalAmount']) as num?)?.toDouble() ?? 0.0;
    final status = (d['status'] ?? 'pending').toString();
    final ts = d['createdAt'] as Timestamp?;
    final dateStr = ts != null ? DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate()) : '';
    final orderType = (d['orderType'] ?? 'takeaway').toString();
    final tableNum = d['tableNumber']?.toString();

    final isCompleted = status == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              tableNum != null ? Icons.table_restaurant_rounded : Icons.point_of_sale_rounded,
              color: c.accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      buyerName,
                      style: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    if (tableNum != null && tableNum.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: c.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                        child: Text('طاولة $tableNum', style: GoogleFonts.ibmPlexSansArabic(color: c.gold, fontSize: 10.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                Text(
                  '$dateStr • نوع الطلب: ${PosConstants.getOrderTypeName(orderType)}',
                  style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${price.toStringAsFixed(0)} د.ع',
                style: GoogleFonts.ibmPlexSansArabic(color: c.accent, fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              const SizedBox(height: 3),
              PosStatusChip(
                label: isCompleted ? 'مكتمل' : 'قيد الانتظار',
                icon: isCompleted ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                color: isCompleted ? c.success : c.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────── طباعة التقرير الفورية ────────────────────────────

  Future<void> _printReportNow() async {
    setState(() => _isPrintingReport = true);
    HapticFeedback.heavyImpact();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('restaurantId', isEqualTo: _restaurantId ?? _uid)
          .get();

      final filtered = snap.docs.where((doc) {
        final d = doc.data();
        final ts = d['createdAt'] as Timestamp?;
        return _matchesPeriod(ts?.toDate()) && _matchesChannel(d);
      }).toList();

      double total = 0;
      int completed = 0;
      double madarS = 0; int madarC = 0;
      double takeS = 0; int takeC = 0;
      double dineS = 0; int dineC = 0;
      double delS = 0; int delC = 0;
      double cash = 0; double zain = 0; double qi = 0;

      final Map<String, Map<String, dynamic>> itemsAgg = {};

      for (var doc in filtered) {
        final d = doc.data();
        final price = ((d['total'] ?? d['totalPrice'] ?? d['grandTotal'] ?? d['totalAmount']) as num?)?.toDouble() ?? 0.0;
        final status = (d['status'] ?? '').toString();
        final pMethod = (d['paymentMethod'] ?? 'cash').toString().toLowerCase();
        final orderType = (d['orderType'] ?? '').toString().toLowerCase();
        final source = (d['source'] ?? '').toString().toLowerCase();
        final hasTable = d['tableNumber'] != null && d['tableNumber'].toString().isNotEmpty;

        if (status == 'completed' || status == 'delivered') {
          completed++;
          total += price;

          if (source.contains('madar') || source.contains('app') || d['isAppOrder'] == true) {
            madarS += price; madarC++;
          } else if (orderType == 'dine_in' || hasTable) {
            dineS += price; dineC++;
          } else if (orderType == 'delivery') {
            delS += price; delC++;
          } else {
            takeS += price; takeC++;
          }

          if (pMethod.contains('zain') || pMethod.contains('wallet')) {
            zain += price;
          } else if (pMethod.contains('card') || pMethod.contains('qi')) {
            qi += price;
          } else {
            cash += price;
          }

          if (d['items'] is List) {
            for (var it in d['items']) {
              if (it is Map) {
                final name = it['name'] ?? it['title'] ?? 'وجبة';
                final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                final itPrice = ((it['price'] as num?)?.toDouble() ?? 0.0) * qty;

                if (!itemsAgg.containsKey(name)) {
                  itemsAgg[name] = {'name': name, 'quantity': 0, 'revenue': 0.0};
                }
                itemsAgg[name]!['quantity'] = (itemsAgg[name]!['quantity'] as int) + qty;
                itemsAgg[name]!['revenue'] = (itemsAgg[name]!['revenue'] as double) + itPrice;
              }
            }
          }
        }
      }

      final topList = itemsAgg.values.toList()
        ..sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));

      String periodLabel = 'اليوم';
      if (_selectedPeriod == 'yesterday') periodLabel = 'البارحة';
      if (_selectedPeriod == 'week') periodLabel = 'آخر 7 أيام';
      if (_selectedPeriod == 'month') periodLabel = 'هذا الشهر';
      if (_selectedPeriod == 'all') periodLabel = 'كافة الفترات';

      final success = await ThermalPrinterService.printSalesReport(
        restaurantName: _restaurantName,
        periodTitle: periodLabel,
        totalSales: total,
        totalOrders: completed,
        madarSales: madarS,
        madarOrdersCount: madarC,
        takeawaySales: takeS,
        takeawayOrdersCount: takeC,
        dineInSales: dineS,
        dineInOrdersCount: dineC,
        deliverySales: delS,
        deliveryOrdersCount: delC,
        cashTotal: cash,
        zainCashTotal: zain,
        qiCardTotal: qi,
        topItems: topList,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'تمت طباعة تقرير المبيعات بنجاح 🖨️' : 'تعذرت الطباعة الحرارية للتقرير.',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
            ),
            backgroundColor: success ? context.posColors.success : context.posColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تجهيز التقرير: $e'), backgroundColor: context.posColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrintingReport = false);
    }
  }

  // ──────────────────────────── تصدير التقرير PDF احترافي A4 ────────────────────────────

  Future<void> _exportPdfReport() async {
    setState(() => _isExporting = true);
    HapticFeedback.lightImpact();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('restaurantId', isEqualTo: _restaurantId ?? _uid)
          .get();

      final filtered = snap.docs.where((doc) {
        final d = doc.data();
        final ts = d['createdAt'] as Timestamp?;
        return _matchesPeriod(ts?.toDate()) && _matchesChannel(d);
      }).toList();

      double total = 0;
      int completed = 0;
      double madarS = 0; int madarC = 0;
      double takeS = 0; int takeC = 0;
      double dineS = 0; int dineC = 0;
      double delS = 0; int delC = 0;
      double cash = 0; double zain = 0; double qi = 0;
      final Map<String, Map<String, dynamic>> itemsAgg = {};

      for (var doc in filtered) {
        final d = doc.data();
        final price = ((d['total'] ?? d['totalPrice'] ?? d['grandTotal'] ?? d['totalAmount']) as num?)?.toDouble() ?? 0.0;
        final status = (d['status'] ?? '').toString();
        final pMethod = (d['paymentMethod'] ?? 'cash').toString().toLowerCase();
        final orderType = (d['orderType'] ?? '').toString().toLowerCase();
        final source = (d['source'] ?? '').toString().toLowerCase();
        final hasTable = d['tableNumber'] != null && d['tableNumber'].toString().isNotEmpty;

        if (status == 'completed' || status == 'delivered') {
          completed++;
          total += price;

          if (source.contains('madar') || source.contains('app') || d['isAppOrder'] == true) {
            madarS += price; madarC++;
          } else if (orderType == 'dine_in' || hasTable) {
            dineS += price; dineC++;
          } else if (orderType == 'delivery') {
            delS += price; delC++;
          } else {
            takeS += price; takeC++;
          }

          if (pMethod.contains('zain') || pMethod.contains('wallet')) {
            zain += price;
          } else if (pMethod.contains('card') || pMethod.contains('qi')) {
            qi += price;
          } else {
            cash += price;
          }

          if (d['items'] is List) {
            for (var it in d['items']) {
              if (it is Map) {
                final name = it['name'] ?? it['title'] ?? 'وجبة';
                final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                final itPrice = ((it['price'] as num?)?.toDouble() ?? 0.0) * qty;

                if (!itemsAgg.containsKey(name)) {
                  itemsAgg[name] = {'name': name, 'quantity': 0, 'revenue': 0.0};
                }
                itemsAgg[name]!['quantity'] = (itemsAgg[name]!['quantity'] as int) + qty;
                itemsAgg[name]!['revenue'] = (itemsAgg[name]!['revenue'] as double) + itPrice;
              }
            }
          }
        }
      }

      final topList = itemsAgg.values.toList()
        ..sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));

      String periodLabel = 'اليوم';
      if (_selectedPeriod == 'yesterday') periodLabel = 'البارحة';
      if (_selectedPeriod == 'week') periodLabel = 'آخر 7 أيام';
      if (_selectedPeriod == 'month') periodLabel = 'هذا الشهر';
      if (_selectedPeriod == 'all') periodLabel = 'كافة الفترات';

      final arabicFont = await PdfGoogleFonts.cairoRegular();
      final arabicBold = await PdfGoogleFonts.cairoBold();

      pw.MemoryImage? logoImage;
      try {
        final logoBytes = (await rootBundle.load('assets/logo.png')).buffer.asUint8List();
        logoImage = pw.MemoryImage(logoBytes);
      } catch (_) {}

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (logoImage != null) ...[
                          pw.Container(
                            width: 52,
                            height: 52,
                            margin: const pw.EdgeInsets.only(left: 12),
                            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                          ),
                        ],
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(_restaurantName, style: pw.TextStyle(font: arabicBold, fontSize: 18, color: PdfColors.teal900)),
                            pw.Text('تقرير المبيعات والتحليلات الشاملة', style: pw.TextStyle(font: arabicBold, fontSize: 13)),
                            pw.Text('الفترة: $periodLabel | تاريخ الاستخراج: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                          ],
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.teal50,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColors.teal200),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text('إجمالي المبيعات', style: const pw.TextStyle(fontSize: 10, color: PdfColors.teal700)),
                          pw.Text(PosConstants.formatMoney(total), style: pw.TextStyle(font: arabicBold, fontSize: 14, color: PdfColors.teal900)),
                          pw.Text('$completed طلب مكتمل', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 10),
                pw.Text('توزيع المبيعات حسب القنوات', style: pw.TextStyle(font: arabicBold, fontSize: 12)),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  headers: ['القناة', 'عدد الطلبات', 'إجمالي المبيعات (د.ع)', 'النسبة'],
                  data: [
                    ['تطبيق مدار', '$madarC', PosConstants.formatMoney(madarS), total > 0 ? '${((madarS / total) * 100).toStringAsFixed(1)}%' : '0%'],
                    ['سفري / مباشر', '$takeC', PosConstants.formatMoney(takeS), total > 0 ? '${((takeS / total) * 100).toStringAsFixed(1)}%' : '0%'],
                    ['صالة وطاولات', '$dineC', PosConstants.formatMoney(dineS), total > 0 ? '${((dineS / total) * 100).toStringAsFixed(1)}%' : '0%'],
                    ['توصيل خارجي', '$delC', PosConstants.formatMoney(delS), total > 0 ? '${((delS / total) * 100).toStringAsFixed(1)}%' : '0%'],
                  ],
                  headerStyle: pw.TextStyle(font: arabicBold, color: PdfColors.white, fontSize: 10),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellAlignment: pw.Alignment.centerRight,
                  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                ),
                pw.SizedBox(height: 14),
                pw.Text('توزيع طرق الدفع', style: pw.TextStyle(font: arabicBold, fontSize: 12)),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  headers: ['طريقة الدفع', 'المبلغ (د.ع)', 'النسبة من الإجمالي'],
                  data: [
                    ['نقدي (كاش)', PosConstants.formatMoney(cash), total > 0 ? '${((cash / total) * 100).toStringAsFixed(1)}%' : '0%'],
                    ['زين كاش / محافظ', PosConstants.formatMoney(zain), total > 0 ? '${((zain / total) * 100).toStringAsFixed(1)}%' : '0%'],
                    ['بطاقة كي كارد / ماستر', PosConstants.formatMoney(qi), total > 0 ? '${((qi / total) * 100).toStringAsFixed(1)}%' : '0%'],
                  ],
                  headerStyle: pw.TextStyle(font: arabicBold, color: PdfColors.white, fontSize: 10),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellAlignment: pw.Alignment.centerRight,
                  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                ),
                if (topList.isNotEmpty) ...[
                  pw.SizedBox(height: 14),
                  pw.Text('أكثر الوجبات طلباً', style: pw.TextStyle(font: arabicBold, fontSize: 12)),
                  pw.SizedBox(height: 6),
                  pw.TableHelper.fromTextArray(
                    headers: ['اسم الوجبة', 'الكمية المباعة', 'إجمالي الإيراد (د.ع)'],
                    data: topList.take(8).map((it) => [
                      it['name'].toString(),
                      it['quantity'].toString(),
                      PosConstants.formatMoney((it['revenue'] as num).toDouble()),
                    ]).toList(),
                    headerStyle: pw.TextStyle(font: arabicBold, color: PdfColors.white, fontSize: 10),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    cellAlignment: pw.Alignment.centerRight,
                    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  ),
                ],
                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('منظومة مدار المتكاملة لإدارة المطاعم • Madar OS', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                    pw.Text('صفحة 1 من 1', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                  ],
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Madar_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تصدير PDF: $e'), backgroundColor: context.posColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ──────────────────────────── تصدير التقرير بتنسيق CSV ────────────────────────────

  Future<void> _exportCsvReport() async {
    setState(() => _isExporting = true);
    HapticFeedback.lightImpact();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('restaurantId', isEqualTo: _restaurantId ?? _uid)
          .get();

      final filtered = snap.docs.where((doc) {
        final d = doc.data();
        final ts = d['createdAt'] as Timestamp?;
        return _matchesPeriod(ts?.toDate()) && _matchesChannel(d);
      }).toList();

      final buffer = StringBuffer();
      // UTF-8 BOM so Excel opens Arabic correctly
      buffer.write('\uFEFF');
      buffer.writeln('رقم الطلب,التاريخ والوقت,نوع الطلب,القناة,طريقة الدفع,الحالة,المبلغ الإجمالي');

      for (var doc in filtered) {
        final d = doc.data();
        final orderNum = d['orderNumber'] ?? doc.id.substring(0, 6);
        final ts = (d['createdAt'] as Timestamp?)?.toDate();
        final dateStr = ts != null ? DateFormat('yyyy-MM-dd HH:mm').format(ts) : '-';
        final orderType = d['orderType'] ?? 'takeaway';
        final source = d['source'] ?? (d['isAppOrder'] == true ? 'تطبيق مدار' : 'نقطة بيع');
        final paymentMethod = d['paymentMethod'] ?? 'كاش';
        final status = d['status'] ?? '-';
        final total = ((d['total'] ?? d['totalPrice'] ?? d['grandTotal'] ?? 0) as num).toDouble();

        buffer.writeln('"$orderNum","$dateStr","$orderType","$source","$paymentMethod","$status",$total');
      }

      final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'sales_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم تجهيز ملف CSV بنجاح!'),
            backgroundColor: context.posColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تصدير CSV: $e'), backgroundColor: context.posColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}
