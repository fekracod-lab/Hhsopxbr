import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'page_items_screen.dart';
import 'package:dalal_alqaim/features/home/pages/home_page.dart';

// --- Palette requested by the user ---
const Color primaryColor = Color(0xFF26A69A);
const Color accentColor = Color(0xFF00796B);
const Color backgroundColor = Color(0xFFFFFFFF);
const Color textColor = Color(0xFF333333); // لون النص الأساسي
const Color hintColor = Color(0xFF9E9E9E); // لون النص التلميحي
const Color subTextColor = Color(0xFF757575); // لون النص الثانوي
const Color surfaceColor = Color(0xFFF8F9FA); // لون السطح

// Dark Mode Palette
const Color darkBackground = Color(0xFF07191A);
const Color darkSurface = Color(0xFF0F2323);
const Color darkCard = Color(0xFF113033);
const Color darkText = Color(0xFFE0F2F1);
const Color darkSubText = Color(0xFF80CBC4);
const Color darkHint = Color(0xFF4DB6AC);

class SectionUserViewPage extends StatefulWidget {
  final String sectionId;
  final String sectionLabel;
  final IconData sectionIcon;
  final Color sectionColor;
  final bool isAdmin;

  const SectionUserViewPage({
    super.key,
    required this.sectionId,
    required this.sectionLabel,
    required this.sectionIcon,
    required this.sectionColor,
    this.isAdmin = false,
  });

  @override
  State<SectionUserViewPage> createState() => _SectionAdminPageState();
}

class _SectionAdminPageState extends State<SectionUserViewPage> with TickerProviderStateMixin {
  late TextEditingController _labelController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Governorate and Region
  String? selectedGovernorateId;
  String? selectedGovernorateName;
  String? selectedRegionId;
  String? selectedRegionName;
  List<Map<String, dynamic>> governorates = [];
  List<Map<String, dynamic>> regions = [];
  bool isLoadingGovernorates = true;
  bool isLoadingRegions = false;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.sectionLabel);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    // fade animation driven by _animationController
    Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack));
    _animationController.forward();
    _fetchSectionData();
    _fetchGovernorates();
  }

  Future<void> _fetchSectionData() async {
    final doc = await FirebaseFirestore.instance.collection('sections').doc(widget.sectionId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        selectedGovernorateId = data['governorateId'];
        selectedGovernorateName = data['governorateName'];
        selectedRegionId = data['regionId'];
        selectedRegionName = data['regionName'];
      });
      if (selectedGovernorateId != null) {
        _fetchRegions(selectedGovernorateId!, isInitial: true);
      }
    }
  }

  Future<void> _fetchGovernorates() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isLoadingGovernorates = false);
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
      final docs = snap.docs.toList();
      // Sort client-side to avoid index requirement
      docs.sort((a, b) {
        final nameA = (a.data() as Map<String, dynamic>?)?['name'] ?? '';
        final nameB = (b.data() as Map<String, dynamic>?)?['name'] ?? '';
        return nameA.compareTo(nameB);
      });

      setState(() {
        governorates =
            docs.map((d) {
              final data = d.data() as Map<String, dynamic>? ?? {};
              return {'id': d.id, 'name': data['name'] ?? ''};
            }).toList();
        isLoadingGovernorates = false;

        // If limited admin and governorate matches, ensure it's selected
        if (role == 'limited_admin' && governorates.length == 1 && selectedGovernorateId == null) {
          selectedGovernorateId = governorates[0]['id'];
          selectedGovernorateName = governorates[0]['name'];
          _fetchRegions(selectedGovernorateId!, isInitial: true);
        }
      });
    } catch (e) {
      debugPrint('Error fetching governorates: $e');
      setState(() => isLoadingGovernorates = false);
    }
  }

  Future<void> _fetchRegions(String govId, {bool isInitial = false}) async {
    if (!isInitial) {
      setState(() {
        isLoadingRegions = true;
        regions = [];
        selectedRegionId = null;
        selectedRegionName = null;
      });
    } else {
      setState(() => isLoadingRegions = true);
    }

    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('governorates')
              .doc(govId)
              .collection('regions')
              .where('isActive', isEqualTo: true)
              .get();
      final docs = snap.docs.toList();
      docs.sort((a, b) {
        final nameA = (a.data())['name'] ?? '';
        final nameB = (b.data())['name'] ?? '';
        return nameA.compareTo(nameB);
      });
      setState(() {
        regions =
            docs.map((d) {
              final data = d.data();
              return {'id': d.id, 'name': data['name'] ?? ''};
            }).toList();
        isLoadingRegions = false;
      });
    } catch (e) {
      debugPrint('Error fetching regions: $e');
      setState(() => isLoadingRegions = false);
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _updateSection() async {
    await FirebaseFirestore.instance.collection('sections').doc(widget.sectionId).update({
      'label': _labelController.text.trim(),
      'governorateId': selectedGovernorateId,
      'governorateName': selectedGovernorateName,
      'regionId': selectedRegionId,
      'regionName': selectedRegionName,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تحديث القسم بنجاح!', style: TextStyle()),
        backgroundColor: primaryColor,
      ),
    );
    setState(() {});
  }

  void _safePopOrGoHome() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(
        context,
      ).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomePage()), (route) => false);
    }
  }

  Future<void> _deleteSection() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: isDark ? darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'تأكيد حذف القسم',
              style: TextStyle(
                color: isDark ? darkText : textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'متأكد تريد تحذف هذا القسم بالكامل؟ سيتم حذف جميع الصفحات والعناصر بداخله!',
              style: TextStyle(color: isDark ? darkSubText : subTextColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'إلغاء',
                  style: TextStyle(color: isDark ? darkHint : hintColor),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'حذف',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance.collection('sections').doc(widget.sectionId).delete();
    if (!mounted) return;
    _safePopOrGoHome();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حذف القسم!', style: TextStyle()),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showEditDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: isDark ? darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'تعديل القسم',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? darkText : textColor,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _labelController,
                    style: TextStyle(color: isDark ? darkText : textColor),
                    decoration: InputDecoration(
                      labelText: 'اسم القسم',
                      labelStyle: TextStyle(color: isDark ? darkHint : hintColor),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? darkSurface : Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  StatefulBuilder(
                    builder: (context, setDialogState) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLoadingGovernorates)
                            const CircularProgressIndicator()
                          else
                            DropdownButtonFormField<String>(
                              initialValue: selectedGovernorateId,
                              dropdownColor: isDark ? darkCard : Colors.white,
                              style: TextStyle(
                                color: isDark ? darkText : textColor,
                              ),
                              decoration: InputDecoration(
                                labelText: 'المحافظة',
                                labelStyle: TextStyle(color: isDark ? darkHint : hintColor),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: isDark ? darkSurface : Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: primaryColor),
                                ),
                              ),
                              items:
                                  governorates.map((g) {
                                    return DropdownMenuItem<String>(
                                      value: g['id'],
                                      child: Text(g['name']),
                                    );
                                  }).toList(),
                              onChanged: (val) async {
                                if (val != null) {
                                  setDialogState(() => isLoadingRegions = true);
                                  final name =
                                      governorates.firstWhere((g) => g['id'] == val)['name'];
                                  setState(() {
                                    selectedGovernorateId = val;
                                    selectedGovernorateName = name;
                                  });
                                  await _fetchRegions(val);
                                  setDialogState(() => isLoadingRegions = false);
                                }
                              },
                            ),
                          const SizedBox(height: 16),
                          if (selectedGovernorateId != null)
                            if (isLoadingRegions)
                              const CircularProgressIndicator()
                            else
                              DropdownButtonFormField<String>(
                                initialValue: selectedRegionId,
                                dropdownColor: isDark ? darkCard : Colors.white,
                                style: TextStyle(
                                  color: isDark ? darkText : textColor,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'المنطقة',
                                  labelStyle: TextStyle(color: isDark ? darkHint : hintColor),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark ? darkSurface : Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: primaryColor),
                                  ),
                                ),
                                items:
                                    regions.map((r) {
                                      return DropdownMenuItem<String>(
                                        value: r['id'],
                                        child: Text(r['name']),
                                      );
                                    }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    final name = regions.firstWhere((r) => r['id'] == val)['name'];
                                    setState(() {
                                      selectedRegionId = val;
                                      selectedRegionName = name;
                                    });
                                    setDialogState(() {});
                                  }
                                },
                              ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'إلغاء',
                  style: TextStyle(color: isDark ? darkHint : hintColor),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await _updateSection();
                  if (!mounted) return;
                  navigator.pop();
                },
                child: const Text(
                  'حفظ',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showAddPageDialog() {
    final pageNameController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: isDark ? darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'إضافة صفحة جديدة',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? darkText : textColor,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pageNameController,
                    style: TextStyle(color: isDark ? darkText : textColor),
                    decoration: InputDecoration(
                      labelText: 'اسم الصفحة',
                      labelStyle: TextStyle(color: isDark ? darkHint : hintColor),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? darkSurface : Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  StatefulBuilder(
                    builder: (context, setDialogState) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLoadingGovernorates)
                            const CircularProgressIndicator()
                          else
                            DropdownButtonFormField<String>(
                              initialValue: selectedGovernorateId,
                              dropdownColor: isDark ? darkCard : Colors.white,
                              style: TextStyle(
                                color: isDark ? darkText : textColor,
                              ),
                              decoration: InputDecoration(
                                labelText: 'المحافظة',
                                labelStyle: TextStyle(color: isDark ? darkHint : hintColor),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: isDark ? darkSurface : Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: primaryColor),
                                ),
                              ),
                              items:
                                  governorates.map((g) {
                                    return DropdownMenuItem<String>(
                                      value: g['id'],
                                      child: Text(g['name']),
                                    );
                                  }).toList(),
                              onChanged: (val) async {
                                if (val != null) {
                                  setDialogState(() => isLoadingRegions = true);
                                  final name =
                                      governorates.firstWhere((g) => g['id'] == val)['name'];
                                  setState(() {
                                    selectedGovernorateId = val;
                                    selectedGovernorateName = name;
                                  });
                                  await _fetchRegions(val);
                                  setDialogState(() => isLoadingRegions = false);
                                }
                              },
                            ),
                          const SizedBox(height: 16),
                          if (selectedGovernorateId != null)
                            if (isLoadingRegions)
                              const CircularProgressIndicator()
                            else
                              DropdownButtonFormField<String>(
                                initialValue: selectedRegionId,
                                dropdownColor: isDark ? darkCard : Colors.white,
                                style: TextStyle(
                                  color: isDark ? darkText : textColor,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'المنطقة',
                                  labelStyle: TextStyle(color: isDark ? darkHint : hintColor),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark ? darkSurface : Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: primaryColor),
                                  ),
                                ),
                                items:
                                    regions.map((r) {
                                      return DropdownMenuItem<String>(
                                        value: r['id'],
                                        child: Text(r['name']),
                                      );
                                    }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    final name = regions.firstWhere((r) => r['id'] == val)['name'];
                                    setState(() {
                                      selectedRegionId = val;
                                      selectedRegionName = name;
                                    });
                                    setDialogState(() {});
                                  }
                                },
                              ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'إلغاء',
                  style: TextStyle(color: isDark ? darkHint : hintColor),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  if (pageNameController.text.trim().isNotEmpty) {
                    final navigator = Navigator.of(context);
                    await FirebaseFirestore.instance
                        .collection('sections')
                        .doc(widget.sectionId)
                        .collection('pages')
                        .add({
                          'name': pageNameController.text.trim(),
                          'createdAt': FieldValue.serverTimestamp(),
                          'governorateId': selectedGovernorateId,
                          'governorateName': selectedGovernorateName,
                          'regionId': selectedRegionId,
                          'regionName': selectedRegionName,
                        });
                    if (!mounted) return;
                    navigator.pop();
                    setState(() {});
                  }
                },
                child: const Text(
                  'إضافة',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _safePopOrGoHome();
      },
      child: Scaffold(
        backgroundColor: isDark ? darkBackground : surfaceColor,
        floatingActionButton:
            widget.isAdmin
                ? FloatingActionButton.extended(
                  onPressed: _showAddPageDialog,
                  backgroundColor: widget.sectionColor,
                  elevation: 8,
                  highlightElevation: 2,
                  icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                  label: const Text(
                    'إضافة صفحة',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
                : null,
        body: Stack(
          children: [
            // Decorative background elements
            Positioned.fill(
              child: CustomPaint(
                painter: _ModernBackgroundPainter(isDark: isDark, accentColor: widget.sectionColor),
              ),
            ),

            SafeArea(
              top: false,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 1. Enhanced Sliver App Bar
                  SliverAppBar(
                    expandedHeight: 240.0,
                    floating: false,
                    pinned: true,
                    stretch: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leadingWidth: 70,
                    leading: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.white70,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        onPressed: _safePopOrGoHome,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    actions:
                        widget.isAdmin
                            ? [
                              _buildHeaderAction(
                                icon: Icons.edit_note_rounded,
                                color: primaryColor,
                                onPressed: _showEditDialog,
                                isDark: isDark,
                              ),
                              _buildHeaderAction(
                                icon: Icons.delete_sweep_rounded,
                                color: Colors.redAccent,
                                onPressed: _deleteSection,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                            ]
                            : null,
                    flexibleSpace: FlexibleSpaceBar(
                      stretchModes: const [
                        StretchMode.zoomBackground,
                        StretchMode.blurBackground,
                        StretchMode.fadeTitle,
                      ],
                      background: _buildHeaderBackground(isDark),
                      centerTitle: true,
                      title: _buildHeaderTitle(isDark),
                      titlePadding: const EdgeInsets.only(bottom: 20),
                    ),
                  ),

                  // 2. Search Section
                  SliverToBoxAdapter(child: _buildSearchSection(isDark)),

                  // 3. Status Bar (Pages Count)
                  SliverToBoxAdapter(child: _buildStatusRow(isDark)),

                  // 4. Pages List
                  StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('sections')
                            .doc(widget.sectionId)
                            .collection('pages')
                            .orderBy('createdAt', descending: false)
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }

                      var pages = snapshot.data?.docs ?? [];
                      if (_searchQuery.isNotEmpty) {
                        pages =
                            pages.where((doc) {
                              final name =
                                  ((doc.data() as Map)['name'] ?? '').toString().toLowerCase();
                              return name.contains(_searchQuery.toLowerCase());
                            }).toList();
                      }

                      if (pages.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(isDark),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final doc = pages[index];
                            final data = doc.data() as Map<String, dynamic>;
                            return _buildPageCardAnimated(doc.id, data, isDark, index);
                          }, childCount: pages.length),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBackground(bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Main gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  isDark
                      ? [darkBackground, darkSurface, darkCard]
                      : [widget.sectionColor, Color.lerp(widget.sectionColor, Colors.black, 0.2)!],
            ),
          ),
        ),
        // Decorative circles
        Positioned(
          top: -50,
          right: -50,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: -30,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
          ),
        ),
        // Big Icon in background
        Positioned(
          right: 20,
          bottom: 40,
          child: Opacity(
            opacity: 0.1,
            child: Icon(widget.sectionIcon, size: 160, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderTitle(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.sectionIcon, color: Colors.white, size: 14),
              const SizedBox(width: 8),
              Text(
                widget.sectionLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(icon: Icon(icon, color: Colors.white, size: 20), onPressed: onPressed),
    );
  }

  Widget _buildSearchSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 58,
            decoration: BoxDecoration(
              color: isDark ? darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(color: isDark ? darkText : textColor),
              decoration: InputDecoration(
                hintText: 'ابحث عن صفحة محددة...',
                hintStyle: TextStyle(
                  color: isDark ? darkHint : hintColor,
                  fontSize: 13,
                ),
                prefixIcon: Icon(Icons.search_rounded, color: widget.sectionColor),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: widget.sectionColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'الصفحات المتاحة',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? darkText : textColor,
            ),
          ),
          const Spacer(),
          if (selectedGovernorateName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: widget.sectionColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                selectedGovernorateName!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: widget.sectionColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPageCardAnimated(String id, Map<String, dynamic> data, bool isDark, int index) {
    return FadeTransition(
      opacity: _animationController,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval((index * 0.05).clamp(0.0, 1.0), 1.0, curve: Curves.easeOutQuart),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Material(
            color: isDark ? darkCard : Colors.white,
            borderRadius: BorderRadius.circular(22),
            elevation: 0,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PageItemsScreen(
                      sectionId: widget.sectionId,
                      pageId: id,
                      pageName: data['name'] ?? '',
                      sectionColor: widget.sectionColor,
                      sectionIcon: widget.sectionIcon,
                      isAdmin: widget.isAdmin,
                    ),
                  ),
                );
              },
              onLongPress: widget.isAdmin ? () => _showPageOptions(id, data['name']) : null,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.sectionColor.withValues(alpha: 0.15),
                            widget.sectionColor.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(widget.sectionIcon, color: widget.sectionColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['name'] ?? 'بدون اسم',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isDark ? darkText : textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'عرض التفاصيل والمنتجات',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? darkSubText : subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: isDark ? darkHint : Colors.grey.shade300,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPageOptions(String pageId, String? currentName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDark ? darkCard : Colors.white,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'خيارات الصفحة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? darkText : textColor,
                  ),
                ),
                const SizedBox(height: 20),
                _buildOptionTile(
                  icon: Icons.edit_rounded,
                  label: 'تعديل الاسم',
                  color: primaryColor,
                  onTap: () => Navigator.pop(ctx, 'edit'),
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildOptionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'حذف الصفحة',
                  color: Colors.redAccent,
                  onTap: () => Navigator.pop(ctx, 'delete'),
                  isDark: isDark,
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
    );

    if (action == 'edit') {
      final controller = TextEditingController(text: currentName ?? '');
      if (!mounted) return;
      final result = await showDialog<String>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: isDark ? darkCard : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('تعديل اسم الصفحة', style: TextStyle()),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor:
                      isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  labelText: 'اسم الصفحة الجديد',
                  labelStyle: const TextStyle(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء', style: TextStyle()),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'حفظ',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
      );

      if (result != null && result.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('sections')
            .doc(widget.sectionId)
            .collection('pages')
            .doc(pageId)
            .update({'name': result});
        if (!mounted) return;
        setState(() {});
      }
    } else if (action == 'delete') {
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: isDark ? darkCard : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'تأكيد الحذف',
                style: TextStyle(color: Colors.redAccent),
              ),
              content: const Text(
                'متأكد تريد تحذف هذه الصفحة؟ سيتم حذف جميع العناصر بداخلها!',
                style: TextStyle(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء', style: TextStyle()),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'رغم ذلك، احذفها',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
      );

      if (confirm == true) {
        // First delete items
        final items =
            await FirebaseFirestore.instance
                .collection('sections')
                .doc(widget.sectionId)
                .collection('pages')
                .doc(pageId)
                .collection('items')
                .get();
        for (final item in items.docs) {
          await item.reference.delete();
        }
        // Then delete page
        await FirebaseFirestore.instance
            .collection('sections')
            .doc(widget.sectionId)
            .collection('pages')
            .doc(pageId)
            .delete();
        if (mounted) setState(() {});
      }
    }
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? darkText : textColor,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark ? Colors.white24 : Colors.black12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_motion_rounded,
            size: 80,
            color: widget.sectionColor.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد صفحات في هذا القسم حالياً',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? darkSubText : subTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernBackgroundPainter extends CustomPainter {
  final bool isDark;
  final Color accentColor;

  _ModernBackgroundPainter({required this.isDark, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Top Right Glow
    final rect = Rect.fromLTWH(size.width * 0.6, -100, 400, 400);
    final gradient = RadialGradient(
      colors: [
        accentColor.withValues(alpha: isDark ? 0.08 : 0.05),
        accentColor.withValues(alpha: 0.0),
      ],
    );
    paint.shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);

    // Bottom Left Glow
    final rect2 = Rect.fromLTWH(-150, size.height * 0.7, 300, 300);
    final gradient2 = RadialGradient(
      colors: [
        accentColor.withValues(alpha: isDark ? 0.06 : 0.03),
        accentColor.withValues(alpha: 0.0),
      ],
    );
    paint.shader = gradient2.createShader(rect2);
    canvas.drawRect(rect2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
