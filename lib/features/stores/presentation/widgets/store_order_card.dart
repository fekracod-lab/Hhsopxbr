import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';
import '../../domain/entities/store_dashboard_models.dart';

/// بطاقة تفاصيل وإجراءات الطلب (Store Order Card Widget)
/// واجهة عرض صافية لبيانات الطلب وعناصره وأزرار التفاعل والانتقال بين الحالات
class StoreOrderCard extends StatelessWidget {
  final StoreOrderEntity order;
  final bool isDark;
  final Function(String orderId, String nextStatus) onStatusChange;
  final Function(String phone)? onCallCustomer;
  final Function(String orderId)? onMarkRead;

  const StoreOrderCard({
    super.key,
    required this.order,
    required this.isDark,
    required this.onStatusChange,
    this.onCallCustomer,
    this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    final isNew = !order.readByStore;
    final timeAgo = order.createdAt != null ? _formatTimeAgo(order.createdAt!) : '';

    final driverName = order.rawData['driverName']?.toString();
    final driverPhone = order.rawData['driverPhone']?.toString();

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D26) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: isNew
            ? Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.6),
                width: 1.5,
              )
            : null,
      ),
      child: Column(
        children: [
          // ── Card Header ──
          Container(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Row(
              children: [
                if (isNew) ...[
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'جديد',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],
                Expanded(
                  child: Text(
                    '#${order.orderId}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6.r,
                        height: 6.r,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Card Body ──
          Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Info Row
                Row(
                  children: [
                    Container(
                      width: 40.r,
                      height: 40.r,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: AppTheme.primaryColor,
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName.isNotEmpty
                                ? order.customerName
                                : 'زبون مجهول',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (timeAgo.isNotEmpty)
                            Text(
                              timeAgo,
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Call Button
                    if (order.customerPhone.isNotEmpty)
                      GestureDetector(
                        onTap: () => onCallCustomer?.call(order.customerPhone),
                        child: Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.call_rounded,
                            color: Colors.green,
                            size: 18.sp,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 12.h),

                // Address
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16.sp,
                        color: Colors.grey,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          order.address.isNotEmpty ? order.address : 'بدون عنوان',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),

                // Driver details if assigned
                if (driverName != null && driverName.isNotEmpty) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.delivery_dining_rounded, size: 16.sp, color: Colors.blue),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'المندوب: $driverName',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                        if (driverPhone != null && driverPhone.isNotEmpty)
                          GestureDetector(
                            onTap: () => onCallCustomer?.call(driverPhone),
                            child: Icon(Icons.call, size: 14.sp, color: Colors.blue),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                ],

                // Items Preview
                if (order.items.isNotEmpty) ...[
                  Text(
                    'المنتجات (${order.items.length})',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  SizedBox(
                    height: 36.h,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: order.items.length > 5 ? 5 : order.items.length,
                      itemBuilder: (context, i) {
                        final item = order.items[i];
                        return Container(
                          margin: EdgeInsets.only(left: 6.w),
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.grey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Center(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 12.h),
                ],

                // Total & Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المجموع',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          '${order.total.toInt()} د.ع',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryColor,
                            fontSize: 18.sp,
                          ),
                        ),
                      ],
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (status == 'pending')
                              _buildActionBtn(
                                icon: Icons.cancel_outlined,
                                label: 'رفض',
                                color: Colors.red,
                                onTap: () => onStatusChange(order.orderId, 'cancelled'),
                              ),
                            if (status == 'pending') SizedBox(width: 8.w),
                            if (status != 'completed' && status != 'cancelled')
                              _buildActionBtn(
                                icon: _getNextActionIcon(status),
                                label: _getNextActionText(status),
                                color: _getNextActionColor(status),
                                onTap: () {
                                  if (!order.readByStore) {
                                    onMarkRead?.call(order.orderId);
                                  }
                                  String? nextStatus;
                                  if (status == 'pending') {
                                    nextStatus = 'accepted';
                                  } else if (status == 'accepted') {
                                    nextStatus = 'ready';
                                  } else if (status == 'ready') {
                                    return; // Waiting for driver pickup
                                  } else if (status == 'delivering' || status == 'picked_up') {
                                    nextStatus = 'completed';
                                  } else {
                                    return;
                                  }
                                  onStatusChange(order.orderId, nextStatus);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16.sp),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'ready':
        return Colors.purple;
      case 'delivering':
      case 'picked_up':
        return const Color(0xFF6C63FF);
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'بانتظار القبول';
      case 'accepted':
        return 'تم القبول والتحضير';
      case 'ready':
        return 'جاهز وبانتظار المندوب';
      case 'delivering':
        return 'تم قبول التوصيل';
      case 'picked_up':
        return 'جاري التوصيل';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'غير معروف';
    }
  }

  IconData _getNextActionIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.check_rounded;
      case 'accepted':
        return Icons.backpack_rounded;
      case 'ready':
        return Icons.hourglass_top_rounded;
      case 'delivering':
      case 'picked_up':
        return Icons.task_alt_rounded;
      default:
        return Icons.check_rounded;
    }
  }

  String _getNextActionText(String status) {
    switch (status) {
      case 'pending':
        return 'قبول';
      case 'accepted':
        return 'تم التجهيز';
      case 'ready':
        return 'انتظار المندوب';
      case 'delivering':
      case 'picked_up':
        return 'إتمام';
      default:
        return 'تحديث';
    }
  }

  Color _getNextActionColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.blue;
      case 'accepted':
        return Colors.purple;
      case 'ready':
        return Colors.orange;
      case 'delivering':
      case 'picked_up':
        return Colors.green;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
