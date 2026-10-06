// صفحة لوحة تحكم مندوب التوصيل المنسقة (Delivery Dashboard Coordinator Page)
// Clean Architecture Presentation Layer — Pure Coordinator

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dalal_alqaim/features/delivery/domain/entities/delivery_dashboard_models.dart';
import 'package:dalal_alqaim/features/delivery/application/delivery_dashboard_controller.dart';
import 'package:dalal_alqaim/features/delivery/data/repositories/delivery_dashboard_repository.dart';

import 'package:dalal_alqaim/features/delivery/presentation/widgets/delivery_dashboard_header.dart';
import 'package:dalal_alqaim/features/delivery/presentation/widgets/delivery_daily_quest_banner.dart';
import 'package:dalal_alqaim/features/delivery/presentation/widgets/delivery_order_filter_chips.dart';
import 'package:dalal_alqaim/features/delivery/presentation/widgets/delivery_available_orders_radar.dart';
import 'package:dalal_alqaim/features/delivery/presentation/widgets/delivery_active_tasks_view.dart';
import 'package:dalal_alqaim/features/delivery/presentation/widgets/delivery_history_view.dart';
import 'package:dalal_alqaim/features/delivery/presentation/widgets/delivery_performance_view.dart';
import 'package:dalal_alqaim/features/delivery/presentation/widgets/delivery_profile_settings_view.dart';

import 'package:dalal_alqaim/services/ringtone_manager.dart';
import 'package:dalal_alqaim/services/onesignal_service.dart';
import 'package:dalal_alqaim/services/user_service.dart';

import 'package:dalal_alqaim/features/delivery/presentation/pages/mersal_order_details_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/order_delivery_details_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/profile_edit_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/wallet_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/live_order_map_page.dart';
import 'package:dalal_alqaim/pages/technical_support_chat_page.dart';
import 'package:dalal_alqaim/pages/delivery_weekly_accounting_page.dart';
import 'package:dalal_alqaim/models/mersal_request.dart';

class DeliveryDashboardPage extends StatefulWidget {
  final DeliveryDashboardController? controller;

  const DeliveryDashboardPage({
    super.key,
    this.controller,
  });

  @override
  State<DeliveryDashboardPage> createState() => _DeliveryDashboardPageState();
}

class _DeliveryDashboardPageState extends State<DeliveryDashboardPage> {
  late final DeliveryDashboardController _controller;
  bool _isControllerLocal = false;
  int _currentIndex = 0;

  static const Color _primary = Color(0xFF00BFA5);
  static const Color _bgLight = Color(0xFFF8FAFC);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSub = Color(0xFF475569);

  final List<String> _quickPrices = [
    '1000',
    '1500',
    '2000',
    '2500',
    '3000',
    '3500',
    '4000',
    '5000',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _isControllerLocal = false;
    } else {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      _controller = DeliveryDashboardController(
        driverId: uid,
        repository: DeliveryDashboardRepository(),
        onNewIncomingOrder: (order) {
          RingtoneManager.startAlarm(order.id, autoStopSeconds: 30);
        },
        onOrderNoLongerPending: (orderId) {
          RingtoneManager.stopAlarm(orderId);
        },
      );
      _isControllerLocal = true;

      if (uid.isNotEmpty) {
        OneSignalService.syncUserRole(uid);
      }
    }
  }

  @override
  void dispose() {
    if (_isControllerLocal) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: _bgLight,
            body: _buildCurrentTab(),
            bottomNavigationBar: _buildBottomNav(),
          ),
        );
      },
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return _buildRadarTab();
      case 1:
        return _buildActiveTasksTab();
      case 2:
        return _buildHistoryTab();
      case 3:
        return _buildPerformanceTab();
      case 4:
        return _buildSettingsTab();
      default:
        return _buildRadarTab();
    }
  }

  Widget _buildRadarTab() {
    return CustomScrollView(
      slivers: [
        DeliveryDashboardHeader(
          driverName: _controller.driverName,
          isOnline: _controller.isOnline,
          isToggling: _controller.isTogglingAvailability,
          todayEarnings: _controller.statistics.todayEarnings,
          todayCompletedCount: _controller.statistics.todayCompletedCount,
          appDebt: _controller.appDebt,
          onToggleOnline: () => _controller.toggleAvailability(),
          onOpenLiveMap: _openLiveMap,
        ),
        SliverToBoxAdapter(
          child: DeliveryDailyQuestBanner(
            questProgress: _controller.questProgress,
          ),
        ),
        SliverToBoxAdapter(
          child: DeliveryOrderFilterChips(
            selectedFilter: _controller.selectedFilter,
            onFilterChanged: (f) => _controller.setFilter(f),
          ),
        ),
        SliverToBoxAdapter(
          child: DeliveryAvailableOrdersRadar(
            orders: _controller.filteredAvailableOrders,
            isOnline: _controller.isOnline,
            activeLocks: {
              for (final o in _controller.filteredAvailableOrders)
                if (_controller.isOrderLocked(o.id)) o.id
            },
            onAcceptOrder: _handleAcceptOrder,
            onOrderDetails: _handleOrderDetails,
            onToggleOnline: () => _controller.toggleAvailability(),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTasksTab() {
    return Scaffold(
      appBar: AppBar(
        title: Text('مهامي قيد التوصيل', style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: DeliveryActiveTasksView(
        activeTasks: _controller.activeTasks,
        onOpenTaskDetails: _handleOrderDetails,
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Scaffold(
      appBar: AppBar(
        title: Text('سجل الطلبات المسلمة', style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: DeliveryHistoryView(
        historyOrders: _controller.historyOrders,
        onOrderTap: _handleOrderDetails,
      ),
    );
  }

  Widget _buildPerformanceTab() {
    return Scaffold(
      appBar: AppBar(
        title: Text('لوحة الأداء والإحصائيات', style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: DeliveryPerformanceView(
        statistics: _controller.statistics,
        onOpenWeeklyAccounting: _openWeeklyAccounting,
        onOpenWallet: _openWallet,
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Scaffold(
      appBar: AppBar(
        title: Text('الملف الشخصي والإعدادات', style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: DeliveryProfileSettingsView(
        driverName: _controller.driverName,
        driverPhone: _controller.driverPhone,
        rating: _controller.rating,
        isOnline: _controller.isOnline,
        isTogglingAvailability: _controller.isTogglingAvailability,
        onToggleAvailability: () => _controller.toggleAvailability(),
        onEditProfile: _openEditProfile,
        onSupportChat: _openSupportChat,
        onSignOut: _showSignOutDialog,
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        selectedItemColor: _primary,
        unselectedItemColor: _textSub,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w900, fontSize: 11),
        unselectedLabelStyle: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 10.5),
        elevation: 0,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.radar_rounded), label: 'الرادار'),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _controller.activeTasks.isNotEmpty,
              label: Text('${_controller.activeTasks.length}'),
              child: const Icon(Icons.delivery_dining_rounded),
            ),
            label: 'مهامي',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'السجل'),
          const BottomNavigationBarItem(icon: Icon(Icons.insights_rounded), label: 'الأداء'),
          const BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'حسابي'),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  // أوامر وإجراءات المنسق (Coordinator Actions)
  // ────────────────────────────────────────────

  Future<void> _handleAcceptOrder(DeliveryOrderEntity order) async {
    RingtoneManager.stopAlarm(order.id);

    if (order.isCustomPrice) {
      final selectedPrice = await _showPriceSelectionBottomSheet(order);
      if (selectedPrice == null) return;

      final res = await _controller.acceptOrder(order: order, agreedPrice: selectedPrice);
      _showAcceptanceFeedback(res);
    } else {
      final res = await _controller.acceptOrder(order: order);
      _showAcceptanceFeedback(res);
    }
  }

  void _showAcceptanceFeedback(OrderAcceptanceResult result) {
    if (!mounted) return;
    if (result == OrderAcceptanceResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم استلام وقبول الطلب بنجاح! توجه لاستلامه'),
          backgroundColor: Color(0xFF00C853),
        ),
      );
      setState(() => _currentIndex = 1); // الانتقال لتبويب المهام
    } else if (result == OrderAcceptanceResult.serverRejected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عذراً، تم قبول الطلب من قبل مندوب آخر مسبقاً.'),
          backgroundColor: Color(0xFFE53935),
        ),
      );
    } else if (result == OrderAcceptanceResult.alreadyLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري معالجة استلام هذا الطلب بالفعل...'),
          backgroundColor: Color(0xFF0284C7),
        ),
      );
    } else if (result == OrderAcceptanceResult.notEligible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب أن تكون متصلاً لاستلام الطلبات.'),
          backgroundColor: Color(0xFFE65100),
        ),
      );
    }
  }

  Future<String?> _showPriceSelectionBottomSheet(DeliveryOrderEntity order) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'حدد أجرة التوصيل المناسبة',
                    style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'طلب مرسال مفتوح السعر من ${order.sourceName} إلى ${order.dropoffName}. اختر سعرك للقبول:',
                style: GoogleFonts.ibmPlexSansArabic(color: _textSub, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickPrices.map((price) {
                  return ActionChip(
                    label: Text(
                      '$price د.ع',
                      style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () => Navigator.pop(ctx, price),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _handleOrderDetails(DeliveryOrderEntity order) {
    if (order.source == DeliveryOrderSource.mersal) {
      final req = MersalRequest.fromMap(order.rawData, order.id);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MersalOrderDetailsPage(
            request: req,
            driverData: _controller.driverProfile,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDeliveryDetailsPage(
            order: order.rawData,
            driverData: _controller.driverProfile,
          ),
        ),
      );
    }
  }

  void _openLiveMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LiveOrdersMapPage(),
      ),
    );
  }

  void _openWeeklyAccounting() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryWeeklyAccountingPage(
          driverId: _controller.driverId,
        ),
      ),
    );
  }

  void _openWallet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const WalletPage(),
      ),
    );
  }

  void _openEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileEditPage(),
      ),
    );
  }

  void _openSupportChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TechnicalSupportChatPage()),
    );
  }

  Future<void> _showSignOutDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تسجيل الخروج', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w900)),
        content: Text('هل أنت متأكد من رغبتك في تسجيل الخروج من لوحة المندوب؟', style: GoogleFonts.ibmPlexSansArabic()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: _textSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('خروج', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await UserService.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
}
