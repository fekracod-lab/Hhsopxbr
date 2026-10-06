import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/ride_chat_screen.dart';
import 'package:dalal_alqaim/services/driver_service.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';
import 'ride_map_widget.dart';

class ActiveRideWidget extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final String status;
  final bool isDark;
  final LatLng driverLocation;
  final LatLng pickup;
  final LatLng dropoff;
  final Function(String, Map<String, dynamic>) onHandleStatusUpdate;
  final Function(double, double) onLaunchNavigation;

  const ActiveRideWidget({
    super.key,
    required this.rideData,
    required this.status,
    required this.isDark,
    required this.driverLocation,
    required this.pickup,
    required this.dropoff,
    required this.onHandleStatusUpdate,
    required this.onLaunchNavigation,
  });

  @override
  State<ActiveRideWidget> createState() => _ActiveRideWidgetState();
}

class _ActiveRideWidgetState extends State<ActiveRideWidget> {
  GoogleMapController? _mapController;
  StreamSubscription? _msgSub;
  String? _lastNotifiedMsgId;

  @override
  void initState() {
    super.initState();
    _listenToCustomerMessages();
  }

  void _listenToCustomerMessages() {
    final rideId = (widget.rideData['id'] ?? widget.rideData['rideId'] ?? '').toString();
    if (rideId.isEmpty) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    _msgSub = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(rideId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (!mounted || snap.docs.isEmpty) return;
      final latestDoc = snap.docs.first;
      final data = latestDoc.data();
      final senderId = data['senderId'];
      final text = data['text'] ?? '';

      // Only notify if message is from the passenger and is new
      if (senderId != currentUid && latestDoc.id != _lastNotifiedMsgId && text.isNotEmpty) {
        _lastNotifiedMsgId = latestDoc.id;
        HapticFeedback.mediumImpact();

        final passengerName = widget.rideData['userName'] ?? 'الراكب';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0C2428),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF26A69A), width: 1.5),
            ),
            duration: const Duration(seconds: 5),
            content: Row(
              children: [
                const Icon(Icons.chat_bubble_rounded, color: Color(0xFF26A69A), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رسالة من $passengerName:',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                      ),
                      Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'رد',
              textColor: const Color(0xFF26A69A),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RideChatScreen(
                      rideId: rideId,
                      peerName: (widget.rideData['userName'] ?? 'الراكب').toString(),
                      peerId: (widget.rideData['userId'] ?? '').toString(),
                      peerPhone: widget.rideData['userPhone']?.toString(),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          // الخريطة
          Positioned.fill(
            child: RideMapWidget(
              mapController: _mapController,
              status: widget.status,
              driverLocation: widget.driverLocation,
              pickup: widget.pickup,
              dropoff: widget.dropoff,
              onLaunchNavigation: widget.onLaunchNavigation,
            ),
          ),

          // أزرار الأعلى
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: Row(
              children: [
                _TopActionButton(
                  icon: Icons.sos_rounded,
                  color: Colors.red,
                  onPressed: () => _showSOSDialog(context),
                ),
                const SizedBox(width: 10),
                _TopActionButton(
                  icon: Icons.share_rounded,
                  color: Colors.blue,
                  onPressed: () => _shareTrip(context),
                ),
              ],
            ),
          ),

          // اللوحة السفلية
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomActionPanel(
              rideData: widget.rideData,
              status: widget.status,
              isDark: widget.isDark,
              onConfirm: () => widget.onHandleStatusUpdate(widget.status, widget.rideData),
              onSOS: () => _showSOSDialog(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showSOSDialog(BuildContext context) {
    final driverUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final driverName = widget.rideData['driverName'] ?? 'كابتن مدار';
    final driverPhone = widget.rideData['driverPhone'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E0E10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              SizedBox(width: 8),
              Text(
                'نداء طوارئ واستغاثة',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 17),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'سيتم فوراً إرسال إحداثيات موقعك الحي وتفاصيل الراكب الحالي لغرفة عمليات مدار.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'الموقع: (${widget.driverLocation.latitude.toStringAsFixed(4)}, ${widget.driverLocation.longitude.toStringAsFixed(4)})',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                final rideId = (widget.rideData['id'] ?? widget.rideData['rideId'])?.toString() ?? '';
                final msg = 'نداء طوارئ كابتن مدار!\nرقم الرحلة: $rideId\nالموقع الحي: https://maps.google.com/?q=${widget.driverLocation.latitude},${widget.driverLocation.longitude}';
                launchUrl(Uri.parse('sms:07819436408?body=${Uri.encodeComponent(msg)}'));
              },
              child: const Text('إرسال SMS طوارئ', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('tel:104'), mode: LaunchMode.externalApplication);
              },
              child: const Text('اتصال بالنجدة (104)', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                try {
                  await DriverService().sendEmergencySos(
                    driverId: driverUid,
                    driverName: driverName,
                    driverPhone: driverPhone,
                    latitude: widget.driverLocation.latitude,
                    longitude: widget.driverLocation.longitude,
                    activeRideId: (widget.rideData['id'] ?? widget.rideData['rideId'])?.toString(),
                    activeRideData: widget.rideData,
                  );
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('تم إرسال نداء SOS لغرفة العمليات بنجاح! الإدارة تتابع موقعك الآن.', style: TextStyle()),
                        backgroundColor: Colors.redAccent,
                        duration: Duration(seconds: 6),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error sending active ride SOS: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('تأكيد نداء SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _shareTrip(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ رابط مشاركة الرحلة', style: TextStyle()),
      ),
    );
  }
}

// ────────────────────────────
// أزرار الأعلى
// ────────────────────────────

class _TopActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _TopActionButton({required this.icon, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      shape: const CircleBorder(),
      color: Colors.white,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

// ────────────────────────────
// اللوحة السفلية
// ────────────────────────────

class _BottomActionPanel extends StatelessWidget {
  final Map<String, dynamic> rideData;
  final String status;
  final bool isDark;
  final VoidCallback onConfirm;
  final VoidCallback onSOS;

  const _BottomActionPanel({
    required this.rideData,
    required this.status,
    required this.isDark,
    required this.onConfirm,
    required this.onSOS,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // مقبض السحب
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 16),

          // معلومات العميل
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: const Icon(Icons.person, color: AppTheme.primaryColor, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rideData['userName'] ?? 'عميل',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: isDark ? AppTheme.darkText : AppTheme.textColor,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getStatusColor(status),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getStatusLabel(status),
                          style: TextStyle(
                            fontSize: 13,
                            color: _getStatusColor(status),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // زر الدردشة مع بادج الرسائل غير المقروءة
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('ride_requests')
                    .doc((rideData['id'] ?? rideData['rideId'] ?? '').toString())
                    .collection('messages')
                    .snapshots(),
                builder: (context, msgSnap) {
                  final msgs = msgSnap.data?.docs ?? [];
                  final currentUid = FirebaseAuth.instance.currentUser?.uid;
                  final unreadCount = msgs.where((m) => m.data()['senderId'] != currentUid && (m.data()['isRead'] != true)).length;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RideChatScreen(
                                  rideId: (rideData['id'] ?? rideData['rideId'] ?? '').toString(),
                                  peerName: (rideData['userName'] ?? 'الراكب').toString(),
                                  peerId: (rideData['userId'] ?? '').toString(),
                                  peerPhone: rideData['userPhone']?.toString(),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryColor, size: 22),
                        ),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 8),
              // زر الاتصال
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    launchUrl(Uri.parse('tel:${rideData['userPhone']}'));
                  },
                  icon: const Icon(Icons.call_rounded, color: Colors.green, size: 22),
                  tooltip: 'اتصال بالزبون',
                ),
              ),
              const SizedBox(width: 8),
              // زر طوارئ واستغاثة SOS
              Container(
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: onSOS,
                  icon: const Icon(Icons.sos_rounded, color: Colors.redAccent, size: 24),
                  tooltip: 'طوارئ SOS',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // العناوين
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryColor,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      ...List.generate(
                        3,
                        (_) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: Container(
                            width: 2,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEF5350),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF5350).withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rideData['pickupAddress'] ?? 'موقع العميل',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkText : AppTheme.textColor,
                        ),
                      ),
                      const Divider(height: 16),
                      Text(
                        rideData['dropoffAddress'] ?? 'الوجهة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkText : AppTheme.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // عداد الانتظار والتنبيه عند وصول السائق لموقع الزبون
          if (status == 'arrived') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.amber, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'وصلت لموقع الزبون بانتظار ركوب الراكب',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // خطوات الرحلة
          _buildVisualStepper(),

          const SizedBox(height: 20),

          // زر السحب للتأكيد
          _SwipeToConfirm(
            text: _getActionText(status),
            color: _getStatusColor(status),
            onConfirmed: onConfirm,
          ),
        ],
      ),
    );
  }

  Widget _buildVisualStepper() {
    final steps = [
      _StepInfo('قبول', true, true),
      _StepInfo('وصول', status == 'arrived' || status == 'in_progress', status != 'accepted'),
      _StepInfo('رحلة', status == 'in_progress', status == 'in_progress' || status == 'completed'),
      _StepInfo('تم', false, status == 'completed'),
    ];

    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _StepperNode(active: steps[i].active, reached: steps[i].reached, label: steps[i].label),
          if (i < steps.length - 1) _StepperLine(active: steps[i].reached),
        ],
      ],
    );
  }

  String _getStatusLabel(String status) {
    if (status == 'accepted') return 'في الطريق للاستلام';
    if (status == 'arrived') return 'وصلت لموقع الزبون';
    if (status == 'in_progress') return 'الرحلة قائمة الآن';
    return 'الرحلة مكتملة';
  }

  Color _getStatusColor(String status) {
    if (status == 'accepted') return Colors.blue;
    if (status == 'arrived') return AppTheme.primaryColor;
    if (status == 'in_progress') return Colors.indigo;
    return AppTheme.successColor;
  }

  String _getActionText(String status) {
    if (status == 'accepted') return 'اسحب لتأكيد الوصول';
    if (status == 'arrived') return 'اسحب لبدء الرحلة';
    if (status == 'in_progress') return 'اسحب لإنهاء الرحلة';
    return 'اسحب للمتابعة';
  }
}

class _StepInfo {
  final String label;
  final bool active;
  final bool reached;
  _StepInfo(this.label, this.active, this.reached);
}

// ────────────────────────────
// خطوات الرحلة
// ────────────────────────────

class _StepperNode extends StatelessWidget {
  final bool active;
  final bool reached;
  final String label;

  const _StepperNode({required this.active, required this.reached, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  reached
                      ? AppTheme.primaryColor
                      : (active ? AppTheme.primaryColor.withValues(alpha: 0.2) : Colors.grey[200]),
            ),
            child: Icon(
              reached ? Icons.check : (active ? Icons.radio_button_checked : Icons.circle),
              size: 12,
              color: reached ? Colors.white : (active ? AppTheme.primaryColor : Colors.grey[400]),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: reached ? FontWeight.bold : FontWeight.normal,
              color: reached ? AppTheme.primaryColor : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperLine extends StatelessWidget {
  final bool active;
  const _StepperLine({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 20,
      height: 2.5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: active ? AppTheme.primaryColor : Colors.grey[200],
      ),
    );
  }
}

// ────────────────────────────
// زر السحب (مع دعم RTL)
// ────────────────────────────

class _SwipeToConfirm extends StatefulWidget {
  final String text;
  final Color color;
  final VoidCallback onConfirmed;

  const _SwipeToConfirm({required this.text, required this.color, required this.onConfirmed});

  @override
  State<_SwipeToConfirm> createState() => _SwipeToConfirmState();
}

class _SwipeToConfirmState extends State<_SwipeToConfirm> with SingleTickerProviderStateMixin {
  double _dragRatio = 0; // 0.0 = بداية, 1.0 = نهاية
  bool _confirmed = false;

  late AnimationController _resetController;
  late Animation<double> _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _resetAnimation = CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic);
    _resetController.addListener(() {
      setState(() {
        _dragRatio = _resetAnimation.value;
      });
    });
  }

  @override
  void didUpdateWidget(covariant _SwipeToConfirm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      setState(() {
        _dragRatio = 0.0;
        _confirmed = false;
      });
      _resetController.reset();
      _resetAnimation = CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const knobSize = 54.0;
    const containerHeight = 62.0;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final maxDrag = totalWidth - knobSize - 10; // مع هامش
        final currentPosition = _dragRatio * maxDrag;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            if (_confirmed) return;
            final delta = isRtl ? -details.delta.dx : details.delta.dx;
            setState(() {
              _dragRatio = (_dragRatio + delta / maxDrag).clamp(0.0, 1.0);
            });
          },
          onHorizontalDragEnd: (_) {
            if (_confirmed) return;
            if (_dragRatio >= 0.85) {
              // تأكيد!
              setState(() {
                _dragRatio = 1.0;
                _confirmed = true;
              });
              HapticFeedback.heavyImpact();
              widget.onConfirmed();

              // إعادة التعيين بعد فترة
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  setState(() {
                    _dragRatio = 0;
                    _confirmed = false;
                  });
                }
              });
            } else {
              // إرجاع الكرة بأنيميشن
              _resetAnimation = Tween<double>(
                begin: _dragRatio,
                end: 0.0,
              ).animate(CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic));
              _resetController.reset();
              _resetController.forward();
            }
          },
          child: Container(
            height: containerHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(containerHeight / 2),
              border: Border.all(color: widget.color.withValues(alpha: 0.15)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // شريط التقدم
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(containerHeight / 2),
                    child: Align(
                      alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 50),
                        width: currentPosition + knobSize,
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: _confirmed ? 0.3 : 0.12),
                          borderRadius: BorderRadius.circular(containerHeight / 2),
                        ),
                      ),
                    ),
                  ),
                ),

                // النص
                AnimatedOpacity(
                  opacity: _confirmed ? 0.0 : (1.0 - _dragRatio * 1.5).clamp(0.0, 1.0),
                  duration: const Duration(milliseconds: 150),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.text,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: widget.color,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_double_arrow_left_rounded,
                        color: widget.color.withValues(alpha: 0.5),
                        size: 18,
                      ),
                    ],
                  ),
                ),

                // أيقونة النجاح
                if (_confirmed) Icon(Icons.check_rounded, color: widget.color, size: 28),

                // الكرة
                Positioned(
                  right: isRtl ? currentPosition + 5 : null,
                  left: isRtl ? null : currentPosition + 5,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 50),
                    width: knobSize,
                    height: knobSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors:
                          _confirmed
                            ? [Colors.green, Colors.green.shade700]
                            : [widget.color, widget.color.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _confirmed
                        ? Icons.check_rounded
                        : (isRtl
                          ? Icons.arrow_back_ios_new_rounded
                          : Icons.arrow_forward_ios_rounded),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
