// رادار وقائمة الطلبات المتاحة للتوصيل (Delivery Available Orders Radar Widget)
// Presentation Layer — Pure UI Component

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/delivery_dashboard_models.dart';
import 'delivery_unified_order_card.dart';

class DeliveryAvailableOrdersRadar extends StatelessWidget {
  final List<DeliveryOrderEntity> orders;
  final bool isOnline;
  final Set<String> activeLocks;
  final ValueChanged<DeliveryOrderEntity> onAcceptOrder;
  final ValueChanged<DeliveryOrderEntity> onOrderDetails;
  final VoidCallback onToggleOnline;

  static const Color _primary = Color(0xFF00BFA5);
  static const Color _primaryDark = Color(0xFF00897B);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSub = Color(0xFF475569);
  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _borderLight = Color(0xFFE2E8F0);

  const DeliveryAvailableOrdersRadar({
    super.key,
    required this.orders,
    required this.isOnline,
    this.activeLocks = const {},
    required this.onAcceptOrder,
    required this.onOrderDetails,
    required this.onToggleOnline,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOnline) {
      return _buildOfflineRadarState();
    }

    if (orders.isEmpty) {
      return _buildEmptyRadarState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final isLocked = activeLocks.contains(order.id);

        return DeliveryUnifiedOrderCard(
          order: order,
          isAccepting: isLocked,
          onAccept: () => onAcceptOrder(order),
          onDetails: () => onOrderDetails(order),
        );
      },
    );
  }

  Widget _buildOfflineRadarState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _cardLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderLight, width: 1.2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded, size: 48, color: _textSub),
          ),
          const SizedBox(height: 16),
          Text(
            'أنت في وضع عدم الاتصال (أوفلاين)',
            style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'قم بتفعيل اتصالك لبدء استقبال طلبات المطاعم والمتاجر ومرسال فورياً.',
            style: GoogleFonts.ibmPlexSansArabic(color: _textSub, fontSize: 13, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onToggleOnline,
            icon: const Icon(Icons.power_settings_new_rounded, size: 18),
            label: Text('الاتصال بالشبكة الآن', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w900, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRadarState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _cardLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderLight, width: 1.2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.radar_rounded, size: 48, color: _primaryDark),
          ),
          const SizedBox(height: 16),
          Text(
            'الرادار نشط وجاري البحث عن طلبات...',
            style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            'ماكو طلبات حالياً جديدة معلقة في منطقتك حالياً. سيصلك إشعار وتنبيه صوتي فور توفر أي طلب!',
            style: GoogleFonts.ibmPlexSansArabic(color: _textSub, fontSize: 12.5, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
