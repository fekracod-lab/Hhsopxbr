/// فئة وتصنيف قائمة الطعام (Menu Category Domain Entity)
class MenuCategoryEntity {
  final String id;
  final String name;
  final int iconCode;

  const MenuCategoryEntity({
    this.id = '',
    required this.name,
    this.iconCode = 0xe2aa, // Default: fastfood
  });
}

/// تفاصيل الوجبة في صفحة المطعم (Menu Item Details Entity)
class MenuItemDetailsEntity {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String description;
  final String category;
  final bool available;
  final Map<String, dynamic> rawData;

  const MenuItemDetailsEntity({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl = '',
    this.description = '',
    this.category = 'الكل',
    this.available = true,
    this.rawData = const {},
  });

  /// خيارات الأحجام المحددة حصراً من قبل صاحب المطعم من لوحة التحكم
  List<Map<String, dynamic>> get customSizes {
    if (rawData.containsKey('sizes') && rawData['sizes'] is List && (rawData['sizes'] as List).isNotEmpty) {
      return (rawData['sizes'] as List).map((s) {
        if (s is Map) {
          return {
            'name': (s['sizeName'] ?? s['name'])?.toString() ?? 'حجم',
            'extra': (s['extra'] ?? s['price'] as num?)?.toDouble() ?? 0.0,
          };
        }
        return {'name': s.toString(), 'extra': 0.0};
      }).toList();
    }
    return const [];
  }

  /// خيارات الإضافات الاختيارية المحددة حصراً من قبل صاحب المطعم من لوحة التحكم
  List<Map<String, dynamic>> get customAddons {
    if (rawData.containsKey('addons') && rawData['addons'] is List && (rawData['addons'] as List).isNotEmpty) {
      return (rawData['addons'] as List).map((a) {
        if (a is Map) {
          return {
            'name': a['name']?.toString() ?? 'إضافة',
            'price': (a['price'] as num?)?.toDouble() ?? 0.0,
            'icon': a['icon']?.toString() ?? '',
          };
        }
        return {'name': a.toString(), 'price': 0.0, 'icon': ''};
      }).toList();
    }
    return const [];
  }
}

/// خيار تخصيص الوجبة (الحجم أو الإضافات) (Item Customization Option)
class ItemCustomizationOption {
  final String name;
  final double extraPrice;
  final bool isSelected;
  final int? iconCode;

  const ItemCustomizationOption({
    required this.name,
    this.extraPrice = 0.0,
    this.isSelected = false,
    this.iconCode,
  });

  ItemCustomizationOption copyWith({
    String? name,
    double? extraPrice,
    bool? isSelected,
    int? iconCode,
  }) {
    return ItemCustomizationOption(
      name: name ?? this.name,
      extraPrice: extraPrice ?? this.extraPrice,
      isSelected: isSelected ?? this.isSelected,
      iconCode: iconCode ?? this.iconCode,
    );
  }
}

/// مراجعة وتقييم المطعم (Restaurant Review Entity)
class RestaurantReviewEntity {
  final String id;
  final double rating;
  final String comment;
  final String userId;
  final String userName;
  final DateTime? createdAt;

  const RestaurantReviewEntity({
    required this.id,
    required this.rating,
    this.comment = '',
    required this.userId,
    this.userName = 'مستخدم',
    this.createdAt,
  });
}

/// إحصائيات التقييمات وتوزيع النجوم (Review Statistics Entity)
class ReviewStatisticsEntity {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> starCounts;

  const ReviewStatisticsEntity({
    required this.averageRating,
    required this.totalReviews,
    required this.starCounts,
  });

  factory ReviewStatisticsEntity.empty() => const ReviewStatisticsEntity(
        averageRating: 0.0,
        totalReviews: 0,
        starCounts: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      );
}
