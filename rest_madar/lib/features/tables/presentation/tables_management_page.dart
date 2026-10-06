import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/pos_language_controller.dart';
import '../../../../core/widgets/pos_page_header.dart';
import '../../../../core/error/madar_crash_guard.dart';
import '../../pos/application/pos_provider.dart';
import 'pages/table_digital_menu_page.dart';
import 'widgets/table_qr_dialog.dart';

/// شكل الطاولة الهندسي
enum TableShape {
  square,    // طاولة مربعة
  round,     // طاولة دائرية
  rectangle, // طاولة مستطيلة
}

/// الحالات التشغيلية الخمس للطاولة
enum TableStatus {
  available,    // شاغرة وجاهزة
  occupied,     // مشغولة بزبائن
  reserved,     // محجوزة مسبقاً
  cleaning,     // تحت التنظيف والتجهيز
  outOfService, // معطلة أو صيانة
}

/// أنماط العرض والتنسيق
enum TablesViewMode {
  floorGrid, // شبكة الصالة البصرية
  byZone,    // مقسمة حسب الصالات والمناطق
  compact,   // جدول الصالة السريع
}

/// نموذج الطاولة الذكي المتكامل لمنظومة مدار
class RestaurantTable {
  final String id;
  final String tableNumber;
  final String name;
  final String section;
  final int capacity;
  final TableShape shape;
  final TableStatus status;
  final String? customerName;
  final String? customerPhone;
  final DateTime? seatedAt;
  final DateTime? reservedAt;
  final double currentBill;
  final String? currentOrderId;
  final String? waiterName;
  final String notes;

  const RestaurantTable({
    required this.id,
    required this.tableNumber,
    this.name = '',
    this.section = 'الصالة الرئيسية',
    this.capacity = 4,
    this.shape = TableShape.square,
    this.status = TableStatus.available,
    this.customerName,
    this.customerPhone,
    this.seatedAt,
    this.reservedAt,
    this.currentBill = 0.0,
    this.currentOrderId,
    this.waiterName,
    this.notes = '',
  });

  factory RestaurantTable.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    final tNum = (d['tableNumber'] ?? doc.id).toString();

    // تحليل الحالة
    TableStatus st = TableStatus.available;
    final stStr = (d['status'] ?? 'available').toString();
    switch (stStr) {
      case 'occupied':
        st = TableStatus.occupied;
        break;
      case 'reserved':
        st = TableStatus.reserved;
        break;
      case 'cleaning':
      case 'dirty':
        st = TableStatus.cleaning;
        break;
      case 'outOfService':
      case 'maintenance':
        st = TableStatus.outOfService;
        break;
      default:
        st = TableStatus.available;
    }

    // تحليل الشكل
    TableShape sh = TableShape.square;
    final shStr = (d['shape'] ?? 'square').toString();
    switch (shStr) {
      case 'round':
      case 'circle':
        sh = TableShape.round;
        break;
      case 'rectangle':
        sh = TableShape.rectangle;
        break;
      default:
        sh = TableShape.square;
    }

    DateTime? sTime;
    if (d['seatedAt'] is Timestamp) {
      sTime = (d['seatedAt'] as Timestamp).toDate();
    }
    DateTime? rTime;
    if (d['reservedAt'] is Timestamp) {
      rTime = (d['reservedAt'] as Timestamp).toDate();
    }

    return RestaurantTable(
      id: doc.id,
      tableNumber: tNum,
      name: d['name'] ?? 'طاولة $tNum',
      section: d['section'] ?? d['zone'] ?? 'الصالة الرئيسية',
      capacity: (d['capacity'] ?? 4) as int,
      shape: sh,
      status: st,
      customerName: d['customerName'],
      customerPhone: d['customerPhone'],
      seatedAt: sTime,
      reservedAt: rTime,
      currentBill: (d['currentBill'] ?? 0.0).toDouble(),
      currentOrderId: d['currentOrderId'],
      waiterName: d['waiterName'],
      notes: d['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    String stStr = 'available';
    switch (status) {
      case TableStatus.occupied:
        stStr = 'occupied';
        break;
      case TableStatus.reserved:
        stStr = 'reserved';
        break;
      case TableStatus.cleaning:
        stStr = 'cleaning';
        break;
      case TableStatus.outOfService:
        stStr = 'outOfService';
        break;
      case TableStatus.available:
        stStr = 'available';
        break;
    }

    String shStr = 'square';
    switch (shape) {
      case TableShape.round:
        shStr = 'round';
        break;
      case TableShape.rectangle:
        shStr = 'rectangle';
        break;
      case TableShape.square:
        shStr = 'square';
        break;
    }

    return {
      'tableNumber': tableNumber,
      'name': name,
      'section': section,
      'capacity': capacity,
      'shape': shStr,
      'status': stStr,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'seatedAt': seatedAt != null ? Timestamp.fromDate(seatedAt!) : null,
      'reservedAt': reservedAt != null ? Timestamp.fromDate(reservedAt!) : null,
      'currentBill': currentBill,
      'currentOrderId': currentOrderId,
      'waiterName': waiterName,
      'notes': notes,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  RestaurantTable copyWith({
    String? id,
    String? tableNumber,
    String? name,
    String? section,
    int? capacity,
    TableShape? shape,
    TableStatus? status,
    String? customerName,
    String? customerPhone,
    DateTime? seatedAt,
    DateTime? reservedAt,
    double? currentBill,
    String? currentOrderId,
    String? waiterName,
    String? notes,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      tableNumber: tableNumber ?? this.tableNumber,
      name: name ?? this.name,
      section: section ?? this.section,
      capacity: capacity ?? this.capacity,
      shape: shape ?? this.shape,
      status: status ?? this.status,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      seatedAt: seatedAt ?? this.seatedAt,
      reservedAt: reservedAt ?? this.reservedAt,
      currentBill: currentBill ?? this.currentBill,
      currentOrderId: currentOrderId ?? this.currentOrderId,
      waiterName: waiterName ?? this.waiterName,
      notes: notes ?? this.notes,
    );
  }
}

/// شاشة إدارة الطاولات والصالة الذكية مع توليد رموز QR ومخطط تفاعلي مباشر
class TablesManagementPage extends StatefulWidget {
  const TablesManagementPage({super.key});

  @override
  State<TablesManagementPage> createState() => _TablesManagementPageState();
}

class _TablesManagementPageState extends State<TablesManagementPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _restaurantName = 'مطعم مدار';
  int _legacyTableCount = 12;

  // الفلاتر ونمط العرض
  String _selectedSection = 'الكل';
  String _statusFilter = 'all'; // 'all', 'available', 'occupied', 'reserved', 'cleaning'
  String _searchQuery = '';
  TablesViewMode _viewMode = TablesViewMode.floorGrid;

  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();
    _loadPersistedData();
    // تحديث المؤقتات الحية كل دقيقة
    _tickerTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localCount = prefs.getInt('pos_tables_count');
      if (localCount != null && localCount > 0 && mounted) {
        setState(() => _legacyTableCount = localCount);
      }
    } catch (_) {}

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        setState(() {
          _restaurantName = data?['restaurantName'] ?? data?['fullName'] ?? 'مطعم مدار';
          if (data?['tablesCount'] != null) {
            _legacyTableCount = (data!['tablesCount'] as num).toInt();
          }
        });
      }
    } catch (e) {
      debugPrint('[TablesManagement] load data failed: $e');
    }
  }

  CollectionReference _tablesRef() {
    return FirebaseFirestore.instance
        .collection('restaurants')
        .doc(_uid)
        .collection('tables');
  }

  // ─────────────────────────── واجهة المستخدم الرئيسية ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;

    return ListenableBuilder(
      listenable: PosLanguageController.instance,
      builder: (context, _) {
        final isEn = PosLanguageController.instance.isEnglish;

        return Directionality(
          textDirection: PosLanguageController.instance.textDirection,
          child: Scaffold(
            backgroundColor: c.background,
            body: SafeCrashBoundary(
              child: StreamBuilder<QuerySnapshot>(
                stream: _uid.isEmpty ? null : _tablesRef().snapshots(),
                builder: (context, snapshot) {
                  final List<RestaurantTable> allTables = [];

                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    for (var doc in snapshot.data!.docs) {
                      allTables.add(RestaurantTable.fromFirestore(doc));
                    }
                  } else {
                    // توليد طاولات افتراضية إذا كانت المجموعة فارغة لأول مرة
                    for (int i = 1; i <= _legacyTableCount; i++) {
                      allTables.add(
                        RestaurantTable(
                          id: '$i',
                          tableNumber: '$i',
                          name: 'طاولة $i',
                          section: i <= 8 ? 'الصالة الرئيسية' : 'التراس الخارجي',
                          capacity: (i % 3 == 0) ? 6 : (i % 2 == 0 ? 2 : 4),
                          shape: (i % 3 == 0)
                              ? TableShape.rectangle
                              : (i % 2 == 0 ? TableShape.round : TableShape.square),
                          status: TableStatus.available,
                        ),
                      );
                    }
                  }

                  // ترتيب الطاولات رقمياً
                  allTables.sort((a, b) {
                    final numA = int.tryParse(a.tableNumber) ?? 999;
                    final numB = int.tryParse(b.tableNumber) ?? 999;
                    if (numA != numB) return numA.compareTo(numB);
                    return a.tableNumber.compareTo(b.tableNumber);
                  });

                  // استخراج كافة المناطق المسجلة
                  final Set<String> sections = {'الكل'};
                  for (var t in allTables) {
                    if (t.section.trim().isNotEmpty) {
                      sections.add(t.section.trim());
                    }
                  }

                  // الحسابات والإحصائيات اللحظية
                  final totalTables = allTables.length;
                  final totalSeats = allTables.fold<int>(0, (total, t) => total + t.capacity);
                  final availableTables = allTables.where((t) => t.status == TableStatus.available).length;
                  final occupiedTables = allTables.where((t) => t.status == TableStatus.occupied).length;
                  final reservedTables = allTables.where((t) => t.status == TableStatus.reserved).length;
                  final cleaningTables = allTables.where((t) => t.status == TableStatus.cleaning).length;
                  final activeRevenue = allTables
                      .where((t) => t.status == TableStatus.occupied)
                      .fold<double>(0.0, (total, t) => total + t.currentBill);

                  final occupancyRate = totalTables > 0 ? (occupiedTables / totalTables * 100).round() : 0;

                  // تصفية الطاولات
                  final filteredTables = allTables.where((t) {
                    final matchSection = _selectedSection == 'الكل' || t.section == _selectedSection;

                    bool matchStatus = true;
                    if (_statusFilter == 'available') {
                      matchStatus = t.status == TableStatus.available;
                    } else if (_statusFilter == 'occupied') {
                      matchStatus = t.status == TableStatus.occupied;
                    } else if (_statusFilter == 'reserved') {
                      matchStatus = t.status == TableStatus.reserved;
                    } else if (_statusFilter == 'cleaning') {
                      matchStatus = t.status == TableStatus.cleaning;
                    }

                    final q = _searchQuery.toLowerCase();
                    final matchSearch = q.isEmpty ||
                        t.tableNumber.toLowerCase().contains(q) ||
                        t.name.toLowerCase().contains(q) ||
                        t.section.toLowerCase().contains(q) ||
                        (t.waiterName ?? '').toLowerCase().contains(q) ||
                        (t.customerName ?? '').toLowerCase().contains(q);

                    return matchSection && matchStatus && matchSearch;
                  }).toList();

                  return Column(
                    children: [
                      // 1. رأس الصفحة مع أزرار الإجراءات السريعة
                      _buildHeader(context, isEn, allTables),

                      // 2. شريط مؤشرات الإشغال والأداء الحي (Hall Intelligence Bar)
                      _buildIntelligenceBar(
                        context,
                        totalTables: totalTables,
                        totalSeats: totalSeats,
                        available: availableTables,
                        occupied: occupiedTables,
                        reserved: reservedTables,
                        cleaning: cleaningTables,
                        occupancyRate: occupancyRate,
                        activeRevenue: activeRevenue,
                      ),

                      // 3. شريط تصفية الأقسام والبحث والتحكم
                      _buildFilterAndControlBar(context, sections, isEn),

                      // 4. المحتوى الرئيسي للطاولات
                      Expanded(
                        child: filteredTables.isEmpty
                            ? _buildEmptyState(context, isEn)
                            : _buildMainContent(context, filteredTables, isEn),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────── رأس الصفحة الموحد ───────────────────────────

  Widget _buildHeader(BuildContext context, bool isEn, List<RestaurantTable> allTables) {
    final c = context.posColors;

    return PosPageHeader(
      icon: Icons.table_restaurant_rounded,
      title: isEn ? 'Smart Tables & Hall Management' : 'إدارة الصالة والطاولات الذكية',
      subtitle: isEn
          ? 'Live floor map, occupancy monitoring, smart QR codes & fast POS billing'
          : 'مخطط الصالة المباشر، مراقبة الإشغال، رموز المنيو الذكي QR والربط المباشر مع الكاشير',
      actions: [
        // زر التوليد السريع للطاولات
        PopupMenuButton<String>(
          tooltip: 'إدارة وتوليد الطاولات',
          onSelected: (val) {
            if (val == 'bulk_generate') {
              _showBulkGenerateDialog(context);
            } else if (val == 'reset_hall') {
              _showResetHallDialog(context, allTables);
            } else if (val == 'print_all_qr') {
              _printAllTableQrs(context, allTables);
            }
          },
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'bulk_generate',
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 19),
                  const SizedBox(width: 8),
                  Text('توليد صالة طاولات سريعة ⚡', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12.5)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'print_all_qr',
              child: Row(
                children: [
                  const Icon(Icons.print_rounded, color: Color(0xFF3B82F6), size: 19),
                  const SizedBox(width: 8),
                  Text('طباعة كافة رموز QR للصالة 🖨️', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'reset_hall',
              child: Row(
                children: [
                  const Icon(Icons.cleaning_services_rounded, color: Color(0xFFEF4444), size: 19),
                  const SizedBox(width: 8),
                  Text('تصفير الصالة وتفريغ الكل 🧹', style: GoogleFonts.ibmPlexSansArabic(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12.5)),
                ],
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.settings_suggest_rounded, color: c.textPrimary, size: 18),
                const SizedBox(width: 6),
                Text(
                  'أدوات الصالة',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
                const Icon(Icons.arrow_drop_down_rounded, size: 18),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // زر إضافة طاولة جديدة
        ElevatedButton.icon(
          onPressed: () => _showAddOrEditTableDialog(context, null),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
          label: Text(
            isEn ? 'Add Table' : 'إضافة طاولة',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12.5),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────── شريط مؤشرات الإشغال والأداء الحي ───────────────────────────

  Widget _buildIntelligenceBar(
    BuildContext context, {
    required int totalTables,
    required int totalSeats,
    required int available,
    required int occupied,
    required int reserved,
    required int cleaning,
    required int occupancyRate,
    required double activeRevenue,
  }) {
    final c = context.posColors;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // شارة نسبة الإشغال الكلية
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: occupancyRate > 75
                    ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                    : occupancyRate > 40
                        ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                        : [const Color(0xFF10B981), const Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (occupancyRate > 75
                          ? const Color(0xFFEF4444)
                          : occupancyRate > 40
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981))
                      .withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.analytics_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'نسبة الإشغال',
                      style: GoogleFonts.ibmPlexSansArabic(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$occupancyRate%',
                      style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // بطاقات الحالات التفاعلية
          Expanded(
            child: Row(
              children: [
                _buildKpiChip(
                  context,
                  title: 'شاغرة وجاهزة',
                  count: '$available',
                  subtitle: 'طاولة متاحة',
                  color: const Color(0xFF10B981),
                  isSelected: _statusFilter == 'available',
                  onTap: () => setState(() => _statusFilter = _statusFilter == 'available' ? 'all' : 'available'),
                ),
                const SizedBox(width: 8),
                _buildKpiChip(
                  context,
                  title: 'مشغولة حالياً',
                  count: '$occupied',
                  subtitle: activeRevenue > 0 ? '${activeRevenue.toInt()} د.ع' : 'نشطة بالصالة',
                  color: const Color(0xFFF59E0B),
                  isSelected: _statusFilter == 'occupied',
                  onTap: () => setState(() => _statusFilter = _statusFilter == 'occupied' ? 'all' : 'occupied'),
                ),
                const SizedBox(width: 8),
                _buildKpiChip(
                  context,
                  title: 'محجوزة مسبقاً',
                  count: '$reserved',
                  subtitle: 'حجوزات اليوم',
                  color: const Color(0xFF3B82F6),
                  isSelected: _statusFilter == 'reserved',
                  onTap: () => setState(() => _statusFilter = _statusFilter == 'reserved' ? 'all' : 'reserved'),
                ),
                const SizedBox(width: 8),
                _buildKpiChip(
                  context,
                  title: 'تحت التنظيف',
                  count: '$cleaning',
                  subtitle: 'بحاجة لتجهيز',
                  color: const Color(0xFF8B5CF6),
                  isSelected: _statusFilter == 'cleaning',
                  onTap: () => setState(() => _statusFilter = _statusFilter == 'cleaning' ? 'all' : 'cleaning'),
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // إجمالي الطاقة الاستيعابية
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Icon(Icons.chair_alt_rounded, color: c.accent, size: 18),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalTables طاولات',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.w800, color: c.textPrimary),
                    ),
                    Text(
                      '$totalSeats مقاعد متوفرة',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: c.textMuted),
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

  Widget _buildKpiChip(
    BuildContext context, {
    required String title,
    required String count,
    required String subtitle,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final c = context.posColors;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : c.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : c.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, fontWeight: FontWeight.bold, color: c.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Text(
                          count,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? color : c.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            subtitle,
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 9.5, color: c.textMuted),
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
        ),
      ),
    );
  }

  // ─────────────────────────── شريط الفلاتر والتحكم والأنماط ───────────────────────────

  Widget _buildFilterAndControlBar(BuildContext context, Set<String> sections, bool isEn) {
    final c = context.posColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Row(
        children: [
          // حقل البحث الفوري
          Container(
            width: 250,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 17, color: c.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'ابحث برقم الطاولة أو القسم...',
                      hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _searchQuery = ''),
                    child: Icon(Icons.clear_rounded, size: 16, color: c.textMuted),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // شرائح تصفية أقسام الصالة
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: sections.map((sec) {
                  final isSel = _selectedSection == sec;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(
                        sec,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                          color: isSel ? Colors.white : c.textPrimary,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: c.primary,
                      backgroundColor: c.card,
                      onSelected: (_) => setState(() => _selectedSection = sec),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: isSel ? c.primary : c.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // أزرار نمط العرض
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                _buildViewButton(
                  icon: Icons.grid_view_rounded,
                  mode: TablesViewMode.floorGrid,
                  tooltip: 'مخطط الصالة البصري',
                ),
                _buildViewButton(
                  icon: Icons.view_agenda_rounded,
                  mode: TablesViewMode.byZone,
                  tooltip: 'عرض مقسم بالصالات',
                ),
                _buildViewButton(
                  icon: Icons.table_rows_rounded,
                  mode: TablesViewMode.compact,
                  tooltip: 'جدول الصالة السريع',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewButton({
    required IconData icon,
    required TablesViewMode mode,
    required String tooltip,
  }) {
    final c = context.posColors;
    final isSel = _viewMode == mode;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() => _viewMode = mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isSel ? c.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 17,
            color: isSel ? Colors.white : c.textMuted,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── المحتوى الرئيسي بأنماطه ───────────────────────────

  Widget _buildMainContent(BuildContext context, List<RestaurantTable> tables, bool isEn) {
    switch (_viewMode) {
      case TablesViewMode.floorGrid:
        return _buildFloorGridView(context, tables, isEn);
      case TablesViewMode.byZone:
        return _buildByZoneView(context, tables, isEn);
      case TablesViewMode.compact:
        return _buildCompactTableView(context, tables, isEn);
    }
  }

  // 1. مخطط الصالة البصري (Floor Grid View)
  Widget _buildFloorGridView(BuildContext context, List<RestaurantTable> tables, bool isEn) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.15,
          ),
          itemCount: tables.length,
          itemBuilder: (context, idx) {
            final table = tables[idx];
            return _buildSmartTableCard(context, table, isEn);
          },
        );
      },
    );
  }

  // بطاقة الطاولة الذكية مع تفاصيلها ومؤقتاتها وأزرارها
  Widget _buildSmartTableCard(BuildContext context, RestaurantTable table, bool isEn) {
    final c = context.posColors;

    Color statusColor = const Color(0xFF10B981); // شاغرة
    String statusLabel = 'شاغرة';
    IconData statusIcon = Icons.check_circle_outline_rounded;

    switch (table.status) {
      case TableStatus.occupied:
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'مشغولة';
        statusIcon = Icons.restaurant_rounded;
        break;
      case TableStatus.reserved:
        statusColor = const Color(0xFF3B82F6);
        statusLabel = 'محجوزة';
        statusIcon = Icons.event_seat_rounded;
        break;
      case TableStatus.cleaning:
        statusColor = const Color(0xFF8B5CF6);
        statusLabel = 'تحت التنظيف';
        statusIcon = Icons.cleaning_services_rounded;
        break;
      case TableStatus.outOfService:
        statusColor = const Color(0xFFEF4444);
        statusLabel = 'معطلة';
        statusIcon = Icons.block_flipped;
        break;
      case TableStatus.available:
        break;
    }

    // حساب مدة الجلوس إذا كانت مشغولة
    String seatedDurationStr = '';
    bool isLongSeating = false;
    if (table.status == TableStatus.occupied && table.seatedAt != null) {
      final diff = DateTime.now().difference(table.seatedAt!);
      final mins = diff.inMinutes;
      if (mins < 60) {
        seatedDurationStr = '$mins د';
      } else {
        final hrs = diff.inHours;
        final remMins = mins % 60;
        seatedDurationStr = '$hrs س $remMins د';
      }
      isLongSeating = mins > 75; // تنبيه إذا طالت مدة الجلوس
    }

    return InkWell(
      onTap: () => _showTableDetailSheet(context, table),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.6),
            width: table.status == TableStatus.occupied ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // الشريط العلوي للطاولة
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  border: Border(bottom: BorderSide(color: c.border.withValues(alpha: 0.5))),
                ),
                child: Row(
                  children: [
                    // شارة القسم
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.background,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        table.section,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: c.textMuted,
                        ),
                      ),
                    ),

                    const Spacer(),

                    // شارة مدة الجلوس إذا مشغولة
                    if (seatedDurationStr.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isLongSeating ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, size: 11, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              seatedDurationStr,
                              style: GoogleFonts.ibmPlexSansArabic(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),

                    // شارة الحالة
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 11, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // جسم الطاولة الرئيسي والمقاعد
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      // رسم هندسي لشكل الطاولة مع المقاعد
                      _buildTableGeometry(context, table, statusColor),

                      const SizedBox(width: 12),

                      // معلومات الطاولة النصية
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              table.name,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: c.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                            Row(
                              children: [
                                Icon(Icons.people_outline_rounded, size: 14, color: c.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  '${table.capacity} مقاعد',
                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                                ),
                              ],
                            ),

                            if (table.status == TableStatus.occupied && table.currentBill > 0) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${table.currentBill.toInt()} د.ع',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ] else if (table.status == TableStatus.reserved && table.customerName != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                table.customerName!,
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ] else if (table.waiterName != null && table.waiterName!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'نادل: ${table.waiterName}',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // الشريط السفلي للأزرار السريعة
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: c.background,
                  border: Border(top: BorderSide(color: c.border.withValues(alpha: 0.5))),
                ),
                child: Row(
                  children: [
                    // زر QR السريع
                    IconButton(
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      tooltip: 'رمز QR ومنيو الطاولة',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: c.accent,
                      onPressed: () => TableQrDialog.show(context, table.tableNumber),
                    ),

                    const Spacer(),

                    // زر تغيير الحالة السريع
                    if (table.status == TableStatus.occupied)
                      TextButton.icon(
                        onPressed: () => _updateTableStatus(table, TableStatus.cleaning),
                        icon: const Icon(Icons.cleaning_services_rounded, size: 14),
                        label: Text('إخلاء وتنظيف', style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF8B5CF6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                    else if (table.status == TableStatus.cleaning)
                      TextButton.icon(
                        onPressed: () => _updateTableStatus(table, TableStatus.available),
                        icon: const Icon(Icons.check_rounded, size: 14),
                        label: Text('جاهزة الآن', style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                    else if (table.status == TableStatus.available)
                      TextButton.icon(
                        onPressed: () => _openTableInPos(context, table),
                        icon: const Icon(Icons.point_of_sale_rounded, size: 14),
                        label: Text('فتح بالكاشير ⚡', style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          foregroundColor: c.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // رسم الشكل الهندسي للطاولة ومقاعدها
  Widget _buildTableGeometry(BuildContext context, RestaurantTable table, Color color) {
    final c = context.posColors;

    return Container(
      width: 60,
      height: 60,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // رسم الطاولة
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: table.shape == TableShape.rectangle ? 50 : 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: table.shape == TableShape.round ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: table.shape == TableShape.round ? null : BorderRadius.circular(10),
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: Text(
                table.tableNumber,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ),

          // تمثيل الكراسي حول الطاولة
          if (table.capacity >= 2) ...[
            Positioned(top: 0, child: _buildChairDot(c)),
            Positioned(bottom: 0, child: _buildChairDot(c)),
          ],
          if (table.capacity >= 4) ...[
            Positioned(right: 0, child: _buildChairDot(c)),
            Positioned(left: 0, child: _buildChairDot(c)),
          ],
        ],
      ),
    );
  }

  Widget _buildChairDot(PosColors c) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: c.textMuted.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
    );
  }

  // 2. عرض الصالة مقسمة حسب المناطق (By Zone View)
  Widget _buildByZoneView(BuildContext context, List<RestaurantTable> tables, bool isEn) {
    final c = context.posColors;

    final Map<String, List<RestaurantTable>> bySection = {};
    for (var t in tables) {
      bySection.putIfAbsent(t.section, () => []).add(t);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: bySection.entries.map((entry) {
        final secName = entry.key;
        final secTables = entry.value;
        final secOccupied = secTables.where((t) => t.status == TableStatus.occupied).length;
        final secRate = secTables.isNotEmpty ? (secOccupied / secTables.length * 100).round() : 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.storefront_rounded, color: c.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    secName,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${secTables.length} طاولات • إشغال $secRate%',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: c.textMuted),
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 260,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.15,
                    ),
                    itemCount: secTables.length,
                    itemBuilder: (context, i) => _buildSmartTableCard(context, secTables[i], isEn),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // 3. عرض جدول الصالة السريع (Compact Table View)
  Widget _buildCompactTableView(BuildContext context, List<RestaurantTable> tables, bool isEn) {
    final c = context.posColors;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(2.0),
              2: FlexColumnWidth(1.8),
              3: FlexColumnWidth(1.2),
              4: FlexColumnWidth(1.4),
              5: FlexColumnWidth(1.5),
              6: FixedColumnWidth(120),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: c.background,
                  border: Border(bottom: BorderSide(color: c.border)),
                ),
                children: [
                  _buildTableHeaderCell('رقم الطاولة'),
                  _buildTableHeaderCell('اسم الطاولة'),
                  _buildTableHeaderCell('القسم / المنطقة'),
                  _buildTableHeaderCell('السعة'),
                  _buildTableHeaderCell('الحالة'),
                  _buildTableHeaderCell('الفاتورة الحالية'),
                  _buildTableHeaderCell('إجراءات'),
                ],
              ),
              ...tables.map((table) {
                Color statusColor = const Color(0xFF10B981);
                String statusLabel = 'شاغرة';
                if (table.status == TableStatus.occupied) {
                  statusColor = const Color(0xFFF59E0B);
                  statusLabel = 'مشغولة';
                } else if (table.status == TableStatus.reserved) {
                  statusColor = const Color(0xFF3B82F6);
                  statusLabel = 'محجوزة';
                } else if (table.status == TableStatus.cleaning) {
                  statusColor = const Color(0xFF8B5CF6);
                  statusLabel = 'تحت التنظيف';
                }

                return TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.border.withValues(alpha: 0.5))),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Text(
                        '#${table.tableNumber}',
                        style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w900, color: c.accent),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Text(
                        table.name,
                        style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, color: c.textPrimary),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Text(
                        table.section,
                        style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Text(
                        '${table.capacity} مقاعد',
                        style: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Text(
                        table.currentBill > 0 ? '${table.currentBill.toInt()} د.ع' : '—',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontWeight: FontWeight.bold,
                          color: table.currentBill > 0 ? const Color(0xFF10B981) : c.textMuted,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                            tooltip: 'QR ومنيو الطاولة',
                            onPressed: () => TableQrDialog.show(context, table.tableNumber),
                          ),
                          IconButton(
                            icon: Icon(Icons.more_horiz_rounded, size: 18, color: c.primary),
                            tooltip: 'تفاصيل وإجراءات',
                            onPressed: () => _showTableDetailSheet(context, table),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        title,
        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
      ),
    );
  }

  // ─────────────────────────── نافذة تفاصيل وإجراءات الطاولة الذكية ───────────────────────────

  void _showTableDetailSheet(BuildContext context, RestaurantTable table) {
    final c = context.posColors;

    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // مقبض السحب
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ترويسة الطاولة
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          '#${table.tableNumber}',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: c.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            table.name,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: c.textPrimary,
                            ),
                          ),
                          Text(
                            '${table.section} • ${table.capacity} مقاعد',
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 10),

                // تغيير الحالة السريع
                Text(
                  'تغيير حالة الطاولة:',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusSelectChip(
                        label: 'شاغرة وجاهزة',
                        color: const Color(0xFF10B981),
                        isSelected: table.status == TableStatus.available,
                        onTap: () {
                          Navigator.pop(ctx);
                          _updateTableStatus(table, TableStatus.available);
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildStatusSelectChip(
                        label: 'مشغولة',
                        color: const Color(0xFFF59E0B),
                        isSelected: table.status == TableStatus.occupied,
                        onTap: () {
                          Navigator.pop(ctx);
                          _updateTableStatus(table, TableStatus.occupied);
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildStatusSelectChip(
                        label: 'محجوزة',
                        color: const Color(0xFF3B82F6),
                        isSelected: table.status == TableStatus.reserved,
                        onTap: () {
                          Navigator.pop(ctx);
                          _showReservationDialog(context, table);
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildStatusSelectChip(
                        label: 'تحت التنظيف',
                        color: const Color(0xFF8B5CF6),
                        isSelected: table.status == TableStatus.cleaning,
                        onTap: () {
                          Navigator.pop(ctx);
                          _updateTableStatus(table, TableStatus.cleaning);
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildStatusSelectChip(
                        label: 'معطلة / صيانة',
                        color: const Color(0xFFEF4444),
                        isSelected: table.status == TableStatus.outOfService,
                        onTap: () {
                          Navigator.pop(ctx);
                          _updateTableStatus(table, TableStatus.outOfService);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // شبكة العمليات الذكية
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.point_of_sale_rounded,
                        title: 'طلب كاشير سريع ⚡',
                        color: c.primary,
                        onTap: () {
                          Navigator.pop(ctx);
                          _openTableInPos(context, table);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.sync_alt_rounded,
                        title: 'نقل الطاولة 🔄',
                        color: const Color(0xFF3B82F6),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showTransferTableDialog(context, table);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.qr_code_2_rounded,
                        title: 'رمز QR ومنيو الطاولة',
                        color: c.accent,
                        onTap: () {
                          Navigator.pop(ctx);
                          TableQrDialog.show(context, table.tableNumber);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.phone_android_rounded,
                        title: 'معاينة منيو الزبون 🍽️',
                        color: const Color(0xFF10B981),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TableDigitalMenuPage(
                                restaurantId: _uid,
                                tableNumber: table.tableNumber,
                                restaurantName: _restaurantName,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.edit_note_rounded,
                        title: 'تعديل بيانات الطاولة',
                        color: const Color(0xFF64748B),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showAddOrEditTableDialog(context, table);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.delete_outline_rounded,
                        title: 'حذف الطاولة 🗑️',
                        color: const Color(0xFFEF4444),
                        onTap: () {
                          Navigator.pop(ctx);
                          _confirmDeleteTable(context, table);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusSelectChip({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final c = context.posColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── نافذة إضافة وتعديل الطاولة ───────────────────────────

  void _showAddOrEditTableDialog(BuildContext context, RestaurantTable? existing) {
    final c = context.posColors;
    final numCtrl = TextEditingController(text: existing?.tableNumber ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final sectionCtrl = TextEditingController(text: existing?.section ?? 'الصالة الرئيسية');
    final waiterCtrl = TextEditingController(text: existing?.waiterName ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    int capacity = existing?.capacity ?? 4;
    TableShape shape = existing?.shape ?? TableShape.square;

    final defaultSections = [
      'الصالة الرئيسية',
      'التراس الخارجي',
      'قسم العوائل',
      'كبائن VIP',
      'الكافيه والمشروبات',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      existing == null ? Icons.add_business_rounded : Icons.edit_rounded,
                      color: c.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    existing == null ? 'إضافة طاولة جديدة للصالة' : 'تعديل بيانات الطاولة',
                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // رقم واسم الطاولة
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('رقم الطاولة*', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: numCtrl,
                                  keyboardType: TextInputType.text,
                                  decoration: InputDecoration(
                                    hintText: '1, 2, VIP-1',
                                    filled: true,
                                    fillColor: c.background,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    isDense: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('اسم مميز للطاولة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: nameCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'مثال: طاولة النافذة',
                                    filled: true,
                                    fillColor: c.background,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    isDense: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // اختيار القسم والمنطقة
                      Text('القسم / منطقة الصالة*', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: sectionCtrl,
                        decoration: InputDecoration(
                          hintText: 'اكتب اسم القسم أو اختر من المقترحات',
                          filled: true,
                          fillColor: c.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: defaultSections.map((sec) {
                          final isCur = sectionCtrl.text.trim() == sec;
                          return ActionChip(
                            label: Text(sec, style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, fontWeight: isCur ? FontWeight.bold : FontWeight.normal)),
                            backgroundColor: isCur ? c.primary.withValues(alpha: 0.15) : c.background,
                            side: BorderSide(color: isCur ? c.primary : c.border),
                            onPressed: () => setModalState(() => sectionCtrl.text = sec),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 14),

                      // اختيار السعة وشكل الطاولة
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('شكل الطاولة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _buildShapeOption(
                                      title: 'مربعة',
                                      icon: Icons.crop_square_rounded,
                                      isSelected: shape == TableShape.square,
                                      onTap: () => setModalState(() => shape = TableShape.square),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildShapeOption(
                                      title: 'دائرية',
                                      icon: Icons.circle_outlined,
                                      isSelected: shape == TableShape.round,
                                      onTap: () => setModalState(() => shape = TableShape.round),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildShapeOption(
                                      title: 'مستطيلة',
                                      icon: Icons.rectangle_outlined,
                                      isSelected: shape == TableShape.rectangle,
                                      onTap: () => setModalState(() => shape = TableShape.rectangle),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // عدد المقاعد
                      Text('سعة الكراسي والمقاعد', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        children: [2, 4, 6, 8, 10].map((cap) {
                          final isCur = capacity == cap;
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ActionChip(
                              label: Text('$cap مقاعد', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: isCur ? FontWeight.bold : FontWeight.normal)),
                              backgroundColor: isCur ? c.primary : c.background,
                              labelStyle: TextStyle(color: isCur ? Colors.white : c.textPrimary),
                              onPressed: () => setModalState(() => capacity = cap),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 14),

                      // النادل المسؤول وملاحظات
                      Text('اسم النادل المسند (اختياري)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: waiterCtrl,
                        decoration: InputDecoration(
                          hintText: 'مثال: أحمد، علي...',
                          filled: true,
                          fillColor: c.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final tNum = numCtrl.text.trim();
                    if (tNum.isEmpty) return;
                    final tName = nameCtrl.text.trim().isEmpty ? 'طاولة $tNum' : nameCtrl.text.trim();
                    final sec = sectionCtrl.text.trim().isEmpty ? 'الصالة الرئيسية' : sectionCtrl.text.trim();

                    final newTable = RestaurantTable(
                      id: tNum,
                      tableNumber: tNum,
                      name: tName,
                      section: sec,
                      capacity: capacity,
                      shape: shape,
                      status: existing?.status ?? TableStatus.available,
                      waiterName: waiterCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                    );

                    await _tablesRef().doc(tNum).set(newTable.toMap(), SetOptions(merge: true));

                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    existing == null ? 'إضافة الطاولة' : 'حفظ التعديلات',
                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShapeOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final c = context.posColors;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? c.primary.withValues(alpha: 0.15) : c.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? c.primary : c.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: isSelected ? c.primary : c.textMuted),
              const SizedBox(height: 2),
              Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── نافذة التوليد التلقائي السريع ───────────────────────────

  void _showBulkGenerateDialog(BuildContext context) {
    final c = context.posColors;
    final countCtrl = TextEditingController(text: '10');
    final sectionCtrl = TextEditingController(text: 'الصالة الرئيسية');
    int capacity = 4;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 24),
                  const SizedBox(width: 8),
                  Text('توليد صالة طاولات سريعة ⚡', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('حدد عدد الطاولات التي تود توليدها دفعة واحدة:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: c.textMuted)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: countCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'عدد الطاولات (مثال: 12)',
                      filled: true,
                      fillColor: c.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sectionCtrl,
                    decoration: InputDecoration(
                      labelText: 'القسم / الصالة',
                      filled: true,
                      fillColor: c.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final cnt = int.tryParse(countCtrl.text.trim()) ?? 0;
                    if (cnt <= 0 || cnt > 100) return;
                    final sec = sectionCtrl.text.trim().isEmpty ? 'الصالة الرئيسية' : sectionCtrl.text.trim();

                    final batch = FirebaseFirestore.instance.batch();
                    for (int i = 1; i <= cnt; i++) {
                      final docRef = _tablesRef().doc('$i');
                      final t = RestaurantTable(
                        id: '$i',
                        tableNumber: '$i',
                        name: 'طاولة $i',
                        section: sec,
                        capacity: capacity,
                        shape: (i % 2 == 0) ? TableShape.round : TableShape.square,
                        status: TableStatus.available,
                      );
                      batch.set(docRef, t.toMap(), SetOptions(merge: true));
                    }
                    await batch.commit();

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم توليد $cnt طاولات في $sec بنجاح! ⚡', style: GoogleFonts.ibmPlexSansArabic()),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('بدء التوليد الفوري', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────── نافذة نقل الطاولة ───────────────────────────

  void _showTransferTableDialog(BuildContext context, RestaurantTable sourceTable) async {
    final c = context.posColors;

    // استخراج الطاولات الشاغرة
    final snap = await _tablesRef().where('status', isEqualTo: 'available').get();
    final availableTables = snap.docs
        .map((d) => RestaurantTable.fromFirestore(d))
        .where((t) => t.tableNumber != sourceTable.tableNumber)
        .toList();

    if (!context.mounted) return;

    if (availableTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لا توجد طاولات شاغرة حالياً لنقل الزبون إليها!', style: GoogleFonts.ibmPlexSansArabic()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    String? selectedTargetTable = availableTables.first.tableNumber;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  const Icon(Icons.sync_alt_rounded, color: Color(0xFF3B82F6), size: 22),
                  const SizedBox(width: 8),
                  Text('نقل طاولة #${sourceTable.tableNumber}', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('اختر الطاولة البديلة لنقل الزبون والطلب إليها:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: c.textMuted)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTargetTable,
                    decoration: InputDecoration(
                      labelText: 'الطاولة الشاغرة البديلة',
                      filled: true,
                      fillColor: c.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: availableTables.map((t) {
                      return DropdownMenuItem(
                        value: t.tableNumber,
                        child: Text('${t.name} (${t.section} • ${t.capacity} مقاعد)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (v) => setModalState(() => selectedTargetTable = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedTargetTable == null) return;

                    // نقل البيانات للطاولة الجديدة وتفريغ القديمة
                    final batch = FirebaseFirestore.instance.batch();

                    // الهدف: يصبح مشغولاً ببيانات القديم
                    batch.set(
                      _tablesRef().doc(selectedTargetTable),
                      {
                        'status': 'occupied',
                        'seatedAt': sourceTable.seatedAt != null ? Timestamp.fromDate(sourceTable.seatedAt!) : FieldValue.serverTimestamp(),
                        'currentBill': sourceTable.currentBill,
                        'currentOrderId': sourceTable.currentOrderId,
                        'customerName': sourceTable.customerName,
                        'customerPhone': sourceTable.customerPhone,
                        'lastUpdated': FieldValue.serverTimestamp(),
                      },
                      SetOptions(merge: true),
                    );

                    // المصدر: يصبح تحت التنظيف
                    batch.set(
                      _tablesRef().doc(sourceTable.tableNumber),
                      {
                        'status': 'cleaning',
                        'currentBill': 0.0,
                        'currentOrderId': null,
                        'customerName': null,
                        'customerPhone': null,
                        'seatedAt': null,
                        'lastUpdated': FieldValue.serverTimestamp(),
                      },
                      SetOptions(merge: true),
                    );

                    await batch.commit();

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم نقل الطاولة #${sourceTable.tableNumber} إلى #${selectedTargetTable!} بنجاح! 🔄', style: GoogleFonts.ibmPlexSansArabic()),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
                  child: Text('تأكيد النقل', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────── نافذة حجز الطاولة ───────────────────────────

  void _showReservationDialog(BuildContext context, RestaurantTable table) {
    final c = context.posColors;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  const Icon(Icons.event_seat_rounded, color: Color(0xFF3B82F6), size: 22),
                  const SizedBox(width: 8),
                  Text('حجز طاولة #${table.tableNumber}', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'اسم صاحب الحجز*',
                      filled: true,
                      fillColor: c.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'رقم الهاتف',
                      filled: true,
                      fillColor: c.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;

                    await _tablesRef().doc(table.tableNumber).set({
                      'status': 'reserved',
                      'customerName': name,
                      'customerPhone': phoneCtrl.text.trim(),
                      'reservedAt': FieldValue.serverTimestamp(),
                      'lastUpdated': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم حجز طاولة #${table.tableNumber} باسم $name بنجاح! 📅', style: GoogleFonts.ibmPlexSansArabic()),
                          backgroundColor: const Color(0xFF3B82F6),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
                  child: Text('تأكيد الحجز', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────── تصفير الصالة وتفريغ الكل ───────────────────────────

  void _showResetHallDialog(BuildContext context, List<RestaurantTable> allTables) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('تصفير الصالة بنهاية اليوم', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
          content: Text(
            'هل أنت متأكد من رغبتك في تحويل كافة طاولات الصالة (${allTables.length} طاولة) إلى شاغرة ومتاحة؟',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic())),
            ElevatedButton(
              onPressed: () async {
                final batch = FirebaseFirestore.instance.batch();
                for (var t in allTables) {
                  batch.set(
                    _tablesRef().doc(t.tableNumber),
                    {
                      'status': 'available',
                      'currentBill': 0.0,
                      'currentOrderId': null,
                      'customerName': null,
                      'customerPhone': null,
                      'seatedAt': null,
                      'reservedAt': null,
                      'lastUpdated': FieldValue.serverTimestamp(),
                    },
                    SetOptions(merge: true),
                  );
                }
                await batch.commit();

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم تصفير الصالة وتفريغ كافة الطاولات بنجاح 🧹', style: GoogleFonts.ibmPlexSansArabic()), backgroundColor: const Color(0xFF10B981)),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              child: Text('تصفير الكل', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── طباعة مجمعة لكافة رموز QR ───────────────────────────

  void _printAllTableQrs(BuildContext context, List<RestaurantTable> tables) {
    final buffer = StringBuffer();
    for (var t in tables) {
      buffer.writeln('طاولة ${t.tableNumber} (${t.section}): https://madar-iq.web.app/menu?restaurantId=$_uid&table=${t.tableNumber}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ روابط المنيو الذكي لكافة طاولات الصالة (${tables.length} طاولة) إلى الحافظة! 📋', style: GoogleFonts.ibmPlexSansArabic()),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─────────────────────────── فتح في الكاشير ───────────────────────────

  void _openTableInPos(BuildContext context, RestaurantTable table) {
    try {
      final pos = Provider.of<PosProvider>(context, listen: false);
      pos.setSelectedTable(table.tableNumber);
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('تم تعيين طاولة #${table.tableNumber} في شاشة الكاشير للطلب المباشر! ⚡', style: GoogleFonts.ibmPlexSansArabic()),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─────────────────────────── تحديث الحالة الفردية ───────────────────────────

  Future<void> _updateTableStatus(RestaurantTable table, TableStatus newStatus) async {
    String stStr = 'available';
    switch (newStatus) {
      case TableStatus.occupied:
        stStr = 'occupied';
        break;
      case TableStatus.reserved:
        stStr = 'reserved';
        break;
      case TableStatus.cleaning:
        stStr = 'cleaning';
        break;
      case TableStatus.outOfService:
        stStr = 'outOfService';
        break;
      case TableStatus.available:
        stStr = 'available';
        break;
    }

    final updateData = <String, dynamic>{
      'status': stStr,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    if (newStatus == TableStatus.occupied && table.seatedAt == null) {
      updateData['seatedAt'] = FieldValue.serverTimestamp();
    } else if (newStatus == TableStatus.available || newStatus == TableStatus.cleaning) {
      updateData['seatedAt'] = null;
      updateData['currentBill'] = 0.0;
      updateData['currentOrderId'] = null;
      updateData['customerName'] = null;
      updateData['customerPhone'] = null;
    }

    try {
      await _tablesRef().doc(table.tableNumber).set(updateData, SetOptions(merge: true));
    } catch (_) {}
  }

  void _confirmDeleteTable(BuildContext context, RestaurantTable table) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('حذف الطاولة #${table.tableNumber}؟', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من حذف هذه الطاولة نهائياً من الصالة؟', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic())),
            ElevatedButton(
              onPressed: () async {
                await _tablesRef().doc(table.tableNumber).delete();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              child: Text('حذف', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── حالات الفراغ وعدم العثور ───────────────────────────

  Widget _buildEmptyState(BuildContext context, bool isEn) {
    final c = context.posColors;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.table_restaurant_rounded, size: 50, color: c.textDisabled),
          const SizedBox(height: 12),
          Text(
            'لا توجد طاولات تطابق معايير الفلترة أو البحث',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 15, fontWeight: FontWeight.bold, color: c.textMuted),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _selectedSection = 'الكل';
                _statusFilter = 'all';
              });
            },
            child: Text('إعادة ضبط الفلاتر', style: GoogleFonts.ibmPlexSansArabic(color: c.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}