// حوار الدفع وإتمام الفاتورة لنقطة البيع (MADAR SHOP POS Payment Dialog)
// Presentation Layer — Split Payments, Cash Tendered, Change & Offline Credit Guard

import 'package:flutter/material.dart';

import '../../../domain/pos/entities/payment.dart';
import '../../../domain/pos/enums/payment_method.dart';
import '../../../domain/pos/enums/payment_status.dart';
import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/sync/enums/connectivity_state.dart';
import '../controllers/windows_pos_controller.dart';
import 'pos_receipt_success_dialog.dart';

class PosPaymentDialog extends StatefulWidget {
  final WindowsPosController controller;

  const PosPaymentDialog({
    super.key,
    required this.controller,
  });

  @override
  State<PosPaymentDialog> createState() => _PosPaymentDialogState();
}

class _PosPaymentDialogState extends State<PosPaymentDialog> {
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  final TextEditingController _cashTenderedCtrl = TextEditingController();
  final TextEditingController _splitCashCtrl = TextEditingController();
  final TextEditingController _splitCardCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  bool _isSplitMode = false;
  bool _autoPrint = true;
  String? _localError;

  @override
  void initState() {
    super.initState();
    final grandTotal = widget.controller.totals.grandTotal.toAmount();
    _cashTenderedCtrl.text = grandTotal.toStringAsFixed(0);
    _splitCashCtrl.text = (grandTotal / 2).toStringAsFixed(0);
    _splitCardCtrl.text = (grandTotal / 2).toStringAsFixed(0);
  }

  @override
  void dispose() {
    _cashTenderedCtrl.dispose();
    _splitCashCtrl.dispose();
    _splitCardCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _cashTendered => double.tryParse(_cashTenderedCtrl.text.trim()) ?? 0.0;
  double get _grandTotal => widget.controller.totals.grandTotal.toAmount();
  double get _changeAmount => (_cashTendered - _grandTotal) > 0 ? (_cashTendered - _grandTotal) : 0.0;

  Future<void> _executeCheckout() async {
    setState(() => _localError = null);
    final currency = widget.controller.currentCart.currency;

    final isOffline = widget.controller.syncStatus.connectivityState == ConnectivityState.offline ||
        widget.controller.syncStatus.connectivityState == ConnectivityState.unstable;

    List<Payment> payments = [];

    if (_isSplitMode) {
      final cashVal = double.tryParse(_splitCashCtrl.text.trim()) ?? 0.0;
      final cardVal = double.tryParse(_splitCardCtrl.text.trim()) ?? 0.0;

      if (cashVal + cardVal < _grandTotal) {
        setState(() => _localError = 'مجموع الدفعات المجزأة أقل من إجمالي الفاتورة المطلوب.');
        return;
      }

      if (cashVal > 0) {
        payments.add(Payment(
          id: 'PAY-SPLIT-CASH-${DateTime.now().microsecondsSinceEpoch}',
          method: PaymentMethod.cash,
          amount: Money.fromAmount(cashVal, currency),
          status: PaymentStatus.completed,
          receivedAt: DateTime.now(),
        ));
      }

      if (cardVal > 0) {
        payments.add(Payment(
          id: 'PAY-SPLIT-CARD-${DateTime.now().microsecondsSinceEpoch}',
          method: PaymentMethod.card,
          amount: Money.fromAmount(cardVal, currency),
          status: PaymentStatus.completed,
          receivedAt: DateTime.now(),
        ));
      }
    } else {
      if (_selectedMethod == PaymentMethod.credit) {
        // فحص البيع الآجل
        if (widget.controller.selectedCustomer == null) {
          setState(() => _localError = 'البيع الآجل يتطلب تحديد حساب العميل أولاً.');
          return;
        }

        if (isOffline) {
          setState(() => _localError = 'البيع الآجل غير متاح بدون اتصال؛ Requires Online Connection.');
          return;
        }

        payments.add(Payment(
          id: 'PAY-CREDIT-${DateTime.now().microsecondsSinceEpoch}',
          method: PaymentMethod.credit,
          amount: Money.fromAmount(_grandTotal, currency),
          status: PaymentStatus.completed,
          receivedAt: DateTime.now(),
        ));
      } else if (_selectedMethod == PaymentMethod.cash) {
        if (_cashTendered < _grandTotal) {
          setState(() => _localError = 'المبلغ المستلم أقل من إجمالي الفاتورة المطلوب.');
          return;
        }

        payments.add(Payment(
          id: 'PAY-CASH-${DateTime.now().microsecondsSinceEpoch}',
          method: PaymentMethod.cash,
          amount: Money.fromAmount(_cashTendered, currency),
          status: PaymentStatus.completed,
          receivedAt: DateTime.now(),
        ));
      } else {
        // بطاقة أو دفع إلكتروني
        payments.add(Payment(
          id: 'PAY-${_selectedMethod.name.toUpperCase()}-${DateTime.now().microsecondsSinceEpoch}',
          method: _selectedMethod,
          amount: Money.fromAmount(_grandTotal, currency),
          status: PaymentStatus.completed,
          receivedAt: DateTime.now(),
        ));
      }
    }

    final success = await widget.controller.processPayment(
      payments: payments,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      autoPrint: _autoPrint,
    );

    if (!mounted) return;

    if (success) {
      final result = widget.controller.lastCheckoutResult;
      final isOfflineSale = widget.controller.isLastSaleOffline;
      Navigator.pop(context); // إغلاق حوار الدفع

      if (result != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => PosReceiptSuccessDialog(
            controller: widget.controller,
            result: result,
            isOfflineSale: isOfflineSale,
          ),
        );
      }
    } else {
      setState(() {
        _localError = widget.controller.errorMessage ?? 'تعذر إتمام الدفع؛ يرجى المحاولة ثانية.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1A1D27) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF2E7D32), size: 24),
          ),
          const SizedBox(width: 12),
          const Text(
            'نافذة الدفع والقبض (F5)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Cairo'),
          ),
          const Spacer(),
          Text(
            'المطلوب: ${_grandTotal.toStringAsFixed(0)} د.ع',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E88E5)),
          ),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_localError != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _localError!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // اختيار نمط الدفع (عادي أو مجزأ)
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('طريقة دفع واحدة', style: TextStyle(fontFamily: 'Cairo'))),
                      ButtonSegment(value: true, label: Text('دفع مجزأ (Split)', style: TextStyle(fontFamily: 'Cairo'))),
                    ],
                    selected: {_isSplitMode},
                    onSelectionChanged: (set) => setState(() => _isSplitMode = set.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (!_isSplitMode) ...[
              // اختيار طريقة الدفع
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMethodChip(PaymentMethod.cash, 'نقداً (Cash)', Icons.money_rounded),
                  _buildMethodChip(PaymentMethod.card, 'بطاقة مصرفية (Card)', Icons.credit_card_rounded),
                  _buildMethodChip(PaymentMethod.digital, 'دفع إلكتروني', Icons.qr_code_2_rounded),
                  _buildMethodChip(PaymentMethod.credit, 'آجل (حساب عميل)', Icons.account_balance_wallet_rounded),
                ],
              ),
              const SizedBox(height: 16),

              // إذا كان الدفع نقداً: إدخال المبلغ المستلم وحساب المتبقي
              if (_selectedMethod == PaymentMethod.cash) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cashTenderedCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'المبلغ المستلم من الزبون',
                          prefixIcon: const Icon(Icons.payments_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('المتبقي للزبون (الفكة):', style: TextStyle(fontSize: 11.5, color: Colors.grey, fontFamily: 'Cairo')),
                            Text(
                              '${_changeAmount.toStringAsFixed(0)} د.ع',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: _changeAmount > 0 ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ] else ...[
              // نمط الدفع المجزأ
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _splitCashCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'جزء نقداً (Cash)',
                        prefixIcon: const Icon(Icons.money_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _splitCardCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'جزء بطاقة (Card)',
                        prefixIcon: const Icon(Icons.credit_card_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // خيار الطباعة التلقائية للإيصال
            CheckboxListTile(
              value: _autoPrint,
              onChanged: (val) => setState(() => _autoPrint = val ?? true),
              title: const Text('طباعة الإيصال تلقائياً فور إتمام البيع', style: TextStyle(fontSize: 13, fontFamily: 'Cairo')),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.controller.isProcessingPayment ? null : () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
        ),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: widget.controller.isProcessingPayment ? null : _executeCheckout,
            icon: widget.controller.isProcessingPayment
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_rounded),
            label: Text(
              widget.controller.isProcessingPayment ? 'جاري المعالجة...' : 'تأكيد وإتمام البيع',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMethodChip(PaymentMethod method, String label, IconData icon) {
    final isSelected = _selectedMethod == method;
    return ChoiceChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontFamily: 'Cairo', fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
      selectedColor: const Color(0xFF1E88E5),
      onSelected: (_) => setState(() => _selectedMethod = method),
    );
  }
}
