import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// ══════════════════════════════════════════════════════════════════════════════
/// Madar High-End 3D Transparent Service Graphics (أيقونات ومجسمات ثري دي لمدار)
/// ══════════════════════════════════════════════════════════════════════════════

class Madar3DServiceGraphic extends StatelessWidget {
  final String serviceType;
  final double size;

  const Madar3DServiceGraphic({
    super.key,
    required this.serviceType,
    this.size = 56.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.r,
      height: size.r,
      child: Center(
        child: _build3DGraphic(serviceType),
      ),
    );
  }

  Widget _build3DGraphic(String type) {
    switch (type) {
      // Core Main Services
      case 'taxi':
        return _Taxi3DVisual(size: size);
      case 'restaurants':
        return _Restaurants3DVisual(size: size);
      case 'stores':
        return _Stores3DVisual(size: size);
      case 'mersal':
        return _Mersal3DVisual(size: size);
      case 'doctors':
        return _Doctors3DVisual(size: size);
      case 'medical':
        return _MedicalSections3DVisual(size: size);

      // Quick Services
      case 'real_estate':
        return _RealEstate3DVisual(size: size);
      case 'jobs':
        return _Jobs3DVisual(size: size);
      case 'emergency':
        return _Emergency3DVisual(size: size);
      case 'complaints':
        return _Complaints3DVisual(size: size);
      case 'contact':
        return const _Contact3DVisual();
      case 'help':
        return _Help3DVisual(size: size);
      default:
        return _Taxi3DVisual(size: size);
    }
  }
}

/// ─── 1. 3D Madar Taxi (تكسي مدار) ───
class _Taxi3DVisual extends StatelessWidget {
  final double size;
  const _Taxi3DVisual({this.size = 56.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.r,
      height: size.r,
      child: Center(
        child: Image.asset(
          'imges/cartaxi.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _buildFallbackVector(),
        ),
      ),
    );
  }

  Widget _buildFallbackVector() {
    return Container(
      width: (size * 0.72).r,
      height: (size * 0.72).r,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFFEF3C7), width: 1.4),
      ),
      child: Center(
        child: Icon(
          Icons.local_taxi_rounded,
          color: Colors.white,
          size: (size * 0.38).sp,
        ),
      ),
    );
  }
}

/// ─── 2. 3D Gourmet Burger & Meal (مطاعم مدار) ───
class _Restaurants3DVisual extends StatelessWidget {
  final double size;
  const _Restaurants3DVisual({this.size = 56.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.r,
      height: size.r,
      child: Center(
        child: Image.asset(
          'imges/food.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _buildFallbackVector(),
        ),
      ),
    );
  }

  Widget _buildFallbackVector() {
    return Container(
      width: (size * 0.72).r,
      height: (size * 0.72).r,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          color: Colors.white,
          size: (size * 0.38).sp,
        ),
      ),
    );
  }
}

/// ─── 3. 3D Boutique Shopping Cart & Bag (متاجر مدار) ───
class _Stores3DVisual extends StatelessWidget {
  final double size;
  const _Stores3DVisual({this.size = 56.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.r,
      height: size.r,
      child: Center(
        child: Image.asset(
          'imges/shop.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _buildFallbackVector(),
        ),
      ),
    );
  }

  Widget _buildFallbackVector() {
    return Container(
      width: (size * 0.72).r,
      height: (size * 0.72).r,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00BFA5), Color(0xFF00897B), Color(0xFF004D40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Center(
        child: Icon(
          Icons.shopping_bag_rounded,
          color: Colors.white,
          size: (size * 0.38).sp,
        ),
      ),
    );
  }
}

/// ─── 4. 3D Mersal Delivery Image & Visual (مرسال مدار) ───
class _Mersal3DVisual extends StatelessWidget {
  final double size;
  const _Mersal3DVisual({this.size = 56.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.r,
      height: size.r,
      child: Center(
        child: Image.asset(
          'imges/delvery.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _buildFallbackVector(),
        ),
      ),
    );
  }

  Widget _buildFallbackVector() {
    return Container(
      width: (size * 0.72).r,
      height: (size * 0.72).r,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED), Color(0xFF5B21B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFDDD6FE), width: 1.4),
      ),
      child: Center(
        child: Icon(
          Icons.delivery_dining_rounded,
          color: Colors.white,
          size: (size * 0.38).sp,
        ),
      ),
    );
  }
}

/// ─── 5. 3D Doctors & Medical Clinic (دليل الأطباء) ───
class _Doctors3DVisual extends StatelessWidget {
  final double size;
  const _Doctors3DVisual({this.size = 56.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.r,
      height: size.r,
      child: Center(
        child: Image.asset(
          'imges/doctor.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _buildFallbackVector(),
        ),
      ),
    );
  }

  Widget _buildFallbackVector() {
    return Container(
      width: (size * 0.72).r,
      height: (size * 0.72).r,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF34D399), Color(0xFF10B981), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 1.4),
      ),
      child: Center(
        child: Icon(
          Icons.health_and_safety_rounded,
          color: Colors.white,
          size: (size * 0.40).sp,
        ),
      ),
    );
  }
}

/// ─── 6. 3D Sections Portal (الأقسام الشاملة) ───
class _MedicalSections3DVisual extends StatelessWidget {
  final double size;
  const _MedicalSections3DVisual({this.size = 56.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.r,
      height: size.r,
      child: Center(
        child: Image.asset(
          'imges/sections.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _buildFallbackVector(),
        ),
      ),
    );
  }

  Widget _buildFallbackVector() {
    return Container(
      width: (size * 0.72).r,
      height: (size * 0.72).r,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1.4),
      ),
      child: Center(
        child: Icon(
          Icons.domain_rounded,
          color: Colors.white,
          size: (size * 0.40).sp,
        ),
      ),
    );
  }
}

/// ─── 7. 3D Modern Real Estate Towers & Property Landmark (العقارات) ───
class _RealEstate3DVisual extends StatelessWidget {
  final double size;
  const _RealEstate3DVisual({this.size = 56.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.r,
      height: size.r,
      child: Center(
        child: Image.asset(
          'imges/aqair.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _buildFallbackVector(),
        ),
      ),
    );
  }

  Widget _buildFallbackVector() {
    return Container(
      width: (size * 0.72).r,
      height: (size * 0.72).r,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2DD4BF), Color(0xFF00BFA5), Color(0xFF004D40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 1.4),
      ),
      child: Center(
        child: Icon(
          Icons.apartment_rounded,
          color: Colors.white,
          size: (size * 0.40).sp,
        ),
      ),
    );
  }
}

/// ─── 8. 3D Executive Briefcase & Career Portal (الوظائف) ───
class _Jobs3DVisual extends StatelessWidget {
  final double size;
  const _Jobs3DVisual({this.size = 56.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.r,
      height: size.r,
      child: Center(
        child: Image.asset(
          'imges/job.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _buildFallbackVector(),
        ),
      ),
    );
  }

  Widget _buildFallbackVector() {
    return Container(
      width: (size * 0.72).r,
      height: (size * 0.72).r,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF14B8A6), Color(0xFF0F766E), Color(0xFF115E59)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF5EEAD4), width: 1.4),
      ),
      child: Center(
        child: Icon(
          Icons.work_rounded,
          color: Colors.white,
          size: (size * 0.40).sp,
        ),
      ),
    );
  }
}

/// ─── 9. 3D Emergency Siren / Rescue Cross (الطوارئ) ───
class _Emergency3DVisual extends StatelessWidget {
  final double size;
  const _Emergency3DVisual({this.size = 56.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.r,
      height: size.r,
      child: Center(
        child: Image.asset(
          'imges/twara.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _buildFallbackVector(),
        ),
      ),
    );
  }

  Widget _buildFallbackVector() {
    return Container(
      width: (size * 0.72).r,
      height: (size * 0.72).r,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFDC2626), Color(0xFF991B1B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
      ),
      child: Center(
        child: Icon(
          Icons.emergency_rounded,
          color: Colors.white,
          size: (size * 0.40).sp,
        ),
      ),
    );
  }
}

/// ─── 10. 3D Customer Protection & Complaints Portal (الشكاوى والمقترحات) ───
class _Complaints3DVisual extends StatelessWidget {
  final double size;
  const _Complaints3DVisual({this.size = 56.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.r,
      height: size.r,
      child: Center(
        child: Image.asset(
          'imges/sakoia.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _buildFallbackVector(),
        ),
      ),
    );
  }

  Widget _buildFallbackVector() {
    return Container(
      width: (size * 0.72).r,
      height: (size * 0.72).r,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFB45309)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
      ),
      child: Center(
        child: Icon(
          Icons.campaign_rounded,
          color: Colors.white,
          size: (size * 0.40).sp,
        ),
      ),
    );
  }
}

/// ─── 11. 3D Phone Hotline Capsule (دليل الاتصال) ───
class _Contact3DVisual extends StatelessWidget {
  const _Contact3DVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48.r,
      height: 48.r,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 2.h,
            child: Container(
              width: 36.r,
              height: 10.r,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.5),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 38.r,
            height: 38.r,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF38BDF8), Color(0xFF0284C7), Color(0xFF0369A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.phone_in_talk_rounded,
                color: Colors.white,
                size: 21.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── 12. 3D Madar Customer Support Specialist (المساعدة والدعم) ───
class _Help3DVisual extends StatelessWidget {
  final double size;
  const _Help3DVisual({this.size = 56.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.r,
      height: size.r,
      child: Center(
        child: Image.asset(
          'imges/help.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _buildFallbackVector(),
        ),
      ),
    );
  }

  Widget _buildFallbackVector() {
    return Container(
      width: (size * 0.72).r,
      height: (size * 0.72).r,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2DD4BF), Color(0xFF0D9488), Color(0xFF134E4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF99F6E4), width: 1.5),
      ),
      child: Center(
        child: Icon(
          Icons.support_agent_rounded,
          color: Colors.white,
          size: (size * 0.40).sp,
        ),
      ),
    );
  }
}
