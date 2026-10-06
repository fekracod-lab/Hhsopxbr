import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:dalal_alqaim/shared/section_utils.dart';
import 'package:dalal_alqaim/services/app_location_service.dart';
import 'package:dalal_alqaim/pages/section_user_view_page.dart'
    hide
        primaryColor,
        accentColor,
        darkBackground,
        darkSurface,
        darkCard,
        darkText,
        darkSubText,
        darkHint,
        hintColor,
        subTextColor;
import 'package:dalal_alqaim/pages/section_admin_page.dart'
    hide
        primaryColor,
        accentColor,
        darkBackground,
        darkSurface,
        darkCard,
        darkText,
        darkSubText,
        darkHint,
        hintColor,
        subTextColor;
import 'package:dalal_alqaim/features/delivery/presentation/pages/mersal_request_page.dart';
import 'package:dalal_alqaim/core/app_globals.dart';

// ─── Theme Palette (Modern Iraqi Luxury) ──────────────────────────────────────
const Color _primaryTeal = Color(0xFF00BFA5);
const Color _primaryDark = Color(0xFF004D40);
const Color _accentCyan = Color(0xFF00E5FF);
const Color _accentAmber = Color(0xFFFFB300);

// Dark Tokens
const Color _darkBg = Color(0xFF071214);
const Color _darkCard = Color(0xFF10272B);
const Color _darkCardBorder = Color(0xFF1B3D42);
const Color _darkText = Color(0xFFE8F5F5);
const Color _darkSubText = Color(0xFF80CBC4);

// Light Tokens
const Color _lightBg = Color(0xFFF3F8F8);
const Color _lightCardBorder = Color(0xFFD4E7E7);
const Color _lightText = Color(0xFF0E2E31);
const Color _lightSubText = Color(0xFF527477);

class AllSectionsPage extends StatefulWidget {
  const AllSectionsPage({super.key});

  @override
  State<AllSectionsPage> createState() => _AllSectionsPageState();
}

class _AllSectionsPageState extends State<AllSectionsPage> with TickerProviderStateMixin {
  String _searchQuery = '';
  String _selectedCategoryFilter = 'all';
  bool _isGridView = true;

  String? _selectedGovernorateId;
  String? _selectedGovernorateName;
  String? _selectedRegionId;
  String? _selectedRegionName;
  List<Map<String, dynamic>> _governorates = [];
  List<Map<String, dynamic>> _regions = [];
  bool _isLoadingGovernorates = true;
  bool _isLoadingRegions = false;

  late AnimationController _entryCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  final ScrollController _scrollCtrl = ScrollController();

  final List<Map<String, dynamic>> _filterChips = [
    {'id': 'all', 'label': 'الكل', 'icon': Icons.grid_view_rounded},
    {'id': 'food', 'label': 'مطاعم وأكلات', 'icon': Icons.restaurant_rounded},
    {'id': 'shopping', 'label': 'أسواق ومسواك', 'icon': Icons.shopping_bag_rounded},
    {'id': 'health', 'label': 'صحة وعلاج', 'icon': Icons.medical_services_rounded},
    {'id': 'delivery', 'label': 'توصيل وتكاسي', 'icon': Icons.local_taxi_rounded},
    {'id': 'services', 'label': 'فنيين وخدمات', 'icon': Icons.handyman_rounded},
    {'id': 'real_estate', 'label': 'عقارات وبيوت', 'icon': Icons.home_work_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 30, end: 0)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _fetchGovernorates();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _shimmerCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchGovernorates() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoadingGovernorates = false);
        return;
      }

      final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final role = profile.data()?['role'];
      final assignedGovId = profile.data()?['assignedGovernorateId'];

      Query query = FirebaseFirestore.instance
          .collection('governorates')
          .where('isActive', isEqualTo: true);
      if (role == 'limited_admin' && assignedGovId != null) {
        query = query.where(FieldPath.documentId, isEqualTo: assignedGovId);
      }

      final snap = await query.get();
      final docs = snap.docs.toList()
        ..sort((a, b) {
          final nameA = (a.data() as Map<String, dynamic>?)?['name'] ?? '';
          final nameB = (b.data() as Map<String, dynamic>?)?['name'] ?? '';
          return nameA.compareTo(nameB);
        });

      if (!mounted) return;
      setState(() {
        _governorates = docs.map((d) {
          final data = d.data() as Map<String, dynamic>? ?? {};
          return {'id': d.id, 'name': data['name'] ?? ''};
        }).toList();
        _isLoadingGovernorates = false;
        if (role == 'limited_admin' && _governorates.length == 1) {
          _selectedGovernorateId = _governorates[0]['id'];
          _selectedGovernorateName = _governorates[0]['name'];
          _fetchRegions(_selectedGovernorateId!);
        }
      });
    } catch (e) {
      debugPrint('Error fetching governorates: $e');
      if (mounted) setState(() => _isLoadingGovernorates = false);
    }
  }

  Future<void> _fetchRegions(String govId) async {
    if (mounted) {
      setState(() {
        _isLoadingRegions = true;
        _regions = [];
        _selectedRegionId = null;
        _selectedRegionName = null;
      });
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('governorates')
          .doc(govId)
          .collection('regions')
          .where('isActive', isEqualTo: true)
          .get();
      final docs = snap.docs.toList()
        ..sort((a, b) {
          final nameA = (a.data() as Map<String, dynamic>?)?['name'] ?? '';
          final nameB = (b.data() as Map<String, dynamic>?)?['name'] ?? '';
          return nameA.compareTo(nameB);
        });
      if (!mounted) return;
      setState(() {
        _regions = docs.map((d) {
          final data = d.data() as Map<String, dynamic>? ?? {};
          return {'id': d.id, 'name': data['name'] ?? ''};
        }).toList();
        _isLoadingRegions = false;
      });
    } catch (e) {
      debugPrint('Error fetching regions: $e');
      if (mounted) setState(() => _isLoadingRegions = false);
    }
  }

  bool _matchesCategory(String label, String filter) {
    if (filter == 'all') return true;
    final l = label.toLowerCase();
    switch (filter) {
      case 'food':
        return l.contains('مطعم') ||
            l.contains('أكل') ||
            l.contains('وجب') ||
            l.contains('كافيه') ||
            l.contains('حلويات') ||
            l.contains('مشويات') ||
            l.contains('شاورما') ||
            l.contains('بيتزا') ||
            l.contains('عصائر');
      case 'shopping':
        return l.contains('سوق') ||
            l.contains('تسوق') ||
            l.contains('متجر') ||
            l.contains('ماركت') ||
            l.contains('محل') ||
            l.contains('ملابس') ||
            l.contains('أحذية') ||
            l.contains('عطور') ||
            l.contains('إلكترون') ||
            l.contains('موبايل') ||
            l.contains('مول');
      case 'health':
        return l.contains('طبي') ||
            l.contains('صحة') ||
            l.contains('دكتور') ||
            l.contains('طبيب') ||
            l.contains('عيادة') ||
            l.contains('صيدلية') ||
            l.contains('علاج') ||
            l.contains('مختبر') ||
            l.contains('أسنان') ||
            l.contains('بصريات');
      case 'delivery':
        return l.contains('تكسي') ||
            l.contains('توصيل') ||
            l.contains('نقل') ||
            l.contains('كابتن') ||
            l.contains('مرسال') ||
            l.contains('سفريات') ||
            l.contains('خطوط');
      case 'services':
        return l.contains('مهن') ||
            l.contains('فني') ||
            l.contains('تصليح') ||
            l.contains('صيانة') ||
            l.contains('خدمات') ||
            l.contains('كهربائي') ||
            l.contains('سباك') ||
            l.contains('حدادة') ||
            l.contains('نجارة') ||
            l.contains('تنظيف');
      case 'real_estate':
        return l.contains('عقار') ||
            l.contains('بيت') ||
            l.contains('شقة') ||
            l.contains('إيجار') ||
            l.contains('بيع') ||
            l.contains('أراضي') ||
            l.contains('مكتب عقار');
      default:
        return true;
    }
  }

  void _showComingSoonDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ComingSoon',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? _darkCard : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? _primaryTeal.withValues(alpha: 0.3) : _lightCardBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryTeal.withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 75,
                    height: 75,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _primaryTeal.withValues(alpha: 0.2),
                          _accentCyan.withValues(alpha: 0.05),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: _primaryTeal.withValues(alpha: 0.4)),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.rocket_launch_rounded,
                        color: _primaryTeal,
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'قريباً بالخدمة!',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? _darkText : _lightText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'كاعدين نجهز ونرتب هذا القسم حتى يوصلكم بأحسن صورة وبأعلى سرعة ممكنة، انتظرونا قريباً!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13.5,
                      height: 1.55,
                      color: isDark ? _darkSubText : _lightSubText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        'صار، كل التوفيق',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
    );
  }

  void _showAddSectionDialog() {
    final labelCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: _darkCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_primaryTeal, _primaryDark]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.add_business_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'إضافة قسم جديد للدليل',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _darkText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _sheetField(labelCtrl, 'اسم القسم (مثال: مطاعم ومشويات، صيدليات...)', Icons.label_rounded),
                const SizedBox(height: 16),
                StatefulBuilder(
                  builder: (ctx2, setSheet) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isLoadingGovernorates)
                          const Center(child: CircularProgressIndicator(color: _primaryTeal))
                        else
                          _sheetDropdown<String>(
                            label: 'المحافظة',
                            icon: Icons.location_city_rounded,
                            value: _selectedGovernorateId,
                            items: _governorates
                                .map(
                                  (g) => DropdownMenuItem<String>(
                                    value: g['id'],
                                    child: Text(g['name']),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) async {
                              if (val != null) {
                                setSheet(() => _isLoadingRegions = true);
                                final name =
                                    _governorates.firstWhere((g) => g['id'] == val)['name'];
                                setState(() {
                                  _selectedGovernorateId = val;
                                  _selectedGovernorateName = name;
                                });
                                await _fetchRegions(val);
                                setSheet(() => _isLoadingRegions = false);
                              }
                            },
                          ),
                        if (_selectedGovernorateId != null) ...[
                          const SizedBox(height: 16),
                          if (_isLoadingRegions)
                            const Center(child: CircularProgressIndicator(color: _primaryTeal))
                          else
                            _sheetDropdown<String>(
                              label: 'المنطقة أو القضاء',
                              icon: Icons.map_rounded,
                              value: _selectedRegionId,
                              items: _regions
                                  .map(
                                    (r) => DropdownMenuItem<String>(
                                      value: r['id'],
                                      child: Text(r['name']),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  final name =
                                      _regions.firstWhere((r) => r['id'] == val)['name'];
                                  setState(() {
                                    _selectedRegionId = val;
                                    _selectedRegionName = name;
                                  });
                                  setSheet(() {});
                                }
                              },
                            ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryTeal,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      if (labelCtrl.text.trim().isNotEmpty) {
                        FirebaseFirestore.instance.collection('sections').add({
                          'label': labelCtrl.text.trim(),
                          'icon': 'category',
                          'color': _primaryTeal.toARGB32(),
                          'order': 99,
                          'governorateId': _selectedGovernorateId,
                          'governorateName': _selectedGovernorateName,
                          'regionId': _selectedRegionId,
                          'regionName': _selectedRegionName,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تمت إضافة القسم بنجاح!',
                              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: _primaryTeal,
                          ),
                        );
                      }
                    },
                    child: Text(
                      'حفظ وإضافة القسم',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String label, IconData icon) => TextField(
        controller: ctrl,
        style: GoogleFonts.ibmPlexSansArabic(color: _darkText, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.ibmPlexSansArabic(color: _darkSubText, fontSize: 13),
          prefixIcon: Icon(icon, color: _darkSubText, size: 20),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primaryTeal, width: 1.5),
          ),
        ),
      );

  Widget _sheetDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) =>
      DropdownButtonFormField<T>(
        initialValue: value,
        dropdownColor: _darkCard,
        style: GoogleFonts.ibmPlexSansArabic(color: _darkText, fontSize: 14),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _darkSubText),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.ibmPlexSansArabic(color: _darkSubText, fontSize: 13),
          prefixIcon: Icon(icon, color: _darkSubText, size: 20),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primaryTeal, width: 1.5),
          ),
        ),
        items: items,
        onChanged: onChanged,
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, _) {
        final bg = isDark ? _darkBg : _lightBg;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: bg,
            body: FadeTransition(
              opacity: _fadeAnim,
              child: AnimatedBuilder(
                animation: _slideAnim,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _slideAnim.value),
                  child: child,
                ),
                child: CustomScrollView(
                  controller: _scrollCtrl,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildSliverHeader(isDark),
                    SliverToBoxAdapter(child: _buildSearchBar(isDark)),
                    SliverToBoxAdapter(child: _buildFilterChips(isDark)),
                    SliverToBoxAdapter(child: _buildMersalExpressBanner(isDark)),
                    SliverToBoxAdapter(child: _buildSectionControlsBar(isDark)),
                    _buildSectionsBody(isDark),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ),
              ),
            ),
            floatingActionButton: _buildFAB(isDark),
          ),
        );
      },
    );
  }

  Widget _buildSliverHeader(bool isDark) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      elevation: 0,
      backgroundColor: isDark ? _darkBg : _lightBg,
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : _primaryTeal.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              color: isDark ? _darkSubText : _primaryDark,
              size: 18,
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _isGridView = !_isGridView);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : _primaryTeal.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                    color: _primaryTeal,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isGridView ? 'عرض قائمة' : 'عرض شبكة',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? _darkText : _lightText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _buildHeaderBackground(isDark),
      ),
    );
  }

  Widget _buildHeaderBackground(bool isDark) {
    return Container(
      color: isDark ? _darkBg : _lightBg,
      child: Stack(
        children: [
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _primaryTeal.withValues(alpha: isDark ? 0.25 : 0.18),
                    _primaryTeal.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accentCyan.withValues(alpha: isDark ? 0.18 : 0.12),
                    _accentCyan.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _shimmerCtrl,
              builder: (_, __) => Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    stops: [
                      (_shimmerCtrl.value - 0.3).clamp(0.0, 1.0),
                      _shimmerCtrl.value.clamp(0.0, 1.0),
                      (_shimmerCtrl.value + 0.3).clamp(0.0, 1.0),
                    ],
                    colors: [
                      Colors.transparent,
                      _primaryTeal.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _primaryTeal.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: _primaryTeal.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _primaryTeal,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'دليل القائم التجاري والخدمي',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          color: isDark ? _accentCyan : _primaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'أقسام ودليل مدار',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: isDark ? _darkText : _lightText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _accentAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _accentAmber.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'مباشر',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: isDark ? _accentAmber : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'كلشي تحتاجه بالقائم من مطاعم ومسواك وخدمات.. تصفح واطلب براحتك!',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5,
                    color: isDark ? _darkSubText : _lightSubText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isDark ? _darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? _darkCardBorder : _lightCardBorder,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          textDirection: TextDirection.rtl,
          onChanged: (v) => setState(() => _searchQuery = v.trim()),
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? _darkText : _lightText,
          ),
          decoration: InputDecoration(
            hintText: 'شنو ببالك؟ ابحث عن قسم، محل، أو خدمة...',
            hintStyle: GoogleFonts.ibmPlexSansArabic(
              color: isDark ? _darkSubText.withValues(alpha: 0.6) : const Color(0xFF8BA5A8),
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: _primaryTeal,
              size: 22,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _searchQuery = '');
                    },
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black12,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _filterChips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _filterChips[index];
          final isSelected = _selectedCategoryFilter == item['id'];

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedCategoryFilter = item['id']);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: [_primaryTeal, _primaryDark])
                    : null,
                color: isSelected ? null : (isDark ? _darkCard : Colors.white),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? _primaryTeal
                      : (isDark ? _darkCardBorder : _lightCardBorder),
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: _primaryTeal.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? _darkSubText : _primaryDark),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item['label'] as String,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? _darkText : _lightText),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMersalExpressBanner(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MersalRequestPage()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      const Color(0xFF0F3836),
                      const Color(0xFF0A2424),
                    ]
                  : [
                      const Color(0xFFE0F7F4),
                      const Color(0xFFEBFBF8),
                    ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _primaryTeal.withValues(alpha: isDark ? 0.35 : 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryTeal.withValues(alpha: isDark ? 0.15 : 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primaryTeal, _accentCyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryTeal.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'محتاج غرض خاص من أي مكان؟',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: isDark ? _darkText : _lightText,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _accentAmber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'مرسال',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? _accentAmber : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'اكتب الغراض وموقعك.. والكابتن يشتريها ويوصلها لباب بيتك فوراً!',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        color: isDark ? _darkSubText : _lightSubText,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryTeal.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: _primaryTeal),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionControlsBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_primaryTeal, _primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? 'نتائج البحث عن "$_searchQuery"'
                    : (_selectedCategoryFilter == 'all'
                        ? 'كافة أقسام مدار المتوفرة'
                        : 'أقسام الفئة المختارة'),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? _darkText : _lightText,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? _darkCard : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? _darkCardBorder : _lightCardBorder,
              ),
            ),
            child: Text(
              _isGridView ? 'نمط الشبكة' : 'نمط القائمة',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: isDark ? _darkSubText : _lightSubText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionsBody(bool isDark) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      sliver: ListenableBuilder(
        listenable: AppLocationService(),
        builder: (context, _) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('sections').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SliverToBoxAdapter(child: _buildSkeletonLoader(isDark));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverToBoxAdapter(child: _buildEmptyState(isDark));
              }

              final allDocs = snapshot.data!.docs.toList()
                ..sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;
                  return (dataA['order'] ?? 999).compareTo(dataB['order'] ?? 999);
                });

              var docs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                final label = (data['label'] ?? '').toString();

                if (_searchQuery.isNotEmpty) {
                  if (!label.toLowerCase().contains(_searchQuery.toLowerCase())) {
                    return false;
                  }
                }

                return _matchesCategory(label, _selectedCategoryFilter);
              }).toList();

              if (docs.isEmpty) {
                return SliverToBoxAdapter(
                  child: _buildEmptyState(
                    isDark,
                    message: _searchQuery.isNotEmpty
                        ? 'ما لكينا أي قسم يطابق "$_searchQuery" يا طيب!'
                        : 'ما متوفرة أقسام بهالتصنيف حالياً.. جرب تختار "الكل"',
                  ),
                );
              }

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseAuth.instance.currentUser == null
                    ? null
                    : FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .snapshots(),
                builder: (context, userSnap) {
                  bool isAdmin = false;
                  if (userSnap.hasData && userSnap.data!.exists) {
                    final role = (userSnap.data!.data() as Map<String, dynamic>)['role'];
                    isAdmin =
                        role == 'admin' || role == 'main_admin' || role == 'limited_admin';
                  }

                  if (_isGridView) {
                    return AnimationLimiter(
                      child: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.96,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            return AnimationConfiguration.staggeredGrid(
                              position: index,
                              columnCount: 2,
                              duration: const Duration(milliseconds: 400),
                              child: ScaleAnimation(
                                scale: 0.92,
                                child: FadeInAnimation(
                                  child: _buildGridSectionCard(
                                    context,
                                    docs[index].id,
                                    data,
                                    isDark,
                                    index,
                                    isAdmin,
                                    docs,
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: docs.length,
                        ),
                      ),
                    );
                  } else {
                    return AnimationLimiter(
                      child: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            return AnimationConfiguration.staggeredList(
                              position: index,
                              duration: const Duration(milliseconds: 380),
                              child: SlideAnimation(
                                horizontalOffset: 25.0,
                                child: FadeInAnimation(
                                  child: _buildListSectionCard(
                                    context,
                                    docs[index].id,
                                    data,
                                    isDark,
                                    index,
                                    isAdmin,
                                    docs,
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: docs.length,
                        ),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildGridSectionCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
    bool isDark,
    int index,
    bool isAdmin,
    List<DocumentSnapshot> allDocs,
  ) {
    final String label = data['label'] ?? 'قسم';
    final String iconName = data['icon'] ?? 'category';
    final int colorValue = data['color'] ?? _primaryTeal.toARGB32();
    final Color secColor = Color(colorValue);
    final bool isLocked = data['isLocked'] == true;
    final String? alertMsg = data['alertMessage']?.toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        splashColor: secColor.withValues(alpha: 0.12),
        highlightColor: secColor.withValues(alpha: 0.05),
        onTap: () => _handleSectionTap(context, docId, label, iconName, secColor, isLocked),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? _darkCard : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? _darkCardBorder : _lightCardBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : secColor.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Positioned(
                  top: -20,
                  left: -20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: secColor.withValues(alpha: isDark ? 0.15 : 0.1),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  secColor.withValues(alpha: isDark ? 0.3 : 0.15),
                                  secColor.withValues(alpha: isDark ? 0.12 : 0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: secColor.withValues(alpha: 0.3),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: secColor.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _buildSectionIcon(label, iconName, secColor, size: 24),
                            ),
                          ),
                          if (isLocked)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.lock_rounded, size: 14, color: Colors.redAccent),
                            )
                          else if (alertMsg != null && alertMsg.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _accentAmber.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.campaign_rounded, size: 14, color: _accentAmber),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: secColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'تصفح',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: secColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isDark ? _darkText : _lightText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        alertMsg != null && alertMsg.isNotEmpty
                            ? alertMsg
                            : _getSectionDefaultSubtitle(label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: alertMsg != null && alertMsg.isNotEmpty
                              ? _accentAmber
                              : (isDark ? _darkSubText : _lightSubText),
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(height: 8),
                        _buildGridAdminActions(docId, data, index, allDocs, isDark),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListSectionCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
    bool isDark,
    int index,
    bool isAdmin,
    List<DocumentSnapshot> allDocs,
  ) {
    final String label = data['label'] ?? 'قسم';
    final String iconName = data['icon'] ?? 'category';
    final int colorValue = data['color'] ?? _primaryTeal.toARGB32();
    final Color secColor = Color(colorValue);
    final bool isLocked = data['isLocked'] == true;
    final String? alertMsg = data['alertMessage']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          splashColor: secColor.withValues(alpha: 0.12),
          highlightColor: secColor.withValues(alpha: 0.05),
          onTap: () => _handleSectionTap(context, docId, label, iconName, secColor, isLocked),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? _darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? _darkCardBorder : _lightCardBorder,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [secColor, secColor.withValues(alpha: 0.3)],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 18, 12),
                    child: Row(
                      children: [
                        if (isAdmin) ...[
                          _adminControlPanel(docId, data, index, allDocs, isDark),
                          const SizedBox(width: 10),
                          Container(width: 1, height: 40, color: Colors.white10),
                          const SizedBox(width: 10),
                        ],
                        if (!isAdmin)
                          Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: isDark
                                ? _darkSubText.withValues(alpha: 0.4)
                                : const Color(0xFFB0C4C6),
                            size: 14,
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (isLocked)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Icon(Icons.lock_rounded,
                                          color: Colors.redAccent, size: 14),
                                    ),
                                  Expanded(
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? _darkText : _lightText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                alertMsg != null && alertMsg.isNotEmpty
                                    ? alertMsg
                                    : _getSectionDefaultSubtitle(label),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: alertMsg != null && alertMsg.isNotEmpty
                                      ? _accentAmber
                                      : (isDark ? _darkSubText : _lightSubText),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                secColor.withValues(alpha: isDark ? 0.3 : 0.15),
                                secColor.withValues(alpha: isDark ? 0.12 : 0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: secColor.withValues(alpha: 0.25),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: secColor.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _buildSectionIcon(label, iconName, secColor, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSectionTap(
    BuildContext context,
    String docId,
    String label,
    String iconName,
    Color secColor,
    bool isLocked,
  ) async {
    HapticFeedback.lightImpact();

    final user = FirebaseAuth.instance.currentUser;
    bool isAdminRole = false;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final role = doc.data()?['role'];
        isAdminRole = role == 'admin' || role == 'main_admin' || role == 'limited_admin';
      }
    }

    if (!mounted) return;

    if (isLocked && !isAdminRole) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Text(
              'عيني، القسم مقفول مؤقتاً',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: Text(
              'هذا القسم حالياً بطور الصيانة والتحديث من قبل إدارة مدار، راح يرجع يشتغل بأقرب وقت!',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, height: 1.5),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'صار، افتهمت',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    final lowerLabel = label.toLowerCase();
    if (lowerLabel.contains('دروب')) {
      if (context.mounted) {
        _showComingSoonDialog(context);
      }
      return;
    }

    if (!context.mounted) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => isAdminRole
            ? SectionAdminPage(
                sectionId: docId,
                sectionLabel: label,
                sectionIcon: sectionIconFromString(iconName),
                sectionColor: secColor,
                isAdmin: true,
              )
            : SectionUserViewPage(
                sectionId: docId,
                sectionLabel: label,
                sectionIcon: sectionIconFromString(iconName),
                sectionColor: secColor,
              ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
  }

  String _getSectionDefaultSubtitle(String label) {
    final l = label.toLowerCase();
    if (l.contains('مطعم') || l.contains('أكل')) return 'أشهى الوجبات والمطاعم';
    if (l.contains('طبي') || l.contains('صحة') || l.contains('دكتور')) return 'أطباء وصيدليات القائم';
    if (l.contains('سوق') || l.contains('تسوق') || l.contains('ماركت')) return 'محلات ومسواك يومي';
    if (l.contains('تكسي') || l.contains('توصيل')) return 'كباتن وسفريات سريعة';
    if (l.contains('مهن') || l.contains('فني') || l.contains('صيانة')) return 'فنيين وحرفيين معتمدين';
    if (l.contains('عقار') || l.contains('بيت')) return 'شقق ودور وأراضي للبيع';
    return 'تصفح المحلات والخدمات';
  }

  Widget _buildSectionIcon(String label, String iconName, Color secColor, {double size = 24}) {
    IconData finalIcon = sectionIconFromString(iconName);

    if (finalIcon == Icons.category || finalIcon == Icons.help_outline) {
      final l = label.toLowerCase();
      if (l.contains('طبي') || l.contains('صحة') || l.contains('دكتور')) {
        finalIcon = Icons.medical_services_rounded;
      } else if (l.contains('مطعم') || l.contains('أكل') || l.contains('غداء')) {
        finalIcon = Icons.restaurant_rounded;
      } else if (l.contains('سوق') || l.contains('تسوق') || l.contains('مول') || l.contains('ماركت')) {
        finalIcon = Icons.shopping_bag_rounded;
      } else if (l.contains('تكسي') || l.contains('توصيل') || l.contains('نقل')) {
        finalIcon = Icons.local_taxi_rounded;
      } else if (l.contains('مهن') || l.contains('فني') || l.contains('تصليح')) {
        finalIcon = Icons.handyman_rounded;
      } else if (l.contains('عقار') || l.contains('بيت') || l.contains('إيجار')) {
        finalIcon = Icons.home_work_rounded;
      } else if (l.contains('حلويات') || l.contains('كيك')) {
        finalIcon = Icons.cake_rounded;
      } else if (l.contains('موبايل') || l.contains('إلكترونيات')) {
        finalIcon = Icons.smartphone_rounded;
      }
    }

    return Icon(finalIcon, color: secColor, size: size);
  }

  Widget _adminControlPanel(
    String docId,
    Map<String, dynamic> data,
    int index,
    List<DocumentSnapshot> allDocs,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _adminActionBtn(Icons.arrow_upward_rounded, Colors.blue, () => _moveSection(index, -1, allDocs)),
            const SizedBox(width: 6),
            _adminActionBtn(Icons.arrow_downward_rounded, Colors.blue, () => _moveSection(index, 1, allDocs)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _adminActionBtn(
              data['isLocked'] == true ? Icons.lock_open_rounded : Icons.lock_rounded,
              data['isLocked'] == true ? Colors.green : Colors.red,
              () => _toggleSectionLock(docId, data['isLocked'] ?? false),
            ),
            const SizedBox(width: 6),
            _adminActionBtn(Icons.campaign_rounded, Colors.amber, () => _editSectionAlert(docId, data['alertMessage'] ?? '')),
          ],
        ),
      ],
    );
  }

  Widget _buildGridAdminActions(
    String docId,
    Map<String, dynamic> data,
    int index,
    List<DocumentSnapshot> allDocs,
    bool isDark,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _adminActionBtn(Icons.arrow_upward_rounded, Colors.blue, () => _moveSection(index, -1, allDocs)),
        _adminActionBtn(Icons.arrow_downward_rounded, Colors.blue, () => _moveSection(index, 1, allDocs)),
        _adminActionBtn(
          data['isLocked'] == true ? Icons.lock_open_rounded : Icons.lock_rounded,
          data['isLocked'] == true ? Colors.green : Colors.red,
          () => _toggleSectionLock(docId, data['isLocked'] ?? false),
        ),
        _adminActionBtn(Icons.campaign_rounded, Colors.amber, () => _editSectionAlert(docId, data['alertMessage'] ?? '')),
      ],
    );
  }

  Widget _adminActionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, color: color, size: 15),
      ),
    );
  }

  Future<void> _moveSection(int index, int direction, List<DocumentSnapshot> allDocs) async {
    int targetIndex = index + direction;
    if (targetIndex < 0 || targetIndex >= allDocs.length) return;

    final currentDoc = allDocs[index];
    final targetDoc = allDocs[targetIndex];

    final currentOrder = (currentDoc.data() as Map<String, dynamic>)['order'] ?? index;
    final targetOrder = (targetDoc.data() as Map<String, dynamic>)['order'] ?? targetIndex;

    await FirebaseFirestore.instance.collection('sections').doc(currentDoc.id).update({'order': targetOrder});
    await FirebaseFirestore.instance.collection('sections').doc(targetDoc.id).update({'order': currentOrder});
    HapticFeedback.mediumImpact();
  }

  Future<void> _toggleSectionLock(String docId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('sections').doc(docId).update({'isLocked': !currentStatus});
    HapticFeedback.mediumImpact();
  }

  void _editSectionAlert(String docId, String currentMsg) {
    final ctrl = TextEditingController(text: currentMsg);
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('تنبيه أو إعلان القسم', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16)),
          content: TextField(
            controller: ctrl,
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'اكتب نص التنبيه أو العرض هنا...',
              hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('sections')
                    .doc(docId)
                    .update({'alertMessage': ctrl.text.trim()});
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primaryTeal, foregroundColor: Colors.white),
              child: Text('حفظ التنبيه', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader(bool isDark) {
    return Column(
      children: List.generate(
        6,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AnimatedBuilder(
            animation: _shimmerCtrl,
            builder: (_, __) => Container(
              height: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  stops: [
                    (_shimmerCtrl.value - 0.35).clamp(0.0, 1.0),
                    _shimmerCtrl.value.clamp(0.0, 1.0),
                    (_shimmerCtrl.value + 0.35).clamp(0.0, 1.0),
                  ],
                  colors: isDark
                      ? [
                          const Color(0xFF0C1D20),
                          const Color(0xFF16383D),
                          const Color(0xFF0C1D20),
                        ]
                      : [
                          const Color(0xFFEAF2F2),
                          Colors.white,
                          const Color(0xFFEAF2F2),
                        ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, {String message = 'ما متوفرة أقسام حالياً يا طيب!'}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 85,
            height: 85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? _darkCard : Colors.white,
              border: Border.all(
                color: _primaryTeal.withValues(alpha: isDark ? 0.3 : 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryTeal.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: _primaryTeal,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: isDark ? _darkSubText : _lightSubText,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB(bool isDark) {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<DocumentSnapshot>(
      stream: user == null
          ? null
          : FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        bool isAdmin = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          final role = (snapshot.data!.data() as Map<String, dynamic>)['role'];
          isAdmin = role == 'admin' || role == 'main_admin' || role == 'limited_admin';
        }

        if (isAdmin) {
          return Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_primaryTeal, _primaryDark]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _primaryTeal.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _showAddSectionDialog();
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                'إضافة قسم',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? _primaryTeal.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _primaryTeal.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: FloatingActionButton.extended(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MersalRequestPage()),
                  );
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                icon: const Icon(Icons.two_wheeler_rounded, color: _primaryTeal, size: 22),
                label: Text(
                  'طلب مرسال',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: _primaryTeal,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
