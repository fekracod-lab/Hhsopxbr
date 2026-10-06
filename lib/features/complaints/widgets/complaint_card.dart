import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import '../services/complaints_service.dart';
import 'complaint_marker_helper.dart';

class ComplaintCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isDark;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Function(String status)? onUpdateStatus;
  final bool isAdmin;

  const ComplaintCard({
    super.key,
    required this.data,
    required this.docId,
    required this.isDark,
    this.onTap,
    this.onDelete,
    this.onUpdateStatus,
    this.isAdmin = false,
  });

  Future<void> _confirmDelete(BuildContext context, ComplaintsService service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0C2428) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8.w),
            const Text(
              'حذف هذا البلاغ؟',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'متأكد تريد تحذف هذا البلاغ نهائياً من الخريطة والقائمة؟',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: const Text('نعم، احذف', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await service.deleteComplaint(docId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف البلاغ بنجاح', style: TextStyle()),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
        onDelete?.call();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ أثناء الحذف: $e', style: const TextStyle()),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ComplaintsService();
    final user = service.currentUser;
    final isOwner = user != null && data['userId'] == user.uid;

    final title = data['title']?.toString() ?? 'بلاغ بالشارع';
    final description = data['description']?.toString() ?? '';
    final category = data['category']?.toString() ?? 'أخرى';
    final status = data['status']?.toString() ?? 'pending';
    final locationName = data['locationName']?.toString() ?? '';
    final cityName = data['city']?.toString() ?? '';
    final governorate = data['governorate']?.toString() ?? 'الأنبار';
    final List<dynamic> images = (data['images'] is List && (data['images'] as List).isNotEmpty)
        ? data['images']
        : (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty ? [data['imageUrl']] : []);
    final imageUrl = images.isNotEmpty ? images.first.toString() : '';
    final upvotesCount = data['upvotesCount'] ?? 0;
    final List<dynamic> upvotedUsers = data['upvotedUsers'] is List ? data['upvotedUsers'] : [];
    final hasUpvoted = user != null && upvotedUsers.contains(user.uid);

    final catColor = ComplaintMarkerHelper.getCategoryColor(category, status);
    final catEmoji = ComplaintMarkerHelper.getCategoryEmoji(category);
    final statusLabel = ComplaintMarkerHelper.getStatusLabel(status);
    final statusColor = ComplaintMarkerHelper.getStatusColor(status);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C2428) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20.r),
          child: Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Header: Category & Status Badges ──
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: catColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            ComplaintMarkerHelper.getCategoryIcon(category, status),
                            size: 13.sp,
                            color: catColor,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            category,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11.sp,
                              color: catColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5.sp,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),

                // ── Title & Content ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5.sp,
                              color: isDark ? Colors.white : const Color(0xFF0C2428),
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            SizedBox(height: 4.h),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                color: isDark ? Colors.white70 : Colors.black54,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (imageUrl.isNotEmpty) ...[
                      SizedBox(width: 10.w),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14.r),
                        child: Image.network(
                          imageUrl,
                          width: 65.r,
                          height: 65.r,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 10.h),

                // ── Location & Date ──
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 14, color: app_colors.primaryColor),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        locationName.isNotEmpty
                            ? '$locationName • ${cityName.isNotEmpty ? cityName : governorate} '
                            : '${cityName.isNotEmpty ? cityName : governorate} ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                // ── Bottom Action Row: Upvote & Menu ──
                Row(
                  children: [
                    // Upvote Button
                    InkWell(
                      onTap: () => service.toggleUpvote(docId),
                      borderRadius: BorderRadius.circular(10.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          color: hasUpvoted
                              ? app_colors.primaryColor.withValues(alpha: 0.15)
                              : (isDark ? Colors.white10 : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: hasUpvoted
                                ? app_colors.primaryColor
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.thumb_up_rounded,
                              size: 14.r,
                              color: hasUpvoted ? app_colors.primaryColor : Colors.grey,
                            ),
                            SizedBox(width: 5.w),
                            Text(
                              'أؤيد البلاغ ($upvotesCount)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 10.5.sp,
                                color: hasUpvoted ? app_colors.primaryColor : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Owner / Admin Menu
                    if (isOwner || isAdmin) ...[
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 18),
                        color: isDark ? const Color(0xFF0D282D) : Colors.white,
                        onSelected: (val) {
                          if (val == 'delete') {
                            _confirmDelete(context, service);
                          }
                          if (val == 'resolved') {
                            service.updateStatus(docId, 'resolved');
                            onUpdateStatus?.call('resolved');
                          }
                          if (val == 'in_progress') {
                            service.updateStatus(docId, 'in_progress');
                            onUpdateStatus?.call('in_progress');
                          }
                        },
                        itemBuilder: (ctx) => [
                          if (isAdmin) ...[
                            const PopupMenuItem(
                              value: 'in_progress',
                              child: Text('تحويل إلى قيد المعالجة', style: TextStyle(fontSize: 12)),
                            ),
                            const PopupMenuItem(
                              value: 'resolved',
                              child: Text('تأكيد تم الحل والإصلاح', style: TextStyle(fontSize: 12, color: Colors.green)),
                            ),
                          ],
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('حذف البلاغ', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
