import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import '../services/vacancy_service.dart';

class VacancyApplySheet extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> vacancyData;
  final bool isDark;

  const VacancyApplySheet({
    super.key,
    required this.docId,
    required this.vacancyData,
    required this.isDark,
  });

  @override
  State<VacancyApplySheet> createState() => _VacancyApplySheetState();
}

class _VacancyApplySheetState extends State<VacancyApplySheet> {
  final nameCtr = TextEditingController();
  final phoneCtr = TextEditingController();
  final msgCtr = TextEditingController();
  String selectedExp = 'وسط (سنة إلى 3)';
  bool isGeneratingAI = false;
  bool isSubmitting = false;

  final List<String> _expLevels = [
    'جديد / مبتدئ',
    'وسط (سنة إلى 3)',
    'خبير ومتمكن',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = VacancyService().currentUser;
    if (user != null) {
      final profile = await VacancyService().getUserJobProfile(user.uid);
      if (mounted && profile != null) {
        setState(() {
          if (nameCtr.text.isEmpty) nameCtr.text = profile['name'] ?? user.displayName ?? '';
          if (phoneCtr.text.isEmpty) phoneCtr.text = profile['phone'] ?? '';
        });
      }
    }
  }

  @override
  void dispose() {
    nameCtr.dispose();
    phoneCtr.dispose();
    msgCtr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.vacancyData['job'] ?? widget.vacancyData['jobDetails'] ?? widget.vacancyData['title'] ?? 'الشغل المعلن';
    final company = widget.vacancyData['company'] ?? widget.vacancyData['name'] ?? 'صاحب العمل';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, MediaQuery.of(context).viewInsets.bottom + 20.h),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF0C2428) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 44.w,
                  height: 4.5.h,
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: app_colors.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: const Icon(Icons.send_rounded, color: app_colors.primaryColor, size: 22),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تقديم على الشغل',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp,
                            color: widget.isDark ? Colors.white : const Color(0xFF0A2828),
                          ),
                        ),
                        Text(
                          '$title • $company',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: widget.isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Form fields
              _field(nameCtr, 'اسمك الكريم', Icons.person_rounded),
              SizedBox(height: 10.h),
              _field(
                phoneCtr,
                'رقم الواتساب للتواصل (مثال: 0770xxxxxxx)',
                Icons.phone_rounded,
                keyboard: TextInputType.phone,
              ),
              SizedBox(height: 12.h),

              Text(
                'مستوى خبرتك:',
                style: TextStyle(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              SizedBox(height: 6.h),
              Wrap(
                spacing: 6.w,
                children: _expLevels.map((e) {
                  final sel = selectedExp == e;
                  return ChoiceChip(
                    label: Text(e),
                    selected: sel,
                    onSelected: (_) => setState(() => selectedExp = e),
                    selectedColor: app_colors.primaryColor,
                    backgroundColor: widget.isDark ? const Color(0xFF113036) : Colors.grey.shade100,
                    labelStyle: TextStyle(
                      fontSize: 10.5.sp,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      color: sel ? Colors.white : (widget.isDark ? Colors.white70 : Colors.black87),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  );
                }).toList(),
              ),
              SizedBox(height: 12.h),

              _field(
                msgCtr,
                'كلمتين لصاحب الشغل (خبرتك، أوقاتك، ليش مناسب للشغل)...',
                Icons.chat_bubble_outline_rounded,
                maxLines: 3,
              ),
              SizedBox(height: 18.h),

              // Submit Button
              InkWell(
                onTap: isSubmitting ? null : _submit,
                borderRadius: BorderRadius.circular(14.r),
                child: Container(
                  height: 48.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF047857)],
                    ),
                    borderRadius: BorderRadius.circular(14.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                        )
                      : Text(
                          'دز طلب التقديم هسة',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5.sp,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 6.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctr,
    String hint,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF113036) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: widget.isDark ? Colors.white12 : Colors.grey.shade300,
        ),
      ),
      child: TextField(
        controller: ctr,
        keyboardType: keyboard,
        maxLines: maxLines,
        cursorColor: app_colors.primaryColor,
        style: TextStyle(
          fontSize: 12.5.sp,
          fontWeight: FontWeight.w600,
          color: widget.isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 11.sp,
            color: widget.isDark ? Colors.white38 : Colors.black45,
          ),
          prefixIcon: Icon(icon, color: app_colors.primaryColor, size: 18.r),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (nameCtr.text.trim().isEmpty || phoneCtr.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة اسمك ورقم الواتساب يا غالي', style: TextStyle()),
          backgroundColor: app_colors.primaryColor,
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      await VacancyService().submitApplication(
        vacancyId: widget.docId,
        applicantName: nameCtr.text.trim(),
        applicantPhone: phoneCtr.text.trim(),
        applicantExp: selectedExp,
        message: msgCtr.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال طلب تقديمك لصاحب الشغل بنجاح!', style: TextStyle()),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء التقديم: $e', style: const TextStyle()),
            backgroundColor: app_colors.primaryColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }
}
