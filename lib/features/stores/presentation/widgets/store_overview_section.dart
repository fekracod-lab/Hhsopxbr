import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';
import '../../domain/entities/store_dashboard_models.dart';

/// قسم النظرة العامة للوحة تحكم المتجر (Store Overview Section)
/// يعرض بطاقات الأرباح والإحصائيات وحالات الطلبات والإجراءات السريعة
class StoreOverviewSection extends StatelessWidget {
  final double todayRevenue;
  final double totalRevenue;
  final int totalOrders;
  final int productCount;
  final StoreOrderStatisticsEntity orderStatistics;
  final bool isDark;
  final VoidCallback onAddProduct;
  final VoidCallback onMadarPoints;
  final VoidCallback onEditStore;

  const StoreOverviewSection({
    super.key,
    required this.todayRevenue,
    required this.totalRevenue,
    required this.totalOrders,
    required this.productCount,
    required this.orderStatistics,
    required this.isDark,
    required this.onAddProduct,
    required this.onMadarPoints,
    required this.onEditStore,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(20.r),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── Revenue Cards ──
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'أرباح اليوم',
                value: '${todayRevenue.toInt()} د.ع',
                icon: Icons.today_rounded,
                color: const Color(0xFF6C63FF),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildStatCard(
                title: 'إجمالي الأرباح',
                value: '${totalRevenue.toInt()} د.ع',
                icon: Icons.account_balance_wallet_rounded,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'إجمالي الطلبات',
                value: '$totalOrders',
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFFFF6B6B),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildStatCard(
                title: 'المنتجات',
                value: '$productCount',
                icon: Icons.inventory_2_rounded,
                color: const Color(0xFFFFAB40),
              ),
            ),
          ],
        ),
        SizedBox(height: 24.h),

        // ── Order Status Overview ──
        _buildSectionTitle('حالة الطلبات'),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.all(20.r),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              _buildStatusRow(
                'بانتظار القبول',
                orderStatistics.pendingOrders,
                Colors.orange,
              ),
              SizedBox(height: 12.h),
              _buildStatusRow(
                'تم القبول',
                orderStatistics.acceptedOrders,
                Colors.blue,
              ),
              SizedBox(height: 12.h),
              _buildStatusRow(
                'جاري التوصيل',
                orderStatistics.deliveringOrders,
                const Color(0xFF6C63FF),
              ),
              SizedBox(height: 12.h),
              _buildStatusRow(
                'مكتمل',
                orderStatistics.completedOrders,
                Colors.green,
              ),
              SizedBox(height: 12.h),
              _buildStatusRow(
                'ملغي',
                orderStatistics.cancelledOrders,
                Colors.red,
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),

        // ── Quick Actions ──
        _buildSectionTitle('إجراءات سريعة'),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildQuickAction(
                Icons.add_box_rounded,
                'إضافة منتج',
                const Color(0xFF6C63FF),
                onAddProduct,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildQuickAction(
                Icons.stars_rounded,
                'نقاط مدار',
                Colors.amber,
                onMadarPoints,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildQuickAction(
                Icons.edit_rounded,
                'تعديل المتجر',
                AppTheme.primaryColor,
                onEditStore,
              ),
            ),
          ],
        ),
        SizedBox(height: 80.h),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 22.sp),
          ),
          SizedBox(height: 12.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 10.r,
          height: 10.r,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3.r),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
        decoration: _cardDecoration(),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1A1D26) : Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }
}
