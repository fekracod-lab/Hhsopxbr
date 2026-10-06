import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/restaurant_details_models.dart';

const Color _primaryColor = Color(0xFF00BFA5);
const Color _darkBackground = Color(0xFF0F1719);
const Color _darkSurface = Color(0xFF142023);
const Color _darkCard = Color(0xFF1B2B2F);

/// قسم عرض تقييمات ومراجعات المطعم وإحصائيات النجوم بخط IBM
class RestaurantReviewsSection extends StatelessWidget {
  final List<RestaurantReviewEntity> reviews;
  final ReviewStatisticsEntity statistics;
  final bool isDark;
  final bool isLoading;
  final String? currentUserId;
  final VoidCallback onAddReview;
  final ValueChanged<String> onDeleteReview;

  const RestaurantReviewsSection({
    super.key,
    required this.reviews,
    required this.statistics,
    required this.isDark,
    required this.isLoading,
    this.currentUserId,
    required this.onAddReview,
    required this.onDeleteReview,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: EdgeInsets.all(30.0.r),
        child: const Center(
          child: CircularProgressIndicator(color: _primaryColor),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Column(
        children: [
          _buildReviewsHeader(),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'آراء العملاء والتقييمات',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5.sp,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onAddReview();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: _primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'أضف تقييمك +',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w800,
                      color: _primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          if (reviews.isEmpty)
            _buildEmptyState()
          else
            ...reviews.map((review) => _buildSingleReviewItem(review)),
        ],
      ),
    );
  }

  Widget _buildReviewsHeader() {
    final avgRating = statistics.averageRating;
    final count = statistics.totalReviews;
    final counts = statistics.starCounts;

    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2EBE9),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                avgRating.toStringAsFixed(1),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 34.sp,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  height: 1,
                ),
              ),
              SizedBox(height: 4.h),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < avgRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 15.sp,
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '$count تقييم',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              children: [
                _buildRatingBar('5', count > 0 ? (counts[5] ?? 0) / count : 0),
                _buildRatingBar('4', count > 0 ? (counts[4] ?? 0) / count : 0),
                _buildRatingBar('3', count > 0 ? (counts[3] ?? 0) / count : 0),
                _buildRatingBar('2', count > 0 ? (counts[2] ?? 0) / count : 0),
                _buildRatingBar('1', count > 0 ? (counts[1] ?? 0) / count : 0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(String label, double percent) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        children: [
          SizedBox(
            width: 14.w,
            child: Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6.r),
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: isDark ? _darkSurface : const Color(0xFFE2EBE9),
                color: Colors.amber,
                minHeight: 5.h,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleReviewItem(RestaurantReviewEntity review) {
    final userName = review.userName.isNotEmpty ? review.userName : 'مستخدم مدار';
    final initial = userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'M';
    final bool isOwner = currentUserId != null && review.userId == currentUserId;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: isDark ? _darkCard.withValues(alpha: 0.7) : Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2EBE9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16.r,
                backgroundColor: _primaryColor.withValues(alpha: 0.14),
                child: Text(
                  initial,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: _primaryColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5.sp,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    if (review.createdAt != null)
                      Text(
                        _formatTimeAgo(review.createdAt!),
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 9.5.sp,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    review.rating.toStringAsFixed(1),
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.w800,
                      color: Colors.amber,
                      fontSize: 11.5.sp,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Icon(Icons.star_rounded, color: Colors.amber, size: 14.sp),
                ],
              ),
              if (isOwner)
                IconButton(
                  onPressed: () => onDeleteReview(review.id),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 16.sp,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 26.w, minHeight: 26.h),
                ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              review.comment,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11.5.sp,
                color: isDark ? const Color(0xFFE2EBE9) : const Color(0xFF334155),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 30.h),
        child: Column(
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 40.sp,
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
            SizedBox(height: 10.h),
            Text(
              'لا توجد مراجعات حتى الآن، كن أول من يشارك رأيه!',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12.sp,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return 'منذ ${diff.inDays} يوم';
    if (diff.inHours > 0) return 'منذ ${diff.inHours} ساعة';
    if (diff.inMinutes > 0) return 'منذ ${diff.inMinutes} دقيقة';
    return 'الآن';
  }
}

/// نافذة إضافة تقييم ومراجعة جديدة للمطعم بخط IBM
class RestaurantAddReviewSheet extends StatefulWidget {
  final bool isDark;
  final Function(double rating, String comment) onSubmit;

  const RestaurantAddReviewSheet({
    super.key,
    required this.isDark,
    required this.onSubmit,
  });

  @override
  State<RestaurantAddReviewSheet> createState() => _RestaurantAddReviewSheetState();
}

class _RestaurantAddReviewSheetState extends State<RestaurantAddReviewSheet> {
  double _rating = 5.0;
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
        top: 16.h,
        left: 20.w,
        right: 20.w,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? _darkBackground : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'قيم تجربتك مع المطعم',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 16.sp,
              fontWeight: FontWeight.w900,
              color: widget.isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (index) => IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _rating = index + 1.0);
                },
                icon: Icon(
                  index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: 32.sp,
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _controller,
            maxLines: 3,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12.5.sp,
              color: widget.isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              hintText: 'اكتب تجربتك وانطباعك عن الأكل والتوصيل...',
              hintStyle: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11.5.sp,
                color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
              ),
              filled: true,
              fillColor: widget.isDark ? _darkSurface : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15.r),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            ),
          ),
          SizedBox(height: 18.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_rating > 0 && !_isSubmitting)
                  ? () async {
                      HapticFeedback.mediumImpact();
                      setState(() => _isSubmitting = true);
                      widget.onSubmit(_rating, _controller.text.trim());
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'إرسال التقييم',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.sp,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
