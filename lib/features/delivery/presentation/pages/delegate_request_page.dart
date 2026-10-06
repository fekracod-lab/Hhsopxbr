import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:geolocator/geolocator.dart';
import 'package:dalal_alqaim/models/delegate_request.dart';
import 'package:dalal_alqaim/services/delegate_service.dart';
import 'package:dalal_alqaim/core/app_globals.dart'; // for isDarkModeNotifier
import 'package:dalal_alqaim/services/notification_service.dart';
import 'package:dalal_alqaim/core/location_permission_helper.dart'; // Added helper import

// Colors tailored for Personal Delegate (Using the Teal/Accent palette from DeliveryPage)
const Color kPrimaryColor = Color(0xFF26A69A);
const Color kAccentColor = Color(0xFF00796B);
const Color kLightBg = Color(0xFFFFFFFF);
const Color kLightSurface = Color(0xFFF8F9FA);
const Color kLightText = Color(0xFF333333);
const Color kLightSubText = Color(0xFF757575);

const Color kDarkBg = Color(0xFF07191A);
const Color kDarkSurface = Color(0xFF0F2323);
const Color kDarkCard = Color(0xFF113033);
const Color kDarkText = Color(0xFFE0F2F1);
const Color kDarkSubText = Color(0xFF80CBC4);

class DelegateRequestPage extends StatefulWidget {
  const DelegateRequestPage({super.key});

  @override
  State<DelegateRequestPage> createState() => _DelegateRequestPageState();
}

class _DelegateRequestPageState extends State<DelegateRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  int _durationHours = 1;
  bool _isLoading = false;
  LatLng? _currentPosition;
  final DelegateService _delegateService = DelegateService();

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    bool hasPermission = await LocationPermissionHelper.requestLocationPermissionWithDisclosure(
      context,
    );

    if (!hasPermission) return;

    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
    if (mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
    }
  }

  double _calculatePrice() {
    // Pricing logic: Base 1000 + 2000 per hour
    // Clamped as per user's preference for other services?
    // Let's go with 1500 per hour base for delegate
    return (1000.0 + (_durationHours * 1500.0)).clamp(1000.0, 10000.0);
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentPosition == null) {
      _showSnackBar('جاري تحديد موقعك الجغرافي...', kAccentColor);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('يجب تسجيل الدخول أولاً');

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final request = DelegateRequest(
        id: '',
        userId: user.uid,
        userName: userData['name'] ?? 'مستخدم',
        userPhone: userData['phone'] ?? '',
        taskDescription: _descriptionController.text.trim(),
        durationHours: _durationHours,
        pickupLat: _currentPosition!.latitude,
        pickupLng: _currentPosition!.longitude,
        pickupAddress:
            _addressController.text.trim().isEmpty
                ? 'موقعي الحالي'
                : _addressController.text.trim(),
        status: 'pending',
        price: _calculatePrice(),
        createdAt: DateTime.now(),
      );

      final requestId = await _delegateService.createRequest(request);

      // Emit Event to Server
      await NotificationService.emitEvent(
        type: 'delegate_request_created',
        payload: {'request_id': requestId},
      );

      if (mounted) _showSuccessDialog();
    } catch (e) {
      if (mounted) _showSnackBar('حدث خطأ: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.fixed,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: isDarkModeNotifier.value ? kDarkSurface : kLightSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.network(
                  'https://assets9.lottiefiles.com/packages/lf20_9w8vuniz.json',
                  height: 150,
                  repeat: false,
                ),
                Text(
                  'تم إرسال طلبك!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkModeNotifier.value ? kDarkText : kLightText,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'سيقوم المندوب الشخصي بالتواصل معك قريباً.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDarkModeNotifier.value ? kDarkSubText : kLightSubText,
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'موافق',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        return Scaffold(
          backgroundColor: isDark ? kDarkBg : kLightBg,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context, isDark),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(
                          'وصف المهمة المطلوبة',
                          Icons.assignment_outlined,
                          isDark,
                        ),
                        _buildField(
                          controller: _descriptionController,
                          hint:
                              'مثلاً: مراجعة دائرة حكومية، الانتظار في طابور، أو أي خدمة شخصية...',
                          maxLines: 4,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 25),
                        _buildSectionTitle(
                          'المدة المطلوبة (بالساعات)',
                          Icons.timer_outlined,
                          isDark,
                        ),
                        _buildDurationSelector(isDark),
                        const SizedBox(height: 25),
                        _buildSectionTitle(
                          'مكان اللقاء أو التنفيذ',
                          Icons.location_on_outlined,
                          isDark,
                        ),
                        _buildLocationBanner(isDark),
                        _buildField(
                          controller: _addressController,
                          hint: 'عنوان دقيق أو علامة دالة (اختياري)',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 30),
                        _buildPriceCard(isDark),
                        const SizedBox(height: 30),
                        _buildSubmitButton(isDark),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      elevation: 0,
      backgroundColor: kPrimaryColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark ? [kDarkSurface, kDarkBg] : [kPrimaryColor, kAccentColor],
                ),
              ),
            ),
            Positioned(
              right: -20,
              bottom: -20,
              child: Opacity(
                opacity: 0.1,
                child: Icon(Icons.hail_rounded, size: 180, color: Colors.white),
              ),
            ),
            Center(
              child: Lottie.network(
                'https://assets5.lottiefiles.com/packages/lf20_m6cu9m9f.json', // Delegate/Delivery animation
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        title: const Text(
          'طلب مندوب شخصي',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isDark ? kDarkSubText : kPrimaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? kDarkText : kLightText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : kLightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
        ),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(fontSize: 14, color: isDark ? kDarkText : kLightText),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? kDarkSubText.withValues(alpha: 0.5) : Colors.grey.shade400,
            fontSize: 13,
          ),
          contentPadding: const EdgeInsets.all(18),
          border: InputBorder.none,
        ),
        validator: (v) {
          if (hint.contains('اختياري')) return null;
          return (v == null || v.isEmpty) ? 'هذا الحقل مطلوب' : null;
        },
      ),
    );
  }

  Widget _buildDurationSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : kLightSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(5, (index) {
          int value = index + 1;
          bool isSelected = _durationHours == value;
          return GestureDetector(
            onTap: () => setState(() => _durationHours = value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? kPrimaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                '$value س',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : (isDark ? kDarkText : kLightText),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLocationBanner(bool isDark) {
    bool hasLocation = _currentPosition != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:
            hasLocation
                ? (isDark
                    ? kPrimaryColor.withValues(alpha: 0.1)
                    : kPrimaryColor.withValues(alpha: 0.08))
                : (Colors.redAccent.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              hasLocation
                  ? kPrimaryColor.withValues(alpha: 0.3)
                  : Colors.redAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasLocation ? Icons.location_history_rounded : Icons.gps_not_fixed,
            color: hasLocation ? kPrimaryColor : Colors.redAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasLocation ? 'سيصل المندوب إلى موقعك الحالي' : 'جاري تحديد موقعك...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: hasLocation ? kPrimaryColor : Colors.redAccent,
                  ),
                ),
                if (hasLocation)
                  Text(
                    'تأكد من تواجدك في المكان عند طلب الخدمة.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? kDarkSubText : kLightSubText,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'التكلفة التقديرية',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? kDarkSubText : kLightSubText,
                ),
              ),
              Text(
                '${_calculatePrice().toInt()} د.ع',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryColor,
                ),
              ),
            ],
          ),
          Icon(Icons.payments_outlined, size: 40, color: kPrimaryColor.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 5,
          shadowColor: kPrimaryColor.withValues(alpha: 0.4),
        ),
        child:
            _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'تأكيد طلب المندوب',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.check_circle_outline, size: 20),
                  ],
                ),
      ),
    );
  }
}
