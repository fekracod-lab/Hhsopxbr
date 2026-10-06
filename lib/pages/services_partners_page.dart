import 'package:flutter/material.dart';
import 'package:dalal_alqaim/shared/app_colors.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/ride_history_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/delivery_dashboard_page.dart' show DeliveryDashboardPage;
import 'package:dalal_alqaim/features/auth/pages/unified_login_page.dart';
import 'package:dalal_alqaim/features/auth/widgets/role_selector_tab.dart';
import 'package:dalal_alqaim/widgets/contact_bottom_sheet.dart' show ContactBottomSheet;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dalal_alqaim/services/cloudinary_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:dalal_alqaim/features/restaurant/presentation/pages/restaurant_dashboard_page.dart' show RestaurantDashboardPage;
import 'package:dalal_alqaim/features/restaurant/presentation/pages/restaurant_register_page.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/store_dashboard_page.dart' show StoreDashboardPage;
import 'package:dalal_alqaim/features/stores/presentation/pages/store_register_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/driver_dashboard_page.dart' show DriverDashboardPage;
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/captain_register_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_register_page.dart';
import 'package:dalal_alqaim/services/notification_service.dart';

class ServicesPartnersPage extends StatefulWidget {
  final Map<String, bool> roles;
  const ServicesPartnersPage({super.key, required this.roles});

  @override
  State<ServicesPartnersPage> createState() => _ServicesPartnersPageState();
}

class _ServicesPartnersPageState extends State<ServicesPartnersPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? darkBackground : backgroundColor;
    final cardBg = isDark ? darkCard : cardColor;
    final txt = isDark ? darkText : textColor;
    // final subTxt = isDark ? darkSubText : subTextColor; // Removed unused variable

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          'الخدمات والشركاء',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: txt,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: txt),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('خدماتي', isDark),
          _buildGroup(isDark, cardBg, [
            _buildTile(
              icon: Icons.history_rounded,
              title: 'سجل الرحلات',
              subtitle: 'عرض رحلاتك السابقة وتقييمها',
              iconColor: primaryColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RideHistoryPage()),
              ),
              isDark: isDark,
            ),
            _buildDivider(isDark),
            _buildTile(
              icon: Icons.work_outline_rounded,
              title: 'إضافة تخصص / مهنة',
              subtitle: 'هل أنت صاحب مهنة؟ أضف خدماتك هنا',
              iconColor: Colors.blue,
              onTap: () => _showAddSpecialtyDialog(context),
              isDark: isDark,
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('لوحة الشركاء', isDark),
          _buildGroup(isDark, cardBg, [
            // Restaurant
            _buildTile(
              icon: Icons.restaurant_rounded,
              title: widget.roles['isRestaurant']!
                  ? 'لوحة المطعم'
                  : (widget.roles['isRestaurantPending']! ? 'طلب المطعم قيد المراجعة' : 'تسجيل كمطعم'),
              iconColor: widget.roles['isRestaurantPending']! ? Colors.grey : (widget.roles['isRestaurant']! ? Colors.orange : null),
              onTap: () {
                if (widget.roles['isRestaurant']!) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantDashboardPage()));
                } else if (widget.roles['isRestaurantPending']!) {
                  _showPendingSnackbar(context);
                } else {
                  _showPartnerRegistrationOptions(
                    context,
                    title: 'تسجيل كمطعم',
                    onFullRegister: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantRegisterPage())),
                    onQuickDialog: () => _showRegisterRestaurantDialog(context),
                  );
                }
              },
              isDark: isDark,
            ),
            _buildDivider(isDark),
            // Store Owner
            _buildTile(
              icon: Icons.storefront_rounded,
              title: widget.roles['isStoreOwner'] == true
                  ? 'لوحة المتجر'
                  : (widget.roles['isStorePending'] == true ? 'طلب المتجر قيد المراجعة' : 'تسجيل كمتجر'),
              iconColor: widget.roles['isStorePending'] == true
                  ? Colors.grey
                  : (widget.roles['isStoreOwner'] == true ? Colors.purple : null),
              onTap: () async {
                if (widget.roles['isStoreOwner'] == true) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final storeQuery = await FirebaseFirestore.instance
                        .collection('stores')
                        .where('ownerId', isEqualTo: user.uid)
                        .limit(1)
                        .get();
                    if (storeQuery.docs.isNotEmpty) {
                      final doc = storeQuery.docs.first;
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StoreDashboardPage(
                              storeId: doc.id,
                              storeData: doc.data(),
                            ),
                          ),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('لم يتم العثور على متجرك كصاحب متجر', style: TextStyle())),
                        );
                      }
                    }
                  }
                } else if (widget.roles['isStorePending'] == true) {
                  _showPendingSnackbar(context);
                } else {
                  _showPartnerRegistrationOptions(
                    context,
                    title: 'تسجيل كمتجر',
                    onFullRegister: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreRegisterPage())),
                    onQuickDialog: () => _showRegisterStoreDialog(context),
                  );
                }
              },
              isDark: isDark,
            ),
            _buildDivider(isDark),
            // Delivery Delegate
            _buildTile(
              icon: Icons.two_wheeler_rounded,
              title: widget.roles['isDeliveryApproved']! ? 'لوحة مندوب التوصيل' : 'تسجيل ودخول مندوب توصيل',
              subtitle: 'توصيل طلبات مرسال، المطاعم، والمتاجر',
              iconColor: widget.roles['isDeliveryApproved']! ? const Color(0xFF10B981) : null,
              onTap: () {
                if (widget.roles['isDeliveryApproved']!) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveryDashboardPage()));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveryRegisterPage()));
                }
              },
              isDark: isDark,
            ),
            _buildDivider(isDark),
            // Driver/Captain Taxi
            _buildTile(
              icon: Icons.local_taxi_rounded,
              title: (widget.roles['isDriver'] ?? false)
                  ? 'لوحة كابتن التكسي'
                  : ((widget.roles['isDriverPending'] ?? false) ? 'طلب الكابتن قيد المراجعة' : 'تسجيل ودخول كابتن تكسي'),
              subtitle: 'مشاوير ونقل الركاب السريعة داخل وخارج القائم',
              iconColor: (widget.roles['isDriverPending'] ?? false)
                  ? Colors.grey
                  : ((widget.roles['isDriver'] ?? false) ? const Color(0xFFFFB300) : null),
              onTap: () {
                if (widget.roles['isDriver'] ?? false) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverDashboardPage()));
                } else if (widget.roles['isDriverPending'] ?? false) {
                  _showPendingSnackbar(context);
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CaptainRegisterPage()));
                }
              },
              isDark: isDark,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildGroup(bool isDark, Color cardBg, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? darkSubText : subTextColor,
          ),
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? iconColor,
    required bool isDark,
  }) {
    final txt = isDark ? darkText : textColor;
    final sub = isDark ? darkSubText : subTextColor;
    final iconC = iconColor ?? (isDark ? darkSubText : Colors.grey.shade600);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconC.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconC, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: txt,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(fontSize: 12, color: sub))
          : null,
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? darkHint : hintColor),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 60,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
    );
  }

  void _showPendingSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('طلبك قيد المراجعة من قبل الإدارة', style: TextStyle()),
      ),
    );
  }

  void _showAddSpecialtyDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ContactBottomSheet(),
    );
  }

  void _showRegisterRestaurantDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? darkCard : Colors.white;
    final txt = isDark ? darkText : textColor;

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final restNameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String? selectedType;
    String? selectedGovId;
    String? selectedGovName;
    String? selectedRegId;
    String? selectedRegName;
    List<Map<String, dynamic>> regions = [];
    bool isLoadingRegions = false;
    Uint8List? selectedImageBytes;
    String? selectedImageFilename;

    final List<String> types = ['مطعم', 'كافيه', 'حلويات', 'وجبات سريعة', 'معجنات'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: bgColor,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'تسجيل كمطعم',
              style: TextStyle(fontWeight: FontWeight.bold, color: txt),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTextField(nameCtrl, 'اسم المالك', Icons.person, isDark),
                  const SizedBox(height: 12),
                  _buildDialogTextField(phoneCtrl, 'رقم الهاتف', Icons.phone, isDark),
                  const SizedBox(height: 12),
                  _buildDialogTextField(restNameCtrl, 'اسم المطعم', Icons.store, isDark),
                  const SizedBox(height: 12),
                  _buildDialogTextField(addressCtrl, 'العنوان', Icons.map, isDark),
                  const SizedBox(height: 12),
                  _buildGovDropdown(isDark, selectedGovId, (id, name) async {
                    setState(() {
                      selectedGovId = id;
                      selectedGovName = name;
                      selectedRegId = null;
                      selectedRegName = null;
                      isLoadingRegions = true;
                    });
                    final rSnap = await FirebaseFirestore.instance
                        .collection('governorates')
                        .doc(id)
                        .collection('regions')
                        .where('isActive', isEqualTo: true)
                        .get();
                    setState(() {
                      regions = rSnap.docs.map((r) => {'id': r.id, ...r.data()}).toList();
                      isLoadingRegions = false;
                    });
                  }),
                  const SizedBox(height: 12),
                  _buildRegDropdown(isDark, selectedRegId, regions, isLoadingRegions, (id, name) {
                    setState(() {
                      selectedRegId = id;
                      selectedRegName = name;
                    });
                  }),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    dropdownColor: bgColor,
                    hint: Text('نوع النشاط', style: TextStyle(fontSize: 14, color: isDark ? darkHint : hintColor)),
                    items: types.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: txt)))).toList(),
                    onChanged: (v) => setState(() => selectedType = v),
                    decoration: _dialogInputDecoration(isDark, 'نوع النشاط', Icons.category),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1000);
                      if (picked != null) {
                        final bytes = await picked.readAsBytes();
                        setState(() {
                          selectedImageBytes = bytes;
                          selectedImageFilename = picked.name;
                        });
                      }
                    },
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: isDark ? darkSurface : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: selectedImageBytes == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_business, color: primaryColor, size: 30),
                                const SizedBox(height: 8),
                                Text('صورة المطعم (اختياري)', style: TextStyle(fontSize: 12, color: txt)),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(selectedImageBytes!, fit: BoxFit.cover, width: double.infinity),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle())),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty || restNameCtrl.text.isEmpty || selectedType == null) {
                    _showErrorSnackbar(context, 'يرجى ملء البيانات المطلوبة');
                    return;
                  }
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;
                    String? url;
                    if (selectedImageBytes != null) {
                      url = await CloudinaryService.uploadBytes(selectedImageBytes!, selectedImageFilename!);
                    }
                    await FirebaseFirestore.instance.collection('restaurant_requests').add({
                      'uid': user.uid,
                      'ownerName': nameCtrl.text,
                      'phone': phoneCtrl.text,
                      'restaurantName': restNameCtrl.text,
                      'address': addressCtrl.text,
                      'governorateId': selectedGovId,
                      'governorateName': selectedGovName,
                      'regionId': selectedRegId,
                      'regionName': selectedRegName,
                      'type': selectedType,
                      'imageUrl': url ?? '',
                      'status': 'pending',
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: primaryColor, content: Text('تم إرسال طلبك بنجاح', style: TextStyle())));
                    }
                  } catch (e) {
                    debugPrint("Error $e");
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                child: const Text('إرسال', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showErrorSnackbar(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle())));
  }

  InputDecoration _dialogInputDecoration(bool isDark, String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? darkHint : hintColor, fontSize: 13),
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      filled: true,
      fillColor: isDark ? darkSurface : surfaceColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryColor)),
    );
  }

  Widget _buildDialogTextField(TextEditingController ctrl, String label, IconData icon, bool isDark) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: isDark ? darkText : textColor),
      decoration: _dialogInputDecoration(isDark, label, icon),
    );
  }

  Widget _buildGovDropdown(bool isDark, String? selectedId, Function(String, String) onChanged) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('governorates').where('isActive', isEqualTo: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator(color: primaryColor);
        final docs = snapshot.data!.docs.toList();
        return DropdownButtonFormField<String>(
          initialValue: selectedId,
          dropdownColor: isDark ? darkCard : Colors.white,
          decoration: _dialogInputDecoration(isDark, 'المحافظة', Icons.location_city),
          items: docs.map((d) => DropdownMenuItem(value: d.id, child: Text(d['name'] ?? '', style: TextStyle(color: isDark ? darkText : textColor)))).toList(),
          onChanged: (v) {
            if (v != null) {
              final doc = docs.firstWhere((d) => d.id == v);
              onChanged(v, doc['name']);
            }
          },
        );
      },
    );
  }

  Widget _buildRegDropdown(bool isDark, String? selectedId, List<Map<String, dynamic>> regions, bool isLoading, Function(String, String) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      dropdownColor: isDark ? darkCard : Colors.white,
      decoration: _dialogInputDecoration(isDark, isLoading ? 'جاري التحميل...' : 'المنطقة', Icons.location_on),
      items: regions.map((r) => DropdownMenuItem(value: r['id'] as String, child: Text(r['name'] ?? '', style: TextStyle(color: isDark ? darkText : textColor)))).toList(),
      onChanged: (v) {
        if (v != null) {
          final r = regions.firstWhere((e) => e['id'] == v);
          onChanged(v, r['name']);
        }
      },
    );
  }

  void _showRegisterStoreDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? darkCard : Colors.white;
    final txt = isDark ? darkText : textColor;

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final storeNameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String? selectedCategory;
    String? selectedGovId;
    String? selectedGovName;
    String? selectedRegId;
    String? selectedRegName;
    List<Map<String, dynamic>> regions = [];
    bool isLoadingRegions = false;
    Uint8List? selectedImageBytes;
    String? selectedImageFilename;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: bgColor,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'تسجيل كمتجر',
              style: TextStyle(fontWeight: FontWeight.bold, color: txt),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTextField(nameCtrl, 'اسم المالك', Icons.person, isDark),
                  const SizedBox(height: 12),
                  _buildDialogTextField(phoneCtrl, 'رقم الهاتف', Icons.phone, isDark),
                  const SizedBox(height: 12),
                  _buildDialogTextField(storeNameCtrl, 'اسم المتجر', Icons.storefront, isDark),
                  const SizedBox(height: 12),
                  _buildDialogTextField(addressCtrl, 'العنوان', Icons.map, isDark),
                  const SizedBox(height: 12),
                  _buildGovDropdown(isDark, selectedGovId, (id, name) async {
                    setState(() {
                      selectedGovId = id;
                      selectedGovName = name;
                      selectedRegId = null;
                      selectedRegName = null;
                      isLoadingRegions = true;
                    });
                    final rSnap = await FirebaseFirestore.instance
                        .collection('governorates')
                        .doc(id)
                        .collection('regions')
                        .where('isActive', isEqualTo: true)
                        .get();
                    setState(() {
                      regions = rSnap.docs.map((r) => {'id': r.id, ...r.data()}).toList();
                      isLoadingRegions = false;
                    });
                  }),
                  const SizedBox(height: 12),
                  _buildRegDropdown(isDark, selectedRegId, regions, isLoadingRegions, (id, name) {
                    setState(() {
                      selectedRegId = id;
                      selectedRegName = name;
                    });
                  }),
                  const SizedBox(height: 12),
                  _buildStoreCategoryDropdown(isDark, selectedCategory, (cat) {
                    setState(() => selectedCategory = cat);
                  }),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1000);
                      if (picked != null) {
                        final bytes = await picked.readAsBytes();
                        setState(() {
                          selectedImageBytes = bytes;
                          selectedImageFilename = picked.name;
                        });
                      }
                    },
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: isDark ? darkSurface : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: selectedImageBytes == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_business, color: primaryColor, size: 30),
                                const SizedBox(height: 8),
                                Text('صورة المتجر (اختياري)', style: TextStyle(fontSize: 12, color: txt)),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(selectedImageBytes!, fit: BoxFit.cover, width: double.infinity),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle())),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty || storeNameCtrl.text.isEmpty || selectedCategory == null) {
                    _showErrorSnackbar(context, 'يرجى ملء البيانات المطلوبة');
                    return;
                  }
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;
                    String? url;
                    if (selectedImageBytes != null) {
                      url = await CloudinaryService.uploadBytes(selectedImageBytes!, selectedImageFilename!);
                    }
                    await FirebaseFirestore.instance.collection('store_requests').add({
                      'uid': user.uid,
                      'ownerName': nameCtrl.text,
                      'phone': phoneCtrl.text,
                      'storeName': storeNameCtrl.text,
                      'address': addressCtrl.text,
                      'governorateId': selectedGovId,
                      'governorateName': selectedGovName,
                      'regionId': selectedRegId,
                      'regionName': selectedRegName,
                      'category': selectedCategory,
                      'imageUrl': url ?? '',
                      'status': 'pending',
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    // 1. Notify the user themselves
                    try {
                      await NotificationService.emitEvent(
                        type: 'user_notification',
                        payload: {
                          'user_id': user.uid,
                          'title': "تم إرسال طلبك بنجاح!",
                          'body': "شكراً لتسجيل متجرك. طلبك قيد المراجعة حالياً وسنقوم بإشعارك فور التفعيل.",
                          'data': {"type": "store_registration_pending"},
                        },
                      );
                    } catch (e) {
                      debugPrint("Error sending pending registration user notification: $e");
                    }

                    // 2. Notify Admins and Governorate Managers
                    try {
                      await NotificationService.emitEvent(
                        type: 'new_store_registration_request',
                        payload: {
                          'storeName': storeNameCtrl.text,
                          'governorateName': selectedGovName ?? '',
                          'ownerName': nameCtrl.text,
                        },
                      );
                    } catch (e) {
                      debugPrint("Error sending admin store registration notification: $e");
                    }

                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: primaryColor, content: const Text('تم إرسال طلب تسجيل المتجر بنجاح', style: TextStyle())));
                    }
                  } catch (e) {
                    debugPrint("Error $e");
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                child: const Text('إرسال', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStoreCategoryDropdown(bool isDark, String? selectedCat, Function(String) onChanged) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('store_categories').orderBy('createdAt', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator(color: primaryColor);
        final docs = snapshot.data!.docs;
        return DropdownButtonFormField<String>(
          initialValue: selectedCat,
          dropdownColor: isDark ? darkCard : Colors.white,
          decoration: _dialogInputDecoration(isDark, 'تصنيف المتجر', Icons.category),
          items: docs.map((d) => DropdownMenuItem(value: d['name'] as String, child: Text(d['name'] ?? '', style: TextStyle(color: isDark ? darkText : textColor)))).toList(),
          onChanged: (v) {
            if (v != null) {
              onChanged(v);
            }
          },
        );
      },
    );
  }

  void _showPartnerRegistrationOptions(
    BuildContext context, {
    required String title,
    required VoidCallback onFullRegister,
    required VoidCallback onQuickDialog,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF132B2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF112525),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'اختر طريقة التسجيل المناسبة لك:',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.rocket_launch_rounded, color: primaryColor),
                ),
                title: const Text('واجهة التسجيل المتكاملة (موصى بها)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('تحديد موقع GPS على الخريطة، رفع الوثائق، وتجهيز كافة البيانات'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  onFullRegister();
                },
              ),
              const Divider(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.quickreply_rounded, color: Colors.blue),
                ),
                title: const Text('طلب سريع لحسابي الحالي', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('إرسال طلب مراجعة سريع وربطه بحسابك المسجل حالياً'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  onQuickDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
