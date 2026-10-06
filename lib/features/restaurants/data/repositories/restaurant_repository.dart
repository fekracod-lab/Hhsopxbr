import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/restaurant_models.dart';
import '../../domain/entities/restaurant_details_models.dart';
import '../datasources/restaurant_remote_datasource.dart';

/// مستودع بيانات المطاعم (Restaurant Repository Implementation)
class RestaurantRepository {
  final RestaurantRemoteDatasource _remoteDatasource;

  RestaurantRepository({
    required RestaurantRemoteDatasource remoteDatasource,
  }) : _remoteDatasource = remoteDatasource;

  /// جلب كافة المطاعم وتحويلها إلى كيانات مجردة (RestaurantEntity)
  Future<List<RestaurantEntity>> getRestaurants() async {
    final rawDocs = await _remoteDatasource.fetchRestaurants();
    return rawDocs.map(_mapToRestaurantEntity).toList();
  }

  /// جلب بيانات مطعم محدد بالمعرّف
  Future<RestaurantEntity?> getRestaurantById(String restaurantId) async {
    final rawData = await _remoteDatasource.fetchRestaurantById(restaurantId);
    if (rawData == null) return null;
    return _mapToRestaurantEntity(rawData);
  }

  /// جلب الوجبات المميزة والأكثر طلباً
  Future<List<MenuItemEntity>> getPopularMeals() async {
    final rawMeals = await _remoteDatasource.fetchPopularMeals();
    return rawMeals.map(_mapToMenuItemEntity).toList();
  }

  /// جلب البيانات الخام للوجبات الأكثر طلباً للعجلة والشبكة التفاعلية
  Future<List<Map<String, dynamic>>> getPopularMealsRaw() async {
    return _remoteDatasource.fetchPopularMeals();
  }

  /// مراقبة عناصر سلة التسوق الفعالة
  Stream<List<CartItemEntity>> watchCartItems(String effectiveCartId) {
    return _remoteDatasource.watchCartItems(effectiveCartId).map((items) {
      return items.map(_mapToCartItemEntity).toList();
    });
  }

  /// مراقبة طلبات المستخدم النشطة
  Stream<List<ActiveOrderEntity>> watchActiveOrders(String uid) {
    return _remoteDatasource.watchUserOrders(uid).map((orders) {
      return orders.map(_mapToActiveOrderEntity).toList();
    });
  }

  /// جلب آخر طلب للمستخدم (لإعادة الطلب السريع)
  Future<ActiveOrderEntity?> getLatestOrder(String uid) async {
    final rawOrder = await _remoteDatasource.fetchLatestOrder(uid);
    if (rawOrder == null) return null;
    return _mapToActiveOrderEntity(rawOrder);
  }

  /// مراقبة السلة الجماعية الحية
  Stream<GroupCartEntity?> watchGroupCart(String code) {
    return _remoteDatasource.watchGroupCart(code).map((data) {
      if (data == null) return null;
      return _mapToGroupCartEntity(data);
    });
  }

  /// جلب بيانات السلة الجماعية
  Future<GroupCartEntity?> getGroupCart(String code) async {
    final rawData = await _remoteDatasource.getGroupCart(code);
    if (rawData == null) return null;
    return _mapToGroupCartEntity(rawData);
  }

  /// إنشاء سلة جماعية جديدة
  Future<void> createGroupCart({
    required String code,
    required String hostId,
    required String hostName,
  }) {
    return _remoteDatasource.createGroupCart(
      code: code,
      hostId: hostId,
      hostName: hostName,
    );
  }

  /// إلغاء تفعيل السلة الجماعية
  Future<void> deactivateGroupCart(String code) {
    return _remoteDatasource.deactivateGroupCart(code);
  }

  /// جلب سياق تصنيفات المطعم والقسم الخاص به
  Future<({String sectionId, String itemId, List<MenuCategoryEntity> categories})?> getRestaurantMenuContext(String restaurantId) async {
    final rawData = await _remoteDatasource.discoverRestaurantMenuContext(restaurantId);
    if (rawData == null) return null;

    final sectionId = rawData['sectionId']?.toString() ?? '';
    final itemId = rawData['itemId']?.toString() ?? '';
    final rawCats = rawData['categories'] as List<dynamic>? ?? [];

    final categories = rawCats.map((c) {
      final map = Map<String, dynamic>.from(c as Map);
      return MenuCategoryEntity(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        iconCode: (map['iconCode'] as num?)?.toInt() ?? 0xe2aa,
      );
    }).where((c) => c.name.isNotEmpty).toList();

    return (sectionId: sectionId, itemId: itemId, categories: categories);
  }

  /// مراقبة وجبات المنيو لتصنيف محدد
  Stream<List<MenuItemDetailsEntity>> watchMenuItems({
    required String sectionId,
    required String itemId,
    String? category,
    String? sortBy,
  }) {
    return _remoteDatasource.watchMenuItems(
      sectionId: sectionId,
      itemId: itemId,
      category: category,
      sortBy: sortBy,
    ).map((items) {
      return items.map(_mapToMenuItemDetailsEntity).toList();
    });
  }

  /// مراقبة الوجبات مباشرة من restaurants/{id}/menu أو merchant_products/{id}/products
  /// يُستخدم عندما لا يتوفر sectionId/itemId (المطاعم المسجلة عبر نظام الكاشير الجديد)
  Stream<List<MenuItemDetailsEntity>> watchMenuItemsDirect({
    required String restaurantId,
    String? category,
    String? sortBy,
  }) {
    return _remoteDatasource.watchMenuItemsDirect(
      restaurantId: restaurantId,
      category: category,
      sortBy: sortBy,
    ).map((items) {
      return items.map(_mapToMenuItemDetailsEntity).toList();
    });
  }

  /// إضافة أو تعديل كمية صنف في السلة
  Future<void> addCartItem({
    required String cartId,
    required String itemId,
    required String name,
    required double price,
    int quantity = 1,
    required String restaurantId,
    required String restaurantName,
    String? imageUrl,
    String size = '',
    String options = '',
    String notes = '',
    String? addedByName,
  }) {
    return _remoteDatasource.addCartItem(
      cartId: cartId,
      itemId: itemId,
      name: name,
      price: price,
      quantity: quantity,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      imageUrl: imageUrl,
      size: size,
      options: options,
      notes: notes,
      addedByName: addedByName,
    );
  }

  /// إنقاص كمية صنف أو حذفه من السلة
  Future<void> removeCartItem({
    required String cartId,
    required String itemId,
  }) {
    return _remoteDatasource.removeCartItem(
      cartId: cartId,
      itemId: itemId,
    );
  }

  /// مراقبة تقييمات ومراجعات المطعم
  Stream<List<RestaurantReviewEntity>> watchRestaurantReviews(String restaurantId) {
    return _remoteDatasource.watchRestaurantReviews(restaurantId).map((reviews) {
      return reviews.map(_mapToRestaurantReviewEntity).toList();
    });
  }

  /// إضافة تقييم للمطعم
  Future<void> addRestaurantReview({
    required String restaurantId,
    required double rating,
    required String comment,
    required String userId,
    required String userName,
  }) {
    return _remoteDatasource.addRestaurantReview(
      restaurantId: restaurantId,
      rating: rating,
      comment: comment,
      userId: userId,
      userName: userName,
    );
  }

  /// حذف تقييم للمطعم
  Future<void> deleteRestaurantReview({
    required String restaurantId,
    required String reviewId,
  }) {
    return _remoteDatasource.deleteRestaurantReview(
      restaurantId: restaurantId,
      reviewId: reviewId,
    );
  }

  // ─── دوال التحويل الآمنة (Defensive Mappers) ──────────────────────────────

  RestaurantEntity _mapToRestaurantEntity(Map<String, dynamic> data) {
    final categoriesRaw = data['categories'];
    final List<String> categoriesList = [];
    if (categoriesRaw is List) {
      for (var c in categoriesRaw) {
        if (c != null && c.toString().isNotEmpty) {
          categoriesList.add(c.toString());
        }
      }
    }

    return RestaurantEntity(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? data['fullName']?.toString() ?? 'مطعم',
      imageUrl: (data['imageUrl'] ?? data['logoUrl'] ?? data['image'] ?? data['profileImage'] ?? '').toString(),
      rating: (data['rating'] as num?)?.toDouble() ?? 4.8,
      deliveryTime: data['deliveryTime']?.toString() ?? '35',
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble() ?? 1500.0,
      isOpen: data['isOpen'] as bool? ?? true,
      category: data['category']?.toString() ?? '',
      categories: categoriesList,
      createdAt: _parseDateTime(data['createdAt']),
      rawData: data,
    );
  }

  MenuItemEntity _mapToMenuItemEntity(Map<String, dynamic> data) {
    return MenuItemEntity(
      id: (data['mealId'] ?? data['id'] ?? '').toString(),
      mealName: (data['mealName'] ?? data['name'] ?? 'وجبة').toString(),
      mealPrice: (data['mealPrice'] ?? data['price'] as num?)?.toDouble() ?? 0.0,
      mealImage: (data['mealImage'] ?? data['imageUrl'] ?? data['image'] ?? '').toString(),
      restaurantName: (data['restaurantName'] ?? '').toString(),
      restaurantId: (data['restaurantId'] ?? '').toString(),
      category: (data['category'] ?? 'المطاعم').toString(),
      isAvailable: data['isAvailable'] as bool? ?? true,
      rawData: data,
    );
  }

  MenuItemDetailsEntity _mapToMenuItemDetailsEntity(Map<String, dynamic> data) {
    return MenuItemDetailsEntity(
      id: (data['id'] ?? data['mealId'] ?? '').toString(),
      name: (data['name'] ?? data['mealName'] ?? 'وجبة').toString(),
      price: ((data['price'] ?? data['mealPrice'] ?? 0.0) as num).toDouble(),
      imageUrl: (data['imageUrl'] ?? data['mealImage'] ?? data['image'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      category: (data['category'] ?? 'الكل').toString(),
      available: data['available'] as bool? ?? data['isAvailable'] as bool? ?? true,
      rawData: data,
    );
  }

  RestaurantReviewEntity _mapToRestaurantReviewEntity(Map<String, dynamic> data) {
    return RestaurantReviewEntity(
      id: (data['id'] ?? '').toString(),
      rating: ((data['rating'] ?? 0.0) as num).toDouble(),
      comment: (data['comment'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? 'مستخدم').toString(),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  CartItemEntity _mapToCartItemEntity(Map<String, dynamic> data) {
    return CartItemEntity(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      price: ((data['price'] ?? 0.0) as num).toDouble(),
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      restaurantId: data['restaurantId']?.toString(),
    );
  }

  ActiveOrderEntity _mapToActiveOrderEntity(Map<String, dynamic> data) {
    return ActiveOrderEntity(
      id: (data['id'] ?? '').toString(),
      restaurantId: data['restaurantId']?.toString(),
      restaurantName: data['restaurantName']?.toString(),
      status: (data['status'] ?? 'pending').toString(),
      totalPrice: ((data['totalPrice'] ?? data['total'] ?? 0.0) as num).toDouble(),
      createdAt: _parseDateTime(data['createdAt']),
      rawData: data,
    );
  }

  GroupCartEntity _mapToGroupCartEntity(Map<String, dynamic> data) {
    return GroupCartEntity(
      code: (data['code'] ?? '').toString(),
      hostId: (data['hostId'] ?? '').toString(),
      hostName: (data['hostName'] ?? 'مضيف').toString(),
      active: data['active'] as bool? ?? true,
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
