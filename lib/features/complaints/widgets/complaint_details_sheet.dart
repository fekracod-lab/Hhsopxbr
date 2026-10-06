import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:url_launcher/url_launcher.dart';
import '../services/complaints_service.dart';
import 'complaint_marker_helper.dart';

class ComplaintDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isDark;
  final bool isAdmin;

  const ComplaintDetailsSheet({
    super.key,
    required this.data,
    required this.docId,
    required this.isDark,
    this.isAdmin = false,
  });

  @override
  State<ComplaintDetailsSheet> createState() => _ComplaintDetailsSheetState();
}

class _ComplaintDetailsSheetState extends State<ComplaintDetailsSheet> {
  final TextEditingController _commentCtrl = TextEditingController();
  final ComplaintsService _service = ComplaintsService();
  bool _isSendingComment = false;

  int _currentImageIndex = 0;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    setState(() => _isSendingComment = true);
    try {
      await _service.addComment(widget.docId, _commentCtrl.text);
      _commentCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت إضافة تعليقك / التحديث بنجاح!', style: TextStyle()),
            backgroundColor: app_colors.primaryColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF0C2428) : Colors.white,
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
          'متأكد تريد تحذف هذا البلاغ نهائياً من الخريطة وقائمة البلاغات؟',
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
        await _service.deleteComplaint(widget.docId);
        if (context.mounted) {
          Navigator.pop(context); // Close bottom sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف البلاغ بنجاح', style: TextStyle()),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
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
    final isDark = widget.isDark;
    final d = widget.data;
    final user = _service.currentUser;
    final isOwner = user != null && d['userId'] == user.uid;

    final title = d['title']?.toString() ?? 'بلاغ';
    final description = d['description']?.toString() ?? '';
    final category = d['category']?.toString() ?? 'أخرى';
    final status = d['status']?.toString() ?? 'pending';
    final locationName = d['locationName']?.toString() ?? '';
    final cityName = d['city']?.toString() ?? '';
    final governorate = d['governorate']?.toString() ?? 'الأنبار';
    final List<dynamic> images = (d['images'] is List && (d['images'] as List).isNotEmpty)
        ? d['images']
        : (d['imageUrl'] != null && d['imageUrl'].toString().isNotEmpty ? [d['imageUrl']] : []);
    final lat = (d['latitude'] is num) ? (d['latitude'] as num).toDouble() : 34.3416;
    final lng = (d['longitude'] is num) ? (d['longitude'] as num).toDouble() : 41.0772;
    final userName = d['userName'] ?? 'مواطن من العراق';
    final upvotesCount = d['upvotesCount'] ?? 0;

    final catColor = ComplaintMarkerHelper.getCategoryColor(category, status);
    final catEmoji = ComplaintMarkerHelper.getCategoryEmoji(category);
    final statusLabel = ComplaintMarkerHelper.getStatusLabel(status);
    final statusColor = ComplaintMarkerHelper.getStatusColor(status);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF07191B) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        ),
        child: Column(
          children: [
            // Handle bar with Close & Delete Buttons
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Container(
                    width: 44.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  const Spacer(),
                  if (isOwner || widget.isAdmin)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      tooltip: 'حذف البلاغ',
                      onPressed: () => _confirmDelete(context),
                    )
                  else
                    SizedBox(width: 40.w),
                ],
              ),
            ),

            // Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Image Slider ──
                    if (images.isNotEmpty) ...[
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20.r),
                            child: SizedBox(
                              height: 220.h,
                              width: double.infinity,
                              child: PageView.builder(
                                itemCount: images.length,
                                onPageChanged: (i) => setState(() => _currentImageIndex = i),
                                itemBuilder: (context, idx) {
                                  return Image.network(
                                    images[idx].toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                                  );
                                },
                              ),
                            ),
                          ),
                          if (images.length > 1)
                            Positioned(
                              bottom: 12.h,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(images.length, (i) {
                                  return Container(
                                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                                    width: _currentImageIndex == i ? 16.w : 6.w,
                                    height: 6.h,
                                    decoration: BoxDecoration(
                                      color: _currentImageIndex == i
                                          ? app_colors.primaryColor
                                          : Colors.white60,
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                  );
                                }),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 14.h),
                    ],

                    // ── 2. Badges Row ──
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
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11.sp,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),

                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                        color: isDark ? Colors.white : const Color(0xFF0C2428),
                      ),
                    ),
                    SizedBox(height: 6.h),

                    // Location Pill & Map Button
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: app_colors.primaryColor, size: 16),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            locationName.isNotEmpty
                                ? '$locationName • ${cityName.isNotEmpty ? cityName : governorate} '
                                : '${cityName.isNotEmpty ? cityName : governorate} ',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            'الموثق: $userName',
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        TextButton.icon(
                          onPressed: () => _openGoogleMaps(lat, lng),
                          icon: const Icon(Icons.map_rounded, size: 16, color: app_colors.primaryColor),
                          label: const Text(
                            'الخريطة',
                            style: TextStyle(fontWeight: FontWeight.bold, color: app_colors.primaryColor),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),

                    // ── 3. Status Timeline ──
                    Container(
                      padding: EdgeInsets.all(14.r),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0D282D) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مراحل متابعة البلاغ:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          _buildTimelineStep('1. تم توثيق البلاغ على الخريطة', true, isDark),
                          _buildTimelineStep('2. قيد المتابعة من فريق المشرفين', status != 'pending', isDark),
                          _buildTimelineStep('3. واصل للبلدية والكوادر الخدمية', status == 'in_progress' || status == 'resolved', isDark),
                          _buildTimelineStep('4. تم الإصلاح ومعالجة المشكلة ', status == 'resolved', isDark, isLast: true),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // Description
                    if (description.isNotEmpty) ...[
                      Text(
                        'تفاصيل البلاغ :',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Container(
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0E2226) : const Color(0xFFFAFBFD),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                        ),
                        child: Text(
                          description,
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            height: 1.6,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                    ],

                    // ── 4. Comments & Community Updates ──
                    Text(
                      'تحديثات وتعليقات أهالي المنطقة',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5.sp,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8.h),

                    // Add comment field
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0D282D) : const Color(0xFFF6F8FB),
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                            ),
                            child: TextField(
                              controller: _commentCtrl,
                              cursorColor: app_colors.primaryColor,
                              style: TextStyle(fontSize: 12.sp, color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'أضف تعليق أو تحديث عن المشكلة...',
                                hintStyle: TextStyle(fontSize: 11.5.sp, color: isDark ? Colors.white54 : Colors.black45),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        IconButton.filled(
                          onPressed: _isSendingComment ? null : _submitComment,
                          icon: _isSendingComment
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.send_rounded, size: 18),
                          style: IconButton.styleFrom(backgroundColor: app_colors.primaryColor),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),

                    // Comments List Stream
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _service.getCommentsStream(widget.docId),
                      builder: (context, snap) {
                        final docs = snap.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                              child: Text(
                                'لا توجد تعليقات حتى الآن.. شارك بتحديثك!',
                                style: TextStyle(fontSize: 11.sp, color: isDark ? Colors.white38 : Colors.black38),
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => SizedBox(height: 8.h),
                          itemBuilder: (context, idx) {
                            final c = docs[idx].data();
                            return Container(
                              padding: EdgeInsets.all(10.r),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0C2226) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c['userName'] ?? 'مواطن',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.sp,
                                      color: app_colors.primaryColor,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    c['text'] ?? '',
                                    style: TextStyle(
                                      fontSize: 11.5.sp,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),

            // ── Bottom Action Bar ──
            Container(
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0C2428) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _service.toggleUpvote(widget.docId);
                        setState(() {});
                      },
                      icon: const Icon(Icons.thumb_up_rounded, color: Colors.white, size: 18),
                      label: Text(
                        'أؤيد هذا البلاغ ($upvotesCount)',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: app_colors.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                    ),
                  ),
                  if (isOwner || widget.isAdmin) ...[
                    SizedBox(width: 8.w),
                    ElevatedButton(
                      onPressed: () => _confirmDelete(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                        foregroundColor: Colors.redAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                      ),
                      child: const Text(
                        'حذف',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  if (widget.isAdmin) ...[
                    SizedBox(width: 8.w),
                    ElevatedButton(
                      onPressed: () async {
                        await _service.updateStatus(widget.docId, 'resolved');
                        if (context.mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                      ),
                      child: const Text(
                        'تأكيد الإصلاح',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep(String label, bool isDone, bool isDark, {bool isLast = false}) {
    return Row(
      children: [
        Icon(
          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: isDone ? const Color(0xFF10B981) : Colors.grey,
          size: 16.r,
        ),
        SizedBox(width: 8.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5.sp,
            fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
            color: isDone ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
          ),
        ),
      ],
    );
  }
}
