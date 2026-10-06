import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/pos_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/pos_language_controller.dart';

/// نافذة الدفع السريع للكاشير (نقدي، بطاقة، حساب الباقي والطباعة)
class PaymentDialog extends StatefulWidget {
  final double grandTotal;
  final String? orderType;
  final String? customerName;
  final String? customerPhone;
  final String? deliveryAddress;
  final Function({
    required String paymentMethod,
    required double amountPaid,
    required bool printReceipt,
    required bool printKitchenTicket,
  }) onConfirmPayment;

  const PaymentDialog({
    super.key,
    required this.grandTotal,
    this.orderType,
    this.customerName,
    this.customerPhone,
    this.deliveryAddress,
    required this.onConfirmPayment,
  });

  static Future<void> show(
    BuildContext context, {
    required double grandTotal,
    String? orderType,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    required Function({
      required String paymentMethod,
      required double amountPaid,
      required bool printReceipt,
      required bool printKitchenTicket,
    }) onConfirmPayment,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PaymentDialog(
        grandTotal: grandTotal,
        orderType: orderType,
        customerName: customerName,
        customerPhone: customerPhone,
        deliveryAddress: deliveryAddress,
        onConfirmPayment: onConfirmPayment,
      ),
    );
  }

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  String _selectedMethod = PosConstants.paymentCash;
  late TextEditingController _paidAmountController;
  late double _amountPaid;
  bool _printReceipt = true;
  bool _printKitchenTicket = true;

  @override
  void initState() {
    super.initState();
    _amountPaid = widget.grandTotal;
    _paidAmountController = TextEditingController(text: widget.grandTotal.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    super.dispose();
  }

  double get _changeAmount {
    if (_amountPaid >= widget.grandTotal) {
      return _amountPaid - widget.grandTotal;
    }
    return 0.0;
  }

  void _setPaid(double val) {
    setState(() {
      _amountPaid = val;
      _paidAmountController.text = val.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEn = PosLanguageController.instance.isEnglish;

    return Directionality(
      textDirection: PosLanguageController.instance.textDirection,
      child: Dialog(
        backgroundColor: PosTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: PosTheme.borderDark),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width.clamp(320.0, 580.0),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // العنوان
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: PosTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.point_of_sale_rounded, color: PosTheme.accent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isEn ? 'Payment & Checkout' : 'إتمام الدفع والمحاسبة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: PosTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: PosTheme.textMuted),
                  ),
                ],
              ),
              const Divider(color: PosTheme.borderDark, height: 28),

              // بطاقة تفاصيل التوصيل إذا كان نوع الطلب توصيل
              if (widget.orderType == PosConstants.orderTypeDelivery) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: PosTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: PosTheme.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: PosTheme.accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.delivery_dining_rounded, color: PosTheme.accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.customerName?.isNotEmpty == true
                                        ? widget.customerName!
                                        : (isEn ? 'Delivery Customer' : 'عميل التوصيل'),
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: PosTheme.textLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.customerPhone?.isNotEmpty == true) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${widget.customerPhone})',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: PosTheme.accent,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (widget.deliveryAddress?.isNotEmpty == true) ...[
                              const SizedBox(height: 2),
                              Text(
                                '📍 ${widget.deliveryAddress}',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 11.5,
                                  color: PosTheme.textMuted,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

            // مربع الإجمالي المطلوب دفعه
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: PosTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PosTheme.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEn ? 'Total Amount Due:' : 'المبلغ الإجمالي المطلوب:',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: PosTheme.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    PosConstants.formatMoney(widget.grandTotal),
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: PosTheme.gold,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // اختيار طريقة الدفع
            Text(
              isEn ? 'Payment Method:' : 'طريقة الدفع:',
              style: GoogleFonts.ibmPlexSansArabic(
                color: PosTheme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMethodButton(PosConstants.paymentCash, isEn ? PosLocale.cashEn : 'نقداً (كاش)', Icons.payments_rounded),
                const SizedBox(width: 10),
                _buildMethodButton(PosConstants.paymentCard, isEn ? PosLocale.cardEn : 'بطاقة / كي كارد', Icons.credit_card_rounded),
                const SizedBox(width: 10),
                _buildMethodButton(PosConstants.paymentZainCash, isEn ? 'Zain Cash' : 'زين كاش', Icons.phone_android_rounded),
                const SizedBox(width: 10),
                _buildMethodButton(PosConstants.paymentDebit, isEn ? 'Debit' : 'آجل (ذمة)', Icons.history_rounded),
              ],
            ),
            const SizedBox(height: 20),

            // تفاصيل الدفع النقدي وحساب الفكة
            if (_selectedMethod == PosConstants.paymentCash) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // حقل المبلغ المستلم
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn ? 'Amount Received:' : 'المبلغ المستلم من الزبون:',
                          style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _paidAmountController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: PosTheme.textLight,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: PosTheme.cardDark,
                            suffixText: isEn ? 'IQD' : 'د.ع',
                            suffixStyle: GoogleFonts.ibmPlexSansArabic(color: PosTheme.accent, fontWeight: FontWeight.bold),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: PosTheme.borderDark),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: PosTheme.primary),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _amountPaid = double.tryParse(val) ?? 0.0;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // مربع الباقي (الفكة)
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn ? 'Change Due:' : 'المتبقي للزبون (الفكة):',
                          style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: _changeAmount > 0 ? PosTheme.success.withValues(alpha: 0.15) : PosTheme.cardDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _changeAmount > 0 ? PosTheme.success : PosTheme.borderDark,
                            ),
                          ),
                          alignment: isEn ? Alignment.centerLeft : Alignment.centerRight,
                          child: Text(
                            PosConstants.formatMoney(_changeAmount),
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: _changeAmount > 0 ? const Color(0xFF69F0AE) : PosTheme.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // أزرار الفئات السريعة
              Wrap(
                spacing: 8,
                children: [
                  _buildQuickCashChip(isEn ? 'Exact' : 'بالتمام', widget.grandTotal),
                  _buildQuickCashChip('5,000', 5000),
                  _buildQuickCashChip('10,000', 10000),
                  _buildQuickCashChip('25,000', 25000),
                  _buildQuickCashChip('50,000', 50000),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // خيارات الطباعة
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      isEn ? 'Print Customer Receipt' : 'طباعة فاتورة الزبون',
                      style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textLight, fontSize: 13),
                    ),
                    value: _printReceipt,
                    activeColor: PosTheme.primary,
                    onChanged: (v) => setState(() => _printReceipt = v ?? true),
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      isEn ? 'Print Kitchen Ticket (KOT)' : 'طباعة بون المطبخ (KOT)',
                      style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textLight, fontSize: 13),
                    ),
                    value: _printKitchenTicket,
                    activeColor: PosTheme.primary,
                    onChanged: (v) => setState(() => _printKitchenTicket = v ?? true),
                  ),
                ),
              ],
            ),
            const Divider(color: PosTheme.borderDark, height: 24),

            // زر تأكيد الدفع
            ElevatedButton(
              onPressed: () {
                widget.onConfirmPayment(
                  paymentMethod: _selectedMethod,
                  amountPaid: _amountPaid,
                  printReceipt: _printReceipt,
                  printKitchenTicket: _printKitchenTicket,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PosTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    isEn ? 'Confirm Payment & Finish' : 'تأكيد الدفع وإنهاء الطلب',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildMethodButton(String method, String title, IconData icon) {
    final isSelected = _selectedMethod == method;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedMethod = method),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? PosTheme.primary.withValues(alpha: 0.2) : PosTheme.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? PosTheme.primary : PosTheme.borderDark,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? PosTheme.accent : PosTheme.textMuted, size: 22),
              const SizedBox(height: 6),
              Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isSelected ? PosTheme.textLight : PosTheme.textMuted,
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickCashChip(String label, double val) {
    return ActionChip(
      label: Text(
        label,
        style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textLight, fontSize: 12),
      ),
      backgroundColor: PosTheme.cardDark,
      side: const BorderSide(color: PosTheme.borderDark),
      onPressed: () => _setPaid(val),
    );
  }
}
