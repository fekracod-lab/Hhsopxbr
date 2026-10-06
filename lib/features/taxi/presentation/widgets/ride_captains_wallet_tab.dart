// تبويب المحافظ وعمولات الكباتن (Ride Captains Wallet Tab Widget)
// Clean Architecture — Presentation Layer: Debt Monitoring, Limits & Settlements

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/entities/ride_management_models.dart';
import '../../domain/services/ride_management_calculator.dart';

class RideCaptainsWalletTab extends StatelessWidget {
  final List<TaxiDriverAdminEntity> drivers;
  final String selectedFilter;
  final String searchQuery;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<TaxiDriverAdminEntity> onSettleCommission;
  final ValueChanged<TaxiDriverAdminEntity> onResetWallet;
  final ValueChanged<TaxiDriverAdminEntity> onEditLimit;
  final void Function(TaxiDriverAdminEntity driver, bool allowException) onToggleException;
  final ValueChanged<String> onCallPhone;
  final bool isDark;

  const RideCaptainsWalletTab({
    super.key,
    required this.drivers,
    required this.selectedFilter,
    required this.searchQuery,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onSettleCommission,
    required this.onResetWallet,
    required this.onEditLimit,
    required this.onToggleException,
    required this.onCallPhone,
    this.isDark = false,
  });

  static const List<Map<String, String>> _filterOptions = [
    {'key': 'all', 'label': 'الكل'},
    {'key': 'blocked', 'label': 'المحظورون للدين'},
    {'key': 'exception', 'label': 'استثناء مالي'},
    {'key': 'active', 'label': 'النشطون'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // حقل البحث
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          color: isDark ? const Color(0xFF0C2428) : Colors.white,
          child: TextField(
            onChanged: onSearchChanged,
            style: TextStyle(fontSize: 12.sp, color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'بحث باسم الكابتن، الهاتف، نوع السيارة أو الرقم...',
              hintStyle: TextStyle(fontSize: 11.sp, color: Colors.grey),
              prefixIcon: Icon(Icons.search_rounded, color: const Color(0xFF00BFA5), size: 20.r),
              filled: true,
              fillColor: isDark ? const Color(0xFF133338) : const Color(0xFFF1F5F9),
              contentPadding: EdgeInsets.symmetric(vertical: 8.h),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
            ),
          ),
        ),

        // شريط الفلاتر
        Container(
          height: 44.h,
          color: isDark ? const Color(0xFF0C2428) : Colors.white,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            itemCount: _filterOptions.length,
            separatorBuilder: (_, __) => SizedBox(width: 6.w),
            itemBuilder: (ctx, idx) {
              final opt = _filterOptions[idx];
              final isSelected = selectedFilter == opt['key'];
              return ChoiceChip(
                label: Text(
                  opt['label']!,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 10.5.sp,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF00BFA5),
                backgroundColor: isDark ? const Color(0xFF133338) : const Color(0xFFF1F5F9),
                onSelected: (_) => onFilterChanged(opt['key']!),
              );
            },
          ),
        ),
        SizedBox(height: 4.h),

        // قائمة بطاقات الكباتن
        Expanded(
          child: drivers.isEmpty
              ? Center(
                  child: Text(
                    'ماكو كباتن حالياً مطابقون للتصفية الحالية',
                    style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  itemCount: drivers.length,
                  itemBuilder: (ctx, idx) {
                    final driver = drivers[idx];
                    return _buildCaptainCard(driver);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCaptainCard(TaxiDriverAdminEntity driver) {
    final debtRatio = driver.debtRatio;
    final isBlocked = driver.isBlockedByDebt;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(
          color: isBlocked ? Colors.red.withValues(alpha: 0.3) : const Color(0xFF00BFA5).withValues(alpha: 0.15),
          width: 1.2,
        ),
      ),
      color: isDark ? const Color(0xFF0C2428) : Colors.white,
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // معلومات الكابتن والحالة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18.r,
                        backgroundColor: const Color(0xFF00BFA5).withValues(alpha: 0.12),
                        child: Icon(Icons.person_rounded, color: const Color(0xFF00BFA5), size: 20.r),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driver.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5.sp,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${driver.carModel} • ${driver.carNumber}',
                              style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: isBlocked
                        ? Colors.red.withValues(alpha: 0.12)
                        : (driver.allowCommissionException
                            ? Colors.amber.withValues(alpha: 0.12)
                            : Colors.green.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    isBlocked
                        ? 'محظور للدين'
                        : (driver.allowCommissionException ? 'استثناء مالي' : 'نشط'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10.sp,
                      color: isBlocked
                          ? Colors.red
                          : (driver.allowCommissionException ? Colors.amber.shade800 : Colors.green),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),

            // شريط نسبة الدين من السقف
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المديونية: ${RideManagementCalculator.formatIraqiCurrency(driver.appDebt)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5.sp,
                    color: isBlocked ? Colors.red : const Color(0xFF0284C7),
                  ),
                ),
                Text(
                  'السقف: ${RideManagementCalculator.formatIraqiCurrency(driver.commissionLimit)}',
                  style: TextStyle(fontSize: 10.5.sp, color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: debtRatio,
                minHeight: 6.h,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isBlocked ? Colors.red : (debtRatio > 0.75 ? Colors.orange : const Color(0xFF00BFA5)),
                ),
              ),
            ),
            SizedBox(height: 12.h),

            // أزرار الإجراءات الإدارية
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onCallPhone(driver.phone),
                  icon: Icon(Icons.phone_rounded, size: 14.r),
                  label: const Text('اتصال', style: TextStyle()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00BFA5),
                    side: const BorderSide(color: Color(0xFF00BFA5)),
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => onToggleException(driver, !driver.allowCommissionException),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: driver.allowCommissionException ? Colors.orange : Colors.blueGrey,
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  ),
                  child: Text(
                    driver.allowCommissionException ? 'إلغاء الاستثناء' : 'تفعيل استثناء',
                    style: const TextStyle(),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => onEditLimit(driver),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  ),
                  child: const Text('تعديل السقف', style: TextStyle()),
                ),
                ElevatedButton(
                  onPressed: () => onSettleCommission(driver),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA5),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  ),
                  child: const Text('تسوية / تصفير', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
