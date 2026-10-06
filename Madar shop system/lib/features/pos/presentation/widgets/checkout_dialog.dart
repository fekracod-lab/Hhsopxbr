import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/pos_controller.dart';
import '../../../receipt/services/receipt_printer_service.dart';

/// نافذة إتمام الدفع السريع وحساب المتبقي وطباعة الفاتورة (Fast POS Checkout Dialog)
class CheckoutDialog extends StatefulWidget {
  final PosController controller;
  final VoidCallback onSuccess;

  const CheckoutDialog({
    super.key,
    required this.controller,
    required this.onSuccess,
  });

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  final TextEditingController _paidController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController(text: 'زبون نقدي');
  final TextEditingController _customerPhoneController = TextEditingController();

  String _paymentMethod = 'cash'; // 'cash', 'card', 'points', 'zain_cash'
  bool _autoPrintReceipt = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // المبلغ المدفوع الافتراضي هو نفس صافي الفاتورة
    _paidController.text = widget.controller.netTotal.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _paidController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  double get _paidAmount => double.tryParse(_paidController.text.trim()) ?? 0.0;
  double get _changeAmount {
    final diff = _paidAmount - widget.controller.netTotal;
    return diff < 0 ? 0.0 : diff;
  }

  void _setExactPaid(double amount) {
    setState(() {
      _paidController.text = amount.toStringAsFixed(0);
    });
  }

  Future<void> _handleConfirmCheckout() async {
    if (_paidAmount < widget.controller.netTotal && _paymentMethod == 'cash') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('المبلغ المدفوع أقل من إجمالي الفاتورة!'),
          backgroundColor: ShopColors.danger,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final transaction = await widget.controller.checkout(
        paidAmount: _paidAmount,
        paymentMethod: _paymentMethod,
        customerName: _customerNameController.text.trim().isEmpty ? 'زبون نقدي' : _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
      );

      if (transaction != null) {
        if (_autoPrintReceipt) {
          try {
            await ReceiptPrinterService.instance.printReceipt(transaction);
          } catch (e) {
            debugPrint('[CheckoutDialog] Print error: $e');
          }
        }

        if (mounted) {
          Navigator.of(context).pop();
          widget.onSuccess();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء إتمام العملية: $e'),
            backgroundColor: ShopColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final netTotal = widget.controller.netTotal;

    return Dialog(
      backgroundColor: isDark ? ShopColors.darkSurface : ShopColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ShopColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.point_of_sale_rounded, color: ShopColors.primary, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إتمام الدفع والفاتورة',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          'عدد المواد: ${widget.controller.totalItemsCount}',
                          style: GoogleFonts.cairo(color: isDark ? ShopColors.darkSubText : ShopColors.lightSubText, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 28),

              // ── Total Card ──
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0F2B30), const Color(0xFF13363D)]
                        : [const Color(0xFFE0F7F4), const Color(0xFFE8F5E9)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ShopColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المبلغ المطلوب:',
                      style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${netTotal.toStringAsFixed(0)} د.ع',
                      style: GoogleFonts.cairo(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: ShopColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Payment Methods ──
              Text('طريقة الدفع:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildPaymentChip('cash', 'نقداً', Icons.payments_rounded, isDark),
                  const SizedBox(width: 8),
                  _buildPaymentChip('card', 'بطاقة / ماستر', Icons.credit_card_rounded, isDark),
                  const SizedBox(width: 8),
                  _buildPaymentChip('points', 'نقاط مدار', Icons.stars_rounded, isDark),
                  const SizedBox(width: 8),
                  _buildPaymentChip('zain_cash', 'زين كاش', Icons.phone_android_rounded, isDark),
                ],
              ),
              const SizedBox(height: 18),

              // ── Cash Calculations (Only if Cash) ──
              if (_paymentMethod == 'cash') ...[
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('المبلغ المستلم من الزبون:', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _paidController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              suffixText: 'د.ع',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: _changeAmount > 0
                              ? ShopColors.warning.withValues(alpha: 0.15)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('المتبقي للزبون', style: GoogleFonts.cairo(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87)),
                            const SizedBox(height: 4),
                            Text(
                              '${_changeAmount.toStringAsFixed(0)} د.ع',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: _changeAmount > 0 ? ShopColors.warning : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // فئات النقد السريعة
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildQuickCashBtn('بالضبط', netTotal),
                    _buildQuickCashBtn('5,000', 5000),
                    _buildQuickCashBtn('10,000', 10000),
                    _buildQuickCashBtn('25,000', 25000),
                    _buildQuickCashBtn('50,000', 50000),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // ── Customer Info (Optional) ──
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customerNameController,
                      decoration: InputDecoration(
                        labelText: 'اسم الزبون (اختياري)',
                        labelStyle: GoogleFonts.cairo(fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _customerPhoneController,
                      decoration: InputDecoration(
                        labelText: 'هاتف الزبون',
                        labelStyle: GoogleFonts.cairo(fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Print Switch ──
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbImage: null,
                activeThumbColor: ShopColors.primary,
                title: Text('طباعة الإيصال الحراري 80mm فوراً', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _autoPrintReceipt,
                onChanged: (val) => setState(() => _autoPrintReceipt = val),
              ),
              const SizedBox(height: 16),

              // ── Confirm Button ──
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _handleConfirmCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ShopColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isProcessing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_rounded, color: Colors.white),
                label: Text(
                  _isProcessing ? 'جاري تسجيل الفاتورة...' : 'تأكيد العملية وحفظ الفاتورة',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentChip(String id, String label, IconData icon, bool isDark) {
    final selected = _paymentMethod == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? ShopColors.primary.withValues(alpha: 0.18)
                : (isDark ? ShopColors.darkCard : ShopColors.lightBg),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? ShopColors.primary : (isDark ? ShopColors.darkBorder : ShopColors.lightBorder),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? ShopColors.primary : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? ShopColors.primary : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickCashBtn(String label, double amount) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
      onPressed: () => _setExactPaid(amount),
      backgroundColor: ShopColors.primary.withValues(alpha: 0.08),
      side: BorderSide(color: ShopColors.primary.withValues(alpha: 0.3)),
    );
  }
}
