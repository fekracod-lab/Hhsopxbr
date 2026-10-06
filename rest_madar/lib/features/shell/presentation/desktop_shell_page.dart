import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:rest_madar/core/theme/app_theme.dart';
import 'package:rest_madar/core/localization/pos_language_controller.dart';
import 'package:rest_madar/core/design_system/madar_design_system.dart';
import 'package:rest_madar/core/widgets/pos_command_palette.dart';
import 'package:rest_madar/core/shortcuts/madar_shortcuts.dart';
import 'package:rest_madar/features/dashboard/presentation/pages/pos_home_page.dart';
import 'package:rest_madar/features/dashboard/presentation/pages/restaurant_analytics_page.dart';
import 'package:rest_madar/features/kitchen_orders/presentation/live_orders_page.dart';
import 'package:rest_madar/features/pos/presentation/pages/pos_main_page.dart';
import 'package:rest_madar/features/menu/presentation/pages/menu_page.dart';
import 'package:rest_madar/features/tables/presentation/tables_management_page.dart';
import 'package:rest_madar/features/orders/presentation/pages/orders_management_page.dart';
import 'package:rest_madar/features/settings/presentation/pages/settings_page.dart';
import 'package:rest_madar/features/menu/presentation/pages/modifiers_page.dart';
import 'package:rest_madar/features/menu/presentation/pages/categories_page.dart';
import 'package:rest_madar/features/tables/presentation/pages/reservations_page.dart';
import 'package:rest_madar/features/customers/presentation/pages/customers_page.dart';
import 'package:rest_madar/features/inventory/presentation/pages/inventory_page.dart';
import 'package:rest_madar/features/inventory/presentation/pages/purchases_page.dart';
import 'package:rest_madar/features/inventory/presentation/pages/suppliers_page.dart';
import 'package:rest_madar/features/expenses/presentation/pages/expenses_page.dart';
import 'package:rest_madar/features/employees/presentation/pages/employees_page.dart';
import 'package:rest_madar/features/marketing/presentation/pages/coupons_page.dart';
import 'package:rest_madar/features/delivery/presentation/pages/delivery_zones_page.dart';
import 'package:rest_madar/features/notifications/presentation/pages/notifications_center_page.dart';
import 'package:rest_madar/services/auto_print_order_service.dart';
import 'package:rest_madar/services/print_lock_service.dart';
import 'package:rest_madar/services/printer_settings_service.dart';
import 'package:rest_madar/services/offline_auth_service.dart';
import 'package:rest_madar/core/widgets/made_in_iraq_badge.dart';
import 'widgets/store_preview_dialog.dart';

/// مؤشرات عناصر القائمة الجانبية الموحدة لنظام مطاعم مدار
abstract final class MadarNav {
  static const int home = 0;
  static const int orders = 1;
  static const int kds = 2;
  static const int pos = 3;
  static const int menu = 4;
  static const int modifiers = 5;
  static const int categories = 6;
  static const int tables = 7;
  static const int reservations = 8;
  static const int customers = 9;
  static const int inventory = 10;
  static const int purchases = 11;
  static const int suppliers = 12;
  static const int expenses = 13;
  static const int employees = 14;
  static const int shifts = 15;
  static const int reports = 16;
  static const int coupons = 17;
  static const int delivery = 18;
  static const int notifications = 19;
  static const int settings = 20;
}

/// الإطار المكتبي المتكامل لنظام مطاعم مدار:
/// شريط جانبي شامل 19 عنصراً، رأس صفحة تفاعلي مع البحث Ctrl+K،
/// بطاقة المطعم الحية، وشريط النظام السفلي.
class DesktopShellPage extends StatefulWidget {
  const DesktopShellPage({super.key});

  @override
  State<DesktopShellPage> createState() => _DesktopShellPageState();
}

class _DesktopShellPageState extends State<DesktopShellPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _restaurantName = 'مطعم مدار';
  bool _isSidebarCollapsed = false;
  String _ownerName = 'صاحب المطعم';
  String _restaurantLocation = 'القائم - الأنبار';
  String? _logoUrl;
  String _terminalId = 'جاري التحميل...';
  StreamSubscription<AutoPrintEvent>? _autoPrintSub;
  StreamSubscription<DocumentSnapshot>? _userDocSub;
  StreamSubscription<DocumentSnapshot>? _restDocSub;
  StreamSubscription<QuerySnapshot>? _tableCallsSub;
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();
  bool _isFullscreen = false;
  bool _isOpen = true;
  String _surgeStatus = 'normal';
  int _prepTimeMinutes = 20;
  String _statusNote = '';
  List<Map<String, dynamic>> _activeTableCalls = [];
  String? _restaurantDocId;
  int _pendingOrdersCount = 0;
  StreamSubscription<QuerySnapshot>? _pendingOrdersSub;

  String get _activeUid {
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
    if (firebaseUid != null && firebaseUid.isNotEmpty) return firebaseUid;
    final offlineUid = OfflineAuthService.instance.currentUid;
    if (offlineUid.isNotEmpty) return offlineUid;
    return _uid;
  }

  @override
  void initState() {
    super.initState();
    final offName = OfflineAuthService.instance.cachedRestaurantName;
    final offOwner = OfflineAuthService.instance.cachedOwnerName;
    if (offName.isNotEmpty && offName != 'مطعم مدار') _restaurantName = offName;
    if (offOwner.isNotEmpty && offOwner != 'صاحب المطعم') _ownerName = offOwner;

    _listenRestaurantDetails();
    _listenTableCalls();
    _listenPendingOrders();
    _initThermalAutoPrintEngine();
    _loadTerminalId();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
  }

  void _listenTableCalls() {
    final uid = _activeUid;
    if (uid.isEmpty) return;
    _tableCallsSub?.cancel();
    _tableCallsSub = FirebaseFirestore.instance
        .collection('merchants')
        .doc(uid)
        .collection('table_calls')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _activeTableCalls = snapshot.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data() as Map);
          data['callId'] = d.id;
          return data;
        }).toList();
      });
    }, onError: (_) {});
  }

  Future<void> _loadTerminalId() async {
    final tid = await PrintLockService.instance.getTerminalId();
    if (mounted) setState(() => _terminalId = tid);
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _autoPrintSub?.cancel();
    _userDocSub?.cancel();
    _restDocSub?.cancel();
    _tableCallsSub?.cancel();
    _pendingOrdersSub?.cancel();
    AutoPrintOrderService.instance.stopListening();
    super.dispose();
  }

  void _listenPendingOrders() {
    final uid = _activeUid;
    if (uid.isEmpty) return;

    _pendingOrdersSub?.cancel();
    final ids = [uid, if (_restaurantDocId != null && _restaurantDocId!.isNotEmpty && _restaurantDocId != uid) _restaurantDocId!];

    Query<Map<String, dynamic>> pendingQuery = FirebaseFirestore.instance.collection('orders');
    if (ids.length == 1) {
      pendingQuery = pendingQuery.where('restaurantId', isEqualTo: ids.first);
    } else {
      pendingQuery = pendingQuery.where('restaurantId', whereIn: ids);
    }
    pendingQuery = pendingQuery.where('status', isEqualTo: 'pending');

    _pendingOrdersSub = pendingQuery
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _pendingOrdersCount = snap.docs.length;
        });
      }
    }, onError: (_) {});
  }

  Future<void> _initThermalAutoPrintEngine() async {
    await PrinterSettingsService.instance.init();
    await AutoPrintOrderService.instance.startListening(
      restaurantName: _restaurantName,
    );

    _autoPrintSub = AutoPrintOrderService.instance.events.listen((event) {
      if (!mounted) return;
      final posColors = context.posColors;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                event.printSuccess
                    ? Icons.print_rounded
                    : Icons.warning_amber_rounded,
                color: event.printSuccess
                    ? Colors.greenAccent
                    : Colors.amberAccent,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.message,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'الزبون: ${event.customerName} • المبلغ: ${event.totalAmount.toStringAsFixed(0)} د.ع',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: event.printSuccess
              ? posColors.primary
              : posColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  String _sanitizeOwnerName(dynamic raw) {
    if (raw == null) return 'صاحب المطعم';
    final name = raw.toString().trim();
    if (name.isEmpty) return 'صاحب المطعم';
    final lower = name.toLowerCase();
    // استبعاد اسم الحساب الافتراضي للمطور/التجربة في حال عدم تحديد اسم صاحب المطعم بعد
    if (name == 'عمر مثنى' ||
        name == 'عمر مثنى الراوي' ||
        name == 'عمر مثنى حامد' ||
        lower == 'omar muthana' ||
        lower == 'omar' ||
        lower == 'عمر') {
      return 'صاحب المطعم';
    }
    return name;
  }

  void _listenRestaurantDetails() {
    final uid = _activeUid;
    if (uid.isEmpty) return;

    _userDocSub?.cancel();
    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        _applyRestaurantData(doc.data() ?? {});
      }
    }, onError: (_) {});

    _restDocSub?.cancel();
    _restDocSub = FirebaseFirestore.instance
        .collection('restaurants')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        _applyRestaurantData(doc.data() ?? {});
      }
    }, onError: (_) {});
  }

  void _applyRestaurantData(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      final name = data['restaurantName'] ??
          data['storeName'] ??
          data['title'] ??
          data['name'];
      if (name != null && name.toString().trim().isNotEmpty) {
        _restaurantName = name.toString().trim();
      }

      final rawOwner = data['ownerName'] ??
          data['restaurantOwner'] ??
          data['managerName'] ??
          data['fullName'];
      final cleanOwner = _sanitizeOwnerName(rawOwner);
      if (cleanOwner != 'صاحب المطعم' || _ownerName == 'صاحب المطعم') {
        _ownerName = cleanOwner;
      }

      if (data['city'] != null && data['city'].toString().trim().isNotEmpty) {
        _restaurantLocation = '${data['city']} - الأنبار';
      } else if (data['address'] != null &&
          data['address'].toString().trim().isNotEmpty) {
        _restaurantLocation = data['address'].toString();
      }

      final photo = data['photoUrl'] ?? data['imageUrl'];
      if (photo != null && photo.toString().trim().isNotEmpty) {
        _logoUrl = photo.toString().trim();
      }

      if (data['isOpen'] != null) {
        _isOpen = data['isOpen'] as bool;
      }
      if (data['surgeStatus'] != null) {
        _surgeStatus = data['surgeStatus'].toString();
      } else if (data['status'] != null) {
        if (data['status'] == 'busy') _surgeStatus = 'busy';
        if (data['status'] == 'closed' || data['status'] == 'paused') _surgeStatus = 'paused';
      }
      if (data['prepTimeMinutes'] != null) {
        _prepTimeMinutes = (data['prepTimeMinutes'] as num).toInt();
      }
      if (data['statusNote'] != null) {
        _statusNote = data['statusNote'].toString();
      }

      final restId = data['restaurantId'] ?? data['merchantId'] ?? data['storeId'];
      if (restId != null && restId.toString().trim().isNotEmpty) {
        final cleanId = restId.toString().trim();
        if (cleanId != _restaurantDocId) {
          _restaurantDocId = cleanId;
          _listenPendingOrders();
        }
      }
    });
  }

  void _openStorePreview() {
    final activeId = (_restaurantDocId != null && _restaurantDocId!.isNotEmpty) ? _restaurantDocId! : _uid;
    StorePreviewDialog.show(
      context,
      restaurantId: activeId,
      restaurantName: _restaurantName,
      logoUrl: _logoUrl,
      location: _restaurantLocation,
      isOpen: _isOpen,
      prepTimeMinutes: _prepTimeMinutes,
      onOpenMenuSettings: () {
        setState(() => _selectedIndex = MadarNav.menu);
      },
    );
  }

  void _showOwnerProfileDialog() {
    final c = context.posColors;
    final ownerCtrl = TextEditingController(
      text: _ownerName == 'صاحب المطعم' ? '' : _ownerName,
    );
    final restCtrl = TextEditingController(text: _restaurantName);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.badge_rounded, color: c.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ملف مدير النظام وصاحب المطعم',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: c.textPrimary,
                    ),
                  ),
                  Text(
                    'تعديل الاسم الذي يظهر في أعلى الشاشة',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اسم صاحب المطعم / المدير',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: ownerCtrl,
                  decoration: InputDecoration(
                    hintText: 'أدخل اسم صاحب المطعم (مثال: أبو فهد)',
                    hintStyle: GoogleFonts.ibmPlexSansArabic(
                      color: c.textMuted,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: c.primary,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: c.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: c.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: c.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: c.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'اسم المنشأة / المطعم',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: restCtrl,
                  decoration: InputDecoration(
                    hintText: 'أدخل اسم المطعم التجاري',
                    hintStyle: GoogleFonts.ibmPlexSansArabic(
                      color: c.textMuted,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.storefront_rounded,
                      color: c.primary,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: c.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: c.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: c.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: c.primary, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'إلغاء',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: c.textMuted,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final newOwner = ownerCtrl.text.trim();
                final newRest = restCtrl.text.trim();
                final uid = FirebaseAuth.instance.currentUser?.uid ?? _uid;

                if (uid.isNotEmpty) {
                  try {
                    final updatePayload = <String, dynamic>{
                      if (newOwner.isNotEmpty) 'ownerName': newOwner,
                      if (newOwner.isNotEmpty) 'fullName': newOwner,
                      if (newRest.isNotEmpty) 'restaurantName': newRest,
                    };
                    await Future.wait([
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .set(updatePayload, SetOptions(merge: true)),
                      FirebaseFirestore.instance
                          .collection('restaurants')
                          .doc(uid)
                          .set(updatePayload, SetOptions(merge: true)),
                    ]);
                  } catch (_) {}
                }

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }

                if (mounted) {
                  setState(() {
                    if (newOwner.isNotEmpty) _ownerName = newOwner;
                    if (newRest.isNotEmpty) _restaurantName = newRest;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم تحديث بيانات المدير بنجاح',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(
                'حفظ وتحديث',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSurgeControlDialog() {
    final c = context.posColors;
    String selectedStatus = _surgeStatus;
    int prepTime = _prepTimeMinutes;
    final noteCtrl = TextEditingController(text: _statusNote);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5B22).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.speed_rounded, color: Color(0xFFFF5B22), size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التحكم بحالة المطعم في تطبيق مدار',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      'تحديث حالة الاستقبال وتنبيه الزبائن بوقت الانتظار لحظياً',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                    ),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حالة استقبال الطلبات الحالية',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildStatusOptionCard(
                      c: c,
                      title: 'استقبال طبيعي (متاح ومستعد)',
                      subtitle: 'المطبخ جاهز لاستقبال كافة طلبات الصالة والتوصيل',
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF10B981),
                      isSelected: selectedStatus == 'normal',
                      onTap: () => setModalState(() => selectedStatus = 'normal'),
                    ),
                    const SizedBox(height: 8),

                    _buildStatusOptionCard(
                      c: c,
                      title: 'ضغط عالي وذروة (المطبخ مزدحم)',
                      subtitle: 'تنبيه الزبائن بزيادة وقت التحضير لمنع الشكاوى',
                      icon: Icons.electric_bolt_rounded,
                      color: const Color(0xFFF59E0B),
                      isSelected: selectedStatus == 'busy',
                      onTap: () => setModalState(() => selectedStatus = 'busy'),
                    ),
                    const SizedBox(height: 8),

                    _buildStatusOptionCard(
                      c: c,
                      title: 'إيقاف استقبال الطلبات الخارجية مؤقتاً',
                      subtitle: 'الصالة ممتلئة - إيقاف استقبال طلبات التوصيل بتطبيق مدار',
                      icon: Icons.pause_circle_filled_rounded,
                      color: const Color(0xFFEF4444),
                      isSelected: selectedStatus == 'paused',
                      onTap: () => setModalState(() => selectedStatus = 'paused'),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'وقت تجهيز الطلب المتوقع (يظهر للزبون في التطبيق):',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [15, 25, 40, 60].map((mins) {
                        final isSel = prepTime == mins;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () => setModalState(() => prepTime = mins),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSel ? c.primary : c.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isSel ? c.primary : c.border),
                                ),
                                child: Center(
                                  child: Text(
                                    '$mins دقيقة',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      color: isSel ? Colors.white : c.textPrimary,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'رسالة خاصة للزبائن في تطبيق مدار (اختياري):',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteCtrl,
                      decoration: InputDecoration(
                        hintText: 'مثال: نعتذر عن التأخير الخفيف، الصالة تشهد إقبالاً كبيراً...',
                        hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted),
                        filled: true,
                        fillColor: c.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final uid = FirebaseAuth.instance.currentUser?.uid ?? _uid;
                  final note = noteCtrl.text.trim();

                  if (uid.isNotEmpty) {
                    try {
                      final isOpenVal = selectedStatus != 'paused';
                      final payload = <String, dynamic>{
                        'isOpen': isOpenVal,
                        'status': selectedStatus == 'busy'
                            ? 'busy'
                            : (selectedStatus == 'paused' ? 'paused' : 'open'),
                        'surgeStatus': selectedStatus,
                        'prepTimeMinutes': prepTime,
                        'statusNote': note,
                        'updatedAt': FieldValue.serverTimestamp(),
                      };

                      await Future.wait([
                        FirebaseFirestore.instance
                            .collection('restaurants')
                            .doc(uid)
                            .set(payload, SetOptions(merge: true)),
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .set(payload, SetOptions(merge: true)),
                      ]);
                    } catch (_) {}
                  }

                  if (ctx.mounted) Navigator.pop(ctx);

                  if (mounted) {
                    setState(() {
                      _surgeStatus = selectedStatus;
                      _isOpen = selectedStatus != 'paused';
                      _prepTimeMinutes = prepTime;
                      _statusNote = note;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم تحديث حالة المطعم في تطبيق مدار للزبائن بنجاح',
                          style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  'تطبيق وبث في التطبيق',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5B22),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOptionCard({
    required PosColors c,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : c.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : c.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: c.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  void _switchTo(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        PosThemeController.instance,
        PosLanguageController.instance,
      ]),
      builder: (context, _) {
        final c = context.posColors;
        final isTabletPortrait = MadarResponsive.isTabletPortrait(context);

        return Directionality(
          textDirection: PosLanguageController.instance.textDirection,
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: c.background,
            drawer: isTabletPortrait ? _buildDrawer(context) : null,
            body: SafeArea(
              child: MadarShortcutsScope(
                onNavigate: _switchTo,
                onOpenStore: _openStorePreview,
                onOpenSurgeControl: _showSurgeControlDialog,
                onToggleFullscreen: () => setState(() => _isFullscreen = !_isFullscreen),
                restaurantName: _restaurantName,
                cashierName: _ownerName,
                terminalId: _terminalId,
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (_selectedIndex != MadarNav.home)
                            _buildSidebar(context),
                          Expanded(
                            child: Column(
                              children: [
                                _buildTopBar(context),
                                Expanded(
                                  child: _buildCurrentPage(context),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildSystemFooterBar(context),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context) {
    if (MadarResponsive.isTabletPortrait(context)) {
      return const SizedBox.shrink();
    }

    final isCompact = MadarResponsive.isTabletLandscape(context) || _isSidebarCollapsed;
    final sidebarWidth = isCompact ? 76.0 : 252.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      width: sidebarWidth,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F1218), Color(0xFF090B0E)],
        ),
        border: Border(left: BorderSide(color: Color(0xFF1E2430), width: 1)),
      ),
      child: _buildSidebarContent(context, isCompact: isCompact, isDrawer: false),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0F1218),
      elevation: 20,
      width: 280,
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F1218), Color(0xFF090B0E)],
            ),
          ),
          child: _buildSidebarContent(context, isCompact: false, isDrawer: true),
        ),
      ),
    );
  }

  Widget _buildSidebarContent(
    BuildContext context, {
    required bool isCompact,
    bool isDrawer = false,
  }) {
    final isEn = PosLanguageController.instance.isEnglish;

    return Column(
      children: [
        _buildBrandHeader(context, isCompact: isCompact, isDrawer: isDrawer),
        const Divider(color: Color(0xFF1A202C), height: 1),
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(
              vertical: 8,
              horizontal: isCompact ? 8 : 10,
            ),
            children: [
              _buildNavSectionHeader(isEn ? 'DIRECT OPERATIONS' : 'العمليات المباشرة', Icons.bolt_rounded, isCompact: isCompact),
              _buildNavItem(index: MadarNav.home, icon: Icons.dashboard_rounded, label: isEn ? 'Dashboard' : 'الرئيسية', isCompact: isCompact, isDrawer: isDrawer),
              _buildNavItem(index: MadarNav.orders, icon: Icons.receipt_long_rounded, label: isEn ? 'Active Orders' : 'الطلبات المباشرة', badgeText: _pendingOrdersCount > 0 ? '$_pendingOrdersCount' : null, isCompact: isCompact, isDrawer: isDrawer),
              _buildNavItem(index: MadarNav.kds, icon: Icons.soup_kitchen_rounded, label: isEn ? 'Kitchen (KDS)' : 'شاشة المطبخ (KDS)', isCompact: isCompact, isDrawer: isDrawer),
              _buildNavItem(index: MadarNav.pos, icon: Icons.point_of_sale_rounded, label: isEn ? 'Cashier POS' : 'نقطة البيع (POS)', isCompact: isCompact, isDrawer: isDrawer),

              _buildNavSectionHeader(isEn ? 'DINING & MENU' : 'القاعة والمنيو', Icons.restaurant_rounded, isCompact: isCompact),
              _buildNavItem(index: MadarNav.menu, icon: Icons.restaurant_menu_rounded, label: isEn ? 'Menu Catalog' : 'إدارة المنيو', isCompact: isCompact, isDrawer: isDrawer),
              _buildNavItem(index: MadarNav.tables, icon: Icons.table_restaurant_rounded, label: isEn ? 'Tables & Hall' : 'إدارة الطاولات', isCompact: isCompact, isDrawer: isDrawer),
              _buildNavItem(index: MadarNav.reservations, icon: Icons.event_seat_rounded, label: isEn ? 'Reservations' : 'الحجوزات المسبقة', isCompact: isCompact, isDrawer: isDrawer),


              _buildNavSectionHeader(isEn ? 'CUSTOMERS & TEAM' : 'العملاء والتسوق', Icons.groups_rounded, isCompact: isCompact),
              _buildNavItem(index: MadarNav.customers, icon: Icons.people_alt_rounded, label: isEn ? 'Customer Database' : 'قاعدة العملاء', isCompact: isCompact, isDrawer: isDrawer),
              _buildNavItem(index: MadarNav.employees, icon: Icons.badge_rounded, label: isEn ? 'Staff & Attendance' : 'فريق العمل والدوام', isCompact: isCompact, isDrawer: isDrawer),
              _buildNavItem(index: MadarNav.delivery, icon: Icons.two_wheeler_rounded, label: isEn ? 'Delivery Fleet' : 'مناطق التوصيل والمناديب', isCompact: isCompact, isDrawer: isDrawer),
              _buildNavItem(index: MadarNav.coupons, icon: Icons.local_offer_rounded, label: isEn ? 'Coupons & Deals' : 'العروض والكوبونات', isCompact: isCompact, isDrawer: isDrawer),

              _buildNavSectionHeader(isEn ? 'REPORTS & SYSTEM' : 'التقارير والنظام', Icons.pie_chart_rounded, isCompact: isCompact),
              _buildNavItem(index: MadarNav.reports, icon: Icons.analytics_rounded, label: isEn ? 'Reports & Analytics' : 'التقارير والتحليلات', isCompact: isCompact, isDrawer: isDrawer),
              _buildNavItem(index: MadarNav.notifications, icon: Icons.notifications_rounded, label: isEn ? 'Notifications Center' : 'مركز الإشعارات', isCompact: isCompact, isDrawer: isDrawer),
              _buildNavItem(index: MadarNav.settings, icon: Icons.settings_rounded, label: isEn ? 'System Settings' : 'إعدادات النظام', isCompact: isCompact, isDrawer: isDrawer),
              const SizedBox(height: 12),
            ],
          ),
        ),
        const Divider(color: Color(0xFF1A202C), height: 1),
        _buildRestaurantBottomCard(context, isCompact: isCompact),
      ],
    );
  }

  Widget _buildNavSectionHeader(String title, IconData icon, {required bool isCompact}) {
    if (isCompact) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Divider(color: Color(0xFF1E2430), height: 1),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6, right: 10, left: 10),
      child: Row(
        children: [
          Icon(icon, size: 12, color: const Color(0xFF5A6679)),
          const SizedBox(width: 6),
          Text(
            title,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B788E),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFF1E2430),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(BuildContext context, {required bool isCompact, bool isDrawer = false}) {
    final isEn = PosLanguageController.instance.isEnglish;

    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: InkWell(
          onTap: () => setState(() => _isSidebarCollapsed = false),
          borderRadius: BorderRadius.circular(12),
          child: Tooltip(
            message: isEn ? 'Expand sidebar' : 'توسيع القائمة الجانبية',
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B1A), Color(0xFFFF853E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B1A).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.restaurant_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B1A), Color(0xFFFF853E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B1A).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.restaurant_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      isEn ? 'MADAR SYSTEM' : 'مدار للمطاعم',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: isEn ? 13.0 : 14.5,
                        letterSpacing: isEn ? 0.3 : -0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'PRO',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: const Color(0xFF10B981),
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'MADAR OS ENTERPRISE',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: const Color(0xFF6B788E),
                    fontWeight: FontWeight.w700,
                    fontSize: 8.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if (isDrawer)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Color(0xFF6B788E), size: 20),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: isEn ? 'Close' : 'إغلاق',
            )
          else
            IconButton(
              icon: const Icon(
                Icons.menu_open_rounded,
                color: Color(0xFF6B788E),
                size: 19,
              ),
              tooltip: isEn ? 'Collapse sidebar' : 'طي القائمة الجانبية',
              splashRadius: 18,
              onPressed: () => setState(() => _isSidebarCollapsed = true),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    String? badgeText,
    required bool isCompact,
    bool isDrawer = false,
  }) {
    final isSelected = _selectedIndex == index;

    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Tooltip(
          message: badgeText != null ? '$label ($badgeText)' : label,
          preferBelow: false,
          child: InkWell(
            onTap: () {
              _switchTo(index);
              if (isDrawer) Navigator.of(context).pop();
            },
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF6B1A)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF6B1A).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? Colors.white : const Color(0xFF8B95A5),
                    size: 20,
                  ),
                  if (badgeText != null)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF0F1218), width: 1.5),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: InkWell(
        onTap: () {
          _switchTo(index);
          if (isDrawer) Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(12),
        hoverColor: const Color(0xFF161B24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      const Color(0xFFFF6B1A).withValues(alpha: 0.16),
                      const Color(0xFFFF6B1A).withValues(alpha: 0.04),
                    ],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? const Border(
                    right: BorderSide(color: Color(0xFFFF6B1A), width: 3.5),
                  )
                : const Border(
                    right: BorderSide(color: Colors.transparent, width: 3.5),
                  ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFFFF6B1A) : const Color(0xFF78859B),
                size: 19,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: isSelected ? Colors.white : const Color(0xFFB0BAC9),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantBottomCard(BuildContext context, {required bool isCompact}) {
    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Tooltip(
              message: '$_restaurantName (${_isOpen ? "مفتوح" : "مغلق"})',
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2430),
                        border: Border.all(color: const Color(0xFF2C3545)),
                      ),
                      child: _logoUrl != null && _logoUrl!.isNotEmpty
                          ? Image.network(
                              _logoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.storefront_rounded,
                                color: Color(0xFFFF6B1A),
                                size: 20,
                              ),
                            )
                          : const Icon(Icons.storefront_rounded, color: Color(0xFFFF6B1A), size: 20),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0F1218), width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Tooltip(
              message: 'معاينة المتجر المباشر',
              child: IconButton(
                icon: const Icon(Icons.open_in_new_rounded, size: 17, color: Color(0xFFFF6B1A)),
                onPressed: _openStorePreview,
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ),
            const SizedBox(height: 8),
            const MadeInIraqBadge(isCompact: true),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF141822),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF222938)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2430),
                      border: Border.all(color: const Color(0xFF2C3545)),
                    ),
                    child: _logoUrl != null && _logoUrl!.isNotEmpty
                        ? Image.network(
                            _logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.storefront_rounded,
                              color: Color(0xFFFF6B1A),
                              size: 20,
                            ),
                          )
                        : const Icon(Icons.storefront_rounded, color: Color(0xFFFF6B1A), size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _restaurantName,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6.5,
                            height: 6.5,
                            decoration: BoxDecoration(
                              color: _isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _isOpen ? 'مستقبل للطلبات' : 'مغلق حالياً',
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: _isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // زر معاينة المتجر
            InkWell(
              onTap: _openStorePreview,
              borderRadius: BorderRadius.circular(9),
              mouseCursor: SystemMouseCursors.click,
              hoverColor: const Color(0xFFFF6B1A).withValues(alpha: 0.15),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: const Color(0xFF1B212D),
                  border: Border.all(color: const Color(0xFF2C3548)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.store_mall_directory_rounded, size: 14, color: Color(0xFFFF6B1A)),
                    const SizedBox(width: 6),
                    Text(
                      'معاينة متجر مدار',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: MadeInIraqBadge(isCompact: false),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── الشريط العلوي الموحد (Top Navigation Bar) ───────────────────────────

  Widget _buildTopBar(BuildContext context) {
    final c = context.posColors;
    final isEn = PosLanguageController.instance.isEnglish;

    final dateFormatted = DateFormat('d MMMM yyyy', isEn ? 'en' : 'ar').format(_currentTime);
    final timeFormatted = DateFormat('hh:mm a').format(_currentTime);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 850;
        final isVeryCompact = constraints.maxWidth < 650;

        return Container(
          height: 60,
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 16),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(bottom: BorderSide(color: c.border, width: 1)),
          ),
          child: Row(
            children: [
              // زر العودة للشاشة الرئيسية المربعة عند فتح أي قسم
              if (_selectedIndex != MadarNav.home) ...[
                InkWell(
                  onTap: () => _switchTo(MadarNav.home),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5B22).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFF5B22).withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isEn ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded, size: 15, color: const Color(0xFFFF5B22)),
                        const SizedBox(width: 5),
                        const Icon(Icons.grid_view_rounded, size: 15, color: Color(0xFFFF5B22)),
                        const SizedBox(width: 5),
                        Text(
                          isEn ? 'Home' : 'الرئيسية',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: const Color(0xFFFF5B22),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ] else ...[
                // شعار مدار وهوية المطعم في الشاشة الرئيسية
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5B22).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFF5B22).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFFFF5B22)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _restaurantName,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: const Color(0xFFFF5B22),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // شريط البحث العالمي مع اختصار Ctrl + K
              if (!isVeryCompact)
                Flexible(
                  child: InkWell(
                    onTap: () => PosCommandPalette.show(
                      context,
                      onNavigate: _switchTo,
                      onOpenStore: _openStorePreview,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      constraints: BoxConstraints(maxWidth: isCompact ? 140 : 200, minWidth: 70),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_rounded, size: 15, color: c.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              isEn ? 'Search...' : 'بحث...',
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: c.textMuted,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isCompact) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: c.border),
                              ),
                              child: Text(
                                'Ctrl+K',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

              if (!isVeryCompact) const SizedBox(width: 8),

              // مؤشر وزر حالة المطعم الحي وتطبيق مدار
              _buildStoreStatusPill(c),

              // مؤشر وضع عدم الاتصال (أوفلاين)
              _buildOfflineStatusBadge(c),

              // شريط تنبيه نداءات الطاولة الحية
              if (_activeTableCalls.isNotEmpty) ...[
                const SizedBox(width: 6),
                _buildActiveTableCallsBanner(c),
              ],

              const Spacer(),

              // زر اختصارات لوحة المفاتيح السريعة (F1)
              Tooltip(
                message: isEn ? 'Keyboard Shortcuts (F1)' : 'اختصارات النظام ولوحة المفاتيح (F1)',
                child: InkWell(
                  onTap: () => MadarShortcutsScope.showShortcutsGuide(
                    context,
                    onNavigate: _switchTo,
                    onOpenStore: _openStorePreview,
                    onOpenSurgeControl: _showSurgeControlDialog,
                    onToggleFullscreen: () => setState(() => _isFullscreen = !_isFullscreen),
                    restaurantName: _restaurantName,
                    cashierName: _ownerName,
                    terminalId: _terminalId,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.keyboard_rounded, size: 14, color: Color(0xFFFF5B22)),
                        const SizedBox(width: 4),
                        Text(
                          'F1',
                          style: GoogleFonts.firaCode(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFF5B22),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // زر قفل وتأمين المحطة السريع (F12)
              Tooltip(
                message: isEn ? 'Lock Terminal (F12)' : 'قفل وتأمين المحطة (F12)',
                child: InkWell(
                  onTap: () => MadarShortcutsScope.lockTerminal(
                    context,
                    restaurantName: _restaurantName,
                    cashierName: _ownerName,
                    terminalId: _terminalId,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                        const SizedBox(width: 4),
                        Text(
                          'F12',
                          style: GoogleFonts.firaCode(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // زر التبديل السريع للغة (EN / عربي)
              Tooltip(
                message: isEn ? 'Switch to Arabic' : 'التحويل إلى الإنجليزية',
                child: InkWell(
                  onTap: () => PosLanguageController.instance.toggle(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.language_rounded, size: 14, color: Color(0xFFFF5B22)),
                        const SizedBox(width: 4),
                        Text(
                          isEn ? 'EN' : 'عربي',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFFF5B22),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // زر ملء الشاشة
              IconButton(
                icon: Icon(
                  _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  color: c.textMuted,
                  size: 19,
                ),
                onPressed: () {
                  setState(() => _isFullscreen = !_isFullscreen);
                },
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 2),

              // جرس الإشعارات مع البادج
              Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_none_rounded, color: c.textMuted, size: 19),
                    onPressed: () => _switchTo(MadarNav.notifications),
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  if (_pendingOrdersCount > 0)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$_pendingOrdersCount',
                            style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),

              // ملف مدير النظام الشخصي (صاحب المطعم)
              Tooltip(
                message: isEn ? 'Click to edit owner profile' : 'اضغط لتعديل اسم المدير وصاحب المطعم',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showOwnerProfileDialog,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: c.primary.withValues(alpha: 0.15),
                            child: const Icon(Icons.person_rounded, size: 16, color: Color(0xFFFF5B22)),
                          ),
                          if (!isVeryCompact) ...[
                            const SizedBox(width: 6),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _ownerName,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                    color: c.textPrimary,
                                  ),
                                ),
                                if (!isCompact)
                                  Text(
                                    isEn ? 'System Admin' : 'مدير النظام',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 9.5,
                                      color: c.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: c.textMuted),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // شريحة الوقت والتاريخ الحية
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_rounded, size: 12, color: c.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      timeFormatted,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    if (!isCompact) ...[
                      const SizedBox(width: 4),
                      Text(
                        '| $dateFormatted',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 10,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStoreStatusPill(PosColors c) {
    final isEn = PosLanguageController.instance.isEnglish;
    Color pillColor;
    String statusLabel;
    IconData statusIcon;

    if (!_isOpen || _surgeStatus == 'paused') {
      pillColor = const Color(0xFFEF4444);
      statusLabel = isEn ? 'Paused' : 'متوقف مؤقتاً';
      statusIcon = Icons.pause_circle_filled_rounded;
    } else if (_surgeStatus == 'busy') {
      pillColor = const Color(0xFFF59E0B);
      statusLabel = isEn ? 'Rush ($_prepTimeMinutes m)' : 'ذروة وضغط ($_prepTimeMinutes د)';
      statusIcon = Icons.electric_bolt_rounded;
    } else {
      pillColor = const Color(0xFF10B981);
      statusLabel = isEn ? 'Ready ($_prepTimeMinutes m)' : 'مستعد للطلبات ($_prepTimeMinutes د)';
      statusIcon = Icons.check_circle_rounded;
    }

    return InkWell(
      onTap: _showSurgeControlDialog,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: pillColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: pillColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: pillColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Icon(statusIcon, size: 14, color: pillColor),
            const SizedBox(width: 5),
            Text(
              statusLabel,
              style: GoogleFonts.ibmPlexSansArabic(
                color: pillColor,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: 16, color: pillColor),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineStatusBadge(PosColors c) {
    final isOffline = OfflineAuthService.instance.isOfflineSession || FirebaseAuth.instance.currentUser == null;
    if (!isOffline) return const SizedBox.shrink();
    final isEn = PosLanguageController.instance.isEnglish;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 14, color: Color(0xFFF59E0B)),
          const SizedBox(width: 5),
          Text(
            isEn ? 'Offline Mode' : 'وضع أوفلاين (بدون إنترنت)',
            style: GoogleFonts.ibmPlexSansArabic(
              color: const Color(0xFFF59E0B),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTableCallsBanner(PosColors c) {
    final firstCall = _activeTableCalls.first;
    final tableNum = firstCall['tableNumber'] ?? '?';
    final isBill = firstCall['type'] == 'request_bill';
    final callId = firstCall['callId']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isBill ? Icons.receipt_long_rounded : Icons.notifications_active_rounded, color: const Color(0xFFEF4444), size: 15),
          const SizedBox(width: 6),
          Text(
            isBill ? 'طاولة $tableNum تطلب الحساب 🧾' : 'طاولة $tableNum تطلب الويتر 🛎️',
            style: GoogleFonts.ibmPlexSansArabic(
              color: const Color(0xFFEF4444),
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid ?? _uid;
              if (uid.isNotEmpty && callId.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('merchants')
                    .doc(uid)
                    .collection('table_calls')
                    .doc(callId)
                    .update({'status': 'completed'});
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'تمت التلبية ✓',
                style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── شريط النظام السفلي ───────────────────────────

  Widget _buildSystemFooterBar(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1050;
        final isVeryCompact = constraints.maxWidth < 850;

        return Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: Color(0xFF15181F),
            border: Border(top: BorderSide(color: Color(0xFF262B36), width: 1)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              children: [
                const Icon(Icons.soup_kitchen_rounded, size: 16, color: Color(0xFFFF5B22)),
                const SizedBox(width: 8),
                Text(
                  'MADAR',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                if (!isCompact) ...[
                  const SizedBox(width: 6),
                  Text(
                    'Restaurants Management System',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: const Color(0xFF8B95A5),
                      fontSize: 10,
                    ),
                  ),
                ],
                const SizedBox(width: 24),
                if (!isVeryCompact) ...[
                  Text(
                    'كل ما يحتاجه مطعمك .. في مكان واحد',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: const Color(0xFF8B95A5),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
                Text(
                  'v2.0.0 • المحطة: $_terminalId',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: const Color(0xFF8B95A5),
                    fontSize: 10.5,
                  ),
                ),
              const SizedBox(width: 12),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'متصل',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: const Color(0xFF10B981),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 14),
              const MadeInIraqBadge(isCompact: false),
            ],
          ),
        ),
      );
    },
    );
  }

  // ─────────────────────────── توجيه الصفحات ───────────────────────────

  Widget _buildCurrentPage(BuildContext context) {
    switch (_selectedIndex) {
      case MadarNav.home:
        return PosHomePage(onNavigate: _switchTo);
      case MadarNav.orders:
        return OrdersManagementPage(onNavigate: _switchTo);
      case MadarNav.kds:
        return const LiveOrdersPage();
      case MadarNav.pos:
        return const PosMainPage();
      case MadarNav.menu:
        return const MenuPage();
      case MadarNav.modifiers:
        return const ModifiersPage();
      case MadarNav.categories:
        return const CategoriesPage();
      case MadarNav.tables:
        return const TablesManagementPage();
      case MadarNav.reservations:
        return const ReservationsPage();
      case MadarNav.customers:
        return CustomersPage(onNavigate: _switchTo);
      case MadarNav.inventory:
        return const InventoryPage();
      case MadarNav.purchases:
        return const PurchasesPage();
      case MadarNav.suppliers:
        return const SuppliersPage();
      case MadarNav.expenses:
        return const ExpensesPage();
      case MadarNav.employees:
        return const EmployeesPage();
      case MadarNav.shifts:
        return PosHomePage(onNavigate: _switchTo);
      case MadarNav.reports:
        return const RestaurantAnalyticsPage();
      case MadarNav.coupons:
        return const CouponsPage();
      case MadarNav.delivery:
        return const DeliveryZonesPage();
      case MadarNav.notifications:
        return NotificationsCenterPage(onNavigate: _switchTo);
      case MadarNav.settings:
        return const SettingsPage();
      default:
        return PosHomePage(onNavigate: _switchTo);
    }
  }
}