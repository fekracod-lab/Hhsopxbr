import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dalal_alqaim/models/rating_model.dart';
import 'package:dalal_alqaim/services/rating_service.dart';
import 'package:dalal_alqaim/core/app_globals.dart';

/// نافذة التقييم التفاعلية باللهجة العراقية (Interactive Rating BottomSheet)
class RatingBottomSheet extends StatefulWidget {
  final String targetId;
  final RatingTargetType targetType;
  final String targetName;
  final String referenceId; // rideId / orderId
  final String? initialComment;
  final VoidCallback? onSubmitted;

  const RatingBottomSheet({
    super.key,
    required this.targetId,
    required this.targetType,
    required this.targetName,
    required this.referenceId,
    this.initialComment,
    this.onSubmitted,
  });

  /// دالة مساعدة لفتح النافذة في أي مكان بالتطبيق
  static Future<void> show(
    BuildContext context, {
    required String targetId,
    required RatingTargetType targetType,
    required String targetName,
    required String referenceId,
    VoidCallback? onSubmitted,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // التحقق من عدم التقييم المسبق
    final alreadyRated = await RatingService.hasUserRated(
      referenceId: referenceId,
      authorId: user.uid,
    );
    if (alreadyRated) {
      debugPrint('ℹ User has already rated this reference: $referenceId');
      return;
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RatingBottomSheet(
        targetId: targetId,
        targetType: targetType,
        targetName: targetName,
        referenceId: referenceId,
        onSubmitted: onSubmitted,
      ),
    );
  }

  @override
  State<RatingBottomSheet> createState() => _RatingBottomSheetState();
}

class _RatingBottomSheetState extends State<RatingBottomSheet> {
  double _currentRating = 5.0;
  final Set<String> _selectedTags = {};
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  List<String> get _availableTags {
    switch (widget.targetType) {
      case RatingTargetType.captain:
        return [
          'سيارة نظيفة',
          'سياقة هادئة',
          'ملتزم بالوقت',
          'خلوق ومحترم',
          'تكييف شغال',
          'حافظ على الطريق',
          'تعامل راقي',
        ];
      case RatingTargetType.restaurant:
        return [
          'أكل حار وطيب',
          'تغليف نظيف ومحكم',
          'تجهيز سريع',
          'كمية وفيرة',
          'طعم أصيل ومضبوط',
          'نفس طيبة',
        ];
      case RatingTargetType.store:
        return [
          'أغراض أصلية وطازة',
          'أسعار مناسبة',
          'تغليف ممتاز',
          'تجهيز دقيق وسريع',
          'تعامل محترم',
        ];
      case RatingTargetType.customer:
        return [
          'محترم وخلوق',
          'جاهز بوقت الوصول',
          'تحديد دقيق للموقع',
          'تعامل طيب وسلس',
          'كرم وأخلاق عالية',
        ];
    }
  }

  String get _ratingLabelIraqi {
    if (_currentRating >= 5.0) return 'درجة أولى فد شي راقي!';
    if (_currentRating >= 4.0) return 'زين وعاشت إيدك';
    if (_currentRating >= 3.0) return 'عادي ماشي الحال';
    if (_currentRating >= 2.0) return 'يحتاج تحسين وتطوير';
    return 'ما عجبني أبد';
  }

  String get _headerTitleIraqi {
    switch (widget.targetType) {
      case RatingTargetType.captain:
        return 'شلون جان مشوارك ويا الكابتن؟';
      case RatingTargetType.restaurant:
        return 'شلون جانت أكلتك وتجربتك؟';
      case RatingTargetType.store:
        return 'شلون جانت مشترياتك وطلبك؟';
      case RatingTargetType.customer:
        return 'شلون جان تعامل الزبون وياك؟';
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    final success = await RatingService.submitRating(
      targetId: widget.targetId,
      targetType: widget.targetType,
      targetName: widget.targetName,
      authorId: user.uid,
      authorName: user.displayName ?? 'زبون مدار',
      authorRole: currentUserRole ?? 'customer',
      referenceId: widget.referenceId,
      rating: _currentRating,
      tags: _selectedTags.toList(),
      comment: _commentController.text,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF007A87),
            behavior: SnackBarBehavior.floating,
            content: Text(
              'شكراً إلك! تم تسجيل تقييمك بنجاح',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
        widget.onSubmitted?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'صار خلل بسيط بتسجيل التقييم، حاول مرة ثانية',
              style: TextStyle(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, _) {
        final bgColor = isDark ? const Color(0xFF0C2426) : Colors.white;
        final cardColor = isDark ? const Color(0xFF13363A) : const Color(0xFFF3F6F8);
        final textColor = isDark ? Colors.white : const Color(0xFF222222);
        final primaryColor = const Color(0xFF00A896);

        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 24 + bottomInset,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // مقبض السحب
                Container(
                  width: 45,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),

                // العنوان التفاعلي
                Text(
                  _headerTitleIraqi,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),

                // اسم الطرف المقيّم
                if (widget.targetName.isNotEmpty)
                  Text(
                    widget.targetName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: primaryColor,
                    ),
                  ),

                const SizedBox(height: 16),

                // النجوم التفاعلية
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    final isFilled = _currentRating >= starIndex;
                    return IconButton(
                      iconSize: 42,
                      splashRadius: 24,
                      onPressed: () {
                        setState(() {
                          _currentRating = starIndex.toDouble();
                        });
                      },
                      icon: Icon(
                        isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isFilled ? const Color(0xFFFFB800) : textColor.withValues(alpha: 0.25),
                      ),
                    );
                  }),
                ),

                // النص العراقي التعبيري بحسب النجوم
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    key: ValueKey<double>(_currentRating),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _ratingLabelIraqi,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _currentRating >= 4
                            ? const Color(0xFF00A896)
                            : (_currentRating <= 2 ? Colors.redAccent : const Color(0xFFFFB800)),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // الوسوم السريعة (Quick Iraqi Tags)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _availableTags.map((tag) {
                    final isSelected = _selectedTags.contains(tag);
                    return FilterChip(
                      selected: isSelected,
                      label: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : textColor.withValues(alpha: 0.8),
                        ),
                      ),
                      selectedColor: primaryColor,
                      backgroundColor: cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(
                          color: isSelected ? primaryColor : Colors.transparent,
                        ),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.remove(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),

                // حقل الملاحظات الاختياري
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  style: TextStyle(fontSize: 13, color: textColor),
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'اكتب رايك وملاحظاتك بكل صراحة وشفافية...',
                    hintStyle: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.4)),
                    filled: true,
                    fillColor: cardColor,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // زر إرسال التقييم
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'إرسال التقييم',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
