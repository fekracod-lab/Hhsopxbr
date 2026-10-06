import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';
import '../../domain/entities/store_dashboard_models.dart';
import 'store_order_card.dart';

/// قسم إدارة طلبات المتجر (Store Orders Section)
/// يعرض شريط تصنيف الطلبات وقائمة بطاقات الطلبات مع حالات التحميل والفرز
class StoreOrdersSection extends StatelessWidget {
  final List<StoreOrderEntity> orders;
  final String selectedFilter;
  final bool isLoading;
  final bool isDark;
  final ValueChanged<String> onFilterChanged;
  final Function(String orderId, String nextStatus) onStatusChange;
  final Function(String phone)? onCallCustomer;
  final Function(String orderId)? onMarkRead;

  const StoreOrdersSection({
    super.key,
    required this.orders,
    required this.selectedFilter,
    this.isLoading = false,
    required this.isDark,
    required this.onFilterChanged,
    required this.onStatusChange,
    this.onCallCustomer,
    this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Filter Chips ──
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Row(
            children: [
              _buildFilterChip('all', 'الكل', Icons.list_alt_rounded),
              _buildFilterChip('pending', 'بانتظار', Icons.hourglass_empty_rounded),
              _buildFilterChip('accepted', 'مقبول', Icons.check_circle_outline_rounded),
              _buildFilterChip('delivering', 'توصيل', Icons.delivery_dining_rounded),
              _buildFilterChip('completed', 'مكتمل', Icons.task_alt_rounded),
              _buildFilterChip('cancelled', 'ملغي', Icons.cancel_outlined),
            ],
          ),
        ),

        // ── Orders List ──
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                    strokeWidth: 2,
                  ),
                )
              : orders.isEmpty
                  ? _buildEmptyState(
                      Icons.receipt_long_outlined,
                      'ماكو طلبات حالياً في هذا القسم',
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 100.h),
                      physics: const BouncingScrollPhysics(),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return StoreOrderCard(
                          order: order,
                          isDark: isDark,
                          onStatusChange: onStatusChange,
                          onCallCustomer: onCallCustomer,
                          onMarkRead: onMarkRead,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = selectedFilter == value;
    return Padding(
      padding: EdgeInsets.only(left: 8.w),
      child: GestureDetector(
        onTap: () => onFilterChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDark ? Colors.white10 : Colors.white),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : Colors.grey.withValues(alpha: 0.2),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16.sp,
                color: isSelected ? Colors.white : Colors.grey,
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48.sp,
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
