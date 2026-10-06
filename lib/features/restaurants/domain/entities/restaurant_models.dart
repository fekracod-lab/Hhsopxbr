/// سجل كيان المطعم المجرد (Restaurant Domain Entity)
class RestaurantEntity {
  final String id;
  final String name;
  final String imageUrl;
  final double rating;
  final String deliveryTime;
  final double deliveryFee;
  final bool isOpen;
  final String category;
  final List<String> categories;
  final DateTime? createdAt;
  final Map<String, dynamic> rawData;

  const RestaurantEntity({
    required this.id,
    required this.name,
    this.imageUrl = '',
    this.rating = 4.8,
    this.deliveryTime = '35',
    this.deliveryFee = 1500.0,
    this.isOpen = true,
    this.category = '',
    this.categories = const [],
    this.createdAt,
    this.rawData = const {},
  });

  bool get isFreeDelivery => deliveryFee == 0.0;
}

/// سجل صنف الطعام والوجبة (Menu Item Entity)
class MenuItemEntity {
  final String id;
  final String mealName;
  final double mealPrice;
  final String mealImage;
  final String restaurantName;
  final String restaurantId;
  final String category;
  final bool isAvailable;
  final Map<String, dynamic> rawData;

  const MenuItemEntity({
    required this.id,
    required this.mealName,
    required this.mealPrice,
    this.mealImage = '',
    this.restaurantName = '',
    this.restaurantId = '',
    this.category = 'المطاعم',
    this.isAvailable = true,
    this.rawData = const {},
  });
}

/// عنصر سلة التسوق (Cart Item Entity)
class CartItemEntity {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String? restaurantId;

  const CartItemEntity({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.restaurantId,
  });

  double get totalPrice => price * quantity;
}

/// ملخص سلة التسوق المالي والعددي
class CartSummaryEntity {
  final int totalCount;
  final double totalPrice;

  const CartSummaryEntity({
    required this.totalCount,
    required this.totalPrice,
  });

  factory CartSummaryEntity.empty() => const CartSummaryEntity(totalCount: 0, totalPrice: 0.0);
}

/// الطلب النشط للعميل (Active Order Entity)
class ActiveOrderEntity {
  final String id;
  final String? restaurantId;
  final String? restaurantName;
  final String status;
  final double totalPrice;
  final DateTime? createdAt;
  final Map<String, dynamic> rawData;

  const ActiveOrderEntity({
    required this.id,
    this.restaurantId,
    this.restaurantName,
    required this.status,
    this.totalPrice = 0.0,
    this.createdAt,
    this.rawData = const {},
  });

  bool get isPending => status == 'pending' || status == 'placed';
  bool get isAccepted => status == 'accepted';
  bool get isDelivering => status == 'delivering' || status == 'on_the_way' || status == 'picked_up';
}

/// سجل السلة الجماعية المشتركة (Group Cart Entity)
class GroupCartEntity {
  final String code;
  final String hostId;
  final String hostName;
  final bool active;
  final DateTime? createdAt;

  const GroupCartEntity({
    required this.code,
    required this.hostId,
    required this.hostName,
    this.active = true,
    this.createdAt,
  });
}

/// مدير سلة المجموعات التوافقي (Group Cart Legacy Manager)
class GroupCartManager {
  static String? groupCartId;
  static String? groupHostName;
  static String? groupCartCode;

  static String getEffectiveCartId(String userUid) {
    if (groupCartId != null && groupCartId!.isNotEmpty) {
      return groupCartId!;
    }
    return userUid;
  }

  static void clear() {
    groupCartId = null;
    groupHostName = null;
    groupCartCode = null;
  }
}

