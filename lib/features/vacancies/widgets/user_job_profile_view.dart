import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import '../services/vacancy_service.dart';

class UserJobProfileView extends StatefulWidget {
  final bool isDark;

  const UserJobProfileView({super.key, required this.isDark});

  @override
  State<UserJobProfileView> createState() => _UserJobProfileViewState();
}

class _UserJobProfileViewState extends State<UserJobProfileView> {
  final VacancyService _service = VacancyService();
  bool _isGeneratingBio = false;

  Future<void> _generateBio({
    required String name,
    required String title,
    required String experience,
    required List<String> skills,
    required String city,
    required String phone,
    required bool isAvailable,
    required String expectedSalary,
  }) async {
    setState(() => _isGeneratingBio = true);
    final newBio = await _service.generateIraqiBioWithAI(
      name: name,
      title: title,
      experience: experience,
      skills: skills,
      city: city,
    );
    await _service.saveUserJobProfile(
      name: name,
      title: title,
      phone: phone,
      city: city,
      experience: experience,
      skills: skills,
      bio: newBio,
      isAvailable: isAvailable,
      expectedSalary: expectedSalary,
    );
    if (!mounted) return;
    setState(() => _isGeneratingBio = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم توليد النبذة المهنية بواسطة سكوزمي وحفظها بنجاح!', style: TextStyle()),
        backgroundColor: app_colors.primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _service.currentUser;
    final isDark = widget.isDark;

    if (user == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_person_rounded, size: 64.r, color: app_colors.primaryColor),
              SizedBox(height: 16.h),
              Text(
                'سجل دخولك لتفعيل ملفك المهني',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'أنشئ سيرتك الذاتية، ودع أصحاب العمل والشركات يتواصلون وياك مباشرة!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              SizedBox(height: 20.h),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                icon: const Icon(Icons.login_rounded, color: Colors.white),
                label: const Text('تسجيل الدخول هسة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: app_colors.primaryColor,
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _service.getUserJobProfileStream(user.uid),
      builder: (context, snapshot) {
        final profile = snapshot.data?.data() ?? {};
        final name = profile['name'] ?? user.displayName ?? 'مستخدم مدار';
        final title = profile['title'] ?? 'باحث عن عمل';
        final phone = profile['phone'] ?? user.phoneNumber ?? '';
        final city = profile['city'] ?? 'القائم';
        final experience = profile['experience'] ?? 'متوسط';
        final skills = List<String>.from(profile['skills'] ?? ['التزام بالمواعيد', 'العمل بروح الفريق']);
        final bio = profile['bio'] ?? '';
        final isAvailable = profile['isAvailable'] ?? true;
        final expectedSalary = profile['expectedSalary'] ?? '';

        return SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Main Profile Glass Card ──
              Container(
                padding: EdgeInsets.all(18.r),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF0F2E33), const Color(0xFF143B41)]
                        : [Colors.white, const Color(0xFFF1F8F8)],
                  ),
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(
                    color: app_colors.primaryColor.withValues(alpha: isDark ? 0.3 : 0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: app_colors.primaryColor.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32.r,
                          backgroundColor: app_colors.primaryColor.withValues(alpha: 0.2),
                          backgroundImage: (user.photoURL != null && user.photoURL!.isNotEmpty)
                              ? NetworkImage(user.photoURL!)
                              : null,
                          child: (user.photoURL == null || user.photoURL!.isEmpty)
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24.sp,
                                    color: app_colors.primaryColor,
                                  ),
                                )
                              : null,
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16.sp,
                                        color: isDark ? Colors.white : const Color(0xFF0A2828),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: isAvailable
                                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                          : Colors.grey.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20.r),
                                      border: Border.all(
                                        color: isAvailable ? const Color(0xFF10B981) : Colors.grey,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 4.r,
                                          backgroundColor: isAvailable ? const Color(0xFF10B981) : Colors.grey,
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          isAvailable ? 'متاح للعمل فوراً' : 'غير متاح حالياً',
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.bold,
                                            color: isAvailable ? const Color(0xFF10B981) : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: app_colors.primaryColor,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Row(
                                children: [
                                  Icon(Icons.location_on_rounded, size: 14.sp, color: Colors.grey),
                                  SizedBox(width: 4.w),
                                  Text(
                                    city,
                                    style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                                  ),
                                  SizedBox(width: 12.w),
                                  Icon(Icons.workspace_premium_rounded, size: 14.sp, color: Colors.grey),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'خبرة: $experience',
                                    style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16.h),
                    const Divider(height: 1),
                    SizedBox(height: 12.h),

                    // Quick Action: Edit Profile
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (phone.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.phone_iphone_rounded, size: 16.sp, color: app_colors.primaryColor),
                              SizedBox(width: 6.w),
                              Text(
                                phone,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            'لم يتم تحديد رقم هاتف',
                            style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                          ),
                        ElevatedButton.icon(
                          onPressed: () => _showEditProfileSheet(
                            context: context,
                            initialName: name,
                            initialTitle: title,
                            initialPhone: phone,
                            initialCity: city,
                            initialExp: experience,
                            initialSkills: skills,
                            initialBio: bio,
                            initialAvailable: isAvailable,
                            initialSalary: expectedSalary,
                            isDark: isDark,
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                          label: const Text('تعديل الملف المهني', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: app_colors.primaryColor,
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // ── Bio & Skozme AI Generator ──
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF10282C) : Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.description_rounded, size: 18.sp, color: app_colors.primaryColor),
                            SizedBox(width: 8.w),
                            Text(
                              'النبذة المهنية والسيرة الذاتية',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                                color: isDark ? Colors.white : const Color(0xFF0A2828),
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: _isGeneratingBio
                              ? null
                              : () => _generateBio(
                                  name: name,
                                  title: title,
                                  experience: experience,
                                  skills: skills,
                                  city: city,
                                  phone: phone,
                                  isAvailable: isAvailable,
                                  expectedSalary: expectedSalary,
                                ),
                          icon: _isGeneratingBio
                              ? SizedBox(width: 14.r, height: 14.r, child: const CircularProgressIndicator(strokeWidth: 2, color: app_colors.primaryColor))
                              : const Icon(Icons.auto_awesome_rounded, size: 15, color: app_colors.primaryColor),
                          label: Text(
                            'توليد بسكوزمي',
                            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: app_colors.primaryColor),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      bio.isNotEmpty
                          ? bio
                          : 'لم تقم بكتابة نبذة مهنية بعد. اضغط على "توليد بسكوزمي" ليقوم سكوزمي بكتابة نبذة احترافية عنك باللهجة العراقية!',
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        height: 1.6,
                        color: bio.isNotEmpty
                            ? (isDark ? Colors.white70 : Colors.black87)
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // ── Skills Chips ──
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF10282C) : Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.stars_rounded, size: 18.sp, color: app_colors.primaryColor),
                        SizedBox(width: 8.w),
                        Text(
                          'المهارات والخبرات المحددة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                            color: isDark ? Colors.white : const Color(0xFF0A2828),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: skills.map((skill) {
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: app_colors.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: app_colors.primaryColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            ' $skill',
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0C2428),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // ── My Published Jobs & Applications Stream ──
              Text(
                'إعلاناتي والوظائف التي نشرتها',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15.sp,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: 10.h),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('vacancies')
                    .where('createdBy', isEqualTo: user.uid)
                    .snapshots(),
                builder: (context, myJobsSnap) {
                  if (myJobsSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: app_colors.primaryColor));
                  }
                  final docs = myJobsSnap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Container(
                      padding: EdgeInsets.all(20.r),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF10282C) : Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Center(
                        child: Text(
                          'لم تقم بنشر أي إعلان وظيفة بعد',
                          style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => SizedBox(height: 10.h),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final jobTitle = data['job'] ?? data['title'] ?? 'إعلان';
                      final type = data['type'] ?? 'employer';

                      return Container(
                        padding: EdgeInsets.all(14.r),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF10282C) : Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              type == 'seeker' ? Icons.person_search_rounded : Icons.business_center_rounded,
                              color: app_colors.primaryColor,
                              size: 24.r,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    jobTitle,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.sp,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    type == 'seeker' ? 'طلب وظيفة (باحث)' : 'فرصة عمل (صاحب عمل)',
                                    style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('حذف الإعلان', style: TextStyle(fontWeight: FontWeight.bold)),
                                    content: const Text('متأكد تريد تحذف هذا الإعلان من الوظائف؟', style: TextStyle()),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle())),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _service.deleteVacancy(doc.id);
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 30.h),
            ],
          ),
        );
      },
    );
  }

  void _showEditProfileSheet({
    required BuildContext context,
    required String initialName,
    required String initialTitle,
    required String initialPhone,
    required String initialCity,
    required String initialExp,
    required List<String> initialSkills,
    required String initialBio,
    required bool initialAvailable,
    required String initialSalary,
    required bool isDark,
  }) {
    final nameCtrl = TextEditingController(text: initialName);
    final titleCtrl = TextEditingController(text: initialTitle);
    final phoneCtrl = TextEditingController(text: initialPhone);
    final cityCtrl = TextEditingController(text: initialCity);
    final salaryCtrl = TextEditingController(text: initialSalary);
    final bioCtrl = TextEditingController(text: initialBio);
    String selectedExp = initialExp;
    bool isAvail = initialAvailable;
    final List<String> skills = List.from(initialSkills);
    final skillInputCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0C2428) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28.r))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  top: 20.h,
                  left: 20.w,
                  right: 20.w,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 45.w,
                          height: 4.h,
                          decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10.r)),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'تعديل ملفك المهني',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16.sp,
                              color: isDark ? Colors.white : const Color(0xFF0C2428),
                            ),
                          ),
                          Switch(
                            value: isAvail,
                            activeThumbColor: const Color(0xFF10B981),
                            onChanged: (val) => setSheetState(() => isAvail = val),
                          ),
                        ],
                      ),
                      Text(
                        isAvail ? 'متاح للعمل واستقبال العروض' : 'غير متاح حالياً',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: isAvail ? const Color(0xFF10B981) : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 14.h),

                      // Name & Title
                      _buildTextField('الاسم الكامل', nameCtrl, Icons.person_rounded, isDark),
                      SizedBox(height: 10.h),
                      _buildTextField('المسمى المهني / التخصص (مثل: كاشير، مهندس، محاسب)', titleCtrl, Icons.work_rounded, isDark),
                      SizedBox(height: 10.h),

                      // Phone & City
                      Row(
                        children: [
                          Expanded(child: _buildTextField('رقم الهاتف والواتساب', phoneCtrl, Icons.phone_rounded, isDark, keyboardType: TextInputType.phone)),
                          SizedBox(width: 10.w),
                          Expanded(child: _buildTextField('المدينة / المنطقة', cityCtrl, Icons.location_on_rounded, isDark)),
                        ],
                      ),
                      SizedBox(height: 10.h),

                      // Experience selector
                      Text('مستوى الخبرة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: isDark ? Colors.white70 : Colors.black87)),
                      SizedBox(height: 6.h),
                      Row(
                        children: ['مبتدئ', 'متوسط', 'خبير'].map((lvl) {
                          final isSel = selectedExp == lvl;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setSheetState(() => selectedExp = lvl),
                              child: Container(
                                margin: EdgeInsets.symmetric(horizontal: 4.w),
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: isSel ? app_colors.primaryColor : (isDark ? const Color(0xFF13363A) : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  lvl,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.sp,
                                    color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 12.h),

                      // Skills Chips & Add Skill
                      Text('المهارات (أضف مهاراتك):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: isDark ? Colors.white70 : Colors.black87)),
                      SizedBox(height: 6.h),
                      Wrap(
                        spacing: 6.w,
                        runSpacing: 6.h,
                        children: skills.map((sk) {
                          return Chip(
                            label: Text(sk, style: const TextStyle(fontSize: 11)),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () => setSheetState(() => skills.remove(sk)),
                            backgroundColor: app_colors.primaryColor.withValues(alpha: 0.15),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: skillInputCtrl,
                              cursorColor: app_colors.primaryColor,
                              style: TextStyle(fontSize: 12.sp, color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'اكتب مهارة واضغط إضافة (مثل: قيادة، إكسل، تسويق)',
                                hintStyle: TextStyle(fontSize: 11.sp, color: Colors.grey),
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          ElevatedButton(
                            onPressed: () {
                              if (skillInputCtrl.text.trim().isNotEmpty) {
                                setSheetState(() {
                                  skills.add(skillInputCtrl.text.trim());
                                  skillInputCtrl.clear();
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: app_colors.primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            ),
                            child: const Text('إضافة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),

                      SizedBox(height: 12.h),

                      // Bio input
                      _buildTextField('النبذة المهنية والسيرة الذاتية', bioCtrl, Icons.article_rounded, isDark, maxLines: 3),
                      SizedBox(height: 18.h),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 48.h,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (nameCtrl.text.trim().isEmpty || titleCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('يرجى كتابة الاسم والمسمى المهني على الأقل', style: TextStyle())),
                              );
                              return;
                            }
                            await _service.saveUserJobProfile(
                              name: nameCtrl.text.trim(),
                              title: titleCtrl.text.trim(),
                              phone: phoneCtrl.text.trim(),
                              city: cityCtrl.text.trim().isNotEmpty ? cityCtrl.text.trim() : 'القائم',
                              experience: selectedExp,
                              skills: skills,
                              bio: bioCtrl.text.trim(),
                              isAvailable: isAvail,
                              expectedSalary: salaryCtrl.text.trim(),
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('تم حفظ وتحديث ملفك المهني بنجاح!', style: TextStyle()), backgroundColor: app_colors.primaryColor),
                              );
                            }
                          },
                          icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                          label: const Text('حفظ الملف المهني هسة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: app_colors.primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
    bool isDark, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      cursorColor: app_colors.primaryColor,
      style: TextStyle(fontSize: 13.sp, color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12.sp, color: isDark ? Colors.white60 : Colors.black54),
        prefixIcon: Icon(icon, size: 20.r, color: app_colors.primaryColor),
        filled: true,
        fillColor: isDark ? const Color(0xFF13363A) : const Color(0xFFF6F8FB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide.none),
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      ),
    );
  }
}
