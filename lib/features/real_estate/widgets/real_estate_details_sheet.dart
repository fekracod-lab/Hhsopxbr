import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import '../services/real_estate_service.dart';

class RealEstateDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isDark;

  const RealEstateDetailsSheet({
    super.key,
    required this.data,
    required this.docId,
    required this.isDark,
  });

  @override
  State<RealEstateDetailsSheet> createState() => _RealEstateDetailsSheetState();
}

class _RealEstateDetailsSheetState extends State<RealEstateDetailsSheet> {
  final TextEditingController _commentCtrl = TextEditingController();
  final RealEstateService _service = RealEstateService();
  int _currentImageIndex = 0;
  bool _isSendingComment = false;

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
            content: Text('تم نشر تعليقك واستفسارك بنجاح!', style: TextStyle()),
            backgroundColor: app_colors.primaryColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final d = widget.data;
    final title = d['title'] ?? 'تفاصيل العقار';
    final type = d['type'] ?? 'للبيع';
    final category = d['category'] ?? 'بيت';
    final price = d['price']?.toString() ?? 'اتفاقي';
    final currency = d['currency'] == 'USD' ? '\$' : 'د.ع';
    final area = d['area']?.toString() ?? '';
    final location = d['location']?.toString() ?? '';
    final city = d['city']?.toString() ?? 'القائم';
    final gov = d['governorate']?.toString() ?? '';
    final locText = (gov.isNotEmpty && gov != city && !city.contains(gov))
        ? (location.isNotEmpty ? '$location • $city ($gov)' : '$city ($gov)')
        : (location.isNotEmpty ? '$location • $city' : city);
    final phone = d['phone']?.toString() ?? '';
    final description = d['description']?.toString() ?? 'ماكو وصف حالياً إضافي.';
    final isSold = d['sold'] == true;
    final bedrooms = d['bedrooms'] ?? 0;
    final bathrooms = d['bathrooms'] ?? 0;
    final streetWidth = d['streetWidth']?.toString() ?? '';
    final List<dynamic> images = (d['images'] is List && (d['images'] as List).isNotEmpty)
        ? d['images']
        : (d['imageUrl'] != null && d['imageUrl'].toString().isNotEmpty ? [d['imageUrl']] : []);
    final List<dynamic> features = (d['features'] is List) ? d['features'] : [];
    final ownerName = d['ownerName'] ?? 'صاحب العقار';

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
            // Handle bar
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              child: Container(
                width: 44.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),

            // Scrollable Content
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
                                    images[idx],
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

                    // Badges row
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: isSold
                                ? Colors.red.shade600
                                : (type == 'للبيع' ? const Color(0xFF10B981) : const Color(0xFF3B82F6)),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Text(
                            isSold ? 'تم البيع / الحجز' : '$type ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11.sp,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: app_colors.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11.sp,
                              color: app_colors.primaryColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$price $currency',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),

                    // Title & Location
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                        color: isDark ? Colors.white : const Color(0xFF0C2428),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: app_colors.primaryColor, size: 16),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            '$locText ',
                            style: TextStyle(
                              fontSize: 12.sp,
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
                            'المعلن: $ownerName',
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),

                    // Specs Grid
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0D282D) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          if (area.isNotEmpty) _buildSpecItem(Icons.aspect_ratio_rounded, 'المساحة', '$area م²', isDark),
                          if (bedrooms > 0) _buildSpecItem(Icons.bed_rounded, 'غرف النوم', '$bedrooms غرف', isDark),
                          if (bathrooms > 0) _buildSpecItem(Icons.bathtub_rounded, 'الحمامات', '$bathrooms حمام', isDark),
                          if (streetWidth.isNotEmpty) _buildSpecItem(Icons.edit_road_rounded, 'الشارع', '$streetWidthم', isDark),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Features List
                    if (features.isNotEmpty) ...[
                      Text(
                        'المميزات والخدمات المتوفرة:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 6.w,
                        runSpacing: 6.h,
                        children: features.map((f) {
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF13363A) : Colors.white,
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(color: app_colors.primaryColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, color: app_colors.primaryColor, size: 14),
                                SizedBox(width: 4.w),
                                Text(
                                  f.toString(),
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 16.h),
                    ],

                    // Description
                    Text(
                      'الوصف والتفاصيل:',
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
                          fontSize: 12.sp,
                          height: 1.6,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // ── Comments & Inquiries ──
                    Text(
                      'الاستفسارات والتعليقات',
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
                          child: TextField(
                            controller: _commentCtrl,
                            cursorColor: app_colors.primaryColor,
                            style: TextStyle(fontSize: 12.sp, color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              hintText: 'اسأل صاحب العقار سؤالك هنا...',
                              hintStyle: TextStyle(fontSize: 11.sp, color: Colors.grey),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F2D32) : Colors.grey.shade100,
                              contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14.r),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        ElevatedButton(
                          onPressed: _isSendingComment ? null : _submitComment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: app_colors.primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                          ),
                          child: _isSendingComment
                              ? SizedBox(width: 16.r, height: 16.r, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('إرسال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),

                    // Comments Stream
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _service.getCommentsStream(widget.docId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            child: Text(
                              'لا توجد استفسارات بعد، كن أول من يسأل!',
                              style: TextStyle(fontSize: 11.sp, color: Colors.grey),
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
                                    c['userName'] ?? 'مستخدم',
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
                    SizedBox(height: 80.h),
                  ],
                ),
              ),
            ),

            // ── Fixed Bottom Contact Bar ──
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
                  // WhatsApp Button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: phone.isNotEmpty ? () => _service.contactWhatsApp(phone, title) : null,
                      icon: const Icon(Icons.chat_rounded, color: Colors.white, size: 18),
                      label: const Text(
                        'واتساب مع المعلن',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),

                  // Phone Call Button
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      onPressed: phone.isNotEmpty ? () => _service.makePhoneCall(phone) : null,
                      icon: const Icon(Icons.phone_rounded, color: app_colors.primaryColor, size: 18),
                      label: const Text(
                        'اتصال',
                        style: TextStyle(fontWeight: FontWeight.bold, color: app_colors.primaryColor),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: app_colors.primaryColor, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecItem(IconData icon, String label, String value, bool isDark) {
    return Column(
      children: [
        Icon(icon, color: app_colors.primaryColor, size: 20),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11.5.sp,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            color: isDark ? Colors.white38 : Colors.grey,
          ),
        ),
      ],
    );
  }
}
