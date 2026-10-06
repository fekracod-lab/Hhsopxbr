import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../services/inventory_deduction_service.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/responsive/madar_responsive.dart';
import '../../../../core/error/madar_crash_guard.dart';

/// نموذج مادة المخزون
class InventoryItem {
  final String id;
  final String name;
  final String category;
  final double currentQuantity;
  final String unit;
  final double minAlertLevel;
  final double costPerUnit;
  final DateTime? lastRestocked;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.currentQuantity,
    required this.unit,
    required this.minAlertLevel,
    required this.costPerUnit,
    this.lastRestocked,
  });

  bool get isLowStock => currentQuantity <= minAlertLevel;
  double get totalStockValue => currentQuantity * costPerUnit;

  factory InventoryItem.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    DateTime? lastR;
    if (d['lastRestocked'] is Timestamp) {
      lastR = (d['lastRestocked'] as Timestamp).toDate();
    }
    return InventoryItem(
      id: doc.id,
      name: (d['name'] ?? 'مادة أولية').toString(),
      category: (d['category'] ?? 'مواد غذائية').toString(),
      currentQuantity: (d['currentQuantity'] ?? d['quantity'] ?? 0).toDouble(),
      unit: (d['unit'] ?? 'كغم').toString(),
      minAlertLevel: (d['minAlertLevel'] ?? 5).toDouble(),
      costPerUnit: (d['costPerUnit'] ?? d['cost'] ?? 0).toDouble(),
      lastRestocked: lastR,
    );
  }
}

/// شاشة إدارة المخزون والمستودع في نظام مطاعم مدار
class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _effectiveRestaurantId = '';
  String _selectedCategory = 'الكل';
  String _searchQuery = '';

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

  CollectionReference _inventoryRef() {
    return FirebaseFirestore.instance
        .collection('merchant_inventory')
        .doc(_activeId)
        .collection('items');
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
            stream: _activeId.isEmpty ? null : _inventoryRef().snapshots(),
            builder: (context, snapshot) {
              List<InventoryItem> items = [];

              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                items = snapshot.data!.docs.map((d) => InventoryItem.fromFirestore(d)).toList();
              }

              final Set<String> categories = {'الكل'};
              for (var it in items) {
                categories.add(it.category);
              }

              final filtered = items.where((it) {
                final matchCat = _selectedCategory == 'الكل' || it.category == _selectedCategory;
                final matchSearch = _searchQuery.isEmpty || it.name.contains(_searchQuery) || it.category.contains(_searchQuery);
                return matchCat && matchSearch;
              }).toList();

              final totalItems = items.length;
              final lowStockCount = items.where((it) => it.isLowStock).length;
              final totalValue = items.fold(0.0, (s, it) => s + it.totalStockValue);

              return SingleChildScrollView(
                padding: EdgeInsets.all(MadarResponsive.contentPadding(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. الترويسة
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 650;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المخزون والمستودع وإدارة المواد',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'متابعة المواد الأولية، كميات اللحوم والزيوت، وحد إعادة الطلب، وتكاليف المواد',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12.5,
                                  color: c.textMuted,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showAddStockDialog(context),
                                  icon: const Icon(Icons.add_box_rounded, size: 20),
                                  label: Text(
                                    'إضافة مادة للمستودع',
                                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: c.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                'المخزون والمستودع وإدارة المواد',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'متابعة المواد الأولية، كميات اللحوم والزيوت، وحد إعادة الطلب، وتكاليف المواد',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 13,
                                  color: c.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () => _showAddStockDialog(context),
                            icon: const Icon(Icons.add_box_rounded, size: 20),
                            label: Text(
                              'إضافة مادة للمستودع',
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
                      );
                    },
                  ),

                    const SizedBox(height: 20),

                    // 2. بطاقات الإحصائيات
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        if (w < 700) {
                          return Column(
                            children: [
                              _buildStatCard(
                                title: 'إجمالي المواد المخزنة',
                                value: '$totalItems صنف',
                                icon: Icons.inventory_2_rounded,
                                color: const Color(0xFF3B82F6),
                                bg: const Color(0xFFEFF6FF),
                              ),
                              const SizedBox(height: 10),
                              _buildStatCard(
                                title: 'نواقص حرجة (Low Stock)',
                                value: '$lowStockCount مواد',
                                icon: Icons.warning_amber_rounded,
                                color: lowStockCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                bg: lowStockCount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                              ),
                              const SizedBox(height: 10),
                              _buildStatCard(
                                title: 'القيمة التقديرية للمستودع',
                                value: '${NumberFormat('#,###').format(totalValue)} د.ع',
                                icon: Icons.account_balance_wallet_rounded,
                                color: const Color(0xFF10B981),
                                bg: const Color(0xFFECFDF5),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                title: 'إجمالي المواد المخزنة',
                                value: '$totalItems صنف',
                                icon: Icons.inventory_2_rounded,
                                color: const Color(0xFF3B82F6),
                                bg: const Color(0xFFEFF6FF),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildStatCard(
                                title: 'نواقص حرجة (Low Stock)',
                                value: '$lowStockCount مواد',
                                icon: Icons.warning_amber_rounded,
                                color: lowStockCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                bg: lowStockCount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildStatCard(
                                title: 'القيمة التقديرية للمستودع',
                                value: '${NumberFormat('#,###').format(totalValue)} د.ع',
                                icon: Icons.account_balance_wallet_rounded,
                                color: const Color(0xFF10B981),
                                bg: const Color(0xFFECFDF5),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // 3. شريط الفئات والبحث
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 700;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: c.card,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: c.border),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.search_rounded, size: 18, color: c.textMuted),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        onChanged: (v) => setState(() => _searchQuery = v.trim()),
                                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: c.textPrimary),
                                        decoration: InputDecoration(
                                          hintText: 'ابحث عن مادة...',
                                          hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: categories.map((cat) {
                                    final isSel = _selectedCategory == cat;
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: ChoiceChip(
                                        label: Text(
                                          cat,
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontSize: 12,
                                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                            color: isSel ? Colors.white : c.textPrimary,
                                          ),
                                        ),
                                        selected: isSel,
                                        selectedColor: c.primary,
                                        backgroundColor: c.card,
                                        onSelected: (_) => setState(() => _selectedCategory = cat),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: BorderSide(color: isSel ? c.primary : c.border),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: categories.map((cat) {
                                    final isSel = _selectedCategory == cat;
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: ChoiceChip(
                                        label: Text(
                                          cat,
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontSize: 12,
                                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                            color: isSel ? Colors.white : c.textPrimary,
                                          ),
                                        ),
                                        selected: isSel,
                                        selectedColor: c.primary,
                                        backgroundColor: c.card,
                                        onSelected: (_) => setState(() => _selectedCategory = cat),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: BorderSide(color: isSel ? c.primary : c.border),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Container(
                              width: 260,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: c.card,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: c.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.search_rounded, size: 18, color: c.textMuted),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: c.textPrimary),
                                      decoration: InputDecoration(
                                        hintText: 'ابحث عن مادة...',
                                        hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // 4. جدول المخزون
                    if (items.isEmpty)
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
                              child: Icon(Icons.inventory_2_outlined, size: 48, color: c.primary),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد مواد مسجلة بالمخزون حالياً',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'المستودع فارغ تماماً. يمكنك البدء بإضافة المواد الأولية ومستلزمات الطبخ من الزر أدناه.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: c.textMuted),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => _showAddStockDialog(context),
                              icon: const Icon(Icons.add_box_rounded, size: 18),
                              label: Text(
                                'إضافة مادة للمخزون',
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
                              Icon(Icons.search_off_rounded, size: 56, color: c.textDisabled),
                              const SizedBox(height: 12),
                              Text(
                                'لا توجد مواد تطابق البحث أو التصنيف المحدد',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 15, fontWeight: FontWeight.bold, color: c.textMuted),
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
                          child: LayoutBuilder(
                            builder: (context, tableConstraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: tableConstraints.maxWidth > 800 ? tableConstraints.maxWidth : 800,
                                  ),
                                  child: Table(
                                    columnWidths: const {
                                      0: FlexColumnWidth(2.8),
                                      1: FlexColumnWidth(2.0),
                                      2: FlexColumnWidth(1.8),
                                      3: FlexColumnWidth(1.8),
                                      4: FlexColumnWidth(2.0),
                                      5: FlexColumnWidth(1.8),
                                      6: FixedColumnWidth(170),
                                    },
                                    children: [
                                      TableRow(
                                        decoration: BoxDecoration(
                                          color: c.background,
                                          border: Border(bottom: BorderSide(color: c.border)),
                                        ),
                                        children: [
                                          _buildHeaderCell('اسم المادة'),
                                          _buildHeaderCell('التصنيف'),
                                          _buildHeaderCell('الكمية الحالية'),
                                          _buildHeaderCell('حد التنبيه'),
                                          _buildHeaderCell('سعر التكلفة (د.ع)'),
                                          _buildHeaderCell('الحالة'),
                                          _buildHeaderCell('تسوية سريعة'),
                                        ],
                                      ),

                                      ...filtered.map((item) {
                                        return TableRow(
                                          decoration: BoxDecoration(
                                            border: Border(bottom: BorderSide(color: c.border.withValues(alpha: 0.5))),
                                          ),
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 32,
                                                    height: 32,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF3B82F6), size: 16),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      item.name,
                                                      style: GoogleFonts.ibmPlexSansArabic(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                        color: c.textPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                              child: Text(item.category, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted)),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                              child: Text(
                                                '${item.currentQuantity.toStringAsFixed(1)} ${item.unit}',
                                                style: GoogleFonts.ibmPlexSansArabic(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                  color: item.isLowStock ? const Color(0xFFEF4444) : c.textPrimary,
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                              child: Text(
                                                '${item.minAlertLevel.toStringAsFixed(0)} ${item.unit}',
                                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                              child: Text(
                                                '${NumberFormat('#,###').format(item.costPerUnit)} د.ع',
                                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold, color: c.textPrimary),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: item.isLowStock
                                                      ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                                                      : const Color(0xFF10B981).withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  item.isLowStock ? 'ناقص بحاجة لطلب' : 'متوفر',
                                                  style: GoogleFonts.ibmPlexSansArabic(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: item.isLowStock ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: Color(0xFF10B981)),
                                                    tooltip: 'إضافة كمية واردة (+)',
                                                    onPressed: () => _adjustQuantity(context, item, 1),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 20, color: Color(0xFFEF4444)),
                                                    tooltip: 'صرف أو استهلاك (-)',
                                                    onPressed: () => _adjustQuantity(context, item, -1),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)),
                                                    tooltip: 'حذف المادة نهائياً',
                                                    onPressed: () => _confirmDeleteItem(context, item),
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
                              );
                            },
                          ),
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

  Widget _buildHeaderCell(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        title,
        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF8B95A5)),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.ibmPlexSansArabic(fontSize: 18, fontWeight: FontWeight.w900, color: c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddStockDialog(BuildContext context) {
    final c = context.posColors;
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'لحوم ودواجن');
    final qtyCtrl = TextEditingController(text: '10');
    final unitCtrl = TextEditingController(text: 'كغم');
    final minCtrl = TextEditingController(text: '5');
    final costCtrl = TextEditingController(text: '12000');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('إضافة مادة أولية جديدة للمستودع', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MadarResponsive.dialogWidth(context, maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('اسم المادة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'مثال: لحم غنم مفروم، صدور دجاج، جبن موزاريلا...',
                      filled: true,
                      fillColor: c.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('التصنيف', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: catCtrl,
                              decoration: InputDecoration(
                                hintText: 'لحوم، خضار، مواد تعبئة...',
                                filled: true,
                                fillColor: c.background,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                            Text('وحدة القياس', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: unitCtrl,
                              decoration: InputDecoration(
                                hintText: 'كغم، لتر، كرتون، حبة...',
                                filled: true,
                                fillColor: c.background,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('الكمية الحالية', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: qtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: c.background,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                            Text('حد التنبيه الأدنى', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: minCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: c.background,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text('سعر التكلفة للوحدة (د.ع)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: costCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'سعر شراء الكيلو أو الحبة بالدينار العراقي',
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
                if (name.isEmpty) return;

                final payload = {
                  'name': name,
                  'category': catCtrl.text.trim().isEmpty ? 'مواد أولية' : catCtrl.text.trim(),
                  'unit': unitCtrl.text.trim().isEmpty ? 'كغم' : unitCtrl.text.trim(),
                  'currentQuantity': double.tryParse(qtyCtrl.text.trim()) ?? 0.0,
                  'minAlertLevel': double.tryParse(minCtrl.text.trim()) ?? 5.0,
                  'costPerUnit': double.tryParse(costCtrl.text.trim()) ?? 0.0,
                  'lastRestocked': FieldValue.serverTimestamp(),
                  'createdAt': FieldValue.serverTimestamp(),
                  'restaurantId': _activeId,
                };

                if (_activeId.isNotEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  await _inventoryRef().add(payload);
                  unawaited(InventoryDeductionService.instance.checkLowStockAlerts(restaurantId: _activeId));
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('تمت إضافة المادة للمخزون بنجاح')),
                    );
                  }
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('حفظ المادة', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _adjustQuantity(BuildContext context, InventoryItem item, int direction) {
    final c = context.posColors;
    final qtyCtrl = TextEditingController(text: '5');
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            direction > 0 ? 'تسجيل وارد جديد (+): ${item.name}' : 'تسجيل استهلاك / صرف (-): ${item.name}',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          content: SizedBox(
            width: MadarResponsive.dialogWidth(context, maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الكمية المراد ${direction > 0 ? "إضافتها" : "خصمها"} (${item.unit})', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: c.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                Text('ملاحظة / سبب الحركة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    hintText: direction > 0 ? 'شحنة جديدة من المورد...' : 'استهلاك وجبات اليوم أو هالك...',
                    filled: true,
                    fillColor: c.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final change = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
                if (change <= 0) return;
                final newQty = item.currentQuantity + (change * direction);

                if (_activeId.isNotEmpty) {
                  await _inventoryRef().doc(item.id).set({
                    'currentQuantity': newQty < 0 ? 0.0 : newQty,
                    'lastRestocked': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                  unawaited(InventoryDeductionService.instance.checkLowStockAlerts(restaurantId: _activeId));
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: direction > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: Text('تأكيد العملية', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteItem(BuildContext context, InventoryItem item) {
    final c = context.posColors;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            'حذف المادة من المخزون',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
          ),
          content: SizedBox(
            width: MadarResponsive.dialogWidth(context, maxWidth: 380),
            child: Text(
              'هل أنت متأكد من رغبتك في حذف مادة "${item.name}" نهائياً من المستودع؟',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
            ),
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
                  await _inventoryRef().doc(item.id).delete();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حذف المادة من المخزون بنجاح')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('فشل حذف المادة: $e')),
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
}
