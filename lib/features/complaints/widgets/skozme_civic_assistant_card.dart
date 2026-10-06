import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import '../services/complaints_service.dart';

class SkozmeCivicAssistantCard extends StatefulWidget {
  final bool isDark;
  final Function(String category)? onQuickSelectCategory;

  const SkozmeCivicAssistantCard({
    super.key,
    required this.isDark,
    this.onQuickSelectCategory,
  });

  @override
  State<SkozmeCivicAssistantCard> createState() => _SkozmeCivicAssistantCardState();
}

class _SkozmeCivicAssistantCardState extends State<SkozmeCivicAssistantCard> {
  final TextEditingController _promptController = TextEditingController();
  final ComplaintsService _service = ComplaintsService();
  String _aiResponse = '';
  bool _isLoading = false;
  bool _isExpanded = false;

  final List<Map<String, String>> _quickActions = [
    {
      'label': 'صيغلي بلاغ حفرة وتخسف',
      'category': 'حفرة وتخسف بالشارع',
      'prompt': 'صيغلي بلاغ رسمي ومحترم لمديرية البلدية عن وجود حفرة كبيرة وتخسف بالشارع يسبب أضرار لسيارات المواطنين.',
    },
    {
      'label': 'بلاغ كسر أنبوب وماء فايض',
      'category': 'ماء فايض وكسر بوري',
      'prompt': 'صيغلي بلاغ عاجل لدائرة الماء عن كسر بوري ماء رئيسي يفيض بالشارع وهدر للمياه.',
    },
    {
      'label': 'بلاغ وايرات كهرباء نازلة',
      'category': 'وايرات كهرباء ومحولات',
      'prompt': 'صيغلي بلاغ طارئ لدائرة توزيع الكهرباء عن سلك كهرباء وطنية مقطوع نازل للشارع ويشكل خطورة على المارة.',
    },
    {
      'label': 'بلاغ انسداد مجاري ومنهول',
      'category': 'انسداد مجاري وفتحات',
      'prompt': 'صيغلي بلاغ لمديرية المجاري عن انسداد شبكة الصرف وطفح مياه المجاري أو فتحة منهول مكشوفة بدون غطاء.',
    },
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _askSkozme(String prompt, [String? category]) async {
    if (prompt.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _isExpanded = true;
      _promptController.text = prompt;
    });

    if (category != null && widget.onQuickSelectCategory != null) {
      widget.onQuickSelectCategory!(category);
    }

    try {
      final res = await _service.generateCivicReportWithAI(
        issueCategory: category ?? 'بلاغ بلدي',
        location: 'القائم',
        additionalNotes: prompt,
      );
      if (mounted) {
        setState(() {
          _aiResponse = res.isNotEmpty
              ? res
              : "تدلل عيوني! أنا سكوزمي البلدي.. حدد موقع الحفرة أو المشكلة بالخريطة واكتبلي تفاصيلها وهسة أصيغلك بلاغ واضح ومباشر للجهات المسؤولة!";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiResponse = "يا هلا بيك! أنصحك بالتقاط صورة واضحة للمشكلة وتحديد المكان بالخريطة حتى توصل كوادر الصيانة والبلدية للمكان مباشرة وبدون تأخير!";
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
              ? [const Color(0xFF0D2428), const Color(0xFF113238)]
              : [const Color(0xFFE6F7F5), const Color(0xFFD0F0EB)],
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
                    child: const Icon(Icons.support_agent_rounded, color: app_colors.primaryColor, size: 24),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'سكوزمي البلدي - عين مدار',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5.sp,
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
                          'صياغة بلاغات الحفر والماء والمجاري والكهرباء ومتابعتها مع المسؤولين',
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
                  Text(
                    'أدوات صياغة البلاغات بلمسة واحدة:',
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
                        onPressed: () => _askSkozme(action['prompt']!, action['category']),
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
                              hintText: 'اكتب مشكلتك بالشارع أو الحي وهسة سكوزمي يصيغها...',
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
                                    'صيغة البلاغ المقترحة من سكوزمي:',
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
                                      content: Text('تم نسخ نص البلاغ!', style: TextStyle()),
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
