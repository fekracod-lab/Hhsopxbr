import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import '../services/vacancy_service.dart';

class VacancyAddSheet extends StatefulWidget {
  final bool isDark;
  final String type; // 'employer' or 'seeker'

  const VacancyAddSheet({
    super.key,
    required this.isDark,
    required this.type,
  });

  @override
  State<VacancyAddSheet> createState() => _VacancyAddSheetState();
}

class _VacancyAddSheetState extends State<VacancyAddSheet> {
  int step = 0;
  bool isPublishing = false;
  bool isGeneratingAI = false;

  final nameCtr = TextEditingController();
  final jobCtr = TextEditingController();
  final phoneCtr = TextEditingController();
  final notesCtr = TextEditingController();
  final salaryCtr = TextEditingController();

  final List<String> _tags = [
    'كاشير ومبيعات',
    'مطاعم وضيافة',
    'سواق دليفري',
    'برمجة وتقنية',
    'تدريس وخصوصي',
    'خلفات وصيانة',
    'محاسبة وإدارة',
    'صيدليات وطبية',
    'حراسة وأمنية',
    'مهن أخرى',
  ];

  final Map<String, String> _tagEmojis = {
    'كاشير ومبيعات': '',
    'مطاعم وضيافة': '',
    'سواق دليفري': '',
    'برمجة وتقنية': '',
    'تدريس وخصوصي': '',
    'خلفات وصيانة': '',
    'محاسبة وإدارة': '',
    'صيدليات وطبية': '',
    'حراسة وأمنية': '',
    'مهن أخرى': '',
  };

  static const List<String> _governorates = [
    'بغداد',
    'الأنبار',
    'البصرة',
    'أربيل',
    'نينوى (الموصل)',
    'كركوك',
    'كربلاء المقدسة',
    'النجف الأشرف',
    'بابل (الحلة)',
    'ديالى',
    'صلاح الدين',
    'واسط',
    'ميسان',
    'ذي قار',
    'المثنى',
    'الديوانية',
    'دهوك',
    'السليمانية',
  ];

  static List<String> _getCitiesForGov(String gov) {
    switch (gov) {
      case 'الأنبار':
        return ['القائم', 'الرمادي', 'الفلوجة', 'هيت', 'حديثة', 'عانة', 'راوة', 'الرطبة', 'الكرمة', 'الخالدية', 'حصيبة', 'الرمانة', 'العبيدي'];
      case 'بغداد':
        return ['الكرخ', 'الرصافة', 'المنصور', 'الكرادة', 'الأعظمية', 'الكاظمية', 'الدورة', 'الشعب', 'مدينة الصدر', 'السيدية', 'العامرية', 'الغزالية'];
      case 'البصرة':
        return ['المركز (العشار)', 'الجبيلة', 'الجمهورية', 'القرنة', 'الزبير', 'شط العرب', 'أبي الخصيب', 'الفاو'];
      case 'نينوى (الموصل)':
        return ['الموصل الأيمن', 'الموصل الأيسر', 'تلعفر', 'الحمدانية', 'سنجار'];
      case 'أربيل':
        return ['المركز', 'عنكاوا', 'سوران', 'شقلاوة', 'كويسنجق'];
      case 'كربلاء المقدسة':
        return ['المركز', 'حي الحسين', 'حي العباس', 'الهندية', 'عين التمر'];
      case 'النجف الأشرف':
        return ['المدينة القديمة', 'الكوفة', 'حي الغدير', 'حي الأمير', 'المناذرة'];
      default:
        return ['المركز', 'حي المعلمين', 'السوق الكبير', 'حي الزهور'];
    }
  }

  final List<String> _workTypes = [
    'دوام كامل (يومي)',
    'نص وقت (مسائي/صباحي)',
    'شغل أونلاين (عن بعد)',
    'شغل باليومية / بالقطعة',
  ];

  final Map<String, String> _workTypeIcons = {
    'دوام كامل (يومي)': '',
    'نص وقت (مسائي/صباحي)': '',
    'شغل أونلاين (عن بعد)': '',
    'شغل باليومية / بالقطعة': '',
  };

  final List<String> _expLevels = [
    'جديد / مبتدئ',
    'وسط (سنة إلى 3)',
    'خبير ومتمكن',
  ];

  late String selectedTag;
  String selectedExp = 'جديد / مبتدئ';
  String selectedGovernorate = 'الأنبار';
  String selectedCity = 'القائم';
  String selectedWorkType = 'دوام كامل (يومي)';

  @override
  void initState() {
    super.initState();
    selectedTag = _tags[0];
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
          if (jobCtr.text.isEmpty && profile['title'] != null && profile['title'] != 'باحث عن عمل') {
            jobCtr.text = profile['title'];
          }
          if (profile['city'] != null) {
            selectedCity = profile['city'];
          }
          if (profile['governorate'] != null) {
            selectedGovernorate = profile['governorate'];
          }
        });
      }
    }
  }

  @override
  void dispose() {
    nameCtr.dispose();
    jobCtr.dispose();
    phoneCtr.dispose();
    notesCtr.dispose();
    salaryCtr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSeeker = widget.type == 'seeker';
    final accent = isSeeker ? const Color(0xFF10B981) : app_colors.primaryColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16.h,
          left: 20.w,
          right: 20.w,
          top: 16.h,
        ),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF0C2428) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle Bar
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
              SizedBox(height: 14.h),

              // Steps Indicator
              Row(
                children: [
                  _stepDot(accent, step >= 0, '1'),
                  Expanded(
                    child: Container(
                      height: 2.h,
                      color: step >= 1 ? accent : (widget.isDark ? Colors.white12 : Colors.grey.shade200),
                    ),
                  ),
                  _stepDot(accent, step >= 1, '2'),
                ],
              ),
              SizedBox(height: 14.h),

              // Sheet Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Icon(
                      isSeeker ? Icons.person_search_rounded : Icons.business_center_rounded,
                      color: accent,
                      size: 22.r,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSeeker ? 'إضافة طلب عمل بسوق الكفاءات' : 'إضافة فرصة عمل شاغرة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5.sp,
                            color: widget.isDark ? Colors.white : const Color(0xFF0A2828),
                          ),
                        ),
                        Text(
                          step == 0 ? 'الخطوة 1: المعلومات ورقم الواتساب' : 'الخطوة 2: المحافظة والتخصص والراتب',
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            color: widget.isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: step == 0 ? _buildStepZero(isSeeker) : _buildStepOne(isSeeker, accent),
              ),
              SizedBox(height: 18.h),

              // Navigation Action Buttons
              Row(
                children: [
                  if (step > 0)
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => step = 0),
                        borderRadius: BorderRadius.circular(14.r),
                        child: Container(
                          height: 48.h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: widget.isDark ? Colors.white10 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Text(
                            'السابق',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                              color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (step > 0) SizedBox(width: 10.w),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: isPublishing ? null : () => _onNextOrPublish(isSeeker),
                      borderRadius: BorderRadius.circular(14.r),
                      child: Container(
                        height: 48.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accent, accent.withValues(alpha: 0.85)],
                          ),
                          borderRadius: BorderRadius.circular(14.r),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: isPublishing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                              )
                            : Text(
                                step == 0 ? 'التالي (الموقع والراتب) ⬅' : 'انشر الإعلان هسة',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.sp,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 0: Basic Contact Info ──
  Widget _buildStepZero(bool isSeeker) {
    return Column(
      key: const ValueKey(0),
      children: [
        _field(
          nameCtr,
          isSeeker ? 'اسمك الكريم' : 'اسم المحل / الشركة أو صاحب العمل',
          isSeeker ? Icons.person_rounded : Icons.storefront_rounded,
        ),
        SizedBox(height: 12.h),
        _field(
          jobCtr,
          isSeeker ? 'المهنة أو التخصص (مثال: كاشير، سائق، خلفة، محاسب)' : 'المسمى الوظيفي المطلوب (مثال: مطلوب كاشير، مندوب مبيعات)',
          Icons.work_rounded,
        ),
        SizedBox(height: 12.h),
        _field(
          phoneCtr,
          'رقم الواتساب للتواصل المباشر (مثال: 0770xxxxxxx)',
          Icons.phone_rounded,
          keyboard: TextInputType.phone,
        ),
      ],
    );
  }

  // ── Step 1: Work Specifics & Details ──
  Widget _buildStepOne(bool isSeeker, Color accent) {
    final availableCities = _getCitiesForGov(selectedGovernorate);

    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Governorate & City ──
        Text(
          'المحافظة والمدينة بالعراق 🇮🇶:',
          style: TextStyle(
            fontSize: 11.5.sp,
            fontWeight: FontWeight.bold,
            color: widget.isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        SizedBox(height: 6.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _governorates.map((gov) {
              final isSel = selectedGovernorate == gov;
              return Padding(
                padding: EdgeInsets.only(left: 6.w),
                child: ChoiceChip(
                  label: Text(gov),
                  selected: isSel,
                  onSelected: (_) {
                    setState(() {
                      selectedGovernorate = gov;
                      final cities = _getCitiesForGov(gov);
                      selectedCity = cities.isNotEmpty ? cities.first : gov;
                    });
                  },
                  selectedColor: accent,
                  backgroundColor: widget.isDark ? const Color(0xFF113036) : Colors.grey.shade100,
                  labelStyle: TextStyle(
                    fontSize: 10.5.sp,
                    color: isSel ? Colors.white : (widget.isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: 6.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: availableCities.map((c) {
              final isSel = selectedCity == c;
              return Padding(
                padding: EdgeInsets.only(left: 6.w),
                child: ActionChip(
                  label: Text(c),
                  backgroundColor: isSel ? accent.withValues(alpha: 0.2) : (widget.isDark ? const Color(0xFF113036) : Colors.grey.shade100),
                  side: BorderSide(color: isSel ? accent : Colors.transparent),
                  labelStyle: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    color: isSel ? accent : (widget.isDark ? Colors.white70 : Colors.black87),
                  ),
                  onPressed: () => setState(() => selectedCity = c),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: 12.h),

        _field(
          salaryCtr,
          isSeeker ? 'الراتب المتوقع أو اليومية (مثال: 600 ألف د.ع، 25 ألف يومية)' : 'الراتب المعروض (مثال: 700 ألف د.ع، يومية، حسب الاتفاق)',
          Icons.payments_rounded,
        ),
        SizedBox(height: 12.h),

        // Tag / Category Chips
        Text(
          'تصنيف المهنة / المجال:',
          style: TextStyle(
            fontSize: 11.5.sp,
            fontWeight: FontWeight.bold,
            color: widget.isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        SizedBox(height: 6.h),
        Wrap(
          spacing: 6.w,
          runSpacing: 6.h,
          children: _tags.map((t) {
            final sel = selectedTag == t;
            return ChoiceChip(
              label: Text('${_tagEmojis[t] ?? ''} $t'),
              selected: sel,
              onSelected: (_) => setState(() => selectedTag = t),
              selectedColor: accent,
              backgroundColor: widget.isDark ? const Color(0xFF113036) : Colors.grey.shade100,
              labelStyle: TextStyle(
                fontSize: 10.5.sp,
                color: sel ? Colors.white : (widget.isDark ? Colors.white70 : Colors.black87),
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            );
          }).toList(),
        ),
        SizedBox(height: 12.h),

        // Experience Level
        Text(
          'مستوى الخبرة المطلوبة:',
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
              selectedColor: const Color(0xFF8B5CF6),
              backgroundColor: widget.isDark ? const Color(0xFF113036) : Colors.grey.shade100,
              labelStyle: TextStyle(
                fontSize: 10.5.sp,
                color: sel ? Colors.white : (widget.isDark ? Colors.white70 : Colors.black87),
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            );
          }).toList(),
        ),
        SizedBox(height: 12.h),

        // Work Type Selector
        Text(
          'نوع الدوام :',
          style: TextStyle(
            fontSize: 11.5.sp,
            fontWeight: FontWeight.bold,
            color: widget.isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        SizedBox(height: 6.h),
        Wrap(
          spacing: 6.w,
          runSpacing: 6.h,
          children: _workTypes.map((w) {
            final sel = selectedWorkType == w;
            return ChoiceChip(
              label: Text('${_workTypeIcons[w] ?? ''} $w'),
              selected: sel,
              onSelected: (_) => setState(() => selectedWorkType = w),
              selectedColor: const Color(0xFFEC4899),
              backgroundColor: widget.isDark ? const Color(0xFF113036) : Colors.grey.shade100,
              labelStyle: TextStyle(
                fontSize: 10.5.sp,
                color: sel ? Colors.white : (widget.isDark ? Colors.white70 : Colors.black87),
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            );
          }).toList(),
        ),
        SizedBox(height: 12.h),

        // Notes
        _field(
          notesCtr,
          'ملاحظات وشروط إضافية (أوقات الدوام، الحي/الشارع، الخبرات المطلوبة)...',
          Icons.notes_rounded,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _stepDot(Color accent, bool active, String label) {
    return Container(
      width: 26.r,
      height: 26.r,
      decoration: BoxDecoration(
        color: active ? accent : (widget.isDark ? Colors.white10 : Colors.grey.shade200),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11.sp,
          color: active ? Colors.white : (widget.isDark ? Colors.white38 : Colors.grey.shade500),
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

  Future<void> _onNextOrPublish(bool isSeeker) async {
    if (step == 0) {
      if (nameCtr.text.trim().isEmpty) {
        _showToast('يرجى كتابة الاسم يا غالي');
        return;
      }
      if (jobCtr.text.trim().isEmpty) {
        _showToast('يرجى تحديد المهنة أو التخصص');
        return;
      }
      if (phoneCtr.text.trim().isEmpty) {
        _showToast('يرجى إدخال رقم الواتساب للتواصل');
        return;
      }
      setState(() => step = 1);
    } else {
      // Publish
      setState(() => isPublishing = true);
      try {
        await VacancyService().addVacancy(
          company: isSeeker ? nameCtr.text.trim() : nameCtr.text.trim(),
          name: nameCtr.text.trim(),
          jobDetails: jobCtr.text.trim(),
          phone: phoneCtr.text.trim(),
          notes: notesCtr.text.trim(),
          type: widget.type,
          tags: [selectedTag],
          governorate: selectedGovernorate,
          city: selectedCity,
          salary: salaryCtr.text.trim().isNotEmpty ? salaryCtr.text.trim() : null,
          workType: selectedWorkType,
          experience: selectedExp,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isSeeker ? 'تم نشر طلب وظيفتك بسوق الكفاءات بنجاح!' : 'تم نشر فرصة العمل بنجاح!',
                style: const TextStyle(),
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          _showToast('فشل النشر: $e');
        }
      } finally {
        if (mounted) setState(() => isPublishing = false);
      }
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle()),
        backgroundColor: app_colors.primaryColor,
      ),
    );
  }
}
