import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import '../../services/real_estate_service.dart';
import '../../widgets/real_estate_card.dart';
import '../../widgets/real_estate_details_sheet.dart';
import '../../widgets/real_estate_add_sheet.dart';
import '../../widgets/skozme_real_estate_assistant_card.dart';

class RealEstatePage extends StatefulWidget {
  const RealEstatePage({super.key});

  @override
  State<RealEstatePage> createState() => _RealEstatePageState();
}

class _RealEstatePageState extends State<RealEstatePage> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final RealEstateService _service = RealEstateService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String _searchQuery = '';
  String _selectedCategory = 'الكل';
  String _selectedGovernorate = 'كل العراق';
  String _selectedCity = 'الكل';

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
    {'name': 'بيوت ومنازل', 'icon': Icons.home_rounded},
    {'name': 'شقق وعمارات', 'icon': Icons.apartment_rounded},
    {'name': 'أراضي وعرصات', 'icon': Icons.terrain_rounded},
    {'name': 'محلات ومكاتب', 'icon': Icons.storefront_rounded},
    {'name': 'بساتين ومزارع', 'icon': Icons.nature_people_rounded},
    {'name': 'شاليهات واستراحات', 'icon': Icons.villa_rounded},
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
            // Tab 0: تصفح الكل (All Properties Feed - Rent & Sale)
            _buildPropertiesFeed(isDark, typeFilter: 'الكل'),

            // Tab 1: عقارات للإيجار (Properties for Rent)
            _buildPropertiesFeed(isDark, typeFilter: 'للإيجار'),

            // Tab 2: عقارات للبيع (Properties for Sale)
            _buildPropertiesFeed(isDark, typeFilter: 'للبيع'),

            // Tab 3: عقاراتي وإعلاناتي (My Properties)
            _buildMyPropertiesTab(isDark),

            // Tab 4: مستشار سكوزمي العقاري (Skozme Real Estate Consultant)
            _buildSkozmeTab(isDark),
          ],
        ),

        // ── القائمة السفلية المرتبة (Bottom Navigation Bar) ──
        bottomNavigationBar: _buildBottomNavigationBar(isDark),

        // ── زر نشر العقار المصمم بفخامة (Floating Action Button) ──
        floatingActionButton: (_currentIndex == 0 || _currentIndex == 1 || _currentIndex == 2)
            ? _buildPublishFloatingButton(isDark)
            : null,
      ),
    );
  }

  // ── زر نشر العقار الفاخر العائم ──
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
          onTap: () => _showAddPropertySheet(isDark),
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
                  child: const Icon(Icons.add_home_rounded, color: Colors.white, size: 20),
                ),
                SizedBox(width: 8.w),
                Text(
                  'انشر عقارك هسة',
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
    String title = 'سوق عقارات مدار';
    String subtitle = 'تصفح كل عروض البيع والإيجار في العراق 🇮🇶';

    if (_currentIndex == 0) {
      title = 'سوق عقارات العراق';
      subtitle = 'كل عروض البيع والإيجار المباشرة من المالكين';
    } else if (_currentIndex == 1) {
      title = 'عقارات للإيجار';
      subtitle = 'بيوت، شقق، ومحلات للإيجار الشهري والسنوي';
    } else if (_currentIndex == 2) {
      title = 'عقارات للبيع';
      subtitle = 'طابو صرف، ملك صرف، وزراعي للبيع في كل المحافظات';
    } else if (_currentIndex == 3) {
      title = 'عقاراتي وإعلاناتي';
      subtitle = 'العقارات المعروضة من قبلك وتعديل حالتها';
    } else if (_currentIndex == 4) {
      title = 'سكوزمي - المستشار العقاري';
      subtitle = 'تقييم العقارات وحساب الدلالية وصياغة الإعلانات';
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
        if (_currentIndex == 0 || _currentIndex == 1 || _currentIndex == 2)
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: app_colors.primaryColor),
            tooltip: 'إضافة إعلان عقار جديد',
            onPressed: () => _showAddPropertySheet(isDark),
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

  // ── Bottom Navigation Bar (الكل، للإيجار، للبيع، إعلاناتي، سكوزمي) ──
  Widget _buildBottomNavigationBar(bool isDark) {
    final items = [
      {'icon': Icons.home_work_outlined, 'activeIcon': Icons.home_work_rounded, 'label': 'الكل'},
      {'icon': Icons.key_outlined, 'activeIcon': Icons.key_rounded, 'label': 'للإيجار'},
      {'icon': Icons.sell_outlined, 'activeIcon': Icons.sell_rounded, 'label': 'للبيع'},
      {'icon': Icons.person_outline_rounded, 'activeIcon': Icons.person_rounded, 'label': 'إعلاناتي'},
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
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
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
                  borderRadius: BorderRadius.circular(12.r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(vertical: 3.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? app_colors.primaryColor.withValues(alpha: isDark ? 0.2 : 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSelected ? item['activeIcon'] as IconData : item['icon'] as IconData,
                          size: 19.sp,
                          color: isSelected ? app_colors.primaryColor : (isDark ? Colors.white54 : Colors.grey.shade500),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          item['label'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5.sp,
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

  // ── Properties Feed (الكل، للإيجار، للبيع) ──
  Widget _buildPropertiesFeed(bool isDark, {required String typeFilter}) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: app_colors.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 80.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input
            _buildSearchBar(isDark),
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
                      ? (typeFilter == 'الكل'
                          ? 'أحدث العقارات في كل العراق 🇮🇶'
                          : typeFilter == 'للبيع'
                              ? 'أحدث العقارات المعروضة للبيع'
                              : 'أحدث العقارات المعروضة للإيجار')
                      : 'عقارات ${typeFilter == "الكل" ? "" : typeFilter} في $_selectedGovernorate',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5.sp,
                    color: isDark ? Colors.white : const Color(0xFF0A2828),
                  ),
                ),
                Text(
                  'مباشر من المالك',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: const Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),

            // Firestore Stream
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('real_estate').snapshots(),
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

                // 1. Filter by Deal Type (للبيع / للإيجار / الكل)
                if (typeFilter != 'الكل') {
                  final isRentTab = typeFilter == 'للإيجار';
                  docs = docs.where((doc) {
                    final d = doc.data();
                    final type = _normalize((d['type'] ?? '').toString());
                    final title = _normalize((d['title'] ?? '').toString());
                    final desc = _normalize((d['description'] ?? '').toString());

                    if (isRentTab) {
                      return type.contains('ايجار') || type.contains('اجار') || title.contains('ايجار') || desc.contains('ايجار');
                    } else {
                      return type.contains('بيع') || title.contains('بيع') || desc.contains('بيع') || (!type.contains('ايجار') && !type.contains('اجار'));
                    }
                  }).toList();
                }

                // 2. Sort descending by date
                docs.sort((a, b) {
                  final aVal = a.data()['createdAt'] ?? a.data()['date'] ?? a.data()['updatedAt'];
                  final bVal = b.data()['createdAt'] ?? b.data()['date'] ?? b.data()['updatedAt'];
                  return (bVal?.toString() ?? '').compareTo(aVal?.toString() ?? '');
                });

                // 3. Apply Governorate & City Filter
                // NOTE: When "كل العراق" is selected, NO filtering is applied so all documents across Iraq show!
                if (_selectedGovernorate != 'كل العراق') {
                  final govClean = _selectedGovernorate
                      .replaceAll(' (الموصل)', '')
                      .replaceAll(' (الحلة)', '')
                      .replaceAll('المقدسة', '')
                      .replaceAll('الأشرف', '');
                  final govQuery = _normalize(govClean);

                  docs = docs.where((doc) {
                    final d = doc.data();
                    final city = _normalize((d['city'] ?? '').toString());
                    final gov = _normalize((d['governorate'] ?? '').toString());
                    final location = _normalize((d['location'] ?? '').toString());
                    final desc = _normalize((d['description'] ?? '').toString());
                    final title = _normalize((d['title'] ?? '').toString());

                    final matchesGov = city.contains(govQuery) ||
                        gov.contains(govQuery) ||
                        location.contains(govQuery) ||
                        desc.contains(govQuery) ||
                        title.contains(govQuery);

                    if (_selectedCity != 'الكل') {
                      final cityQuery = _normalize(_selectedCity);
                      return city.contains(cityQuery) || location.contains(cityQuery) || desc.contains(cityQuery) || title.contains(cityQuery);
                    }
                    return matchesGov;
                  }).toList();
                }

                // 4. Apply Category Filter
                if (_selectedCategory != 'الكل') {
                  final catRaw = _selectedCategory;
                  docs = docs.where((doc) {
                    final d = doc.data();
                    final cat = _normalize((d['category'] ?? '').toString());
                    final title = _normalize((d['title'] ?? '').toString());
                    final desc = _normalize((d['description'] ?? '').toString());
                    final combined = '$cat $title $desc';

                    if (catRaw.contains('بيوت')) {
                      return combined.contains('بيت') || combined.contains('منزل') || combined.contains('دار') || combined.contains('فيلا') || combined.contains('فلل');
                    } else if (catRaw.contains('شقق')) {
                      return combined.contains('شقه') || combined.contains('عماره') || combined.contains('بنايه');
                    } else if (catRaw.contains('اراضي') || catRaw.contains('أراضي')) {
                      return combined.contains('ارض') || combined.contains('عرصه') || combined.contains('قطعه');
                    } else if (catRaw.contains('محلات')) {
                      return combined.contains('محل') || combined.contains('مكتب') || combined.contains('معرض') || combined.contains('تجاري');
                    } else if (catRaw.contains('بساتين')) {
                      return combined.contains('بستان') || combined.contains('مزرع') || combined.contains('زراعي');
                    } else if (catRaw.contains('شاليهات')) {
                      return combined.contains('شاليه') || combined.contains('استراح') || combined.contains('فيلا');
                    }
                    return combined.contains(_normalize(catRaw));
                  }).toList();
                }

                // 5. Apply Search Query
                if (_searchQuery.isNotEmpty) {
                  final q = _normalize(_searchQuery);
                  docs = docs.where((doc) {
                    final d = doc.data();
                    final title = _normalize((d['title'] ?? '').toString());
                    final location = _normalize((d['location'] ?? '').toString());
                    final city = _normalize((d['city'] ?? '').toString());
                    final gov = _normalize((d['governorate'] ?? '').toString());
                    final desc = _normalize((d['description'] ?? '').toString());
                    final cat = _normalize((d['category'] ?? '').toString());
                    return title.contains(q) || location.contains(q) || city.contains(q) || gov.contains(q) || desc.contains(q) || cat.contains(q);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return _buildEmptyState(
                    title: 'ما لكينه عقارات مطابقة للبحث أو المحافظة',
                    subtitle: 'جرب تختار (كل العراق) أو تبحث بكلمة ثانية يا غالي',
                    isDark: isDark,
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => SizedBox(height: 6.h),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    return RealEstateCard(
                      docId: doc.id,
                      data: data,
                      isDark: isDark,
                      onTap: () => _showPropertyDetails(doc.id, data, isDark),
                      onDelete: () => _service.deleteProperty(doc.id),
                      onToggleSold: () => _service.toggleSoldStatus(doc.id, !(data['sold'] == true)),
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

  // ── Tab 3: عقاراتي وإعلاناتي ──
  Widget _buildMyPropertiesTab(bool isDark) {
    if (_currentUser == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_person_rounded, size: 64.r, color: app_colors.primaryColor),
              SizedBox(height: 16.h),
              Text(
                'سجل دخولك أولاً يا غالي',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: isDark ? Colors.white : Colors.black87),
              ),
              SizedBox(height: 8.h),
              Text(
                'حتى تكدر تشوف إعلانات عقاراتك وتعدل حالتها وتتحكم بيها',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.sp, color: isDark ? Colors.white60 : Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.getMyPropertiesStream(_currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: app_colors.primaryColor));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.r),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home_work_outlined, size: 64.r, color: app_colors.primaryColor.withValues(alpha: 0.4)),
                  SizedBox(height: 16.h),
                  Text(
                    'ما عندك أي إعلان عقار منشور حالياً',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp, color: isDark ? Colors.white : Colors.black87),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'انشر إعلان بيتك أو أرضك وشوف اتصالات وواتسابات الزبائن مباشرة!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5.sp, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton.icon(
                    onPressed: () => _showAddPropertySheet(isDark),
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: const Text('نشر عقار جديد هسة', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 80.h),
          itemCount: docs.length,
          separatorBuilder: (_, __) => SizedBox(height: 6.h),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return RealEstateCard(
              docId: doc.id,
              data: data,
              isDark: isDark,
              onTap: () => _showPropertyDetails(doc.id, data, isDark),
              onDelete: () => _service.deleteProperty(doc.id),
              onToggleSold: () => _service.toggleSoldStatus(doc.id, !(data['sold'] == true)),
            );
          },
        );
      },
    );
  }

  // ── Tab 4: سكوزمي العقاري ──
  Widget _buildSkozmeTab(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 80.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkozmeRealEstateAssistantCard(
            isDark: isDark,
            onFilterProperty: (q) => setState(() {
              _searchQuery = q;
              _currentIndex = 0; // Go to All tab
            }),
          ),
          SizedBox(height: 16.h),
          Text(
            'نصائح الدلالية والبيع والشراء بالعراق',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.5.sp,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: 10.h),
          _buildRealEstateTip(
            title: '1. تأكد من جنس السند القانوني ',
            body: 'الطابو الصرف الملك الصرف هو الأضمن في التسجيل، أما الأراضي الزراعية فيجب التأكد من قرار المحكمة وإقرار المالكين.',
            isDark: isDark,
          ),
          SizedBox(height: 8.h),
          _buildRealEstateTip(
            title: '2. دقة المواصفات تسرّع البيع ',
            body: 'الصور الواضحة مع ذكر تفاصيل الخدمات (ماء، كهرباء، مجاري، فايبر) تزيد من ثقة المشتري وتجلب مشترين جادين.',
            isDark: isDark,
          ),
          SizedBox(height: 8.h),
          _buildRealEstateTip(
            title: '3. معرفة أسعار المتر في المنطقة ',
            body: 'استشر سكوزمي العقاري لتقدير متوسط سعر المتر المربع حسب المحافظة والحي قبل تحديد السعر النهائي.',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildRealEstateTip({required String title, required String body, required bool isDark}) {
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

  // ── Search Bar ──
  Widget _buildSearchBar(bool isDark) {
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
          hintText: 'ابحث عن عقار (بيت 200م، شقة، طابو صرف، الكرابلة، المنصور)...',
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
            Icon(Icons.home_work_outlined, size: 54.r, color: app_colors.primaryColor.withValues(alpha: 0.5)),
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

  // ── Bottom Sheet: Add Property ──
  void _showAddPropertySheet(bool isDark) {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('سجل دخولك أولاً حتى تنشر إعلان عقارك يا غالي', style: TextStyle()),
          backgroundColor: app_colors.primaryColor,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RealEstateAddSheet(isDark: isDark),
    );
  }

  // ── Bottom Sheet: Property Details ──
  void _showPropertyDetails(String docId, Map<String, dynamic> data, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RealEstateDetailsSheet(
        docId: docId,
        data: data,
        isDark: isDark,
      ),
    );
  }
}
