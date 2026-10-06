import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import '../../widgets/skozme_job_assistant_card.dart';
import '../../widgets/user_job_profile_view.dart';
import '../../widgets/vacancy_add_sheet.dart';
import '../../widgets/vacancy_apply_sheet.dart';
import '../../widgets/vacancy_card.dart';
import '../../services/vacancy_service.dart';

class VacanciesPage extends StatefulWidget {
  const VacanciesPage({super.key});

  @override
  State<VacanciesPage> createState() => _VacanciesPageState();
}

class _VacanciesPageState extends State<VacanciesPage> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final VacancyService _vacancyService = VacancyService();
  String _searchQuery = '';
  String _selectedCategory = 'الكل';
  String _selectedGovernorate = 'كل العراق';
  String _selectedCity = 'الكل';
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  static const List<String> _iraqGovernorates = [
    'كل العراق',
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
        return ['الكل', 'القائم', 'الرمادي', 'الفلوجة', 'هيت', 'حديثة', 'عانة', 'راوة', 'الرطبة', 'الكرمة', 'الخالدية', 'حصيبة', 'الرمانة', 'العبيدي'];
      case 'بغداد':
        return ['الكل', 'الكرخ', 'الرصافة', 'المنصور', 'الكرادة', 'الأعظمية', 'الكاظمية', 'الدورة', 'الشعب', 'مدينة الصدر', 'السيدية', 'العامرية', 'الغزالية'];
      case 'البصرة':
        return ['الكل', 'المركز (العشار)', 'الجبيلة', 'الجمهورية', 'القرنة', 'الزبير', 'شط العرب', 'أبي الخصيب', 'الفاو'];
      case 'نينوى (الموصل)':
        return ['الكل', 'الموصل الأيمن', 'الموصل الأيسر', 'تلعفر', 'الحمدانية', 'سنجار'];
      case 'أربيل':
        return ['الكل', 'المركز', 'عنكاوا', 'سوران', 'شقلاوة', 'كويسنجق'];
      case 'كربلاء المقدسة':
        return ['الكل', 'المركز', 'حي الحسين', 'حي العباس', 'الهندية', 'عين التمر'];
      case 'النجف الأشرف':
        return ['الكل', 'المدينة القديمة', 'الكوفة', 'حي الغدير', 'حي الأمير', 'المناذرة'];
      default:
        return ['الكل', 'المركز', 'حي المعلمين', 'السوق الكبير', 'حي الزهور'];
    }
  }

  final List<Map<String, dynamic>> _categories = [
    {'name': 'الكل', 'icon': Icons.stars_rounded},
    {'name': 'كاشير ومبيعات ومحلات', 'icon': Icons.point_of_sale_rounded},
    {'name': 'مطاعم وكافيهات وضيافة', 'icon': Icons.restaurant_rounded},
    {'name': 'سواق دليفري وتوصيل', 'icon': Icons.local_taxi_rounded},
    {'name': 'برمجة وتصميم وتقنية', 'icon': Icons.computer_rounded},
    {'name': 'تدريس ومعاهد وخصوصي', 'icon': Icons.school_rounded},
    {'name': 'خلفات وحرفيين وصيانة', 'icon': Icons.handyman_rounded},
    {'name': 'محاسبة وإدارة مكاتب', 'icon': Icons.account_balance_wallet_rounded},
    {'name': 'صيدليات ومجمعات طبية', 'icon': Icons.local_hospital_rounded},
    {'name': 'حراسة وأمنية', 'icon': Icons.security_rounded},
  ];

  static String _normalize(String text) {
    return text
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .toLowerCase()
        .trim();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF07181A) : const Color(0xFFF6F8FB),
        appBar: _buildAppBar(isDark),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            // 0: فرص الشغل والوظائف المتاحة (Job Listings Feed)
            _buildJobListingsTab(isDark),

            // 1: سوق الكفاءات والوادم (Job Seekers Feed)
            _buildJobSeekersTab(isDark),

            // 2: بروفايلي المهني وسيرتي الذاتية (My Career Profile)
            UserJobProfileView(isDark: isDark),

            // 3: سكوزمي المهني (Skozme AI Assistant)
            _buildSkozmeCareerTab(isDark),
          ],
        ),

        // ── القائمة السفلية المرتبة (Bottom Navigation Bar) ──
        bottomNavigationBar: _buildBottomNavigationBar(isDark),

        // ── زر نشر الوظيفة المصمم بفخامة (Floating Action Button) ──
        floatingActionButton: (_currentIndex == 0 || _currentIndex == 1)
            ? _buildPublishFloatingButton(isDark)
            : null,
      ),
    );
  }

  // ── زر نشر الوظيفة المصمم بأناقة عالية ──
  Widget _buildPublishFloatingButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showPublishOptions(isDark),
          borderRadius: BorderRadius.circular(28.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                ),
                SizedBox(width: 8.w),
                Text(
                  _currentIndex == 0 ? 'انشر فرصة شغل' : 'انشر طلب وظيفتك',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Top App Bar ──
  PreferredSizeWidget _buildAppBar(bool isDark) {
    String title = 'سوق الشغل والوظائف';
    String subtitle = 'فرص عمل حية ومباشرة في كل العراق 🇮🇶';

    if (_currentIndex == 1) {
      title = 'سوق الكفاءات والوادم';
      subtitle = 'تواصل ويه أهل الصنعة والخبرة مباشرة';
    } else if (_currentIndex == 2) {
      title = 'بروفايلي وسيرتي الذاتية';
      subtitle = 'معلوماتك وخبراتك المهنية ورقم تواصلك';
    } else if (_currentIndex == 3) {
      title = 'سكوزمي - المستشار المهني';
      subtitle = 'يسويلك سيرة ذاتية ويضبطلك التقديم';
    }

    return AppBar(
      backgroundColor: isDark ? const Color(0xFF0C2428) : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: isDark ? Colors.white : const Color(0xFF0A2828),
          size: 19.r,
        ),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15.5.sp,
                  color: isDark ? Colors.white : const Color(0xFF0A2828),
                ),
              ),
              SizedBox(width: 6.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                decoration: BoxDecoration(
                  color: app_colors.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  _selectedGovernorate == 'كل العراق' ? '🇮🇶 كل العراق' : _selectedGovernorate,
                  style: TextStyle(
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.bold,
                    color: app_colors.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10.5.sp,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
      actions: [
        if (_currentIndex == 0 || _currentIndex == 1)
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: app_colors.primaryColor),
            tooltip: 'إضافة إعلان جديد',
            onPressed: () => _showPublishOptions(isDark),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
          height: 1,
        ),
      ),
    );
  }

  // ── Bottom Navigation Bar ──
  Widget _buildBottomNavigationBar(bool isDark) {
    final items = [
      {'icon': Icons.business_center_outlined, 'activeIcon': Icons.business_center_rounded, 'label': 'فرص شغل'},
      {'icon': Icons.people_outline_rounded, 'activeIcon': Icons.people_rounded, 'label': 'الوادم'},
      {'icon': Icons.person_outline_rounded, 'activeIcon': Icons.person_rounded, 'label': 'بروفايلي'},
      {'icon': Icons.smart_toy_outlined, 'activeIcon': Icons.smart_toy_rounded, 'label': 'سكوزمي'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A2024) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Container(
          height: 60.h,
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          child: Row(
            children: items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final isSelected = _currentIndex == idx;

              return Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() => _currentIndex = idx);
                  },
                  borderRadius: BorderRadius.circular(14.r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? app_colors.primaryColor.withValues(alpha: isDark ? 0.2 : 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSelected ? item['activeIcon'] as IconData : item['icon'] as IconData,
                          size: 20.sp,
                          color: isSelected ? app_colors.primaryColor : (isDark ? Colors.white54 : Colors.grey.shade500),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          item['label'] as String,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? app_colors.primaryColor : (isDark ? Colors.white60 : Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Location & Governorate Filter Bar ──
  Widget _buildGovernorateFilterBar(bool isDark) {
    final hasSubCities = _selectedGovernorate != 'كل العراق';
    final subCities = hasSubCities ? _getCitiesForGov(_selectedGovernorate) : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Governorates Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _iraqGovernorates.map((gov) {
              final isSelected = _selectedGovernorate == gov;
              return Padding(
                padding: EdgeInsets.only(left: 6.w),
                child: FilterChip(
                  label: Text(gov == 'كل العراق' ? '🇮🇶 كل العراق' : gov),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedGovernorate = gov;
                      _selectedCity = 'الكل';
                    });
                  },
                  selectedColor: const Color(0xFF10B981),
                  backgroundColor: isDark ? const Color(0xFF10282C) : Colors.white,
                  labelStyle: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF10B981) : (isDark ? Colors.white12 : Colors.grey.shade300),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),

        // Sub-cities row if specific governorate is selected
        if (hasSubCities && subCities.isNotEmpty) ...[
          SizedBox(height: 6.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: subCities.map((c) {
                final isSelected = _selectedCity == c;
                return Padding(
                  padding: EdgeInsets.only(left: 6.w),
                  child: ActionChip(
                    label: Text(c),
                    backgroundColor: isSelected
                        ? app_colors.primaryColor.withValues(alpha: 0.25)
                        : (isDark ? const Color(0xFF10282C) : Colors.grey.shade100),
                    side: BorderSide(
                      color: isSelected ? app_colors.primaryColor : Colors.transparent,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? app_colors.primaryColor : (isDark ? Colors.white60 : Colors.black87),
                    ),
                    onPressed: () => setState(() => _selectedCity = c),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  // ── Tab 0: Job Listings Feed (فرص الشغل الشاغرة - فلترة لكل العراق) ──
  Widget _buildJobListingsTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: app_colors.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 80.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            _buildSearchBar(isDark, 'ابحث عن شغل (كاشير، مندوب، محاسب، سائق توصيل)...'),
            SizedBox(height: 10.h),

            // ── فلتر المحافظات والمدن بالعراق 🇮🇶 ──
            _buildGovernorateFilterBar(isDark),
            SizedBox(height: 8.h),

            // Category Chips
            _buildCategoryChips(isDark),
            SizedBox(height: 12.h),

            // Feed Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedGovernorate == 'كل العراق'
                      ? 'أحدث فرص الشغل في العراق 🇮🇶'
                      : 'فرص الشغل في $_selectedGovernorate',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5.sp,
                    color: isDark ? Colors.white : const Color(0xFF0A2828),
                  ),
                ),
                Text(
                  'مباشر من أصحاب العمل',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: const Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),

            // Firestore Stream for Employer Jobs
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('vacancies').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: app_colors.primaryColor),
                    ),
                  );
                }

                var docs = snapshot.data?.docs ?? [];
                // Filter only employers / job offers
                var jobDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final type = data['type'] ?? 'employer';
                  return type != 'seeker';
                }).toList();

                // Sort descending by date
                jobDocs.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['date'];
                  final bTime = (b.data() as Map<String, dynamic>)['date'];
                  return (bTime?.toString() ?? '').compareTo(aTime?.toString() ?? '');
                });

                // Apply Governorate & City Filter
                // NOTE: When "كل العراق" is selected, NO filtering is applied so all documents across Iraq show!
                if (_selectedGovernorate != 'كل العراق') {
                  final govClean = _selectedGovernorate
                      .replaceAll(' (الموصل)', '')
                      .replaceAll(' (الحلة)', '')
                      .replaceAll('المقدسة', '')
                      .replaceAll('الأشرف', '');
                  final govQuery = _normalize(govClean);

                  jobDocs = jobDocs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final city = _normalize((d['city'] ?? '').toString());
                    final gov = _normalize((d['governorate'] ?? '').toString());
                    final notes = _normalize((d['notes'] ?? '').toString());
                    final company = _normalize((d['company'] ?? '').toString());

                    final matchesGov = city.contains(govQuery) || gov.contains(govQuery) || notes.contains(govQuery) || company.contains(govQuery);
                    if (_selectedCity != 'الكل') {
                      final cityQuery = _normalize(_selectedCity);
                      return city.contains(cityQuery) || notes.contains(cityQuery);
                    }
                    return matchesGov;
                  }).toList();
                }

                // Apply Category Filter
                if (_selectedCategory != 'الكل') {
                  final catWords = _selectedCategory.split(' ');
                  jobDocs = jobDocs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final title = _normalize((d['jobDetails'] ?? d['job'] ?? '').toString());
                    final tags = _normalize((d['tags'] as List?)?.join(' ') ?? '');
                    final tag = _normalize((d['tag'] ?? '').toString());
                    final combined = '$title $tags $tag';

                    return catWords.any((w) => w.length > 2 && combined.contains(_normalize(w)));
                  }).toList();
                }

                // Apply Search Query
                if (_searchQuery.isNotEmpty) {
                  final q = _normalize(_searchQuery);
                  jobDocs = jobDocs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final title = _normalize((d['jobDetails'] ?? d['job'] ?? '').toString());
                    final company = _normalize((d['company'] ?? '').toString());
                    final city = _normalize((d['city'] ?? '').toString());
                    final notes = _normalize((d['notes'] ?? '').toString());
                    return title.contains(q) || company.contains(q) || city.contains(q) || notes.contains(q);
                  }).toList();
                }

                if (jobDocs.isEmpty) {
                  return _buildEmptyState(
                    title: 'ما لكينه فرص عمل مطابقة للبحث أو المحافظة',
                    subtitle: 'جرب تختار (كل العراق) أو تبحث بمسمى وظيفي ثاني يا غالي',
                    isDark: isDark,
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: jobDocs.length,
                  separatorBuilder: (_, __) => SizedBox(height: 4.h),
                  itemBuilder: (context, index) {
                    final data = jobDocs[index].data() as Map<String, dynamic>;
                    data['id'] = jobDocs[index].id;
                    return VacancyCard(
                      data: data,
                      isDark: isDark,
                      onDelete: () => _vacancyService.deleteVacancy(jobDocs[index].id),
                      onApply: () => _showApplySheet(data, isDark),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Job Seekers Feed (سوق الكفاءات والوادم - فلترة لكل العراق) ──
  Widget _buildJobSeekersTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: app_colors.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 80.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            _buildSearchBar(isDark, 'ابحث عن كفاءة (محاسب، مصمم، كهربائي، معلم، خلفة)...'),
            SizedBox(height: 10.h),

            // ── فلتر المحافظات والمدن بالعراق 🇮🇶 ──
            _buildGovernorateFilterBar(isDark),
            SizedBox(height: 8.h),

            // Category Chips
            _buildCategoryChips(isDark),
            SizedBox(height: 12.h),

            // Feed Title Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedGovernorate == 'كل العراق'
                      ? 'الوادم والكفاءات في العراق'
                      : 'الكفاءات في $_selectedGovernorate',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5.sp,
                    color: isDark ? Colors.white : const Color(0xFF0A2828),
                  ),
                ),
                Text(
                  'متاحين للشغل والتوظيف فوراً',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: app_colors.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),

            // Firestore Stream for Job Seekers
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('vacancies').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: app_colors.primaryColor),
                    ),
                  );
                }

                var docs = snapshot.data?.docs ?? [];
                // Filter only job seekers
                var seekerDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['type'] == 'seeker';
                }).toList();

                // Sort descending
                seekerDocs.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['date'];
                  final bTime = (b.data() as Map<String, dynamic>)['date'];
                  return (bTime?.toString() ?? '').compareTo(aTime?.toString() ?? '');
                });

                // Apply Governorate & City Filter
                if (_selectedGovernorate != 'كل العراق') {
                  final govClean = _selectedGovernorate
                      .replaceAll(' (الموصل)', '')
                      .replaceAll(' (الحلة)', '')
                      .replaceAll('المقدسة', '')
                      .replaceAll('الأشرف', '');
                  final govQuery = _normalize(govClean);

                  seekerDocs = seekerDocs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final city = _normalize((d['city'] ?? '').toString());
                    final gov = _normalize((d['governorate'] ?? '').toString());
                    final notes = _normalize((d['notes'] ?? '').toString());

                    final matchesGov = city.contains(govQuery) || gov.contains(govQuery) || notes.contains(govQuery);
                    if (_selectedCity != 'الكل') {
                      final cityQuery = _normalize(_selectedCity);
                      return city.contains(cityQuery) || notes.contains(cityQuery);
                    }
                    return matchesGov;
                  }).toList();
                }

                // Apply Category Filter
                if (_selectedCategory != 'الكل') {
                  final catWords = _selectedCategory.split(' ');
                  seekerDocs = seekerDocs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final job = _normalize((d['job'] ?? d['jobDetails'] ?? '').toString());
                    final tags = _normalize((d['tags'] as List?)?.join(' ') ?? '');
                    final combined = '$job $tags';
                    return catWords.any((w) => w.length > 2 && combined.contains(_normalize(w)));
                  }).toList();
                }

                // Apply Search Query
                if (_searchQuery.isNotEmpty) {
                  final q = _normalize(_searchQuery);
                  seekerDocs = seekerDocs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final name = _normalize((d['name'] ?? '').toString());
                    final job = _normalize((d['job'] ?? d['jobDetails'] ?? '').toString());
                    final city = _normalize((d['city'] ?? '').toString());
                    final notes = _normalize((d['notes'] ?? '').toString());
                    return name.contains(q) || job.contains(q) || city.contains(q) || notes.contains(q);
                  }).toList();
                }

                if (seekerDocs.isEmpty) {
                  return _buildEmptyState(
                    title: 'ماكو باحثين عن عمل مسجلين بهذه المحافظة حالياً',
                    subtitle: 'انشر طلب وظيفتك وخلي أصحاب المحلات والشركات يتواصلون وياك!',
                    isDark: isDark,
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: seekerDocs.length,
                  separatorBuilder: (_, __) => SizedBox(height: 4.h),
                  itemBuilder: (context, index) {
                    final data = seekerDocs[index].data() as Map<String, dynamic>;
                    data['id'] = seekerDocs[index].id;
                    return VacancyCard(
                      data: data,
                      isDark: isDark,
                      onDelete: () => _vacancyService.deleteVacancy(seekerDocs[index].id),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 3: Skozme AI Career Consultant Tab (مستشار سكوزمي) ──
  Widget _buildSkozmeCareerTab(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 80.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkozmeJobAssistantCard(isDark: isDark),
          SizedBox(height: 16.h),
          Text(
            'نصائح النجاح والتوفيق بسوق الشغل',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.5.sp,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: 10.h),
          _buildCareerTip(
            title: '1. رتّب نبذة واضحة ومختصرة ',
            body: 'أصحاب المحلات والشركات يفضلون معرفة خبرتك الأساسية ورقم واتسابك مباشرة وبدون تعقيد.',
            isDark: isDark,
          ),
          SizedBox(height: 8.h),
          _buildCareerTip(
            title: '2. الالتزام والمصداقية أهم من كل شيء ',
            body: 'الالتزام بأوقات الدوام وحسن التعامل مع الزبائن هي الصفة الأولى لزيادة الراتب والترقية.',
            isDark: isDark,
          ),
          SizedBox(height: 8.h),
          _buildCareerTip(
            title: '3. حدد مهنتك وصنعتك بدقة ',
            body: 'كتابة مسمى واضح مثل (كاشير برنامج الأمين، سائق دليفري، معلم فيزياء) تزيد فرص قبولك بسرعة.',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildCareerTip({required String title, required String body, required bool isDark}) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF10282C) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12.5.sp,
              color: app_colors.primaryColor,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            body,
            style: TextStyle(
              fontSize: 11.5.sp,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Bar Component ──
  Widget _buildSearchBar(bool isDark, String hint) {
    return Container(
      height: 46.h,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D282D) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: app_colors.primaryColor.withValues(alpha: isDark ? 0.3 : 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
        cursorColor: app_colors.primaryColor,
        style: TextStyle(
          fontSize: 12.5.sp,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 11.5.sp, color: isDark ? Colors.white54 : Colors.black45),
          prefixIcon: const Icon(Icons.search_rounded, color: app_colors.primaryColor),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: isDark ? Colors.white70 : Colors.black54,
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10.h),
        ),
      ),
    );
  }

  // ── Category Chips ──
  Widget _buildCategoryChips(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat['name'];
          return Padding(
            padding: EdgeInsets.only(left: 6.w),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cat['icon'] as IconData, size: 12.sp, color: isSelected ? Colors.white : app_colors.primaryColor),
                  SizedBox(width: 4.w),
                  Text(cat['name'] as String),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedCategory = cat['name'] as String),
              selectedColor: app_colors.primaryColor,
              backgroundColor: isDark ? const Color(0xFF10282C) : Colors.white,
              labelStyle: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
              side: BorderSide(
                color: isSelected ? app_colors.primaryColor : (isDark ? Colors.white12 : Colors.grey.shade300),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Empty State ──
  Widget _buildEmptyState({required String title, required String subtitle, required bool isDark}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline_rounded, size: 54.r, color: app_colors.primaryColor.withValues(alpha: 0.5)),
            SizedBox(height: 12.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: isDark ? Colors.white : Colors.black87),
            ),
            SizedBox(height: 6.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5.sp, color: isDark ? Colors.white60 : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  // ── Apply Sheet Modal ──
  void _showApplySheet(Map<String, dynamic> vacancy, bool isDark) {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('سجل دخولك أول شي يا غالي حتى تكدر تقدم على الشغل', style: TextStyle()),
          backgroundColor: app_colors.primaryColor,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VacancyApplySheet(
        docId: vacancy['id']?.toString() ?? '',
        vacancyData: vacancy,
        isDark: isDark,
      ),
    );
  }

  // ── خيارات النشر المصممة بلهجة عراقية فاخرة ──
  void _showPublishOptions(bool isDark) {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('سجل دخولك أولاً حتى تنشر إعلانك يا غالي', style: TextStyle()),
          backgroundColor: app_colors.primaryColor,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 28.h),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C2428) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 44.w,
                  height: 4.5.h,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
              SizedBox(height: 18.h),

              // Title
              Text(
                'شنو تحب تنشر بسوق الشغل؟',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                  color: isDark ? Colors.white : const Color(0xFF0A2828),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'اختر نوع الإعلان لنشره لكل أهالي العراق مباشرة',
                style: TextStyle(
                  fontSize: 11.5.sp,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              SizedBox(height: 18.h),

              // ── خيار 1: صاحب عمل / متجر ──
              _buildPublishCard(
                title: 'أنا صاحب محل / شركة (أريد موظف)',
                subtitle: 'انشر فرصة عمل شاغرة وحدد الراتب والدوام والموقع',
                badgeText: 'طلب موظفين',
                icon: Icons.business_center_rounded,
                accentColor: app_colors.primaryColor,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => VacancyAddSheet(isDark: isDark, type: 'employer'),
                  );
                },
              ),
              SizedBox(height: 12.h),

              // ── خيار 2: باحث عن عمل ──
              _buildPublishCard(
                title: 'أنا أدور على شغل (أعرض مهنتي وخبرتي)',
                subtitle: 'انشر طلب وظيفتك وسيرتك ليتواصل وياك أصحاب المحلات والشركات',
                badgeText: 'متاح للشغل',
                icon: Icons.person_search_rounded,
                accentColor: const Color(0xFF10B981),
                isDark: isDark,
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => VacancyAddSheet(isDark: isDark, type: 'seeker'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPublishCard({
    required String title,
    required String subtitle,
    required String badgeText,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF113036) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.4,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18.r),
          child: Padding(
            padding: EdgeInsets.all(14.r),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(icon, color: accentColor, size: 24.r),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5.sp,
                                color: isDark ? Colors.white : const Color(0xFF0A2828),
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          color: isDark ? Colors.white60 : Colors.black54,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6.w),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14.r,
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
