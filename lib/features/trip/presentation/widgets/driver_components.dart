import 'package:flutter/material.dart';
import 'package:dalal_alqaim/features/trip/domain/entities/trip.dart';
import 'package:dalal_alqaim/features/trip/presentation/trip_design.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────
// شريحة الحالة – Status Chip
// ─────────────────────────────────────────────────────────────
class StatusChip extends StatelessWidget {
  final TripStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _chipConfig;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [config.color, config.color.withValues(alpha: 0.85)]),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: config.color.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            config.text,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: TripDesign.kFontFamily,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  _ChipConfig get _chipConfig {
    switch (status) {
      case TripStatus.arrived:
        return _ChipConfig('الكابتن وصل', Icons.pin_drop_rounded, const Color(0xFF26A69A));
      case TripStatus.started:
        return _ChipConfig('الرحلة جارية', Icons.navigation_rounded, const Color(0xFF1E88E5));
      default:
        return _ChipConfig('الكابتن في الطريق', Icons.local_taxi_rounded, const Color(0xFFFF9800));
    }
  }
}

class _ChipConfig {
  final String text;
  final IconData icon;
  final Color color;
  const _ChipConfig(this.text, this.icon, this.color);
}

// ─────────────────────────────────────────────────────────────
// بطاقة السائق – Driver Profile Card
// ─────────────────────────────────────────────────────────────
class DriverProfileCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onChat;
  final VoidCallback onCancel;

  const DriverProfileCard({
    super.key,
    required this.trip,
    required this.onChat,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── صف السائق: صورة + اسم + تقييم ──
          Row(
            children: [
              // صورة السائق مع إطار متدرج
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: TripDesign.primaryGradient,
                ),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    color: const Color(0xFFF0F5F4),
                    image:
                        trip.driverImage != null
                            ? DecorationImage(
                              image: NetworkImage(trip.driverImage!),
                              fit: BoxFit.cover,
                            )
                            : null,
                  ),
                  child:
                      trip.driverImage == null
                          ? const Icon(Icons.person_rounded, color: Color(0xFF26A69A), size: 28)
                          : null,
                ),
              ),
              const SizedBox(width: 14),
              // معلومات السائق
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.driverName ?? 'اسم السائق',
                      style: const TextStyle(
                        fontFamily: TripDesign.kFontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // التقييم
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 14),
                              const SizedBox(width: 2),
                              Text(
                                trip.driverRating?.toStringAsFixed(1) ?? 'غير متوفر',
                                style: const TextStyle(
                                  fontFamily: TripDesign.kFontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE6A800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── معلومات السيارة ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF26A69A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.directions_car_rounded,
                    color: Color(0xFF26A69A),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.driverCar ?? '',
                        style: const TextStyle(
                          fontFamily: TripDesign.kFontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                      if (trip.driverCarColor != null && trip.driverCarColor!.isNotEmpty)
                        Text(
                          trip.driverCarColor!,
                          style: TextStyle(
                            fontFamily: TripDesign.kFontFamily,
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ),
                // رقم لوحة (إن وجد)
                if (trip.driverCarNumber != null && trip.driverCarNumber!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      trip.driverCarNumber!,
                      style: const TextStyle(
                        fontFamily: TripDesign.kFontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── أزرار التفاعل ──
          Row(
            children: [
              // اتصال
              Expanded(
                child: _ActionButton(
                  icon: Icons.phone_rounded,
                  label: 'اتصال',
                  color: const Color(0xFF1E88E5),
                  onTap: () => _makeCall(trip.driverPhone),
                ),
              ),
              const SizedBox(width: 10),
              // محادثة
              Expanded(
                child: _ActionButton(
                  icon: Icons.chat_bubble_rounded,
                  label: 'محادثة',
                  color: const Color(0xFF26A69A),
                  onTap: onChat,
                ),
              ),
              const SizedBox(width: 10),
              // إلغاء
              Expanded(
                child: _ActionButton(
                  icon: Icons.close_rounded,
                  label: 'إلغاء',
                  color: const Color(0xFFEF5350),
                  onTap: onCancel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _makeCall(String? phone) async {
    if (phone == null) return;
    final url = Uri.parse("tel:$phone");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// زر الأكشن – Action Button
// ─────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: TripDesign.kFontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
