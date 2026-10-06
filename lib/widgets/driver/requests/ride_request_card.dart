import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

const Color kPrimary = Color(0xFF26A69A); // Modern Teal
const Color kCardBg = Color(0xFF0C2428);
const Color kTextWhite = Color(0xFFFFFFFF);
const Color kTextSub = Color(0xFF80CBC4);

class RideRequestCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final Map<String, dynamic> driverData;
  final bool isDark;
  final Function(String) onReject;
  final Function(String, Map<String, dynamic>) onAccept;

  const RideRequestCard({
    super.key,
    required this.id,
    required this.data,
    required this.driverData,
    required this.isDark,
    required this.onReject,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? kCardBg : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kPrimary.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            // Header Section
            _buildHeader(isDark),
            
            // Route Details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: _buildRouteDetails(isDark),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: _buildActionButtons(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: kPrimary.withValues(alpha: 0.15))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kPrimary.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.local_taxi_rounded, color: kPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['userName'] ?? 'درب جديد',
                    style: TextStyle(
                      color: isDark ? kTextWhite : const Color(0xFF0C2428),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const Text(
                    'طلب تكسي متاح يمك هسه',
                    style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kPrimary.withValues(alpha: 0.4)),
            ),
            child: Text(
              _formatPrice(data['price']),
              style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteDetails(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            _dotIndicator(Colors.green),
            _lineConnector(),
            _dotIndicator(Colors.redAccent),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: [
              _locationItem('مكان الزبون (الانطلاق)', data['pickupAddress'] ?? 'غير محدد', Colors.green, isDark),
              const SizedBox(height: 18),
              _locationItem('الوجهة (النزول)', data['dropoffAddress'] ?? data['destinationAddress'] ?? 'غير محدد', Colors.redAccent, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dotIndicator(Color color) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(child: Container(width: 4, height: 4, decoration: BoxDecoration(color: color, shape: BoxShape.circle))),
    );
  }

  Widget _lineConnector() {
    return Container(
      width: 2,
      height: 32,
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.green.withValues(alpha: 0.5), Colors.redAccent.withValues(alpha: 0.5)],
        ),
      ),
    );
  }

  Widget _locationItem(String label, String address, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text(
          address,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isDark ? kTextWhite : const Color(0xFF0C2428),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Reject Button (مشغول / تجاوز)
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onReject(id);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                SizedBox(width: 6),
                Text(
                  'مشغول',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Accept Button (أخذ الدرب)
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.heavyImpact();
              onAccept(id, driverData);
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF26A69A), Color(0xFF00796B)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF26A69A).withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('أخذ الدرب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    SizedBox(width: 8),
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatPrice(dynamic p) {
    if (p == null) return 'غير محدد';
    final n = double.tryParse(p.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
    if (n == null) return p.toString();
    return '${NumberFormat('#,###').format(n)} د.ع';
  }
}
