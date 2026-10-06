import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dalal_alqaim/widgets/driver/requests/requests_tab.dart';
import 'package:dalal_alqaim/widgets/driver/history/driver_history_tab.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/wallet_page.dart';
import 'package:dalal_alqaim/core/utils/map_marker_utils.dart';

import '../../../application/driver_dashboard_controller.dart';
import '../../../domain/entities/driver_dashboard_models.dart';
import '../../../domain/services/driver_dashboard_calculator.dart';
import '../../widgets/driver_top_status_bar.dart';
import '../../widgets/driver_quick_stats_bar.dart';
import '../../widgets/driver_map_view.dart';
import '../../widgets/driver_notifications_sheet.dart';
import '../../widgets/driver_account_tab.dart';
import 'package:dalal_alqaim/services/user_service.dart';

/// Driver Dashboard Page (لوحة تحكم الكابتن)
/// تم تحويل الصفحة إلى معمارية نظيفة مفصولة الطبقات مع حماية ذرية للتزامن (Concurrency-Safe Clean Architecture).
class DriverDashboardPage extends StatefulWidget {
  const DriverDashboardPage({super.key});

  @override
  State<DriverDashboardPage> createState() => _DriverDashboardPageState();
}

class _DriverDashboardPageState extends State<DriverDashboardPage> with TickerProviderStateMixin {
  late final DriverDashboardController _controller;
  GoogleMapController? _mapController;
  bool _isStatsExpanded = false;
  LatLng? _lastFollowedPosition;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _controller = DriverDashboardController(driverUid: uid)..init();
    _controller.addListener(_onControllerUpdated);
    _loadCarIcon();
  }

  void _onControllerUpdated() {
    if (!mounted || _mapController == null) return;
    if (_controller.shouldFollowDriver && _controller.liveDriverPosition != null) {
      final pos = _controller.liveDriverPosition!;
      if (_lastFollowedPosition == null ||
          (_lastFollowedPosition!.latitude - pos.latitude).abs() > 0.0001 ||
          (_lastFollowedPosition!.longitude - pos.longitude).abs() > 0.0001) {
        _lastFollowedPosition = pos;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _mapController != null) {
            _mapController!.animateCamera(CameraUpdate.newLatLng(pos));
          }
        });
      }
    }
  }

  Future<void> _loadCarIcon() async {
    try {
      final icon = await MapMarkerUtils.createTealCarMarker();
      if (mounted) {
        _controller.setCarIcon(icon);
      }
    } catch (e) {
      debugPrint('[DriverDashboardPage] Error loading car icon: $e');
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdated);
    _mapController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final profile = _controller.driverProfile;
        final stats = _controller.driverStats;

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: SafeArea(
            child: Stack(
              children: [
                // محتوى التبويب المختار
                IndexedStack(
                  index: _controller.currentTab,
                  children: [
                    // تبويب الخريطة والطلبات الحية (Tab 0)
                    DriverMapView(
                      initialPosition: _controller.initialDriverPosition,
                      livePosition: _controller.liveDriverPosition,
                      carIcon: _controller.carIcon,
                      polylines: _controller.polylines,
                      shouldFollowDriver: _controller.shouldFollowDriver,
                      activeRide: _controller.activeRide,
                      pendingRequests: _controller.filteredPendingRequests,
                      isProcessing: _controller.isProcessing,
                      onMapCreated: (mapCtrl) {
                        _mapController = mapCtrl;
                        if (_controller.liveDriverPosition != null) {
                          _lastFollowedPosition = _controller.liveDriverPosition;
                          mapCtrl.animateCamera(CameraUpdate.newLatLng(_controller.liveDriverPosition!));
                        }
                      },
                      onToggleFollow: () => _controller.setShouldFollowDriver(!_controller.shouldFollowDriver),
                      onAcceptRequest: _handleAcceptRequest,
                      onRejectRequest: (req) => _controller.rejectRide(req),
                      onUpdateRideStatus: _controller.updateRideStatus,
                    ),

                    // تبويب الطلبات المتاحة (Tab 1)
                    RequestsTab(
                      driverData: _controller.driverProfile?.rawData ?? {'uid': _controller.driverUid},
                      isDark: true,
                      requestsStream: FirebaseFirestore.instance
                          .collection('ride_requests')
                          .where('status', whereIn: ['searching', 'pending'])
                          .snapshots()
                          .handleError((e) {
                            debugPrint('[DriverDashboard] Ride requests stream error: $e');
                          }),
                      onRejectRide: (reqId) {
                        _controller.rejectRide(RideRequestEntity(
                          id: reqId,
                          passengerName: '',
                          passengerPhone: '',
                          pickupAddress: '',
                          pickupLat: 0,
                          pickupLng: 0,
                          destinationAddress: '',
                          destinationLat: 0,
                          destinationLng: 0,
                          estimatedFare: 0,
                          status: RideStatus.searching,
                        ));
                      },
                      onAcceptRide: (reqId, reqData) {
                        _handleAcceptRequest(RideRequestEntity(
                          id: reqId,
                          passengerName: reqData['userName'] ?? reqData['passengerName'] ?? 'راكب مدار',
                          passengerPhone: reqData['userPhone'] ?? reqData['passengerPhone'] ?? '',
                          pickupAddress: reqData['pickupAddress'] ?? '',
                          pickupLat: (reqData['pickupLat'] is num) ? (reqData['pickupLat'] as num).toDouble() : 0.0,
                          pickupLng: (reqData['pickupLng'] is num) ? (reqData['pickupLng'] as num).toDouble() : 0.0,
                          destinationAddress: reqData['destinationAddress'] ?? '',
                          destinationLat: (reqData['destinationLat'] is num) ? (reqData['destinationLat'] as num).toDouble() : 0.0,
                          destinationLng: (reqData['destinationLng'] is num) ? (reqData['destinationLng'] as num).toDouble() : 0.0,
                          estimatedFare: (reqData['price'] is num) ? (reqData['price'] as num).toDouble() : 0.0,
                          status: RideStatus.searching,
                        ));
                      },
                      onToggleStatus: (status) => _controller.updateRideStatus(status),
                    ),

                    // تبويب سجل الرحلات السابقة (Tab 2)
                    DriverHistoryTab(
                      historyStream: _controller.driverUid != null
                          ? FirebaseFirestore.instance
                              .collection('ride_requests')
                              .where('driverId', isEqualTo: _controller.driverUid)
                              .where('status', whereIn: ['completed', 'cancelled'])
                              .snapshots()
                              .handleError((e) {
                                debugPrint('[DriverDashboard] History stream error: $e');
                              })
                          : null,
                      isDark: true,
                    ),

                    // تبويب الحساب والإعدادات وتسجيل الخروج (Tab 3)
                    DriverAccountTab(
                      profile: profile,
                      stats: stats,
                      onSignOut: _showSignOutDialog,
                      onOpenMyWay: _showMyWayDialog,
                      onNavigateToHistory: () => _controller.setTab(2),
                    ),
                  ],
                ),

                // الشريط العلوي الثابت وشريط البونص السريع (يظهر فقط في تبويب الخريطة)
                if (_controller.currentTab == 0)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DriverTopStatusBar(
                          profile: profile,
                          unreadNotificationsCount: _controller.unreadNotificationsCount,
                          isMyWayActive: _controller.isMyWayActive,
                          myWayDestination: _controller.myWayDestination,
                          onToggleOnline: _handleToggleOnline,
                          onOpenNotifications: () {
                            if (_controller.driverUid != null) {
                              DriverNotificationsSheet.show(context, _controller.driverUid!);
                            }
                          },
                          onOpenWallet: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage()));
                          },
                          onToggleMyWay: _showMyWayDialog,
                          onOpenSettings: () => _controller.setTab(3),
                        ),
                        if (_controller.activeRide == null) ...[
                          const SizedBox(height: 6),
                          DriverQuickStatsBar(
                            stats: stats,
                            isExpanded: _isStatsExpanded,
                            onToggleExpand: () => setState(() => _isStatsExpanded = !_isStatsExpanded),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNavigationBar(),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return NavigationBar(
      selectedIndex: _controller.currentTab,
      onDestinationSelected: _controller.setTab,
      backgroundColor: const Color(0xFF1E293B),
      indicatorColor: const Color(0xFF26A69A).withValues(alpha: 0.3),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.map_outlined, color: Colors.white60),
          selectedIcon: Icon(Icons.map_rounded, color: Color(0xFF26A69A)),
          label: 'الرئيسية',
        ),
        NavigationDestination(
          icon: Icon(Icons.list_alt_rounded, color: Colors.white60),
          selectedIcon: Icon(Icons.list_alt_rounded, color: Color(0xFF26A69A)),
          label: 'الطلبات',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_rounded, color: Colors.white60),
          selectedIcon: Icon(Icons.history_rounded, color: Color(0xFF26A69A)),
          label: 'السجل',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined, color: Colors.white60),
          selectedIcon: Icon(Icons.settings_rounded, color: Color(0xFF26A69A)),
          label: 'الإعدادات',
        ),
      ],
    );
  }

  Future<void> _handleToggleOnline() async {
    final profile = _controller.driverProfile;
    if (profile == null) return;

    // فحص سقف المديونية والعمولة
    if (!profile.isOnline && DriverDashboardCalculator.isCommissionBlocked(profile.debtAmount)) {
      _showCommissionBlockedDialog(profile.debtAmount);
      return;
    }

    await _controller.toggleOnlineAvailability();
  }

  Future<void> _handleAcceptRequest(RideRequestEntity request) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await _controller.acceptRide(request);

    if (!mounted) return;
    if (!success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('عذراً، تم قبول الطلب من قبل كابتن آخر أو تم إلغاؤه', style: TextStyle()),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showCommissionBlockedDialog(double debtAmount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text('تجاوز حد العمولة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        content: Text(
          'رصيد المديونية الحالي هو (${debtAmount.toStringAsFixed(0)} د.ع). يرجى شحن وتصفية رصيد المحفظة لمتابعة استقبال الطلبات.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لاحقاً', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF26A69A)),
            child: const Text('شحن المحفظة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showMyWayDialog() {
    final textController = TextEditingController(text: _controller.myWayDestination ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.alt_route_rounded, color: Color(0xFFF59E0B), size: 28),
            SizedBox(width: 10),
            Text('ميزة درب الرجعة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل اسم المنطقة أو الحي لوجهتك ليتم توجيه الطلبات الواقعة في طريقك فقط:',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'مثال: الكرادة، المنصور، الأعظمية...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
        actions: [
          if (_controller.isMyWayActive)
            TextButton(
              onPressed: () {
                _controller.toggleMyWay(false, null);
                Navigator.pop(ctx);
              },
              child: const Text('إلغاء التفعيل', style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              final dest = textController.text.trim();
              if (dest.isNotEmpty) {
                _controller.toggleMyWay(true, dest);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF26A69A)),
            child: const Text('تفعيل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showSignOutDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFE53935)),
            SizedBox(width: 8),
            Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج من لوحة تحكم الكابتن؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      if (_controller.driverProfile?.isOnline ?? false) {
        await _controller.toggleOnlineAvailability();
      }
      await UserService.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
}
