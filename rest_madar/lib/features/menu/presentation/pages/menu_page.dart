import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/design_system/madar_design_system.dart';
import '../../../../core/responsive/madar_responsive.dart';
import '../../../../core/error/madar_crash_guard.dart';
import '../../../pos/presentation/widgets/quick_add_meal_dialog.dart';
import '../widgets/category_manager_dialog.dart';
import '../widgets/meal_recipe_dialog.dart';
import 'modifiers_page.dart';

/// صفحة إدارة المنتجات والمنيو الحقيقية لنظام مطاعم مدار
/// متصلة 100% بقاعدة بيانات Firestore وخالية تماماً من البيانات الوهمية
class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _effectiveRestaurantId = '';

  String _searchQuery = '';
  String _availabilityFilter = 'all'; // 'all', 'available', 'unavailable'
  String _selectedCategoryFilter = 'all';
  String _sortBy = 'latest'; // 'latest', 'price_asc', 'price_desc', 'name', 'sales'

  Stream<List<_ProductItem>>? _productsStream;

  @override
  void initState() {
    super.initState();
    _effectiveRestaurantId = _uid;
    _initStream();
    _resolveRestaurantId();
  }

  void _initStream() {
    final activeId = _effectiveRestaurantId.isNotEmpty ? _effectiveRestaurantId : _uid;
    _productsStream = _getProductsStream(activeId);
  }

  Future<void> _resolveRestaurantId() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        final rId = (data?['restaurantId'] ?? data?['storeId'] ?? data?['branchId'])?.toString().trim() ?? '';
        if (rId.isNotEmpty && rId != _effectiveRestaurantId) {
          setState(() {
            _effectiveRestaurantId = rId;
            _initStream();
          });
        }
      }
    } catch (_) {}
  }

  /// دمج تدفق المنتجات الحية من مجموعتي merchant_products و restaurants/menu لضمان شمولية المنيو
  Stream<List<_ProductItem>> _getProductsStream(String activeId) {
    if (activeId.isEmpty) {
      return Stream.value(<_ProductItem>[]);
    }

    late StreamController<List<_ProductItem>> controller;
    StreamSubscription? sub1;
    StreamSubscription? sub2;

    final Map<String, _ProductItem> merchantItems = {};
    final Map<String, _ProductItem> menuItems = {};

    void emitMerged() {
      if (!controller.isClosed) {
        // الوجبات من merchant_products تُدمج وتأخذ الأسبقية
        final Map<String, _ProductItem> merged = {...menuItems, ...merchantItems};
        controller.add(merged.values.toList());
      }
    }

    controller = StreamController<List<_ProductItem>>(
      onListen: () {
        sub1 = FirebaseFirestore.instance
            .collection('merchant_products')
            .doc(activeId)
            .collection('products')
            .snapshots()
            .listen((snap) {
          merchantItems.clear();
          for (var doc in snap.docs) {
            merchantItems[doc.id] = _ProductItem.fromFirestore(doc);
          }
          emitMerged();
        }, onError: (_) {
          emitMerged();
        });

        sub2 = FirebaseFirestore.instance
            .collection('restaurants')
            .doc(activeId)
            .collection('menu')
            .snapshots()
            .listen((snap) {
          menuItems.clear();
          for (var doc in snap.docs) {
            menuItems[doc.id] = _ProductItem.fromFirestore(doc);
          }
          emitMerged();
        }, onError: (_) {
          emitMerged();
        });
      },
      onCancel: () {
        sub1?.cancel();
        sub2?.cancel();
      },
    );

    return controller.stream;
  }

  Future<void> _importStarterMenuPack() async {
    final activeId = _effectiveRestaurantId.isNotEmpty ? _effectiveRestaurantId : _uid;
    if (activeId.isEmpty) return;
    HapticFeedback.mediumImpact();

    final starterMeals = [
      {
        'name': 'كباب عراقي مشكل على الفحم',
        'category': 'مشاوي وكباب',
        'price': 14000.0,
        'description': 'سيخين لحم وسيخ دجاج مشوي مع خبز حار، طماطم مشوية، بصل وسماق',
        'code': 'KBB-01',
        'isAvailable': true,
      },
      {
        'name': 'همبرغر لحم دبل كلاسيك',
        'category': 'برجر وسندويشات',
        'price': 8500.0,
        'description': 'شريحتي لحم بقري طازج مع جبن شيدر ذائب وصوص مدار المميز وبطاطا',
        'code': 'BRG-01',
        'isAvailable': true,
      },
      {
        'name': 'شاورما لحم عربي مع الصمون',
        'category': 'شاورما',
        'price': 5000.0,
        'description': 'شاورما لحم غنم مع صوص الطحينية ومخلل خيار وبطاطا مقلية',
        'code': 'SHW-01',
        'isAvailable': true,
      },
      {
        'name': 'بيتزا دجاج رانش إيطالية',
        'category': 'بيتزا وفطائر',
        'price': 12000.0,
        'description': 'عجينة طازجة مع قطع دجاج متبل، صوص رانش، فطر وجبن موزاريلا فاخر',
        'code': 'PZ-01',
        'isAvailable': true,
      },
      {
        'name': 'أصابع بطاطا مقلية مقرمشة (كبير)',
        'category': 'مقبلات وسلطات',
        'price': 3000.0,
        'description': 'بطاطس مقرمشة ذهبية متبلة مع صوص الكاتشب والمايونيز',
        'code': 'APP-01',
        'isAvailable': true,
      },
      {
        'name': 'بيبسي بارد مثلج (علبة 330 مل)',
        'category': 'عصائر ومشروبات باردة',
        'price': 1000.0,
        'description': 'مشروب غازي بيبسي منعش ومثلج',
        'code': 'DRK-01',
        'isAvailable': true,
      },
    ];

    try {
      final batch = FirebaseFirestore.instance.batch();
      final productsRef = FirebaseFirestore.instance
          .collection('merchant_products')
          .doc(activeId)
          .collection('products');

      for (var meal in starterMeals) {
        final doc = productsRef.doc();
        batch.set(doc, {
          ...meal,
          'restaurantId': activeId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'salesCount': 0,
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم استيراد ${starterMeals.length} وجبات نموذجية مقترحة للمطعم بنجاح! 🎉',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الاستيراد: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeCrashBoundary(
          child: StreamBuilder<List<_ProductItem>>(
            stream: _productsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(color: c.primary, strokeWidth: 3),
                );
              }

              if (snapshot.hasError) {
                final info = MadarCrashGuard.analyzeError(snapshot.error);
                return Center(
                  child: MadarInlineErrorCard(
                    errorInfo: info,
                    onRetry: () => setState(() => _initStream()),
                  ),
                );
              }

              final List<_ProductItem> allProducts = snapshot.data ?? [];

              // استخراج التصنيفات الفعلية المتوفرة في المنيو
              final Set<String> dynamicCategories = {'الكل'};
              for (var p in allProducts) {
                if (p.category.trim().isNotEmpty) {
                  dynamicCategories.add(p.category.trim());
                }
              }

              // تطبيق الفلاتر والبحث
              List<_ProductItem> filtered = allProducts.where((p) {
                if (_availabilityFilter == 'available' && !p.isAvailable) return false;
                if (_availabilityFilter == 'unavailable' && p.isAvailable) return false;
                if (_selectedCategoryFilter != 'all' && p.category.trim() != _selectedCategoryFilter.trim()) {
                  return false;
                }
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  final matchName = p.name.toLowerCase().contains(q);
                  final matchCat = p.category.toLowerCase().contains(q);
                  final matchCode = p.code.toLowerCase().contains(q);
                  final matchDesc = p.description.toLowerCase().contains(q);
                  if (!matchName && !matchCat && !matchCode && !matchDesc) return false;
                }
                return true;
              }).toList();

              // تطبيق الترتيب
              switch (_sortBy) {
                case 'price_asc':
                  filtered.sort((a, b) => a.price.compareTo(b.price));
                  break;
                case 'price_desc':
                  filtered.sort((a, b) => b.price.compareTo(a.price));
                  break;
                case 'name':
                  filtered.sort((a, b) => a.name.compareTo(b.name));
                  break;
                case 'sales':
                  filtered.sort((a, b) => b.salesCount.compareTo(a.salesCount));
                  break;
                case 'latest':
                default:
                  filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  break;
              }

              // حساب الإحصائيات الحقيقية بدقة 100%
              final stats = _computeRealProductStats(allProducts);

              return Padding(
                padding: EdgeInsets.all(MadarResponsive.contentPadding(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. ترويسة الصفحة مع أزرار الإضافة والتصنيفات
                    _buildHeader(context),

                    const SizedBox(height: 16),

                    // 2. مؤشرات المنيو الحقيقية
                    _buildKpiMetricsRow(context, stats),

                    const SizedBox(height: 16),

                    // 3. شريط البحث والتصفية المتطورة
                    _buildFilterBar(context, dynamicCategories),

                    const SizedBox(height: 16),

                    // 4. جدول المنتجات الحقيقية أو الحالة الفارغة
                    Expanded(
                      child: _buildProductsTable(
                        context,
                        filtered,
                        isTotalEmpty: allProducts.isEmpty,
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

  // ─────────────────────────── 1. ترويسة الصفحة ───────────────────────────

  Widget _buildHeader(BuildContext context) {
    final c = context.posColors;
    final isNarrow = MediaQuery.of(context).size.width < 800;

    final titleBlock = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.restaurant_menu_rounded, color: c.primary, size: 26),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'إدارة المنيو وقائمة الطعام',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: isNarrow ? 18 : 22,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'إضافة وتعديل وحذف وجبات المطعم، وضبط الأسعار وحالة التوفر اللحظية',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 11.5,
                  color: c.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );

    final actionButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // زر إدارة الأقسام
        OutlinedButton.icon(
          onPressed: () {
            CategoryManagerDialog.show(
              context,
              onUpdated: () {
                if (mounted) setState(() {});
              },
            );
          },
          icon: const Icon(Icons.category_outlined, size: 18),
          label: Text(
            'إدارة الأقسام',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.textPrimary,
            side: BorderSide(color: c.border),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 8),
        // زر إدارة الخيارات والإضافات
        OutlinedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                clipBehavior: Clip.antiAlias,
                child: const ModifiersPage(),
              ),
            );
          },
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: Text(
            'إدارة الإضافات والخيارات',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.textPrimary,
            side: BorderSide(color: c.border),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 10),
        // زر إضافة منتج جديد
        ElevatedButton.icon(
          onPressed: () {
            QuickAddMealDialog.show(
              context,
              onMealSaved: () {
                if (mounted) setState(() {});
              },
            );
          },
          icon: const Icon(Icons.add_circle_outline_rounded, size: 19),
          label: Text(
            '+ إضافة وجبة جديدة',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ],
    );

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleBlock,
          const SizedBox(height: 12),
          actionButtons,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: titleBlock),
        const SizedBox(width: 16),
        actionButtons,
      ],
    );
  }

  // ─────────────────────────── 2. بطاقات مؤشرات المنيو الحقيقية ───────────────────────────

  Widget _buildKpiMetricsRow(BuildContext context, _ProductStats stats) {
    final width = MediaQuery.of(context).size.width;

    final c1 = _buildMetricCard(
      context,
      title: 'إجمالي الوجبات',
      value: '${stats.totalProducts}',
      subtitle: 'أصناف مسجلة بالمنيو',
      icon: Icons.inventory_2_outlined,
      color: const Color(0xFFF59E0B),
      bg: const Color(0xFFFFFBEB),
    );
    final c2 = _buildMetricCard(
      context,
      title: 'الوجبات المتوفرة',
      value: '${stats.availableCount}',
      subtitle: stats.totalProducts > 0
          ? '${((stats.availableCount / stats.totalProducts) * 100).round()}% متاحة للطلب'
          : 'لا توجد وجبات',
      icon: Icons.check_circle_outline_rounded,
      color: const Color(0xFF10B981),
      bg: const Color(0xFFF0FDF4),
    );
    final c3 = _buildMetricCard(
      context,
      title: 'غير متوفرة (نفدت)',
      value: '${stats.unavailableCount}',
      subtitle: stats.unavailableCount > 0 ? 'موقوفة مؤقتاً' : 'الكل متاح',
      icon: Icons.pause_circle_outline_rounded,
      color: const Color(0xFFEF4444),
      bg: const Color(0xFFFEF2F2),
    );
    final c4 = _buildMetricCard(
      context,
      title: 'أكثر الوجبات طلباً',
      value: stats.topSellingOrders > 0 ? stats.topSellingName : '—',
      subtitle: stats.topSellingOrders > 0 ? '${stats.topSellingOrders} طلب مسجل' : 'بانتظار طلبات',
      icon: Icons.local_fire_department_outlined,
      color: const Color(0xFFFF5B22),
      bg: const Color(0xFFFFF7ED),
    );
    final c5 = _buildMetricCard(
      context,
      title: 'عدد الأقسام',
      value: '${stats.categoriesCount}',
      subtitle: 'أقسام طعام نشطة',
      icon: Icons.category_outlined,
      color: const Color(0xFF8B5CF6),
      bg: const Color(0xFFFAF5FF),
    );
    final c6 = _buildMetricCard(
      context,
      title: 'قيمة المنيو التقديرية',
      value: '${_formatAmount(stats.totalPriceSum)} د.ع',
      subtitle: 'مجموع أسعار القائمة',
      icon: Icons.monetization_on_outlined,
      color: const Color(0xFF3B82F6),
      bg: const Color(0xFFEFF6FF),
    );

    if (width >= 1150) {
      return Row(
        children: [
          c1, const SizedBox(width: 10),
          c2, const SizedBox(width: 10),
          c3, const SizedBox(width: 10),
          c4, const SizedBox(width: 10),
          c5, const SizedBox(width: 10),
          c6,
        ],
      );
    } else if (width >= 720) {
      return Column(
        children: [
          Row(children: [c1, const SizedBox(width: 10), c2, const SizedBox(width: 10), c3]),
          const SizedBox(height: 10),
          Row(children: [c4, const SizedBox(width: 10), c5, const SizedBox(width: 10), c6]),
        ],
      );
    } else {
      return Column(
        children: [
          Row(children: [c1, const SizedBox(width: 10), c2]),
          const SizedBox(height: 10),
          Row(children: [c3, const SizedBox(width: 10), c4]),
          const SizedBox(height: 10),
          Row(children: [c5, const SizedBox(width: 10), c6]),
        ],
      );
    }
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    final c = context.posColors;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11,
                      color: c.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: c.textMuted,
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

  // ─────────────────────────── 3. شريط التصفية والبحث ───────────────────────────

  Widget _buildFilterBar(BuildContext context, Set<String> categories) {
    final c = context.posColors;
    final isNarrow = MediaQuery.of(context).size.width < 900;

    final searchField = SizedBox(
      width: isNarrow ? double.infinity : 280,
      height: 38,
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        decoration: InputDecoration(
          hintText: 'ابحث عن وجبة، تصنيف، أو رمز...',
          hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: c.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.primary, width: 1.4)),
        ),
        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5),
      ),
    );

    final filtersWrap = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // فلتر القسم
        PopupMenuButton<String>(
          initialValue: _selectedCategoryFilter,
          tooltip: 'تصفية حسب القسم',
          onSelected: (val) => setState(() => _selectedCategoryFilter = val),
          itemBuilder: (ctx) => categories.map((cat) {
            return PopupMenuItem<String>(
              value: cat == 'الكل' ? 'all' : cat,
              child: Text(
                cat,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12.5,
                  fontWeight: (_selectedCategoryFilter == 'all' && cat == 'الكل') ||
                          _selectedCategoryFilter == cat
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
          child: _buildFilterPill(
            context,
            label: _selectedCategoryFilter == 'all' ? 'جميع الأقسام' : _selectedCategoryFilter,
            icon: Icons.category_rounded,
            isActive: _selectedCategoryFilter != 'all',
          ),
        ),

        // فلتر التوفر
        PopupMenuButton<String>(
          initialValue: _availabilityFilter,
          tooltip: 'حالة التوفر',
          onSelected: (val) => setState(() => _availabilityFilter = val),
          itemBuilder: (ctx) => [
            PopupMenuItem(value: 'all', child: Text('الكل (متوفر وغير متوفر)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12))),
            PopupMenuItem(value: 'available', child: Text('المتوفرة فقط 🟢', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12))),
            PopupMenuItem(value: 'unavailable', child: Text('غير المتوفرة فقط 🔴', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12))),
          ],
          child: _buildFilterPill(
            context,
            label: _getAvailabilityTitle(_availabilityFilter),
            icon: Icons.filter_alt_outlined,
            isActive: _availabilityFilter != 'all',
          ),
        ),

        // الفرز والترتيب
        PopupMenuButton<String>(
          initialValue: _sortBy,
          tooltip: 'ترتيب حسب',
          onSelected: (val) => setState(() => _sortBy = val),
          itemBuilder: (ctx) => [
            PopupMenuItem(value: 'latest', child: Text('الأحدث إضافة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12))),
            PopupMenuItem(value: 'price_asc', child: Text('السعر: من الأقل للأعلى', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12))),
            PopupMenuItem(value: 'price_desc', child: Text('السعر: من الأعلى للأقل', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12))),
            PopupMenuItem(value: 'sales', child: Text('الأكثر مبيعاً وطلباً', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12))),
            PopupMenuItem(value: 'name', child: Text('أبجدياً (أ - ي)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12))),
          ],
          child: _buildFilterPill(
            context,
            label: _getSortTitle(_sortBy),
            icon: Icons.sort_rounded,
            isActive: _sortBy != 'latest',
          ),
        ),

        // زر إعادة ضبط الفلاتر عند تفعيل أي منها
        if (_searchQuery.isNotEmpty || _availabilityFilter != 'all' || _selectedCategoryFilter != 'all' || _sortBy != 'latest')
          TextButton.icon(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _availabilityFilter = 'all';
                _selectedCategoryFilter = 'all';
                _sortBy = 'latest';
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              'إعادة ضبط',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted),
            ),
          ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 10),
                filtersWrap,
              ],
            )
          : Row(
              children: [
                searchField,
                const SizedBox(width: 12),
                Expanded(child: filtersWrap),
              ],
            ),
    );
  }

  Widget _buildFilterPill(BuildContext context, {required String label, required IconData icon, bool isActive = false}) {
    final c = context.posColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? c.primary.withValues(alpha: 0.1) : c.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? c.primary : c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isActive ? c.primary : c.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? c.primary : c.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: isActive ? c.primary : c.textMuted),
        ],
      ),
    );
  }

  // ─────────────────────────── 4. جدول المنتجات الحقيقية ───────────────────────────

  Widget _buildProductsTable(BuildContext context, List<_ProductItem> products, {required bool isTotalEmpty}) {
    final c = context.posColors;

    // في حال عدم وجود منتجات نهائياً في قاعدة البيانات
    if (isTotalEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.restaurant_menu_rounded, size: 48, color: c.primary),
              ),
              const SizedBox(height: 18),
              Text(
                'قائمة طعام مطعمك فارغة حالياً',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'لم يتم العثور على وجبات مسجلة في حسابك.\nأضف وجباتك الأولى لتظهر فوراً في شاشة الكاشير السريع وتطبيق الزبائن والمنيو الرقمي.',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  color: c.textMuted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      QuickAddMealDialog.show(
                        context,
                        onMealSaved: () {
                          if (mounted) setState(() {});
                        },
                      );
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                    label: Text(
                      '+ إضافة أول وجبة الآن',
                      style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  OutlinedButton.icon(
                    onPressed: _importStarterMenuPack,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 19),
                    label: Text(
                      'استيراد وجبات مقترحة (قالب جاهز)',
                      style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.textPrimary,
                      side: BorderSide(color: c.border),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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

    // في حال عدم وجود نتائج تطابق البحث والفلاتر
    if (products.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 50, color: c.textDisabled),
              const SizedBox(height: 14),
              Text(
                'لا توجد وجبات تطابق معايير البحث الحالية',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'جرّب البحث باسم وجبة آخر أو إلغاء فلاتر التوفر والأقسام.',
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: c.textMuted),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _availabilityFilter = 'all';
                    _selectedCategoryFilter = 'all';
                    _sortBy = 'latest';
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(
                  'إلغاء التصفية وعرض الكل',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.primary,
                  side: BorderSide(color: c.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final showSecondary = MediaQuery.of(context).size.width >= 1050;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
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
                _buildHeaderCell('الصورة', flex: 1),
                _buildHeaderCell('اسم الوجبة والرمز', flex: showSecondary ? 3 : 4),
                _buildHeaderCell('القسم / التصنيف', flex: 2),
                _buildHeaderCell('السعر الحالي', flex: 2),
                _buildHeaderCell('حالة التوفر', flex: 2),
                if (showSecondary) _buildHeaderCell('المبيعات', flex: 1),
                if (showSecondary) _buildHeaderCell('تاريخ الإضافة', flex: 2),
                _buildHeaderCell('الإجراءات', flex: 2, alignment: Alignment.center),
              ],
            ),
          ),

          // قائمة الوجبات الحقيقية
          Expanded(
            child: ListView.separated(
              itemCount: products.length,
              separatorBuilder: (_, _) => Divider(color: c.border.withValues(alpha: 0.6), height: 1),
              itemBuilder: (context, index) {
                final product = products[index];

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // 1. الصورة
                      Expanded(
                        flex: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 44,
                            height: 44,
                            color: c.background,
                            child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                                ? Image.network(
                                    product.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Center(
                                      child: Icon(Icons.fastfood_rounded, color: c.primary, size: 22),
                                    ),
                                  )
                                : Center(
                                    child: Icon(Icons.fastfood_rounded, color: c.primary, size: 22),
                                  ),
                          ),
                        ),
                      ),

                      // 2. الاسم والرمز
                      Expanded(
                        flex: showSecondary ? 3 : 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Text(
                                  product.code,
                                  style: const TextStyle(
                                    fontFamily: 'Consolas',
                                    fontSize: 10.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                if (product.description.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      product.description,
                                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textMuted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 3. التصنيف
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _buildCategoryBadge(context, product.category),
                        ),
                      ),

                      // 4. السعر
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${_formatAmount(product.price)} د.ع',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                      ),

                      // 5. مفتاح التوفر الفوري
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Switch(
                              value: product.isAvailable,
                              onChanged: (val) => _toggleAvailability(product.id, val),
                              activeThumbColor: const Color(0xFF10B981),
                              inactiveThumbColor: const Color(0xFFEF4444),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              product.isAvailable ? 'متوفر' : 'غير متوفر',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: product.isAvailable ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 6. المبيعات / عدد الطلبات
                      if (showSecondary)
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${product.salesCount}',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                        ),

                      // 7. تاريخ الإضافة
                      if (showSecondary)
                        Expanded(
                          flex: 2,
                          child: Text(
                            DateFormat('yyyy/MM/dd').format(product.createdAt),
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11.5,
                              color: c.textMuted,
                            ),
                          ),
                        ),

                      // 8. إجراءات (تعديل وحذف)
                      Expanded(
                        flex: 2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.soup_kitchen_rounded, size: 18, color: Color(0xFF10B981)),
                              tooltip: 'مكونات الوجبة والخصم من المخزون',
                              onPressed: () {
                                MealRecipeDialog.show(
                                  context,
                                  restaurantId: _effectiveRestaurantId.isNotEmpty ? _effectiveRestaurantId : _uid,
                                  mealId: product.id,
                                  mealName: product.name,
                                  mealPrice: product.price,
                                );
                              },
                              splashRadius: 18,
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF3B82F6)),
                              tooltip: 'تعديل بيانات الوجبة',
                              onPressed: () {
                                QuickAddMealDialog.show(
                                  context,
                                  initialMealId: product.id,
                                  initialMealData: product.rawData,
                                  onMealSaved: () {
                                    if (mounted) setState(() {});
                                  },
                                );
                              },
                              splashRadius: 18,
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                              tooltip: 'حذف من المنيو',
                              onPressed: () => _deleteProduct(product.id, product.name),
                              splashRadius: 18,
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
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title, {required int flex, Alignment alignment = Alignment.centerRight}) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignment,
        child: Text(
          title,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF8B95A5),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── إجراءات التعديل والحذف ───────────────────────────

  Future<void> _toggleAvailability(String productId, bool newVal) async {
    final activeId = _effectiveRestaurantId.isNotEmpty ? _effectiveRestaurantId : _uid;
    HapticFeedback.selectionClick();

    try {
      await FirebaseFirestore.instance
          .collection('merchant_products')
          .doc(activeId)
          .collection('products')
          .doc(productId)
          .update({'isAvailable': newVal});
    } catch (_) {}

    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(activeId)
          .collection('menu')
          .doc(productId)
          .update({'isAvailable': newVal});
    } catch (_) {}
  }

  Future<void> _deleteProduct(String productId, String productName) async {
    final activeId = _effectiveRestaurantId.isNotEmpty ? _effectiveRestaurantId : _uid;
    final c = context.posColors;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          title: Text(
            'حذف الوجبة من المنيو؟',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في حذف "$productName" نهائياً؟ لن تظهر مجدداً في الكاشير أو تطبيق الزبائن.',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              child: Text(
                'تأكيد الحذف',
                style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('merchant_products')
            .doc(activeId)
            .collection('products')
            .doc(productId)
            .delete();
      } catch (_) {}

      try {
        await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(activeId)
            .collection('menu')
            .doc(productId)
            .delete();
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف الوجبة "$productName" من المنيو بنجاح', style: GoogleFonts.ibmPlexSansArabic()),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  // ─────────────────────────── أدوات المساعدة والبيانات الحقيقية ───────────────────────────

  Widget _buildCategoryBadge(BuildContext context, String cat) {
    Color bg;
    Color text;

    switch (cat) {
      case 'برغر':
      case 'برجر':
        bg = const Color(0xFFFFF7ED);
        text = const Color(0xFFFF5B22);
        break;
      case 'بيتزا':
        bg = const Color(0xFFFEF2F2);
        text = const Color(0xFFEF4444);
        break;
      case 'شاورما':
        bg = const Color(0xFFFAF5FF);
        text = const Color(0xFF8B5CF6);
        break;
      case 'وجبات':
      case 'وجبات رئيسية':
        bg = const Color(0xFFFFFBEB);
        text = const Color(0xFFF59E0B);
        break;
      case 'مقبلات':
        bg = const Color(0xFFF0FDF4);
        text = const Color(0xFF10B981);
        break;
      case 'مشروبات':
      case 'عصائر':
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF3B82F6);
        break;
      case 'مشاوي':
        bg = const Color(0xFFFEF2F2);
        text = const Color(0xFFDC2626);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        cat,
        style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.w700, color: text),
      ),
    );
  }

  String _getAvailabilityTitle(String filter) {
    switch (filter) {
      case 'available':
        return 'المتوفرة فقط';
      case 'unavailable':
        return 'غير المتوفرة فقط';
      default:
        return 'كل حالات التوفر';
    }
  }

  String _getSortTitle(String sort) {
    switch (sort) {
      case 'price_asc':
        return 'السعر: الأقل أولاً';
      case 'price_desc':
        return 'السعر: الأعلى أولاً';
      case 'sales':
        return 'الأكثر طلباً';
      case 'name':
        return 'أبجدياً';
      case 'latest':
      default:
        return 'الأحدث أولاً';
    }
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,###').format(amount);
  }

  /// حساب المؤشرات الحسابية الحقيقية 100% دون أي أرقام مفبركة
  _ProductStats _computeRealProductStats(List<_ProductItem> items) {
    int available = 0;
    int unavailable = 0;
    double totalPriceSum = 0;
    final Set<String> cats = {};
    String topName = '—';
    int topOrders = 0;

    for (var item in items) {
      if (item.isAvailable) {
        available++;
      } else {
        unavailable++;
      }
      if (item.category.trim().isNotEmpty) {
        cats.add(item.category.trim());
      }
      totalPriceSum += item.price;
      if (item.salesCount > topOrders) {
        topOrders = item.salesCount;
        topName = item.name;
      }
    }

    return _ProductStats(
      totalProducts: items.length,
      availableCount: available,
      unavailableCount: unavailable,
      topSellingName: topName,
      topSellingOrders: topOrders,
      categoriesCount: cats.length,
      totalPriceSum: totalPriceSum,
    );
  }
}

/// كائن بيانات الوجبة الحقيقية
class _ProductItem {
  final String id;
  final String code;
  final String name;
  final String category;
  final double price;
  final bool isAvailable;
  final int salesCount;
  final DateTime createdAt;
  final String? imageUrl;
  final String description;
  final Map<String, dynamic> rawData;

  _ProductItem({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.price,
    required this.isAvailable,
    required this.salesCount,
    required this.createdAt,
    this.imageUrl,
    this.description = '',
    required this.rawData,
  });

  factory _ProductItem.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};

    double parsePrice(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) {
        final clean = val.replaceAll(',', '').replaceAll('د.ع', '').trim();
        return double.tryParse(clean) ?? 0.0;
      }
      return 0.0;
    }

    int parseSales(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    DateTime dt = DateTime.now();
    if (d['createdAt'] is Timestamp) {
      dt = (d['createdAt'] as Timestamp).toDate();
    } else if (d['createdAt'] is String) {
      dt = DateTime.tryParse(d['createdAt'] as String) ?? DateTime.now();
    } else if (d['createdAt'] is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(d['createdAt'] as int);
    }

    final id = doc.id;
    final code = (d['code'] ?? '#PRD-${id.substring(0, math.min(id.length, 4)).toUpperCase()}').toString();
    final name = (d['name'] ?? d['title'] ?? 'وجبة').toString();
    final category = (d['category'] ?? 'عام').toString().trim();
    final price = parsePrice(d['price'] ?? d['sellingPrice']);
    final isAvailable = d['isAvailable'] != false;
    final sales = parseSales(d['salesCount'] ?? d['ordersCount']);
    final imageUrl = (d['imageUrl'] ?? d['photoUrl'])?.toString();
    final description = (d['description'] ?? '').toString();

    return _ProductItem(
      id: id,
      code: code,
      name: name,
      category: category.isEmpty ? 'عام' : category,
      price: price,
      isAvailable: isAvailable,
      salesCount: sales,
      createdAt: dt,
      imageUrl: imageUrl,
      description: description,
      rawData: d,
    );
  }
}

class _ProductStats {
  final int totalProducts;
  final int availableCount;
  final int unavailableCount;
  final String topSellingName;
  final int topSellingOrders;
  final int categoriesCount;
  final double totalPriceSum;

  _ProductStats({
    required this.totalProducts,
    required this.availableCount,
    required this.unavailableCount,
    required this.topSellingName,
    required this.topSellingOrders,
    required this.categoriesCount,
    required this.totalPriceSum,
  });
}