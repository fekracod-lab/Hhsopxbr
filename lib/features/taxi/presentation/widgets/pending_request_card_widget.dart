import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/entities/driver_dashboard_models.dart';

/// ويدجت بطاقة الطلب الجديد العائم مع مؤقت عد تنازلي معزول (Isolated Timer Countdown)
class PendingRequestCardWidget extends StatefulWidget {
  final RideRequestEntity request;
  final bool isProcessing;
  final Future<void> Function(RideRequestEntity request) onAccept;
  final Future<void> Function(RideRequestEntity request) onReject;

  const PendingRequestCardWidget({
    super.key,
    required this.request,
    required this.isProcessing,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<PendingRequestCardWidget> createState() => _PendingRequestCardWidgetState();
}

class _PendingRequestCardWidgetState extends State<PendingRequestCardWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  Timer? _countdownTimer;
  int _remainingSeconds = 30;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _initCountdown();
  }

  void _initCountdown() {
    if (widget.request.createdAt != null) {
      final elapsed = DateTime.now().difference(widget.request.createdAt!).inSeconds;
      _remainingSeconds = (30 - elapsed).clamp(0, 30);
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        widget.onReject(widget.request);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remainingSeconds / 30.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF26A69A), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF26A69A).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // شريط التقدم الزمني للطلب
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.3 ? const Color(0xFF26A69A) : Colors.redAccent,
              ),
              minHeight: 6,
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // رأس البطاقة: السعر واسم الراكب
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
                          child: const Icon(Icons.person_pin_circle_rounded, color: Color(0xFF26A69A), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.request.passengerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'المسافة: ${widget.request.distanceKm.toStringAsFixed(1)} كم',
                              style: const TextStyle(fontSize: 12, color: Colors.white54),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: Text(
                        '${widget.request.estimatedFare.toStringAsFixed(0)} د.ع',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // مسار الانطلاق والوصول
                _buildLocationRow(Icons.my_location_rounded, Colors.greenAccent, 'من:', widget.request.pickupAddress),
                const SizedBox(height: 8),
                _buildLocationRow(Icons.location_on_rounded, Colors.redAccent, 'إلى:', widget.request.destinationAddress),
                const SizedBox(height: 20),

                // أزرار القبول والرفض
                Row(
                  children: [
                    // زر الرفض
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: widget.isProcessing ? null : () => widget.onReject(widget.request),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('تخطي', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // زر القبول
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: widget.isProcessing ? null : () => widget.onAccept(widget.request),
                        icon: widget.isProcessing
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_rounded, color: Colors.white),
                        label: Text(
                          widget.isProcessing ? 'جاري القبول...' : 'قبول الطلب ($_remainingSeconds ث)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF26A69A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, Color color, String label, String address) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
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
