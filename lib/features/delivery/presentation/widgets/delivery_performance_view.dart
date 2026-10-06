// لوحة أداء وإحصائيات المندوب والمحاسبة (Delivery Performance View Widget)
// Presentation Layer — Pure UI Component

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../domain/entities/delivery_dashboard_models.dart';

class DeliveryPerformanceView extends StatelessWidget {
  final DeliveryDashboardStatistics statistics;
  final VoidCallback onOpenWeeklyAccounting;
  final VoidCallback onOpenWallet;

  static const Color _primary = Color(0xFF00BFA5);
  static const Color _primaryDark = Color(0xFF00897B);
  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _borderLight = Color(0xFFE2E8F0);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSub = Color(0xFF475569);

  const DeliveryPerformanceView({
    super.key,
    required this.statistics,
    required this.onOpenWeeklyAccounting,
    required this.onOpenWallet,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,###', 'ar');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // بطاقة الدخل الشامل
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primary, _primaryDark],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.3),
                  blurRadius: 16,
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
                    Text(
                      'إجمالي الأرباح المحققة',
                      style: GoogleFonts.ibmPlexSansArabic(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'معدل الإنجاز ${statistics.completionRate.toStringAsFixed(0)}%',
                        style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${currencyFormat.format(statistics.totalEarnings)} د.ع',
                  style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // شبكة الإحصائيات التفصيلية
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'أرباح اليوم',
                  value: '${currencyFormat.format(statistics.todayEarnings)} د.ع',
                  color: const Color(0xFF2E7D32),
                  icon: Icons.today_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'طلبات اليوم',
                  value: '${statistics.todayCompletedCount} طلب',
                  color: const Color(0xFF0284C7),
                  icon: Icons.done_all_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'إجمالي المنجز',
                  value: '${statistics.completedOrders} طلب',
                  color: const Color(0xFF7C3AED),
                  icon: Icons.military_tech_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'العمولة المستحقة',
                  value: '${currencyFormat.format(statistics.appDebt)} د.ع',
                  color: statistics.appDebt > 0 ? const Color(0xFFE65100) : _textSub,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // روابط سريعة للمحاسبة والمحفظة
          Text(
            'الإدارة المالية والتقارير',
            style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            title: 'المحاسبة الأسبوعية وتصفية الحسابات',
            subtitle: 'كشف الحسابات الأسبوعية وتفاصيل المستحقات المالية والعمولات',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF0284C7),
            onTap: onOpenWeeklyAccounting,
          ),
          const SizedBox(height: 10),
          _buildActionCard(
            title: 'المحفظة وسجل السحب والشحن',
            subtitle: 'إدارة رصيد المحفظة وتسوية عمولات التطبيق',
            icon: Icons.wallet_rounded,
            color: _primaryDark,
            onTap: onOpenWallet,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderLight, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(color: _textSub, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.ibmPlexSansArabic(color: color, fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderLight, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.ibmPlexSansArabic(color: _textSub, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: _textSub, size: 16),
          ],
        ),
      ),
    );
  }
}
