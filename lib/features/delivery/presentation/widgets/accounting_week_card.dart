import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../domain/entities/delivery_accounting_models.dart';
import '../../services/delivery_accounting_pdf_service.dart';
import 'accounting_driver_breakdown.dart';
import 'accounting_entity_breakdown.dart';
import 'accounting_status_dialog.dart';
import 'accounting_transactions_sheet.dart';

/// كارت ملخص الأسبوع المالي (Accounting Week Card)
class AccountingWeekCard extends StatelessWidget {
  final WeeklySummaryEntity summary;
  final int index;
  final String tabName;
  final bool isDark;
  final bool isManagerMode;
  final PaymentStatusRecord paymentStatus;
  final Map<String, Map<String, dynamic>> driversMap;
  final Map<String, String> restaurantNamesMap;
  final Map<String, String> storeNamesMap;
  final String? govName;
  final Future<void> Function(String newStatus, DateTime? postponedToDate) onUpdateStatus;

  const AccountingWeekCard({
    super.key,
    required this.summary,
    required this.index,
    required this.tabName,
    required this.isDark,
    required this.isManagerMode,
    required this.paymentStatus,
    this.driversMap = const {},
    this.restaurantNamesMap = const {},
    this.storeNamesMap = const {},
    this.govName,
    required this.onUpdateStatus,
  });

  String _getWeekLabel(int index) {
    const labels = [
      'الأسبوع الأول (الحالي)',
      'الأسبوع الثاني',
      'الأسبوع الثالث',
      'الأسبوع الرابع',
      'الأسبوع الخامس',
      'الأسبوع السادس',
      'الأسبوع السابع',
      'الأسبوع الثامن',
      'الأسبوع التاسع',
      'الأسبوع العاشر'
    ];
    if (index < labels.length) return labels[index];
    return 'الأسبوع ${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    final currencyFormat = NumberFormat.currency(symbol: 'د.ع', decimalDigits: 0, locale: 'ar');
    final String dateRange = '${dateFormat.format(summary.weekStart)} - ${dateFormat.format(summary.weekEnd)}';
    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final weekLabel = _getWeekLabel(index);

    Color statusColor = Colors.grey;
    String statusText = 'غير محاسب';
    if (paymentStatus.isPaid) {
      statusColor = Colors.green;
      statusText = 'محاسب';
    } else if (paymentStatus.isPostponed) {
      statusColor = Colors.orange;
      statusText = 'مؤجل';
      if (paymentStatus.postponedTo != null) {
        statusText = 'مؤجل إلى: ${dateFormat.format(paymentStatus.postponedTo!)}';
      }
    }

    double totalAmount = 0.0;
    if (tabName == 'drivers') {
      totalAmount = summary.netEarnings;
    } else {
      totalAmount = summary.totalOrdersAmount;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          iconColor: const Color(0xFF00BFA5),
          collapsedIconColor: isDark ? Colors.white60 : Colors.black45,
          title: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA5).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        weekLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF00897B),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: isManagerMode
                          ? () => AccountingStatusDialog.show(
                                context: context,
                                tabName: tabName,
                                weekStart: summary.weekStart,
                                currentStatus: paymentStatus.status,
                                onStatusSelected: onUpdateStatus,
                              )
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                            if (isManagerMode) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.edit_rounded, color: statusColor, size: 10),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'أسبوع: $dateRange',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildQuickStat(
                      tabName == 'drivers' ? 'عدد الطلبات' : 'عدد العمليات',
                      '${summary.orders.length}',
                    ),
                    _buildQuickStat(
                      tabName == 'drivers' ? 'صافي مستحقات الكباتن' : 'إجمالي المبيعات الأسبوعية',
                      currencyFormat.format(totalAmount),
                      highlight: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          children: [
            Container(
              height: 1,
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
            ),
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tabName == 'drivers') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildFinancialDetailRow('إجمالي أجور التوصيل', currencyFormat.format(summary.totalDeliveryFees)),
                          const SizedBox(height: 10),
                          _buildFinancialDetailRow('عمولة التطبيق (500 د.ع / طلب)', currencyFormat.format(summary.platformCommission), isDeduction: true),
                          const SizedBox(height: 12),
                          Container(
                            height: 1,
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
                          ),
                          const SizedBox(height: 12),
                          _buildFinancialDetailRow('صافي مستحقات الكباتن', currencyFormat.format(summary.netEarnings), isTotal: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => DeliveryAccountingPdfService.printWeeklyAccountingReport(
                          title: 'كشف حساب الكباتن - $weekLabel',
                          orders: summary.orders,
                          tabName: tabName,
                          govName: govName,
                          restaurantNamesMap: restaurantNamesMap,
                          storeNamesMap: storeNamesMap,
                        ),
                        icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'تصدير كشف حساب (PDF)',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isManagerMode ? 'تفاصيل الكباتن في هذا الأسبوع:' : 'تفاصيل طلباتك هذا الأسبوع:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AccountingDriverBreakdown(
                      summary: summary,
                      isDark: isDark,
                      isManagerMode: isManagerMode,
                      driversMap: driversMap,
                      govName: govName,
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildFinancialDetailRow(
                            tabName == 'restaurants' ? 'إجمالي مبيعات المطاعم' : 'إجمالي مبيعات المتاجر',
                            currencyFormat.format(totalAmount),
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => AccountingTransactionsSheet.show(
                          context: context,
                          title: 'كشف عمليات ${tabName =='restaurants' ? 'المطاعم' : 'المتاجر'} - $weekLabel',
                          orders: summary.orders,
                          tabName: tabName,
                          govName: govName,
                          restaurantNamesMap: restaurantNamesMap,
                          storeNamesMap: storeNamesMap,
                        ),
                        icon: const Icon(Icons.history_toggle_off_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'تفاصيل التواريخ وأوقات المبيعات',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BFA5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      tabName == 'restaurants' ? 'تفاصيل مبيعات المطاعم هذا الأسبوع:' : 'تفاصيل مبيعات المتاجر هذا الأسبوع:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AccountingEntityBreakdown(
                      summary: summary,
                      isDark: isDark,
                      tabName: tabName,
                      entityNamesMap: tabName == 'restaurants' ? restaurantNamesMap : storeNamesMap,
                      govName: govName,
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: highlight ? 16 : 14,
            fontWeight: FontWeight.w900,
            color: highlight
                ? (isDark ? const Color(0xFF00BFA5) : const Color(0xFF00897B))
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialDetailRow(String label, String value, {bool isDeduction = false, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 13 : 12,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
            color: isDark
                ? (isTotal ? Colors.white : Colors.white70)
                : (isTotal ? Colors.black87 : Colors.black54),
          ),
        ),
        Text(
          isDeduction ? '- $value' : value,
          style: TextStyle(
            fontSize: isTotal ? 15 : 13,
            fontWeight: FontWeight.w800,
            color: isDeduction
                ? Colors.redAccent
                : isTotal
                    ? (isDark ? const Color(0xFF00BFA5) : const Color(0xFF00897B))
                    : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }
}
