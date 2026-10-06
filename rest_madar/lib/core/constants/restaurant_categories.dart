import 'package:flutter/material.dart';

/// بطاقة تصنيف ومجموعة المطعم في منظومة مدار
class RestaurantCategoryItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String? badge;

  const RestaurantCategoryItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.badge,
  });
}

/// مجموعات وتصنيفات المطاعم الرسمية المعتمدة في تطبيق مدار ومنظومة POS
class MadarRestaurantCategories {
  static const List<RestaurantCategoryItem> all = [
    RestaurantCategoryItem(
      id: 'مشويات وكباب عراقي',
      title: 'مشويات وكباب عراقي',
      subtitle: 'كباب، تكة، معلاق، ومشويات فحم وتتبيلات عراقية',
      icon: Icons.outdoor_grill_rounded,
      accentColor: Color(0xFFE53935),
      badge: 'شائع جداً',
    ),
    RestaurantCategoryItem(
      id: 'وجبات سريعة وبرغر',
      title: 'وجبات سريعة وبرغر',
      subtitle: 'سندويشات، برغر لحم ودجاج، مقبلات وبطاطس',
      icon: Icons.lunch_dining_rounded,
      accentColor: Color(0xFFFF9800),
      badge: 'الأكثر طلباً',
    ),
    RestaurantCategoryItem(
      id: 'بيتزا ومعجنات إيطالية',
      title: 'بيتزا ومعجنات إيطالية',
      subtitle: 'بيتزا نابوليتان، معجنات وفطائر ساخنة، صفيحة',
      icon: Icons.local_pizza_rounded,
      accentColor: Color(0xFFFF7043),
    ),
    RestaurantCategoryItem(
      id: 'دجاج ومقرمشات',
      title: 'دجاج ومقرمشات (كرسبي)',
      subtitle: 'دجاج كرسبي، بروستد، زنجر، وتندرز عائلي',
      icon: Icons.fastfood_rounded,
      accentColor: Color(0xFFF59E0B),
      badge: 'عائلي',
    ),
    RestaurantCategoryItem(
      id: 'مأكولات عراقية وشرقية',
      title: 'مأكولات عراقية وشرقية',
      subtitle: 'قوزي، تمن ومرك، باجة، دولمة، وأكلات تراثية',
      icon: Icons.ramen_dining_rounded,
      accentColor: Color(0xFF8D6E63),
    ),
    RestaurantCategoryItem(
      id: 'شاورما وقص',
      title: 'شاورما وقص عراقي',
      subtitle: 'قص لحم ودجاج، شاورما عربي وإيطالي وصحون مقبلات',
      icon: Icons.kebab_dining_rounded,
      accentColor: Color(0xFFD84315),
      badge: 'سريع',
    ),
    RestaurantCategoryItem(
      id: 'حلويات وكنافـة وكافيه',
      title: 'حلويات وكنافـة وكافيه',
      subtitle: 'كنافة نابلسية، بقلاوة، كيك، وافل ومشروبات ساخنة',
      icon: Icons.cake_rounded,
      accentColor: Color(0xFFEC407A),
    ),
    RestaurantCategoryItem(
      id: 'عصائر ومشروبات طبيعية',
      title: 'عصائر ومشروبات طبيعية',
      subtitle: 'عصائر طازجة، موهيتو، سموذي وميلك شيك منعش',
      icon: Icons.local_bar_rounded,
      accentColor: Color(0xFF00ACC1),
    ),
    RestaurantCategoryItem(
      id: 'مأكولات بحرية وسمك',
      title: 'مأكولات بحرية وسمك مسكوف',
      subtitle: 'مسكوف عراقي، روبيان، فيليه مشوي ومقلي',
      icon: Icons.set_meal_rounded,
      accentColor: Color(0xFF1E88E5),
    ),
    RestaurantCategoryItem(
      id: 'مطعم وكافيه شامل',
      title: 'مطعم وكافيه شامل',
      subtitle: 'قائمة طعام شاملة، وجبات رئيسية ومشروبات متنوعة',
      icon: Icons.storefront_rounded,
      accentColor: Color(0xFF00BFA5),
      badge: 'متكامل',
    ),
  ];

  static RestaurantCategoryItem findById(String? id) {
    if (id == null || id.isEmpty) return all.first;
    return all.firstWhere(
      (c) => c.id == id || c.title == id,
      orElse: () => all.first,
    );
  }
}
