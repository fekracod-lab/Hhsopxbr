import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/error/madar_crash_guard.dart';
import '../../../../core/utils/category_icon_helper.dart';
import '../../../../core/design_system/widgets/madar_side_sheet.dart';

/// نموذج تصنيف وقسم المنيو المتطور والشامل
class MenuCategory {
  final String id;
  final String name;
  final String? nameEn;
  final String? code;
  final IconData icon;
  final Color color;
  final int displayOrder;
  final bool isActive;
  final int productsCount;
  final String? kitchenStation; // محطة المطبخ (مطبخ رئيسي، شواية، مشروبات، فرن، إلخ)
  final double? discountPercent; // نسبة خصم ترويجية على مستوى القسم بالكامل
  final bool discountActive; // هل الخصم مفعل حالياً
  final bool isScheduleEnabled; // هل جدول الساعات مفعل
  final String? availableFrom; // مثلاً 07:00
  final String? availableTo; // مثلاً 12:00

  const MenuCategory({
    required this.id,
    required this.name,
    this.nameEn,
    this.code,
    required this.icon,
    required this.color,
    this.displayOrder = 0,
    this.isActive = true,
    this.productsCount = 0,
    this.kitchenStation,
    this.discountPercent,
    this.discountActive = false,
    this.isScheduleEnabled = false,
    this.availableFrom,
    this.availableTo,
  });

  bool get hasActiveDiscount => discountActive && (discountPercent != null && discountPercent! > 0);

  bool get isCurrentlyInSchedule {
    if (!isScheduleEnabled || availableFrom == null || availableTo == null) return true;
    try {
      final now = TimeOfDay.now();
      final nowMinutes = now.hour * 60 + now.minute;

      final fromParts = availableFrom!.split(':');
      final toParts = availableTo!.split(':');

      final fromMinutes = int.parse(fromParts[0]) * 60 + int.parse(fromParts[1]);
      final toMinutes = int.parse(toParts[0]) * 60 + int.parse(toParts[1]);

      if (fromMinutes <= toMinutes) {
        return nowMinutes >= fromMinutes && nowMinutes <= toMinutes;
      } else {
        // فترات تعبر منتصف الليل (مثل 22:00 إلى 04:00)
        return nowMinutes >= fromMinutes || nowMinutes <= toMinutes;
      }
    } catch (_) {
      return true;
    }
  }

  MenuCategory copyWith({
    String? id,
    String? name,
    String? nameEn,
    String? code,
    IconData? icon,
    Color? color,
    int? displayOrder,
    bool? isActive,
    int? productsCount,
    String? kitchenStation,
    double? discountPercent,
    bool? discountActive,
    bool? isScheduleEnabled,
    String? availableFrom,
    String? availableTo,
  }) {
    return MenuCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      nameEn: nameEn ?? this.nameEn,
      code: code ?? this.code,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      productsCount: productsCount ?? this.productsCount,
      kitchenStation: kitchenStation ?? this.kitchenStation,
      discountPercent: discountPercent ?? this.discountPercent,
      discountActive: discountActive ?? this.discountActive,
      isScheduleEnabled: isScheduleEnabled ?? this.isScheduleEnabled,
      availableFrom: availableFrom ?? this.availableFrom,
      availableTo: availableTo ?? this.availableTo,
    );
  }

  factory MenuCategory.fromFirestore(DocumentSnapshot doc, int count) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final iconCode = data['iconCode'] as int? ?? Icons.fastfood_rounded.codePoint;
    final colorVal = data['colorValue'] as int? ?? 0xFFFF5B22;

    return MenuCategory(
      id: doc.id,
      name: data['name'] ?? 'تصنيف',
      nameEn: data['nameEn'],
      code: data['code'],
      icon: IconData(iconCode, fontFamily: 'MaterialIcons'),
      color: Color(colorVal),
      displayOrder: data['displayOrder'] ?? 0,
      isActive: data['isActive'] ?? true,
      productsCount: count,
      kitchenStation: data['kitchenStation'],
      discountPercent: (data['discountPercent'] as num?)?.toDouble(),
      discountActive: data['discountActive'] as bool? ?? false,
      isScheduleEnabled: data['isScheduleEnabled'] as bool? ?? false,
      availableFrom: data['availableFrom'] as String?,
      availableTo: data['availableTo'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nameEn': nameEn,
      'code': code,
      'displayOrder': displayOrder,
      'isActive': isActive,
      'kitchenStation': kitchenStation,
      'discountPercent': discountPercent,
      'discountActive': discountActive,
      'isScheduleEnabled': isScheduleEnabled,
      'availableFrom': availableFrom,
      'availableTo': availableTo,
    };
  }
}

/// شاشة إدارة تصنيفات وأقسام المنيو الاحترافية لمنظومة مدار
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _effectiveRestaurantId = '';
  String _searchQuery = '';
  String _filterTab = 'all'; // 'all', 'active', 'hidden', 'with_meals', 'empty', 'discount'
  String _viewMode = 'grid'; // 'grid', 'table'
  String _sortBy = 'order'; // 'order', 'meals_desc', 'name'
  bool _isReorderLoading = false;
  bool _isReorderModeActive = false; // وضع السحب والإفلات

  // تحديد جماعي للأقسام
  final Set<String> _selectedCategoryIds = {};

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

  // باقات الأقسام الشاملة والجاهزة للاستيراد المباشر
  static const List<Map<String, dynamic>> _presetPacks = [
    {
      'title': 'باقة مطعم عراقي ومشويات 🍢',
      'desc': 'مشاوي، قوزي، كباب، مقبلات، وشوربات',
      'items': [
        {'name': 'وجبات رئيسية وقوزي', 'icon': Icons.dinner_dining_rounded, 'color': 0xFFFF5B22, 'station': 'المطبخ الرئيسي 👨‍🍳'},
        {'name': 'مشاوي وكباب عراقي', 'icon': Icons.outdoor_grill_rounded, 'color': 0xFFEA580C, 'station': 'شواية الفحم والمشاوي 🔥'},
        {'name': 'شاورما وقص', 'icon': Icons.kebab_dining_rounded, 'color': 0xFFD97706, 'station': 'سيخ الشاورما 🌯'},
        {'name': 'مقبلات وسلطات', 'icon': Icons.dining_rounded, 'color': 0xFF10B981, 'station': 'محطة المقبلات والبارد 🥗'},
        {'name': 'شوربات وتمن ومرق', 'icon': Icons.soup_kitchen_rounded, 'color': 0xFFF59E0B, 'station': 'المطبخ الرئيسي 👨‍🍳'},
        {'name': 'خبز وتنور وصمون', 'icon': Icons.bakery_dining_rounded, 'color': 0xFFB45309, 'station': 'فرن البيتزا والمعجنات 🍕'},
        {'name': 'عصائر ولبن أربيل', 'icon': Icons.local_drink_rounded, 'color': 0xFF0284C7, 'station': 'محطة المشروبات والقهوة 🥤'},
        {'name': 'حلويات وشاي مخدر', 'icon': Icons.local_cafe_rounded, 'color': 0xFF8B5CF6, 'station': 'محطة المشروبات والقهوة 🥤'},
      ],
    },
    {
      'title': 'باقة برغر ووجبات سريعة 🍔',
      'desc': 'برغر لحم، دجاج، كرسبي، بطاطس ومشروبات',
      'items': [
        {'name': 'برغر لحم كلاسيك', 'icon': Icons.lunch_dining_rounded, 'color': 0xFFFF5B22, 'station': 'خط القلي والبرغر 🍔'},
        {'name': 'برغر دجاج وزنجر', 'icon': Icons.fastfood_rounded, 'color': 0xFFEA580C, 'station': 'خط القلي والبرغر 🍔'},
        {'name': 'ستربس وكرسبي', 'icon': Icons.restaurant_rounded, 'color': 0xFFF59E0B, 'station': 'خط القلي والبرغر 🍔'},
        {'name': 'بطاطا ومقبلات مقلية', 'icon': Icons.ramen_dining_rounded, 'color': 0xFFEAB308, 'station': 'خط القلي والبرغر 🍔'},
        {'name': 'صوصات وإضافات خاصة', 'icon': Icons.soup_kitchen_rounded, 'color': 0xFF10B981, 'station': 'محطة التجهيز والتغليف 📦'},
        {'name': 'بوكسات ووجبات عائلية', 'icon': Icons.inventory_2_rounded, 'color': 0xFF6366F1, 'station': 'محطة التجهيز والتغليف 📦'},
        {'name': 'مشروبات غازية وباردة', 'icon': Icons.local_drink_rounded, 'color': 0xFF0284C7, 'station': 'محطة المشروبات والقهوة 🥤'},
        {'name': 'ميلك شيك وآيس كريم', 'icon': Icons.icecream_rounded, 'color': 0xFFEC4899, 'station': 'ركن الحلويات والآيس كريم 🍰'},
      ],
    },
    {
      'title': 'باقة كافيه ومشروبات ☕',
      'desc': 'إسبريسو، قهوة مثلجة، شاي، وحلويات',
      'items': [
        {'name': 'قهوة ساخنة وإسبريسو', 'icon': Icons.local_cafe_rounded, 'color': 0xFF78350F, 'station': 'محطة المشروبات والقهوة 🥤'},
        {'name': 'قهوة مثلجة وآيس كوفي', 'icon': Icons.emoji_food_beverage_rounded, 'color': 0xFF0284C7, 'station': 'محطة المشروبات والقهوة 🥤'},
        {'name': 'شاي ومشروبات عشبية', 'icon': Icons.coffee_rounded, 'color': 0xFF16A34A, 'station': 'محطة المشروبات والقهوة 🥤'},
        {'name': 'عصائر طازجة وسموذي', 'icon': Icons.local_bar_rounded, 'color': 0xFFF59E0B, 'station': 'محطة المشروبات والقهوة 🥤'},
        {'name': 'كيك وتشيز كيك', 'icon': Icons.cake_rounded, 'color': 0xFF9333EA, 'station': 'ركن الحلويات والآيس كريم 🍰'},
        {'name': 'وافل وبانكيك وكريب', 'icon': Icons.cookie_rounded, 'color': 0xFFD97706, 'station': 'ركن الحلويات والآيس كريم 🍰'},
        {'name': 'كرواسون ومخبوزات', 'icon': Icons.bakery_dining_rounded, 'color': 0xFFCA8A04, 'station': 'فرن البيتزا والمعجنات 🍕'},
      ],
    },
    {
      'title': 'باقة بيتزا ومعجنات إيطالية 🍕',
      'desc': 'بيتزا، باستا، كالزوني، وسلطات',
      'items': [
        {'name': 'بيتزا كلاسيك وإيطالية', 'icon': Icons.local_pizza_rounded, 'color': 0xFFE11D48, 'station': 'فرن البيتزا والمعجنات 🍕'},
        {'name': 'باستا ومعكرونة', 'icon': Icons.soup_kitchen_rounded, 'color': 0xFFEA580C, 'station': 'المطبخ الرئيسي 👨‍🍳'},
        {'name': 'فطائر وكالزوني', 'icon': Icons.bakery_dining_rounded, 'color': 0xFFD97706, 'station': 'فرن البيتزا والمعجنات 🍕'},
        {'name': 'لازانيا وغراتان', 'icon': Icons.dinner_dining_rounded, 'color': 0xFFF59E0B, 'station': 'فرن البيتزا والمعجنات 🍕'},
        {'name': 'أجنحة دجاج ومقبلات', 'icon': Icons.set_meal_rounded, 'color': 0xFF10B981, 'station': 'المطبخ الرئيسي 👨‍🍳'},
        {'name': 'سلطات إيطالية', 'icon': Icons.dining_rounded, 'color': 0xFF059669, 'station': 'محطة المقبلات والبارد 🥗'},
        {'name': 'مشروبات ومياه غازية', 'icon': Icons.local_drink_rounded, 'color': 0xFF0284C7, 'station': 'محطة المشروبات والقهوة 🥤'},
      ],
    },
  ];

  // أيقونات منظمة للتصنيفات
  static const List<Map<String, dynamic>> _culinaryIcons = [
    {'name': 'وجبات رئيسية', 'icon': Icons.dinner_dining_rounded, 'group': 'وجبات'},
    {'name': 'برغر وسندويتش', 'icon': Icons.lunch_dining_rounded, 'group': 'وجبات'},
    {'name': 'وجبات سريعة', 'icon': Icons.fastfood_rounded, 'group': 'وجبات'},
    {'name': 'مشويات وكباب', 'icon': Icons.outdoor_grill_rounded, 'group': 'لحوم'},
    {'name': 'كباب وشاورما', 'icon': Icons.kebab_dining_rounded, 'group': 'لحوم'},
    {'name': 'دجاج وبروستد', 'icon': Icons.restaurant_rounded, 'group': 'لحوم'},
    {'name': 'أسماك وبحريات', 'icon': Icons.phishing_rounded, 'group': 'لحوم'},
    {'name': 'بيتزا إيطالية', 'icon': Icons.local_pizza_rounded, 'group': 'معجنات'},
    {'name': 'باستا ومعكرونة', 'icon': Icons.soup_kitchen_rounded, 'group': 'معجنات'},
    {'name': 'مخبوزات وتنور', 'icon': Icons.bakery_dining_rounded, 'group': 'معجنات'},
    {'name': 'مقبلات وسلطات', 'icon': Icons.dining_rounded, 'group': 'مقبلات'},
    {'name': 'شوربات وأطباق', 'icon': Icons.ramen_dining_rounded, 'group': 'مقبلات'},
    {'name': 'أطباق صحية', 'icon': Icons.eco_rounded, 'group': 'مقبلات'},
    {'name': 'عصائر ومشروبات', 'icon': Icons.local_drink_rounded, 'group': 'مشروبات'},
    {'name': 'قهوة وشاي', 'icon': Icons.local_cafe_rounded, 'group': 'مشروبات'},
    {'name': 'مشروبات باردة', 'icon': Icons.local_bar_rounded, 'group': 'مشروبات'},
    {'name': 'حلويات وتورتة', 'icon': Icons.cake_rounded, 'group': 'حلويات'},
    {'name': 'آيس كريم ومثلجات', 'icon': Icons.icecream_rounded, 'group': 'حلويات'},
    {'name': 'وافل وبسكويت', 'icon': Icons.cookie_rounded, 'group': 'حلويات'},
    {'name': 'بوكسات وطلبات خاصة', 'icon': Icons.inventory_2_rounded, 'group': 'أخرى'},
    {'name': 'عروض ووجبات توفير', 'icon': Icons.loyalty_rounded, 'group': 'أخرى'},
    {'name': 'إضافات ومعدلات', 'icon': Icons.add_circle_outline_rounded, 'group': 'أخرى'},
  ];

  static const List<Color> _paletteColors = [
    Color(0xFFFF5B22), // برتقالي مدار الرئيسي
    Color(0xFFEA580C), // برتقالي داكن
    Color(0xFFF97316), // برتقالي مشرق
    Color(0xFFE11D48), // قرمزي / أحمر بيتزا
    Color(0xFFEF4444), // أحمر دافئ
    Color(0xFFD97706), // عنبري كلاسيك
    Color(0xFFCA8A04), // خردلي ذهبي
    Color(0xFF10B981), // زمردي أخضر
    Color(0xFF059669), // أخضر نعناعي
    Color(0xFF0284C7), // سماوي أزرق
    Color(0xFF2563EB), // نيلي ملكي
    Color(0xFF6366F1), // لافندر
    Color(0xFF8B5CF6), // بنفسجي ناصع
    Color(0xFF9333EA), // أرجواني حلويات
    Color(0xFFEC4899), // وردي آيس كريم
    Color(0xFF78350F), // بني قهوة وإسبريسو
  ];

  static const List<String> _kitchenStations = [
    'المطبخ الرئيسي 👨‍🍳',
    'شواية الفحم والمشاوي 🔥',
    'سيخ الشاورما 🌯',
    'فرن البيتزا والمعجنات 🍕',
    'خط القلي والبرغر 🍔',
    'محطة المشروبات والقهوة 🥤',
    'ركن الحلويات والآيس كريم 🍰',
    'محطة المقبلات والبارد 🥗',
    'محطة التجهيز والتغليف 📦',
  ];

  CollectionReference _categoriesRef() {
    return FirebaseFirestore.instance
        .collection('merchant_categories')
        .doc(_activeId)
        .collection('categories');
  }

  // ─────────────────────────── العمليات والحفظ ───────────────────────────

  Future<void> _importPresetPack(Map<String, dynamic> pack) async {
    if (_activeId.isEmpty) return;
    HapticFeedback.mediumImpact();

    final items = pack['items'] as List<Map<String, dynamic>>;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final catRef = _categoriesRef();

      int orderIndex = 1;
      final List<String> namesToSync = [];

      for (var cat in items) {
        final doc = catRef.doc();
        final name = cat['name'] as String;
        namesToSync.add(name);

        final iconData = cat['icon'] as IconData;
        final colorVal = cat['color'] as int;

        batch.set(doc, {
          'name': name,
          'iconCode': iconData.codePoint,
          'colorValue': colorVal,
          'displayOrder': orderIndex++,
          'isActive': true,
          'kitchenStation': cat['station'],
          'restaurantId': _activeId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final restRef = FirebaseFirestore.instance.collection('restaurants').doc(_activeId);
      batch.set(restRef, {
        'categories': namesToSync,
      }, SetOptions(merge: true));

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم استيراد ${items.length} أقسام من "${pack['title']}" بنجاح! 🎉',
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

  Future<void> _toggleCategoryStatus(MenuCategory cat) async {
    if (_activeId.isEmpty) return;
    HapticFeedback.selectionClick();
    final newStatus = !cat.isActive;

    try {
      await _categoriesRef().doc(cat.id).set({
        'isActive': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'تم تفعيل قسم "${cat.name}" وإظهاره في الكاشير ✓'
                  : 'تم إخفاء قسم "${cat.name}" من الكاشير مؤقتاً',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            duration: const Duration(seconds: 1),
            backgroundColor: newStatus ? const Color(0xFF10B981) : const Color(0xFF475569),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تعديل الحالة: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _moveCategoryOrder(List<MenuCategory> allCategories, MenuCategory cat, bool moveUp) async {
    final currentIndex = allCategories.indexWhere((c) => c.id == cat.id);
    if (currentIndex == -1) return;
    final targetIndex = moveUp ? currentIndex - 1 : currentIndex + 1;
    if (targetIndex < 0 || targetIndex >= allCategories.length) return;

    final targetCat = allCategories[targetIndex];

    setState(() => _isReorderLoading = true);
    HapticFeedback.selectionClick();

    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(_categoriesRef().doc(cat.id), {'displayOrder': targetIndex});
      batch.update(_categoriesRef().doc(targetCat.id), {'displayOrder': currentIndex});

      final newOrderedList = List<MenuCategory>.from(allCategories);
      newOrderedList.removeAt(currentIndex);
      newOrderedList.insert(targetIndex, cat);

      final restRef = FirebaseFirestore.instance.collection('restaurants').doc(_activeId);
      batch.set(restRef, {
        'categories': newOrderedList.map((c) => c.name).toList(),
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      debugPrint('[CategoriesPage] Reorder failed: $e');
    } finally {
      if (mounted) setState(() => _isReorderLoading = false);
    }
  }

  /// إعادة الترتيب عبر السحب والإفلات التفاعلي
  Future<void> _handleDragReorder(List<MenuCategory> allCategories, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;

    final reordered = List<MenuCategory>.from(allCategories);
    final movedItem = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, movedItem);

    setState(() => _isReorderLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (int i = 0; i < reordered.length; i++) {
        batch.update(_categoriesRef().doc(reordered[i].id), {'displayOrder': i});
      }

      final restRef = FirebaseFirestore.instance.collection('restaurants').doc(_activeId);
      batch.set(restRef, {
        'categories': reordered.map((c) => c.name).toList(),
      }, SetOptions(merge: true));

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث وحفظ ترتيب الأقسام في الكاشير بنجاح! 🔃'),
            duration: Duration(seconds: 1),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[CategoriesPage] Drag reorder failed: $e');
    } finally {
      if (mounted) setState(() => _isReorderLoading = false);
    }
  }

  /// تصدير هيكل الأقسام كـ JSON للنسخ الاحتياطي
  void _exportCategoriesJson(List<MenuCategory> categories) {
    final list = categories.map((c) => c.toMap()).toList();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(list);
    Clipboard.setData(ClipboardData(text: jsonStr));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ بيانات الأقسام (JSON) إلى الحافظة بنجاح! 📋'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// تنفيذ إجراء جماعي على الأقسام المحددة
  Future<void> _executeBatchAction(String action, List<MenuCategory> allCategories) async {
    if (_selectedCategoryIds.isEmpty) return;
    HapticFeedback.mediumImpact();

    final batch = FirebaseFirestore.instance.batch();

    for (var id in _selectedCategoryIds) {
      final docRef = _categoriesRef().doc(id);
      if (action == 'activate') {
        batch.update(docRef, {'isActive': true});
      } else if (action == 'deactivate') {
        batch.update(docRef, {'isActive': false});
      } else if (action == 'delete') {
        batch.delete(docRef);
      }
    }

    try {
      await batch.commit();
      setState(() => _selectedCategoryIds.clear());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تطبيق الإجراء الجماعي بنجاح ✓'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء التنفيذ: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  // ─────────────────────────── بناء الواجهة الرئيسية ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeCrashBoundary(
          child: StreamBuilder<QuerySnapshot>(
            stream: _activeId.isEmpty
                ? null
                : FirebaseFirestore.instance
                    .collection('merchant_products')
                    .doc(_activeId)
                    .collection('products')
                    .snapshots(),
            builder: (context, productsSnap) {
              final Map<String, int> productCountByCategory = {};
              if (productsSnap.hasData) {
                for (var doc in productsSnap.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final cat = (data['category'] ?? '').toString().trim();
                  if (cat.isNotEmpty) {
                    productCountByCategory[cat] = (productCountByCategory[cat] ?? 0) + 1;
                  }
                }
              }

              return StreamBuilder<QuerySnapshot>(
                stream: _activeId.isEmpty ? null : _categoriesRef().snapshots(),
                builder: (context, catSnap) {
                  List<MenuCategory> categories = [];

                  if (catSnap.hasData && catSnap.data!.docs.isNotEmpty) {
                    categories = catSnap.data!.docs.map((doc) {
                      final data = (doc.data() as Map<String, dynamic>?) ?? {};
                      final name = (data['name'] ?? '').toString().trim();
                      final count = productCountByCategory[name] ?? 0;
                      return MenuCategory.fromFirestore(doc, count);
                    }).toList();
                  }

                  // دمج أي تصنيفات مسجلة في المنتجات بدون بطاقة مخصصة
                  final Set<String> existingNames = categories.map((c) => c.name.trim()).toSet();
                  for (final catName in productCountByCategory.keys) {
                    final trimmed = catName.trim();
                    if (trimmed.isNotEmpty && !existingNames.contains(trimmed)) {
                      categories.add(MenuCategory(
                        id: 'prod_cat_$trimmed',
                        name: trimmed,
                        icon: CategoryIconHelper.getIconForCategory(trimmed),
                        color: CategoryIconHelper.getColorForCategory(trimmed),
                        displayOrder: categories.length,
                        productsCount: productCountByCategory[trimmed] ?? 0,
                      ));
                      existingNames.add(trimmed);
                    }
                  }

                  // تطبيق الفرز
                  switch (_sortBy) {
                    case 'meals_desc':
                      categories.sort((a, b) => b.productsCount.compareTo(a.productsCount));
                      break;
                    case 'name':
                      categories.sort((a, b) => a.name.compareTo(b.name));
                      break;
                    case 'order':
                    default:
                      categories.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
                      break;
                  }

                  // تطبيق الفلاتر والبحث
                  List<MenuCategory> filtered = categories.where((cat) {
                    if (_filterTab == 'active' && !cat.isActive) return false;
                    if (_filterTab == 'hidden' && cat.isActive) return false;
                    if (_filterTab == 'with_meals' && cat.productsCount == 0) return false;
                    if (_filterTab == 'empty' && cat.productsCount > 0) return false;
                    if (_filterTab == 'discount' && !cat.hasActiveDiscount) return false;

                    if (_searchQuery.isNotEmpty) {
                      final q = _searchQuery.toLowerCase();
                      final nameMatch = cat.name.toLowerCase().contains(q);
                      final enMatch = cat.nameEn?.toLowerCase().contains(q) ?? false;
                      final stationMatch = cat.kitchenStation?.toLowerCase().contains(q) ?? false;
                      if (!nameMatch && !enMatch && !stationMatch) return false;
                    }
                    return true;
                  }).toList();

                  final totalCategories = categories.length;
                  final activeCategories = categories.where((cat) => cat.isActive).length;
                  final hiddenCategories = totalCategories - activeCategories;
                  final totalMeals = productCountByCategory.values.fold(0, (s, n) => s + n);
                  final emptyCategories = categories.where((cat) => cat.productsCount == 0).length;
                  final discountedCategories = categories.where((cat) => cat.hasActiveDiscount).length;

                  return Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. ترويسة الصفحة مع أزرار الإضافة والباقات وترتيب السحب
                            _buildHeader(context, categories),

                            const SizedBox(height: 16),

                            // 2. مؤشرات وبطاقات الإحصائيات التفاعلية (KPIs)
                            _buildKpiMetricsRow(
                              context,
                              total: totalCategories,
                              active: activeCategories,
                              hidden: hiddenCategories,
                              totalMeals: totalMeals,
                              empty: emptyCategories,
                              discounted: discountedCategories,
                            ),

                            const SizedBox(height: 16),

                            // 3. شريط البحث والتصفية المتطورة مع التبديل بين كروت/جدول/سحب
                            _buildFilterAndControlBar(context, categories.length, filtered.length),

                            const SizedBox(height: 16),

                            // 4. المحتوى الرئيسي
                            if (categories.isEmpty)
                              _buildEmptyState(context)
                            else if (filtered.isEmpty)
                              _buildNoSearchResultsState(context)
                            else if (_isReorderModeActive)
                              _buildReorderableList(context, categories)
                            else if (_viewMode == 'grid')
                              _buildCategoriesGrid(context, categories, filtered)
                            else
                              _buildCategoriesTable(context, categories, filtered),
                          ],
                        ),
                      ),

                      // شريط الإجراءات الجماعية العائم
                      if (_selectedCategoryIds.isNotEmpty)
                        Positioned(
                          bottom: 16,
                          left: 20,
                          right: 20,
                          child: _buildBatchActionBar(context, categories),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── مكونات الصفحة ───────────────────────────

  /// ترويسة الصفحة العلوية
  Widget _buildHeader(BuildContext context, List<MenuCategory> categories) {
    final c = context.posColors;

    return Container(
      padding: const EdgeInsets.all(18),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  c.primary.withValues(alpha: 0.18),
                  c.primary.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.primary.withValues(alpha: 0.25)),
            ),
            child: Icon(Icons.grid_view_rounded, size: 26, color: c.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'إدارة التصنيفات والأقسام',
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
                        color: c.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${categories.length} قسماً مسجلاً',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: c.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'تنظيم هيكلية المنيو، ربط الأقسام بمحطات المطبخ، ضبط الخصومات وساعات التوفر، واستعراض الوجبات',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
                ),
              ],
            ),
          ),

          // زر تفعيل وضع السحب والإفلات التفاعلي
          OutlinedButton.icon(
            onPressed: () => setState(() => _isReorderModeActive = !_isReorderModeActive),
            icon: Icon(
              _isReorderModeActive ? Icons.check_circle_rounded : Icons.swap_vert_rounded,
              size: 17,
              color: _isReorderModeActive ? const Color(0xFF10B981) : c.textPrimary,
            ),
            label: Text(
              _isReorderModeActive ? 'إنهاء الترتيب ✓' : 'ترتيب بالسحب 🔃',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _isReorderModeActive ? const Color(0xFF10B981) : c.textPrimary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: _isReorderModeActive ? const Color(0xFF10B981) : c.border,
                width: _isReorderModeActive ? 1.5 : 1.0,
              ),
              backgroundColor: _isReorderModeActive ? const Color(0xFF10B981).withValues(alpha: 0.08) : c.background,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),

          const SizedBox(width: 8),

          // زر خيارات إضافية (تصدير JSON، باقات جاهزة)
          PopupMenuButton<String>(
            tooltip: 'خيارات إضافية واستيراد باقات',
            onSelected: (val) {
              if (val == 'export') {
                _exportCategoriesJson(categories);
              } else if (val.startsWith('pack_')) {
                final idx = int.parse(val.replaceFirst('pack_', ''));
                _importPresetPack(_presetPacks[idx]);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.copy_all_rounded, size: 16, color: Color(0xFF0284C7)),
                    SizedBox(width: 8),
                    Text('نسخ احتياطي للأقسام (JSON) 📋'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                enabled: false,
                child: Text('باقات أقسام جاهزة للاستيراد:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              for (int i = 0; i < _presetPacks.length; i++)
                PopupMenuItem(
                  value: 'pack_$i',
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 15, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Text(_presetPacks[i]['title']),
                    ],
                  ),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.more_horiz_rounded, size: 18),
                  const SizedBox(width: 4),
                  Text('خيارات ⚡', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),

          // زر إضافة قسم جديد
          ElevatedButton.icon(
            onPressed: () => _showCategoryFormDialog(context, null),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              'إضافة قسم جديد',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  /// بطاقات مؤشرات الأداء السريعة (KPIs)
  Widget _buildKpiMetricsRow(
    BuildContext context, {
    required int total,
    required int active,
    required int hidden,
    required int totalMeals,
    required int empty,
    required int discounted,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            _buildKpiCard(
              context,
              title: 'إجمالي الأقسام',
              value: '$total',
              subtitle: 'أقسام المنيو الكلية',
              icon: Icons.category_rounded,
              color: const Color(0xFF3B82F6),
              isActiveFilter: _filterTab == 'all',
              onTap: () => setState(() => _filterTab = 'all'),
            ),
            const SizedBox(width: 12),
            _buildKpiCard(
              context,
              title: 'الأقسام النشطة',
              value: '$active',
              subtitle: 'ظاهرة في الكاشير',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF10B981),
              isActiveFilter: _filterTab == 'active',
              onTap: () => setState(() => _filterTab = 'active'),
            ),
            const SizedBox(width: 12),
            _buildKpiCard(
              context,
              title: 'المخفية مؤقتاً',
              value: '$hidden',
              subtitle: 'غير معروضة للبيع',
              icon: Icons.visibility_off_rounded,
              color: const Color(0xFF64748B),
              isActiveFilter: _filterTab == 'hidden',
              onTap: () => setState(() => _filterTab = 'hidden'),
            ),
            const SizedBox(width: 12),
            _buildKpiCard(
              context,
              title: 'الوجبات المسجلة',
              value: '$totalMeals',
              subtitle: 'موزعة عبر الأقسام',
              icon: Icons.restaurant_menu_rounded,
              color: const Color(0xFFFF5B22),
              isActiveFilter: _filterTab == 'with_meals',
              onTap: () => setState(() => _filterTab = 'with_meals'),
            ),
            if (discounted > 0) ...[
              const SizedBox(width: 12),
              _buildKpiCard(
                context,
                title: 'عروض وتخفيضات',
                value: '$discounted',
                subtitle: 'أقسام بخصم نشط 🔥',
                icon: Icons.local_fire_department_rounded,
                color: const Color(0xFFE11D48),
                isActiveFilter: _filterTab == 'discount',
                onTap: () => setState(() => _filterTab = 'discount'),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isActiveFilter,
    required VoidCallback onTap,
  }) {
    final c = context.posColors;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isActiveFilter ? color.withValues(alpha: 0.08) : c.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActiveFilter ? color : c.border,
              width: isActiveFilter ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isActiveFilter ? 0.04 : 0.01),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: c.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 9.5,
                        color: c.textDisabled,
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

  /// شريط البحث والتصفية والتحكم بالعرض
  Widget _buildFilterAndControlBar(BuildContext context, int totalCount, int filteredCount) {
    final c = context.posColors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // حقل البحث
              Expanded(
                flex: 3,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                            hintText: 'ابحث باسم القسم أو محطة المطبخ...',
                            hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        InkWell(
                          onTap: () => setState(() => _searchQuery = ''),
                          child: Icon(Icons.close_rounded, size: 16, color: c.textMuted),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // خيار الترتيب
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    icon: Icon(Icons.sort_rounded, size: 18, color: c.textMuted),
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textPrimary, fontWeight: FontWeight.bold),
                    items: [
                      DropdownMenuItem(
                        value: 'order',
                        child: Text('ترتيب الكاشير 🔢', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5)),
                      ),
                      DropdownMenuItem(
                        value: 'meals_desc',
                        child: Text('الأكثر أصنافاً 🍲', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5)),
                      ),
                      DropdownMenuItem(
                        value: 'name',
                        child: Text('أبجدياً (أ-ي) 🔤', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _sortBy = val);
                    },
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // مفتاح التبديل بين كروت / جدول
              Container(
                height: 42,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildViewModeToggleBtn(
                      icon: Icons.grid_view_rounded,
                      tooltip: 'عرض كروت شبكية',
                      isSelected: _viewMode == 'grid' && !_isReorderModeActive,
                      onTap: () => setState(() {
                        _viewMode = 'grid';
                        _isReorderModeActive = false;
                      }),
                    ),
                    const SizedBox(width: 4),
                    _buildViewModeToggleBtn(
                      icon: Icons.view_list_rounded,
                      tooltip: 'عرض جدول بيانات',
                      isSelected: _viewMode == 'table' && !_isReorderModeActive,
                      onTap: () => setState(() {
                        _viewMode = 'table';
                        _isReorderModeActive = false;
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // تبويبات الفلاتر السريعة
          Row(
            children: [
              _buildFilterChip('الكل ($totalCount)', 'all'),
              const SizedBox(width: 6),
              _buildFilterChip('النشطة في الكاشير', 'active'),
              const SizedBox(width: 6),
              _buildFilterChip('المخفية مؤقتاً', 'hidden'),
              const SizedBox(width: 6),
              _buildFilterChip('مع وجبات مسجلة', 'with_meals'),
              const SizedBox(width: 6),
              _buildFilterChip('أقسام فارغة', 'empty'),
              const SizedBox(width: 6),
              _buildFilterChip('خصومات نشطة 🔥', 'discount'),
              const Spacer(),
              if (_isReorderLoading)
                Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'جاري حفظ الترتيب...',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.primary),
                    ),
                  ],
                )
              else
                Text(
                  'عرض $filteredCount من أصل $totalCount قسم',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String key) {
    final c = context.posColors;
    final isSelected = _filterTab == key;

    return InkWell(
      onTap: () => setState(() => _filterTab = key),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? c.primary : c.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? c.primary : c.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : c.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildViewModeToggleBtn({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final c = context.posColors;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? c.card : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected ? c.primary : c.textMuted,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── شبكة الكروت الحديثة (Grid View) ───────────────────────────

  Widget _buildCategoriesGrid(
    BuildContext context,
    List<MenuCategory> allCategories,
    List<MenuCategory> displayCategories,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1200
            ? 4
            : (constraints.maxWidth >= 850 ? 3 : (constraints.maxWidth >= 550 ? 2 : 1));

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayCategories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: 245,
          ),
          itemBuilder: (context, idx) {
            final cat = displayCategories[idx];
            return _buildCategoryModernCard(context, cat, allCategories);
          },
        );
      },
    );
  }

  /// كرت التصنيف العصري المتجاوب
  Widget _buildCategoryModernCard(
    BuildContext context,
    MenuCategory cat,
    List<MenuCategory> allCategories,
  ) {
    final c = context.posColors;
    final catColor = cat.color;
    final isSelected = _selectedCategoryIds.contains(cat.id);

    return InkWell(
      onTap: () => _showCategoryMealsDrawer(context, cat),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? c.primary.withValues(alpha: 0.05) : c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? c.primary
                : (cat.isActive ? c.border : c.border.withValues(alpha: 0.5)),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: catColor.withValues(alpha: cat.isActive ? 0.06 : 0.01),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // خط علوي متدرج مميز بلون القسم
              Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      catColor,
                      catColor.withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // السطر الأول: الأيقونة والاسم ومفتاح التفعيل المباشر
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // مربع التحديد الجماعي
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedCategoryIds.add(cat.id);
                                } else {
                                  _selectedCategoryIds.remove(cat.id);
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 6),

                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: cat.isActive ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: catColor.withValues(alpha: cat.isActive ? 0.4 : 0.2),
                            ),
                          ),
                          child: Icon(
                            cat.icon,
                            color: cat.isActive ? catColor : c.textMuted,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.name,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: cat.isActive ? c.textPrimary : c.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (cat.nameEn != null && cat.nameEn!.isNotEmpty)
                                Text(
                                  cat.nameEn!,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 10.5,
                                    color: c.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        // مفتاح التبديل الفوري لتفعيل/إخفاء القسم
                        Tooltip(
                          message: cat.isActive ? 'ظاهر في الكاشير (انقر للإخفاء)' : 'مخفي حالياً (انقر للتفعيل)',
                          child: Transform.scale(
                            scale: 0.76,
                            child: Switch(
                              value: cat.isActive,
                              activeThumbColor: catColor,
                              onChanged: (_) => _toggleCategoryStatus(cat),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // السطر الثاني: شارات الخصم وساعات التوفر
                    Row(
                      children: [
                        if (cat.hasActiveDiscount) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_fire_department_rounded, size: 12, color: Color(0xFFDC2626)),
                                const SizedBox(width: 3),
                                Text(
                                  'خصم ${cat.discountPercent?.toInt()}%',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (cat.isScheduleEnabled && cat.availableFrom != null && cat.availableTo != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: cat.isCurrentlyInSchedule
                                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                  : const Color(0xFF64748B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 11,
                                  color: cat.isCurrentlyInSchedule ? const Color(0xFF059669) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${cat.availableFrom} - ${cat.availableTo}',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: cat.isCurrentlyInSchedule ? const Color(0xFF059669) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),

                    const SizedBox(height: 8),

                    // السطر الثالث: شارة محطة المطبخ وعدد الوجبات
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (cat.kitchenStation != null && cat.kitchenStation!.isNotEmpty)
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                                : c.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (cat.kitchenStation != null && cat.kitchenStation!.isNotEmpty)
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                                  : c.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.soup_kitchen_rounded,
                                size: 12,
                                color: (cat.kitchenStation != null && cat.kitchenStation!.isNotEmpty)
                                    ? const Color(0xFFD97706)
                                    : c.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                cat.kitchenStation?.isNotEmpty == true
                                    ? cat.kitchenStation!
                                    : 'المطبخ الافتراضي',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: (cat.kitchenStation != null && cat.kitchenStation!.isNotEmpty)
                                      ? const Color(0xFFB45309)
                                      : c.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cat.productsCount > 0
                                ? catColor.withValues(alpha: 0.1)
                                : const Color(0xFF64748B).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            cat.productsCount > 0 ? '${cat.productsCount} وجبة' : 'فارغ',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: cat.productsCount > 0 ? catColor : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),
              Divider(color: c.border, height: 1),

              // السطر السفلي: أزرار الترتيب السريع واستعراض الوجبات والخصم والتعديل
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                color: c.background.withValues(alpha: 0.5),
                child: Row(
                  children: [
                    // شارة رقم الترتيب
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: c.border),
                      ),
                      child: Text(
                        '#${cat.displayOrder + 1}',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: c.textMuted,
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),

                    // أسهم التقديم والتأخير في الكاشير
                    Tooltip(
                      message: 'تقديم الترتيب',
                      child: InkWell(
                        onTap: () => _moveCategoryOrder(allCategories, cat, true),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.arrow_upward_rounded, size: 15, color: c.textMuted),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'تأخير الترتيب',
                      child: InkWell(
                        onTap: () => _moveCategoryOrder(allCategories, cat, false),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.arrow_downward_rounded, size: 15, color: c.textMuted),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // زر الخصم والعروض
                    Tooltip(
                      message: 'تحديد خصم على القسم',
                      child: InkWell(
                        onTap: () => _showCategoryDiscountDialog(context, cat),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Icon(
                            Icons.local_fire_department_rounded,
                            size: 16,
                            color: cat.hasActiveDiscount ? const Color(0xFFEF4444) : c.textMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // زر استعراض الوجبات
                    Tooltip(
                      message: 'استعراض وإدارة وجبات القسم',
                      child: InkWell(
                        onTap: () => _showCategoryMealsDrawer(context, cat),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Icon(Icons.restaurant_rounded, size: 16, color: c.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // زر تعديل
                    IconButton(
                      onPressed: () => _showCategoryFormDialog(context, cat),
                      icon: Icon(Icons.edit_outlined, size: 16, color: c.primary),
                      tooltip: 'تعديل بيانات القسم',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    ),
                    const SizedBox(width: 2),

                    // زر حذف
                    IconButton(
                      onPressed: () => _confirmDeleteCategory(context, cat),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                      tooltip: 'حذف القسم',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
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

  // ─────────────────────────── وضع السحب والإفلات التفاعلي ───────────────────────────

  Widget _buildReorderableList(BuildContext context, List<MenuCategory> categories) {
    final c = context.posColors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.touch_app_rounded, size: 18, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text(
                'اسحب الأقسام وأفلتها لتحديد ترتيب ظهورها الدقيق في شريط الكاشير والمنيو:',
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => setState(() => _isReorderModeActive = false),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('حفظ وإنهاء الوضع ✓'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            onReorder: (oldIdx, newIdx) => _handleDragReorder(categories, oldIdx, newIdx),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final catColor = cat.color;

              return Container(
                key: ValueKey(cat.id),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.drag_indicator_rounded, color: Color(0xFF94A3B8), size: 22),
                    const SizedBox(width: 10),
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.border),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: c.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(cat.icon, size: 18, color: catColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.name,
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13.5, fontWeight: FontWeight.bold, color: c.textPrimary),
                          ),
                          Text(
                            '${cat.productsCount} وجبة • ${cat.kitchenStation ?? "المطبخ الافتراضي"}',
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cat.isActive ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFF64748B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cat.isActive ? 'ظاهر في الكاشير' : 'مخفي',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: cat.isActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── جدول البيانات المنظم (Table View) ───────────────────────────

  Widget _buildCategoriesTable(
    BuildContext context,
    List<MenuCategory> allCategories,
    List<MenuCategory> displayCategories,
  ) {
    final c = context.posColors;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // ترويسة الجدول
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: c.background,
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Checkbox(
                      value: _selectedCategoryIds.length == displayCategories.length && displayCategories.isNotEmpty,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedCategoryIds.addAll(displayCategories.map((c) => c.id));
                          } else {
                            _selectedCategoryIds.clear();
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    child: Text('الترتيب', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold, color: c.textMuted)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: Text('القسم والأيقونة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold, color: c.textMuted)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('محطة المطبخ', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold, color: c.textMuted)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('عدد الوجبات', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold, color: c.textMuted)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('الحالة بالكاشير', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold, color: c.textMuted)),
                  ),
                  SizedBox(
                    width: 140,
                    child: Center(
                      child: Text('إجراءات سريعة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold, color: c.textMuted)),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: c.border, height: 1),

            // صفوف الأقسام
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayCategories.length,
              separatorBuilder: (_, _) => Divider(color: c.border, height: 1),
              itemBuilder: (context, index) {
                final cat = displayCategories[index];
                final catColor = cat.color;
                final isSelected = _selectedCategoryIds.contains(cat.id);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // مربع تحديد
                      SizedBox(
                        width: 30,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedCategoryIds.add(cat.id);
                              } else {
                                _selectedCategoryIds.remove(cat.id);
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // الترتيب
                      SizedBox(
                        width: 50,
                        child: Text(
                          '#${cat.displayOrder + 1}',
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold, color: c.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // الأيقونة والاسم
                      Expanded(
                        flex: 3,
                        child: InkWell(
                          onTap: () => _showCategoryMealsDrawer(context, cat),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(cat.icon, size: 18, color: catColor),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          cat.name,
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: cat.isActive ? c.textPrimary : c.textMuted,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (cat.hasActiveDiscount) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'خصم ${cat.discountPercent?.toInt()}%',
                                              style: GoogleFonts.ibmPlexSansArabic(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (cat.nameEn?.isNotEmpty == true)
                                      Text(
                                        cat.nameEn!,
                                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: c.textMuted),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // محطة المطبخ
                      Expanded(
                        flex: 2,
                        child: Text(
                          cat.kitchenStation?.isNotEmpty == true ? cat.kitchenStation! : 'المطبخ الافتراضي',
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // عدد الوجبات
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () => _showCategoryMealsDrawer(context, cat),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: cat.productsCount > 0 ? catColor.withValues(alpha: 0.1) : c.background,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${cat.productsCount} وجبة 🍲',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: cat.productsCount > 0 ? catColor : c.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // مفتاح الحالة في الكاشير
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Transform.scale(
                              scale: 0.75,
                              child: Switch(
                                value: cat.isActive,
                                activeThumbColor: catColor,
                                onChanged: (_) => _toggleCategoryStatus(cat),
                              ),
                            ),
                            Text(
                              cat.isActive ? 'نشط' : 'مخفي',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: cat.isActive ? const Color(0xFF10B981) : c.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // إجراءات الجدول
                      SizedBox(
                        width: 140,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () => _showCategoryMealsDrawer(context, cat),
                              icon: const Icon(Icons.restaurant_rounded, size: 16),
                              tooltip: 'استعراض الوجبات',
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              padding: EdgeInsets.zero,
                            ),
                            IconButton(
                              onPressed: () => _showCategoryDiscountDialog(context, cat),
                              icon: Icon(Icons.local_fire_department_rounded, size: 16, color: cat.hasActiveDiscount ? const Color(0xFFEF4444) : c.textMuted),
                              tooltip: 'خصم القسم',
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              padding: EdgeInsets.zero,
                            ),
                            IconButton(
                              onPressed: () => _showCategoryFormDialog(context, cat),
                              icon: Icon(Icons.edit_outlined, size: 16, color: c.primary),
                              tooltip: 'تعديل',
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              padding: EdgeInsets.zero,
                            ),
                            IconButton(
                              onPressed: () => _confirmDeleteCategory(context, cat),
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                              tooltip: 'حذف',
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// شريط العمليات الجماعية العائم
  Widget _buildBatchActionBar(BuildContext context, List<MenuCategory> categories) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.checklist_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            'تم تحديد ${_selectedCategoryIds.length} أقسام',
            style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _executeBatchAction('activate', categories),
            icon: const Icon(Icons.check_rounded, size: 15),
            label: const Text('تفعيل الكل بالكاشير'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _executeBatchAction('deactivate', categories),
            icon: const Icon(Icons.visibility_off_rounded, size: 15),
            label: const Text('إخفاء الكل'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF475569),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _executeBatchAction('delete', categories),
            icon: const Icon(Icons.delete_forever_rounded, size: 15),
            label: const Text('حذف المحدد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () => setState(() => _selectedCategoryIds.clear()),
            child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: const Color(0xFF94A3B8))),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── درج استعراض وإدارة وجبات القسم ───────────────────────────

  void _showCategoryMealsDrawer(BuildContext context, MenuCategory cat) {
    MadarSideSheet.showModal(
      context: context,
      title: 'وجبات قسم: ${cat.name}',
      subtitle: '${cat.productsCount} وجبة مسجلة في هذا القسم',
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cat.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(cat.icon, color: cat.color, size: 20),
      ),
      content: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('merchant_products')
            .doc(_activeId)
            .collection('products')
            .where('category', isEqualTo: cat.name)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.restaurant_menu_rounded, size: 40, color: context.posColors.textDisabled),
                    const SizedBox(height: 12),
                    Text(
                      'لا توجد وجبات مسجلة في قسم "${cat.name}" حالياً',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'يمكنك إضافة وجبات جديدة أو تعديل تصنيف الوجبات الحالية من صفحة المنيو',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: context.posColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snap.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name']?.toString() ?? 'وجبة';
              final price = (data['price'] as num?)?.toDouble() ?? 0.0;
              final isAvailable = data['isAvailable'] as bool? ?? true;
              final imageUrl = data['imageUrl'] as String?;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.posColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.posColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.posColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.posColors.border),
                      ),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Icon(Icons.fastfood_rounded, color: cat.color),
                              ),
                            )
                          : Icon(Icons.fastfood_rounded, color: cat.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${price.toStringAsFixed(0)} د.ع',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: context.posColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // مفتاح توفر الوجبة المباشر
                    Tooltip(
                      message: isAvailable ? 'الوجبة متوفرة للطلب' : 'الوجبة نافذة (غير متوفرة)',
                      child: Transform.scale(
                        scale: 0.75,
                        child: Switch(
                          value: isAvailable,
                          activeThumbColor: const Color(0xFF10B981),
                          onChanged: (val) async {
                            HapticFeedback.selectionClick();
                            await doc.reference.update({'isAvailable': val});
                          },
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
    );
  }

  // ─────────────────────────── نافذة الخصم الترويجي للقسم ───────────────────────────

  void _showCategoryDiscountDialog(BuildContext context, MenuCategory cat) {
    final c = context.posColors;
    double currentDiscount = cat.discountPercent ?? 10.0;
    bool isDiscountActive = cat.discountActive;
    final ctrl = TextEditingController(text: currentDiscount.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Color(0xFFEF4444), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'خصم ترويجي لقسم: ${cat.name}',
                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تطبيق نسبة خصم ترويجية فورية على جميع الوجبات التابعة لهذا القسم عند الطلب في الكاشير.',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted, height: 1.3),
                    ),
                    const SizedBox(height: 16),

                    // مفتاح التفعيل
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDiscountActive ? const Color(0xFFEF4444).withValues(alpha: 0.08) : c.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDiscountActive ? const Color(0xFFEF4444) : c.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.discount_rounded,
                            color: isDiscountActive ? const Color(0xFFDC2626) : c.textMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تفعيل الخصم على هذا القسم',
                              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ),
                          Switch(
                            value: isDiscountActive,
                            activeThumbColor: const Color(0xFFEF4444),
                            onChanged: (val) => setModalState(() => isDiscountActive = val),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'نسبة الخصم المئوية (%)',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // شرائح النسب السريعة
                    Row(
                      children: [5, 10, 15, 20, 25, 30].map((rate) {
                        final isSel = currentDiscount.toInt() == rate;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  currentDiscount = rate.toDouble();
                                  ctrl.text = '$rate';
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSel ? const Color(0xFFEF4444) : c.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isSel ? const Color(0xFFEF4444) : c.border),
                                ),
                                child: Text(
                                  '$rate%',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSel ? Colors.white : c.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),
                    TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final parsed = double.tryParse(v);
                        if (parsed != null) {
                          setModalState(() => currentDiscount = parsed.clamp(0.0, 100.0));
                        }
                      },
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        suffixText: '%',
                        hintText: 'أو أدخل نسبة مخصصة...',
                        filled: true,
                        fillColor: c.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    HapticFeedback.mediumImpact();
                    await _categoriesRef().doc(cat.id).update({
                      'discountPercent': currentDiscount,
                      'discountActive': isDiscountActive,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('حفظ الخصم 🔥', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────── الحالات الفارغة ───────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    final c = context.posColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.grid_view_rounded, size: 48, color: c.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد أقسام مسجلة في المنيو حتى الآن',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ابدأ بإضافة تصنيفات مطعمك لتنظيم وجباتك وتسهيل طلبها على الكاشير، أو استخدم باقات الأقسام الجاهزة بضغطة واحدة!',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: c.textMuted, height: 1.4),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _importPresetPack(_presetPacks.first),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: const Text('استيراد باقة مشويات وعراقي (8 أقسام)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showCategoryFormDialog(context, null),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('إضافة قسم يدوياً'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.textPrimary,
                      side: BorderSide(color: c.border),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildNoSearchResultsState(BuildContext context) {
    final c = context.posColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Column(
          children: [
            Icon(Icons.filter_alt_off_rounded, size: 48, color: c.textDisabled),
            const SizedBox(height: 12),
            Text(
              'لا توجد أقسام مطابقة للبحث أو الفلتر المحدد',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.bold, color: c.textMuted),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() {
                _searchQuery = '';
                _filterTab = 'all';
              }),
              child: const Text('إعادة ضبط الفلاتر'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── نافذة الإضافة والتعديل التفاعلية مع المعاينة الحية ───────────────────────────

  void _showCategoryFormDialog(BuildContext context, MenuCategory? existing) {
    final c = context.posColors;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final nameEnCtrl = TextEditingController(text: existing?.nameEn ?? '');
    final orderCtrl = TextEditingController(
      text: existing != null ? '${existing.displayOrder + 1}' : '1',
    );
    final fromTimeCtrl = TextEditingController(text: existing?.availableFrom ?? '07:00');
    final toTimeCtrl = TextEditingController(text: existing?.availableTo ?? '12:00');

    int selectedIconIndex = 0;
    int selectedColorIndex = 0;
    String? selectedStation = existing?.kitchenStation;
    String iconFilterGroup = 'الكل';
    bool isScheduleEnabled = existing?.isScheduleEnabled ?? false;

    if (existing != null) {
      final foundIcon = _culinaryIcons.indexWhere((it) => (it['icon'] as IconData).codePoint == existing.icon.codePoint);
      if (foundIcon >= 0) selectedIconIndex = foundIcon;
      final foundColor = _paletteColors.indexWhere((col) => col.toARGB32() == existing.color.toARGB32());
      if (foundColor >= 0) selectedColorIndex = foundColor;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentColor = _paletteColors[selectedColorIndex];
          final currentIcon = _culinaryIcons[selectedIconIndex]['icon'] as IconData;
          final previewName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'اسم القسم الجديد';

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      existing == null ? Icons.add_rounded : Icons.edit_rounded,
                      color: c.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    existing == null ? 'إضافة قسم جديد للمنيو' : 'تعديل بيانات القسم',
                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. بطاقة المعاينة الحية الفورية (Live Preview)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.visibility_rounded, size: 14, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 6),
                                Text(
                                  'معاينة حية للقسم في الكاشير والمنيو:',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: c.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                // معاينة شريحة الكاشير
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: currentColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: currentColor, width: 1.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(currentIcon, size: 16, color: currentColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        previewName,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: c.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                if (selectedStation != null && selectedStation!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'تذكرة: $selectedStation',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 2. حقول إدخال الاسم
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'اسم القسم بالعربية *',
                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: nameCtrl,
                                  onChanged: (_) => setModalState(() {}),
                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5),
                                  decoration: InputDecoration(
                                    hintText: 'مثال: مشاوي، برغر، بيتزا...',
                                    filled: true,
                                    fillColor: c.background,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الاسم بالإنجليزية (اختياري)',
                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: nameEnCtrl,
                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Grills, Burgers, Pizza...',
                                    filled: true,
                                    fillColor: c.background,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // 3. محطة المطبخ والترتيب
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'محطة المطبخ والطباعة الحرارية',
                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: c.background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: c.border),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedStation,
                                      isExpanded: true,
                                      hint: Text('اختر محطة المطبخ المختصة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted)),
                                      items: [
                                        for (var st in _kitchenStations)
                                          DropdownMenuItem(
                                            value: st,
                                            child: Text(st, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12)),
                                          ),
                                      ],
                                      onChanged: (val) => setModalState(() => selectedStation = val),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الترتيب',
                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: orderCtrl,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5),
                                  decoration: InputDecoration(
                                    hintText: '1',
                                    filled: true,
                                    fillColor: c.background,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // 4. جدول ساعات التوفر (Dayparts)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'تحديد ساعات توفر مخصصة للقسم (مثل: فطور صباحي)',
                                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Switch(
                                  value: isScheduleEnabled,
                                  activeThumbColor: currentColor,
                                  onChanged: (val) => setModalState(() => isScheduleEnabled = val),
                                ),
                              ],
                            ),
                            if (isScheduleEnabled) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('من الساعة (مثال 07:00)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted)),
                                        const SizedBox(height: 4),
                                        TextField(
                                          controller: fromTimeCtrl,
                                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            filled: true,
                                            fillColor: c.card,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('إلى الساعة (مثال 12:00)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted)),
                                        const SizedBox(height: 4),
                                        TextField(
                                          controller: toTimeCtrl,
                                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            filled: true,
                                            fillColor: c.card,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 5. اختيار الأيقونة مع تبويبات التصنيف
                      Text(
                        'اختر أيقونة القسم',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      // فئات الأيقونات
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var g in ['الكل', 'وجبات', 'لحوم', 'معجنات', 'مقبلات', 'مشروبات', 'حلويات', 'أخرى'])
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: InkWell(
                                  onTap: () => setModalState(() => iconFilterGroup = g),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: iconFilterGroup == g ? c.primary : c.background,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: iconFilterGroup == g ? c.primary : c.border),
                                    ),
                                    child: Text(
                                      g,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: iconFilterGroup == g ? Colors.white : c.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // شبكة الأيقونات
                      Container(
                        height: 120,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.border),
                        ),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(_culinaryIcons.length, (i) {
                              final item = _culinaryIcons[i];
                              if (iconFilterGroup != 'الكل' && item['group'] != iconFilterGroup) {
                                return const SizedBox.shrink();
                              }

                              final isSelected = selectedIconIndex == i;
                              return Tooltip(
                                message: item['name'],
                                child: InkWell(
                                  onTap: () => setModalState(() => selectedIconIndex = i),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? currentColor.withValues(alpha: 0.2) : c.card,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected ? currentColor : c.border,
                                        width: isSelected ? 1.8 : 1.0,
                                      ),
                                    ),
                                    child: Icon(
                                      item['icon'] as IconData,
                                      color: isSelected ? currentColor : c.textMuted,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 6. باليت الألوان العصرية
                      Text(
                        'لون القسم المميز',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_paletteColors.length, (i) {
                          final color = _paletteColors[i];
                          final isSelected = selectedColorIndex == i;
                          return InkWell(
                            onTap: () => setModalState(() => selectedColorIndex = i),
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8, offset: const Offset(0, 2))]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                  : null,
                            ),
                          );
                        }),
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

                    final nameEn = nameEnCtrl.text.trim();
                    final order = (int.tryParse(orderCtrl.text.trim()) ?? 1) - 1;
                    final icon = _culinaryIcons[selectedIconIndex]['icon'] as IconData;
                    final color = _paletteColors[selectedColorIndex];

                    final payload = {
                      'name': name,
                      'nameEn': nameEn.isNotEmpty ? nameEn : null,
                      'displayOrder': order,
                      'iconCode': icon.codePoint,
                      'colorValue': color.toARGB32(),
                      'kitchenStation': selectedStation,
                      'isScheduleEnabled': isScheduleEnabled,
                      'availableFrom': isScheduleEnabled ? fromTimeCtrl.text.trim() : null,
                      'availableTo': isScheduleEnabled ? toTimeCtrl.text.trim() : null,
                      'isActive': existing?.isActive ?? true,
                      'updatedAt': FieldValue.serverTimestamp(),
                    };

                    if (_activeId.isNotEmpty) {
                      if (existing == null) {
                        payload['createdAt'] = FieldValue.serverTimestamp();
                        await _categoriesRef().add(payload);
                        try {
                          await FirebaseFirestore.instance.collection('restaurants').doc(_activeId).set({
                            'categories': FieldValue.arrayUnion([name]),
                          }, SetOptions(merge: true));
                          await FirebaseFirestore.instance.collection('merchant_products').doc(_activeId).collection('categories').doc(name).set(payload);
                        } catch (_) {}
                      } else {
                        await _categoriesRef().doc(existing.id).set(payload, SetOptions(merge: true));
                        try {
                          await FirebaseFirestore.instance.collection('restaurants').doc(_activeId).set({
                            'categories': FieldValue.arrayUnion([name]),
                          }, SetOptions(merge: true));
                        } catch (_) {}
                      }
                    }

                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    existing == null ? 'إضافة القسم 🚀' : 'حفظ التعديلات ✓',
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

  // ─────────────────────────── نافذة تأكيد الحذف ───────────────────────────

  void _confirmDeleteCategory(BuildContext context, MenuCategory cat) {
    final c = context.posColors;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
              const SizedBox(width: 8),
              Text(
                'حذف القسم؟',
                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            'هل أنت متأكد من حذف قسم "${cat.name}"؟'
            '${cat.productsCount > 0 ? "\n\nتنبيه: يحتوي هذا القسم على ${cat.productsCount} وجبة مسجلة، لن يتم حذف الوجبات ولكنها ستصبح غير مصنفة." : ""}',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_activeId.isNotEmpty) {
                  await _categoriesRef().doc(cat.id).delete();
                  try {
                    await FirebaseFirestore.instance.collection('restaurants').doc(_activeId).set({
                      'categories': FieldValue.arrayRemove([cat.name]),
                    }, SetOptions(merge: true));
                    await FirebaseFirestore.instance.collection('merchant_products').doc(_activeId).collection('categories').doc(cat.name).delete();
                  } catch (_) {}
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'تأكيد الحذف',
                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
