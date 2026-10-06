import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dalal_alqaim/services/mersal_service.dart';
import 'package:dalal_alqaim/models/mersal_request.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/customer_mersal_tracking_page.dart';

class MersalTrackingWidget extends StatelessWidget {
  const MersalTrackingWidget({super.key});

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'جاي نبحث عن كابتن قريب إلك...';
      case 'accepted':
        return 'الكابتن قبل الطلب وطاير للمحل';
      case 'arrived_at_pickup':
        return 'الكابتن وصل للمحل وجاي يشتري الغراض';
      case 'picked_up':
      case 'on_the_way':
        return 'الغراض جاهزة والكابتن بطريقه إلك';
      case 'delivered':
      case 'completed':
        return 'عاشت إيدك! تم تسليم الغراض بنجاح';
      default:
        return 'جاري المتابعة والتنفيذ...';
    }
  }

  String _getCategoryTitle(String? category) {
    switch (category) {
      case 'pharmacy':
        return 'علاج صيدلية';
      case 'supermarket':
        return 'مسواك السوك';
      case 'express':
        return 'مرسال مستعجل';
      case 'restaurant':
        return 'أكل ومطاعم';
      default:
        return 'طلب مِـرسال';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.radar_rounded;
      case 'accepted':
        return Icons.electric_moped_rounded;
      case 'arrived_at_pickup':
        return Icons.storefront_rounded;
      case 'picked_up':
      case 'on_the_way':
        return Icons.delivery_dining_rounded;
      case 'delivered':
      case 'completed':
        return Icons.check_circle_rounded;
      default:
        return Icons.hourglass_bottom_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<MersalRequest>>(
      stream: MersalService().getUserActiveOrders(user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final activeOrders = snapshot.data!;
        final order = activeOrders.first;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerMersalTrackingPage(
                    requestId: order.id,
                    initialRequest: order,
                  ),
                ),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [Colors.white, const Color(0xFFF0FDF4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF00BFA5).withValues(alpha: 0.35),
                  width: 1.3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00BFA5).withValues(alpha: isDark ? 0.2 : 0.1),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BFA5).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getStatusIcon(order.status),
                          color: const Color(0xFF00BFA5),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'طلب نشط: ${_getCategoryTitle(order.category)}',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              _getStatusText(order.status),
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11.5,
                                color: const Color(0xFF00897B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (order.driverPhone != null && order.driverPhone!.isNotEmpty)
                        _actionButton(
                          Icons.phone_in_talk_rounded,
                          () async {
                            final uri = Uri.parse('tel:${order.driverPhone}');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                        ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BFA5).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 13,
                          color: Color(0xFF00BFA5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress Bar
                  _buildProgressIndicator(order.status),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order.storeName ?? (order.driverName != null ? 'الكابتن: ${order.driverName}' : 'المحل: حسب الاتفاق'),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.touch_app_rounded, size: 13, color: Color(0xFF00BFA5)),
                          const SizedBox(width: 4),
                          Text(
                            'انقر لتتبع الكابتن',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF00BFA5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator(String status) {
    int step = 1;
    switch (status) {
      case 'pending':
        step = 1;
        break;
      case 'accepted':
        step = 2;
        break;
      case 'arrived_at_pickup':
        step = 3;
        break;
      case 'picked_up':
      case 'on_the_way':
        step = 4;
        break;
      case 'delivered':
      case 'completed':
        step = 5;
        break;
    }

    return Row(
      children: List.generate(5, (index) {
        final isActive = index < step;
        return Expanded(
          child: Container(
            height: 4.5,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF00BFA5) : const Color(0xFF00BFA5).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }

  Widget _actionButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: const Color(0xFF00BFA5),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00BFA5).withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 17, color: Colors.white),
      ),
    );
  }
}
