import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/driver_dashboard_models.dart';

/// ويدجت لوحة تحكم الرحلة الحالية النشطة
class DriverActiveRideOverlay extends StatelessWidget {
  final RideRequestEntity activeRide;
  final Future<void> Function(String newStatus) onUpdateStatus;

  const DriverActiveRideOverlay({
    super.key,
    required this.activeRide,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF26A69A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس الرحلة: اسم الراكب وزر الاتصال والملاحة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF26A69A).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded, color: Color(0xFF26A69A), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeRide.passengerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _getStatusLabel(activeRide.status),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF26A69A)),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  // زر الاتصال الهاتفي
                  if (activeRide.passengerPhone.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF10B981)),
                      onPressed: () => launchUrl(Uri.parse('tel:${activeRide.passengerPhone}')),
                    ),

                  // زر فتح تطبيق خرائط Google
                  IconButton(
                    icon: const Icon(Icons.navigation_rounded, color: Colors.blueAccent),
                    onPressed: () {
                      final lat = activeRide.status == RideStatus.accepted ? activeRide.pickupLat : activeRide.destinationLat;
                      final lng = activeRide.status == RideStatus.accepted ? activeRide.pickupLng : activeRide.destinationLng;
                      launchUrl(Uri.parse('google.navigation:q=$lat,$lng'));
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // تفاصيل المسار
          _buildLocationRow(Icons.my_location_rounded, Colors.greenAccent, 'نقطة الانطلاق:', activeRide.pickupAddress),
          const SizedBox(height: 6),
          _buildLocationRow(Icons.location_on_rounded, Colors.redAccent, 'الوجهة:', activeRide.destinationAddress),
          const SizedBox(height: 20),

          // زر تقدم حالة الرحلة
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    switch (activeRide.status) {
      case RideStatus.accepted:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => onUpdateStatus('arrived'),
            icon: const Icon(Icons.location_on_rounded, color: Colors.white),
            label: const Text('وصلت لموقع الراكب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        );
      case RideStatus.arrived:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => onUpdateStatus('in_progress'),
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            label: const Text('بدء الرحلة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        );
      case RideStatus.inProgress:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => onUpdateStatus('completed'),
            icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
            label: Text(
              'إنهاء الرحلة وتحصيل (${activeRide.estimatedFare.toStringAsFixed(0)} د.ع)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF26A69A),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _getStatusLabel(RideStatus status) {
    switch (status) {
      case RideStatus.accepted:
        return 'في الطريق للراكب';
      case RideStatus.arrived:
        return 'في موقع الراكب';
      case RideStatus.inProgress:
        return 'الرحلة جارية نحو الوجهة';
      default:
        return '';
    }
  }

  Widget _buildLocationRow(IconData icon, Color color, String label, String address) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            address,
            style: const TextStyle(fontSize: 13, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
