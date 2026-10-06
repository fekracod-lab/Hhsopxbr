import 'package:flutter/material.dart';
import 'package:dalal_alqaim/models/rating_model.dart';
import 'package:dalal_alqaim/services/rating_service.dart';
import 'package:dalal_alqaim/core/app_globals.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// صفحة إدارة ومتابعة التقييمات الشاملة للإدارة (Admin Ratings Management)
class AdminRatingsManagementPage extends StatefulWidget {
  const AdminRatingsManagementPage({super.key});

  @override
  State<AdminRatingsManagementPage> createState() => _AdminRatingsManagementPageState();
}

class _AdminRatingsManagementPageState extends State<AdminRatingsManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _showReplyDialog(RatingModel rating) {
    _replyController.text = rating.reply ?? '';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.reply_rounded, color: Color(0xFF00A896), size: 24),
              const SizedBox(width: 8),
              Text(
                'الرد على تقييم ${rating.authorName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'التقييم: ${rating.rating} | المستهدف: ${rating.targetName}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (rating.comment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    rating.comment,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _replyController,
                maxLines: 3,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'اكتب رد الإدارة الرسمي هنا...',
                  hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A896),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final replyText = _replyController.text.trim();
                if (replyText.isNotEmpty) {
                  Navigator.pop(ctx);
                  await RatingService.replyToRating(rating.id, replyText);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم نشر الرد بنجاح', style: TextStyle()),
                        backgroundColor: Color(0xFF00A896),
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'نشر الرد',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, _) {
        final bgColor = isDark ? const Color(0xFF0C2426) : const Color(0xFFF7FAFA);
        final cardColor = isDark ? const Color(0xFF13363A) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
        final primaryColor = const Color(0xFF00A896);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(
              title: const Text(
                'إدارة ومراقبة التقييمات',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              centerTitle: true,
              backgroundColor: cardColor,
              elevation: 0,
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: primaryColor,
                unselectedLabelColor: textColor.withValues(alpha: 0.6),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                indicatorColor: primaryColor,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'الكل'),
                  Tab(text: 'سلبية'),
                  Tab(text: 'الكباتن'),
                  Tab(text: 'المطاعم'),
                  Tab(text: 'المتاجر'),
                ],
              ),
            ),
            body: StreamBuilder<List<RatingModel>>(
              stream: RatingService.getAllRatingsStreamForAdmin(limit: 100),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryColor));
                }

                final allRatings = snapshot.data ?? [];

                if (allRatings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star_outline_rounded, size: 64, color: textColor.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'ماكو تقييمات حالياً مسجلة بعد في النظام',
                          style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  );
                }

                // إحصائيات سريعة
                double sumScore = 0;
                int lowRatingCount = 0;
                for (var r in allRatings) {
                  sumScore += r.rating;
                  if (r.rating <= 2.5) lowRatingCount++;
                }
                final avgScore = (sumScore / allRatings.length).toStringAsFixed(1);

                return Column(
                  children: [
                    // شريط الإحصائيات السريعة
                    Container(
                      margin: const EdgeInsets.all(14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('إجمالي التقييمات', '${allRatings.length}', Icons.rate_review_rounded, primaryColor, textColor),
                          _buildStatItem('المعدل العام', ' $avgScore', Icons.star_rounded, const Color(0xFFFFB800), textColor),
                          _buildStatItem('تقييمات منخفضة', '$lowRatingCount', Icons.warning_amber_rounded, Colors.redAccent, textColor),
                        ],
                      ),
                    ),

                    // المحتوى حسب التبويبات
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildRatingsList(allRatings, cardColor, textColor, primaryColor),
                          _buildRatingsList(allRatings.where((r) => r.rating <= 2.5).toList(), cardColor, textColor, primaryColor),
                          _buildRatingsList(allRatings.where((r) => r.targetType == RatingTargetType.captain).toList(), cardColor, textColor, primaryColor),
                          _buildRatingsList(allRatings.where((r) => r.targetType == RatingTargetType.restaurant).toList(), cardColor, textColor, primaryColor),
                          _buildRatingsList(allRatings.where((r) => r.targetType == RatingTargetType.store).toList(), cardColor, textColor, primaryColor),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color, Color textColor) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  Widget _buildRatingsList(List<RatingModel> list, Color cardColor, Color textColor, Color primaryColor) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          'ماكو تقييمات حالياً في هذا القسم',
          style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.5)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final r = list[index];
        final isLow = r.rating <= 2.5;

        Color ratingColor = const Color(0xFF00A896);
        if (r.rating <= 2.0) {
          ratingColor = Colors.redAccent;
        } else if (r.rating <= 3.5) {
          ratingColor = const Color(0xFFFFB800);
        }

        String targetBadge = 'كابتن';
        if (r.targetType == RatingTargetType.restaurant) targetBadge = 'مطعم';
        if (r.targetType == RatingTargetType.store) targetBadge = 'متجر';
        if (r.targetType == RatingTargetType.customer) targetBadge = 'زبون';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLow ? Colors.redAccent.withValues(alpha: 0.3) : Colors.transparent,
              width: isLow ? 1.5 : 0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصف العلوي (المُقيّم، المستهدف، والنجوم)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: ratingColor.withValues(alpha: 0.15),
                    child: Text(
                      '${r.rating}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: ratingColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              r.authorName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'قيم $targetBadge: ${r.targetName}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('yyyy/MM/dd - hh:mm a').format(r.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: textColor.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.reply_rounded, color: Color(0xFF00A896)),
                    tooltip: 'الرد على التقييم',
                    onPressed: () => _showReplyDialog(r),
                  ),
                ],
              ),

              // الوسوم المختارة (Tags)
              if (r.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: r.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor.withValues(alpha: 0.8),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // التعليق النصي إن وجد
              if (r.comment.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  ' "${r.comment}"',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: textColor.withValues(alpha: 0.85),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],

              // رد الإدارة إن وجد
              if (r.reply != null && r.reply!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_rounded, size: 16, color: Color(0xFF00A896)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'رد الإدارة الرسمي:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Color(0xFF00A896),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r.reply!,
                              style: TextStyle(
                                fontSize: 12,
                                color: textColor.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
