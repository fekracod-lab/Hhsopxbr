import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/error/madar_crash_guard.dart';
import '../../../../core/database/local_database_service.dart';
import '../../../pos/domain/pos_order.dart';
import '../../../pos/domain/pos_cart_item.dart';
import '../../../../core/constants/pos_constants.dart';
import '../../../../services/thermal_printer_service.dart';
import '../../../../services/delivery_dispatch_service.dart';
import '../../../../services/audio_alert_service.dart';
import '../../../../services/audit_log_service.dart';
import '../../../../core/design_system/madar_design_system.dart';

/// صفحة إدارة الطلبات المتقدمة لسطح المكتب (Master-Detail)
/// مربوطة بنسبة 100% بالبيانات والأعداد الحقيقية المباشرة من Firestore و SQLite
class OrdersManagementPage extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const OrdersManagementPage({super.key, this.onNavigate});

  @override
  State<OrdersManagementPage> createState() => _OrdersManagementPageState();
}

class _OrdersManagementPageState extends State<OrdersManagementPage>
    with SingleTickerProviderStateMixin {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _selectedStatusFilter = 'all';
  String _selectedSourceFilter = 'all';
  String _selectedDateFilter = 'all'; // 'all', 'today', 'yesterday', 'week', 'custom'
  DateTimeRange? _customDateRange;
  String _searchQuery = '';
  PosOrder? _selectedOrder;
  late TabController _detailTabController;
  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 1;
  static const int _pageSize = 10;
  List<PosOrder> _localOrders = [];
  String _restaurantName = 'مطعم مدار';
  String _effectiveRestaurantId = '';

  // ميزات جديدة: التحديد الجماعي والتنبيه الصوتي الحقيقي وترتيب ونمط عرض الفواتير
  final Set<String> _selectedOrderIds = {};
  final Set<String> _knownPendingOrderIds = {};
  bool _hasInitialStreamLoaded = false;
  bool _isAudioMuted = false;
  String? _latestNewOrderId;
  String _selectedSortOption = 'newest'; // 'newest', 'oldest', 'highest_amount', 'lowest_amount', 'priority'
  String _viewMode = 'table'; // 'table', 'cards'

  @override
  void initState() {
    super.initState();
    _detailTabController = TabController(length: 2, vsync: this);
    _loadLocalOrders();
    _loadRestaurantInfo();
  }

  Future<void> _loadRestaurantInfo() async {
    if (_uid.isEmpty) return;
    try {
      // 1. فحص بيانات المستخدم في users للحصول على معرف المطعم المرتبط
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final restId = data['restaurantId'] ?? data['merchantId'] ?? data['storeId'];
        if (restId != null && restId.toString().trim().isNotEmpty) {
          _effectiveRestaurantId = restId.toString().trim();
        }
        final name = data['restaurantName'] ?? data['storeName'] ?? data['name'];
        if (name != null && name.toString().trim().isNotEmpty && mounted) {
          _restaurantName = name.toString().trim();
        }
      }

      // 2. فحص بيانات restaurants
      final doc = await FirebaseFirestore.instance.collection('restaurants').doc(_uid).get();
      if (doc.exists && doc.data() != null) {
        final name = doc.data()!['name'] ?? doc.data()!['restaurantName'];
        if (name != null && name.toString().trim().isNotEmpty && mounted) {
          _restaurantName = name.toString().trim();
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[OrdersManagementPage] Error loading restaurant info: $e');
    }
  }

  @override
  void dispose() {
    AudioAlertService.stopAlarm();
    _searchController.dispose();
    _detailTabController.dispose();
    super.dispose();
  }

  /// استرجاع الطلبات المحفوظة محلياً في SQLite مع استبعاد أي بيانات تالفة
  Future<void> _loadLocalOrders() async {
    try {
      final rows = await LocalDatabaseService.instance.getAllLocalOrders(limit: 100);
      if (mounted) {
        setState(() {
          _localOrders = rows
              .map((r) => PosOrder.fromSqlite(r))
              .where((lo) => lo.totalAmount > 0 && lo.items.isNotEmpty)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('[OrdersManagementPage] Error loading SQLite orders: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;
    final ids = [
      _uid,
      if (_effectiveRestaurantId.isNotEmpty && _effectiveRestaurantId != _uid)
        _effectiveRestaurantId,
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeCrashBoundary(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _uid.isEmpty
                ? null
                : FirebaseFirestore.instance
                    .collection('orders')
                    .where('restaurantId', whereIn: ids)
                    .snapshots(),
            builder: (context, snapshot) {
              // شريط الخطأ التشخيصي في حال تعذر الاتصال بـ Firestore
              Widget? errorBanner;
              if (snapshot.hasError) {
                final errorInfo = MadarCrashGuard.analyzeError(snapshot.error, snapshot.stackTrace);
                errorBanner = Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تنبيه قاعدة البيانات: ${errorInfo.title} (${errorInfo.code})',
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: const Color(0xFF991B1B),
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              errorInfo.message,
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: const Color(0xFFB91C1C),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          MadarCrashGuard.showErrorDialog(
                            context,
                            snapshot.error,
                            stackTrace: snapshot.stackTrace,
                          );
                        },
                        icon: const Icon(Icons.info_outline_rounded, size: 16),
                        label: Text(
                          'سبب الخطأ والحل',
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // استخراج الطلبات الحقيقية من Firestore
              final docs = snapshot.data?.docs ?? [];
              final List<PosOrder> orders = [];

              for (final doc in docs) {
                try {
                  orders.add(PosOrder.fromMap(doc.data(), doc.id));
                } catch (e) {
                  debugPrint('[OrdersManagementPage] Error parsing order ${doc.id}: $e');
                }
              }

              // دمج الطلبات المحلية المحفوظة في SQLite وغير المرفوعة بعد
              final Set<String> firestoreIds = orders.map((o) => o.orderId).toSet();
              for (final lo in _localOrders) {
                if (!firestoreIds.contains(lo.orderId)) {
                  orders.add(lo);
                }
              }

              // فرز الطلبات من الأحدث إلى الأقدم
              orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              // كشف وصول طلبات جديدة في الوقت الفعلي وتشغيل التنبيه الصوتي
              final currentPendingIds = orders
                  .where((o) => o.status.toLowerCase() == 'pending' || o.status.toLowerCase() == 'new')
                  .map((o) => o.orderId)
                  .toSet();

              if (_hasInitialStreamLoaded) {
                final newIncomingIds = currentPendingIds.difference(_knownPendingOrderIds);
                if (newIncomingIds.isNotEmpty && !_isAudioMuted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    AudioAlertService.playOrderAlarm(durationSeconds: 15);
                    if (mounted) {
                      setState(() {
                        _latestNewOrderId = newIncomingIds.first;
                      });
                    }
                  });
                }
              } else {
                _hasInitialStreamLoaded = true;
              }
              _knownPendingOrderIds
                ..clear()
                ..addAll(currentPendingIds);

              // احتساب الأعداد الحقيقية لكافة الحالات
              final counts = _calculateCounts(orders);

              // تصفية الطلبات حسب الفلاتر النشطة
              final now = DateTime.now();
              final filteredOrders = orders.where((order) {
                // 1. فلتر الحالة
                if (_selectedStatusFilter != 'all') {
                  final s = order.status.toLowerCase();
                  if (_selectedStatusFilter == 'pending') {
                    if (s != 'pending' && s != 'new') return false;
                  } else if (_selectedStatusFilter == 'completed') {
                    if (s != 'completed' && s != 'delivered') return false;
                  } else if (_selectedStatusFilter == 'on_way') {
                    if (s != 'on_way' && s != 'in_delivery') return false;
                  } else if (s != _selectedStatusFilter) {
                    return false;
                  }
                }

                // 2. فلتر المصدر
                if (_selectedSourceFilter != 'all') {
                  final t = order.orderType.toLowerCase();
                  if (_selectedSourceFilter == 'app') {
                    if (t != 'delivery' && !(order.notes?.contains('تطبيق') ?? false)) return false;
                  } else if (_selectedSourceFilter == 'dine_in') {
                    if (t != 'dine_in' && order.tableNumber == null) return false;
                  } else if (_selectedSourceFilter == 'takeaway') {
                    if (t != 'takeaway') return false;
                  }
                }

                // 3. فلتر التاريخ
                if (_selectedDateFilter == 'today') {
                  final isToday = order.createdAt.year == now.year &&
                      order.createdAt.month == now.month &&
                      order.createdAt.day == now.day;
                  if (!isToday) return false;
                } else if (_selectedDateFilter == 'yesterday') {
                  final y = now.subtract(const Duration(days: 1));
                  final isYesterday = order.createdAt.year == y.year &&
                      order.createdAt.month == y.month &&
                      order.createdAt.day == y.day;
                  if (!isYesterday) return false;
                } else if (_selectedDateFilter == 'week') {
                  final weekAgo = now.subtract(const Duration(days: 7));
                  if (order.createdAt.isBefore(weekAgo)) return false;
                } else if (_selectedDateFilter == 'custom' && _customDateRange != null) {
                  final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
                  final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
                  if (order.createdAt.isBefore(start) || order.createdAt.isAfter(end)) return false;
                }

                // 4. البحث النصي
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase().trim();
                  final name = (order.customerName ?? '').toLowerCase();
                  final phone = (order.customerPhone ?? '').toLowerCase();
                  final id = order.orderId.toLowerCase();
                  final table = (order.tableNumber ?? '').toLowerCase();
                  if (!name.contains(q) && !phone.contains(q) && !id.contains(q) && !table.contains(q)) {
                    return false;
                  }
                }

                return true;
              }).toList();

              // فرز وترتيب الفواتير حسب الخيار المختار
              filteredOrders.sort((a, b) {
                switch (_selectedSortOption) {
                  case 'oldest':
                    return a.createdAt.compareTo(b.createdAt);
                  case 'highest_amount':
                    return b.totalAmount.compareTo(a.totalAmount);
                  case 'lowest_amount':
                    return a.totalAmount.compareTo(b.totalAmount);
                  case 'priority':
                    int getPriority(String s) {
                      final lower = s.toLowerCase();
                      if (lower == 'pending' || lower == 'new') return 0;
                      if (lower == 'preparing') return 1;
                      if (lower == 'ready') return 2;
                      if (lower == 'on_way' || lower == 'in_delivery') return 3;
                      if (lower == 'completed' || lower == 'delivered') return 4;
                      return 5;
                    }
                    final pComp = getPriority(a.status).compareTo(getPriority(b.status));
                    if (pComp != 0) return pComp;
                    return b.createdAt.compareTo(a.createdAt);
                  case 'newest':
                  default:
                    return b.createdAt.compareTo(a.createdAt);
                }
              });

              // مزامنة الطلب المحدد حالياً في لوحة الفحص
              if (_selectedOrder == null && filteredOrders.isNotEmpty) {
                _selectedOrder = filteredOrders.first;
              } else if (_selectedOrder != null) {
                final matched = orders.where((o) => o.orderId == _selectedOrder!.orderId);
                if (matched.isNotEmpty) {
                  _selectedOrder = matched.first;
                } else if (filteredOrders.isNotEmpty) {
                  _selectedOrder = filteredOrders.first;
                } else {
                  _selectedOrder = null;
                }
              }

              final isTabletPortrait = MadarResponsive.isTabletPortrait(context);
              final isMobile = MadarResponsive.isMobile(context);
              final isNarrow = isTabletPortrait || isMobile;

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MadarResponsive.contentPadding(context),
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ?errorBanner,
                    if (_latestNewOrderId != null) ...[
                      _buildNewOrderAlertBanner(context),
                      const SizedBox(height: 12),
                    ],
                    _buildHeader(context),
                    const SizedBox(height: 16),
                    _buildKpiCards(context, counts),
                    const SizedBox(height: 16),
                    _buildFilterBar(context, orders.length, filteredOrders.length),
                    const SizedBox(height: 16),
                    Expanded(
                      child: isNarrow
                          ? (_viewMode == 'cards'
                              ? _buildOrdersCardsGrid(context, orders, filteredOrders, isNarrow: true)
                              : _buildOrdersTable(context, orders, filteredOrders, isNarrow: true))
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // عرض الفواتير الرئيسي (جدول أو كروت)
                                Expanded(
                                  flex: 6,
                                  child: _viewMode == 'cards'
                                      ? _buildOrdersCardsGrid(context, orders, filteredOrders, isNarrow: false)
                                      : _buildOrdersTable(context, orders, filteredOrders, isNarrow: false),
                                ),
                                const SizedBox(width: 16),
                                // لوحة فحص وتفاصيل الطلب الجانبية
                                Expanded(
                                  flex: 4,
                                  child: _buildOrderDetailsInspector(context, _selectedOrder),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── شريط التنبيه عند وصول طلب جديد ───────────────────────────

  Widget _buildNewOrderAlertBanner(BuildContext context) {
    if (_latestNewOrderId == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔔 نداء عاجل: وصل طلب جديد (#${_formatOrderId(_latestNewOrderId!)})!',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: const Color(0xFF92400E),
                  ),
                ),
                Text(
                  'يرجى مراجعة تفاصيل الطلب وتأكيد إرساله لخط تحضير المطبخ',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11.5,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              AudioAlertService.stopAlarm();
              setState(() => _latestNewOrderId = null);
            },
            icon: const Icon(Icons.volume_off_rounded, size: 16),
            label: const Text('إيقاف الرنين 🔕'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF92400E), size: 20),
            onPressed: () {
              AudioAlertService.stopAlarm();
              setState(() => _latestNewOrderId = null);
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── رأس الصفحة ───────────────────────────

  Widget _buildHeader(BuildContext context) {
    final c = context.posColors;

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إدارة الطلبات الحية',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'متابعة ومعالجة كافة الطلبات المسجلة في مطعمك بالوقت الفعلي',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                color: c.textMuted,
              ),
            ),
          ],
        ),
        const Spacer(),
        // زر كتم / تفعيل التنبيهات الصوتية للطلبات
        Tooltip(
          message: _isAudioMuted ? 'تفعيل رنين الطلبات الجديدة' : 'كتم رنين الطلبات الجديدة',
          child: InkWell(
            onTap: () {
              setState(() => _isAudioMuted = !_isAudioMuted);
              if (_isAudioMuted) AudioAlertService.stopAlarm();
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _isAudioMuted ? const Color(0xFFFEF2F2) : c.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _isAudioMuted ? const Color(0xFFEF4444) : c.border),
              ),
              child: Row(
                children: [
                  Icon(
                    _isAudioMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    size: 18,
                    color: _isAudioMuted ? const Color(0xFFDC2626) : c.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isAudioMuted ? 'صامت' : 'التنبيه نشط',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: _isAudioMuted ? const Color(0xFFDC2626) : c.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // زر تحديث فوري
        OutlinedButton.icon(
          onPressed: () {
            _loadLocalOrders();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'تم تحديث سجل الطلبات المباشرة',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                ),
                duration: const Duration(seconds: 2),
                backgroundColor: c.primary,
              ),
            );
          },
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('تحديث'),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.textPrimary,
            side: BorderSide(color: c.border),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 10),
        // زر طباعة الفاتورة للطلب المحدد
        OutlinedButton.icon(
          onPressed: _selectedOrder == null
              ? null
              : () {
                  ThermalPrinterService.printOrder(order: _selectedOrder!);
                },
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('طباعة'),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.textPrimary,
            side: BorderSide(color: c.border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 10),
        // زر إضافة طلب جديد POS
        ElevatedButton.icon(
          onPressed: () {
            if (widget.onNavigate != null) {
              widget.onNavigate!(3); // الانتقال لشاشة POS الكاشير
            }
          },
          icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
          label: const Text('+ طلب جديد (POS)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────── بطاقات الحالات الست بأرقام حقيقية ───────────────────────────

  Widget _buildKpiCards(BuildContext context, Map<String, int> counts) {
    final cardNew = _buildStatusBadgeCard(
      title: 'جديد',
      count: counts['new'] ?? 0,
      icon: Icons.shopping_cart_outlined,
      color: MadarColors.primary,
      bg: const Color(0xFFFFF7ED),
      isSelected: _selectedStatusFilter == 'pending',
      onTap: () => setState(() => _selectedStatusFilter =
          _selectedStatusFilter == 'pending' ? 'all' : 'pending'),
    );
    final cardCompleted = _buildStatusBadgeCard(
      title: 'مكتمل',
      count: counts['completed'] ?? 0,
      icon: Icons.verified_outlined,
      color: const Color(0xFF10B981),
      bg: const Color(0xFFF0FDF4),
      isSelected: _selectedStatusFilter == 'completed',
      onTap: () => setState(() => _selectedStatusFilter =
          _selectedStatusFilter == 'completed' ? 'all' : 'completed'),
    );
    final cardReady = _buildStatusBadgeCard(
      title: 'جاهز',
      count: counts['ready'] ?? 0,
      icon: Icons.shopping_bag_outlined,
      color: const Color(0xFF0284C7),
      bg: const Color(0xFFF0F9FF),
      isSelected: _selectedStatusFilter == 'ready',
      onTap: () => setState(() => _selectedStatusFilter =
          _selectedStatusFilter == 'ready' ? 'all' : 'ready'),
    );
    final cardPreparing = _buildStatusBadgeCard(
      title: 'قيد التحضير',
      count: counts['preparing'] ?? 0,
      icon: Icons.soup_kitchen_outlined,
      color: const Color(0xFFF59E0B),
      bg: const Color(0xFFFFFBEB),
      isSelected: _selectedStatusFilter == 'preparing',
      onTap: () => setState(() => _selectedStatusFilter =
          _selectedStatusFilter == 'preparing' ? 'all' : 'preparing'),
    );
    final cardOnWay = _buildStatusBadgeCard(
      title: 'قيد التوصيل',
      count: counts['on_way'] ?? 0,
      icon: Icons.delivery_dining_outlined,
      color: const Color(0xFF3B82F6),
      bg: const Color(0xFFEFF6FF),
      isSelected: _selectedStatusFilter == 'on_way',
      onTap: () => setState(() => _selectedStatusFilter =
          _selectedStatusFilter == 'on_way' ? 'all' : 'on_way'),
    );
    final cardCancelled = _buildStatusBadgeCard(
      title: 'ملغي',
      count: counts['cancelled'] ?? 0,
      icon: Icons.cancel_outlined,
      color: const Color(0xFFEF4444),
      bg: const Color(0xFFFEF2F2),
      isSelected: _selectedStatusFilter == 'cancelled',
      onTap: () => setState(() => _selectedStatusFilter =
          _selectedStatusFilter == 'cancelled' ? 'all' : 'cancelled'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              Row(
                children: [
                  cardNew,
                  const SizedBox(width: 8),
                  cardCompleted,
                  const SizedBox(width: 8),
                  cardReady,
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  cardPreparing,
                  const SizedBox(width: 8),
                  cardOnWay,
                  const SizedBox(width: 8),
                  cardCancelled,
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            cardNew,
            const SizedBox(width: 10),
            cardCompleted,
            const SizedBox(width: 10),
            cardReady,
            const SizedBox(width: 10),
            cardPreparing,
            const SizedBox(width: 10),
            cardOnWay,
            const SizedBox(width: 10),
            cardCancelled,
          ],
        );
      },
    );
  }

  Widget _buildStatusBadgeCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required Color bg,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final c = context.posColors;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? bg : c.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : c.border,
              width: isSelected ? 1.8 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11.5,
                      color: c.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$count',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── شريط التصفية والبحث ───────────────────────────

  Widget _buildFilterBar(BuildContext context, int totalOrders, int filteredCount) {
    final c = context.posColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          // فلتر التاريخ
          PopupMenuButton<String>(
            tooltip: 'تصفية حسب التاريخ',
            onSelected: (val) async {
              if (val == 'custom') {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  initialDateRange: _customDateRange ??
                      DateTimeRange(
                        start: DateTime.now().subtract(const Duration(days: 7)),
                        end: DateTime.now(),
                      ),
                  builder: (ctx, child) {
                    return Directionality(
                      textDirection: TextDirection.rtl,
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                );
                if (picked != null) {
                  setState(() {
                    _selectedDateFilter = 'custom';
                    _customDateRange = picked;
                    _currentPage = 1;
                  });
                }
              } else {
                setState(() {
                  _selectedDateFilter = val;
                  _currentPage = 1;
                });
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'all', child: Text('كافة التواريخ')),
              const PopupMenuItem(value: 'today', child: Text('طلبات اليوم')),
              const PopupMenuItem(value: 'yesterday', child: Text('طلبات الأمس')),
              const PopupMenuItem(value: 'week', child: Text('آخر 7 أيام')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'custom',
                child: Row(
                  children: [
                    Icon(Icons.date_range_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('تحديد نطاق تواريخ مخصص...'),
                  ],
                ),
              ),
            ],
            child: _buildDropdownPill(
              context,
              label: _getDateTitle(_selectedDateFilter),
              icon: Icons.calendar_today_outlined,
            ),
          ),
          const SizedBox(width: 10),
          // فلتر الحالات
          PopupMenuButton<String>(
            tooltip: 'تصفية حسب الحالة',
            onSelected: (val) => setState(() {
              _selectedStatusFilter = val;
              _currentPage = 1;
            }),
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'all', child: Text('كافة الحالات')),
              const PopupMenuItem(value: 'pending', child: Text('جديد / معلق')),
              const PopupMenuItem(value: 'preparing', child: Text('قيد التحضير بالمطبخ')),
              const PopupMenuItem(value: 'ready', child: Text('جاهز للتسليم')),
              const PopupMenuItem(value: 'on_way', child: Text('قيد التوصيل')),
              const PopupMenuItem(value: 'completed', child: Text('مكتمل ومسلّم')),
              const PopupMenuItem(value: 'cancelled', child: Text('ملغي')),
            ],
            child: _buildDropdownPill(
              context,
              label: _getStatusTitle(_selectedStatusFilter),
              icon: Icons.tune_outlined,
            ),
          ),
          const SizedBox(width: 10),
          // مصادر الطلب
          PopupMenuButton<String>(
            tooltip: 'تصفية حسب المصدر',
            onSelected: (val) => setState(() {
              _selectedSourceFilter = val;
              _currentPage = 1;
            }),
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'all', child: Text('كافة المصادر')),
              const PopupMenuItem(value: 'app', child: Text('تطبيق مدار (توصيل)')),
              const PopupMenuItem(value: 'dine_in', child: Text('داخل الصالة (طاولات)')),
              const PopupMenuItem(value: 'takeaway', child: Text('استلام سفري')),
            ],
            child: _buildDropdownPill(
              context,
              label: _getSourceTitle(_selectedSourceFilter),
              icon: Icons.layers_outlined,
            ),
          ),
          const SizedBox(width: 10),
          // قائمة فرز وترتيب الفواتير
          PopupMenuButton<String>(
            tooltip: 'ترتيب وفرز الفواتير',
            onSelected: (val) => setState(() {
              _selectedSortOption = val;
            }),
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'newest',
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('الأحدث أولاً (افتراضي)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'oldest',
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('الأقدم أولاً'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'highest_amount',
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward_rounded, size: 16, color: Color(0xFF10B981)),
                    SizedBox(width: 8),
                    Text('الأعلى قيمة / مبلغاً 💰'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'lowest_amount',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward_rounded, size: 16, color: Color(0xFF0284C7)),
                    SizedBox(width: 8),
                    Text('الأقل قيمة / مبلغاً'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'priority',
                child: Row(
                  children: [
                    Icon(Icons.priority_high_rounded, size: 16, color: Color(0xFFFF5B22)),
                    SizedBox(width: 8),
                    Text('حسب الأولوية والحالة 🚨'),
                  ],
                ),
              ),
            ],
            child: _buildDropdownPill(
              context,
              label: _getSortTitle(_selectedSortOption),
              icon: Icons.sort_rounded,
            ),
          ),
          const SizedBox(width: 10),
          // أزرار تبديل نمط العرض (جدول vs كروت فواتير)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewModeButton(
                  context,
                  mode: 'table',
                  icon: Icons.table_rows_rounded,
                  tooltip: 'عرض الجدول التفصيلي',
                  isSelected: _viewMode == 'table',
                ),
                const SizedBox(width: 3),
                _buildViewModeButton(
                  context,
                  mode: 'cards',
                  icon: Icons.grid_view_rounded,
                  tooltip: 'عرض كروت الفواتير المصغرة',
                  isSelected: _viewMode == 'cards',
                ),
              ],
            ),
          ),
          if (_selectedStatusFilter != 'all' || _selectedSourceFilter != 'all' || _selectedDateFilter != 'all' || _searchQuery.isNotEmpty) ...[
            const SizedBox(width: 10),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedStatusFilter = 'all';
                  _selectedSourceFilter = 'all';
                  _selectedDateFilter = 'all';
                  _searchQuery = '';
                  _searchController.clear();
                  _currentPage = 1;
                });
              },
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: Text(
                'إعادة ضبط الفلاتر',
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
          const Spacer(),
          // حقل البحث
          SizedBox(
            width: 260,
            height: 38,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() {
                _searchQuery = v;
                _currentPage = 1;
              }),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم، رقم الطلب، الهاتف...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _currentPage = 1;
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: c.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: c.primary, width: 1.4),
                ),
              ),
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeButton(
    BuildContext context, {
    required String mode,
    required IconData icon,
    required String tooltip,
    required bool isSelected,
  }) {
    final c = context.posColors;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() => _viewMode = mode),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? c.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : c.textMuted,
          ),
        ),
      ),
    );
  }

  String _getSortTitle(String sort) {
    switch (sort) {
      case 'oldest':
        return 'الأقدم أولاً';
      case 'highest_amount':
        return 'الأعلى قيمة 💰';
      case 'lowest_amount':
        return 'الأقل قيمة';
      case 'priority':
        return 'حسب الأولوية 🚨';
      case 'newest':
      default:
        return 'الأحدث أولاً 🕒';
    }
  }

  Widget _buildDropdownPill(
    BuildContext context, {
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final c = context.posColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: c.textMuted),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── دوال العمليات والمنبهات وتعديل الطلبات ───────────────────────────

  /// شارة مدة التحضير ومؤشر التأخير الحرج
  Widget _buildElapsedTimerBadge(BuildContext context, PosOrder order) {
    final now = DateTime.now();
    final difference = now.difference(order.createdAt);
    final minutes = difference.inMinutes;
    final s = order.status.toLowerCase();
    final isPendingOrPreparing = s == 'pending' || s == 'new' || s == 'preparing';
    final isReady = s == 'ready';
    final isCompleted = s == 'completed' || s == 'delivered';
    final isCancelled = s == 'cancelled';

    if (isCancelled) {
      return const SizedBox.shrink();
    }

    if (isCompleted) {
      return Text(
        'أُنجز في $minutes د',
        style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
      );
    }

    final isDelayed = isPendingOrPreparing && minutes >= 25;
    final isWarning = isPendingOrPreparing && minutes >= 15 && minutes < 25;

    Color bg = const Color(0xFFF3F4F6);
    Color text = const Color(0xFF6B7280);
    IconData icon = Icons.timer_outlined;

    if (isDelayed) {
      bg = const Color(0xFFFEE2E2);
      text = const Color(0xFFDC2626);
      icon = Icons.warning_amber_rounded;
    } else if (isWarning) {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFFD97706);
      icon = Icons.hourglass_top_rounded;
    } else if (isReady) {
      bg = const Color(0xFFE0F2FE);
      text = const Color(0xFF0284C7);
      icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: text.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: text),
          const SizedBox(width: 3),
          Text(
            isDelayed ? 'متأخر ($minutes د)' : '$minutes د',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 9.5, fontWeight: FontWeight.bold, color: text),
          ),
        ],
      ),
    );
  }

  /// فتح محادثة واتساب سريعة مع الزبون بنص تلقائي جاهز
  Future<void> _openWhatsApp(String phone, PosOrder order) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('07')) {
      cleanPhone = '964${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('964') && cleanPhone.length == 10 && cleanPhone.startsWith('7')) {
      cleanPhone = '964$cleanPhone';
    }

    final message = Uri.encodeComponent(
      'مرحباً بك! نود إعلامك أن طلبك رقم #${_formatOrderId(order.orderId)} في $_restaurantName بحالة: ${_getStatusTitle(order.status)}. شكراً لاختيارك لنا!',
    );
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$message');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح تطبيق واتساب: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  /// تحديث جماعي لحالة الطلبات المحددة
  Future<void> _batchUpdateStatus(String newStatus) async {
    if (_selectedOrderIds.isEmpty) return;
    final count = _selectedOrderIds.length;
    final ids = List<String>.from(_selectedOrderIds);

    for (final id in ids) {
      await _updateOrderStatus(id, newStatus);
    }

    if (mounted) {
      setState(() => _selectedOrderIds.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث $count طلبات إلى حالة ${_getStatusTitle(newStatus)} بنجاح ✓'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  /// إرسال وطباعة جماعية للمطبخ
  Future<void> _batchPrintAndSendToKitchen(List<PosOrder> allOrders) async {
    if (_selectedOrderIds.isEmpty) return;
    final selectedOrders = allOrders.where((o) => _selectedOrderIds.contains(o.orderId)).toList();
    final count = selectedOrders.length;

    for (final order in selectedOrders) {
      await _updateOrderStatus(order.orderId, 'preparing');
      ThermalPrinterService.printOrder(order: order);
    }

    if (mounted) {
      setState(() => _selectedOrderIds.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إرسال وطباعة $count طلبات للمطبخ بنجاح 👨‍🍳'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  /// نافذة إلغاء الطلب مع توثيق سبب الإلغاء في السجل الرقابي
  Future<void> _showCancelReasonDialog(BuildContext context, PosOrder order) async {
    final messenger = ScaffoldMessenger.of(context);
    final reasons = [
      'طلب العميل إلغاء الطلب',
      'نفاد بعض المكونات في المطبخ',
      'تأخر العميل عن الاستلام',
      'خطأ في تسجيل الطلب من الكاشير',
      'العنوان خارج نطاق التوصيل',
      'سبب آخر',
    ];
    String selectedReason = reasons.first;
    final textController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final c = context.posColors;
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: c.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 24),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'إلغاء الطلب ${_formatOrderId(order.orderId)}',
                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'يرجى تحديد سبب الإلغاء لتوثيقه في السجل الرقابي والمالي للمطعم:',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: c.textMuted),
                    ),
                    const SizedBox(height: 12),
                    ...reasons.map((r) {
                      final isSel = selectedReason == r;
                      return InkWell(
                        onTap: () => setDialogState(() => selectedReason = r),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Row(
                            children: [
                              Icon(
                                isSel ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: isSel ? const Color(0xFFEF4444) : c.textMuted,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                r,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12.5,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (selectedReason == 'سبب آخر') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: textController,
                        decoration: InputDecoration(
                          hintText: 'اكتب سبب الإلغاء هنا...',
                          hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('رجوع', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('تأكيد الإلغاء', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (confirmed == true) {
      final finalReason = selectedReason == 'سبب آخر' && textController.text.trim().isNotEmpty
          ? textController.text.trim()
          : selectedReason;

      try {
        await FirebaseFirestore.instance.collection('orders').doc(order.orderId).update({
          'status': 'cancelled',
          'cancellationReason': finalReason,
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': _uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // توثيق في سجل التدقيق التجاري
        await AuditLogService.instance.log(
          action: AuditLogAction.orderCancelled,
          targetType: 'order',
          targetId: order.orderId,
          reason: 'إلغاء الطلب #${order.orderId} بسبب: $finalReason',
        );

        // تحديث محلي
        try {
          final db = await LocalDatabaseService.instance.database;
          await db.update(
            'local_orders',
            {'status': 'cancelled'},
            where: 'local_id = ? OR remote_id = ?',
            whereArgs: [order.orderId, order.orderId],
          );
          _loadLocalOrders();
        } catch (_) {}

        messenger.showSnackBar(
          SnackBar(
            content: Text('تم إلغاء الطلب وتوثيق السبب: $finalReason'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('خطأ أثناء إلغاء الطلب: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  /// نافذة تعديل تفاصيل وأصناف الطلب بعد إنشائه
  Future<void> _showEditOrderDialog(BuildContext context, PosOrder order) async {
    final messenger = ScaffoldMessenger.of(context);
    final c = context.posColors;
    final List<PosCartItem> editedItems = order.items.map((i) => PosCartItem(
      id: i.id,
      mealId: i.mealId,
      name: i.name,
      unitPrice: i.unitPrice,
      quantity: i.quantity,
      selectedSize: i.selectedSize,
      selectedAddons: List<Map<String, dynamic>>.from(i.selectedAddons),
      notes: i.notes,
      imageUrl: i.imageUrl,
    )).toList();

    final tableController = TextEditingController(text: order.tableNumber ?? '');
    final addressController = TextEditingController(text: order.deliveryAddress ?? '');
    final notesController = TextEditingController(text: order.notes ?? '');

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final double subtotal = editedItems.fold(0.0, (acc, i) => acc + i.totalPrice);
          final double total = (subtotal + order.deliveryFee + order.taxOrService - order.discountAmount).clamp(0.0, 99999999.0);

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: c.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.edit_note_rounded, color: c.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'تعديل تفاصيل وأصناف الطلب ${_formatOrderId(order.orderId)}',
                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // حقول الطاولة / العنوان / الملاحظات
                      if (order.orderType == 'dine_in') ...[
                        Text('رقم الطاولة في الصالة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: tableController,
                          decoration: InputDecoration(
                            hintText: 'مثال: 5',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (order.orderType == 'delivery') ...[
                        Text('عنوان التوصيل', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: addressController,
                          decoration: InputDecoration(
                            hintText: 'تفاصيل العنوان والمنطقة...',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text('ملاحظات خاصة للطلب', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: notesController,
                        decoration: InputDecoration(
                          hintText: 'أي تعليمات أو ملاحظات إضافية...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Divider(color: c.border),
                      const SizedBox(height: 8),

                      // قائمة الأصناف مع أزرار الزيادة والنقصان والحذف
                      Text('أصناف الوجبة (${editedItems.length})', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (editedItems.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'لا يمكن حفظ الطلب بدون أي صنف! يرجى الإبقاء على صنف واحد على الأقل.',
                              style: GoogleFonts.ibmPlexSansArabic(color: const Color(0xFFEF4444), fontSize: 12),
                            ),
                          ),
                        )
                      else
                        ...editedItems.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: c.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: c.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.name, style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('${_formatAmount(item.unitPrice)} د.ع للقطعة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted)),
                                    ],
                                  ),
                                ),
                                // عداد الكمية
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                                      color: item.quantity > 1 ? c.primary : c.textDisabled,
                                      onPressed: item.quantity > 1
                                          ? () => setDialogState(() => item.quantity--)
                                          : null,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Text(
                                        '${item.quantity}',
                                        style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, size: 20),
                                      color: c.primary,
                                      onPressed: () => setDialogState(() => item.quantity++),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${_formatAmount(item.totalPrice)} د.ع',
                                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                  tooltip: 'حذف الصنف',
                                  onPressed: () => setDialogState(() => editedItems.removeAt(idx)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 12),
                      Divider(color: c.border),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('المجموع الفرعي الجديد:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: c.textMuted)),
                          Text('${_formatAmount(subtotal)} د.ع', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('الإجمالي النهائي الجديد:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13.5, fontWeight: FontWeight.bold)),
                          Text(
                            '${_formatAmount(total)} د.ع',
                            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w900, fontSize: 15, color: c.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: Text('حفظ التعديلات', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: editedItems.isEmpty
                      ? null
                      : () async {
                          try {
                            final newSubtotal = editedItems.fold(0.0, (acc, i) => acc + i.totalPrice);
                            final newTotal = (newSubtotal + order.deliveryFee + order.taxOrService - order.discountAmount).clamp(0.0, 99999999.0);

                            final updateData = {
                              'items': editedItems.map((e) => e.toMap()).toList(),
                              'subtotal': newSubtotal,
                              'total': newTotal,
                              'totalAmount': newTotal,
                              'totalPrice': newTotal,
                              'tableNumber': tableController.text.trim().isEmpty ? null : tableController.text.trim(),
                              'deliveryAddress': addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                              'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            };

                            await FirebaseFirestore.instance.collection('orders').doc(order.orderId).update(updateData);

                            // توثيق التعديل في سجل التدقيق
                            await AuditLogService.instance.log(
                              action: AuditLogAction.priceOverridden,
                              targetType: 'order',
                              targetId: order.orderId,
                              reason: 'تعديل أصناف وبيانات الطلب من شاشة الطلبات',
                            );

                            // تحديث محلي
                            try {
                              final db = await LocalDatabaseService.instance.database;
                              await db.update(
                                'local_orders',
                                {
                                  'total_amount': newTotal,
                                  'items_json': jsonEncode(editedItems.map((e) => e.toMap()).toList()),
                                },
                                where: 'local_id = ? OR remote_id = ?',
                                whereArgs: [order.orderId, order.orderId],
                              );
                              _loadLocalOrders();
                            } catch (_) {}

                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('تم حفظ تعديلات الطلب وتحديث الحسابات بنجاح ✓'),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          } catch (e) {
                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            messenger.showSnackBar(
                              SnackBar(content: Text('تعذر حفظ التعديلات: $e'), backgroundColor: const Color(0xFFEF4444)),
                            );
                          }
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────── نافذة المعاينة الحرارية الواقعية للفاتورة ───────────────────────────

  /// نافذة المعاينة الحرارية الواقعية للفاتورة (Realistic Thermal Invoice Preview)
  void _showInvoicePreviewDialog(BuildContext context, PosOrder order) {
    final formattedId = _formatOrderId(order.orderId);
    final dateStr = DateFormat('yyyy/MM/dd - hh:mm a').format(order.createdAt);
    final isDelivery = order.orderType == 'delivery';
    final isDineIn = order.orderType == 'dine_in';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: 400,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 25,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // شريط ترويسة النافذة
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: Color(0xFFFF5B22), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'معاينة الفاتورة الحرارية (80mm)',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),

                // ورقة الفاتورة الحرارية القابلة للتمرير
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // شعار المطعم
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
                          ),
                          child: const Icon(Icons.restaurant_rounded, size: 26, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _restaurantName,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'فاتورة إلكترونية مبسطة',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'العراق - الأنبار • خدمة الزبائن',
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: const Color(0xFF64748B)),
                        ),

                        _buildThermalDashedLine(),

                        // بيانات الفاتورة
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('رقم الفاتورة:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF475569))),
                            Text(
                              '#$formattedId',
                              style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('التاريخ والوقت:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF475569))),
                            Text(dateStr, style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: const Color(0xFF0F172A))),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('نوع الطلب:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF475569))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                PosConstants.getOrderTypeName(order.orderType),
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        if (isDineIn && order.tableNumber != null && order.tableNumber!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('رقم الطاولة:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF475569))),
                              Text('طاولة ${order.tableNumber}', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFFF5B22))),
                            ],
                          ),
                        ],
                        if (order.customerName != null && order.customerName!.isNotEmpty && order.customerName != 'زبون مباشر') ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text('الزبون:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF475569))),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order.customerName!,
                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                  textAlign: TextAlign.left,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (order.customerPhone != null && order.customerPhone!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text('الهاتف:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF475569))),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order.customerPhone!,
                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                  textAlign: TextAlign.left,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (isDelivery && order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('العنوان:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF475569))),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order.deliveryAddress!,
                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: const Color(0xFF0F172A)),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('الكاشير:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF475569))),
                            Text(order.cashierName, style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: const Color(0xFF0F172A))),
                          ],
                        ),

                        _buildThermalDashedLine(),

                        // جدول الأصناف
                        Row(
                          children: [
                            Expanded(flex: 4, child: Text('الصنف', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)))),
                            Expanded(flex: 1, child: Text('العدد', textAlign: TextAlign.center, style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)))),
                            Expanded(flex: 2, child: Text('الإجمالي', textAlign: TextAlign.left, style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Divider(color: Color(0xFFCBD5E1), height: 1, thickness: 1),
                        const SizedBox(height: 6),

                        ...order.items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.name, style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                      if (item.selectedSize != null && item.selectedSize!.isNotEmpty)
                                        Text('(${item.selectedSize})', style: GoogleFonts.ibmPlexSansArabic(fontSize: 9.5, color: const Color(0xFF64748B))),
                                      if (item.selectedAddons.isNotEmpty)
                                        Text(
                                          '+ ${item.selectedAddons.map((e) => e['name']).join(', ')}',
                                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 9, color: const Color(0xFF64748B)),
                                        ),
                                      if (item.notes != null && item.notes!.isNotEmpty)
                                        Text('* ${item.notes}', style: GoogleFonts.ibmPlexSansArabic(fontSize: 9, color: const Color(0xFFEF4444))),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text('× ${item.quantity}', textAlign: TextAlign.center, style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${_formatAmount(item.totalPrice)} د.ع',
                                    textAlign: TextAlign.left,
                                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        _buildThermalDashedLine(),

                        // الحسابات والملخص المالي
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('مجموع الأصناف:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF475569))),
                            Text('${_formatAmount(order.subtotal)} د.ع', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                          ],
                        ),
                        if (order.discountAmount > 0) ...[
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('الخصم:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFFEF4444))),
                              Text('-${_formatAmount(order.discountAmount)} د.ع', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444))),
                            ],
                          ),
                        ],
                        if (order.deliveryFee > 0 || order.taxOrService > 0) ...[
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('توصيل / خدمة:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF475569))),
                              Text('${_formatAmount(order.deliveryFee + order.taxOrService)} د.ع', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF0F172A))),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),

                        // صندوق المجموع الكلي البارز
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'المجموع النهائي:',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(
                                '${_formatAmount(order.totalAmount)} د.ع',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFFFF5B22)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'طريقة الدفع: ${PosConstants.getPaymentMethodName(order.paymentMethod)}',
                              style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                            ),
                          ],
                        ),

                        _buildThermalDashedLine(),

                        // محاكاة الباركود الحراري
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          height: 36,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(36, (i) {
                              final widths = [1.0, 2.0, 1.0, 3.0, 1.5, 2.5, 1.0, 3.5];
                              final isSpace = (i % 5 == 0) || (i % 9 == 0);
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                width: widths[i % widths.length],
                                height: 36,
                                color: isSpace ? Colors.transparent : Colors.black,
                              );
                            }),
                          ),
                        ),
                        Text(
                          'MADAR-${order.orderId.toUpperCase()}',
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 9, letterSpacing: 1.5, color: const Color(0xFF64748B)),
                        ),

                        const SizedBox(height: 10),
                        // صندوق التحقق السحابي
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'الفاتورة موثقة رقمياً عبر سيرفر مدار',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              ),
                              Text(
                                'SHA256 • Verified Digital POS Receipt',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 8.5, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                        Text(
                          'شكراً لزيارتكم • نسعد بخدمتكم دائماً',
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                        Text(
                          'نظام مدار الذكي لنقاط البيع 🇮🇶 • MADE IN IRAQ',
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 9, color: const Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // شريط أزرار الإجراءات السفلية
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ThermalPrinterService.printOrder(order: order);
                          },
                          icon: const Icon(Icons.print_rounded, size: 16),
                          label: Text('طباعة الفاتورة 🖨️', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5B22),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ThermalPrinterService.printKitchenTicketOnly(order: order);
                          },
                          icon: const Icon(Icons.soup_kitchen_rounded, size: 16),
                          label: Text('بون المطبخ 👨‍🍳', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      if (order.customerPhone?.isNotEmpty == true) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            _openWhatsApp(order.customerPhone!, order);
                          },
                          tooltip: 'إرسال الفاتورة عبر واتساب',
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF16A34A)),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                            padding: const EdgeInsets.all(10),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThermalDashedLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: List.generate(40, (index) {
          return Expanded(
            child: Container(
              height: 1,
              color: index % 2 == 0 ? const Color(0xFF94A3B8) : Colors.transparent,
            ),
          );
        }),
      ),
    );
  }

  /// شاشة فارغة مشتركة في حال عدم وجود طلبات
  Widget _buildEmptyOrdersView(BuildContext context, bool isAllEmpty) {
    final c = context.posColors;

    if (isAllEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                  border: Border.all(color: MadarColors.primary.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.receipt_long_rounded, size: 48, color: Color(0xFFFF5B22)),
              ),
              const SizedBox(height: 14),
              Text(
                'لا توجد طلبات مسجلة في مطعمك حتى الآن',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'يمكنك البدء بإنشاء طلبات مباشرة من نقطة البيع (POS) أو انتظار وصول طلبات جديدة من الزبائن',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: c.textMuted,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  if (widget.onNavigate != null) {
                    widget.onNavigate!(3);
                  }
                },
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                label: const Text('فتح الكاشير ونقاط البيع (POS)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_alt_off_rounded, size: 44, color: c.textDisabled),
          const SizedBox(height: 10),
          Text(
            'لا توجد فواتير مطابقة للفلتر أو البحث المحدد',
            style: GoogleFonts.ibmPlexSansArabic(
              color: c.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'جرب تغيير معايير البحث أو إعادة ضبط الفلاتر',
            style: GoogleFonts.ibmPlexSansArabic(
              color: c.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _selectedStatusFilter = 'all';
                _selectedSourceFilter = 'all';
                _selectedDateFilter = 'all';
                _customDateRange = null;
                _searchQuery = '';
                _searchController.clear();
                _currentPage = 1;
              });
            },
            child: const Text('عرض كافة الفواتير'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── جدول الطلبات الرئيسي الحقيقي ───────────────────────────

  Widget _buildOrdersTable(BuildContext context, List<PosOrder> allOrders, List<PosOrder> filteredOrders, {bool isNarrow = false}) {
    final c = context.posColors;

    // احتساب الترقيم
    final totalCount = filteredOrders.length;
    final totalPages = (totalCount / _pageSize).ceil().clamp(1, 9999);
    if (_currentPage > totalPages) _currentPage = totalPages;
    final pagedOrders = filteredOrders.skip((_currentPage - 1) * _pageSize).take(_pageSize).toList();

    return Column(
      children: [
        // شريط العمليات والإجراءات الجماعية
        if (_selectedOrderIds.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.checklist_rounded, color: c.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'تم تحديد ${_selectedOrderIds.length} طلبات',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12.5, color: c.primary),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _batchUpdateStatus('preparing'),
                  icon: const Icon(Icons.check_circle_outline, size: 15),
                  label: const Text('قبول المحددة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _batchPrintAndSendToKitchen(allOrders),
                  icon: const Icon(Icons.soup_kitchen_rounded, size: 15),
                  label: const Text('إرسال وطباعة للمطبخ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _selectedOrderIds.clear()),
                  child: Text('إلغاء التحديد', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted)),
                ),
              ],
            ),
          ),
        ],

        // الجدول الرئيسي
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // رأس الجدول
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: c.background.withValues(alpha: 0.6),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    border: Border(bottom: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    children: [
                      // مربع تحديد الكل
                      SizedBox(
                        width: 32,
                        child: Checkbox(
                          value: pagedOrders.isNotEmpty && pagedOrders.every((o) => _selectedOrderIds.contains(o.orderId)),
                          tristate: pagedOrders.any((o) => _selectedOrderIds.contains(o.orderId)) &&
                              !pagedOrders.every((o) => _selectedOrderIds.contains(o.orderId)),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedOrderIds.addAll(pagedOrders.map((o) => o.orderId));
                              } else {
                                for (final o in pagedOrders) {
                                  _selectedOrderIds.remove(o.orderId);
                                }
                              }
                            });
                          },
                        ),
                      ),
                      _buildHeaderCell('رقم الفاتورة', flex: 2),
                      _buildHeaderCell('الوقت والمدة', flex: 2),
                      _buildHeaderCell('العميل', flex: 2),
                      if (!isNarrow) _buildHeaderCell('نوع الطلب', flex: 2),
                      _buildHeaderCell('المجموع', flex: 2),
                      _buildHeaderCell('حالة الطلب', flex: 2),
                      if (!isNarrow) _buildHeaderCell('طريقة الدفع', flex: 2),
                      if (!isNarrow) _buildHeaderCell('السائق', flex: 2),
                      _buildHeaderCell('إجراءات سريعة', flex: 2, alignment: Alignment.center),
                    ],
                  ),
                ),

                // صفوف الجدول أو الشاشات الفارغة
                Expanded(
                  child: allOrders.isEmpty || filteredOrders.isEmpty
                      ? _buildEmptyOrdersView(context, allOrders.isEmpty)
                      : ListView.separated(
                          itemCount: pagedOrders.length,
                          separatorBuilder: (_, _) => Divider(color: c.border, height: 1),
                          itemBuilder: (context, index) {
                            final order = pagedOrders[index];
                            final isSelected = _selectedOrder?.orderId == order.orderId;

                            return InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedOrder = order);
                                if (isNarrow) {
                                  _openOrderDetailsModal(context, order);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                color: isSelected
                                    ? c.primary.withValues(alpha: 0.08)
                                    : Colors.transparent,
                                child: Row(
                                  children: [
                                    // مربع تحديد السطر
                                    SizedBox(
                                      width: 32,
                                      child: Checkbox(
                                        value: _selectedOrderIds.contains(order.orderId),
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedOrderIds.add(order.orderId);
                                            } else {
                                              _selectedOrderIds.remove(order.orderId);
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    // رقم الفاتورة
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: c.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: c.primary.withValues(alpha: 0.2)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.receipt_rounded, size: 13, color: c.primary),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatOrderId(order.orderId),
                                                style: GoogleFonts.ibmPlexSansArabic(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12,
                                                  color: c.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // الوقت والمدة المنقضية
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            DateFormat('hh:mm a').format(order.createdAt),
                                            style: GoogleFonts.ibmPlexSansArabic(
                                              fontSize: 11.5,
                                              color: c.textMuted,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          _buildElapsedTimerBadge(context, order),
                                        ],
                                      ),
                                    ),
                                    // العميل
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor: c.primary.withValues(alpha: 0.12),
                                            child: Icon(Icons.person_outline_rounded, size: 13, color: c.primary),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  order.customerName ?? 'عميل مباشر',
                                                  style: GoogleFonts.ibmPlexSansArabic(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: c.textPrimary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (order.customerPhone?.isNotEmpty == true)
                                                  Text(
                                                    order.customerPhone!,
                                                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: c.textMuted),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // نوع الطلب
                                    if (!isNarrow)
                                      Expanded(
                                        flex: 2,
                                        child: _buildOrderTypeBadge(context, order),
                                      ),
                                    // المجموع
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${_formatAmount(order.totalAmount)} د.ع',
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: c.textPrimary,
                                        ),
                                      ),
                                    ),
                                    // حالة الطلب
                                    Expanded(
                                      flex: 2,
                                      child: _buildOrderStatusBadge(context, order.status),
                                    ),
                                    // طريقة الدفع
                                    if (!isNarrow)
                                      Expanded(
                                        flex: 2,
                                        child: _buildPaymentMethodBadge(context, order.paymentMethod),
                                      ),
                                    // السائق
                                    if (!isNarrow)
                                      Expanded(
                                        flex: 2,
                                        child: _buildDriverCell(context, order),
                                      ),
                                    // إجراءات سريعة
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          // زر معاينة الفاتورة الحرارية
                                          IconButton(
                                            icon: const Icon(Icons.receipt_long_rounded, size: 17),
                                            tooltip: 'معاينة الفاتورة الحرارية 📄',
                                            color: c.primary,
                                            onPressed: () => _showInvoicePreviewDialog(context, order),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          ),
                                          const SizedBox(width: 2),
                                          // زر طباعة فورية
                                          IconButton(
                                            icon: const Icon(Icons.print_rounded, size: 16),
                                            tooltip: 'طباعة فورية 🖨️',
                                            color: c.textPrimary,
                                            onPressed: () => ThermalPrinterService.printOrder(order: order),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          ),
                                          const SizedBox(width: 2),
                                          // قائمة المزيد
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert_rounded, size: 16),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                            onSelected: (val) {
                                              if (val == 'preview') {
                                                _showInvoicePreviewDialog(context, order);
                                              } else if (val == 'edit') {
                                                _showEditOrderDialog(context, order);
                                              } else if (val == 'whatsapp') {
                                                if (order.customerPhone?.isNotEmpty == true) {
                                                  _openWhatsApp(order.customerPhone!, order);
                                                }
                                              } else if (val == 'print') {
                                                ThermalPrinterService.printOrder(order: order);
                                              } else if (val == 'preparing') {
                                                _updateOrderStatus(order.orderId, 'preparing');
                                              } else if (val == 'ready') {
                                                _updateOrderStatus(order.orderId, 'ready');
                                              } else if (val == 'completed') {
                                                _updateOrderStatus(order.orderId, 'completed');
                                              } else if (val == 'cancelled') {
                                                _showCancelReasonDialog(context, order);
                                              } else if (val == 'delete_local') {
                                                _deleteLocalOrder(order.orderId);
                                              }
                                            },
                                            itemBuilder: (ctx) => [
                                              const PopupMenuItem(
                                                value: 'preview',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF0284C7)),
                                                    SizedBox(width: 8),
                                                    Text('معاينة الفاتورة الحرارية 📄'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFFFF5B22)),
                                                    SizedBox(width: 8),
                                                    Text('تعديل الطلب والأصناف ✏️'),
                                                  ],
                                                ),
                                              ),
                                              if (order.customerPhone?.isNotEmpty == true)
                                                const PopupMenuItem(
                                                  value: 'whatsapp',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF25D366)),
                                                      SizedBox(width: 8),
                                                      Text('مراسلة واتساب 🟢'),
                                                    ],
                                                  ),
                                                ),
                                              const PopupMenuItem(
                                                value: 'print',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.print_rounded, size: 16),
                                                    SizedBox(width: 8),
                                                    Text('طباعة الفاتورة'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'preparing',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.soup_kitchen_rounded, size: 16, color: Color(0xFFF59E0B)),
                                                    SizedBox(width: 8),
                                                    Text('إرسال للمطبخ (قيد التحضير)'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'ready',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.shopping_bag_rounded, size: 16, color: Color(0xFF0284C7)),
                                                    SizedBox(width: 8),
                                                    Text('جاهز للتسليم'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'completed',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                                                    SizedBox(width: 8),
                                                    Text('تم التسليم (مكتمل)'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'cancelled',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.cancel_rounded, size: 16, color: Color(0xFFEF4444)),
                                                    SizedBox(width: 8),
                                                    Text('إلغاء الطلب مع السبب'),
                                                  ],
                                                ),
                                              ),
                                              if (_localOrders.any((lo) => lo.orderId == order.orderId))
                                                const PopupMenuItem(
                                                  value: 'delete_local',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                                      SizedBox(width: 8),
                                                      Text('حذف من المحلي 🗑️', style: TextStyle(color: Color(0xFFEF4444))),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // شريط الترقيم السفلي
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.background.withValues(alpha: 0.6),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                    border: Border(top: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'عرض ${pagedOrders.length} من أصل $totalCount فاتورة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          color: c.textMuted,
                        ),
                      ),
                      const Spacer(),
                      _buildPageButton(
                        context,
                        label: '<',
                        enabled: _currentPage > 1,
                        onTap: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                      ),
                      for (int p = 1; p <= totalPages && p <= 5; p++)
                        _buildPageButton(
                          context,
                          label: '$p',
                          active: _currentPage == p,
                          onTap: () => setState(() => _currentPage = p),
                        ),
                      _buildPageButton(
                        context,
                        label: '>',
                        enabled: _currentPage < totalPages,
                        onTap: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────── شبكة كروت الفواتير المصغرة ───────────────────────────

  Widget _buildOrdersCardsGrid(
    BuildContext context,
    List<PosOrder> allOrders,
    List<PosOrder> filteredOrders, {
    bool isNarrow = false,
  }) {
    final c = context.posColors;

    final totalCount = filteredOrders.length;
    final totalPages = (totalCount / _pageSize).ceil().clamp(1, 9999);
    if (_currentPage > totalPages) _currentPage = totalPages;
    final pagedOrders = filteredOrders.skip((_currentPage - 1) * _pageSize).take(_pageSize).toList();

    return Column(
      children: [
        // شريط العمليات والإجراءات الجماعية
        if (_selectedOrderIds.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.checklist_rounded, color: c.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'تم تحديد ${_selectedOrderIds.length} طلبات',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12.5, color: c.primary),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _batchUpdateStatus('preparing'),
                  icon: const Icon(Icons.check_circle_outline, size: 15),
                  label: const Text('قبول المحددة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _batchPrintAndSendToKitchen(allOrders),
                  icon: const Icon(Icons.soup_kitchen_rounded, size: 15),
                  label: const Text('إرسال وطباعة للمطبخ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _selectedOrderIds.clear()),
                  child: Text('إلغاء التحديد', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted)),
                ),
              ],
            ),
          ),
        ],

        // شبكة كروت الفواتير
        Expanded(
          child: allOrders.isEmpty || filteredOrders.isEmpty
              ? _buildEmptyOrdersView(context, allOrders.isEmpty)
              : LayoutBuilder(
                  builder: (ctx, constraints) {
                    final crossCount = (constraints.maxWidth / 320).floor().clamp(1, 4);

                    return GridView.builder(
                      padding: const EdgeInsets.all(4),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 250,
                      ),
                      itemCount: pagedOrders.length,
                      itemBuilder: (context, index) {
                        final order = pagedOrders[index];
                        final isSelected = _selectedOrder?.orderId == order.orderId;
                        final isChecked = _selectedOrderIds.contains(order.orderId);

                        return _buildInvoiceCardItem(context, order, isSelected: isSelected, isChecked: isChecked);
                      },
                    );
                  },
                ),
        ),

        // شريط الترقيم السفلي
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: c.background.withValues(alpha: 0.6),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: Row(
            children: [
              Text(
                'عرض ${pagedOrders.length} من أصل $totalCount فاتورة',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 11.5,
                  color: c.textMuted,
                ),
              ),
              const Spacer(),
              _buildPageButton(
                context,
                label: '<',
                enabled: _currentPage > 1,
                onTap: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
              ),
              for (int p = 1; p <= totalPages && p <= 5; p++)
                _buildPageButton(
                  context,
                  label: '$p',
                  active: _currentPage == p,
                  onTap: () => setState(() => _currentPage = p),
                ),
              _buildPageButton(
                context,
                label: '>',
                enabled: _currentPage < totalPages,
                onTap: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceCardItem(
    BuildContext context,
    PosOrder order, {
    required bool isSelected,
    required bool isChecked,
  }) {
    final c = context.posColors;
    final formattedId = _formatOrderId(order.orderId);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedOrder = order);
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? c.primary.withValues(alpha: 0.06) : c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? c.primary : c.border,
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.06 : 0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // سطر الترويسة
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: isChecked,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedOrderIds.add(order.orderId);
                        } else {
                          _selectedOrderIds.remove(order.orderId);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 4),
                // رقم الفاتورة
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_rounded, size: 12, color: c.primary),
                      const SizedBox(width: 4),
                      Text(
                        '#$formattedId',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: c.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _buildOrderStatusBadge(context, order.status),
              ],
            ),
            const SizedBox(height: 8),

            // العميل والنوع والوقت
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 14, color: c.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.customerName ?? 'عميل مباشر',
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold, color: c.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildElapsedTimerBadge(context, order),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildOrderTypeBadge(context, order),
                const SizedBox(width: 6),
                _buildPaymentMethodBadge(context, order.paymentMethod),
                const Spacer(),
                Text(
                  DateFormat('hh:mm a').format(order.createdAt),
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // قائمة موجزة للأصناف
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.border.withValues(alpha: 0.5)),
                ),
                child: order.items.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد أصناف',
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textMuted),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < order.items.length && i < 2; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  Text(
                                    '${order.items[i].quantity}× ',
                                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, fontWeight: FontWeight.bold, color: c.primary),
                                  ),
                                  Expanded(
                                    child: Text(
                                      order.items[i].name,
                                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${_formatAmount(order.items[i].totalPrice)} د.ع',
                                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: c.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          if (order.items.length > 2)
                            Text(
                              '+ ${order.items.length - 2} أصناف أخرى...',
                              style: GoogleFonts.ibmPlexSansArabic(fontSize: 9.5, color: c.textMuted),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),

            // شريط الإجمالي والأزرار السريعة
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الإجمالي', style: GoogleFonts.ibmPlexSansArabic(fontSize: 9.5, color: c.textMuted)),
                    Text(
                      '${_formatAmount(order.totalAmount)} د.ع',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: c.primary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // زر معاينة الفاتورة
                OutlinedButton.icon(
                  onPressed: () => _showInvoicePreviewDialog(context, order),
                  icon: const Icon(Icons.receipt_long_rounded, size: 14),
                  label: Text('معاينة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.primary,
                    side: BorderSide(color: c.primary.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(60, 30),
                  ),
                ),
                const SizedBox(width: 4),
                // زر طباعة
                IconButton(
                  onPressed: () => ThermalPrinterService.printOrder(order: order),
                  icon: const Icon(Icons.print_rounded, size: 16),
                  tooltip: 'طباعة فورية',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                ),
                // زر خيارات
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onSelected: (val) {
                    if (val == 'preview') {
                      _showInvoicePreviewDialog(context, order);
                    } else if (val == 'edit') {
                      _showEditOrderDialog(context, order);
                    } else if (val == 'whatsapp') {
                      if (order.customerPhone?.isNotEmpty == true) {
                        _openWhatsApp(order.customerPhone!, order);
                      }
                    } else if (val == 'preparing') {
                      _updateOrderStatus(order.orderId, 'preparing');
                    } else if (val == 'ready') {
                      _updateOrderStatus(order.orderId, 'ready');
                    } else if (val == 'completed') {
                      _updateOrderStatus(order.orderId, 'completed');
                    } else if (val == 'cancelled') {
                      _showCancelReasonDialog(context, order);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'preview',
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 15, color: Color(0xFF0284C7)),
                          SizedBox(width: 8),
                          Text('معاينة الفاتورة الحرارية 📄'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_note_rounded, size: 15, color: Color(0xFFFF5B22)),
                          SizedBox(width: 8),
                          Text('تعديل الطلب ✏️'),
                        ],
                      ),
                    ),
                    if (order.customerPhone?.isNotEmpty == true)
                      const PopupMenuItem(
                        value: 'whatsapp',
                        child: Row(
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Color(0xFF25D366)),
                            SizedBox(width: 8),
                            Text('مراسلة واتساب'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'preparing',
                      child: Row(
                        children: [
                          Icon(Icons.soup_kitchen_rounded, size: 15, color: Color(0xFFF59E0B)),
                          SizedBox(width: 8),
                          Text('إرسال للمطبخ'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'completed',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF10B981)),
                          SizedBox(width: 8),
                          Text('تم التسليم (مكتمل)'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'cancelled',
                      child: Row(
                        children: [
                          Icon(Icons.cancel_rounded, size: 15, color: Color(0xFFEF4444)),
                          SizedBox(width: 8),
                          Text('إلغاء الطلب مع السبب'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String label, {required int flex, Alignment alignment = Alignment.centerRight}) {
    final c = context.posColors;
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignment,
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: c.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildPageButton(
    BuildContext context, {
    required String label,
    bool active = false,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    final c = context.posColors;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: active ? c.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? c.primary : c.border),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11.5,
              fontWeight: active ? FontWeight.bold : FontWeight.w600,
              color: active ? Colors.white : (enabled ? c.textPrimary : c.textDisabled),
            ),
          ),
        ),
      ),
    );
  }

  void _openOrderDetailsModal(BuildContext context, PosOrder order) {
    MadarSideSheet.showModal(
      context: context,
      title: 'تفاصيل الطلب ${_formatOrderId(order.orderId)}',
      content: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: _buildOrderDetailsInspector(context, order, isModal: true),
      ),
    );
  }

  // ─────────────────────────── لوحة فحص وتفاصيل الطلب الحقيقي ───────────────────────────

  Widget _buildOrderDetailsInspector(BuildContext context, PosOrder? order, {bool isModal = false}) {
    final c = context.posColors;

    if (order == null) {
      return Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: isModal ? BorderRadius.zero : BorderRadius.circular(14),
          border: isModal ? null : Border.all(color: c.border),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_outlined, size: 40, color: c.textDisabled),
              const SizedBox(height: 10),
              Text(
                'حدد طلباً من الجدول لعرض كامل تفاصيله',
                style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: isModal ? BorderRadius.zero : BorderRadius.circular(14),
        border: isModal ? null : Border.all(color: c.border),
        boxShadow: isModal
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          // ترويسة الطلب
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: c.background.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatOrderId(order.orderId),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      DateFormat('yyyy/MM/dd - hh:mm a').format(order.createdAt),
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                    ),
                  ],
                ),
                const Spacer(),
                _buildOrderStatusBadge(context, order.status),
              ],
            ),
          ),

          // شريط مراحل دورة حياة الطلب التفاعلي (Pipeline Stepper)
          _buildOrderLifecycleStepper(context, order),

          // شريط التبويبين النظيفين (الفاتورة والأصناف | سجل التدقيق الحقيقي)
          TabBar(
            controller: _detailTabController,
            labelColor: c.primary,
            unselectedLabelColor: c.textMuted,
            indicatorColor: c.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text('الفاتورة والبنود (${order.items.length})'),
                  ],
                ),
              ),
              const Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_edu_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('سجل التدقيق والعمليات 🔒'),
                  ],
                ),
              ),
            ],
          ),
          Divider(color: c.border, height: 1),

          // محتوى التبويبات
          Expanded(
            child: TabBarView(
              controller: _detailTabController,
              children: [
                // 1) الفاتورة والبنود الشاملة
                _buildOrderInvoiceAndItemsTab(context, order),
                // 2) سجل التدقيق الحقيقي الموثق
                _buildOrderRealAuditLogTab(context, order),
              ],
            ),
          ),

          Divider(color: c.border, height: 1),

          // شريط الأزرار التفاعلية الذكي والسياقي
          _buildInspectorActions(context, order),
        ],
      ),
    );
  }

  // ─────────────────────────── مسار مراحل الطلب البصري ───────────────────────────

  Widget _buildOrderLifecycleStepper(BuildContext context, PosOrder order) {
    final c = context.posColors;
    final s = order.status.toLowerCase();
    final isCancelled = s == 'cancelled';

    if (isCancelled) {
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'الطلب ملغي في النظام',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: const Color(0xFF991B1B),
                    ),
                  ),
                  Text(
                    'السبب: ${order.cancellationReason ?? "إلغاء مباشر من الإدارة"}',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11,
                      color: const Color(0xFFB91C1C),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final stages = [
      {'key': 'new', 'label': 'جديد', 'icon': Icons.fiber_new_rounded},
      {'key': 'preparing', 'label': 'بالمطبخ', 'icon': Icons.soup_kitchen_rounded},
      {'key': 'ready', 'label': 'جاهز', 'icon': Icons.shopping_bag_rounded},
      {'key': 'completed', 'label': 'مسلّم', 'icon': Icons.verified_rounded},
    ];

    int currentIdx = 0;
    if (s == 'preparing') currentIdx = 1;
    if (s == 'ready') currentIdx = 2;
    if (s == 'on_way' || s == 'in_delivery') currentIdx = 2;
    if (s == 'completed' || s == 'delivered') currentIdx = 3;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (int i = 0; i < stages.length; i++) ...[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < currentIdx
                          ? const Color(0xFF10B981)
                          : (i == currentIdx ? c.primary : c.border),
                    ),
                    child: Center(
                      child: i < currentIdx
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                          : Icon(stages[i]['icon'] as IconData, color: Colors.white, size: 13),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    stages[i]['label'] as String,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 10,
                      fontWeight: i == currentIdx ? FontWeight.bold : FontWeight.w600,
                      color: i == currentIdx
                          ? c.primary
                          : (i < currentIdx ? const Color(0xFF10B981) : c.textMuted),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (i < stages.length - 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  width: 12,
                  height: 2,
                  color: i < currentIdx ? const Color(0xFF10B981) : c.border,
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────── شريط الأزرار التفاعلية الذكي المتكيف ───────────────────────────

  Widget _buildInspectorActions(BuildContext context, PosOrder order) {
    final c = context.posColors;
    final s = order.status.toLowerCase();
    final isCancelled = s == 'cancelled';
    final isCompleted = s == 'completed' || s == 'delivered';

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. الزر الرئيسي الذكي والسياقي
          if (!isCancelled && !isCompleted) ...[
            if (s == 'pending' || s == 'new')
              ElevatedButton.icon(
                onPressed: () async {
                  await _updateOrderStatus(order.orderId, 'preparing');
                  ThermalPrinterService.printOrder(order: order);
                },
                icon: const Icon(Icons.soup_kitchen_rounded, size: 18),
                label: const Text('قبول الطلب وإرسال للمطبخ 👨‍🍳'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              )
            else if (s == 'preparing')
              ElevatedButton.icon(
                onPressed: () => _updateOrderStatus(order.orderId, 'ready'),
                icon: const Icon(Icons.shopping_bag_rounded, size: 18),
                label: const Text('تأكيد جاهزية الطلب للتسليم 🛍️'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              )
            else if (s == 'ready' || s == 'on_way' || s == 'in_delivery')
              ElevatedButton.icon(
                onPressed: () => _updateOrderStatus(order.orderId, 'completed'),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('تأكيد تسليم الطلب للزبون بنجاح ✓'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF15803D),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
          ] else if (isCompleted) ...[
            ElevatedButton.icon(
              onPressed: () => _showInvoicePreviewDialog(context, order),
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: const Text('معاينة وإعادة طباعة الفاتورة 📄'),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(
                  'الطلب ملغي في السجل المالي والتشغيلي',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: const Color(0xFFB91C1C),
                  ),
                ),
              ),
            ),
          ],

          // كابتن التوصيل للطلبات التوصيل
          if (order.orderType == 'delivery' && !isCancelled) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showCourierDispatchDialog(context, order),
              icon: const Icon(Icons.moped_rounded, size: 16),
              label: Text(
                order.driverName?.isNotEmpty == true
                    ? 'إدارة كابتن التوصيل (${order.driverName}) 🛵'
                    : (order.deliveryStatus == 'searching_driver'
                        ? 'متابعة بث المناديب 📡'
                        : 'طلب مندوب مدار 🛵'),
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: order.driverName?.isNotEmpty == true
                    ? const Color(0xFF10B981)
                    : (order.deliveryStatus == 'searching_driver'
                        ? const Color(0xFFF59E0B)
                        : MadarColors.primary),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],

          const SizedBox(height: 8),

          // 2. صف الإجراءات المساعدة 1: تعديل + طباعة
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEditOrderDialog(context, order),
                  icon: const Icon(Icons.edit_note_rounded, size: 15),
                  label: const Text('تعديل الطلب'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.primary,
                    side: BorderSide(color: c.primary.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ThermalPrinterService.printOrder(order: order),
                  icon: const Icon(Icons.print_rounded, size: 15),
                  label: const Text('طباعة إيصال'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.textPrimary,
                    side: BorderSide(color: c.border),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),

          // 3. صف الإجراءات المساعدة 2: إلغاء الطلب إن أمكن
          if (!isCancelled && !isCompleted) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showCancelReasonDialog(context, order),
                icon: const Icon(Icons.cancel_outlined, size: 15),
                label: const Text('إلغاء الطلب وتوثيق السبب'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────── تبويب الفاتورة والبنود ───────────────────────────

  Widget _buildOrderInvoiceAndItemsTab(BuildContext context, PosOrder order) {
    final c = context.posColors;

    String locationDisplay;
    if (order.orderType == 'dine_in') {
      locationDisplay = 'داخل المطعم - صالة ${order.tableNumber != null ? "(طاولة ${order.tableNumber})" : ""}';
    } else if (order.orderType == 'takeaway') {
      locationDisplay = 'استلام سفري مباشر من المطعم';
    } else {
      locationDisplay = order.deliveryAddress?.isNotEmpty == true ? order.deliveryAddress! : 'العنوان قيد التحديد للتوصيل';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // زر معاينة الفاتورة الحرارية المباشر
          InkWell(
            onTap: () => _showInvoicePreviewDialog(context, order),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    c.primary.withValues(alpha: 0.12),
                    c.primary.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_rounded, color: c.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'معاينة الفاتورة الحرارية (80mm) والطباعة 📄',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: c.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // بطاقة معلومات العميل والطلب المتجاوبة
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. السطر الأول: صورة/أيقونة العميل + الاسم + نوع الطلب
                Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: c.primary.withValues(alpha: 0.12),
                      child: Icon(Icons.person_rounded, color: c.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.customerName?.trim().isNotEmpty == true
                                ? order.customerName!
                                : 'عميل مباشر',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: c.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            order.orderType == 'dine_in'
                                ? 'طلب صالة داخلي'
                                : (order.orderType == 'delivery'
                                    ? 'طلب توصيل خارجي'
                                    : 'طلب استلام سفري'),
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10.5,
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildOrderTypeBadge(context, order),
                  ],
                ),

                const SizedBox(height: 10),

                // 2. السطر الثاني: صندوق رقم الهاتف التفاعلي المنفصل مع أزرار الإجراءات
                if (order.customerPhone?.isNotEmpty == true) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.border.withValues(alpha: 0.8)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.phone_iphone_rounded, size: 15, color: c.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            order.customerPhone!,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        // زر نسخ الرقم
                        Tooltip(
                          message: 'نسخ الرقم',
                          child: InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: order.customerPhone!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم نسخ رقم الهاتف بنجاح 📋'),
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Icon(Icons.copy_rounded, size: 14, color: c.textMuted),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // زر واتساب الذكي
                        Tooltip(
                          message: 'مراسلة عبر واتساب',
                          child: InkWell(
                            onTap: () => _openWhatsApp(order.customerPhone!, order),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Color(0xFF16A34A)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'واتساب',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.card.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.border.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.phone_disabled_rounded, size: 14, color: c.textDisabled),
                        const SizedBox(width: 8),
                        Text(
                          'بدون رقم هاتف مسجل للعميل',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            color: c.textDisabled,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // 3. السطر الثالث: تفاصيل الموقع / الطاولة / الاستلام
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.border.withValues(alpha: 0.8)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.location_on_outlined, size: 14, color: c.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          locationDisplay,
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textPrimary, height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // كارت الملاحظات البارز (إن وجدت ملاحظات خاصة)
          if (order.notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note_alt_outlined, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ملاحظة الزبون والمطبخ:',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                        Text(
                          order.notes!,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF78350F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // بطاقة كابتن التوصيل والبحث عن مناديب مدار
          if (order.orderType == 'delivery' || order.driverName?.isNotEmpty == true || order.deliveryStatus == 'searching_driver') ...[
            const SizedBox(height: 12),
            _buildDeliveryCourierCard(context, order),
          ],

          const SizedBox(height: 16),

          // قائمة الأصناف والبنود الكاملة
          Text(
            'بنود الطلب (${order.items.length})',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          if (order.items.isEmpty)
            Text(
              'لا توجد أصناف مسجلة في هذا الطلب',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
            )
          else
            ...order.items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: c.border),
                      ),
                      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Image.network(
                                item.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Icon(Icons.fastfood_rounded, size: 18, color: c.primary),
                              ),
                            )
                          : Icon(Icons.fastfood_rounded, size: 18, color: c.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.name} × ${item.quantity}',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                          if (item.selectedSize != null)
                            Text(
                              'الحجم: ${item.selectedSize}',
                              style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textMuted),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${_formatAmount(item.totalPrice)} د.ع',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 12),
          Divider(color: c.border, height: 1),
          const SizedBox(height: 12),

          // الحساب المالي الدقيق
          _buildFinancialRow('المجموع الفرعي', '${_formatAmount(order.subtotal)} د.ع'),
          const SizedBox(height: 6),
          if (order.orderType == 'delivery') ...[
            _buildFinancialRow(
              'رسوم التوصيل',
              order.deliveryFee > 0 ? '${_formatAmount(order.deliveryFee)} د.ع' : 'مجاني',
            ),
            const SizedBox(height: 6),
          ],
          if (order.discountAmount > 0) ...[
            _buildFinancialRow('الخصم', '-${_formatAmount(order.discountAmount)} د.ع'),
            const SizedBox(height: 6),
          ],
          if (order.taxOrService > 0) ...[
            _buildFinancialRow('الضريبة والخدمة', '${_formatAmount(order.taxOrService)} د.ع'),
            const SizedBox(height: 6),
          ],
          Divider(color: c.border, height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الإجمالي النهائي',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              Text(
                '${_formatAmount(order.totalAmount)} د.ع',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: c.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String title, String value) {
    final c = context.posColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
        ),
        Text(
          value,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────── تبويب سجل التدقيق الحقيقي 100% ───────────────────────────

  Widget _buildOrderRealAuditLogTab(BuildContext context, PosOrder order) {
    final c = context.posColors;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AuditLogService.instance.getLogsForOrder(order.orderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final auditLogs = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // ترويسة أمان التدقيق
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: c.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سجل العمليات والرقابة التجارية المباشر للطلب #${_formatOrderId(order.orderId)}',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 1. لحظة إصدار الطلب الحقيقية
            _buildLogStep(
              title: 'تم تسجيل الطلب وإصداره في النظام',
              subtitle: 'المصدر: ${order.orderType == "delivery" ? "توصيل" : (order.orderType == "dine_in" ? "صالة" : "سفري")} • الكاشير: ${order.cashierName}',
              time: DateFormat('yyyy/MM/dd hh:mm a').format(order.createdAt),
              done: true,
            ),

            // 2. لحظة قبول الطلب أو التحضير إن توفرت
            if (order.acceptedAt != null || order.preparingAt != null)
              _buildLogStep(
                title: 'قبول الطلب وإرساله لخط المطبخ',
                subtitle: 'تم تأكيد الطلب وبدء التحضير',
                time: DateFormat('yyyy/MM/dd hh:mm a').format(order.acceptedAt ?? order.preparingAt!),
                done: true,
              ),

            // 3. لحظة الجاهزية إن توفرت
            if (order.readyAt != null)
              _buildLogStep(
                title: 'اكتمال الطهي وجاهزية الطلب للتسليم',
                subtitle: 'تم نقله إلى رف التسليم',
                time: DateFormat('yyyy/MM/dd hh:mm a').format(order.readyAt!),
                done: true,
              ),

            // 4. لحظة التسليم أو الاكتمال إن توفرت
            if (order.completedAt != null)
              _buildLogStep(
                title: 'إتمام الطلب وتسليمه بنجاح ✓',
                subtitle: 'تم إغلاق الفاتورة واستلام المبلغ',
                time: DateFormat('yyyy/MM/dd hh:mm a').format(order.completedAt!),
                done: true,
              ),

            // 5. في حال الإلغاء
            if (order.status.toLowerCase() == 'cancelled')
              _buildLogStep(
                title: 'تم إلغاء الطلب ✕',
                subtitle: 'السبب: ${order.cancellationReason ?? "إلغاء مباشر من الإدارة"}',
                time: order.cancelledAt != null
                    ? DateFormat('yyyy/MM/dd hh:mm a').format(order.cancelledAt!)
                    : 'ملغي',
                done: true,
                isDanger: true,
              ),

            // 6. الحركات والعمليات المسجلة في سجل التدقيق التجاري
            if (auditLogs.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 12),
              Text(
                'العمليات الرقابية الموثقة (${auditLogs.length}):',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: c.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              ...auditLogs.map((log) {
                final action = log['action']?.toString() ?? '';
                final actionArabic = AuditLogService.actionToArabic(action);
                final userName = log['user_name']?.toString() ?? 'الكاشير';
                final reason = log['reason']?.toString() ?? '';
                final rawTime = log['timestamp']?.toString();
                String formattedTime = '';
                if (rawTime != null) {
                  final dt = DateTime.tryParse(rawTime);
                  if (dt != null) {
                    formattedTime = DateFormat('yyyy/MM/dd hh:mm a').format(dt);
                  } else {
                    formattedTime = rawTime;
                  }
                }

                final isCancel = action.contains('cancel');

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isCancel ? const Color(0xFFFEF2F2) : c.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCancel
                          ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                          : c.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isCancel ? Icons.warning_amber_rounded : Icons.history_rounded,
                            size: 15,
                            color: isCancel ? const Color(0xFFEF4444) : c.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            actionArabic,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isCancel ? const Color(0xFF991B1B) : c.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            formattedTime,
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textMuted),
                          ),
                        ],
                      ),
                      if (reason.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          reason,
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textPrimary),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        'المسؤول: $userName',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textMuted),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }

  Widget _buildLogStep({
    required String title,
    String? subtitle,
    required String time,
    required bool done,
    bool isDanger = false,
  }) {
    final c = context.posColors;
    Color iconColor;
    if (isDanger) {
      iconColor = const Color(0xFFEF4444);
    } else if (done) {
      iconColor = const Color(0xFF10B981);
    } else {
      iconColor = c.textDisabled;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              isDanger
                  ? Icons.cancel_rounded
                  : (done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded),
              color: iconColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5,
                    color: isDanger
                        ? const Color(0xFFEF4444)
                        : (done ? c.textPrimary : c.textMuted),
                    fontWeight: done ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                  ),
              ],
            ),
          ),
          Text(
            time,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11,
              color: isDanger ? const Color(0xFFEF4444) : c.textMuted,
              fontWeight: isDanger ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── تحديث حالة الطلب في Firestore و SQLite ───────────────────────────

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      HapticFeedback.mediumImpact();

      final now = FieldValue.serverTimestamp();
      final Map<String, dynamic> updateData = {
        'status': newStatus,
        'updatedAt': now,
      };

      if (newStatus == 'preparing') {
        updateData['acceptedAt'] = now;
        updateData['preparingAt'] = now;
      } else if (newStatus == 'ready') {
        updateData['readyAt'] = now;
      } else if (newStatus == 'completed' || newStatus == 'delivered') {
        updateData['completedAt'] = now;
      }

      // 1. تحديث Firestore
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update(updateData);

      // 2. توثيق في سجل التدقيق التجاري الحقيقي
      final user = FirebaseAuth.instance.currentUser;
      await AuditLogService.instance.log(
        action: 'order_status_$newStatus',
        targetType: 'order',
        targetId: orderId,
        reason: 'تحديث حالة الطلب إلى ${_getStatusTitle(newStatus)}',
        customCashierName: user?.displayName ?? 'كاشير المحطة',
      );

      // 3. تحديث SQLite محلياً
      try {
        final db = await LocalDatabaseService.instance.database;
        await db.update(
          'local_orders',
          {'status': newStatus},
          where: 'local_id = ? OR remote_id = ?',
          whereArgs: [orderId, orderId],
        );
        _loadLocalOrders();
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث حالة الطلب إلى ${_getStatusTitle(newStatus)} بنجاح'),
            backgroundColor: context.posColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تحديث حالة الطلب: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _deleteLocalOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا الطلب من التخزين المحلي؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await LocalDatabaseService.instance.deleteLocalOrder(orderId);
      await _loadLocalOrders();
      if (mounted) {
        setState(() {
          if (_selectedOrder?.orderId == orderId) {
            _selectedOrder = null;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الطلب المحلي بنجاح'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  // ─────────────────────────── خلية السائق في جدول الطلبات ───────────────────────────

  Widget _buildDriverCell(BuildContext context, PosOrder order) {
    final c = context.posColors;

    // إذا لم يكن الطلب من نوع توصيل ولا يوجد سائق معين
    if (order.orderType != 'delivery' && (order.driverName == null || order.driverName!.isEmpty)) {
      return Text(
        '—',
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 12,
          color: c.textDisabled,
        ),
      );
    }

    // إذا تم تعيين سائق بالفعل
    if (order.driverName?.isNotEmpty == true) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showCourierDispatchDialog(context, order),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delivery_dining_rounded, size: 15, color: Color(0xFF10B981)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  order.driverName!,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF047857),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // إذا كان جاري البحث عن مندوب عبر بث مدار
    if (order.deliveryStatus == 'searching_driver') {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showCourierDispatchDialog(context, order),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'جاري البحث...',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB45309),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // طلب توصيل يحتاج مندوب ولم يتم إرسال طلب بعد
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showCourierDispatchDialog(context, order),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: c.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.moped_rounded, size: 14, color: c.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'طلب مندوب 🛵',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── بطاقة كابتن التوصيل في لوحة التفاصيل ───────────────────────────

  Widget _buildDeliveryCourierCard(BuildContext context, PosOrder order) {
    final c = context.posColors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: order.deliveryStatus == 'searching_driver'
              ? const Color(0xFFF59E0B)
              : (order.driverName?.isNotEmpty == true
                  ? const Color(0xFF10B981).withValues(alpha: 0.5)
                  : c.border),
          width: order.deliveryStatus == 'searching_driver' ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (order.driverName?.isNotEmpty == true
                          ? const Color(0xFF10B981)
                          : (order.deliveryStatus == 'searching_driver'
                              ? const Color(0xFFF59E0B)
                              : c.primary))
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  order.driverName?.isNotEmpty == true
                      ? Icons.delivery_dining_rounded
                      : (order.deliveryStatus == 'searching_driver'
                          ? Icons.sensors_rounded
                          : Icons.moped_rounded),
                  size: 20,
                  color: order.driverName?.isNotEmpty == true
                      ? const Color(0xFF10B981)
                      : (order.deliveryStatus == 'searching_driver'
                          ? const Color(0xFFF59E0B)
                          : c.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'كابتن التوصيل (مناديب مدار)',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      order.driverName?.isNotEmpty == true
                          ? 'تم تعيين المندوب للطلب'
                          : (order.deliveryStatus == 'searching_driver'
                              ? 'جاري البحث وإرسال إشعار لكافة المناديب'
                              : 'لم يتم تعيين مندوب حتى الآن'),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        color: c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (order.driverName?.isNotEmpty == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'معين ✓',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF047857),
                    ),
                  ),
                )
              else if (order.deliveryStatus == 'searching_driver')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 8,
                        height: 8,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'جاري البحث',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (order.driverName?.isNotEmpty == true) ...[
            // معلومات المندوب المعين
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                    backgroundImage: (order.driverImage != null && order.driverImage!.isNotEmpty)
                        ? NetworkImage(order.driverImage!)
                        : null,
                    onBackgroundImageError: (order.driverImage != null && order.driverImage!.isNotEmpty)
                        ? (_, _) {}
                        : null,
                    child: (order.driverImage == null || order.driverImage!.isEmpty)
                        ? const Icon(Icons.person, color: Color(0xFF10B981), size: 20)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.driverName!,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: c.textPrimary,
                          ),
                        ),
                        Text(
                          order.driverPhone?.isNotEmpty == true
                              ? order.driverPhone!
                              : 'رقم الهاتف غير متوفر',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            color: c.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showCourierDispatchDialog(context, order),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('تغيير المندوب'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      foregroundColor: c.primary,
                      side: BorderSide(color: c.primary.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (order.driverId != null && order.driverId!.isNotEmpty) {
                        try {
                          await DeliveryDispatchService.instance.assignSpecificCourier(
                            order: order,
                            courier: OnlineCourier(
                              id: order.driverId!,
                              name: order.driverName ?? 'كابتن التوصيل',
                              phone: order.driverPhone ?? '',
                            ),
                            restaurantName: _restaurantName,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم إرسال إشعار تذكير للكابتن ${order.driverName} بنجاح 🔔'),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('[OrdersManagementPage] Error pinging driver: $e');
                        }
                      }
                    },
                    icon: const Icon(Icons.notifications_active_rounded, size: 16),
                    label: const Text('تذكير المندوب'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (order.deliveryStatus == 'searching_driver') ...[
            // شريط جاري البحث وبث الإشعار
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sensors_rounded, color: Color(0xFFD97706), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تم إرسال إشعار نداء عاجل لكافة مناديب مدار. النظام بانتظار قبول أحدهم للطلب.',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await DeliveryDispatchService.instance.cancelCourierSearch(order.orderId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم إلغاء البحث عن المندوب.'),
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      foregroundColor: c.danger,
                      side: BorderSide(color: c.danger.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('إلغاء البحث'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showCourierDispatchDialog(context, order),
                    icon: const Icon(Icons.person_search_rounded, size: 16),
                    label: const Text('اختيار كابتن محدد'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      backgroundColor: c.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // لم يتم إرسال طلب مندوب بعد
            ElevatedButton.icon(
              onPressed: () => _showCourierDispatchDialog(context, order),
              icon: const Icon(Icons.moped_rounded, size: 18),
              label: const Text('طلب كابتن توصيل مدار وإرسال إشعار 🛵'),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────── نافذة البحث عن كابتن وتعيين مندوب مدار ───────────────────────────

  void _showCourierDispatchDialog(BuildContext context, PosOrder order) {
    final c = context.posColors;
    final messenger = ScaffoldMessenger.of(context);
    bool isBroadcasting = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (contentCtx, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Dialog(
                backgroundColor: c.card,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  width: 640,
                  constraints: const BoxConstraints(maxHeight: 700),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ترويسة النافذة
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: c.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.moped_rounded, color: c.primary, size: 26),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'البحث عن مندوب وإرسال إشعار 🛵',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'طلب ${_formatOrderId(order.orderId)} • ${_formatAmount(order.totalAmount)} د.ع • ${order.deliveryAddress ?? "العنوان قيد التحديد"}',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 12,
                                    color: c.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: c.textMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Divider(color: c.border, height: 1),
                      const SizedBox(height: 16),

                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. بطاقة البث الفوري العام لكافة المناديب
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFFFFF7ED),
                                      const Color(0xFFFFEDD5),
                                    ],
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFDBA74)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: MadarColors.primary,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.campaign_rounded,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'بث عام لكافة مناديب مدار 📢',
                                                style: GoogleFonts.ibmPlexSansArabic(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: const Color(0xFF9A3412),
                                                ),
                                              ),
                                              Text(
                                                'إرسال إشعار فوري عالي الأولوية (Alarm Alert) لجميع المناديب في تطبيق مدار',
                                                style: GoogleFonts.ibmPlexSansArabic(
                                                  fontSize: 11.5,
                                                  color: const Color(0xFFC2410C),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'سيصل إشعار نداء فوري بصوت مميز إلى هواتف كافة كباتن التوصيل المسجلين، مع تفاصيل العنوان والمطعم ليقوم أول كابتن متاح بقبول وتوصيل الطلب.',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 11.5,
                                        color: const Color(0xFF7C2D12),
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: isBroadcasting
                                                ? null
                                                : () async {
                                                    setDialogState(() => isBroadcasting = true);
                                                    final success = await DeliveryDispatchService.instance.broadcastToAllCouriers(
                                                      order: order,
                                                      restaurantName: _restaurantName,
                                                    );
                                                    setDialogState(() => isBroadcasting = false);

                                                    if (dialogCtx.mounted) {
                                                      Navigator.of(dialogCtx).pop();
                                                    }
                                                    if (mounted) {
                                                      messenger.showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            success
                                                                ? 'تم إرسال إشعار نداء عاجل لكافة مناديب مدار بنجاح! 🛵📡'
                                                                : 'تعذر بث الإشعار، يرجى التحقق من الاتصال.',
                                                          ),
                                                          backgroundColor: success
                                                              ? const Color(0xFF10B981)
                                                              : const Color(0xFFEF4444),
                                                        ),
                                                      );
                                                    }
                                                  },
                                            icon: isBroadcasting
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Icon(Icons.send_rounded, size: 16),
                                            label: Text(
                                              isBroadcasting
                                                  ? 'جاري إرسال الإشعار...'
                                                  : (order.deliveryStatus == 'searching_driver'
                                                      ? 'إعادة إرسال البث لجميع المناديب 📢'
                                                      : 'إرسال إشعار وبث للجميع الآن 📢'),
                                              style: GoogleFonts.ibmPlexSansArabic(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: MadarColors.primary,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ),
                                        if (order.deliveryStatus == 'searching_driver') ...[
                                          const SizedBox(width: 8),
                                          OutlinedButton(
                                            onPressed: () async {
                                              await DeliveryDispatchService.instance.cancelCourierSearch(order.orderId);
                                              if (dialogCtx.mounted) {
                                                Navigator.of(dialogCtx).pop();
                                              }
                                              if (mounted) {
                                                messenger.showSnackBar(
                                                  const SnackBar(
                                                    content: Text('تم إلغاء البحث وبث الطلب.'),
                                                  ),
                                                );
                                              }
                                            },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFFEF4444),
                                              side: const BorderSide(color: Color(0xFFEF4444)),
                                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            child: const Text('إلغاء البحث'),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // 2. فاصل أو اختيار مندوب محدد
                              Row(
                                children: [
                                  Expanded(child: Divider(color: c.border)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      'أو اختيار وتعيين كابتن محدد بالاسم',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 12,
                                        color: c.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: c.border)),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // 3. قائمة المناديب المتصلين حالياً من Firestore
                              StreamBuilder<List<OnlineCourier>>(
                                stream: DeliveryDispatchService.instance.getOnlineCouriersStream(),
                                builder: (context, courierSnap) {
                                  if (courierSnap.connectionState == ConnectionState.waiting) {
                                    return const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Center(
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    );
                                  }

                                  final couriers = courierSnap.data ?? [];

                                  if (couriers.isEmpty) {
                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: c.background,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: c.border),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.info_outline_rounded, color: c.textMuted, size: 22),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'لا يوجد كباتن في وضع الاتصال المباشر حالياً. يمكنك استخدام زر البث بالأعلى لإرسال إشعار فوري لكافة المناديب فور فتحهم للتطبيق.',
                                              style: GoogleFonts.ibmPlexSansArabic(
                                                fontSize: 12,
                                                color: c.textMuted,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'المناديب المتصلين في تطبيق مدار (${couriers.length})',
                                            style: GoogleFonts.ibmPlexSansArabic(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: c.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF10B981),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: couriers.length,
                                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                                        itemBuilder: (context, index) {
                                          final courier = couriers[index];
                                          final isAlreadyAssigned = order.driverId == courier.id;

                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: isAlreadyAssigned
                                                  ? const Color(0xFF10B981).withValues(alpha: 0.08)
                                                  : c.background,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isAlreadyAssigned
                                                    ? const Color(0xFF10B981)
                                                    : c.border,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Stack(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 20,
                                                      backgroundColor: c.primary.withValues(alpha: 0.12),
                                                      backgroundImage: courier.imageUrl != null && courier.imageUrl!.isNotEmpty
                                                          ? NetworkImage(courier.imageUrl!)
                                                          : null,
                                                      onBackgroundImageError: courier.imageUrl != null && courier.imageUrl!.isNotEmpty
                                                          ? (_, _) {}
                                                          : null,
                                                      child: courier.imageUrl == null || courier.imageUrl!.isEmpty
                                                          ? Icon(Icons.person_rounded, color: c.primary, size: 22)
                                                          : null,
                                                    ),
                                                    Positioned(
                                                      bottom: 0,
                                                      right: 0,
                                                      child: Container(
                                                        width: 10,
                                                        height: 10,
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF10B981),
                                                          shape: BoxShape.circle,
                                                          border: Border.all(color: Colors.white, width: 1.5),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            courier.name,
                                                            style: GoogleFonts.ibmPlexSansArabic(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 13,
                                                              color: c.textPrimary,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            '• ${courier.vehicleType}',
                                                            style: GoogleFonts.ibmPlexSansArabic(
                                                              fontSize: 11,
                                                              color: c.textMuted,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        courier.phone.isNotEmpty
                                                            ? courier.phone
                                                            : 'هاتف غير مسجل',
                                                        style: GoogleFonts.ibmPlexSansArabic(
                                                          fontSize: 11,
                                                          color: c.textMuted,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (isAlreadyAssigned)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      'المندوب الحالي ✓',
                                                      style: GoogleFonts.ibmPlexSansArabic(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.bold,
                                                        color: const Color(0xFF047857),
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  ElevatedButton.icon(
                                                    onPressed: () async {
                                                      final success = await DeliveryDispatchService.instance.assignSpecificCourier(
                                                        order: order,
                                                        courier: courier,
                                                        restaurantName: _restaurantName,
                                                      );

                                                      if (dialogCtx.mounted) {
                                                        Navigator.of(dialogCtx).pop();
                                                      }
                                                      if (mounted) {
                                                        messenger.showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              success
                                                                  ? 'تم إسناد الطلب للكابتن ${courier.name} وإرسال إشعار مباشر لجوّاله بنجاح! 🛵'
                                                                  : 'تعذر تعيين المندوب، يرجى المحاولة ثانية.',
                                                            ),
                                                            backgroundColor: success
                                                                ? const Color(0xFF10B981)
                                                                : const Color(0xFFEF4444),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    icon: const Icon(Icons.send_to_mobile_rounded, size: 14),
                                                    label: const Text('تعيين وإشعار 📲'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: c.primary,
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────── أدوات المساعدة والبادجات الحقيقية ───────────────────────────

  Widget _buildOrderStatusBadge(BuildContext context, String status) {
    Color bg;
    Color text;
    String label;

    switch (status.toLowerCase()) {
      case 'new':
      case 'pending':
        bg = const Color(0xFFFFF7ED);
        text = MadarColors.primary;
        label = 'جديد';
        break;
      case 'preparing':
        bg = const Color(0xFFFFFBEB);
        text = const Color(0xFFF59E0B);
        label = 'قيد التحضير';
        break;
      case 'ready':
        bg = const Color(0xFFF0FDF4);
        text = const Color(0xFF10B981);
        label = 'جاهز';
        break;
      case 'on_way':
      case 'in_delivery':
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF3B82F6);
        label = 'في التوصيل';
        break;
      case 'completed':
      case 'delivered':
        bg = const Color(0xFFF0FDF4);
        text = const Color(0xFF15803D);
        label = 'مكتمل';
        break;
      case 'cancelled':
      default:
        bg = const Color(0xFFFEF2F2);
        text = const Color(0xFFEF4444);
        label = 'ملغي';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.ibmPlexSansArabic(
          color: text,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildOrderTypeBadge(BuildContext context, PosOrder order) {
    final c = context.posColors;
    IconData icon;
    String label;

    final type = order.orderType.toLowerCase();

    switch (type) {
      case 'delivery':
        icon = Icons.two_wheeler_rounded;
        label = 'توصيل';
        break;
      case 'dine_in':
        icon = Icons.table_restaurant_rounded;
        label = order.tableNumber != null && order.tableNumber!.isNotEmpty
            ? 'طاولة ${order.tableNumber}'
            : 'صالة';
        break;
      case 'takeaway':
      default:
        icon = Icons.shopping_bag_outlined;
        label = 'سفري';
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 12,
            color: c.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodBadge(BuildContext context, String method) {
    Color bg;
    Color text;
    String label;

    switch (method.toLowerCase()) {
      case 'card':
      case 'visa':
      case 'mastercard':
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF1D4ED8);
        label = 'بطاقة';
        break;
      case 'wallet':
      case 'zain_cash':
        bg = const Color(0xFFFAF5FF);
        text = const Color(0xFF7E22CE);
        label = 'محفظة';
        break;
      case 'debit':
      case 'credit':
        bg = const Color(0xFFFFFBEB);
        text = const Color(0xFFD97706);
        label = 'آجل';
        break;
      case 'cash':
      default:
        bg = const Color(0xFFF0FDF4);
        text = const Color(0xFF15803D);
        label = 'نقدي';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 11,
          color: text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getStatusTitle(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'new':
        return 'جديد';
      case 'preparing':
        return 'قيد التحضير';
      case 'ready':
        return 'جاهز';
      case 'on_way':
      case 'in_delivery':
        return 'في التوصيل';
      case 'completed':
      case 'delivered':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'جميع الحالات';
    }
  }

  String _getSourceTitle(String source) {
    switch (source.toLowerCase()) {
      case 'app':
        return 'تطبيق مدار (توصيل)';
      case 'dine_in':
        return 'داخل الصالة';
      case 'takeaway':
        return 'سفري واستلام';
      default:
        return 'جميع مصادر الطلب';
    }
  }

  String _getDateTitle(String dateKey) {
    switch (dateKey) {
      case 'today':
        return 'اليوم';
      case 'yesterday':
        return 'الأمس';
      case 'week':
        return 'آخر 7 أيام';
      case 'custom':
        if (_customDateRange != null) {
          final s = DateFormat('MM/dd').format(_customDateRange!.start);
          final e = DateFormat('MM/dd').format(_customDateRange!.end);
          return '$s - $e';
        }
        return 'نطاق مخصص';
      default:
        return 'جميع التواريخ';
    }
  }

  String _formatOrderId(String id) {
    if (id.startsWith('MAD-') || id.startsWith('ORD-')) return '#$id';
    if (id.length > 6) return '#MAD-${id.substring(id.length - 6).toUpperCase()}';
    return '#MAD-$id';
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,###').format(amount);
  }

  /// احتساب الأعداد الحقيقية لكافة الحالات بناءً على الطلبات الفعلية
  Map<String, int> _calculateCounts(List<PosOrder> orders) {
    final map = {
      'new': 0,
      'completed': 0,
      'ready': 0,
      'preparing': 0,
      'on_way': 0,
      'cancelled': 0,
    };

    for (final o in orders) {
      final s = o.status.toLowerCase();
      if (s == 'new' || s == 'pending') {
        map['new'] = (map['new'] ?? 0) + 1;
      } else if (s == 'completed' || s == 'delivered') {
        map['completed'] = (map['completed'] ?? 0) + 1;
      } else if (s == 'ready') {
        map['ready'] = (map['ready'] ?? 0) + 1;
      } else if (s == 'preparing') {
        map['preparing'] = (map['preparing'] ?? 0) + 1;
      } else if (s == 'on_way' || s == 'in_delivery') {
        map['on_way'] = (map['on_way'] ?? 0) + 1;
      } else if (s == 'cancelled') {
        map['cancelled'] = (map['cancelled'] ?? 0) + 1;
      }
    }
    return map;
  }
}
