import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class VacancyDetailsPage extends StatefulWidget {
  final String vacancyId;
  final Map<String, dynamic> vacancyData;

  const VacancyDetailsPage({
    super.key,
    required this.vacancyId,
    required this.vacancyData,
  });

  @override
  State<VacancyDetailsPage> createState() => _VacancyDetailsPageState();
}

class _VacancyDetailsPageState extends State<VacancyDetailsPage> {
  final _commentController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  bool _isSubmittingComment = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
    // Increment view count in Firestore
    FirebaseFirestore.instance
        .collection('vacancies')
        .doc(widget.vacancyId)
        .update({'views': FieldValue.increment(1)}).catchError((e) {
      debugPrint('Error incrementing views: $e');
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('سجّل دخولك أولاً للتعليق', style: TextStyle()),
          behavior: SnackBarBehavior.fixed,
        ),
      );
      return;
    }

    setState(() => _isSubmittingComment = true);
    try {
      // Get author name from user profile
      String authorName = _currentUser.displayName ?? _currentUser.email ?? 'مستخدم مدار';
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .get();
      if (userDoc.exists) {
        authorName = userDoc.data()?['name'] ?? userDoc.data()?['fullName'] ?? authorName;
      }

      await FirebaseFirestore.instance
          .collection('vacancies')
          .doc(widget.vacancyId)
          .collection('comments')
          .add({
        'commentText': text,
        'authorName': authorName,
        'authorUid': _currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إضافة التعليق: $e', style: const TextStyle()),
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingComment = false);
      }
    }
  }

  Future<void> _deleteVacancy() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text(
            'تأكيد الحذف',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'متأكد تريد تحذف هذا الإعلان؟',
            style: TextStyle(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'حذف',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('vacancies').doc(widget.vacancyId).delete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الوظيفة بنجاح', style: TextStyle()),
            behavior: SnackBarBehavior.fixed,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is Timestamp) {
      final dt = date.toDate();
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    return '';
  }

  Future<void> _checkAdminRole() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _isAdmin = doc.data()?['role'] == 'admin';
        });
      }
    } catch (e) {
      debugPrint('Error checking admin role: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = app_colors.primaryColor;
    final bg = isDark ? app_colors.darkBackground : const Color(0xFFF8F9FC);
    final cardBg = isDark ? app_colors.darkCard : Colors.white;
    final textTheme = isDark ? Colors.white : Colors.black87;
    final subTextTheme = isDark ? Colors.white54 : Colors.grey.shade600;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vacancies')
          .doc(widget.vacancyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: bg,
            body: const Center(child: CircularProgressIndicator(color: app_colors.primaryColor)),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: bg,
            body: Center(
              child: Text(
                'هذه الوظيفة غير موجودة أو تم حذفها.',
                style: TextStyle(color: textTheme),
              ),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final isSeeker = data['type'] == 'seeker';
        final accent = isSeeker ? primary : const Color(0xFFFF6B35);
        final isOwner = _currentUser?.uid == data['createdBy'];
        final imageUrl = data['imageUrl'] as String?;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: bg,
            appBar: AppBar(
              backgroundColor: bg,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: textTheme, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                isSeeker ? 'طلب عمل' : 'فرصة عمل',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18.sp,
                  color: textTheme,
                ),
              ),
              actions: [
                if (_isAdmin || isOwner)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    onPressed: _deleteVacancy,
                  ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main Details Card
                        Container(
                          padding: EdgeInsets.all(16.r),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(24.r),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image view if present
                              if (imageUrl != null && imageUrl.isNotEmpty) ...[
                                Hero(
                                  tag: 'vacancy_image_${widget.vacancyId}',
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16.r),
                                    child: Image.network(
                                      imageUrl,
                                      width: double.infinity,
                                      height: 200.h,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 200.h,
                                        color: isDark ? Colors.white12 : Colors.grey.shade200,
                                        child: Icon(Icons.broken_image_rounded, color: accent, size: 40.sp),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16.h),
                              ],
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(10.r),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16.r),
                                    ),
                                    child: Icon(
                                      isSeeker ? Icons.person_rounded : Icons.business_rounded,
                                      color: accent,
                                      size: 32.sp,
                                    ),
                                  ),
                                  SizedBox(width: 14.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['name'] ?? data['company'] ?? 'غير معروف',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18.sp,
                                            color: textTheme,
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          isSeeker ? 'باحث عن فرصة عمل' : 'صاحب عمل يعلن عن فرصة',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: accent,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20.h),
                              Text(
                                data['job'] ?? data['jobDetails'] ?? '',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                  color: textTheme,
                                  height: 1.5,
                                ),
                              ),
                              if (data['notes'] != null && data['notes'].toString().isNotEmpty) ...[
                                SizedBox(height: 14.h),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(14.r),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF9FBFB),
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                                    ),
                                  ),
                                  child: Text(
                                    data['notes'],
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                                      height: 1.7,
                                    ),
                                  ),
                                ),
                              ],
                              SizedBox(height: 16.h),
                              // Chips
                              Wrap(
                                spacing: 8.w,
                                runSpacing: 8.h,
                                children: [
                                  if (data['tag'] != null)
                                    _detailChip(Icons.tag_rounded, data['tag'], primary),
                                  if (data['experience'] != null)
                                    _detailChip(Icons.grade_rounded, data['experience'], const Color(0xFF8B5CF6)),
                                  if (data['salary'] != null && data['salary'].toString().isNotEmpty)
                                    _detailChip(Icons.payments_rounded, data['salary'], const Color(0xFF10B981)),
                                  if (data['workType'] != null)
                                    _detailChip(Icons.schedule_rounded, data['workType'], const Color(0xFFEC4899)),
                                  if (data['city'] != null)
                                    _detailChip(Icons.location_on_rounded, data['city'], const Color(0xFF6366F1)),
                                  _detailChip(Icons.visibility_rounded, '${data['views'] ?? 0} مشاهدة', Colors.blueGrey),
                                  _detailChip(Icons.today_rounded, _formatDate(data['date']), Colors.grey),
                                ],
                              ),
                              SizedBox(height: 20.h),
                              // Contact actions
                              Row(
                                children: [
                                  if (data['phone'] != null) ...[
                                    Expanded(
                                      child: _contactButton(
                                        Icons.phone_rounded,
                                        'اتصال',
                                        const Color(0xFF10B981),
                                        () => launchUrl(Uri.parse('tel:${data['phone']}')),
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: _contactButton(
                                        Icons.chat_rounded,
                                        'واتساب',
                                        const Color(0xFF25D366),
                                        () => launchUrl(Uri.parse('https://wa.me/${data['phone']}')),
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                  ],
                                  _shareButton(data),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24.h),
                        // Comments Title
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: Text(
                            'التعليقات والمناقشة',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: textTheme,
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        // Live Comments Stream
                        _buildCommentsList(isDark, cardBg, textTheme, subTextTheme),
                      ],
                    ),
                  ),
                ),
                // Comment input bar
                _buildCommentInputBar(isDark, cardBg, textTheme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailChip(IconData icon, String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.2 : 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? color.withValues(alpha: 0.9) : color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        height: 48.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18.sp, color: color),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shareButton(Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white60 : Colors.grey.shade700;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        final name = data['name'] ?? data['company'] ?? '';
        final job = data['job'] ?? data['jobDetails'] ?? '';
        final phone = data['phone'] ?? '';
        final salary = data['salary'] ?? '';
        final city = data['city'] ?? '';
        final text =
            'وظيفة: $job\n'
            'الاسم: $name\n'
            '${salary.isNotEmpty ? "الراتب: $salary\n" : ""}'
            '${city.isNotEmpty ? "المدينة: $city\n" : ""}'
            '${phone.isNotEmpty ? "للتواصل: $phone\nواتساب: https://wa.me/$phone" : ""}';
        Share.share(text);
      },
      child: Container(
        width: 48.r,
        height: 48.r,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
        ),
        child: Icon(Icons.share_rounded, size: 18.sp, color: color),
      ),
    );
  }

  Widget _buildCommentsList(bool isDark, Color cardBg, Color textTheme, Color subTextTheme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vacancies')
          .doc(widget.vacancyId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100),
            ),
            child: Column(
              children: [
                Icon(Icons.forum_outlined, color: subTextTheme.withValues(alpha: 0.5), size: 36.sp),
                SizedBox(height: 8.h),
                Text(
                  'لا توجد تعليقات بعد.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: subTextTheme,
                  ),
                ),
                Text(
                  'كن أول من يشارك بتعليق أو سؤال!',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: subTextTheme.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => SizedBox(height: 10.h),
          itemBuilder: (context, i) {
            final comment = docs[i].data() as Map<String, dynamic>;
            final author = comment['authorName'] ?? 'مستخدم مدار';
            final text = comment['commentText'] ?? '';
            final isOwnComment = _currentUser?.uid == comment['authorUid'];
            final time = _formatDate(comment['createdAt']);

            return Align(
              alignment: isOwnComment ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                padding: EdgeInsets.all(12.r),
                constraints: BoxConstraints(maxWidth: 0.8.sw),
                decoration: BoxDecoration(
                  color: isOwnComment
                      ? app_colors.primaryColor.withValues(alpha: 0.08)
                      : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(16.r).copyWith(
                    bottomRight: isOwnComment ? null : Radius.circular(16.r),
                    bottomLeft: isOwnComment ? Radius.circular(16.r) : null,
                  ),
                  border: Border.all(
                    color: isOwnComment
                        ? app_colors.primaryColor.withValues(alpha: 0.25)
                        : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          author,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11.sp,
                            color: isOwnComment ? app_colors.primaryColor : textTheme,
                          ),
                        ),
                        if (time.isNotEmpty) ...[
                          SizedBox(width: 8.w),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: subTextTheme.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCommentInputBar(bool isDark, Color cardBg, Color textTheme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF2F5F8),
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _commentController,
                  style: TextStyle(color: textTheme, fontSize: 13.sp),
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: _currentUser == null ? 'سجّل دخولك أولاً للتعليق...' : 'اكتب تعليقاً أو استفساراً...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white30 : Colors.grey.shade400,
                      fontSize: 12.sp,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                    enabled: _currentUser != null,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: _isSubmittingComment ? null : _submitComment,
              child: Container(
                width: 42.r,
                height: 42.r,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [app_colors.primaryColor, app_colors.accentColor],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: app_colors.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: _isSubmittingComment
                    ? Padding(
                        padding: EdgeInsets.all(12.r),
                        child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Icon(Icons.send_rounded, color: Colors.white, size: 18.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
