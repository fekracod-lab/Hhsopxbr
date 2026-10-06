import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/pos_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pos_page_header.dart';
import '../../../../core/widgets/pos_status_chip.dart';
import '../../../../services/shift_service.dart';

/// شاشة إدارة الوردية وصندوق الكاشير (فتح/إغلاق الوردية + Z-Report) — تصميم موحّد
class ShiftDrawerPage extends StatelessWidget {
  const ShiftDrawerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Consumer<ShiftService>(
        builder: (context, shift, _) {
          return Column(
            children: [
              // رأس الصفحة الموحّد + حالة الوردية
              PosPageHeader(
                icon: Icons.account_balance_wallet_rounded,
                title: 'إدارة الوردية وصندوق الكاشير',
                subtitle: 'فتح وإغلاق الوردية مع جرد النقد وتقرير Z-Report',
                actions: [
                  PosStatusChip(
                    label: shift.isShiftOpen ? 'الوردية مفتوحة' : 'الوردية مغلقة',
                    icon: shift.isShiftOpen
                        ? Icons.lock_open_rounded
                        : Icons.lock_outline_rounded,
                    color: shift.isShiftOpen ? c.success : c.danger,
                    filled: shift.isShiftOpen,
                  ),
                ],
              ),

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 520),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                                alpha: context.isDarkMode ? 0.25 : 0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: shift.isShiftOpen
                          ? _buildCloseShiftView(context, shift)
                          : _buildOpenShiftView(context, shift),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOpenShiftView(BuildContext context, ShiftService shift) {
    final c = context.posColors;
    final cashController = TextEditingController();
    final nameController = TextEditingController(text: 'كاشير رئيسي');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: c.primary.withValues(alpha: 0.4)),
          ),
          child: Icon(Icons.lock_open_rounded, color: c.primary, size: 36),
        ),
        const SizedBox(height: 16),
        Text(
          'فتح وردية جديدة',
          style: GoogleFonts.ibmPlexSansArabic(
            color: c.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 19,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'أدخل رصيد العهدة الافتتاحي واسم الكاشير لبدء الوردية',
          style: GoogleFonts.ibmPlexSansArabic(
            color: c.textMuted,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // حقل اسم الكاشير
        TextField(
          controller: nameController,
          style: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary, fontSize: 14),
          decoration: const InputDecoration(
            labelText: 'اسم الكاشير',
            prefixIcon: Icon(Icons.person_rounded),
          ),
        ),
        const SizedBox(height: 14),

        // حقل العهدة الافتتاحية
        TextField(
          controller: cashController,
          keyboardType: TextInputType.number,
          style: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'رصيد العهدة الافتتاحي (د.ع)',
            prefixIcon: Icon(Icons.payments_rounded, color: c.gold),
          ),
        ),
        const SizedBox(height: 28),

        ElevatedButton.icon(
          onPressed: () {
            final cash = double.tryParse(cashController.text) ?? 0;
            final name = nameController.text.trim().isNotEmpty
                ? nameController.text.trim()
                : 'كاشير رئيسي';
            shift.openShift(initialCash: cash, cashier: name);
          },
          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
          label: Text(
            'فتح الوردية الآن',
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _buildCloseShiftView(BuildContext context, ShiftService shift) {
    final c = context.posColors;
    final drawerCashController = TextEditingController();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: c.warning.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: c.warning.withValues(alpha: 0.4)),
          ),
          child: Icon(Icons.lock_rounded, color: c.warning, size: 36),
        ),
        const SizedBox(height: 16),
        Text(
          'إغلاق الوردية الحالية',
          style: GoogleFonts.ibmPlexSansArabic(
            color: c.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 19,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border),
          ),
          child: Text(
            'الكاشير: ${shift.cashierName}\nالعهدة الافتتاحية: ${PosConstants.formatMoney(shift.openingCash)}',
            style: GoogleFonts.ibmPlexSansArabic(
              color: c.textMuted,
              fontSize: 12.5,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),

        TextField(
          controller: drawerCashController,
          keyboardType: TextInputType.number,
          style: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'النقد الفعلي في الصندوق بعد الجرد (د.ع)',
            prefixIcon: Icon(Icons.money_rounded, color: c.gold),
          ),
        ),
        const SizedBox(height: 28),

        ElevatedButton.icon(
          onPressed: () async {
            final actualCash = double.tryParse(drawerCashController.text) ?? 0;
            final report =
                await shift.closeShift(actualCashInDrawer: actualCash);

            if (context.mounted) {
              // عرض التقرير وخيار الطباعة
              showDialog(
                context: context,
                builder: (_) => _ZReportDialog(reportData: report),
              );
            }
          },
          icon: const Icon(Icons.stop_circle_rounded, color: Colors.white),
          label: Text(
            'إغلاق الوردية وإصدار التقرير',
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: c.warning,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}

class _ZReportDialog extends StatelessWidget {
  final Map<String, dynamic> reportData;
  const _ZReportDialog({required this.reportData});

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;
    final diff = (reportData['difference'] ?? 0.0) as double;

    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.border),
      ),
      title: Row(
        children: [
          Icon(Icons.summarize_rounded, color: c.accent, size: 22),
          const SizedBox(width: 8),
          Text(
            'تقرير ختام الوردية (Z-Report)',
            style: GoogleFonts.ibmPlexSansArabic(
              color: c.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row(c, 'الكاشير:', reportData['cashierName'] ?? '-'),
            _row(c, 'عدد الطلبات:', '${reportData['ordersCount'] ?? 0}'),
            Divider(color: c.border),
            _row(
                c, 'مبيعات النقد:', PosConstants.formatMoney(reportData['totalCashSales'] ?? 0)),
            _row(
                c, 'مبيعات الشبكة:', PosConstants.formatMoney(reportData['totalCardSales'] ?? 0)),
            _row(c, 'إجمالي المبيعات:',
                PosConstants.formatMoney(reportData['totalSales'] ?? 0),
                isBold: true),
            if (((reportData['totalShiftExpenses'] ?? 0.0) as num).toDouble() > 0) ...[
              Divider(color: c.border),
              _row(c, 'إجمالي المصروفات (${reportData['expensesCount'] ?? 0}):',
                  '- ${PosConstants.formatMoney(reportData['totalShiftExpenses'] ?? 0)}'),
              _row(c, 'مصروف نقدي مخصوم:',
                  '- ${PosConstants.formatMoney(reportData['totalCashExpenses'] ?? 0)}'),
              _row(c, 'صافي الأرباح:',
                  PosConstants.formatMoney(reportData['netProfit'] ?? 0),
                  isBold: true),
            ],
            Divider(color: c.border),
            _row(c, 'المبلغ المفترض بالصندوق:',
                PosConstants.formatMoney(reportData['expectedCash'] ?? 0)),
            _row(c, 'المبلغ الفعلي بالجرد:',
                PosConstants.formatMoney(reportData['actualCash'] ?? 0),
                isBold: true),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: diff < 0
                    ? c.danger.withValues(alpha: 0.1)
                    : c.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    diff == 0
                        ? 'مطابقة تامة ✅'
                        : (diff < 0 ? 'عجز ❌' : 'فائض ⬆️'),
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: diff < 0 ? c.danger : c.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    PosConstants.formatMoney(diff.abs()),
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: diff < 0 ? c.danger : c.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            ShiftService.printZReport(reportData, 'مطعم مدار');
          },
          child: Text(
            'طباعة التقرير 🖨️',
            style: GoogleFonts.ibmPlexSansArabic(
              color: c.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'إغلاق',
            style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _row(PosColors c, String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 13),
          ),
          Text(
            value,
            style: GoogleFonts.ibmPlexSansArabic(
              color: isBold ? c.gold : c.textPrimary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}