// شريط رأس لوحة تحكم المندوب ومؤشرات اليوم (Delivery Dashboard Header Widget)
// Presentation Layer — Pure UI Component

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

class DeliveryDashboardHeader extends StatelessWidget {
  final String driverName;
  final bool isOnline;
  final bool isToggling;
  final double todayEarnings;
  final int todayCompletedCount;
  final double appDebt;
  final VoidCallback onToggleOnline;
  final VoidCallback onOpenLiveMap;

  static const Color _primary = Color(0xFF00BFA5);
  static const Color _primaryDark = Color(0xFF00897B);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSub = Color(0xFF475569);
  static const Color _borderLight = Color(0xFFE2E8F0);
  static const Color _success = Color(0xFF00C853);

  const DeliveryDashboardHeader({
    super.key,
    required this.driverName,
    required this.isOnline,
    this.isToggling = false,
    required this.todayEarnings,
    required this.todayCompletedCount,
    required this.appDebt,
    required this.onToggleOnline,
    required this.onOpenLiveMap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,###', 'ar');

    return SliverAppBar(
      expandedHeight: 235,
      pinned: true,
      backgroundColor: _primary,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.map_rounded, color: Colors.white),
          tooltip: 'خريطة الطلبات الحية',
          onPressed: onOpenLiveMap,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: const EdgeInsets.fromLTRB(18, 48, 18, 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary, _primaryDark],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.waving_hand_rounded, color: Color(0xFFFFD54F), size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'يا هلا بيك يا $driverName',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: Colors.white,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'مدينة القائم وضواحيها',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // سويتش الاتصال
                  GestureDetector(
                    onTap: isToggling ? null : onToggleOnline,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.white : Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          if (isToggling)
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          else
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isOnline ? _success : Colors.white60,
                              ),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            isOnline ? 'أنت متصل' : 'أوفلاين',
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: isOnline ? _primaryDark : Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // شريط ملخص أرباح اليوم
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildHeaderMetric('أرباحك اليوم', '${currencyFormat.format(todayEarnings)} د.ع', _primaryDark),
                    Container(width: 1, height: 26, color: _borderLight),
                    _buildHeaderMetric('الطلبات المنجزة', '$todayCompletedCount طلب', _textMain),
                    Container(width: 1, height: 26, color: _borderLight),
                    _buildHeaderMetric('العمولة المستحقة', '${currencyFormat.format(appDebt)} د.ع', appDebt > 0 ? const Color(0xFFE65100) : _textSub),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderMetric(String title, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.ibmPlexSansArabic(color: _textSub, fontSize: 10.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.ibmPlexSansArabic(color: color, fontWeight: FontWeight.w900, fontSize: 13.5),
        ),
      ],
    );
  }
}
