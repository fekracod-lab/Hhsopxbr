import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import '../services/vacancy_service.dart';

class SkozmeJobAssistantCard extends StatefulWidget {
  final bool isDark;
  final Function(String query)? onFilterJob;

  const SkozmeJobAssistantCard({
    super.key,
    required this.isDark,
    this.onFilterJob,
  });

  @override
  State<SkozmeJobAssistantCard> createState() => _SkozmeJobAssistantCardState();
}

class _SkozmeJobAssistantCardState extends State<SkozmeJobAssistantCard> {
  final VacancyService _vacancyService = VacancyService();
  final TextEditingController _promptController = TextEditingController();
  bool _isLoading = false;
  String? _aiResponse;
  bool _isExpanded = false;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _askSkozme(String prompt) async {
    if (prompt.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _isExpanded = true;
      _aiResponse = null;
    });

    try {
      final user = _vacancyService.currentUser;
      Map<String, dynamic>? profile;
      if (user != null) {
        profile = await _vacancyService.getUserJobProfile(user.uid);
      }

      final contextPrompt = """أنت "سكوزمي"، المستشار المهني والتوظيفي الذكي في تطبيق"مدار" لمدينة القائم ومحافظة الأنبار والعراق.
تحدث دائماً باللهجة العراقية المحترمة واللطيفة والمشجعة.
معلومات المستخدم إن وجدت:
الاسم: ${profile?['name'] ?? user?.displayName ?? 'مستخدم مدار'}
المسمى: ${profile?['title'] ?? 'باحث عن عمل'}
المدينة: ${profile?['city'] ?? 'القائم'}
المهارات: ${(profile?['skills'] as List?)?.join(', ') ?? 'تواصل والتزام'}

سؤال أو طلب المستخدم:
$prompt

جاوب بأسلوب عراقي عملي ومباشر ومفيد جداً وبدون إطالة مفرطة مع نقاط واضحة.
""";

      final res = await _vacancyService.generateWithAI(contextPrompt);
      if (mounted) {
        setState(() {
          _aiResponse = res.isNotEmpty
              ? res
              : "تدلل يا غالي! أنا سكوزمي مستشارك المهني بمدار. كلي شنو تخصصك أو شنو نوع الوظيفة اللي تدور عليها بالقائم وهسة أساعدك ترتب سيرة ذاتية ورسالة تقديم تخبل!";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiResponse =
              "يا هلا بيك! أنا وياك سكوزمي.. انصحك ترتب بروفايلك المهني وتضيف مهاراتك ورقمك حتى أصحاب العمل والمتاجر بالقائم يتواصلون وياك مباشرة!";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0C2428), const Color(0xFF0F3237)]
              : [const Color(0xFFE6F7F5), const Color(0xFFD3F2EE)],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: app_colors.primaryColor.withValues(alpha: isDark ? 0.35 : 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: app_colors.primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(20.r),
            child: Padding(
              padding: EdgeInsets.all(14.r),
              child: Row(
                children: [
                  Container(
                    width: 42.r,
                    height: 42.r,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [app_colors.primaryColor, app_colors.accentColor],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: app_colors.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'سكوزمي المستشار المهني',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                                color: isDark ? Colors.white : const Color(0xFF0C2428),
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: app_colors.primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                'ذكاء مدار',
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.bold,
                                  color: app_colors.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'اكتب سيرتك الذاتية، رتب رسالة التقديم، أو صيغ إعلان وظيفة بالعراقي',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: app_colors.primaryColor,
                    size: 24.r,
                  ),
                ],
              ),
            ),
          ),

          // Quick Action Pills
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickPill(
                    icon: Icons.edit_note_rounded,
                    label: 'اكتبلي نبذة عني',
                    onTap: () {
                      _promptController.text = 'اكتبلي نبذة مهنية وسيرة ذاتية مختصرة تناسب بروفايلي للتقديم على وظيفة';
                      _askSkozme(_promptController.text);
                    },
                    isDark: isDark,
                  ),
                  SizedBox(width: 8.w),
                  _buildQuickPill(
                    icon: Icons.send_rounded,
                    label: 'رسالة تقديم واتساب',
                    onTap: () {
                      _promptController.text = 'صيغلي رسالة تقديم محترمة أرسلها لصاحب العمل على الواتساب';
                      _askSkozme(_promptController.text);
                    },
                    isDark: isDark,
                  ),
                  SizedBox(width: 8.w),
                  _buildQuickPill(
                    icon: Icons.campaign_rounded,
                    label: 'صيغلي إعلان وظيفة',
                    onTap: () {
                      _promptController.text = 'أنا صاحب محل/شركة وأريد أكتب إعلان لطلب موظفين براتب وساعات دوام بالقائم';
                      _askSkozme(_promptController.text);
                    },
                    isDark: isDark,
                  ),
                  SizedBox(width: 8.w),
                  _buildQuickPill(
                    icon: Icons.tips_and_updates_rounded,
                    label: 'نصائح للمقابلة',
                    onTap: () {
                      _promptController.text = 'شنو أهم النصائح لمقابلة عمل ناجحة والاتفاق على الراتب بالعراقي؟';
                      _askSkozme(_promptController.text);
                    },
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 10.h),

          // Expanded interactive area
          if (_isExpanded) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Response Box
                  if (_isLoading)
                    Container(
                      padding: EdgeInsets.all(14.r),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF07191B) : Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18.r,
                            height: 18.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: app_colors.primaryColor,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            'سكوزمي يفكر ويرتبلك الإجابة بالعراقي...',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_aiResponse != null)
                    Container(
                      padding: EdgeInsets.all(14.r),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF07191B) : Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: app_colors.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'رد سكوزمي المهني :',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.sp,
                                  color: app_colors.primaryColor,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                color: app_colors.primaryColor,
                                tooltip: 'نسخ النص',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _aiResponse!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم نسخ النص بنجاح!', style: TextStyle()),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          SelectableText(
                            _aiResponse!,
                            style: TextStyle(
                              fontSize: 13.sp,
                              height: 1.6,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: 10.h),

                  // Prompt input
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF081C1E) : Colors.white,
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(
                        color: app_colors.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 14.w),
                        Expanded(
                          child: TextField(
                            controller: _promptController,
                            cursorColor: app_colors.primaryColor,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'اسأل سكوزمي عن أي شي يخص الوظائف...',
                              hintStyle: TextStyle(
                                fontSize: 12.sp,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                            ),
                            onSubmitted: _askSkozme,
                          ),
                        ),
                        IconButton(
                          icon: Container(
                            padding: EdgeInsets.all(6.r),
                            decoration: const BoxDecoration(
                              color: app_colors.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_upward_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          onPressed: () => _askSkozme(_promptController.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF103338) : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: app_colors.primaryColor.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0C2428),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
