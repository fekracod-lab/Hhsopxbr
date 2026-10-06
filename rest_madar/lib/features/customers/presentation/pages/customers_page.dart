import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/design_system/madar_design_system.dart';
import '../../../../core/responsive/madar_responsive.dart';
import '../../../../core/error/madar_crash_guard.dart';

/// نموذج بيانات العميل
class CustomerProfile {
  final String id;
  final String name;
  final String phone;
  final String address;
  final int totalOrders;
  final double totalSpend;
  final DateTime? lastOrderDate;
  final String notes;

  const CustomerProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.totalOrders = 0,
    this.totalSpend = 0.0,
    this.lastOrderDate,
    this.notes = '',
  });

  bool get isVip => totalOrders >= 5 || totalSpend >= 50000;

  int get daysSinceLastOrder {
    if (lastOrderDate == null) return 999;
    return DateTime.now().difference(lastOrderDate!).inDays;
  }

  bool get isLapsing => daysSinceLastOrder >= 14 && totalOrders >= 1;
}

/// شاشة إدارة ودليل العملاء في نظام مطاعم مدار
class CustomersPage extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const CustomersPage({super.key, this.onNavigate});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _effectiveRestaurantId = '';
  String _searchQuery = '';
  String _filterVip = 'الكل'; // 'الكل', 'VIP', 'جديد'

  @override
  void initState() {
    super.initState();
    _resolveRestaurantId();
  }

  Future<void> _resolveRestaurantId() async {
    if (_uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        final rId = (data?['restaurantId'] ?? data?['storeId'] ?? data?['branchId'] ?? data?['merchantId'])?.toString().trim() ?? '';
        if (rId.isNotEmpty && rId != _effectiveRestaurantId) {
          setState(() {
            _effectiveRestaurantId = rId;
          });
        }
      }
    } catch (_) {}
  }

  String get _activeId => _effectiveRestaurantId.isNotEmpty ? _effectiveRestaurantId : _uid;

  List<String> get _restaurantIds => [_uid, _effectiveRestaurantId]
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();

  CollectionReference _customersRef() {
    return FirebaseFirestore.instance
        .collection('merchant_customers')
        .doc(_activeId)
        .collection('customers');
  }

  Stream<QuerySnapshot>? _buildOrdersStream() {
    final ids = _restaurantIds;
    if (ids.isEmpty) return null;
    if (ids.length == 1) {
      return FirebaseFirestore.instance
          .collection('orders')
          .where('restaurantId', isEqualTo: ids.first)
          .snapshots();
    }
    return FirebaseFirestore.instance
        .collection('orders')
        .where('restaurantId', whereIn: ids)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeCrashBoundary(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildOrdersStream(),
            builder: (context, ordersSnap) {
              // تجميع العملاء من الطلبات الحية + العملاء المسجلين يدوياً
              final Map<String, CustomerProfile> customerMap = {};

              if (ordersSnap.hasData) {
                for (var doc in ordersSnap.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['customerName'] ?? data['userName'] ?? '').toString().trim();
                  final phone = (data['customerPhone'] ?? data['phone'] ?? '').toString().trim();
                  final address = (data['deliveryAddress'] ?? data['address'] ?? 'القائم').toString().trim();
                  final total = (data['total'] ?? data['totalPrice'] ?? data['totalAmount'] ?? 0).toDouble();
                  DateTime? orderDate;
                  if (data['createdAt'] is Timestamp) {
                    orderDate = (data['createdAt'] as Timestamp).toDate();
                  }

                  if (phone.isNotEmpty || name.isNotEmpty) {
                    final key = phone.isNotEmpty ? phone : name;
                    final existing = customerMap[key];
                    if (existing == null) {
                      customerMap[key] = CustomerProfile(
                        id: key,
                        name: name.isNotEmpty ? name : 'عميل غير محدد',
                        phone: phone.isNotEmpty ? phone : 'غير مسجل',
                        address: address,
                        totalOrders: 1,
                        totalSpend: total,
                        lastOrderDate: orderDate,
                      );
                    } else {
                      final newerDate = orderDate != null && (existing.lastOrderDate == null || orderDate.isAfter(existing.lastOrderDate!))
                          ? orderDate
                          : existing.lastOrderDate;
                      customerMap[key] = CustomerProfile(
                        id: key,
                        name: existing.name == 'عميل غير محدد' && name.isNotEmpty ? name : existing.name,
                        phone: existing.phone == 'غير مسجل' && phone.isNotEmpty ? phone : existing.phone,
                        address: existing.address == 'القائم' && address.isNotEmpty ? address : existing.address,
                        totalOrders: existing.totalOrders + 1,
                        totalSpend: existing.totalSpend + total,
                        lastOrderDate: newerDate,
                      );
                    }
                  }
                }
              }

              return StreamBuilder<QuerySnapshot>(
                stream: _activeId.isEmpty ? null : _customersRef().snapshots(),
                builder: (context, manualSnap) {
                  if (manualSnap.hasData) {
                    for (var doc in manualSnap.data!.docs) {
                      final d = doc.data() as Map<String, dynamic>;
                      final phone = (d['phone'] ?? '').toString().trim();
                      final name = (d['name'] ?? '').toString().trim();
                      final key = phone.isNotEmpty ? phone : doc.id;
                      final existing = customerMap[key];

                      customerMap[key] = CustomerProfile(
                        id: doc.id,
                        name: name.isNotEmpty ? name : (existing?.name ?? 'عميل'),
                        phone: phone.isNotEmpty ? phone : (existing?.phone ?? '—'),
                        address: (d['address'] ?? existing?.address ?? 'القائم').toString(),
                        totalOrders: existing?.totalOrders ?? 0,
                        totalSpend: existing?.totalSpend ?? 0.0,
                        lastOrderDate: existing?.lastOrderDate,
                        notes: (d['notes'] ?? '').toString(),
                      );
                    }
                  }

                  final allCustomers = customerMap.values.toList();
                  allCustomers.sort((a, b) => b.totalSpend.compareTo(a.totalSpend));

                  final lapsingCustomers = allCustomers.where((c) => c.isLapsing).toList();
                  final lapsingRevenue = lapsingCustomers.fold(0.0, (s, c) => s + c.totalSpend);

                  // فلترة
                  final filtered = allCustomers.where((cust) {
                    final matchesSearch = _searchQuery.isEmpty ||
                        cust.name.contains(_searchQuery) ||
                        cust.phone.contains(_searchQuery) ||
                        cust.address.contains(_searchQuery);
                    final matchesFilter = _filterVip == 'الكل' ||
                        (_filterVip == 'VIP' && cust.isVip) ||
                        (_filterVip == 'جديد' && cust.totalOrders <= 1) ||
                        (_filterVip == 'غائب' && cust.isLapsing);
                    return matchesSearch && matchesFilter;
                  }).toList();

                  final totalCount = allCustomers.length;
                  final vipCount = allCustomers.where((c) => c.isVip).length;
                  final totalRevenue = allCustomers.fold(0.0, (s, c) => s + c.totalSpend);

                  final width = MediaQuery.of(context).size.width;
                  final isNarrow = width < 800;

                  return SingleChildScrollView(
                    padding: EdgeInsets.all(MadarResponsive.contentPadding(context)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. الترويسة
                        if (isNarrow)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'دليل العملاء وسجل المشتريات',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'قاعدة بيانات العملاء المتكاملة، مجموع مشترياتهم وتفضيلات التوصيل',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 12,
                                      color: c.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (lapsingCustomers.isNotEmpty)
                                    ElevatedButton.icon(
                                      onPressed: () => _showWinBackRadarDialog(context, lapsingCustomers),
                                      icon: const Icon(Icons.radar_rounded, size: 18),
                                      label: Text(
                                        'رادار الاسترجاع (${lapsingCustomers.length}) 🎯',
                                        style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFEF4444),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ElevatedButton.icon(
                                    onPressed: () => _showAddCustomerDialog(context),
                                    icon: const Icon(Icons.person_add_rounded, size: 20),
                                    label: Text(
                                      'إضافة عميل جديد',
                                      style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: c.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'دليل العملاء وسجل المشتريات',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'قاعدة بيانات العملاء المتكاملة، مجموع مشترياتهم وتفضيلات التوصيل',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 13,
                                      color: c.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              if (lapsingCustomers.isNotEmpty) ...[
                                ElevatedButton.icon(
                                  onPressed: () => _showWinBackRadarDialog(context, lapsingCustomers),
                                  icon: const Icon(Icons.radar_rounded, size: 18),
                                  label: Text(
                                    'رادار الاسترجاع (${lapsingCustomers.length}) 🎯',
                                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              ElevatedButton.icon(
                                onPressed: () => _showAddCustomerDialog(context),
                                icon: const Icon(Icons.person_add_rounded, size: 20),
                                label: Text(
                                  'إضافة عميل جديد',
                                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: c.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 20),

                        // 2. بطاقات الإحصائيات التكيفية
                        if (width >= 1000)
                          Row(
                            children: [
                              _buildStatCard(
                                title: 'إجمالي العملاء',
                                value: '$totalCount',
                                icon: Icons.people_alt_rounded,
                                color: const Color(0xFF3B82F6),
                                bg: const Color(0xFFEFF6FF),
                              ),
                              const SizedBox(width: 14),
                              _buildStatCard(
                                title: 'عملاء مميزين (VIP)',
                                value: '$vipCount',
                                icon: Icons.star_rounded,
                                color: const Color(0xFFF59E0B),
                                bg: const Color(0xFFFFFBEB),
                              ),
                              const SizedBox(width: 14),
                              _buildStatCard(
                                title: 'غائبون (>14 يوم) 🎯',
                                value: '${lapsingCustomers.length}',
                                icon: Icons.radar_rounded,
                                color: const Color(0xFFEF4444),
                                bg: const Color(0xFFFEF2F2),
                              ),
                              const SizedBox(width: 14),
                              _buildStatCard(
                                title: 'مجموع إنفاق العملاء',
                                value: '${NumberFormat('#,###').format(totalRevenue)} د.ع',
                                icon: Icons.monetization_on_rounded,
                                color: const Color(0xFF10B981),
                                bg: const Color(0xFFECFDF5),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              Row(
                                children: [
                                  _buildStatCard(
                                    title: 'إجمالي العملاء',
                                    value: '$totalCount',
                                    icon: Icons.people_alt_rounded,
                                    color: const Color(0xFF3B82F6),
                                    bg: const Color(0xFFEFF6FF),
                                  ),
                                  const SizedBox(width: 14),
                                  _buildStatCard(
                                    title: 'عملاء مميزين (VIP)',
                                    value: '$vipCount',
                                    icon: Icons.star_rounded,
                                    color: const Color(0xFFF59E0B),
                                    bg: const Color(0xFFFFFBEB),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildStatCard(
                                    title: 'غائبون (>14 يوم) 🎯',
                                    value: '${lapsingCustomers.length}',
                                    icon: Icons.radar_rounded,
                                    color: const Color(0xFFEF4444),
                                    bg: const Color(0xFFFEF2F2),
                                  ),
                                  const SizedBox(width: 14),
                                  _buildStatCard(
                                    title: 'مجموع إنفاق العملاء',
                                    value: '${NumberFormat('#,###').format(totalRevenue)} د.ع',
                                    icon: Icons.monetization_on_rounded,
                                    color: const Color(0xFF10B981),
                                    bg: const Color(0xFFECFDF5),
                                  ),
                                ],
                              ),
                            ],
                          ),

                        if (lapsingCustomers.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildWinBackRadarBanner(context, lapsingCustomers, lapsingRevenue),
                        ],

                        const SizedBox(height: 20),

                        // 3. شريط البحث والفلترة
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: c.card,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: c.border),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.search_rounded, color: c.textMuted, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        onChanged: (v) => setState(() => _searchQuery = v.trim()),
                                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: c.textPrimary),
                                        decoration: InputDecoration(
                                          hintText: 'ابحث بالاسم، رقم الهاتف، أو الحي السكني...',
                                          hintStyle: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 12.5),
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            SegmentedButton<String>(
                              segments: [
                                const ButtonSegment(value: 'الكل', label: Text('الكل')),
                                const ButtonSegment(value: 'VIP', label: Text('⭐ VIP')),
                                const ButtonSegment(value: 'جديد', label: Text('جديد')),
                                ButtonSegment(
                                  value: 'غائب',
                                  label: Text('🎯 غائبون (${lapsingCustomers.length})'),
                                ),
                              ],
                              selected: {_filterVip},
                              onSelectionChanged: (set) => setState(() => _filterVip = set.first),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // 4. جدول العملاء
                        if (allCustomers.isEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: c.border),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: c.primary.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.people_outline_rounded, size: 48, color: c.primary),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'لا يوجد عملاء مسجلون حالياً',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'سيظهر العملاء تلقائياً بمجرد إتمام أول طلبية، أو يمكنك إضافة عميل يدوي في قاعدة البيانات.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: c.textMuted),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () => _showAddCustomerDialog(context),
                                  icon: const Icon(Icons.person_add_rounded, size: 18),
                                  label: Text(
                                    'إضافة عميل جديد',
                                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: c.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (filtered.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 60),
                              child: Column(
                                children: [
                                  Icon(Icons.person_search_rounded, size: 56, color: c.textDisabled),
                                  const SizedBox(height: 12),
                                  Text(
                                    'لا يوجد عملاء يطابقون شروط البحث أو الفلترة',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: c.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: c.border),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(2.6),
                                  1: FlexColumnWidth(1.8),
                                  2: FlexColumnWidth(2.4),
                                  3: FlexColumnWidth(1.1),
                                  4: FlexColumnWidth(1.8),
                                  5: FlexColumnWidth(1.8),
                                  6: FixedColumnWidth(180),
                                },
                                children: [
                                  // الترويسة
                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: c.background,
                                      border: Border(bottom: BorderSide(color: c.border)),
                                    ),
                                    children: [
                                      _buildHeaderCell('الاسم والصفة'),
                                      _buildHeaderCell('رقم الهاتف'),
                                      _buildHeaderCell('العنوان المعتاد'),
                                      _buildHeaderCell('الطلبات'),
                                      _buildHeaderCell('إجمالي الإنفاق'),
                                      _buildHeaderCell('آخر طلب'),
                                      _buildHeaderCell('إجراءات'),
                                    ],
                                  ),

                                  // الصفوف
                                  ...filtered.map((cust) {
                                    return TableRow(
                                      decoration: BoxDecoration(
                                        border: Border(bottom: BorderSide(color: c.border.withValues(alpha: 0.5))),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 16,
                                                backgroundColor: cust.isVip
                                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                                    : (cust.isLapsing
                                                        ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                                        : c.primary.withValues(alpha: 0.15)),
                                                child: Text(
                                                  cust.name.isNotEmpty ? cust.name[0] : 'ع',
                                                  style: GoogleFonts.ibmPlexSansArabic(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: cust.isVip
                                                        ? const Color(0xFFF59E0B)
                                                        : (cust.isLapsing
                                                            ? const Color(0xFFEF4444)
                                                            : c.primary),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      cust.name,
                                                      style: GoogleFonts.ibmPlexSansArabic(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12.5,
                                                        color: c.textPrimary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    if (cust.isVip)
                                                      Text(
                                                        'عميل ذهبي VIP ⭐',
                                                        style: GoogleFonts.ibmPlexSansArabic(
                                                          fontSize: 10,
                                                          color: const Color(0xFFF59E0B),
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    if (cust.isLapsing)
                                                      Container(
                                                        margin: const EdgeInsets.only(top: 2),
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFFEF2F2),
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: const Color(0xFFFCA5A5)),
                                                        ),
                                                        child: Text(
                                                          'غائب (${cust.daysSinceLastOrder} يوم) ⚠️',
                                                          style: GoogleFonts.ibmPlexSansArabic(
                                                            fontSize: 9.5,
                                                            color: const Color(0xFFDC2626),
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                          child: Text(
                                            cust.phone,
                                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textPrimary),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                          child: Text(
                                            cust.address,
                                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                          child: Text(
                                            '${cust.totalOrders}',
                                            style: GoogleFonts.ibmPlexSansArabic(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: c.textPrimary,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                          child: Text(
                                            '${NumberFormat('#,###').format(cust.totalSpend)} د.ع',
                                            style: GoogleFonts.ibmPlexSansArabic(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF10B981),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                cust.lastOrderDate != null
                                                    ? DateFormat('yyyy/MM/dd').format(cust.lastOrderDate!)
                                                    : '—',
                                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted),
                                              ),
                                              if (cust.isLapsing)
                                                Text(
                                                  'منذ ${cust.daysSinceLastOrder} يوم',
                                                  style: GoogleFonts.ibmPlexSansArabic(
                                                    fontSize: 10,
                                                    color: const Color(0xFFDC2626),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              if (cust.phone.isNotEmpty && cust.phone != 'غير مسجل' && cust.phone != '—')
                                                IconButton(
                                                  icon: const Icon(Icons.chat_rounded, size: 18, color: Color(0xFF25D366)),
                                                  tooltip: 'استرجاع عبر WhatsApp 💬',
                                                  onPressed: () => _launchWhatsAppWinBack(cust),
                                                ),
                                              IconButton(
                                                icon: Icon(Icons.point_of_sale_rounded, size: 18, color: c.primary),
                                                tooltip: 'إنشاء طلب جديد',
                                                onPressed: () {
                                                  if (widget.onNavigate != null) {
                                                    widget.onNavigate!(3); // ينتقل لشاشة POS
                                                  }
                                                },
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.edit_outlined, size: 18, color: c.textMuted),
                                                tooltip: 'تعديل',
                                                onPressed: () => _showEditCustomerDialog(context, cust),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                                tooltip: 'حذف العميل',
                                                onPressed: () => _confirmDeleteCustomer(cust),
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
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        title,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF8B95A5),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    final c = context.posColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: c.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    _showCustomerFormDialog(context, null);
  }

  void _showEditCustomerDialog(BuildContext context, CustomerProfile cust) {
    _showCustomerFormDialog(context, cust);
  }

  void _showCustomerFormDialog(BuildContext context, CustomerProfile? existing) {
    final c = context.posColors;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone == '—' || existing?.phone == 'غير مسجل' ? '' : existing?.phone ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? 'القائم');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            existing == null ? 'إضافة عميل جديد' : 'تعديل بيانات العميل',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('اسم العميل', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'مثال: أحمد عبد الله، أبو محمد...',
                      filled: true,
                      fillColor: c.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('رقم الهاتف', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '0770xxxxxxx أو 0780xxxxxxx',
                      filled: true,
                      fillColor: c.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('عنوان التوصيل', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: addressCtrl,
                    decoration: InputDecoration(
                      hintText: 'القائم - حي السكك، قرب الجامع الكبير...',
                      filled: true,
                      fillColor: c.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('ملاحظات خاصة بالعميل', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'تفضيلات خاصة، بدون حار، الاتصال قبل الوصول...',
                      filled: true,
                      fillColor: c.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                if (name.isEmpty && phone.isEmpty) return;

                final payload = {
                  'restaurantId': _activeId,
                  'name': name.isNotEmpty ? name : 'عميل مباشر',
                  'phone': phone,
                  'address': addressCtrl.text.trim(),
                  'notes': notesCtrl.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (_activeId.isNotEmpty) {
                  try {
                    if (existing == null) {
                      payload['createdAt'] = FieldValue.serverTimestamp();
                      await _customersRef().add(payload);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تمت إضافة العميل بنجاح')),
                        );
                      }
                    } else {
                      await _customersRef().doc(existing.id).set(payload, SetOptions(merge: true));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم تحديث بيانات العميل بنجاح')),
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('فشل حفظ العميل: $e')),
                      );
                    }
                  }
                }

                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('حفظ العميل', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCustomer(CustomerProfile cust) {
    final c = context.posColors;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            'حذف العميل',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في حذف العميل "${cust.name}" (${cust.phone}) من الدليل؟',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _customersRef().doc(cust.id).delete();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حذف العميل بنجاح')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تعذر حذف العميل (قد يكون عميل طلبات آلية): $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: Text('حذف نهائياً', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────── رادار مدار الذكي لاسترجاع الزبائن ───────────────────

  Widget _buildWinBackRadarBanner(
    BuildContext context,
    List<CustomerProfile> lapsing,
    double revenue,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF2F2), Color(0xFFFFF7ED)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.radar_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'رادار مدار الذكي: رصد الزبائن الغائبين 🎯',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: const Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${lapsing.length} زبون يحتاج تنشيط',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'تم رصد ${lapsing.length} زبون لم يطلبوا منذ أكثر من أسبوعين (إجمالي مشترياتهم السابقة ${NumberFormat('#,###').format(revenue)} د.ع). استرجعهم اليوم برسالة ترحيبية وكود خصم عبر WhatsApp بنقرة واحدة!',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: const Color(0xFF7F1D1D),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          OutlinedButton(
            onPressed: () => setState(() => _filterVip = 'غائب'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF991B1B),
              side: const BorderSide(color: Color(0xFFF87171)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'تصفية في الجدول',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showWinBackRadarDialog(context, lapsing),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: Text(
              'إطلاق حملة الاسترجاع 🚀',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchWhatsAppWinBack(CustomerProfile cust) async {
    String phone = cust.phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد رقم هاتف مسجل لهذا العميل')),
      );
      return;
    }

    if (phone.startsWith('07')) {
      phone = '964${phone.substring(1)}';
    } else if (phone.startsWith('7')) {
      phone = '964$phone';
    }

    final message = 'أهلاً بك يا ${cust.name} الغالي 🌹\n'
        'مشتاقين لطلباتك في مطعمنا عبر تطبيق مدار!\n'
        'خصصنا لك كود خصم خاص بيك (MADAR10) بخصم 10% على وجبتك القادمة 🍔🍟\n'
        'تكدر تطلب هسة مباشرة من التطبيق ونوصلك بأسرع وقت! ✨';

    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح WhatsApp: $e')),
        );
      }
    }
  }

  void _showWinBackRadarDialog(BuildContext context, List<CustomerProfile> lapsing) {
    final c = context.posColors;

    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: c.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 600,
              constraints: const BoxConstraints(maxHeight: 650),
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.radar_rounded, color: Color(0xFFEF4444), size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'رادار استرجاع الزبائن الغائبين 🎯',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                              ),
                            ),
                            Text(
                              'إرسال رسائل ودية مخصصة للزبائن الغائبين عبر WhatsApp مع كود خصم تشجيعي',
                              style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                        color: c.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: c.border, height: 1),
                  const SizedBox(height: 16),

                  // نص الرسالة المقترحة
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF16A34A), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'نص الرسالة المعتمدة (تلقائياً باسم كل زبون):',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '«أهلاً بك يا [اسم الزبون] الغالي 🌹، مشتاقين لطلباتك في مطعمنا عبر تطبيق مدار! خصصنا لك كود خصم خاص بيك (MADAR10) بخصم 10% على وجبتك القادمة 🍔🍟»',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.5,
                            color: const Color(0xFF166534),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'قائمة الزبائن المرصودين (${lapsing.length}):',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    child: ListView.separated(
                      itemCount: lapsing.length,
                      separatorBuilder: (_, _) => Divider(color: c.border, height: 1),
                      itemBuilder: (context, index) {
                        final cust = lapsing[index];
                        final hasPhone = cust.phone.isNotEmpty &&
                            cust.phone != 'غير مسجل' &&
                            cust.phone != '—';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.12),
                            child: Text(
                              cust.name.isNotEmpty ? cust.name[0] : 'ع',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                          title: Text(
                            cust.name,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: c.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '${cust.phone} • غائب منذ ${cust.daysSinceLastOrder} يوم • سابقاً: ${NumberFormat('#,###').format(cust.totalSpend)} د.ع',
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                          ),
                          trailing: hasPhone
                              ? ElevatedButton.icon(
                                  onPressed: () => _launchWhatsAppWinBack(cust),
                                  icon: const Icon(Icons.chat_rounded, size: 15),
                                  label: const Text('واتساب 💬'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    textStyle: GoogleFonts.ibmPlexSansArabic(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                )
                              : Text(
                                  'بدون هاتف',
                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textDisabled),
                                ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إغلاق'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
