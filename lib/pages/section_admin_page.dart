import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'page_items_screen.dart';
import 'package:dalal_alqaim/features/home/pages/home_page.dart';
import 'dart:math' as math;

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

class SectionAdminPage extends StatefulWidget {
  final String sectionId;
  final String sectionLabel;
  final IconData sectionIcon;
  final Color sectionColor;
  final bool isAdmin;

  const SectionAdminPage({
    super.key,
    required this.sectionId,
    required this.sectionLabel,
    required this.sectionIcon,
    required this.sectionColor,
    this.isAdmin = false,
  });

  @override
  State<SectionAdminPage> createState() => _SectionAdminPageState();
}

class _SectionAdminPageState extends State<SectionAdminPage> with TickerProviderStateMixin {
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
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _safePopOrGoHome();
      },
      child: Stack(
        children: [
          // خلفية متدرجة
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors:
                    isDark
                        ? [darkBackground, darkSurface, darkCard]
                        : [surfaceColor, Colors.white, surfaceColor],
              ),
            ),
          ),

          // رسومات خلفية
          Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _BackgroundPainter(isDark: isDark))),
          ),

          Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton:
                widget.isAdmin
                    ? FloatingActionButton.extended(
                      onPressed: _showAddPageDialog,
                      backgroundColor: primaryColor,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'إضافة صفحة',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                    : null,
            body: SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 1. Sliver App Bar
                  SliverAppBar(
                    expandedHeight: 120.0,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? darkCard.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: isDark ? darkText : Colors.black87,
                          size: 20,
                        ),
                        onPressed: _safePopOrGoHome,
                      ),
                    ),
                    flexibleSpace: Container(
                      decoration: BoxDecoration(
                        gradient:
                            isDark
                                ? LinearGradient(
                                  colors: [
                                    darkBackground.withValues(alpha: 0.95),
                                    darkBackground.withValues(alpha: 0.8),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                )
                                : LinearGradient(
                                  colors: [
                                    surfaceColor.withValues(alpha: 0.9),
                                    surfaceColor.withValues(alpha: 0.7),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                      ),
                      child: FlexibleSpaceBar(
                        centerTitle: true,
                        titlePadding: const EdgeInsets.only(bottom: 16),
                        title: Text(
                          widget.sectionLabel,
                          style: TextStyle(
                            color: isDark ? darkText : const Color(0xFF2D2D2D),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    actions:
                        widget.isAdmin
                            ? [
                              _buildAppBarAction(
                                icon: Icons.edit,
                                color: primaryColor,
                                tooltip: 'تعديل القسم',
                                onPressed: _showEditDialog,
                                isDark: isDark,
                              ),
                              _buildAppBarAction(
                                icon: Icons.delete,
                                color: Colors.red,
                                tooltip: 'حذف القسم',
                                onPressed: _deleteSection,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                            ]
                            : null,
                  ),

                  // 2. Search Bar
                  SliverToBoxAdapter(
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.5),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Container(
                          height: 55,
                          decoration: BoxDecoration(
                            color: isDark ? darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                            style: TextStyle(
                              color: isDark ? darkText : textColor,
                            ),
                            decoration: InputDecoration(
                              hintText: 'ابحث عن صفحة...',
                              hintStyle: TextStyle(
                                color: isDark ? darkHint : Colors.grey[400],
                                fontSize: 16,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: isDark ? darkHint : Colors.grey,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. Pages List
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
                        return const SliverToBoxAdapter(
                          child: Center(child: CircularProgressIndicator(color: primaryColor)),
                        );
                      }
                      if (snapshot.hasError) {
                        return SliverToBoxAdapter(
                          child: Center(
                            child: Text(
                              'حدث خطأ: ${snapshot.error}',
                              style: TextStyle(color: isDark ? darkText : textColor),
                            ),
                          ),
                        );
                      }

                      var pages = snapshot.data?.docs ?? [];

                      // Client-side filtering
                      if (_searchQuery.isNotEmpty) {
                        pages =
                            pages.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final name = (data['name'] ?? '').toString().toLowerCase();
                              return name.contains(_searchQuery.toLowerCase());
                            }).toList();
                      }

                      if (pages.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 50),
                                Icon(
                                  Icons.folder_open,
                                  size: 64,
                                  color:
                                      isDark ? darkHint.withValues(alpha: 0.3) : Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'لا توجد صفحات هنا',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDark ? darkSubText : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.all(20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final doc = pages[index];
                            final page = doc.data() as Map<String, dynamic>;
                            return FadeTransition(
                              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                                CurvedAnimation(
                                  parent: _animationController,
                                  curve: Interval(
                                    (index * 0.1).clamp(0.0, 1.0),
                                    1.0,
                                    curve: Curves.easeOut,
                                  ),
                                ),
                              ),
                              child: _buildPageCard(doc.id, page, isDark),
                            );
                          }, childCount: pages.length),
                        ),
                      );
                    },
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? darkCard.withValues(alpha: 0.8) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: IconButton(icon: Icon(icon, color: color), onPressed: onPressed, tooltip: tooltip),
    );
  }

  Widget _buildPageCard(String pageId, Map<String, dynamic> pageData, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PageItemsScreen(
                  sectionId: widget.sectionId,
                  pageId: pageId,
                  pageName: pageData['name'] ?? '',
                  sectionColor: widget.sectionColor,
                  sectionIcon: widget.sectionIcon,
                  isAdmin: widget.isAdmin,
                ),
              ),
            );
          },
          onLongPress: widget.isAdmin ? () => _showPageOptions(pageId, pageData['name']) : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.sectionColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.sectionIcon, color: widget.sectionColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    pageData['name'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? darkText : const Color(0xFF2D2D2D),
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isDark ? darkHint : Colors.grey[400],
                  size: 18,
                ),
              ],
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.edit, color: primaryColor),
                  title: Text(
                    'تعديل اسم الصفحة',
                    style: TextStyle(color: isDark ? darkText : textColor),
                  ),
                  onTap: () => Navigator.pop(ctx, 'edit'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    'حذف الصفحة',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () => Navigator.pop(ctx, 'delete'),
                ),
                const SizedBox(height: 10),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'تعديل اسم الصفحة',
                style: TextStyle(color: isDark ? darkText : textColor),
              ),
              content: TextField(
                controller: controller,
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
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
                  onPressed: () => Navigator.pop(ctx, controller.text.trim()),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'تأكيد الحذف',
                style: TextStyle(color: isDark ? darkText : textColor),
              ),
              content: Text(
                'متأكد تريد تحذف هذه الصفحة؟ سيتم حذف جميع العناصر بداخلها!',
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

      if (confirm == true) {
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
        await FirebaseFirestore.instance
            .collection('sections')
            .doc(widget.sectionId)
            .collection('pages')
            .doc(pageId)
            .delete();
        if (mounted) {
          setState(() {});
        }
      }
    }
  }
}

class _BackgroundPainter extends CustomPainter {
  final bool isDark;

  _BackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.fill
          ..strokeCap = StrokeCap.round;

    final path = Path();

    // الموجة الأولى
    paint.color =
        isDark ? primaryColor.withValues(alpha: 0.05) : primaryColor.withValues(alpha: 0.05);
    path.moveTo(0, size.height * 0.3);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.35,
      size.width * 0.5,
      size.height * 0.25,
    );
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.15, size.width, size.height * 0.2);
    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();
    canvas.drawPath(path, paint);

    // الموجة الثانية
    path.reset();
    paint.color =
        isDark ? accentColor.withValues(alpha: 0.05) : accentColor.withValues(alpha: 0.03);
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.85,
      size.width * 0.5,
      size.height * 0.75,
    );
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.65, size.width, size.height * 0.7);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);

    if (isDark) {
      final starPaint =
          Paint()
            ..color = Colors.white.withValues(alpha: 0.05)
            ..style = PaintingStyle.fill;

      final random = math.Random(42);
      for (int i = 0; i < 20; i++) {
        canvas.drawCircle(
          Offset(random.nextDouble() * size.width, random.nextDouble() * size.height),
          random.nextDouble() * 2 + 1,
          starPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
