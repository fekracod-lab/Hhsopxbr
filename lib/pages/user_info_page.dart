import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dalal_alqaim/services/notification_service.dart';
import 'restaurants_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dalal_alqaim/widgets/map_picker_page.dart';

// --- Premium Palette ---
const Color primaryColor = Color(0xFF26A69A);
const Color accentColor = Color(0xFF00796B);
const Color backgroundColor = Color(0xFFFFFFFF);
const Color textColor = Color(0xFF1E293B);
const Color hintColor = Color(0xFF94A3B8);
const Color subTextColor = Color(0xFF64748B);
const Color surfaceColor = Color(0xFFF8FAFC);

// --- Dark Mode Premium Palette ---
const Color darkBackground = Color(0xFF0F172A);
const Color darkSurface = Color(0xFF1E293B);
const Color darkCard = Color(0xFF0F172A);
const Color darkText = Color(0xFFF1F5F9);
const Color darkSubText = Color(0xFF94A3B8);
const Color darkHint = Color(0xFF475569);

class UserInfoPage extends StatefulWidget {
  final String? restaurantId;
  final List<Map<String, dynamic>>? cartItems;
  const UserInfoPage({super.key, this.restaurantId, this.cartItems});

  @override
  State<UserInfoPage> createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedLocationType = 'المنزل';

  List<Map<String, dynamic>> _deliveryAreas = [];
  Map<String, dynamic>? _selectedRegion;
  bool _loading = false;
  bool _isSubmitting = false;
  String? _uid;
  LatLng? _selectedLatLng;

  // الحساب المباشر للمجموع الفرعي للمأكولات
  double get cartSubtotal => widget.cartItems?.fold(
        0.0,
        (acc, item) => (acc ?? 0.0) + ((item['price'] ?? 0.0) * (item['quantity'] ?? 0)),
      ) ?? 0.0;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    if (widget.restaurantId != null) {
      _fetchDeliveryAreas();
    }
    _loadUserProfile();
  }

  Future<void> _fetchDeliveryAreas() async {
    setState(() => _loading = true);
    try {
      final doc =
          await FirebaseFirestore.instance.collection('restaurants').doc(widget.restaurantId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['deliveryAreas'] != null) {
          setState(() {
            _deliveryAreas = List<Map<String, dynamic>>.from(data['deliveryAreas']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching delivery areas: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadUserProfile() async {
    if (_uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        setState(() {
          if (_nameController.text.isEmpty) {
            _nameController.text = data['fullName'] ?? data['name'] ?? '';
          }
          if (_phoneController.text.isEmpty) {
            _phoneController.text = data['phone'] ?? '';
          }
          if (_addressController.text.isEmpty) {
            _addressController.text = data['address'] ?? '';
          }
          if (data['latitude'] != null && data['longitude'] != null) {
            _selectedLatLng = LatLng(
              (data['latitude'] as num).toDouble(),
              (data['longitude'] as num).toDouble(),
            );
          } else if (data['lat'] != null && data['lng'] != null) {
            _selectedLatLng = LatLng(
              (data['lat'] as num).toDouble(),
              (data['lng'] as num).toDouble(),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? darkBackground : backgroundColor;
    final mainTextColor = isDark ? darkText : textColor;
    final secondaryTextColor = isDark ? darkSubText : subTextColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? darkSurface : surfaceColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
            ),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: mainTextColor, size: 16),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'تأكيد طلبك وتوصيله',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: mainTextColor,
            fontSize: 16,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(isDark, mainTextColor, secondaryTextColor),
                const SizedBox(height: 25),

                // --- قسم المعلومات الشخصية ---
                _buildSectionTitle('المعلومات الشخصية', isDark),
                const SizedBox(height: 12),
                _buildInputField(
                  controller: _nameController,
                  label: 'الاسم الكامل',
                  hint: 'الاسم الذي سيظهر للمطعم والمندوب',
                  icon: Icons.person_outline_rounded,
                  isDark: isDark,
                  validator: (val) => val!.trim().isEmpty ? 'يرجى إدخال الاسم' : null,
                ),
                const SizedBox(height: 14),
                _buildInputField(
                  controller: _phoneController,
                  label: 'رقم الهاتف',
                  hint: 'رقم فعال للتواصل عند التوصيل',
                  icon: Icons.phone_android_rounded,
                  inputType: TextInputType.phone,
                  isDark: isDark,
                  validator: (val) =>
                      val == null || val.length < 9 ? 'رقم الهاتف قصير جداً' : null,
                ),

                const SizedBox(height: 28),

                // --- قسم العنوان ---
                _buildSectionTitle('تفاصيل العنوان والتوصيل', isDark),
                const SizedBox(height: 12),
                _buildLocationTypeCards(isDark, secondaryTextColor),
                const SizedBox(height: 16),

                // --- اختيار المنطقة للتوصيل ---
                if (_loading || _deliveryAreas.isNotEmpty) ...[
                  _buildSectionTitle('اختر منطقة التوصيل', isDark),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? darkSurface : surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<Map<String, dynamic>>(
                        initialValue: _selectedRegion,
                        hint: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primaryColor,
                                ),
                              )
                            : Text(
                                'اختر منطقتك لتحديد سعر التوصيل دليفري',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? darkHint : hintColor,
                                ),
                              ),
                        isExpanded: true,
                        dropdownColor: isDark ? darkSurface : Colors.white,
                        items: _deliveryAreas.map((area) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: area,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  area['name'] ?? '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDark ? darkText : textColor,
                                  ),
                                ),
                                Text(
                                  '${area['price']} د.ع',
                                  style: const TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedRegion = val);
                        },
                        validator: (val) => val == null ? 'يرجى اختيار المنطقة' : null,
                        decoration: const InputDecoration(border: InputBorder.none),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                _buildInputField(
                  controller: _addressController,
                  label: 'العنوان بالتفصيل',
                  hint: 'المنطقة، الحي، الشارع، أقرب نقطة دالة...',
                  icon: Icons.map_outlined,
                  maxLines: 2,
                  isDark: isDark,
                  validator: (val) => val!.trim().isEmpty ? 'يرجى إدخال العنوان' : null,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'تحديد الموقع الحالي مباشرة (GPS)',
                        icon: Icon(
                          _selectedLatLng != null ? Icons.my_location_rounded : Icons.location_searching_rounded,
                          color: _selectedLatLng != null ? primaryColor : Colors.grey,
                        ),
                        onPressed: () async {
                          try {
                            bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                            if (!serviceEnabled) {
                              _showSnack('الرجاء تفعيل خدمة تحديد الموقع (GPS)', Colors.redAccent);
                              return;
                            }
                            LocationPermission permission = await Geolocator.checkPermission();
                            if (permission == LocationPermission.denied) {
                              permission = await Geolocator.requestPermission();
                              if (permission == LocationPermission.denied) return;
                            }
                            if (permission == LocationPermission.deniedForever) return;
                            if (!mounted) return;

                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) => const Center(child: CircularProgressIndicator(color: primaryColor)),
                            );

                            final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
                            final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
                            if (!mounted) return;
                            Navigator.pop(context); // close loading

                            String addr = 'موقع محدد';
                            if (placemarks.isNotEmpty) {
                              final p = placemarks.first;
                              final List<String> parts = [];
                              if (p.street != null && p.street!.trim().isNotEmpty && !p.street!.contains('+')) parts.add(p.street!.trim());
                              if (p.subLocality != null && p.subLocality!.trim().isNotEmpty) parts.add(p.subLocality!.trim());
                              if (p.locality != null && p.locality!.trim().isNotEmpty) parts.add(p.locality!.trim());
                              if (parts.isNotEmpty) {
                                addr = parts.join('،');
                              }
                            }
                            setState(() {
                              _selectedLatLng = LatLng(pos.latitude, pos.longitude);
                              _addressController.text = addr;
                            });
                            _showSnack('تم تحديد موقعك بنجاح', primaryColor);
                          } catch (e) {
                            if (mounted) {
                              if (Navigator.canPop(context)) Navigator.pop(context);
                              _showSnack('حدث خطأ أثناء تحديد الموقع: $e', Colors.redAccent);
                            }
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'اختيار من الخريطة',
                        icon: const Icon(Icons.map_rounded, color: primaryColor),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MapPickerPage()),
                          );
                          if (result != null && result is Map) {
                            setState(() {
                              _addressController.text = result['address'];
                              _selectedLatLng = result['location'];
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildInputField(
                  controller: _notesController,
                  label: 'ملاحظات خاصة (اختياري)',
                  hint: 'مثال: زيادة صوص، بدون بصل، رن الجرس مرتين...',
                  icon: Icons.note_alt_outlined,
                  isDark: isDark,
                  isOptional: true,
                ),

                // --- ملخص الطلب المالي ---
                _buildSummaryCard(isDark),

                const SizedBox(height: 35),

                // --- زر تأكيد وإرسال الطلب النهائي المضيء ---
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: _isSubmitting ? 0.1 : 0.35),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                                SizedBox(width: 10),
                                Text(
                                  'تأكيد وإرسال الطلب',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Widgets Helpers ---

  Widget _buildHeaderCard(bool isDark, Color titleColor, Color subColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F2C2A), const Color(0xFF07191A)]
              : [const Color(0xFFE0F2F1), const Color(0xFFB2DFDB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: isDark ? 0.05 : 0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? primaryColor.withValues(alpha: 0.2) : Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delivery_dining_rounded, color: primaryColor, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تفاصيل التوصيل والطلب',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF004D40),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'يرجى ملء معلوماتك لنربط طلبك بمندوب التوصيل وصاحب المطعم مباشرة',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : const Color(0xFF00796B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: isDark ? darkSubText : accentColor,
      ),
    );
  }

  Widget _buildLocationTypeCards(bool isDark, Color secondaryTextColor) {
    final types = [
      {'name': 'المنزل', 'icon': Icons.home_rounded},
      {'name': 'العمل', 'icon': Icons.business_center_rounded},
      {'name': 'آخر', 'icon': Icons.map_rounded},
    ];

    return Row(
      children: types.map((type) {
        final isSelected = _selectedLocationType == type['name'];
        final cardBg = isSelected
            ? (isDark ? primaryColor.withValues(alpha: 0.15) : primaryColor.withValues(alpha: 0.08))
            : (isDark ? darkSurface : Colors.white);
        final cardBorder = isSelected ? primaryColor : Colors.grey.withValues(alpha: isDark ? 0.05 : 0.1);
        final color = isSelected ? primaryColor : secondaryTextColor;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedLocationType = type['name'] as String);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder, width: 1.5),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Column(
                children: [
                  Icon(type['icon'] as IconData, color: color, size: 24),
                  const SizedBox(height: 6),
                  Text(
                    type['name'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    if (widget.cartItems == null || widget.cartItems!.isEmpty) return const SizedBox.shrink();

    final subtotal = cartSubtotal;
    final deliveryFee = (_selectedRegion?['price'] ?? 0).toDouble();
    final grandTotal = subtotal + deliveryFee;

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? darkSurface : surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_rounded, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'ملخص الحساب المالي',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isDark ? darkText : textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 12),
          _buildSummaryItem('قيمة الوجبات', '${subtotal.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} د.ع', isDark, false),
          const SizedBox(height: 8),
          _buildSummaryItem(
              'أجور التوصيل (مندوب الدليفري)',
              deliveryFee > 0
                  ? '${deliveryFee.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} د.ع'
                  : 'حدد منطقتك لحساب التوصيل',
              isDark,
              false),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 12),
          _buildSummaryItem(
              'المجموع النهائي',
              '${grandTotal.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} د.ع',
              isDark,
              true),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String val, bool isDark, bool isTotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: isTotal ? 16 : 13,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold,
            color: isTotal ? primaryColor : (isDark ? darkText : textColor),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 13 : 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isDark ? darkSubText : subTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    int maxLines = 1,
    required bool isDark,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    bool isOptional = false,
  }) {
    final fillColor = isDark ? darkSurface : surfaceColor;
    final borderColor = isDark ? Colors.transparent : Colors.grey.withValues(alpha: 0.1);
    final labelColor = isDark ? darkText : textColor;
    final hintStyleColor = isDark ? darkHint.withValues(alpha: 0.5) : hintColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: inputType,
            maxLines: maxLines,
            style: TextStyle(
              color: isDark ? darkText : textColor,
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
            ),
            validator: isOptional ? null : validator,
            decoration: InputDecoration(
              filled: true,
              fillColor: fillColor,
              hintText: hint,
              hintStyle: TextStyle(color: hintStyleColor, fontSize: 12),
              prefixIcon: Icon(icon, color: isDark ? darkSubText : accentColor, size: 20),
              suffixIcon: suffixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: borderColor, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uid == null) {
      _showSnack('سجّل دخولك أولاً لإتمام الطلب', Colors.redAccent);
      return;
    }

    final items = widget.cartItems;
    if (items == null || items.isEmpty) {
      _showSnack('سلة التسوق فارغة!', Colors.redAccent);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 2. تجميع العناصر حسب المطعم
      final Map<String, List<Map<String, dynamic>>> groupedOrders = {};

      for (final item in items) {
        final itemId = item['id'];
        final name = item['name'];
        final imageUrl = item['image'];
        final quantity = item['quantity'];
        final price = item['price'];

        // --- محاولة تحديد معرف المطعم الحقيقي (Owner ID) ---
        String? currentRid = (item['restaurantId'] ?? item['restaurant'])?.toString();
        String? resolvedRid = await _resolveRealOwnerId(itemId.toString(), currentRid);
        final finalRid =
            (resolvedRid != null && resolvedRid.isNotEmpty) ? resolvedRid : 'unknown_restaurant';

        final orderItem = {
          'itemId': itemId,
          'name': name,
          'price': price,
          'quantity': quantity,
          'imageUrl': imageUrl,
          'totalPrice': price * quantity,
        };

        if (!groupedOrders.containsKey(finalRid)) {
          groupedOrders[finalRid] = [];
        }
        groupedOrders[finalRid]!.add(orderItem);
      }

      // 3. التحقق الأمني الصارم من هوية المتاجر/المطاعم لمنع خلط البيانات
      if (groupedOrders.containsKey('unknown_restaurant')) {
        throw Exception('يحتوي الطلب على عناصر غير محددة المصدر، يرجى تحديث السلة والمحاولة مجدداً');
      }

      final double deliveryFee = (_selectedRegion?['price'] ?? 0).toDouble();
      final String? selectedRegionName = _selectedRegion?['name']?.toString();

      // 4. إنشاء الطلبات في Firestore
      for (final rid in groupedOrders.keys) {
        final groupItems = groupedOrders[rid]!;
        double totalAmount = 0.0;
        for (var i in groupItems) {
          totalAmount += (i['price'] * i['quantity']);
        }
        final String restaurantDocId = rid;

        if (restaurantDocId.isEmpty || restaurantDocId == 'general_orders') {
          throw Exception('تعذّر إرسال الطلب حالياً، حاول مرة ثانية بعد شوية');
        }

        String restaurantName = 'مطعم';
        try {
          final restSnap = await FirebaseFirestore.instance.collection('users').doc(restaurantDocId).get();
          if (restSnap.exists) {
            restaurantName = restSnap.data()?['restaurantName'] ?? restSnap.data()?['fullName'] ?? 'مطعم';
          }
        } catch (e) {
          debugPrint('Error fetching restaurant name: $e');
        }

        final orderData = {
          'restaurantDocId': restaurantDocId,
          'restaurantId': rid,
          'restaurantOwnerId': rid,
          'restaurantName': restaurantName,
          'orderType': 'food',
          'userId': _uid,
          'customerId': _uid,
          'customerEmail': FirebaseAuth.instance.currentUser?.email ?? '',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'items': groupItems,
          'total': totalAmount,
          'deliveryFee': deliveryFee,
          'discount': 0.0,
          'grandTotal': totalAmount + deliveryFee,
          'selectedRegion': selectedRegionName,
          'customerName': _nameController.text.trim(),
          'customerPhone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'notes': _notesController.text.trim(),
          'locationType': _selectedLocationType,
          'readByRestaurant': false,
          'latitude': _selectedLatLng?.latitude,
          'longitude': _selectedLatLng?.longitude,
        };

        final orderRef = await FirebaseFirestore.instance.collection('orders').add(orderData);
        await orderRef.update({'orderId': orderRef.id});

        // Mirror to restaurants collection
        try {
          final restaurantOrderRef = FirebaseFirestore.instance
              .collection('restaurants')
              .doc(restaurantDocId)
              .collection('orders')
              .doc(orderRef.id);
          final copyData = Map<String, dynamic>.from(orderData);
          copyData['orderId'] = orderRef.id;
          copyData['createdAt'] = FieldValue.serverTimestamp();
          await restaurantOrderRef.set(copyData);
        } catch (e) {
          debugPrint('Error mirroring order to restaurant: $e');
        }

        // 2. Add to Customer History (Madar Orders)
        try {
          await FirebaseFirestore.instance
              .collection('madar_orders')
              .doc(_uid)
              .collection('orders')
              .doc(orderRef.id)
              .set({
            ...orderData,
            'orderId': orderRef.id,
            'createdAt': FieldValue.serverTimestamp(),
          });
          debugPrint(' Order synced to customer history');
        } catch (e) {
          debugPrint('Error syncing to customer history: $e');
        }

        // Notifications to both Merchant (Restaurant Owner) and Delivery Captains
        try {
          // ℹ إشعار المطعم يتم تلقائياً عبر Cloud Function (notifyRestaurantOnNewOrder)
          // عند إنشاء المستند في orders collection — لا حاجة لـ emitEvent هنا

          // Notify Delivery Driver via Server Event (لا يوجد trigger مباشر لهذا)
          await NotificationService.emitEvent(
            type: 'food_order',
            payload: {
              'order_id': orderRef.id,
              'restaurant_id': restaurantDocId,
              'title': 'طلب طعام جديد للتوصيل',
              'body': 'هناك طلب طعام جديد جاهز للتوصيل في منطقتك! سارع بقبوله',
            },
          );
          // Notify Customer via Server Event
          await NotificationService.emitEvent(
            type: 'order_status_updated',
            payload: {'order_id': orderRef.id, 'status': 'pending'},
          );
        } catch (e) {
          debugPrint('Notification error: $e');
        }
      }

      // Update user profile coordinates & info
      try {
        await FirebaseFirestore.instance.collection('users').doc(_uid).update({
          'fullName': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'latitude': _selectedLatLng?.latitude,
          'longitude': _selectedLatLng?.longitude,
        });
      } catch (e) {
        debugPrint('Error updating user profile: $e');
      }

      // 5. تنظيف السلة
      await _clearCart();
      _showSnack('تم إرسال طلبك بنجاح!', Colors.green);

      // 6. Thank you dialog
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: primaryColor, size: 72),
                    const SizedBox(height: 12),
                    const Text(
                      'شكراً لطلبك!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'تم استلام طلبك وسيتم التواصل معك قريباً.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'العودة للرئيسية',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
      _showSnack('حدث خطأ: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<String?> _resolveRealOwnerId(String itemId, String? hintRid) async {
    if (hintRid != null && hintRid.length >= 20) return hintRid;
    try {
      var query =
          await FirebaseFirestore.instance
              .collectionGroup('menu')
              .where(FieldPath.documentId, isEqualTo: itemId)
              .limit(1)
              .get();
      if (query.docs.isEmpty) {
        query =
            await FirebaseFirestore.instance
                .collectionGroup('items')
                .where(FieldPath.documentId, isEqualTo: itemId)
                .limit(1)
                .get();
      }
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        if (data['ownerId'] != null) return data['ownerId'].toString();
        final grandParentDoc = query.docs.first.reference.parent.parent;
        if (grandParentDoc != null) {
          if (grandParentDoc.parent.id == 'restaurants') return grandParentDoc.id;
          final pSnap = await grandParentDoc.get();
          final pData = pSnap.data();
          if (pData != null) {
            return (pData['ownerId'] ?? pData['uid'] ?? pData['restaurantId'])?.toString();
          }
        }
      }
    } catch (_) {}
    return hintRid;
  }

  Future<void> _clearCart() async {
    if (_uid != null) {
      final cartId = GroupCartManager.getEffectiveCartId(_uid!);
      final col = FirebaseFirestore.instance.collection('carts').doc(cartId).collection('items');
      final snap = await col.get();
      final batch = FirebaseFirestore.instance.batch();
      for (var d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }
}
