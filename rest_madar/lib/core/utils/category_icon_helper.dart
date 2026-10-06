import 'package:flutter/material.dart';

/// مساعد ذكي لتحديد وإدارة أيقونات أقسام وجبات المطاعم
class CategoryIconItem {
  final String key;
  final String title;
  final IconData icon;
  final Color color;

  const CategoryIconItem({
    required this.key,
    required this.title,
    required this.icon,
    required this.color,
  });
}

class CategoryIconHelper {
  /// قائمة الأيقونات الشائعة لأقسام المطاعم مع أسمائها وألوانها
  static const List<CategoryIconItem> availableIcons = [
    CategoryIconItem(
      key: 'all',
      title: 'الكل',
      icon: Icons.grid_view_rounded,
      color: Color(0xFF26A69A),
    ),
    CategoryIconItem(
      key: 'main',
      title: 'وجبات رئيسية',
      icon: Icons.dinner_dining_rounded,
      color: Color(0xFFE57373),
    ),
    CategoryIconItem(
      key: 'burger',
      title: 'برجر',
      icon: Icons.lunch_dining_rounded,
      color: Color(0xFFFFB74D),
    ),
    CategoryIconItem(
      key: 'pizza',
      title: 'بيتزا',
      icon: Icons.local_pizza_rounded,
      color: Color(0xFFFF8A65),
    ),
    CategoryIconItem(
      key: 'shawarma',
      title: 'شاورما وسندويش',
      icon: Icons.kebab_dining_rounded,
      color: Color(0xFFA1887F),
    ),
    CategoryIconItem(
      key: 'grills',
      title: 'مشاوي وكباب',
      icon: Icons.outdoor_grill_rounded,
      color: Color(0xFFD32F2F),
    ),
    CategoryIconItem(
      key: 'chicken',
      title: 'دجاج وبروستد',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFFFA726),
    ),
    CategoryIconItem(
      key: 'appetizers',
      title: 'مقبلات وسلطات',
      icon: Icons.ramen_dining_rounded,
      color: Color(0xFF81C784),
    ),
    CategoryIconItem(
      key: 'pasta',
      title: 'معكرونة وباستا',
      icon: Icons.soup_kitchen_rounded,
      color: Color(0xFFFFD54F),
    ),
    CategoryIconItem(
      key: 'seafood',
      title: 'مأكولات بحرية وسمك',
      icon: Icons.phishing_rounded,
      color: Color(0xFF4FC3F7),
    ),
    CategoryIconItem(
      key: 'drinks',
      title: 'مشروبات وعصائر',
      icon: Icons.local_drink_rounded,
      color: Color(0xFF4DD0E1),
    ),
    CategoryIconItem(
      key: 'coffee',
      title: 'قهوة وشاي',
      icon: Icons.local_cafe_rounded,
      color: Color(0xFF8D6E63),
    ),
    CategoryIconItem(
      key: 'sweets',
      title: 'حلويات وكيك',
      icon: Icons.cake_rounded,
      color: Color(0xFFBA68C8),
    ),
    CategoryIconItem(
      key: 'icecream',
      title: 'مثلجات وآيس كريم',
      icon: Icons.icecream_rounded,
      color: Color(0xFFF06292),
    ),
    CategoryIconItem(
      key: 'breakfast',
      title: 'فطور ومعجنات',
      icon: Icons.bakery_dining_rounded,
      color: Color(0xFFFFCA28),
    ),
    CategoryIconItem(
      key: 'boxes',
      title: 'بوكسات ووجبات عائلية',
      icon: Icons.inventory_2_rounded,
      color: Color(0xFF7E57C2),
    ),
    CategoryIconItem(
      key: 'fastfood',
      title: 'وجبات سريعة',
      icon: Icons.fastfood_rounded,
      color: Color(0xFFFF7043),
    ),
    CategoryIconItem(
      key: 'offers',
      title: 'عروض وخصومات',
      icon: Icons.local_offer_rounded,
      color: Color(0xFFEF5350),
    ),
  ];

  /// خريطة صور طعام جاهزة وعالية الجودة للاختيار السريع
  static const List<Map<String, String>> presetFoodImages = [
    {
      'title': 'برجر لحم كلاسيك',
      'category': 'برجر',
      'url': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'برجر دجاج كريسبي',
      'category': 'برجر',
      'url': 'https://images.unsplash.com/photo-1625813506062-0aeb1d7a094b?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'شاورما لحم عربي',
      'category': 'شاورما',
      'url': 'https://images.unsplash.com/photo-1633321702518-7feccafb94d5?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'شاورما دجاج صاج',
      'category': 'شاورما',
      'url': 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'بيتزا بيبروني',
      'category': 'بيتزا',
      'url': 'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'بيتزا خضار مارغريتا',
      'category': 'بيتزا',
      'url': 'https://images.unsplash.com/photo-1604382354936-07c5d9983bd3?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'كباب ومشاوي عراقية',
      'category': 'مشاوي',
      'url': 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'تكة لحم وشيش طاووق',
      'category': 'مشاوي',
      'url': 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'دجاج بروستد مقرمش',
      'category': 'دجاج',
      'url': 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'بطاطا مقلية كريسبي',
      'category': 'مقبلات',
      'url': 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'حمص ومتبل عربي',
      'category': 'مقبلات',
      'url': 'https://images.unsplash.com/photo-1577906096429-f73c2c312435?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'سلطة سيزر / فتوش',
      'category': 'مقبلات',
      'url': 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'مشروب غازي كولا / بيبسي',
      'category': 'مشروبات',
      'url': 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'عصير برتقال طبيعي',
      'category': 'مشروبات',
      'url': 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'شاي عراقي مهيّل',
      'category': 'مشروبات',
      'url': 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'كنافة بالجبن / بقلاوة',
      'category': 'حلويات',
      'url': 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'وافل وشوكولاتة',
      'category': 'حلويات',
      'url': 'https://images.unsplash.com/photo-1562376552-0d160a2f238d?w=600&auto=format&fit=crop&q=80',
    },
    {
      'title': 'وجبة سمك مسكوف',
      'category': 'مأكولات بحرية',
      'url': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=600&auto=format&fit=crop&q=80',
    },
  ];

  /// جلب الأيقونة المناسبة لاسم القسم تلقائياً
  static IconData getIconForCategory(String categoryName) {
    final lower = categoryName.trim().toLowerCase();

    if (lower == 'الكل' || lower == 'all') {
      return Icons.grid_view_rounded;
    }
    if (lower.contains('برجر') || lower.contains('burger')) {
      return Icons.lunch_dining_rounded;
    }
    if (lower.contains('بيتزا') || lower.contains('pizza')) {
      return Icons.local_pizza_rounded;
    }
    if (lower.contains('شاورما') || lower.contains('shawarma') || lower.contains('سندويش') || lower.contains('لفة')) {
      return Icons.kebab_dining_rounded;
    }
    if (lower.contains('مشاوي') || lower.contains('كباب') || lower.contains('تكة') || lower.contains('grill') || lower.contains('bbq')) {
      return Icons.outdoor_grill_rounded;
    }
    if (lower.contains('دجاج') || lower.contains('بروستد') || lower.contains('chicken') || lower.contains('كرسبي') || lower.contains('ستربس')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('مقبلات') || lower.contains('سلطة') || lower.contains('سلطات') || lower.contains('حمص') || lower.contains('فتوش')) {
      return Icons.ramen_dining_rounded;
    }
    if (lower.contains('باستا') || lower.contains('معكرونة') || lower.contains('اندومي') || lower.contains('pasta')) {
      return Icons.soup_kitchen_rounded;
    }
    if (lower.contains('سمك') || lower.contains('مسكوف') || lower.contains('بحري') || lower.contains('seafood') || lower.contains('روبيان')) {
      return Icons.phishing_rounded;
    }
    if (lower.contains('عصير') || lower.contains('مشروب') || lower.contains('غازي') || lower.contains('بيبسي') || lower.contains('drink')) {
      return Icons.local_drink_rounded;
    }
    if (lower.contains('قهوة') || lower.contains('شاي') || lower.contains('كافيه') || lower.contains('coffee') || lower.contains('tea')) {
      return Icons.local_cafe_rounded;
    }
    if (lower.contains('حلو') || lower.contains('كيك') || lower.contains('كنافة') || lower.contains('وافل') || lower.contains('dessert')) {
      return Icons.cake_rounded;
    }
    if (lower.contains('ايس') || lower.contains('مثلجات') || lower.contains('بوظة') || lower.contains('ice cream')) {
      return Icons.icecream_rounded;
    }
    if (lower.contains('فطور') || lower.contains('صباح') || lower.contains('معجنات') || lower.contains('مناقيش') || lower.contains('breakfast')) {
      return Icons.bakery_dining_rounded;
    }
    if (lower.contains('بوكس') || lower.contains('عائل') || lower.contains('box') || lower.contains('كومبو') || lower.contains('combo')) {
      return Icons.inventory_2_rounded;
    }
    if (lower.contains('عرض') || lower.contains('عروض') || lower.contains('offer') || lower.contains('خصم')) {
      return Icons.local_offer_rounded;
    }
    if (lower.contains('رئيسي') || lower.contains('وجب') || lower.contains('رز') || lower.contains('قوزي') || lower.contains('برياني')) {
      return Icons.dinner_dining_rounded;
    }

    return Icons.restaurant_menu_rounded;
  }

  /// جلب لون مميز للقسم
  static Color getColorForCategory(String categoryName) {
    final lower = categoryName.trim().toLowerCase();

    if (lower == 'الكل') return const Color(0xFF26A69A);
    if (lower.contains('برجر')) return const Color(0xFFFFB74D);
    if (lower.contains('بيتزا')) return const Color(0xFFFF8A65);
    if (lower.contains('شاورما')) return const Color(0xFFA1887F);
    if (lower.contains('مشاوي')) return const Color(0xFFE57373);
    if (lower.contains('دجاج')) return const Color(0xFFFFA726);
    if (lower.contains('مقبلات') || lower.contains('سلطة')) return const Color(0xFF81C784);
    if (lower.contains('مشروب')) return const Color(0xFF4DD0E1);
    if (lower.contains('قهوة') || lower.contains('شاي')) return const Color(0xFF8D6E63);
    if (lower.contains('حلو')) return const Color(0xFFBA68C8);
    if (lower.contains('سمك')) return const Color(0xFF4FC3F7);
    if (lower.contains('فطور')) return const Color(0xFFFFCA28);
    if (lower.contains('بوكس')) return const Color(0xFF7E57C2);

    return const Color(0xFF00796B);
  }
}
