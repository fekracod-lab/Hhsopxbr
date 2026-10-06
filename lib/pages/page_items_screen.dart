import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'item_details_page.dart';
import 'package:dalal_alqaim/services/app_location_service.dart';
import 'package:dalal_alqaim/widgets/location_selector_widget.dart';
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

class PageItemsScreen extends StatefulWidget {
  final String sectionId;
  final String pageId;
  final String pageName;
  final Color sectionColor;
  final IconData sectionIcon;
  final bool isAdmin;

  const PageItemsScreen({
    super.key,
    required this.sectionId,
    required this.pageId,
    required this.pageName,
    required this.sectionColor,
    required this.sectionIcon,
    required this.isAdmin,
  });

  @override
  State<PageItemsScreen> createState() => _PageItemsScreenState();
}

class _PageItemsScreenState extends State<PageItemsScreen> with TickerProviderStateMixin {
  String searchQuery = '';
  String? selectedSpecialty;
  bool? _isAdminLocal;

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
    _checkIsAdmin();
    _fetchGovernorates();
    AppLocationService().addListener(_onLocationChanged);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    AppLocationService().removeListener(_onLocationChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _onLocationChanged() {
    if (mounted) setState(() {});
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

        if (role == 'limited_admin' && governorates.length == 1) {
          selectedGovernorateId = governorates[0]['id'];
          selectedGovernorateName = governorates[0]['name'];
          _fetchRegions(selectedGovernorateId!);
        } else if (role == 'limited_admin' && assignedGovId != null) {
          // Extra safety for limited admins
          final match = governorates.where((g) => g['id'] == assignedGovId);
          if (match.isNotEmpty) {
            selectedGovernorateId = match.first['id'];
            selectedGovernorateName = match.first['name'];
            _fetchRegions(selectedGovernorateId!);
          }
        }
      });
    } catch (e) {
      debugPrint('Error fetching governorates: $e');
      setState(() => isLoadingGovernorates = false);
    }
  }

  Future<void> _fetchRegions(String govId) async {
    setState(() {
      isLoadingRegions = true;
      regions = [];
      selectedRegionId = null;
      selectedRegionName = null;
    });

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
        final nameA = (a.data() as Map<String, dynamic>?)?['name'] ?? '';
        final nameB = (b.data() as Map<String, dynamic>?)?['name'] ?? '';
        return nameA.compareTo(nameB);
      });
      setState(() {
        regions =
            docs.map((d) {
              final data = d.data() as Map<String, dynamic>? ?? {};
              return {'id': d.id, 'name': data['name'] ?? ''};
            }).toList();
        isLoadingRegions = false;
      });
    } catch (e) {
      debugPrint('Error fetching regions: $e');
      setState(() => isLoadingRegions = false);
    }
  }

  Future<void> _checkIsAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isAdminLocal = false);
        return;
      }
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final role = doc.data()?['role'] as String?;
      if (role != null) {
        setState(
          () =>
              _isAdminLocal =
                  (role == 'admin') || (role == 'limited_admin' && widget.isAdmin == true),
        );
        return;
      }
      setState(() => _isAdminLocal = widget.isAdmin == true);
    } catch (_) {
      setState(() => _isAdminLocal = false);
    }
  }

  Future<void> _deleteItem(String itemId) async {
    await FirebaseFirestore.instance
        .collection('sections')
        .doc(widget.sectionId)
        .collection('pages')
        .doc(widget.pageId)
        .collection('items')
        .doc(itemId)
        .delete();

    try {
      final actor = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('admin_actions').add({
        'action': 'limited_admin_delete_item',
        'actorUid': actor?.uid,
        'actorEmail': actor?.email,
        'sectionId': widget.sectionId,
        'pageId': widget.pageId,
        'itemId': itemId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حذف العنصر!', style: TextStyle()),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _confirmDeleteItem(String itemId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: isDark ? darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'تأكيد الحذف',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? darkText : textColor,
              ),
            ),
            content: Text(
              'هل أنت متأكد من رغبتك في حذف هذا العنصر؟ لا يمكن التراجع عن هذا الإجراء.',
              style: TextStyle(color: isDark ? darkSubText : subTextColor),
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
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _deleteItem(itemId);
                },
                child: const Text(
                  'حذف',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final specialtyController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final mapsUrlController = TextEditingController();
    final imageUrlController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: isDark ? darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'إضافة عنصر جديد',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? darkText : textColor,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTextField(nameController, 'الاسم', isDark),
                  const SizedBox(height: 10),
                  _buildDialogTextField(specialtyController, 'التخصص/المهنة', isDark),
                  const SizedBox(height: 10),
                  _buildDialogTextField(
                    phoneController,
                    'رقم الهاتف',
                    isDark,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),
                  _buildDialogTextField(addressController, 'العنوان', isDark),
                  const SizedBox(height: 10),
                  _buildDialogTextField(mapsUrlController, 'رابط خرائط جوجل (اختياري)', isDark),
                  const SizedBox(height: 10),
                  _buildDialogTextField(imageUrlController, 'رابط الصورة (اختياري)', isDark),
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
                  if (nameController.text.trim().isNotEmpty) {
                    await FirebaseFirestore.instance
                        .collection('sections')
                        .doc(widget.sectionId)
                        .collection('pages')
                        .doc(widget.pageId)
                        .collection('items')
                        .add({
                          'name': nameController.text.trim(),
                          'specialty': specialtyController.text.trim(),
                          'phone': phoneController.text.trim(),
                          'address': addressController.text.trim(),
                          'mapUrl': mapsUrlController.text.trim(),
                          'imageUrl': imageUrlController.text.trim(),
                          'createdAt': FieldValue.serverTimestamp(),
                          'governorateId': selectedGovernorateId,
                          'governorateName': selectedGovernorateName,
                          'regionId': selectedRegionId,
                          'regionName': selectedRegionName,
                        });

                    try {
                      final actor = FirebaseAuth.instance.currentUser;
                      await FirebaseFirestore.instance.collection('admin_actions').add({
                        'action': 'limited_admin_add_item',
                        'actorUid': actor?.uid,
                        'actorEmail': actor?.email,
                        'sectionId': widget.sectionId,
                        'pageId': widget.pageId,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    } catch (_) {}

                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'تم إضافة العنصر بنجاح',
                          style: TextStyle(),
                        ),
                        backgroundColor: primaryColor,
                      ),
                    );
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

  void _showEditItemDialog(String itemId, Map<String, dynamic> item) {
    final nameController = TextEditingController(text: item['name']);
    final specialtyController = TextEditingController(text: item['specialty']);
    final phoneController = TextEditingController(text: item['phone']);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Initialize location fields from item data
    setState(() {
      selectedGovernorateId = item['governorateId'];
      selectedGovernorateName = item['governorateName'];
      selectedRegionId = item['regionId'];
      selectedRegionName = item['regionName'];
    });

    if (selectedGovernorateId != null) {
      _fetchRegions(selectedGovernorateId!);
    }

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: isDark ? darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'تعديل العنصر',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? darkText : textColor,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTextField(nameController, 'الاسم', isDark),
                  const SizedBox(height: 10),
                  _buildDialogTextField(specialtyController, 'التخصص', isDark),
                  const SizedBox(height: 10),
                  _buildDialogTextField(phoneController, 'الهاتف', isDark),
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
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('sections')
                      .doc(widget.sectionId)
                      .collection('pages')
                      .doc(widget.pageId)
                      .collection('items')
                      .doc(itemId)
                      .update({
                        'name': nameController.text.trim(),
                        'specialty': specialtyController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'governorateId': selectedGovernorateId,
                        'governorateName': selectedGovernorateName,
                        'regionId': selectedRegionId,
                        'regionName': selectedRegionName,
                      });
                  if (ctx.mounted) Navigator.pop(ctx);
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

  Widget _buildDialogTextField(
    TextEditingController controller,
    String label,
    bool isDark, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? darkText : textColor),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEffectiveAdmin = (widget.isAdmin == true) || (_isAdminLocal == true);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
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
                isEffectiveAdmin
                    ? FloatingActionButton.extended(
                      onPressed: _showAddItemDialog,
                      backgroundColor: primaryColor,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'إضافة عنصر',
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
                  // 1. App Bar
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
                        onPressed: () => Navigator.of(context).pop(),
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
                        title: ListenableBuilder(
                          listenable: AppLocationService(),
                          builder: (context, _) {
                            final location = AppLocationService().currentLocation;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.pageName,
                                  style: TextStyle(
                                    color: isDark ? darkText : const Color(0xFF2D2D2D),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _showLocationSelector(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.location_on, size: 12, color: primaryColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          location.governorateName ?? 'كل العراق',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
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
                            onChanged: (value) {
                              setState(() {
                                searchQuery = value.trim();
                              });
                            },
                            style: TextStyle(
                              color: isDark ? darkText : textColor,
                            ),
                            decoration: InputDecoration(
                              hintText: 'ابحث باسم العنصر أو التخصص...',
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

                  // 3. Items Stream and List
                  StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('sections')
                            .doc(widget.sectionId)
                            .collection('pages')
                            .doc(widget.pageId)
                            .collection('items')
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
                              'حدث خطأ أثناء جلب البيانات',
                              style: TextStyle(color: isDark ? darkText : textColor),
                            ),
                          ),
                        );
                      }

                      final items = snapshot.data?.docs ?? [];

                      // 1. Filter by Location & Search FIRST
                      final availableItems =
                          items.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;

                            // Location Filter disabled: display all items

                            // Search Query Filter
                            if (searchQuery.isNotEmpty) {
                              final name = (data['name'] ?? '').toString().toLowerCase();
                              final specialty = (data['specialty'] ?? '').toString().toLowerCase();
                              final q = searchQuery.toLowerCase();
                              if (!name.contains(q) && !specialty.contains(q)) return false;
                            }

                            return true;
                          }).toList();

                      // 2. Extract Specialties from AVAILABLE Items
                      final specialties = <String>{};
                      for (final doc in availableItems) {
                        final item = doc.data() as Map<String, dynamic>;
                        if ((item['specialty'] ?? '').toString().isNotEmpty) {
                          specialties.add(item['specialty']);
                        }
                      }
                      final specialtyList = specialties.toList();

                      // 3. Apply Specialty Filter if selected
                      List<QueryDocumentSnapshot> filteredItems = availableItems;
                      if (selectedSpecialty != null && selectedSpecialty!.isNotEmpty) {
                        // If selected specialty is no longer available (e.g. changed location), clear it
                        if (!specialties.contains(selectedSpecialty)) {
                          // We can't setState during build, so we just ignore the filter essentially
                          // Or better, we treat it as no filter match?
                          // Let's just filter. If it returns empty, the user will likely deselect.
                          // However, strictly filtering might show empty list which is correct.
                          filteredItems =
                              filteredItems.where((doc) {
                                final item = doc.data() as Map<String, dynamic>;
                                return item['specialty'] == selectedSpecialty;
                              }).toList();
                        } else {
                          filteredItems =
                              filteredItems.where((doc) {
                                final item = doc.data() as Map<String, dynamic>;
                                return item['specialty'] == selectedSpecialty;
                              }).toList();
                        }
                      }

                      return SliverList(
                        delegate: SliverChildListDelegate([
                          // Specialties Filter
                          if (specialtyList.isNotEmpty)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: Row(
                                children:
                                    specialtyList.map((s) {
                                      final isSelected = selectedSpecialty == s;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: ChoiceChip(
                                          label: Text(
                                            s,
                                            style: TextStyle(
                                              color:
                                                  isSelected
                                                      ? Colors.white
                                                      : (isDark ? darkText : Colors.black87),
                                            ),
                                          ),
                                          selected: isSelected,
                                          selectedColor: primaryColor,
                                          backgroundColor: isDark ? darkCard : Colors.white,
                                          onSelected:
                                              (v) =>
                                                  setState(() => selectedSpecialty = v ? s : null),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                            side: BorderSide(
                                              color:
                                                  isSelected
                                                      ? Colors.transparent
                                                      : (isDark
                                                          ? Colors.white10
                                                          : Colors.grey.withValues(alpha: 0.2)),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ),

                          // Empty State
                          if (filteredItems.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 50),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 60,
                                    color:
                                        isDark ? darkHint.withValues(alpha: 0.3) : Colors.grey[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'لا توجد عناصر مطابقة',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isDark ? darkSubText : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.builder(
                              padding: const EdgeInsets.all(20),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final doc = filteredItems[index];
                                final item = doc.data() as Map<String, dynamic>;
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
                                  child: _buildItemCard(doc.id, item, isEffectiveAdmin, isDark),
                                );
                              },
                            ),

                          const SizedBox(height: 80),
                        ]),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(String itemId, Map<String, dynamic> item, bool isAdmin, bool isDark) {
    final isNew =
        item['createdAt'] != null &&
        item['createdAt'] is Timestamp &&
        DateTime.now().difference((item['createdAt'] as Timestamp).toDate()).inDays < 3;

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
            Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (context) => ItemDetailsPage(
                      sectionId: widget.sectionId,
                      itemId: itemId,
                      sectionLabel: widget.pageName,
                      sectionIcon: widget.sectionIcon,
                      sectionColor: widget.sectionColor,
                      pageId: widget.pageId,
                    ),
              ),
            );
          },
          onLongPress: isAdmin ? () => _showEditItemDialog(itemId, item) : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Image or Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: widget.sectionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child:
                        (item['imageUrl'] ?? '').toString().isNotEmpty
                            ? Image.network(
                              item['imageUrl'],
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: widget.sectionColor.withValues(alpha: 0.05),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        widget.sectionColor,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder:
                                  (ctx, err, st) => Container(
                                    width: 60,
                                    height: 60,
                                    color: widget.sectionColor.withValues(alpha: 0.1),
                                    child: Icon(
                                      widget.sectionIcon,
                                      color: widget.sectionColor,
                                      size: 30,
                                    ),
                                  ),
                            )
                            : Icon(widget.sectionIcon, color: widget.sectionColor, size: 30),
                  ),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['name'] ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? darkText : const Color(0xFF2D2D2D),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isNew)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'جديد',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if ((item['specialty'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.work_outline,
                                size: 14,
                                color: isDark ? darkHint : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item['specialty'],
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? darkSubText : Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if ((item['phone'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.phone, size: 14, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                item['phone'],
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              if (isAdmin)
                                InkWell(
                                  onTap: () => _confirmDeleteItem(itemId),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  ),
                                ),
                            ],
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
    );
  }

  void _showLocationSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LocationSelectorWidget(),
    );
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
