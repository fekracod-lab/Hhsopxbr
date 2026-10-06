import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/error/madar_crash_guard.dart';

/// نموذج خيار أو إضافة للوجبة متوافق مع أعلى معايير المطاعم
class MealModifier {
  final String id;
  final String name;
  final String nameEn;
  final String groupName;
  final double price;
  final bool isRequired;
  final bool isMultiSelect;
  final int minSelection;
  final int maxSelection;
  final bool isActive;
  final bool isOutOfStock; // كود 86: نفد المخزون مؤقتاً
  final int calories;
  final int orderIndex;

  const MealModifier({
    required this.id,
    required this.name,
    this.nameEn = '',
    required this.groupName,
    required this.price,
    this.isRequired = false,
    this.isMultiSelect = true,
    this.minSelection = 0,
    this.maxSelection = 0,
    this.isActive = true,
    this.isOutOfStock = false,
    this.calories = 0,
    this.orderIndex = 0,
  });

  factory MealModifier.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    final isReq = d['isRequired'] ?? false;
    final isMulti = d['isMultiSelect'] ?? true;

    return MealModifier(
      id: doc.id,
      name: d['name'] ?? 'إضافة',
      nameEn: d['nameEn'] ?? '',
      groupName: d['groupName'] ?? d['category'] ?? 'إضافات عامة',
      price: (d['price'] ?? 0).toDouble(),
      isRequired: isReq,
      isMultiSelect: isMulti,
      minSelection: (d['minSelection'] ?? (isReq ? 1 : 0)) as int,
      maxSelection: (d['maxSelection'] ?? (isMulti ? 0 : 1)) as int,
      isActive: d['isActive'] ?? true,
      isOutOfStock: d['isOutOfStock'] ?? false,
      calories: (d['calories'] ?? 0) as int,
      orderIndex: (d['orderIndex'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'nameEn': nameEn,
      'groupName': groupName,
      'price': price,
      'isRequired': isRequired,
      'isMultiSelect': isMultiSelect,
      'minSelection': minSelection,
      'maxSelection': maxSelection,
      'isActive': isActive,
      'isOutOfStock': isOutOfStock,
      'calories': calories,
      'orderIndex': orderIndex,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  MealModifier copyWith({
    String? id,
    String? name,
    String? nameEn,
    String? groupName,
    double? price,
    bool? isRequired,
    bool? isMultiSelect,
    int? minSelection,
    int? maxSelection,
    bool? isActive,
    bool? isOutOfStock,
    int? calories,
    int? orderIndex,
  }) {
    return MealModifier(
      id: id ?? this.id,
      name: name ?? this.name,
      nameEn: nameEn ?? this.nameEn,
      groupName: groupName ?? this.groupName,
      price: price ?? this.price,
      isRequired: isRequired ?? this.isRequired,
      isMultiSelect: isMultiSelect ?? this.isMultiSelect,
      minSelection: minSelection ?? this.minSelection,
      maxSelection: maxSelection ?? this.maxSelection,
      isActive: isActive ?? this.isActive,
      isOutOfStock: isOutOfStock ?? this.isOutOfStock,
      calories: calories ?? this.calories,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}

/// أنماط عرض صفحة الإضافات
enum ModifierViewMode {
  grid,    // عرض الكروت الشبكية
  table,   // عرض جدول البيانات
  grouped, // عرض مقسم حسب المجموعات
}

/// فلاتر الإحصائيات السريعة
enum ModifierQuickFilter {
  all,
  paid,
  free,
  outOfStock,
  active,
}

/// شاشة إدارة الإضافات والخيارات المطورة لمنظومة مطاعم مدار
class ModifiersPage extends StatefulWidget {
  const ModifiersPage({super.key});

  @override
  State<ModifiersPage> createState() => _ModifiersPageState();
}

class _ModifiersPageState extends State<ModifiersPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _effectiveRestaurantId = '';
  String _selectedGroupFilter = 'الكل';
  String _searchQuery = '';
  ModifierViewMode _viewMode = ModifierViewMode.grid;
  ModifierQuickFilter _quickFilter = ModifierQuickFilter.all;

  // نمط التحديد المتعدد للعمليات الجماعية
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

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

  CollectionReference _modifiersRef() {
    return FirebaseFirestore.instance
        .collection('merchant_modifiers')
        .doc(_activeId)
        .collection('modifiers');
  }

  CollectionReference _restaurantModifiersRef() {
    return FirebaseFirestore.instance
        .collection('restaurants')
        .doc(_activeId)
        .collection('modifiers');
  }

  // ─────────────────────────── واجهة المستخدم الرئيسية ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeCrashBoundary(
          child: StreamBuilder<QuerySnapshot>(
            stream: _activeId.isEmpty ? null : _modifiersRef().snapshots(),
            builder: (context, snapshot) {
              List<MealModifier> items = [];

              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                items = snapshot.data!.docs
                    .map((d) => MealModifier.fromFirestore(d))
                    .toList();
                // ترتيب العناصر حسب orderIndex ثم الاسم
                items.sort((a, b) {
                  final cmp = a.orderIndex.compareTo(b.orderIndex);
                  if (cmp != 0) return cmp;
                  return a.name.compareTo(b.name);
                });
              }

              // استخراج المجموعات الفريدة
              final Set<String> groups = {'الكل'};
              for (var it in items) {
                if (it.groupName.trim().isNotEmpty) {
                  groups.add(it.groupName.trim());
                }
              }

              // فلترة العناصر
              final filtered = items.where((it) {
                // فلتر المجموعة
                final matchGroup = _selectedGroupFilter == 'الكل' || it.groupName == _selectedGroupFilter;

                // فلتر البحث
                final query = _searchQuery.toLowerCase();
                final matchSearch = query.isEmpty ||
                    it.name.toLowerCase().contains(query) ||
                    it.nameEn.toLowerCase().contains(query) ||
                    it.groupName.toLowerCase().contains(query);

                // فلتر البطاقات السريع
                bool matchQuick = true;
                switch (_quickFilter) {
                  case ModifierQuickFilter.all:
                    matchQuick = true;
                    break;
                  case ModifierQuickFilter.paid:
                    matchQuick = it.price > 0;
                    break;
                  case ModifierQuickFilter.free:
                    matchQuick = it.price == 0;
                    break;
                  case ModifierQuickFilter.outOfStock:
                    matchQuick = it.isOutOfStock;
                    break;
                  case ModifierQuickFilter.active:
                    matchQuick = it.isActive && !it.isOutOfStock;
                    break;
                }

                return matchGroup && matchSearch && matchQuick;
              }).toList();

              // الإحصائيات
              final totalCount = items.length;
              final paidCount = items.where((i) => i.price > 0).length;
              final freeCount = items.where((i) => i.price == 0).length;
              final outOfStockCount = items.where((i) => i.isOutOfStock).length;
              final activeCount = items.where((i) => i.isActive && !i.isOutOfStock).length;

              return Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. الترويسة الرئيسية مع أزرار الإجراءات
                        _buildHeader(context, items),

                        const SizedBox(height: 18),

                        // 2. بطاقات مؤشرات الأداء الحية (KPIs)
                        _buildStatCards(
                          context,
                          total: totalCount,
                          paid: paidCount,
                          free: freeCount,
                          outOfStock: outOfStockCount,
                          active: activeCount,
                        ),

                        const SizedBox(height: 18),

                        // 3. شريط التحكم والبحث وتبديل أنماط العرض
                        _buildControlBar(context, groups, items),

                        const SizedBox(height: 16),

                        // 4. المحتوى الرئيسي حسب النمط المختار
                        if (items.isEmpty)
                          _buildEmptyState(context)
                        else if (filtered.isEmpty)
                          _buildNoFilterResults(context)
                        else
                          _buildContentView(context, filtered),
                      ],
                    ),
                  ),

                  // شريط العمليات المجمعة العائم أسفل الشاشة
                  if (_isSelectionMode && _selectedIds.isNotEmpty)
                    Positioned(
                      bottom: 20,
                      left: 24,
                      right: 24,
                      child: _buildBatchActionBar(context, items),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── الترويسة الرئيسية ───────────────────────────

  Widget _buildHeader(BuildContext context, List<MealModifier> items) {
    final c = context.posColors;

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.tune_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'الإضافات والخيارات (Modifiers & Add-ons)',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${items.length} خيار مسجل',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'التحكم الدقيق في خيارات الوجبات، الأجبان، الصوصات، درجات الطهي، والحدود التشغيلية',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12.5,
                color: c.textMuted,
              ),
            ),
          ],
        ),
        const Spacer(),

        // زر الباقات الجاهزة المسبقة
        PopupMenuButton<String>(
          tooltip: 'استيراد باقة إضافات جاهزة',
          onSelected: (packKey) => _applyPresetPack(context, packKey),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          itemBuilder: (ctx) => [
            _buildPresetMenuItem(
              value: 'burger',
              icon: Icons.lunch_dining_rounded,
              title: 'باقة البرغر والوجبات السريعة 🍔',
              subtitle: 'أجبان، صوصات، خبز بريوش، إكسترا لحوم ومقبلات',
            ),
            _buildPresetMenuItem(
              value: 'shawarma',
              icon: Icons.kebab_dining_rounded,
              title: 'باقة المشويات والشاورما العراقي 🍢',
              subtitle: 'عمبة، ثومية، صمون حجري، خبز صاج، طرشي ولية',
            ),
            _buildPresetMenuItem(
              value: 'pizza',
              icon: Icons.local_pizza_rounded,
              title: 'باقة البيتزا والمعجنات الإيطالية 🍕',
              subtitle: 'أطراف محشوة، بيبروني، فطر، موزاريلا مضاعفة',
            ),
            _buildPresetMenuItem(
              value: 'cafe',
              icon: Icons.local_cafe_rounded,
              title: 'باقة الكافيه والمشروبات ☕',
              subtitle: 'حليب نباتي، شوت إسبريسو، سيرب كراميل وفانيلا',
            ),
            _buildPresetMenuItem(
              value: 'kitchen_notes',
              icon: Icons.edit_note_rounded,
              title: 'باقة الملاحظات والتجهيز المطبخي 🍳',
              subtitle: 'بدون بصل، قليل الملح، حار، صوص جانبي، سفري محكم',
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 19),
                const SizedBox(width: 6),
                Text(
                  'باقات جاهزة ⚡',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFD97706), size: 18),
              ],
            ),
          ),
        ),

        const SizedBox(width: 10),

        // زر تصدير النسخة الاحتياطية JSON
        OutlinedButton.icon(
          onPressed: items.isEmpty ? null : () => _exportModifiersJson(context, items),
          icon: const Icon(Icons.file_download_outlined, size: 18),
          label: Text('تصدير JSON', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.textPrimary,
            side: BorderSide(color: c.border),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),

        const SizedBox(width: 10),

        // زر إضافة خيار جديد
        ElevatedButton.icon(
          onPressed: () => _showModifierDialog(context, null),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 19),
          label: Text(
            'إضافة خيار جديد',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 2,
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildPresetMenuItem({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF6366F1)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── بطاقات مؤشرات الأداء الحية ───────────────────────────

  Widget _buildStatCards(
    BuildContext context, {
    required int total,
    required int paid,
    required int free,
    required int outOfStock,
    required int active,
  }) {
    return Row(
      children: [
        _buildStatCard(
          context,
          title: 'إجمالي الخيارات',
          value: '$total',
          subtitle: 'كافة الخيارات المسجلة',
          icon: Icons.tune_rounded,
          color: const Color(0xFF6366F1),
          isSelected: _quickFilter == ModifierQuickFilter.all,
          onTap: () => setState(() => _quickFilter = ModifierQuickFilter.all),
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          context,
          title: 'إضافات مدفوعة (Extra)',
          value: '$paid',
          subtitle: 'تزيد من قيمة الفاتورة',
          icon: Icons.monetization_on_rounded,
          color: const Color(0xFF10B981),
          isSelected: _quickFilter == ModifierQuickFilter.paid,
          onTap: () => setState(() => _quickFilter = ModifierQuickFilter.paid),
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          context,
          title: 'مجانية وملاحظات',
          value: '$free',
          subtitle: 'تفضيلات الطهي وتعديل المكونات',
          icon: Icons.check_circle_outline_rounded,
          color: const Color(0xFF3B82F6),
          isSelected: _quickFilter == ModifierQuickFilter.free,
          onTap: () => setState(() => _quickFilter = ModifierQuickFilter.free),
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          context,
          title: 'نفد المخزون (86)',
          value: '$outOfStock',
          subtitle: 'غير متاحة مؤقتاً في الكاشير',
          icon: Icons.do_not_disturb_on_rounded,
          color: const Color(0xFFEF4444),
          isSelected: _quickFilter == ModifierQuickFilter.outOfStock,
          onTap: () => setState(() => _quickFilter = ModifierQuickFilter.outOfStock),
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          context,
          title: 'الخيارات النشطة',
          value: '$active',
          subtitle: 'معروضة وجاهزة للطلب',
          icon: Icons.verified_rounded,
          color: const Color(0xFF8B5CF6),
          isSelected: _quickFilter == ModifierQuickFilter.active,
          onTap: () => setState(() => _quickFilter = ModifierQuickFilter.active),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final c = context.posColors;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : c.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: c.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? color : c.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 10,
                        color: c.textMuted.withValues(alpha: 0.8),
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
      ),
    );
  }

  // ─────────────────────────── شريط التحكم والبحث وتبديل العرض ───────────────────────────

  Widget _buildControlBar(BuildContext context, Set<String> groups, List<MealModifier> items) {
    final c = context.posColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          // حقل البحث الفوري
          Container(
            width: 280,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: c.background,
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
                      hintText: 'ابحث بالاسم، المجموعة، أو السعر...',
                      hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted),
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

          const SizedBox(width: 14),

          // شرائح تصفية المجموعات
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: groups.map((grp) {
                  final isSel = _selectedGroupFilter == grp;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(
                        grp,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                          color: isSel ? Colors.white : c.textPrimary,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: c.primary,
                      backgroundColor: c.background,
                      onSelected: (_) => setState(() => _selectedGroupFilter = grp),
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

          const SizedBox(width: 14),

          // زر التحديد المتعدد
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _isSelectionMode = !_isSelectionMode;
                if (!_isSelectionMode) _selectedIds.clear();
              });
            },
            icon: Icon(
              _isSelectionMode ? Icons.close_rounded : Icons.checklist_rounded,
              size: 17,
              color: _isSelectionMode ? const Color(0xFFEF4444) : c.textPrimary,
            ),
            label: Text(
              _isSelectionMode ? 'إلغاء التحديد' : 'تحديد متعدد',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: _isSelectionMode ? const Color(0xFFEF4444) : c.textPrimary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _isSelectionMode ? const Color(0xFFEF4444) : c.border),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),

          const SizedBox(width: 10),

          // أزرار نمط العرض (شبكي، جدول، مجمع)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                _buildViewModeButton(
                  icon: Icons.grid_view_rounded,
                  mode: ModifierViewMode.grid,
                  tooltip: 'عرض الكروت الشبكية',
                ),
                _buildViewModeButton(
                  icon: Icons.table_rows_rounded,
                  mode: ModifierViewMode.table,
                  tooltip: 'عرض جدول البيانات',
                ),
                _buildViewModeButton(
                  icon: Icons.view_agenda_rounded,
                  mode: ModifierViewMode.grouped,
                  tooltip: 'عرض مجمع حسب المجموعات',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeButton({
    required IconData icon,
    required ModifierViewMode mode,
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
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isSel ? c.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSel ? Colors.white : c.textMuted,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── المحتوى الرئيسي بأنماطه ───────────────────────────

  Widget _buildContentView(BuildContext context, List<MealModifier> items) {
    switch (_viewMode) {
      case ModifierViewMode.grid:
        return _buildGridView(context, items);
      case ModifierViewMode.table:
        return _buildTableView(context, items);
      case ModifierViewMode.grouped:
        return _buildGroupedView(context, items);
    }
  }

  // 1. العرض الشبكي (Grid View)
  Widget _buildGridView(BuildContext context, List<MealModifier> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 3;
        if (width < 800) {
          crossAxisCount = 1;
        } else if (width < 1200) {
          crossAxisCount = 2;
        } else if (width < 1600) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 4;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.85,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildModifierCard(context, item);
          },
        );
      },
    );
  }

  Widget _buildModifierCard(BuildContext context, MealModifier item) {
    final c = context.posColors;
    final isSelected = _selectedIds.contains(item.id);

    return InkWell(
      onTap: _isSelectionMode
          ? () => _toggleItemSelection(item.id)
          : () => _showModifierDialog(context, item),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? c.primary
                : item.isOutOfStock
                    ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                    : c.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الشريط العلوي
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: item.isOutOfStock
                      ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                      : const Color(0xFF6366F1).withValues(alpha: 0.08),
                  border: Border(bottom: BorderSide(color: c.border.withValues(alpha: 0.5))),
                ),
                child: Row(
                  children: [
                    if (_isSelectionMode)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(
                          isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          color: isSelected ? c.primary : c.textMuted,
                          size: 19,
                        ),
                      ),

                    // شارة المجموعة
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: c.border),
                      ),
                      child: Text(
                        item.groupName,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // شارة الإلزامي / الاختياري
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.isRequired
                            ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                            : const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.isRequired ? 'إلزامي' : 'اختياري',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: item.isRequired ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // شارة متعدد / مفرد
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.background,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.isMultiSelect ? 'متعدد' : 'مفرد',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: c.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // جسم البطاقة
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: item.isOutOfStock ? c.textMuted : c.textPrimary,
                                    decoration: item.isOutOfStock ? TextDecoration.lineThrough : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (item.nameEn.isNotEmpty)
                                  Text(
                                    item.nameEn,
                                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // السعر
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: item.price > 0
                                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                  : c.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.price > 0 ? '+${item.price.toInt()} د.ع' : 'مجاني',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: item.price > 0 ? const Color(0xFF10B981) : c.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // شريط الإجراءات والتحكم
                      Row(
                        children: [
                          // زر 86 نفد المخزون
                          InkWell(
                            onTap: () => _toggleOutOfStock(item),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: item.isOutOfStock
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    item.isOutOfStock ? Icons.do_not_disturb_on_rounded : Icons.block_flipped,
                                    size: 14,
                                    color: item.isOutOfStock ? Colors.white : const Color(0xFFEF4444),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.isOutOfStock ? 'نفد (86)' : 'تعطيل مؤقت',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: item.isOutOfStock ? Colors.white : const Color(0xFFEF4444),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const Spacer(),

                          // مفتاح التفعيل / الإخفاء
                          Transform.scale(
                            scale: 0.75,
                            child: Switch(
                              value: item.isActive,
                              activeTrackColor: c.primary,
                              activeThumbColor: Colors.white,
                              onChanged: (_) => _toggleActiveStatus(item),
                            ),
                          ),

                          // زر تعديل
                          IconButton(
                            icon: Icon(Icons.edit_outlined, size: 17, color: c.primary),
                            tooltip: 'تعديل',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showModifierDialog(context, item),
                          ),

                          const SizedBox(width: 8),

                          // زر حذف
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFFEF4444)),
                            tooltip: 'حذف',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _confirmDelete(context, item),
                          ),
                        ],
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
  }

  // 2. عرض جدول البيانات (Table View)
  Widget _buildTableView(BuildContext context, List<MealModifier> items) {
    final c = context.posColors;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2.8),
            1: FlexColumnWidth(1.8),
            2: FlexColumnWidth(1.4),
            3: FlexColumnWidth(1.2),
            4: FlexColumnWidth(1.4),
            5: FlexColumnWidth(1.2),
            6: FixedColumnWidth(110),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: c.background,
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              children: [
                _buildTableHeaderCell('اسم الإضافة / الخيار'),
                _buildTableHeaderCell('المجموعة'),
                _buildTableHeaderCell('السعر الإضافي'),
                _buildTableHeaderCell('النوع'),
                _buildTableHeaderCell('المخزون (86)'),
                _buildTableHeaderCell('الحالة'),
                _buildTableHeaderCell('إجراءات'),
              ],
            ),
            ...items.map((item) {
              final isSelected = _selectedIds.contains(item.id);

              return TableRow(
                decoration: BoxDecoration(
                  color: isSelected ? c.primary.withValues(alpha: 0.05) : Colors.transparent,
                  border: Border(bottom: BorderSide(color: c.border.withValues(alpha: 0.5))),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        if (_isSelectionMode)
                          GestureDetector(
                            onTap: () => _toggleItemSelection(item.id),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(
                                isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                color: isSelected ? c.primary : c.textMuted,
                                size: 18,
                              ),
                            ),
                          ),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.tune_rounded, color: Color(0xFF6366F1), size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: item.isOutOfStock ? c.textMuted : c.textPrimary,
                                  decoration: item.isOutOfStock ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (item.nameEn.isNotEmpty)
                                Text(
                                  item.nameEn,
                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textMuted),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: c.border),
                        ),
                        child: Text(
                          item.groupName,
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF6366F1)),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Text(
                      item.price > 0 ? '+${item.price.toInt()} د.ع' : 'مجاني',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                        color: item.price > 0 ? const Color(0xFF10B981) : c.textMuted,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        Text(
                          item.isRequired ? 'إلزامي' : 'اختياري',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: item.isRequired ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '• ${item.isMultiSelect ? 'متعدد' : 'مفرد'}',
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () => _toggleOutOfStock(item),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.isOutOfStock ? const Color(0xFFEF4444) : const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.isOutOfStock ? 'نفد (86)' : 'متوفر',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: item.isOutOfStock ? Colors.white : const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: item.isActive,
                        activeTrackColor: c.primary,
                        activeThumbColor: Colors.white,
                        onChanged: (_) => _toggleActiveStatus(item),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 17, color: c.primary),
                          tooltip: 'تعديل',
                          onPressed: () => _showModifierDialog(context, item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFFEF4444)),
                          tooltip: 'حذف',
                          onPressed: () => _confirmDelete(context, item),
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
  }

  Widget _buildTableHeaderCell(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        title,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }

  // 3. العرض المجمع حسب المجموعات (Grouped View)
  Widget _buildGroupedView(BuildContext context, List<MealModifier> items) {
    final c = context.posColors;

    // تجميع العناصر حسب اسم المجموعة
    final Map<String, List<MealModifier>> grouped = {};
    for (var it in items) {
      final grp = it.groupName.trim().isEmpty ? 'إضافات عامة' : it.groupName.trim();
      grouped.putIfAbsent(grp, () => []).add(it);
    }

    return Column(
      children: grouped.entries.map((entry) {
        final groupName = entry.key;
        final groupItems = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(14),
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
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder_open_rounded, color: Color(0xFF6366F1), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    groupName,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border),
                    ),
                    child: Text(
                      '${groupItems.length} خيارات',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: c.textMuted),
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: _buildGridView(context, groupItems),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────── شريط العمليات المجمعة ───────────────────────────

  Widget _buildBatchActionBar(BuildContext context, List<MealModifier> allItems) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.checklist_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(
            'تم تحديد ${_selectedIds.length} خيارات',
            style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const Spacer(),

          // تفعيل الكل
          ElevatedButton.icon(
            onPressed: () => _executeBatchUpdate({'isActive': true}),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
            label: const Text('تفعيل المحدد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 8),

          // تعطيل مؤقت (86)
          ElevatedButton.icon(
            onPressed: () => _executeBatchUpdate({'isOutOfStock': true}),
            icon: const Icon(Icons.block_flipped, size: 15),
            label: const Text('تعطيل نفاد (86)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 8),

          // إعادة توفر
          ElevatedButton.icon(
            onPressed: () => _executeBatchUpdate({'isOutOfStock': false, 'isActive': true}),
            icon: const Icon(Icons.restore_rounded, size: 15),
            label: const Text('إعادة توفر'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 8),

          // حذف المحدد
          ElevatedButton.icon(
            onPressed: () => _executeBatchDelete(),
            icon: const Icon(Icons.delete_forever_rounded, size: 15),
            label: const Text('حذف المحدد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 12),

          TextButton(
            onPressed: () => setState(() => _selectedIds.clear()),
            child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: const Color(0xFF94A3B8))),
          ),
        ],
      ),
    );
  }

  void _toggleItemSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _executeBatchUpdate(Map<String, dynamic> updateData) async {
    if (_activeId.isEmpty || _selectedIds.isEmpty) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var id in _selectedIds) {
        batch.set(_modifiersRef().doc(id), updateData, SetOptions(merge: true));
        batch.set(_restaurantModifiersRef().doc(id), updateData, SetOptions(merge: true));
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث ${_selectedIds.length} خيارات بنجاح', style: GoogleFonts.ibmPlexSansArabic()),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        setState(() => _selectedIds.clear());
      }
    } catch (_) {}
  }

  Future<void> _executeBatchDelete() async {
    if (_activeId.isEmpty || _selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('تأكيد الحذف الجماعي', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من رغبتك في حذف ${_selectedIds.length} خيارات نهائياً؟', style: GoogleFonts.ibmPlexSansArabic()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              child: Text('تأكيد الحذف', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var id in _selectedIds) {
        batch.delete(_modifiersRef().doc(id));
        batch.delete(_restaurantModifiersRef().doc(id));
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف ${_selectedIds.length} خيارات بنجاح', style: GoogleFonts.ibmPlexSansArabic()),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        setState(() => _selectedIds.clear());
      }
    } catch (_) {}
  }

  // ─────────────────────────── نافذة الإضافة والتعديل مع المعاينة الحية ───────────────────────────

  void _showModifierDialog(BuildContext context, MealModifier? existing) {
    final c = context.posColors;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final nameEnCtrl = TextEditingController(text: existing?.nameEn ?? '');
    final groupCtrl = TextEditingController(text: existing?.groupName ?? 'إضافات عامة');
    final priceCtrl = TextEditingController(text: existing != null ? '${existing.price.toInt()}' : '0');
    final caloriesCtrl = TextEditingController(text: existing != null && existing.calories > 0 ? '${existing.calories}' : '');

    bool isRequired = existing?.isRequired ?? false;
    bool isMulti = existing?.isMultiSelect ?? true;
    int minSel = existing?.minSelection ?? (isRequired ? 1 : 0);
    int maxSel = existing?.maxSelection ?? (isMulti ? 0 : 1);

    final suggestedGroups = [
      'إضافات الجبن',
      'الصوصات والإضافات',
      'نوع الخبز',
      'درجة الاستواء',
      'ملاحظات المطبخ',
      'إكسترا ومقبلات',
      'الحجم ونوع الحليب',
      'نكهات وسيرب',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentPrice = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
          final displayName = nameCtrl.text.trim().isEmpty ? 'اسم الإضافة' : nameCtrl.text.trim();
          final displayGroup = groupCtrl.text.trim().isEmpty ? 'المجموعة' : groupCtrl.text.trim();

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      existing == null ? Icons.add_circle_outline_rounded : Icons.edit_note_rounded,
                      color: const Color(0xFF6366F1),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    existing == null ? 'إضافة خيار أو إضافة جديدة' : 'تعديل تفاصيل الخيار',
                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w900, fontSize: 17),
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
                      // بطاقة المعاينة الحية في الكاشير
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF6366F1).withValues(alpha: 0.08),
                              const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.remove_red_eye_outlined, size: 16, color: Color(0xFF6366F1)),
                                const SizedBox(width: 6),
                                Text(
                                  'معاينة حية لشكل الخيار في شاشة الكاشير وسلة الطلبات:',
                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF6366F1)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: c.card,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: c.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isMulti ? Icons.check_box_outlined : Icons.radio_button_checked_rounded,
                                    size: 18,
                                    color: c.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary),
                                        ),
                                        Text(
                                          '$displayGroup • ${isRequired ? 'إلزامي' : 'اختياري'}',
                                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: currentPrice > 0 ? const Color(0xFF10B981).withValues(alpha: 0.12) : c.background,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      currentPrice > 0 ? '+${currentPrice.toInt()} د.ع' : 'مجاني',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: currentPrice > 0 ? const Color(0xFF10B981) : c.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // اسم الخيار بالعربي والإنجليزي
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('اسم الإضافة / الخيار (بالعربية)*', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: nameCtrl,
                                  onChanged: (_) => setModalState(() {}),
                                  decoration: InputDecoration(
                                    hintText: 'مثال: جبن موزاريلا إضافي',
                                    hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('الاسم بالإنجليزية (اختياري)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: nameEnCtrl,
                                  onChanged: (_) => setModalState(() {}),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Extra Mozzarella',
                                    hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted),
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

                      // اسم المجموعة واقتراحات سريعة
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('اسم المجموعة (لتنظيم الخيارات في السلة)*', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: groupCtrl,
                            onChanged: (_) => setModalState(() {}),
                            decoration: InputDecoration(
                              hintText: 'اكتب اسم مجموعة أو اختر من المقترحات أدناه',
                              hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted),
                              filled: true,
                              fillColor: c.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: suggestedGroups.map((sug) {
                              final isCur = groupCtrl.text.trim() == sug;
                              return ActionChip(
                                label: Text(sug, style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, fontWeight: isCur ? FontWeight.bold : FontWeight.normal)),
                                backgroundColor: isCur ? const Color(0xFF6366F1).withValues(alpha: 0.15) : c.background,
                                side: BorderSide(color: isCur ? const Color(0xFF6366F1) : c.border),
                                onPressed: () {
                                  setModalState(() {
                                    groupCtrl.text = sug;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // السعر الإضافي وأزرار مبالغ سريعة
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('السعر الإضافي (د.ع)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setModalState(() {}),
                            decoration: InputDecoration(
                              hintText: '0 للمجاني، أو 1000، 2000...',
                              hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted),
                              filled: true,
                              fillColor: c.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildQuickPriceChip('مجاني', 0, priceCtrl, setModalState),
                              const SizedBox(width: 6),
                              _buildQuickPriceChip('+500', 500, priceCtrl, setModalState),
                              const SizedBox(width: 6),
                              _buildQuickPriceChip('+1000', 1000, priceCtrl, setModalState),
                              const SizedBox(width: 6),
                              _buildQuickPriceChip('+1500', 1500, priceCtrl, setModalState),
                              const SizedBox(width: 6),
                              _buildQuickPriceChip('+2000', 2000, priceCtrl, setModalState),
                              const SizedBox(width: 6),
                              _buildQuickPriceChip('+3000', 3000, priceCtrl, setModalState),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // قواعد الاختيار (إلزامي / اختياري - متعدد / مفرد)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.border),
                        ),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              value: isRequired,
                              activeColor: c.primary,
                              title: Text(
                                'خيار إلزامي (مطلوب من الزبون قبل إتمام الطلب)',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'مثل: اختيار درجة استواء اللحم، أو نوع الخبز الإلزامي',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textMuted),
                              ),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (v) {
                                setModalState(() {
                                  isRequired = v ?? false;
                                  if (isRequired && minSel == 0) minSel = 1;
                                });
                              },
                            ),
                            const Divider(height: 16),
                            CheckboxListTile(
                              value: isMulti,
                              activeColor: c.primary,
                              title: Text(
                                'سماح باختيار أكثر من عنصر (Multi-select)',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'إذا عُطّل، يصبح الاختيار فردياً (Radio button) كاختيار نوع الخبز فقط',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textMuted),
                              ),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (v) {
                                setModalState(() {
                                  isMulti = v ?? true;
                                  if (!isMulti) maxSel = 1;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // السعرات الحرارية
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('السعرات الحرارية (كالوري - اختياري)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: caloriesCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'مثال: 120 كالوري',
                                    hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted),
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
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final group = groupCtrl.text.trim().isEmpty ? 'إضافات عامة' : groupCtrl.text.trim();
                    final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                    final calories = int.tryParse(caloriesCtrl.text.trim()) ?? 0;

                    final payload = {
                      'name': name,
                      'nameEn': nameEnCtrl.text.trim(),
                      'groupName': group,
                      'price': price,
                      'isRequired': isRequired,
                      'isMultiSelect': isMulti,
                      'minSelection': minSel,
                      'maxSelection': maxSel,
                      'calories': calories,
                      'isActive': existing?.isActive ?? true,
                      'isOutOfStock': existing?.isOutOfStock ?? false,
                      'updatedAt': FieldValue.serverTimestamp(),
                    };

                    if (_activeId.isNotEmpty) {
                      if (existing == null) {
                        payload['createdAt'] = FieldValue.serverTimestamp();
                        final ref = await _modifiersRef().add(payload);
                        try {
                          await _restaurantModifiersRef().doc(ref.id).set(payload);
                        } catch (_) {}
                      } else {
                        await _modifiersRef().doc(existing.id).set(payload, SetOptions(merge: true));
                        try {
                          await _restaurantModifiersRef().doc(existing.id).set(payload, SetOptions(merge: true));
                        } catch (_) {}
                      }
                    }

                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    existing == null ? 'إضافة الخيار' : 'حفظ التعديلات',
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

  Widget _buildQuickPriceChip(String label, int price, TextEditingController ctrl, StateSetter setModalState) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, fontWeight: FontWeight.bold)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      onPressed: () {
        setModalState(() {
          ctrl.text = '$price';
        });
      },
    );
  }

  // ─────────────────────────── تطبيق الباقات الجاهزة ───────────────────────────

  Future<void> _applyPresetPack(BuildContext context, String packKey) async {
    if (_activeId.isEmpty) return;

    List<Map<String, dynamic>> presetItems = [];
    String packName = '';

    switch (packKey) {
      case 'burger':
        packName = 'باقة البرغر والوجبات السريعة';
        presetItems = [
          {'name': 'جبن شيدر ذائب', 'groupName': 'إضافات الجبن', 'price': 1000.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'جبن موزاريلا إضافي', 'groupName': 'إضافات الجبن', 'price': 1000.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'صوص رانش خاص', 'groupName': 'الصوصات والإضافات', 'price': 500.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'صوص باربيكيو مدخن', 'groupName': 'الصوصات والإضافات', 'price': 500.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'هالبينو حار', 'groupName': 'إضافات الخضار', 'price': 500.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'بيكون بقري مقرمش', 'groupName': 'إكسترا لحوم', 'price': 2000.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'خبز بريوش طازج', 'groupName': 'نوع الخبز', 'price': 1000.0, 'isRequired': false, 'isMultiSelect': false},
          {'name': 'بدون بصل', 'groupName': 'ملاحظات المطبخ', 'price': 0.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'بدون مخلل', 'groupName': 'ملاحظات المطبخ', 'price': 0.0, 'isRequired': false, 'isMultiSelect': true},
        ];
        break;
      case 'shawarma':
        packName = 'باقة المشويات والشاورما العراقي';
        presetItems = [
          {'name': 'ثومية خاصة', 'groupName': 'الصوصات والمقبلات', 'price': 500.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'عمبة عراقية أصلية', 'groupName': 'الصوصات والمقبلات', 'price': 500.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'صوص طحينية ودبس رمان', 'groupName': 'الصوصات والمقبلات', 'price': 500.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'خبز صاج خفيف', 'groupName': 'نوع الخبز', 'price': 0.0, 'isRequired': true, 'isMultiSelect': false},
          {'name': 'صمون حجري طازج', 'groupName': 'نوع الخبز', 'price': 0.0, 'isRequired': true, 'isMultiSelect': false},
          {'name': 'طرشي عراقي مشكل', 'groupName': 'المقبلات', 'price': 1000.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'شحم لية إضافي', 'groupName': 'إكسترا مشويات', 'price': 1500.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'بدون دهن (سادة)', 'groupName': 'ملاحظات المطبخ', 'price': 0.0, 'isRequired': false, 'isMultiSelect': true},
        ];
        break;
      case 'pizza':
        packName = 'باقة البيتزا والمعجنات الإيطالية';
        presetItems = [
          {'name': 'أطراف محشوة جبن', 'groupName': 'نوع العجينة والأطراف', 'price': 2000.0, 'isRequired': false, 'isMultiSelect': false},
          {'name': 'إكسترا موزاريلا', 'groupName': 'إضافات الجبن', 'price': 1500.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'بيبروني إضافي', 'groupName': 'إضافات اللحوم', 'price': 2000.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'فطر طازج ومشروم', 'groupName': 'إضافات الخضار', 'price': 1000.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'زيتون كالاماتا أسود', 'groupName': 'إضافات الخضار', 'price': 500.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'صلصة طماطم خاصة إضافية', 'groupName': 'الصلصات', 'price': 500.0, 'isRequired': false, 'isMultiSelect': true},
        ];
        break;
      case 'cafe':
        packName = 'باقة الكافيه والمشروبات';
        presetItems = [
          {'name': 'شوت إسبريسو إضافي', 'groupName': 'خيارات القهوة', 'price': 1000.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'حليب لوز نباتي', 'groupName': 'نوع الحليب', 'price': 1000.0, 'isRequired': false, 'isMultiSelect': false},
          {'name': 'حليب شوفان', 'groupName': 'نوع الحليب', 'price': 1000.0, 'isRequired': false, 'isMultiSelect': false},
          {'name': 'سيرب كراميل مملح', 'groupName': 'النكهات والسيرب', 'price': 500.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'سيرب فانيلا فرنسية', 'groupName': 'النكهات والسيرب', 'price': 500.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'كريمة مخفوقة', 'groupName': 'إضافات المشروب', 'price': 500.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'قليل السكر', 'groupName': 'تفضيلات التحضير', 'price': 0.0, 'isRequired': false, 'isMultiSelect': true},
        ];
        break;
      case 'kitchen_notes':
        packName = 'باقة الملاحظات والتجهيز المطبخي';
        presetItems = [
          {'name': 'بدون بصل', 'groupName': 'ملاحظات المطبخ', 'price': 0.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'بدون مخلل', 'groupName': 'ملاحظات المطبخ', 'price': 0.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'قليل الملح', 'groupName': 'ملاحظات المطبخ', 'price': 0.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'حار جداً (Extra Spicy)', 'groupName': 'ملاحظات المطبخ', 'price': 0.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'صوص خارجي منفصل', 'groupName': 'ملاحظات المطبخ', 'price': 0.0, 'isRequired': false, 'isMultiSelect': true},
          {'name': 'سفري محكم وتغليف خاص', 'groupName': 'ملاحظات المطبخ', 'price': 0.0, 'isRequired': false, 'isMultiSelect': true},
        ];
        break;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('استيراد $packName', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
          content: Text(
            'سيتم توليد ${presetItems.length} خيارات وإضافات جاهزة تلقائياً في قائمة مطعمك. هل تود المتابعة؟',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              child: Text('استيراد فوري', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (var item in presetItems) {
        final docRef = _modifiersRef().doc();
        final payload = {
          ...item,
          'isActive': true,
          'isOutOfStock': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        batch.set(docRef, payload);
        batch.set(_restaurantModifiersRef().doc(docRef.id), payload);
      }
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم استيراد $packName بنجاح (${presetItems.length} خيارات)', style: GoogleFonts.ibmPlexSansArabic()),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (_) {}
  }

  // ─────────────────────────── تصدير JSON ───────────────────────────

  void _exportModifiersJson(BuildContext context, List<MealModifier> items) {
    final exportData = items.map((i) => i.toMap()).toList();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.code_rounded, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text('تصدير بيانات الإضافات والخيارات (JSON)', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 500,
            height: 350,
            child: SingleChildScrollView(
              child: SelectableText(
                jsonStr,
                style: GoogleFonts.firaCode(fontSize: 11),
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonStr));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم نسخ بيانات JSON إلى الحافظة', style: GoogleFonts.ibmPlexSansArabic())),
                );
                Navigator.pop(ctx);
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text('نسخ للحافظة', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إغلاق', style: GoogleFonts.ibmPlexSansArabic()),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── العمليات الفردية ───────────────────────────

  void _toggleActiveStatus(MealModifier item) async {
    if (_activeId.isEmpty) return;
    try {
      final updateData = {'isActive': !item.isActive};
      await _modifiersRef().doc(item.id).set(updateData, SetOptions(merge: true));
      try {
        await _restaurantModifiersRef().doc(item.id).set(updateData, SetOptions(merge: true));
      } catch (_) {}
    } catch (_) {}
  }

  void _toggleOutOfStock(MealModifier item) async {
    if (_activeId.isEmpty) return;
    try {
      final newStatus = !item.isOutOfStock;
      final updateData = {'isOutOfStock': newStatus};
      await _modifiersRef().doc(item.id).set(updateData, SetOptions(merge: true));
      try {
        await _restaurantModifiersRef().doc(item.id).set(updateData, SetOptions(merge: true));
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus ? 'تم تعيين "${item.name}" كـ غير متوفر مؤقتاً (86)' : 'تمت إعادة "${item.name}" للمخزون المتوفر',
              style: GoogleFonts.ibmPlexSansArabic(),
            ),
            backgroundColor: newStatus ? const Color(0xFFEF4444) : const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  void _confirmDelete(BuildContext context, MealModifier item) {
    final c = context.posColors;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('حذف الإضافة؟', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من حذف خيار "${item.name}"؟', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_activeId.isNotEmpty) {
                  await _modifiersRef().doc(item.id).delete();
                  try {
                    await _restaurantModifiersRef().doc(item.id).delete();
                  } catch (_) {}
                }
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

  Widget _buildEmptyState(BuildContext context) {
    final c = context.posColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tune_rounded, size: 50, color: Color(0xFF6366F1)),
            ),
            const SizedBox(height: 18),
            Text(
              'لا توجد إضافات أو خيارات مسجلة حالياً',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'يمكنك استيراد باقة جاهزة بضغطة زر واحدة أو البدء بإضافة خيارات مخصصة لوجباتك',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                color: c.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _applyPresetPack(context, 'burger'),
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text('استيراد باقة جاهزة سريعة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _showModifierDialog(context, null),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('إضافة خيار يدوياً'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.primary,
                    side: BorderSide(color: c.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFilterResults(BuildContext context) {
    final c = context.posColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.filter_alt_off_rounded, size: 50, color: c.textDisabled),
            const SizedBox(height: 12),
            Text(
              'لا توجد خيارات تطابق معايير البحث أو الفلترة',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: c.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _selectedGroupFilter = 'الكل';
                  _quickFilter = ModifierQuickFilter.all;
                });
              },
              child: Text('إعادة ضبط الفلاتر', style: GoogleFonts.ibmPlexSansArabic(color: c.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
