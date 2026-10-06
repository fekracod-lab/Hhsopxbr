import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../utils/theme_constants.dart';

/// نافذة إتمام وتأكيد الطلب السفلية (Store Checkout Details Sheet)
class StoreCheckoutDetailsSheet extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final String initialAddress;
  final double subtotal;
  final double deliveryFee;
  final int userPoints;
  final double userBalance;
  final bool isProcessing;
  final VoidCallback? onPickLocationGPS;
  final VoidCallback? onPickLocationMap;
  final void Function({
    required String name,
    required String phone,
    required String address,
    required String notes,
    required bool usePoints,
    required bool useWallet,
  }) onConfirmOrder;

  const StoreCheckoutDetailsSheet({
    super.key,
    required this.initialName,
    required this.initialPhone,
    required this.initialAddress,
    required this.subtotal,
    required this.deliveryFee,
    required this.userPoints,
    required this.userBalance,
    this.isProcessing = false,
    this.onPickLocationGPS,
    this.onPickLocationMap,
    required this.onConfirmOrder,
  });

  @override
  State<StoreCheckoutDetailsSheet> createState() =>
      _StoreCheckoutDetailsSheetState();
}

class _StoreCheckoutDetailsSheetState extends State<StoreCheckoutDetailsSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _notesCtrl;

  bool _usePoints = false;
  bool _useWallet = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
    _addressCtrl = TextEditingController(text: widget.initialAddress);
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 100 pts = 1000 IQD rate
    final pointsValue = (widget.userPoints / 100.0) * 1000.0;
    final pointsDiscount = _usePoints ? pointsValue : 0.0;

    double walletDiscount = 0.0;
    if (_useWallet) {
      walletDiscount = (widget.subtotal - pointsDiscount) * 0.05;
    }

    final finalTotal = (widget.subtotal +
            widget.deliveryFee -
            pointsDiscount -
            walletDiscount)
        .clamp(0.0, 9999999.0);

    final canPayWithWallet = widget.userBalance >= finalTotal;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24.w,
        24.h,
        24.w,
        MediaQuery.of(context).viewInsets.bottom + 40.h,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D26) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'إتمام وتأكيد الطلب',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24.h),

            _buildTextField('الاسم الكامل', _nameCtrl, isDark),
            SizedBox(height: 16.h),
            _buildTextField('رقم الهاتف', _phoneCtrl, isDark,
                keyboardType: TextInputType.phone),
            SizedBox(height: 16.h),
            _buildTextField(
              'العنوان / الموقع',
              _addressCtrl,
              isDark,
              maxLines: 2,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onPickLocationGPS != null)
                    IconButton(
                      tooltip: 'تحديد الموقع الحالي مباشرة (GPS)',
                      icon: Icon(
                        Icons.my_location_rounded,
                        color: AppTheme.primaryColor,
                        size: 20.sp,
                      ),
                      onPressed: widget.onPickLocationGPS,
                    ),
                  if (widget.onPickLocationMap != null)
                    IconButton(
                      tooltip: 'اختيار من الخريطة',
                      icon: Icon(
                        Icons.map_outlined,
                        color: AppTheme.primaryColor,
                        size: 20.sp,
                      ),
                      onPressed: widget.onPickLocationMap,
                    ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            _buildTextField(
              'تفاصيل إضافية (لون، ديزاين، ملاحظات)',
              _notesCtrl,
              isDark,
              maxLines: 2,
              hint: 'مثال: اللون أحمر، ديزاين رقم 5...',
            ),

            SizedBox(height: 24.h),
            Text(
              'خيارات الدفع والمكافآت',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 12.h),

            // 1. Points Option
            if (widget.userPoints > 0)
              _buildPaymentOption(
                icon: Icons.stars_rounded,
                title: 'استخدام نقاط مدار (${widget.userPoints} نقطة)',
                subtitle: 'خصم بقيمة ${pointsValue.toInt()} د.ع',
                color: Colors.amber,
                value: _usePoints,
                onChanged: (v) => setState(() => _usePoints = v),
              ),

            SizedBox(height: 12.h),

            // 2. Wallet (Coins) Option
            _buildPaymentOption(
              icon: Icons.account_balance_wallet_rounded,
              title: 'الدفع عبر الكوينز (المحفظة)',
              subtitle: _useWallet
                  ? 'تم تطبيق خصم 5% للدفع بالكوينز!'
                  : 'خصم 5% إضافي عند الدفع بالكوينز',
              color: AppTheme.primaryColor,
              value: _useWallet,
              enabled: canPayWithWallet || _useWallet,
              onChanged: (v) => setState(() => _useWallet = v),
              trailing: !canPayWithWallet && !_useWallet
                  ? Text(
                      'رصيد غير كافٍ',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.red,
                      ),
                    )
                  : null,
            ),

            SizedBox(height: 32.h),

            // Total Preview
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'المجموع النهائي:',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_usePoints || _useWallet)
                        Text(
                          '${(widget.subtotal + widget.deliveryFee).toInt()} د.ع',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      Text(
                        '${finalTotal.toInt()} د.ع',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      if (_useWallet)
                        Text(
                          'سيخصم ${finalTotal.toInt()} كوين من رصيدك',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              height: 56.h,
              child: ElevatedButton(
                onPressed: widget.isProcessing
                    ? null
                    : () {
                        if (_nameCtrl.text.trim().isEmpty ||
                            _phoneCtrl.text.trim().isEmpty ||
                            _addressCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'يرجى ملء كافة البيانات الأساسية',
                                style: TextStyle(),
                              ),
                            ),
                          );
                          return;
                        }
                        widget.onConfirmOrder(
                          name: _nameCtrl.text.trim(),
                          phone: _phoneCtrl.text.trim(),
                          address: _addressCtrl.text.trim(),
                          notes: _notesCtrl.text.trim(),
                          usePoints: _usePoints,
                          useWallet: _useWallet,
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: widget.isProcessing
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white))
                    : Text(
                        _useWallet
                            ? 'تأكيد الخصم والطلب'
                            : 'تأكيد الطلب (دفع نقدي عند الاستلام )',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
    Widget? trailing,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: value ? color : color.withValues(alpha: 0.1),
            width: value ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
            Switch.adaptive(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeThumbColor: color,
              activeTrackColor: color.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl,
    bool isDark, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            color: Colors.grey,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(),
          decoration: InputDecoration(
            filled: true,
            hintText: hint,
            suffixIcon: suffixIcon,
            hintStyle: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
