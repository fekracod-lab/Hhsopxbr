import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:dalal_alqaim/pages/vacancy_details_page.dart';
import '../services/vacancy_service.dart';

class VacancyCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  final VoidCallback? onDelete;
  final VoidCallback? onApply;

  const VacancyCard({
    super.key,
    required this.data,
    required this.isDark,
    this.onDelete,
    this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final type = data['type'] ?? 'employer';
    final isSeeker = type == 'seeker';

    return isSeeker ? _buildCandidateCard(context) : _buildJobCard(context);
  }

  // ══════════════════════════════════════════════════════════
  // 1. بطاقة فرصة عمل شاغرة (Job Opportunity Card)
  // ══════════════════════════════════════════════════════════
  Widget _buildJobCard(BuildContext context) {
    final service = VacancyService();
    final title = data['jobDetails'] ?? data['job'] ?? data['title'] ?? 'وظيفة شاغرة';
    final company = data['company'] ?? 'متجر / شركة';
    final city = data['city']?.toString() ?? 'القائم';
    final gov = data['governorate']?.toString() ?? '';
    final locText = (gov.isNotEmpty && gov != city && !city.contains(gov)) ? '$city • $gov' : city;
    final phone = data['phone']?.toString() ?? '';
    final salary = (data['salary'] != null && data['salary'].toString().isNotEmpty)
        ? data['salary'].toString()
        : 'راتب مجزي / اتفاقي';
    final description = data['notes'] ?? data['description'] ?? '';
    final List<dynamic> tags = data['tags'] ?? (data['tag'] != null ? [data['tag']] : []);
    final workType = data['workType'] ?? 'دوام كامل';
    final experience = data['experience'] ?? 'متوسط';
    final isOwner = data['createdBy'] == service.currentUser?.uid && data['id'] != null;
    final dateFormatted = data['date'] != null ? service.formatDate(service.parseDate(data['date'])) : 'اليوم';

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C2428) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (data['id'] != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VacancyDetailsPage(
                    vacancyId: data['id'],
                    vacancyData: data,
                  ),
                ),
              );
            } else if (onApply != null) {
              onApply!();
            }
          },
          borderRadius: BorderRadius.circular(20.r),
          child: Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Top Header: Company Info + Location + Date ──
                Row(
                  children: [
                    // Company Icon Badge
                    Container(
                      width: 44.r,
                      height: 44.r,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            app_colors.primaryColor.withValues(alpha: isDark ? 0.25 : 0.15),
                            app_colors.primaryColor.withValues(alpha: isDark ? 0.4 : 0.25),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: app_colors.primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: app_colors.primaryColor, size: 22),
                    ),
                    SizedBox(width: 10.w),

                    // Company Name & Location
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            company,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, color: app_colors.primaryColor, size: 12),
                              SizedBox(width: 3.w),
                              Text(
                                '$locText ',
                                style: TextStyle(
                                  fontSize: 10.5.sp,
                                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                ' • $dateFormatted',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Owner Delete Button or Bookmark
                    if (isOwner && onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: onDelete,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    else
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6.r,
                              height: 6.r,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'فرصة نشطة',
                              style: TextStyle(
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 10.h),

                // ── 2. Job Title ──
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15.sp,
                    color: isDark ? Colors.white : const Color(0xFF0C2428),
                  ),
                ),
                SizedBox(height: 8.h),

                // ── 3. Prominent Badges Row (Salary, Work Type, Experience) ──
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Salary Badge
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.12),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.payments_rounded, color: Color(0xFF10B981), size: 14),
                            SizedBox(width: 4.w),
                            Text(
                              salary.contains('د.ع') || salary.contains('\$') ? salary : '$salary د.ع',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11.sp,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 6.w),

                      // Work Type Badge
                      _buildChip(
                        icon: Icons.access_time_filled_rounded,
                        text: workType,
                        color: const Color(0xFF3B82F6),
                        isDark: isDark,
                      ),
                      SizedBox(width: 6.w),

                      // Experience Badge
                      _buildChip(
                        icon: Icons.military_tech_rounded,
                        text: experience,
                        color: const Color(0xFFF59E0B),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),

                // ── 4. Short Description Snippet ──
                if (description.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      height: 1.4,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],

                // ── 5. Skills Tags ──
                if (tags.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 5.w,
                    runSpacing: 4.h,
                    children: tags.take(3).map((tag) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF13363A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: isDark ? Colors.white60 : Colors.grey.shade700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                SizedBox(height: 12.h),

                Divider(color: isDark ? Colors.white10 : Colors.grey.shade200, height: 1),
                SizedBox(height: 10.h),

                // ── 6. Action Footer (WhatsApp / Call / Apply) ──
                Row(
                  children: [
                    // Direct WhatsApp Contact
                    if (phone.isNotEmpty) ...[
                      Expanded(
                        child: InkWell(
                          onTap: () => service.contactWhatsApp(phone, title),
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: const Color(0xFF25D366), width: 1),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 15),
                                SizedBox(width: 4.w),
                                Text(
                                  'واتساب سريع',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5.sp,
                                    color: const Color(0xFF25D366),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                    ],

                    // Apply Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onApply,
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 14),
                        label: Text(
                          'قدّم على الشغل',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5.sp,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: app_colors.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // 2. بطاقة باحث عن عمل وكفاءة (Job Seeker / Talent Card)
  // ══════════════════════════════════════════════════════════
  Widget _buildCandidateCard(BuildContext context) {
    final service = VacancyService();
    final name = data['name'] ?? 'مستخدم مدار';
    final job = data['job'] ?? data['jobDetails'] ?? 'باحث عن عمل';
    final experience = data['experience'] ?? 'متوسط';
    final city = data['city']?.toString() ?? 'القائم';
    final gov = data['governorate']?.toString() ?? '';
    final locText = (gov.isNotEmpty && gov != city && !city.contains(gov)) ? '$city • $gov' : city;
    final phone = data['phone']?.toString() ?? '';
    final avatar = data['imageUrl'] ?? data['avatar'] ?? '';
    final List<dynamic> skills = data['skills'] ?? (data['tag'] != null ? [data['tag']] : []);
    final isOwner = data['createdBy'] == service.currentUser?.uid && data['id'] != null;
    final dateFormatted = data['date'] != null ? service.formatDate(service.parseDate(data['date'])) : 'اليوم';
    final bio = data['notes'] ?? data['bio'] ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C2428) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (data['id'] != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VacancyDetailsPage(
                    vacancyId: data['id'],
                    vacancyData: data,
                  ),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(20.r),
          child: Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Top Row: Avatar + Name + Available Status ──
                Row(
                  children: [
                    // Avatar with status ring
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 24.r,
                          backgroundColor: app_colors.primaryColor.withValues(alpha: 0.15),
                          backgroundImage: (avatar != null && avatar.toString().isNotEmpty)
                              ? NetworkImage(avatar.toString())
                              : null,
                          child: (avatar == null || avatar.toString().isEmpty)
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.sp,
                                    color: app_colors.primaryColor,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 12.r,
                            height: 12.r,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(color: isDark ? const Color(0xFF0C2428) : Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 10.w),

                    // Name & Career Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.sp,
                                    color: isDark ? Colors.white : const Color(0xFF0C2428),
                                  ),
                                ),
                              ),
                              SizedBox(width: 4.w),
                              const Icon(Icons.verified_rounded, color: app_colors.primaryColor, size: 14),
                            ],
                          ),
                          Text(
                            job,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                              color: app_colors.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Available Badge / Delete
                    if (isOwner && onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: onDelete,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    else
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          'متاح للعمل',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 10.h),

                // ── 2. Experience & City Badges ──
                Row(
                  children: [
                    _buildChip(
                      icon: Icons.military_tech_rounded,
                      text: 'خبرة $experience',
                      color: const Color(0xFFF59E0B),
                      isDark: isDark,
                    ),
                    SizedBox(width: 6.w),
                    _buildChip(
                      icon: Icons.location_on_rounded,
                      text: '$locText • $dateFormatted',
                      color: const Color(0xFF3B82F6),
                      isDark: isDark,
                    ),
                  ],
                ),

                // ── 3. Bio / Summary ──
                if (bio.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Text(
                    bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      height: 1.4,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],

                // ── 4. Skills Tags ──
                if (skills.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 4.h,
                    children: skills.take(4).map((skill) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF13363A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                        ),
                        child: Text(
                          skill.toString(),
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                SizedBox(height: 12.h),

                Divider(color: isDark ? Colors.white10 : Colors.grey.shade200, height: 1),
                SizedBox(height: 10.h),

                // ── 5. Contact Buttons (WhatsApp & Call) ──
                Row(
                  children: [
                    if (phone.isNotEmpty) ...[
                      Expanded(
                        child: InkWell(
                          onTap: () => service.contactWhatsApp(phone, 'باحث عن عمل: $job ($name)'),
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: const Color(0xFF25D366), width: 1),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 15),
                                SizedBox(width: 4.w),
                                Text(
                                  'واتساب سريع',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5.sp,
                                    color: const Color(0xFF25D366),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                    ],

                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (data['id'] != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VacancyDetailsPage(
                                  vacancyId: data['id'],
                                  vacancyData: data,
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.person_search_rounded, color: Colors.white, size: 15),
                        label: Text(
                          'شوف السيرة والخبرات',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5.sp,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: app_colors.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String text,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12.sp),
          SizedBox(width: 3.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
