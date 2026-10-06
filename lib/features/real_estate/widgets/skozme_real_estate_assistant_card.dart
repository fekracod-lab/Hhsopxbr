import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import '../services/real_estate_service.dart';

class SkozmeRealEstateAssistantCard extends StatefulWidget {
  final bool isDark;
  final Function(String query)? onFilterProperty;

  const SkozmeRealEstateAssistantCard({
    super.key,
    required this.isDark,
    this.onFilterProperty,
  });

  @override
  State<SkozmeRealEstateAssistantCard> createState() => _SkozmeRealEstateAssistantCardState();
}

class _SkozmeRealEstateAssistantCardState extends State<SkozmeRealEstateAssistantCard> {
  final TextEditingController _promptController = TextEditingController();
  final RealEstateService _service = RealEstateService();
  String _aiResponse = '';
  bool _isLoading = false;
  bool _isExpanded = false;

  final List<Map<String, String>> _quickActions = [
    {
      'label': 'صيغلي إعلان بيع بيت',
      'prompt': 'صيغلي إعلان جذاب لبيع بيت طابو صرف مساحة 200 متر بالقائم مع الخدمات كاملة.',
    },
    {
      'label': 'شكد أسعار المتر بالقائم؟',
      'prompt': 'كلي شكد متوسط أسعار المتر والأراضي السكنية والتجارية بمناطق القائم والأنبار؟',
    },
    {
      'label': 'شروط كتابة عقد إيجار',
      'prompt': 'شنو أهم الشروط والبنود اللي لازم أكتبها بعقد إيجار شقة أو بيت بالعراق لحفظ حقوق الطرفين؟',
    },
    {
      'label': 'نصائح قبل شراء أي عقار',
      'prompt': 'شنو أهم النصائح القانونية والفنية قبل ما اشتري بيت أو قطعة أرض بالقائم؟',
    },
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _askSkozme(String prompt) async {
    if (prompt.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _isExpanded = true;
      _promptController.text = prompt;
    });

    try {
      final res = await _service.generateRealEstateTextWithAI(prompt: prompt);
      if (mounted) {
        setState(() {
          _aiResponse = res.isNotEmpty
              ? res
              : "تدلل عيوني! أنا سكوزمي مستشارك العقاري بمدار.. كلي شنو نوع العقار اللي تدور عليه أو حابب تعلن عنه وهسة أساعدك فوراً!";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiResponse = "يا هلا بيك! أنصحك دائماً بالتأكد من سند الطابو ومخطط الإفراز ورقم القطعة قبل الشراء، وأنا وياك خطوة بخطوة!";
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
              ? [const Color(0xFF0D2529), const Color(0xFF103338)]
              : [const Color(0xFFE8F6F4), const Color(0xFFD4EFEA)],
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
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: app_colors.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: const Icon(Icons.maps_home_work_rounded, color: app_colors.primaryColor, size: 24),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'سكوزمي المستشار العقاري',
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
                                color: app_colors.primaryColor,
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                'ذكاء اصطناعي',
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'صياغة إعلانات بيوت جذابة، تقدير الأسعار، واستشارات الطابو بالعراقي',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: app_colors.primaryColor,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          if (_isExpanded) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: Divider(color: isDark ? Colors.white10 : Colors.grey.shade300, height: 1),
            ),
            Padding(
              padding: EdgeInsets.all(14.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions Chips
                  Text(
                    'أدوات عقارية جاهزة بلمسة واحدة:',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: _quickActions.map((action) {
                      return ActionChip(
                        label: Text(
                          action['label']!,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0C2428),
                          ),
                        ),
                        backgroundColor: isDark ? const Color(0xFF143B40) : Colors.white,
                        side: BorderSide(
                          color: app_colors.primaryColor.withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        onPressed: () => _askSkozme(action['prompt']!),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 12.h),

                  // Custom Prompt Input
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF08181A) : Colors.white,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: app_colors.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _promptController,
                            cursorColor: app_colors.primaryColor,
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'اسأل سكوزمي عن أي عقار، بيت، سعر المتر، أو اكتبلي إعلان...',
                              hintStyle: TextStyle(
                                fontSize: 11.sp,
                                color: isDark ? Colors.white38 : Colors.grey.shade500,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                            ),
                            onSubmitted: _askSkozme,
                          ),
                        ),
                        IconButton(
                          icon: _isLoading
                              ? SizedBox(
                                  width: 18.r,
                                  height: 18.r,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: app_colors.primaryColor,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, color: app_colors.primaryColor),
                          onPressed: _isLoading ? null : () => _askSkozme(_promptController.text),
                        ),
                      ],
                    ),
                  ),

                  // AI Response Box
                  if (_aiResponse.isNotEmpty) ...[
                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF091F22) : Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: app_colors.primaryColor.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.auto_awesome, color: app_colors.primaryColor, size: 16),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'جواب سكوزمي العقاري:',
                                    style: TextStyle(
                                      fontSize: 11.5.sp,
                                      fontWeight: FontWeight.bold,
                                      color: app_colors.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16, color: app_colors.primaryColor),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _aiResponse));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم نسخ الرد بنجاح!', style: TextStyle()),
                                      backgroundColor: app_colors.primaryColor,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            _aiResponse,
                            style: TextStyle(
                              fontSize: 12.sp,
                              height: 1.5,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
