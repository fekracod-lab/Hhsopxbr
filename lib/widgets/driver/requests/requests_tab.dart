import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/mersal_request.dart';
import '../../../models/parcel_delivery_request.dart';
import 'ride_request_card.dart';
import 'dart:math' as math;

const Color _primaryTeal = Color(0xFF26A69A);

class RequestsTab extends StatelessWidget {
  final Map<String, dynamic> driverData;
  final bool isDark;
  final Stream<QuerySnapshot> requestsStream;
  final Stream<List<MersalRequest>>? mRequestsStream;
  final Stream<List<ParcelDeliveryRequest>>? pRequestsStream;
  final Function(String) onRejectRide;
  final Function(String, Map<String, dynamic>) onAcceptRide;
  final Function(ParcelDeliveryRequest, Map<String, dynamic>)? onShowParcelDetails;
  final Function(String) onToggleStatus;

  const RequestsTab({
    super.key,
    required this.driverData,
    required this.isDark,
    required this.requestsStream,
    this.mRequestsStream,
    this.pRequestsStream,
    required this.onRejectRide,
    required this.onAcceptRide,
    this.onShowParcelDetails,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: requestsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: _buildRadarState(isDark));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _primaryTeal));
        }

        final now = DateTime.now();
        final currentDriverId = driverData['id'] ?? driverData['uid'];
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final status = data['status'] as String? ?? '';
          if (status != 'searching' && status != 'pending') return false;

          final rejectedDrivers = (data['rejectedDrivers'] as List?) ?? [];
          if (currentDriverId != null && rejectedDrivers.contains(currentDriverId)) {
            return false;
          }

          final rawCreated = data['createdAt'];
          DateTime? createdAt;
          if (rawCreated is Timestamp) createdAt = rawCreated.toDate();
          if (rawCreated is DateTime) createdAt = rawCreated;
          if (rawCreated is String) createdAt = DateTime.tryParse(rawCreated);

          if (createdAt == null) return false;
          final difference = now.difference(createdAt).inSeconds;
          return difference <= 90 && difference >= -60;
        }).toList();

        final bool hasRideRequests = docs.isNotEmpty;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              // Ride Requests
              if (hasRideRequests) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.near_me_rounded, color: _primaryTeal, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'دروب تكسي قريبة عليك هسه (${docs.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? Colors.white : const Color(0xFF0C2428),
                        ),
                      ),
                    ],
                  ),
                ),
                ...docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return RideRequestCard(
                    id: doc.id,
                    data: data,
                    driverData: driverData,
                    isDark: isDark,
                    onReject: onRejectRide,
                    onAccept: onAcceptRide,
                  );
                }),
              ],

              // Radar Search State (if no ride requests)
              if (!hasRideRequests) _buildRadarState(isDark),

              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRadarState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const RadarAnimation(),
          const SizedBox(height: 28),
          Text(
            'جاري البحث عن مشاوير تكسي وركاب قريبين يمك...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0C2428),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'خلّك متصل وأول ما ينزل مشوار تكسي راح ننبّهك برنّة واهتزاز فوراً',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class RadarAnimation extends StatefulWidget {
  const RadarAnimation({super.key});

  @override
  State<RadarAnimation> createState() => _RadarAnimationState();
}

class _RadarAnimationState extends State<RadarAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: RadarPainter(_controller.value),
          size: const Size(200, 200),
        );
      },
    );
  }
}

class RadarPainter extends CustomPainter {
  final double progress;
  RadarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    final paint = Paint()
      ..color = _primaryTeal.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * (i / 3), paint);
    }

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [Colors.transparent, _primaryTeal.withValues(alpha: 0.5)],
        stops: const [0.75, 1.0],
        transform: GradientRotation(progress * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);

    final pulseRadius = radius * progress;
    final pulsePaint = Paint()
      ..color = _primaryTeal.withValues(alpha: 0.15 * (1 - progress))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, pulseRadius, pulsePaint);

    // Center Pulse Dot
    canvas.drawCircle(center, 6, Paint()..color = _primaryTeal);
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) => true;
}
