import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../utils/category_icon_helper.dart';
import '../../services/audit_log_service.dart';
import '../../services/thermal_printer_service.dart';
import '../../features/pos/application/pos_provider.dart';
import '../../features/pos/presentation/widgets/manager_pin_dialog.dart';
import '../../features/pos/presentation/widgets/quick_add_meal_dialog.dart';

/// وصف وجهة داخل النظام (صفحة أو وجبة أو إجراء سريع)
class _PaletteItem {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PaletteItem({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

/// البحث الشامل السريع (Ctrl+K):
/// تنقل بين أقسام النظام + بحث فوري في الوجبات وإضافتها للسلة + إجراءات سريعة
/// — كلها واجهة فقط، بدون أي تغيير على قواعد البيانات.
class PosCommandPalette extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  final VoidCallback? onOpenStore;

  const PosCommandPalette({
    super.key,
    required this.onNavigate,
    this.onOpenStore,
  });

  /// فتح اللوحة عبر حوار غير شفاف
  static Future<void> show(
    BuildContext context, {
    required ValueChanged<int> onNavigate,
    VoidCallback? onOpenStore,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => PosCommandPalette(
        onNavigate: onNavigate,
        onOpenStore: onOpenStore,
      ),
    );
  }

  @override
  State<PosCommandPalette> createState() => _PosCommandPaletteState();
}

class _PosCommandPaletteState extends State<PosCommandPalette> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _debounce;
  List<Map<String, dynamic>> _mealResults = [];
  bool _searchingMeals = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String val) {
    setState(() => _query = val.trim().toLowerCase());
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _searchMeals(_query);
    });
  }

  Future<void> _searchMeals(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _mealResults = [];
          _searchingMeals = false;
        });
      }
      return;
    }
    setState(() => _searchingMeals = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final snap = await FirebaseFirestore.instance
          .collection('merchant_products')
          .doc(uid)
          .collection('products')
          .limit(30)
          .get();
      if (!mounted) return;
      final results = snap.docs.where((doc) {
        final name = (doc.data()['name'] ?? '').toString().toLowerCase();
        final cat = (doc.data()['category'] ?? '').toString().toLowerCase();
        return name.contains(query) || cat.contains(query);
      }).map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'name': d['name'] ?? 'وجبة',
          'price': (d['price'] ?? 0).toDouble(),
          'category': d['category'] ?? '',
          'imageUrl': d['imageUrl'] ?? d['photoUrl'],
        };
      }).toList();
      setState(() {
        _mealResults = results;
        _searchingMeals = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searchingMeals = false);
    }
  }

  void _navigateAndClose(int index) {
    Navigator.of(context).pop();
    widget.onNavigate(index);
  }

  Future<void> _openDrawer() async {
    Navigator.of(context).pop();
    final auth = await ManagerPinDialog.show(
      context,
      title: 'فتح درج الكاشير',
      actionDescription: 'فتح درج النقد يدوياً بدون عملية بيع',
      requireReason: true,
    );
    if (auth != null && auth.success) {
      await ThermalPrinterService.kickCashDrawer();
      await AuditLogService.instance.log(
        action: AuditLogAction.cashDrawerManualOpen,
        targetType: 'cash_drawer',
        targetId: 'drawer_manual',
        beforeState: 'closed',
        afterState: 'opened',
        reason: auth.reason,
        managerPinVerified: true,
      );
    }
  }

  List<_PaletteItem> get _destinations => [
        _PaletteItem(
          title: 'الرئيسية',
          subtitle: 'لوحة المتابعة الشاملة للمطعم',
          icon: Icons.home_rounded,
          color: const Color(0xFF26A69A),
          onTap: () => _navigateAndClose(0),
        ),
        _PaletteItem(
          title: 'نقطة البيع السريع',
          subtitle: 'شاشة الكاشير الرئيسية',
          icon: Icons.point_of_sale_rounded,
          color: const Color(0xFF00BFA5),
          onTap: () => _navigateAndClose(1),
        ),
        _PaletteItem(
          title: 'طلبات مدار الحية',
          subtitle: 'استقبال طلبات التطبيق والمطبخ',
          icon: Icons.delivery_dining_rounded,
          color: const Color(0xFFFFB300),
          onTap: () => _navigateAndClose(2),
        ),
        _PaletteItem(
          title: 'إدارة الطاولات',
          subtitle: 'الطاولات ومنيو QR',
          icon: Icons.table_restaurant_rounded,
          color: const Color(0xFFFF7043),
          onTap: () => _navigateAndClose(3),
        ),
        _PaletteItem(
          title: 'قائمة المنيو',
          subtitle: 'إدارة الوجبات والأقسام والأسعار',
          icon: Icons.restaurant_menu_rounded,
          color: const Color(0xFF26A69A),
          onTap: () => _navigateAndClose(4),
        ),
        _PaletteItem(
          title: 'الوردية والجرد',
          subtitle: 'فتح/إغلاق الوردية وتقارير الكاش',
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFFAB47BC),
          onTap: () => _navigateAndClose(5),
        ),
        _PaletteItem(
          title: 'التقارير والتحليلات',
          subtitle: 'المبيعات والأرباح وإحصائيات المطعم',
          icon: Icons.analytics_rounded,
          color: const Color(0xFF42A5F5),
          onTap: () => _navigateAndClose(6),
        ),
      ];

  List<_PaletteItem> get _quickActions => [
        _PaletteItem(
          title: 'فتح درج النقد',
          subtitle: 'بمحاذاة رمز مدير + توثيق تدقيق',
          icon: Icons.archive_outlined,
          color: const Color(0xFFF9A825),
          onTap: _openDrawer,
        ),
        _PaletteItem(
          title: 'إضافة وجبة جديدة',
          subtitle: 'إضافة سريعة للمنيو',
          icon: Icons.add_rounded,
          color: const Color(0xFF26A69A),
          onTap: () {
            Navigator.of(context).pop();
            QuickAddMealDialog.show(context);
          },
        ),
        if (widget.onOpenStore != null)
          _PaletteItem(
            title: 'عرض المتجر (معاينة الزبائن)',
            subtitle: 'معاينة المنيو والطلب، فتح الرابط بالمتصفح ورمز QR',
            icon: Icons.storefront_rounded,
            color: const Color(0xFFFF5B22),
            onTap: () {
              Navigator.of(context).pop();
              widget.onOpenStore!();
            },
          ),
        _PaletteItem(
          title: 'تبديل هوية المظهر',
          subtitle: 'فاتح / داكن',
          icon: Icons.contrast_rounded,
          color: const Color(0xFF7E57C2),
          onTap: () {
            PosThemeController.instance.toggle();
            setState(() {});
          },
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;
    final meals = _mealResults;

    final navResults = _query.isEmpty
        ? <_PaletteItem>[]
        : _destinations
            .where((d) =>
                d.title.toLowerCase().contains(_query) ||
                (d.subtitle ?? '').toLowerCase().contains(_query))
            .toList();

    final actions = _query.isEmpty ? _quickActions : <_PaletteItem>[];

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // شريط البحث العلوي
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: c.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      onChanged: _onQueryChanged,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: c.textPrimary,
                        fontSize: 14.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن صفحة، وجبة، طلب... (ESC للإغلاق)',
                        hintStyle: GoogleFonts.ibmPlexSansArabic(
                          color: c.textDisabled,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: c.border),
                    ),
                    child: Text(
                      'Ctrl+K',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: c.textDisabled,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (navResults.isNotEmpty) ...[
                      _sectionLabel(context, 'التنقل السريع'),
                      ...navResults.map((e) => _itemTile(context, e)),
                    ],

                    if (actions.isNotEmpty && navResults.isEmpty) ...[
                      _sectionLabel(context, 'إجراءات سريعة'),
                      ...actions.map((e) => _itemTile(context, e)),
                    ],

                    if (_query.isNotEmpty) ...[
                      if (_searchingMeals)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      else if (meals.isNotEmpty) ...[
                        _sectionLabel(context, 'الوجبات (${meals.length})'),
                        ...meals.map((m) => _mealTile(context, m)),
                      ] else if (navResults.isEmpty) ...[
                        _sectionLabel(context, 'البحث في الوجبات'),
                        const SizedBox(height: 4),
                        Text(
                          'لا توجد نتائج مطابقة لـ "$_query"',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: c.textMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ],

                    if (_query.isEmpty && navResults.isEmpty && actions.isEmpty) ...[
                      _sectionLabel(context, 'أقسام النظام'),
                      ..._destinations.map((e) => _itemTile(context, e)),
                      _sectionLabel(context, 'إجراءات سريعة'),
                      ...actions.map((e) => _itemTile(context, e)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String title) {
    final c = context.posColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      child: Text(
        title,
        style: GoogleFonts.ibmPlexSansArabic(
          color: c.textMuted,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _itemTile(BuildContext context, _PaletteItem item) {
    final c = context.posColors;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(item.icon, size: 18, color: item.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (item.subtitle != null)
                    Text(
                      item.subtitle!,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: c.textMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: c.textDisabled),
          ],
        ),
      ),
    );
  }

  Widget _mealTile(BuildContext context, Map<String, dynamic> meal) {
    final c = context.posColors;
    final name = meal['name']?.toString() ?? 'وجبة';
    final price = (meal['price'] as num?)?.toDouble() ?? 0;
    final imageUrl = meal['imageUrl']?.toString();

    return InkWell(
      onTap: () {
        final pos = context.read<PosProvider>();
        pos.addToCart(
          mealId: meal['id']?.toString() ?? '',
          name: name,
          unitPrice: price,
          imageUrl: imageUrl,
        );
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تمت إضافة «$name» إلى السلة ✓'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 34,
                        height: 34,
                        color: c.background,
                        child: Icon(
                          CategoryIconHelper.getIconForCategory(meal['category']?.toString() ?? ''),
                          size: 17,
                          color: c.primary,
                        ),
                      ),
                    )
                  : Container(
                      width: 34,
                      height: 34,
                      color: c.background,
                      child: Icon(
                        CategoryIconHelper.getIconForCategory(meal['category']?.toString() ?? ''),
                        size: 17,
                        color: c.primary,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${price.toStringAsFixed(0)} د.ع • ${meal['category'] ?? ''}',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: c.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_shopping_cart_rounded, size: 14, color: c.accent),
                  const SizedBox(width: 4),
                  Text(
                    'أضف',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: c.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// اختصار لوحة المفاتيح العام: Ctrl+K لفتح البحث الشامل السريع
class PosCommandPaletteShortcut extends StatefulWidget {
  final Widget child;
  final ValueChanged<int> onNavigate;

  const PosCommandPaletteShortcut({
    super.key,
    required this.child,
    required this.onNavigate,
  });

  @override
  State<PosCommandPaletteShortcut> createState() =>
      _PosCommandPaletteShortcutState();
}

class _PosCommandPaletteShortcutState extends State<PosCommandPaletteShortcut> {
  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            () => PosCommandPalette.show(
                  context,
                  onNavigate: widget.onNavigate,
                ),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            () => PosCommandPalette.show(
                  context,
                  onNavigate: widget.onNavigate,
                ),
      },
      child: Focus(
        autofocus: true,
        child: widget.child,
      ),
    );
  }
}