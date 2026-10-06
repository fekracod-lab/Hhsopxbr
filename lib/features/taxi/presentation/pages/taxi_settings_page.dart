import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const Color _primaryColor = Color(0xFF26A69A);

class TaxiSettingsPage extends StatefulWidget {
  const TaxiSettingsPage({super.key});

  @override
  State<TaxiSettingsPage> createState() => _TaxiSettingsPageState();
}

class _TaxiSettingsPageState extends State<TaxiSettingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _baseFareController = TextEditingController();
  final TextEditingController _perKmController = TextEditingController();
  final TextEditingController _minFareController = TextEditingController();
  final TextEditingController _commissionPercentController = TextEditingController();
  final TextEditingController _cancelFeeController = TextEditingController();
  final TextEditingController _surgeMultiplierController = TextEditingController();
  final TextEditingController _freeWaitMinutesController = TextEditingController();
  final TextEditingController _waitMinutePriceController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _baseFareController.dispose();
    _perKmController.dispose();
    _minFareController.dispose();
    _commissionPercentController.dispose();
    _cancelFeeController.dispose();
    _surgeMultiplierController.dispose();
    _freeWaitMinutesController.dispose();
    _waitMinutePriceController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await _firestore.collection('settings').doc('taxi_config').get();
      if (doc.exists) {
        final data = doc.data()!;
        _baseFareController.text = (data['baseFare'] ?? 1500).toString();
        _perKmController.text = (data['perKm'] ?? 750).toString();
        _minFareController.text = (data['minTripFare'] ?? 3000).toString();
        _commissionPercentController.text = (data['platformCommissionPercent'] ?? 10).toString();
        _cancelFeeController.text = (data['cancelFee'] ?? 1000).toString();
        _surgeMultiplierController.text = (data['nightSurgeMultiplier'] ?? 1.25).toString();
        _freeWaitMinutesController.text = (data['freeWaitMinutes'] ?? 5).toString();
        _waitMinutePriceController.text = (data['waitMinutePrice'] ?? 250).toString();
      } else {
        _baseFareController.text = '1500';
        _perKmController.text = '750';
        _minFareController.text = '3000';
        _commissionPercentController.text = '10';
        _cancelFeeController.text = '1000';
        _surgeMultiplierController.text = '1.25';
        _freeWaitMinutesController.text = '5';
        _waitMinutePriceController.text = '250';
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await _firestore.collection('settings').doc('taxi_config').set({
        'baseFare': double.tryParse(_baseFareController.text) ?? 1500.0,
        'perKm': double.tryParse(_perKmController.text) ?? 750.0,
        'minTripFare': double.tryParse(_minFareController.text) ?? 3000.0,
        'platformCommissionPercent': double.tryParse(_commissionPercentController.text) ?? 10.0,
        'cancelFee': double.tryParse(_cancelFeeController.text) ?? 1000.0,
        'nightSurgeMultiplier': double.tryParse(_surgeMultiplierController.text) ?? 1.25,
        'freeWaitMinutes': int.tryParse(_freeWaitMinutesController.text) ?? 5,
        'waitMinutePrice': double.tryParse(_waitMinutePriceController.text) ?? 250.0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ وتحديث إعدادات وتعرفة التاكسي بنجاح', style: TextStyle()),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء الحفظ: $e', style: const TextStyle()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF07191A) : const Color(0xFFF6F8FB),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF0C2428) : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : const Color(0xFF0A2828), size: 19.r),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(
            'إعدادات وتعرفة التاكسي',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: isDark ? Colors.white : const Color(0xFF0A2828)),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _primaryColor))
            : SingleChildScrollView(
                padding: EdgeInsets.all(16.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('1. تعرفة حساب الأجرة الأساسية ', isDark),
                    SizedBox(height: 8.h),
                    _buildSettingCard(
                      label: 'فتحة العداد الأساسية (د.ع)',
                      controller: _baseFareController,
                      icon: Icons.flag_rounded,
                      hint: 'مثال: 1500',
                      isDark: isDark,
                    ),
                    SizedBox(height: 8.h),
                    _buildSettingCard(
                      label: 'سعر كل كيلومتر (د.ع / كم)',
                      controller: _perKmController,
                      icon: Icons.add_road_rounded,
                      hint: 'مثال: 750',
                      isDark: isDark,
                    ),
                    SizedBox(height: 8.h),
                    _buildSettingCard(
                      label: 'الحد الأدنى للأجرة (د.ع)',
                      controller: _minFareController,
                      icon: Icons.price_check_rounded,
                      hint: 'مثال: 3000',
                      isDark: isDark,
                    ),
                    SizedBox(height: 18.h),

                    _buildSectionHeader('2. عمولة المنصة ورسوم الإلغاء ', isDark),
                    SizedBox(height: 8.h),
                    _buildSettingCard(
                      label: 'نسبة عمولة المنصة من كل رحلة (%)',
                      controller: _commissionPercentController,
                      icon: Icons.percent_rounded,
                      hint: 'مثال: 10',
                      isDark: isDark,
                    ),
                    SizedBox(height: 8.h),
                    _buildSettingCard(
                      label: 'رسوم إلغاء الرحلة بعد القبول (د.ع)',
                      controller: _cancelFeeController,
                      icon: Icons.cancel_presentation_rounded,
                      hint: 'مثال: 1000',
                      isDark: isDark,
                    ),
                    SizedBox(height: 18.h),

                    _buildSectionHeader('3. تسعير الذروة والانتظار ', isDark),
                    SizedBox(height: 8.h),
                    _buildSettingCard(
                      label: 'معامل تسعير أوقات الذروة والليل (Surge Multiplier)',
                      controller: _surgeMultiplierController,
                      icon: Icons.trending_up_rounded,
                      hint: 'مثال: 1.25 يعني زيادة 25%',
                      isDark: isDark,
                    ),
                    SizedBox(height: 8.h),
                    _buildSettingCard(
                      label: 'دقائق الانتظار المجانية عند وصول الكابتن (دقيقة)',
                      controller: _freeWaitMinutesController,
                      icon: Icons.timer_rounded,
                      hint: 'مثال: 5 دقائق',
                      isDark: isDark,
                    ),
                    SizedBox(height: 8.h),
                    _buildSettingCard(
                      label: 'سعر دقيقة الانتظار الإضافية (د.ع)',
                      controller: _waitMinutePriceController,
                      icon: Icons.hourglass_bottom_rounded,
                      hint: 'مثال: 250',
                      isDark: isDark,
                    ),
                    SizedBox(height: 28.h),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50.h,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveSettings,
                        icon: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_rounded, color: Colors.white),
                        label: Text(
                          _isSaving ? 'جاري حفظ الإعدادات...' : 'حفظ ونشر التعرفة الجديدة',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        ),
                      ),
                    ),
                    SizedBox(height: 30.h),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13.5.sp,
        color: isDark ? Colors.white : const Color(0xFF0C2428),
      ),
    );
  }

  Widget _buildSettingCard({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C2428) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 11.5.sp, color: isDark ? Colors.white70 : Colors.black54),
          hintText: hint,
          hintStyle: TextStyle(fontSize: 11.sp, color: Colors.grey),
          prefixIcon: Icon(icon, color: _primaryColor, size: 20),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
