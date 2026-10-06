import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/entities/store_profile.dart';
import '../../domain/entities/shift_models.dart';
import '../../data/services/shift_service.dart';

/// صفحة إدارة ورديات الكاشير والصندوق وجرد النقدية وحساب Z-Report (Shift & Cash Register Page)
class ShiftPage extends StatefulWidget {
  final StoreProfile store;

  const ShiftPage({super.key, required this.store});

  @override
  State<ShiftPage> createState() => _ShiftPageState();
}

class _ShiftPageState extends State<ShiftPage> {
  final TextEditingController _openCashCtrl = TextEditingController(text: '50000');
  final TextEditingController _cashierNameCtrl = TextEditingController(text: 'كاشير مدار');

  @override
  void dispose() {
    _openCashCtrl.dispose();
    _cashierNameCtrl.dispose();
    super.dispose();
  }

  void _showAddExpenseDialog() {
    final amountCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تسجيل مصروف نثري من الصندوق', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'بيان المصروف (مثال: أكياس، بنزين، نظافة)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ (د.ع)', suffixText: 'د.ع', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'ملاحظات إضافية', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              final t = titleCtrl.text.trim();
              if (amt > 0 && t.isNotEmpty) {
                ShiftService.instance.addExpense(amount: amt, title: t, notes: notesCtrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: ShopColors.primary),
            child: Text('تسجيل السند', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCloseShiftDialog(ShiftSession shift) {
    final closingCashCtrl = TextEditingController(text: shift.expectedCash.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final counted = double.tryParse(closingCashCtrl.text.trim()) ?? 0.0;
          final diff = counted - shift.expectedCash;

          return AlertDialog(
            title: Text('إغلاق الوردية وجرد الصندوق (Z-Report)', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('الرصيد النقدي المتوقع في الصندوق:', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
                Text('${shift.expectedCash.toStringAsFixed(0)} د.ع', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w900, color: ShopColors.primary)),
                const SizedBox(height: 14),
                TextField(
                  controller: closingCashCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'النقد الفعلي المعدود في الدرج', suffixText: 'د.ع', border: OutlineInputBorder()),
                  onChanged: (_) => setDlgState(() {}),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: diff == 0
                        ? ShopColors.success.withValues(alpha: 0.15)
                        : (diff > 0 ? ShopColors.info.withValues(alpha: 0.15) : ShopColors.danger.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(diff == 0 ? 'المطابقة: دقيقة 100%' : (diff > 0 ? 'يوجد فائض نقدي:' : 'يوجد عجز نقدي:'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                      Text('${diff.abs().toStringAsFixed(0)} د.ع', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.cairo())),
              ElevatedButton(
                onPressed: () async {
                  await ShiftService.instance.closeShift(counted);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إغلاق الوردية وتخزين تقرير Z-Report بنجاح'), backgroundColor: ShopColors.success),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: ShopColors.danger),
                child: Text('تأكيد إغلاق الوردية', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: ShiftService.instance,
      builder: (context, _) {
        final shift = ShiftService.instance.currentShift;
        final hasActive = ShiftService.instance.hasActiveShift;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ──
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ShopColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: ShopColors.primary, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إدارة الورديات وجرد الصندوق (Z-Report)',
                              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text(
                              'متابعة النقد، مبيعات الكاشير، المصروفات، وإغلاق الصندوق اليومي',
                              style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (hasActive) ...[
                        ElevatedButton.icon(
                          onPressed: _showAddExpenseDialog,
                          style: ElevatedButton.styleFrom(backgroundColor: ShopColors.warning),
                          icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.black87),
                          label: Text('سند صرف نثري', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.black87)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => _showCloseShiftDialog(shift!),
                          style: ElevatedButton.styleFrom(backgroundColor: ShopColors.danger),
                          icon: const Icon(Icons.lock_clock_rounded, color: Colors.white),
                          label: Text('إغلاق الوردية والتقرير', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ],
                  ),
                  const Divider(height: 32),

                  // ── State 1: No active shift (Open shift view) ──
                  if (!hasActive)
                    Center(
                      child: Container(
                        width: 520,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: isDark ? ShopColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? ShopColors.darkBorder : ShopColors.lightBorder),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(Icons.lock_open_rounded, size: 54, color: ShopColors.primary),
                            const SizedBox(height: 14),
                            Text(
                              'لا توجد وردية نشطة حالياً',
                              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'يرجى إدخال الرصيد الافتتاحي في درج الكاشير لفتح الوردية وبدء البيع',
                              style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _cashierNameCtrl,
                              decoration: InputDecoration(
                                labelText: 'اسم مسؤول الكاشير',
                                prefixIcon: const Icon(Icons.person_outline_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _openCashCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'الرصيد النقدي الافتتاحي (د.ع)',
                                prefixIcon: const Icon(Icons.payments_outlined),
                                suffixText: 'د.ع',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 22),
                            ElevatedButton.icon(
                              onPressed: () {
                                final openCash = double.tryParse(_openCashCtrl.text.trim()) ?? 0.0;
                                final cashier = _cashierNameCtrl.text.trim().isEmpty ? 'كاشير' : _cashierNameCtrl.text.trim();
                                ShiftService.instance.openShift(
                                  storeId: widget.store.storeId,
                                  cashierName: cashier,
                                  openingCash: openCash,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ShopColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.vpn_key_rounded, color: Colors.white),
                              label: Text('فتح الوردية وبدء المبيعات', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    // ── State 2: Active shift overview ──
                    Row(
                      children: [
                        _buildShiftMetric('الافتتاحي في الصندوق', '${shift!.openingCash.toStringAsFixed(0)} د.ع', Icons.savings_rounded, isDark),
                        const SizedBox(width: 14),
                        _buildShiftMetric('مبيعات النقد', '${shift.totalCashSales.toStringAsFixed(0)} د.ع', Icons.payments_rounded, isDark, ShopColors.success),
                        const SizedBox(width: 14),
                        _buildShiftMetric('مبيعات إلكترونية', '${shift.totalCardSales.toStringAsFixed(0)} د.ع', Icons.credit_card_rounded, isDark, ShopColors.info),
                        const SizedBox(width: 14),
                        _buildShiftMetric('المصروفات النثرية', '${shift.totalExpenses.toStringAsFixed(0)} د.ع', Icons.money_off_rounded, isDark, ShopColors.danger),
                        const SizedBox(width: 14),
                        _buildShiftMetric('المتوقع في الصندوق', '${shift.expectedCash.toStringAsFixed(0)} د.ع', Icons.account_balance_rounded, isDark, ShopColors.primary),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Expenses List
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? ShopColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? ShopColors.darkBorder : ShopColors.lightBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('سندات ومصروفات الوردية الحالية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text('إجمالي المصروفات: ${shift.totalExpenses.toStringAsFixed(0)} د.ع', style: GoogleFonts.cairo(color: ShopColors.danger, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(height: 20),
                          if (ShiftService.instance.expenses.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Center(
                                child: Text('لا توجد مصروفات مسجلة في هذه الوردية', style: GoogleFonts.cairo(color: Colors.grey)),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: ShiftService.instance.expenses.length,
                              separatorBuilder: (_, _i) => const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final exp = ShiftService.instance.expenses[i];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? ShopColors.darkCard : ShopColors.lightBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.receipt_long_rounded, color: ShopColors.danger, size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(exp.title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
                                            if (exp.notes.isNotEmpty)
                                              Text(exp.notes, style: GoogleFonts.cairo(color: Colors.grey, fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '- ${exp.amount.toStringAsFixed(0)} د.ع',
                                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: ShopColors.danger, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShiftMetric(String title, String value, IconData icon, bool isDark, [Color? color]) {
    final c = color ?? ShopColors.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? ShopColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: c, size: 24),
            const SizedBox(height: 10),
            Text(value, style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900, color: c)),
            const SizedBox(height: 2),
            Text(title, style: GoogleFonts.cairo(fontSize: 11, color: isDark ? Colors.white70 : Colors.black54)),
          ],
        ),
      ),
    );
  }
}
