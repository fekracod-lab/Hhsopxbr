import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';

class IncomingRequestScreen extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final Function(String, Map<String, dynamic>) onAccept;
  final Function(String) onReject;
  final Map<String, dynamic> driverData;

  const IncomingRequestScreen({
    super.key,
    required this.rideData,
    required this.onAccept,
    required this.onReject,
    required this.driverData,
  });

  @override
  State<IncomingRequestScreen> createState() => _IncomingRequestScreenState();
}

class _IncomingRequestScreenState extends State<IncomingRequestScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  StreamSubscription<DocumentSnapshot>? _statusSubscription;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    // Pulse animation for the buttons and headers
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _listenToStatusChanges();
    _startTimeoutTimer();
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) {
        debugPrint(' IncomingRequestScreen: Timeout reached (15s). Auto-rejecting.');
        _handleReject();
      }
    });
  }

  void _listenToStatusChanges() {
    final rideId = widget.rideData['id'] ?? widget.rideData['rideId'];
    if (rideId != null && rideId.toString().isNotEmpty) {
      _statusSubscription = FirebaseFirestore.instance
          .collection('ride_requests')
          .doc(rideId.toString())
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data != null) {
            final status = data['status'] as String?;
            // If the ride is no longer pending, close the screen
            if (status != 'pending' && mounted) {
              _closeScreen();
            }
          }
        } else if (mounted) {
          // If document is deleted, close screen
          _closeScreen();
        }
      });
    }
  }

  void _closeScreen() {
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _statusSubscription?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _handleAccept() {
    HapticFeedback.heavyImpact();
    _timeoutTimer?.cancel();
    widget.onAccept(widget.rideData['id'] ?? widget.rideData['rideId'] ?? '', widget.driverData);
    Navigator.pop(context);
  }

  void _handleReject() {
    HapticFeedback.lightImpact();
    _timeoutTimer?.cancel();
    widget.onReject(widget.rideData['id'] ?? widget.rideData['rideId'] ?? '');
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Information
    final pickup = widget.rideData['pickupAddress'] ?? widget.rideData['pickup']?['address'] ?? 'موقع الانطلاق';
    final dropoff = widget.rideData['dropoffAddress'] ?? widget.rideData['dropoff']?['address'] ?? 'الوجهة';
    final price = widget.rideData['price']?.toString() ?? 'غير محدد';
    final customerName = widget.rideData['customerName'] ?? 'زبون مدار';
    final customerPhoto = widget.rideData['customerPhoto'];
    final rideType = widget.rideData['rideType'] ?? 'تاكسي مدار';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background Map Blur Effect
            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            Positioned.fill(
               child: BackdropFilter(
                 filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
                 child: Container(
                   color: const Color(0xFF07191A).withValues(alpha: 0.85),
                 ),
               ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                  // Top Section (Title & Caller Info)
                  Column(
                    children: [
                      const SizedBox(height: 30),
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Column(
                          children: [
                            const Text(
                              'طلب رحلة جديد',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryColor,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'جاري الاتصال...',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        rideType,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Customer Avatar
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5), width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                          image: DecorationImage(
                            image: customerPhoto != null
                                ? NetworkImage(customerPhoto)
                                : const AssetImage('assets/images/logo.png') as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                          const SizedBox(width: 5),
                          Text(
                            (widget.rideData['passengerRating'] as num?)?.toDouble().toStringAsFixed(1) ??
                                widget.rideData['passengerRating']?.toString() ??
                                'جديد',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Middle Section (Ride Details Card)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        children: [
                          _buildLocationRow(Icons.my_location_rounded, 'الانطلاق:', pickup, AppTheme.successColor),
                          Padding(
                            padding: const EdgeInsets.only(left: 17, right: 17),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                height: 30,
                                width: 2,
                                color: Colors.white24,
                              ),
                            ),
                          ),
                          _buildLocationRow(Icons.location_on_rounded, 'الوجهة:', dropoff, AppTheme.errorColor),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Divider(color: Colors.white12, height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'السعر المقدر',
                                style: TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                              Text(
                                price,
                                style: const TextStyle(color: AppTheme.primaryColor, fontSize: 20, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Section (Action Buttons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 50.0, left: 30, right: 30),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Decline Button
                        Column(
                          children: [
                            GestureDetector(
                              onTap: _handleReject,
                              child: Container(
                                width: 75,
                                height: 75,
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Colors.redAccent.withValues(alpha: 0.4), blurRadius: 15, spreadRadius: 3),
                                  ],
                                ),
                                child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 35),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text('رفض', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),

                        // Accept Button
                        Column(
                          children: [
                            GestureDetector(
                              onTap: _handleAccept,
                              child: ScaleTransition(
                                scale: _pulseAnimation,
                                child: Container(
                                  width: 75,
                                  height: 75,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00C853),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFF00C853).withValues(alpha: 0.4), blurRadius: 15, spreadRadius: 3),
                                    ],
                                  ),
                                  child: const Icon(Icons.call_rounded, color: Colors.white, size: 35),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text('قبول', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                    ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
