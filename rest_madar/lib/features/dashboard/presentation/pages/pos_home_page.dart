import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/error/madar_crash_guard.dart';
import '../../../../core/design_system/madar_design_system.dart';
import '../../../../core/localization/pos_language_controller.dart';
import '../../../../services/thermal_printer_service.dart';
import '../../../shell/presentation/desktop_shell_page.dart' show MadarNav;
import '../../../pos/domain/pos_order.dart';

/// الشاشة الرئيسية التنفيذية المتطورة (Executive Live Command Center)
/// مصممة بنمط لوحة القيادة اللحظية للمطاعم المتقدمة:
/// 1. شريط الرأس التشغيلي الفخم مع حالة الوردية المباشرة وحالة السحابة
/// 2. بطاقات مؤشرات الأداء الحية الفاخرة (KPI Cards)
/// 3. مخطط سرعة وتدفق المبيعات الأسبوعية (7-Day Sales Velocity Chart)
/// 4. رادار إشغال الصالة والطاولات ورادار المخزون الحرج
/// 5. تدفق الطلبات المباشرة اللحظية (Live Orders Stream) مع إجراءات التحديث والطباعة الفورية
/// 6. قائمة الأصناف الأكثر طلباً اليوم وتوزيع قنوات البيع
class PosHomePage extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const PosHomePage({super.key, required this.onNavigate});

  @override
  State<PosHomePage> createState() => _PosHomePageState();
}

class _PosHomePageState extends State<PosHomePage> with SingleTickerProviderStateMixin {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _effectiveRestaurantId = '';
  String _restaurantDisplayName = 'مطعم مدار';
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // رادار المخزون الحرج
  StreamSubscription<QuerySnapshot>? _inventorySub;
  List<Map<String, dynamic>> _lowStockAlerts = [];
  int _totalInventoryCount = 0;

  // رادار الطاولات
  int _totalTablesCount = 12;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _resolveRestaurantDetails();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _inventorySub?.cancel();
    super.dispose();
  }

  Future<void> _resolveRestaurantDetails() async {
    if (_uid.isEmpty) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (userDoc.exists && userDoc.data() != null && mounted) {
        final data = userDoc.data()!;
        final restId = data['restaurantId'] ?? data['merchantId'] ?? data['storeId'];
        final name = data['restaurantName'] ?? data['fullName'] ?? 'مطعم مدار';
        final tables = data['tablesCount'] ?? 12;

        setState(() {
          _restaurantDisplayName = name.toString();
          _totalTablesCount = (tables as num).toInt();
          if (restId != null && restId.toString().trim().isNotEmpty) {
            _effectiveRestaurantId = restId.toString().trim();
          }
        });
      }
    } catch (_) {}

    _listenLowStock();
  }

  void _listenLowStock() {
    final targetId = _effectiveRestaurantId.isNotEmpty ? _effectiveRestaurantId : _uid;
    if (targetId.isEmpty) return;

    _inventorySub?.cancel();
    _inventorySub = FirebaseFirestore.instance
        .collection('merchants')
        .doc(targetId)
        .collection('inventory')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final List<Map<String, dynamic>> urgent = [];
      for (var d in snap.docs) {
        final data = d.data();
        final current = (data['currentQuantity'] ?? data['quantity'] ?? 0).toDouble();
        final minAlert = (data['minAlertLevel'] ?? 5).toDouble();
        if (current <= minAlert) {
          urgent.add({
            'id': d.id,
            'name': data['name'] ?? 'مادة أولية',
            'current': current,
            'unit': data['unit'] ?? 'كغم',
            'min': minAlert,
          });
        }
      }
      setState(() {
        _totalInventoryCount = snap.docs.length;
        _lowStockAlerts = urgent;
      });
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;
    final ids = [
      _uid,
      if (_effectiveRestaurantId.isNotEmpty && _effectiveRestaurantId != _uid)
        _effectiveRestaurantId,
    ];

    return ListenableBuilder(
      listenable: PosLanguageController.instance,
      builder: (context, _) {
        return Directionality(
          textDirection: PosLanguageController.instance.textDirection,
          child: Scaffold(
            backgroundColor: c.background,
            body: SafeCrashBoundary(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _uid.isEmpty
                    ? null
                    : (ids.length == 1
                        ? FirebaseFirestore.instance
                            .collection('orders')
                            .where('restaurantId', isEqualTo: ids.first)
                            .snapshots()
                        : FirebaseFirestore.instance
                            .collection('orders')
                            .where('restaurantId', whereIn: ids)
                            .snapshots()),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  final stats = _computeDashboardStats(docs);

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: MadarResponsive.contentPadding(context),
                      vertical: 18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // تنبيه تشخيصي في حال الخطأ
                        if (snapshot.hasError) ...[
                          _buildErrorAlert(context, snapshot.error, snapshot.stackTrace),
                          const SizedBox(height: 16),
                        ],

                        // 1. شريط الرأس القيادي مع حالة الوردية المباشرة (Hero Operational Bar)
                        _buildHeroOperationalBanner(context, stats),

                        const SizedBox(height: 18),

                        // 2. بطاقات مؤشرات الأداء الحية الفاخرة (Executive KPI Cards)
                        _buildExecutiveKpiCards(context, stats),

                        const SizedBox(height: 24),

                        // 3. القسم الأوسط: مخطط سرعة المبيعات + رادار الصالة والمخزون
                        _buildMiddleOperationalSection(context, stats),

                        const SizedBox(height: 24),

                        // 4. القسم السفلي: تدفق الطلبات الحية الفورية + الأصناف الأكثر طلباً
                        _buildBottomOperationalSection(context, stats),

                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────── 1. شريط الرأس القيادي المتطور ───────────────────────────

  Widget _buildHeroOperationalBanner(BuildContext context, _DashboardStats stats) {
    final c = context.posColors;
    final isDark = context.isDarkMode;
    final isEn = PosLanguageController.instance.isEnglish;
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE، d MMMM yyyy', isEn ? 'en_US' : 'ar').format(now);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.card,
            isDark ? const Color(0xFF19202D) : const Color(0xFFF8FAFC),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 980;

          return Flex(
            direction: isWide ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: isWide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // الهوية واسم المطعم وحالة السحابة
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF5B22), Color(0xFFFF8A3D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF5B22).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(7),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.restaurant_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _restaurantDisplayName,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: c.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // شارة نبضية للنظام المباشر
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ScaleTransition(
                                  scale: _pulseAnimation,
                                  child: Container(
                                    width: 6.5,
                                    height: 6.5,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isEn ? 'Live Cloud OS' : 'متصل بالسحابة',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$dateStr  •  ${isEn ? 'Executive Operations Dashboard' : 'لوحة العمليات والتحكم اللحظي'}',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (!isWide) const SizedBox(height: 14),

              // أزرار التشغيل السريع
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // زر بيع كاشير سريع
                  _buildQuickActionBtn(
                    label: isEn ? 'POS Cashier' : 'بيع كاشير سريع',
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFFFF5B22),
                    onTap: () => widget.onNavigate(MadarNav.pos),
                  ),

                  // زر شاشة المطبخ
                  _buildQuickActionBtn(
                    label: isEn ? 'Kitchen KDS' : 'شاشة المطبخ',
                    icon: Icons.soup_kitchen_rounded,
                    color: const Color(0xFF10B981),
                    badge: stats.activeOrdersCount > 0 ? '${stats.activeOrdersCount}' : null,
                    onTap: () => widget.onNavigate(MadarNav.kds),
                  ),

                  // زر التقارير
                  _buildQuickActionBtn(
                    label: isEn ? 'Analytics' : 'التقارير',
                    icon: Icons.analytics_rounded,
                    color: const Color(0xFF8B5CF6),
                    onTap: () => widget.onNavigate(MadarNav.reports),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickActionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── 2. بطاقات مؤشرات الأداء الحية (KPIs) ───────────────────────────

  Widget _buildExecutiveKpiCards(BuildContext context, _DashboardStats stats) {
    final isEn = PosLanguageController.instance.isEnglish;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount;
        if (width >= 1250) {
          crossAxisCount = 5;
        } else if (width >= 900) {
          crossAxisCount = 4;
        } else if (width >= 560) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 1;
        }

        final cards = [
          _buildKpiCard(
            context: context,
            title: isEn ? "Today's Revenue" : 'مبيعات اليوم',
            value: '${_formatNumber(stats.todaySales)} ${isEn ? 'IQD' : 'د.ع'}',
            badgeText: stats.yesterdaySalesFormatted,
            badgeIsPositive: stats.isSalesGrowthPositive,
            badgePrefix: isEn ? 'vs yesterday' : 'مقارنة بالأمس',
            icon: Icons.payments_rounded,
            accentColor: const Color(0xFF10B981),
            onTap: () => widget.onNavigate(MadarNav.reports),
          ),
          _buildKpiCard(
            context: context,
            title: isEn ? "Today's Orders" : 'فواتير اليوم',
            value: '${stats.todayOrdersCount}',
            badgeText: stats.ordersGrowthFormatted,
            badgeIsPositive: stats.isOrdersGrowthPositive,
            badgePrefix: isEn ? 'growth' : 'نمو الطلبات',
            icon: Icons.receipt_long_rounded,
            accentColor: const Color(0xFF3B82F6),
            onTap: () => widget.onNavigate(MadarNav.orders),
          ),
          _buildKpiCard(
            context: context,
            title: isEn ? 'Active in Kitchen' : 'قيد التحضير بالمطبخ',
            value: '${stats.activeOrdersCount}',
            badgeText: isEn ? 'Live Now' : 'مباشر الآن',
            badgeIsPositive: true,
            icon: Icons.soup_kitchen_rounded,
            accentColor: const Color(0xFFFF5B22),
            onTap: () => widget.onNavigate(MadarNav.kds),
            isPulsing: stats.activeOrdersCount > 0,
          ),
          _buildKpiCard(
            context: context,
            title: isEn ? 'Avg. Ticket Value' : 'متوسط الفاتورة',
            value: '${_formatNumber(stats.averageOrderValue.round())} ${isEn ? 'IQD' : 'د.ع'}',
            badgeText: '${stats.todayValidOrdersCount} ${isEn ? 'Bills' : 'فاتورة'}',
            badgeIsPositive: true,
            icon: Icons.shopping_bag_rounded,
            accentColor: const Color(0xFF8B5CF6),
            onTap: () => widget.onNavigate(MadarNav.reports),
          ),
          _buildKpiCard(
            context: context,
            title: isEn ? "Today's Cash" : 'المبيعات النقدية',
            value: '${_formatNumber(stats.todayCashSales.round())} ${isEn ? 'IQD' : 'د.ع'}',
            badgeText: isEn ? 'Cash Drawer' : 'صندوق الكاش',
            badgeIsPositive: true,
            icon: Icons.payments_rounded,
            accentColor: const Color(0xFF14B8A6),
            onTap: () => widget.onNavigate(MadarNav.reports),
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 136,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required BuildContext context,
    required String title,
    required String value,
    required String badgeText,
    required bool badgeIsPositive,
    String? badgePrefix,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
    bool isPulsing = false,
  }) {
    final c = context.posColors;
    final isDark = context.isDarkMode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPulsing
                  ? accentColor.withValues(alpha: 0.6)
                  : c.border.withValues(alpha: 0.8),
              width: isPulsing ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isPulsing
                    ? accentColor.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: c.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 16, color: accentColor),
                  ),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: c.textPrimary,
                    height: 1.1,
                  ),
                ),
              ),
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: (badgeIsPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: badgeIsPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (badgePrefix != null) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        badgePrefix,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: c.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── 3. القسم الأوسط: مخطط المبيعات + الرادار ───────────────────────────

  Widget _buildMiddleOperationalSection(BuildContext context, _DashboardStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // مخطط تدفق المبيعات الأسبوعية (Flex: 7)
              Expanded(
                flex: 7,
                child: _buildSalesVelocityChartCard(context, stats),
              ),
              const SizedBox(width: 16),
              // رادار الصالة والمخزون الحرج (Flex: 5)
              Expanded(
                flex: 5,
                child: _buildHallAndStockRadar(context, stats),
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildSalesVelocityChartCard(context, stats),
            const SizedBox(height: 16),
            _buildHallAndStockRadar(context, stats),
          ],
        );
      },
    );
  }

  /// مخطط بياني تفاعلي لمبيعات 7 أيام وسرعة تدفق الطلبات
  Widget _buildSalesVelocityChartCard(BuildContext context, _DashboardStats stats) {
    final c = context.posColors;
    final isEn = PosLanguageController.instance.isEnglish;
    final maxSale = stats.weeklySales.fold<double>(1.0, (prev, val) => val > prev ? val : prev);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF10B981), size: 19),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn ? '7-Day Sales Velocity' : 'سرعة المبيعات ومسار 7 أيام',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        isEn
                            ? 'Weekly revenue performance breakdown'
                            : 'المسار الإيرادي المقارن للأيام السبعة الماضية',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: () => widget.onNavigate(MadarNav.reports),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isEn ? 'Full Report' : 'التقرير التفصيلي',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: c.primary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.arrow_forward_ios_rounded, size: 10, color: c.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // أعمدة المخطط البياني الأسبوعي
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(stats.weeklySales.length, (index) {
                final sale = stats.weeklySales[index];
                final ordersCount = stats.weeklyOrders[index].toInt();
                final label = stats.weeklyDaysLabels[index];
                final isToday = index == stats.weeklySales.length - 1;
                final heightFactor = (sale / maxSale).clamp(0.06, 1.0);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // القيمة فوق العمود
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            sale > 0 ? _formatCompactNumber(sale) : '0',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 9.5,
                              fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                              color: isToday ? const Color(0xFFFF5B22) : c.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // شريط العمود الملون
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: heightFactor,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: isToday
                                      ? [const Color(0xFFFF5B22), const Color(0xFFFF8A3D)]
                                      : [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
                                ),
                                boxShadow: isToday
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFFF5B22).withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // اسم اليوم
                        Text(
                          isToday ? (isEn ? 'Today' : 'اليوم') : label,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 10.5,
                            fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                            color: isToday ? c.textPrimary : c.textMuted,
                          ),
                          maxLines: 1,
                        ),
                        Text(
                          '$ordersCount ${isEn ? 'ord' : 'طلب'}',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 8.5,
                            color: c.textMuted.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // ملخص قنوات المبيعات
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.spaceAround,
            children: [
              _buildChannelPill('صالة', stats.dineInCount, stats.dineInSales, const Color(0xFF3B82F6)),
              _buildChannelPill('سفري', stats.takeawayCount, stats.takeawaySales, const Color(0xFF10B981)),
              _buildChannelPill('توصيل', stats.deliveryCount, stats.deliverySales, const Color(0xFF8B5CF6)),
              _buildChannelPill('تطبيق مدار', stats.appOrdersCount, stats.appOrdersSales, const Color(0xFFFF5B22)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelPill(String title, int count, double revenue, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$title: ',
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        Text(
          '$count (${revenue > 0 ? _formatCompactNumber(revenue) : '0'})',
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: color, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  /// رادار الصالة والطاولات ورادار المخزون الحرج
  Widget _buildHallAndStockRadar(BuildContext context, _DashboardStats stats) {
    final c = context.posColors;
    final isEn = PosLanguageController.instance.isEnglish;

    // حساب الطاولات المشغولة حالياً
    final occupiedTables = stats.occupiedTablesCount.clamp(0, _totalTablesCount);
    final availableTables = (_totalTablesCount - occupiedTables).clamp(0, _totalTablesCount);
    final occupancyPercent = _totalTablesCount > 0 ? (occupiedTables / _totalTablesCount) : 0.0;

    return Column(
      children: [
        // 1. بطاقة رادار الصالة
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.border.withValues(alpha: 0.8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.table_restaurant_rounded, color: Color(0xFF8B5CF6), size: 17),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEn ? 'Hall & Tables Occupancy' : 'إشغال الصالة والطاولات',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => widget.onNavigate(MadarNav.tables),
                    child: Text(
                      isEn ? 'View Floor' : 'خريطة الصالة',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$occupiedTables / $_totalTablesCount ${isEn ? 'Tables Busy' : 'طاولات مشغولة'}',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$availableTables ${isEn ? 'Tables available now' : 'طاولة شاغرة حالياً'}',
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF10B981), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${(occupancyPercent * 100).toStringAsFixed(0)}% إشغال',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: occupancyPercent,
                  minHeight: 6,
                  backgroundColor: c.border.withValues(alpha: 0.4),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 2. بطاقة رادار المخزون الحرج
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _lowStockAlerts.isNotEmpty
                  ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                  : c.border.withValues(alpha: 0.8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: (_lowStockAlerts.isNotEmpty ? const Color(0xFFEF4444) : const Color(0xFF10B981))
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          _lowStockAlerts.isNotEmpty ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                          color: _lowStockAlerts.isNotEmpty ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEn ? 'Stock & Inventory Alerts' : 'تنبيهات المخزون والمواد',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => widget.onNavigate(MadarNav.inventory),
                    child: Text(
                      isEn ? 'Inventory ($_totalInventoryCount items)' : 'المستودع ($_totalInventoryCount مادة)',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: c.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_lowStockAlerts.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isEn ? 'All ingredients at safe levels ✓' : 'المخزون بمستويات آمنة وطبيعية ✓',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._lowStockAlerts.take(2).map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${item['name']}',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF991B1B)),
                                maxLines: 1,
                              ),
                            ),
                            Text(
                              'متبقي ${item['current']} ${item['unit']}',
                              style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626)),
                            ),
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────── 4. القسم السفلي: تدفق الطلبات الحية + الأكثر مبيعاً ───────────────────────────

  Widget _buildBottomOperationalSection(BuildContext context, _DashboardStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // تدفق أحدث العمليات والطلبات الحية (Flex: 7)
              Expanded(
                flex: 7,
                child: _buildLiveOrdersFeedCard(context, stats),
              ),
              const SizedBox(width: 16),
              // الأكثر طلباً اليوم وقنوات البيع (Flex: 5)
              Expanded(
                flex: 5,
                child: _buildTopProductsAndChannelsCard(context, stats),
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildLiveOrdersFeedCard(context, stats),
            const SizedBox(height: 16),
            _buildTopProductsAndChannelsCard(context, stats),
          ],
        );
      },
    );
  }

  /// جدول وبطاقات أحدث العمليات المباشرة اللحظية
  Widget _buildLiveOrdersFeedCard(BuildContext context, _DashboardStats stats) {
    final c = context.posColors;
    final isEn = PosLanguageController.instance.isEnglish;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5B22).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFFF5B22), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEn ? 'Live Orders Stream' : 'تدفق العمليات والطلبات الحية',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5B22).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${stats.recentOrders.length} ${isEn ? 'Live' : 'مباشر'}',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFF5B22),
                      ),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => widget.onNavigate(MadarNav.orders),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isEn ? 'View All' : 'إدارة الطلبات',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: c.primary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.arrow_forward_ios_rounded, size: 10, color: c.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (stats.recentOrders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 38, color: c.textMuted.withValues(alpha: 0.4)),
                    const SizedBox(height: 8),
                    Text(
                      isEn ? 'No live orders yet today' : 'لا توجد طلبات مسجلة حتى الآن اليوم',
                      style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () => widget.onNavigate(MadarNav.pos),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(
                        isEn ? 'Create First Order' : 'تسجيل أول طلب كاشير',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...stats.recentOrders.map((order) => _buildLiveOrderItemRow(context, order)),
        ],
      ),
    );
  }

  Widget _buildLiveOrderItemRow(BuildContext context, PosOrder order) {
    final c = context.posColors;
    final isEn = PosLanguageController.instance.isEnglish;
    final orderTime = DateFormat('hh:mm a').format(order.createdAt);
    final statusColor = _resolveStatusColor(order.status);
    final statusLabel = _resolveStatusLabel(order.status, isEn);

    // تفاصيل الزبون أو الطاولة
    String partyLabel = order.customerName?.isNotEmpty == true ? order.customerName! : (isEn ? 'Walk-in' : 'زبون مباشر');
    if (order.tableNumber?.isNotEmpty == true) {
      partyLabel = isEn ? 'Table ${order.tableNumber}' : 'طاولة ${order.tableNumber}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.background.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          // رقم الطلب والقناة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.border),
            ),
            child: Text(
              '#${order.orderId.length > 5 ? order.orderId.substring(order.orderId.length - 5) : order.orderId}',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: c.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // الزبون والوقت
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        partyLabel,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildOrderTypeTag(order.orderType),
                  ],
                ),
                Text(
                  '$orderTime  •  ${order.items.length} ${isEn ? 'items' : 'وجبات'}',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textMuted),
                ),
              ],
            ),
          ),

          // السعر والحالة
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_formatNumber(order.totalAmount)} ${isEn ? 'IQD' : 'د.ع'}',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFFF5B22),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 10),

          // زر طباعة حرارية سريعة
          IconButton(
            onPressed: () => _quickPrintOrder(order),
            tooltip: isEn ? 'Quick Print Receipt' : 'طباعة الفاتورة سريعاً',
            icon: const Icon(Icons.print_rounded, size: 18),
            color: c.textMuted,
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTypeTag(String type) {
    Color color;
    String label;

    switch (type.toLowerCase()) {
      case 'dine_in':
        color = const Color(0xFF3B82F6);
        label = 'صالة';
        break;
      case 'delivery':
        color = const Color(0xFF8B5CF6);
        label = 'توصيل';
        break;
      case 'takeaway':
      default:
        color = const Color(0xFF10B981);
        label = 'سفري';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: GoogleFonts.ibmPlexSansArabic(fontSize: 9, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Future<void> _quickPrintOrder(PosOrder order) async {
    try {
      final success = await ThermalPrinterService.printOrder(
        order: order,
        restaurantName: _restaurantDisplayName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'تم إرسال الفاتورة للطابعة بنجاح 🖨️' : 'تعذر إتمام الطباعة، تأكد من الطابعة',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
            ),
            backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ بالطباعة: $e', style: GoogleFonts.ibmPlexSansArabic()),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  /// بطاقة الأكثر طلباً اليوم وتوزيع قنوات البيع
  Widget _buildTopProductsAndChannelsCard(BuildContext context, _DashboardStats stats) {
    final c = context.posColors;
    final isEn = PosLanguageController.instance.isEnglish;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8A3D).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.star_rounded, color: Color(0xFFFF8A3D), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                isEn ? 'Top Selling Items Today' : 'الأكثر طلباً ومبيعاً اليوم',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (stats.topProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  isEn ? 'No product sales recorded yet' : 'بانتظار تسجيل وجبات جديدة اليوم',
                  style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 12),
                ),
              ),
            )
          else
            ...stats.topProducts.take(4).map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.background.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.border.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5B22).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(p.icon, size: 15, color: const Color(0xFFFF5B22)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p.name,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${p.quantity} ${isEn ? 'sold' : 'وجبة'}',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFFF5B22),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_formatCompactNumber(p.revenue)} د.ع',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: c.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // توزيع قنوات الطلب كشريط تقدم
          Text(
            isEn ? 'Order Channels Breakdown' : 'توزيع قنوات الطلبات المباشرة',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
          const SizedBox(height: 8),
          ...stats.orderSources.map((source) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          source.label,
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                        ),
                        Text(
                          '${source.count} (${source.percent.toStringAsFixed(0)}%)',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: source.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: source.percent > 0 ? (source.percent / 100).clamp(0.0, 1.0) : 0.0,
                        minHeight: 4.5,
                        backgroundColor: source.color.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(source.color),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─────────────────────────── دوال المساعدة والحسابات ───────────────────────────

  Widget _buildErrorAlert(BuildContext context, Object? error, StackTrace? stackTrace) {
    final errorInfo = MadarCrashGuard.analyzeError(error, stackTrace);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF4444)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تنبيه قاعدة البيانات: ${errorInfo.title}',
                  style: GoogleFonts.ibmPlexSansArabic(color: const Color(0xFF991B1B), fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                Text(
                  errorInfo.message,
                  style: GoogleFonts.ibmPlexSansArabic(color: const Color(0xFFB91C1C), fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => MadarCrashGuard.showErrorDialog(context, error, stackTrace: stackTrace),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            child: Text('التفاصيل', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Color _resolveStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'new':
        return const Color(0xFF3B82F6);
      case 'preparing':
      case 'in_kitchen':
        return const Color(0xFFFF5B22);
      case 'ready':
        return const Color(0xFF10B981);
      case 'completed':
      case 'delivered':
        return const Color(0xFF059669);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _resolveStatusLabel(String status, bool isEn) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'new':
        return isEn ? 'Pending' : 'جديد';
      case 'preparing':
      case 'in_kitchen':
        return isEn ? 'Kitchen' : 'بالمطبخ';
      case 'ready':
        return isEn ? 'Ready' : 'جاهز';
      case 'completed':
      case 'delivered':
        return isEn ? 'Done' : 'مكتمل';
      case 'cancelled':
        return isEn ? 'Cancelled' : 'ملغى';
      default:
        return status;
    }
  }

  String _formatNumber(num amount) {
    return NumberFormat('#,###', 'en').format(amount);
  }

  String _formatCompactNumber(num amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k';
    }
    return amount.toStringAsFixed(0);
  }

  IconData _matchProductIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('برغر') || lower.contains('burger') || lower.contains('سندويش')) {
      return Icons.lunch_dining_rounded;
    }
    if (lower.contains('بيتزا') || lower.contains('pizza')) {
      return Icons.local_pizza_rounded;
    }
    if (lower.contains('شاورما') || lower.contains('shawarma') || lower.contains('كباب') || lower.contains('مشوي')) {
      return Icons.kebab_dining_rounded;
    }
    if (lower.contains('دجاج') || lower.contains('chicken') || lower.contains('كرسبي') || lower.contains('كنتاكي')) {
      return Icons.dinner_dining_rounded;
    }
    if (lower.contains('عصير') || lower.contains('بيبسي') || lower.contains('مشروب') || lower.contains('ماء') || lower.contains('كولا')) {
      return Icons.local_drink_rounded;
    }
    if (lower.contains('بطاطا') || lower.contains('fries')) {
      return Icons.fastfood_rounded;
    }
    return Icons.restaurant_menu_rounded;
  }

  // ─────────────────────────── معالجة وحساب الإحصائيات ───────────────────────────

  _DashboardStats _computeDashboardStats(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final List<PosOrder> allOrders = [];

    for (var doc in docs) {
      try {
        final data = doc.data();
        allOrders.add(PosOrder.fromMap(data, doc.id));
      } catch (e) {
        debugPrint('[PosHomePage] Error parsing order ${doc.id}: $e');
      }
    }

    allOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfYesterday = startOfToday.subtract(const Duration(days: 1));

    // 1. طلبات اليوم
    final todayOrders = allOrders
        .where((o) => o.createdAt.isAfter(startOfToday) || o.createdAt.isAtSameMomentAs(startOfToday))
        .toList();
    final todayValidOrders = todayOrders.where((o) => o.status.toLowerCase() != 'cancelled').toList();

    final double todaySales = todayValidOrders.fold<double>(0.0, (acc, o) => acc + o.totalAmount);
    final double todayCashSales = todayValidOrders
        .where((o) => o.paymentMethod.toLowerCase() == 'cash' || o.paymentMethod.toLowerCase() == 'كاش')
        .fold<double>(0.0, (acc, o) => acc + o.totalAmount);

    final int todayOrdersCount = todayOrders.length;
    final int todayValidOrdersCount = todayValidOrders.length;

    // طلبات الأمس
    final yesterdayOrders = allOrders.where((o) =>
        (o.createdAt.isAfter(startOfYesterday) || o.createdAt.isAtSameMomentAs(startOfYesterday)) &&
        o.createdAt.isBefore(startOfToday)).toList();
    final double yesterdaySales = yesterdayOrders
        .where((o) => o.status.toLowerCase() != 'cancelled')
        .fold<double>(0.0, (acc, o) => acc + o.totalAmount);

    double salesGrowthPercent = 0.0;
    bool isSalesGrowthPositive = true;
    if (yesterdaySales > 0) {
      salesGrowthPercent = ((todaySales - yesterdaySales) / yesterdaySales) * 100;
      isSalesGrowthPositive = salesGrowthPercent >= 0;
    } else if (todaySales > 0) {
      salesGrowthPercent = 100.0;
      isSalesGrowthPositive = true;
    }

    double ordersGrowthPercent = 0.0;
    bool isOrdersGrowthPositive = true;
    if (yesterdayOrders.isNotEmpty) {
      ordersGrowthPercent = ((todayOrdersCount - yesterdayOrders.length) / yesterdayOrders.length) * 100;
      isOrdersGrowthPositive = ordersGrowthPercent >= 0;
    } else if (todayOrdersCount > 0) {
      ordersGrowthPercent = 100.0;
      isOrdersGrowthPositive = true;
    }

    // 3. متوسط الفاتورة
    final double averageOrderValue = todayValidOrders.isNotEmpty ? (todaySales / todayValidOrders.length) : 0.0;

    // 4. الطلبات قيد التحضير بالمطبخ
    final int activeOrdersCount = allOrders.where((o) {
      final s = o.status.toLowerCase();
      return s == 'pending' || s == 'new' || s == 'preparing' || s == 'in_kitchen' || s == 'ready';
    }).length;

    // 5. الطاولات المشغولة حالياً
    final Set<String> activeTables = {};
    for (var o in allOrders) {
      final s = o.status.toLowerCase();
      if ((s == 'pending' || s == 'preparing' || s == 'ready' || s == 'in_kitchen') &&
          o.tableNumber != null &&
          o.tableNumber!.trim().isNotEmpty) {
        activeTables.add(o.tableNumber!.trim());
      }
    }

    // 6. مبيعات الأيام السبعة السابقة
    final List<double> weeklySales = [];
    final List<double> weeklyOrders = [];
    final List<String> weeklyDaysLabels = [];

    for (int i = 6; i >= 0; i--) {
      final dayDate = startOfToday.subtract(Duration(days: i));
      final nextDay = dayDate.add(const Duration(days: 1));

      final dayOrders = allOrders.where((o) =>
          (o.createdAt.isAfter(dayDate) || o.createdAt.isAtSameMomentAs(dayDate)) &&
          o.createdAt.isBefore(nextDay)).toList();

      final daySales = dayOrders
          .where((o) => o.status.toLowerCase() != 'cancelled')
          .fold<double>(0.0, (acc, o) => acc + o.totalAmount);

      weeklySales.add(daySales);
      weeklyOrders.add(dayOrders.length.toDouble());
      weeklyDaysLabels.add(DateFormat('E d', 'ar').format(dayDate));
    }

    // 7. مصادر وقنوات الطلبات
    int appCount = 0;
    double appSales = 0.0;
    int dineInCount = 0;
    double dineInSales = 0.0;
    int takeawayCount = 0;
    double takeawaySales = 0.0;
    int deliveryCount = 0;
    double deliverySales = 0.0;

    for (var o in todayValidOrders) {
      final type = o.orderType.toLowerCase();
      final hasTable = o.tableNumber != null && o.tableNumber!.trim().isNotEmpty;

      if (type == 'delivery') {
        deliveryCount++;
        deliverySales += o.totalAmount;
      } else if (type == 'dine_in' || hasTable) {
        dineInCount++;
        dineInSales += o.totalAmount;
      } else if (type == 'takeaway') {
        takeawayCount++;
        takeawaySales += o.totalAmount;
      } else {
        appCount++;
        appSales += o.totalAmount;
      }
    }

    final int totalSources = appCount + dineInCount + takeawayCount + deliveryCount;
    final List<_OrderSourceStat> orderSources = [
      _OrderSourceStat(
        label: 'صالة',
        count: dineInCount,
        percent: totalSources > 0 ? (dineInCount / totalSources * 100) : 0,
        color: const Color(0xFF3B82F6),
      ),
      _OrderSourceStat(
        label: 'سفري',
        count: takeawayCount,
        percent: totalSources > 0 ? (takeawayCount / totalSources * 100) : 0,
        color: const Color(0xFF10B981),
      ),
      _OrderSourceStat(
        label: 'توصيل',
        count: deliveryCount,
        percent: totalSources > 0 ? (deliveryCount / totalSources * 100) : 0,
        color: const Color(0xFF8B5CF6),
      ),
      _OrderSourceStat(
        label: 'تطبيق مدار',
        count: appCount,
        percent: totalSources > 0 ? (appCount / totalSources * 100) : 0,
        color: const Color(0xFFFF5B22),
      ),
    ];

    // 8. أكثر المنتجات مبيعاً
    final Map<String, int> productCounts = {};
    final Map<String, double> productRevenues = {};

    for (var o in todayValidOrders) {
      for (var it in o.items) {
        final name = it.name.trim();
        if (name.isNotEmpty) {
          productCounts[name] = (productCounts[name] ?? 0) + it.quantity;
          productRevenues[name] = (productRevenues[name] ?? 0.0) + it.totalPrice;
        }
      }
    }

    final sortedProductEntries = productCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<_ProductSaleStat> topProducts = [];
    for (var entry in sortedProductEntries.take(5)) {
      final name = entry.key;
      final qty = entry.value;
      final rev = productRevenues[name] ?? 0.0;
      topProducts.add(_ProductSaleStat(
        name: name,
        quantity: qty,
        revenue: rev,
        icon: _matchProductIcon(name),
      ));
    }

    // 9. أحدث الطلبات اللحظية (أول 6 طلبات)
    final List<PosOrder> recentOrders = allOrders.take(6).toList();

    return _DashboardStats(
      todaySales: todaySales,
      todayCashSales: todayCashSales,
      todayOrdersCount: todayOrdersCount,
      todayValidOrdersCount: todayValidOrdersCount,
      averageOrderValue: averageOrderValue,
      activeOrdersCount: activeOrdersCount,
      occupiedTablesCount: activeTables.length,
      salesGrowthPercent: salesGrowthPercent,
      isSalesGrowthPositive: isSalesGrowthPositive,
      ordersGrowthPercent: ordersGrowthPercent,
      isOrdersGrowthPositive: isOrdersGrowthPositive,
      weeklySales: weeklySales,
      weeklyOrders: weeklyOrders,
      weeklyDaysLabels: weeklyDaysLabels,
      orderSources: orderSources,
      topProducts: topProducts,
      recentOrders: recentOrders,
      dineInCount: dineInCount,
      dineInSales: dineInSales,
      takeawayCount: takeawayCount,
      takeawaySales: takeawaySales,
      deliveryCount: deliveryCount,
      deliverySales: deliverySales,
      appOrdersCount: appCount,
      appOrdersSales: appSales,
    );
  }
}

// ─────────────────────────── نماذج البيانات الإحصائية ───────────────────────────

class _ProductSaleStat {
  final String name;
  final int quantity;
  final double revenue;
  final IconData icon;

  _ProductSaleStat({
    required this.name,
    required this.quantity,
    required this.revenue,
    required this.icon,
  });
}

class _OrderSourceStat {
  final String label;
  final int count;
  final double percent;
  final Color color;

  _OrderSourceStat({
    required this.label,
    required this.count,
    required this.percent,
    required this.color,
  });
}

class _DashboardStats {
  final double todaySales;
  final double todayCashSales;
  final int todayOrdersCount;
  final int todayValidOrdersCount;
  final double averageOrderValue;
  final int activeOrdersCount;
  final int occupiedTablesCount;

  final double salesGrowthPercent;
  final bool isSalesGrowthPositive;
  final double ordersGrowthPercent;
  final bool isOrdersGrowthPositive;

  final List<double> weeklySales;
  final List<double> weeklyOrders;
  final List<String> weeklyDaysLabels;

  final List<_OrderSourceStat> orderSources;
  final List<_ProductSaleStat> topProducts;
  final List<PosOrder> recentOrders;

  final int dineInCount;
  final double dineInSales;
  final int takeawayCount;
  final double takeawaySales;
  final int deliveryCount;
  final double deliverySales;
  final int appOrdersCount;
  final double appOrdersSales;

  _DashboardStats({
    required this.todaySales,
    required this.todayCashSales,
    required this.todayOrdersCount,
    required this.todayValidOrdersCount,
    required this.averageOrderValue,
    required this.activeOrdersCount,
    required this.occupiedTablesCount,
    required this.salesGrowthPercent,
    required this.isSalesGrowthPositive,
    required this.ordersGrowthPercent,
    required this.isOrdersGrowthPositive,
    required this.weeklySales,
    required this.weeklyOrders,
    required this.weeklyDaysLabels,
    required this.orderSources,
    required this.topProducts,
    required this.recentOrders,
    required this.dineInCount,
    required this.dineInSales,
    required this.takeawayCount,
    required this.takeawaySales,
    required this.deliveryCount,
    required this.deliverySales,
    required this.appOrdersCount,
    required this.appOrdersSales,
  });

  String get yesterdaySalesFormatted {
    if (salesGrowthPercent == 0.0) return '0%';
    final sign = isSalesGrowthPositive ? '↑ +' : '↓ ';
    return '$sign${salesGrowthPercent.abs().toStringAsFixed(1)}%';
  }

  String get ordersGrowthFormatted {
    if (ordersGrowthPercent == 0.0) return '0%';
    final sign = isOrdersGrowthPositive ? '↑ +' : '↓ ';
    return '$sign${ordersGrowthPercent.abs().toStringAsFixed(1)}%';
  }
}