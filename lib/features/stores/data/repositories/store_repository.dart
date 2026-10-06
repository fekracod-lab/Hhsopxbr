import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/store_dashboard_models.dart';
import '../datasources/store_remote_datasource.dart';

/// مستودع بيانات المتجر (Store Repository Implementation)
/// يقوم بتحويل بيانات Firestore الخام إلى كيانات النطاق الصافية (Domain Entities)
/// وتفويض عمليات التخزين إلى StoreRemoteDatasource
class StoreRepository {
  final StoreRemoteDatasource _remoteDatasource;

  StoreRepository({StoreRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? StoreRemoteDatasource();

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 1. ترحيل وتحديث البيانات القديمة (Migration) ───────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> migrateOldData(String storeId) async {
    await _remoteDatasource.migrateOldData(storeId);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 2. مراقبة وإدارة الطلبات (Orders Management) ───────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// مراقبة الطلبات المعلقة
  Stream<List<StoreOrderEntity>> watchPendingOrders(String storeId) {
    return _remoteDatasource
        .watchPendingOrders(storeId)
        .map((list) => list.map(_mapOrderFromMap).toList());
  }

  /// مراقبة جميع الطلبات للإحصائيات العامة
  Stream<List<StoreOrderEntity>> watchAllOrders(String storeId) {
    return _remoteDatasource
        .watchAllOrders(storeId)
        .map((list) => list.map(_mapOrderFromMap).toList());
  }

  /// مراقبة قائمة الطلبات مرتبة تنازلياً
  Stream<List<StoreOrderEntity>> watchOrders(String storeId) {
    return _remoteDatasource
        .watchOrders(storeId)
        .map((list) => list.map(_mapOrderFromMap).toList());
  }

  /// تعليم الطلب كمقروء
  Future<void> markOrderAsRead({
    required String storeId,
    required String orderId,
  }) async {
    await _remoteDatasource.markOrderAsRead(storeId: storeId, orderId: orderId);
  }

  /// تحديث حالة الطلب ذرياً مع النقاط ورصيد المحفظة
  Future<void> updateOrderStatus({
    required String storeId,
    required String orderId,
    required String nextStatus,
  }) async {
    await _remoteDatasource.updateOrderStatus(
      storeId: storeId,
      orderId: orderId,
      nextStatus: nextStatus,
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 3. مراقبة وإدارة المنتجات (Products CRUD) ──────────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// مراقبة منتجات المتجر
  Stream<List<StoreProductEntity>> watchProducts(String storeId) {
    return _remoteDatasource
        .watchProducts(storeId)
        .map((list) => list.map(_mapProductFromMap).toList());
  }

  /// إضافة منتج جديد
  Future<void> createProduct({
    required String storeId,
    required String name,
    required double price,
    String description = '',
    String category = 'عام',
    String imageUrl = '',
    bool isAvailable = true,
  }) async {
    final payload = {
      'name': name.trim(),
      'price': price < 0 ? 0.0 : price,
      'description': description.trim(),
      'category': category.trim().isEmpty ? 'عام' : category.trim(),
      'imageUrl': imageUrl.trim(),
      'isAvailable': isAvailable,
    };
    await _remoteDatasource.createProduct(storeId: storeId, productData: payload);
  }

  /// تعديل بيانات منتج
  Future<void> updateProduct({
    required String storeId,
    required String productId,
    required String name,
    required double price,
    String description = '',
    String category = 'عام',
    String imageUrl = '',
    bool isAvailable = true,
  }) async {
    final payload = {
      'name': name.trim(),
      'price': price < 0 ? 0.0 : price,
      'description': description.trim(),
      'category': category.trim().isEmpty ? 'عام' : category.trim(),
      'imageUrl': imageUrl.trim(),
      'isAvailable': isAvailable,
    };
    await _remoteDatasource.updateProduct(
      storeId: storeId,
      productId: productId,
      productData: payload,
    );
  }

  /// حذف منتج
  Future<void> deleteProduct({
    required String storeId,
    required String productId,
  }) async {
    await _remoteDatasource.deleteProduct(storeId: storeId, productId: productId);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 4. مراقبة وإدارة التصنيفات (Categories CRUD) ────────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// مراقبة التصنيفات
  Stream<List<StoreCategoryEntity>> watchCategories(String storeId) {
    return _remoteDatasource
        .watchCategories(storeId)
        .map((list) => list.map(_mapCategoryFromMap).toList());
  }

  /// إضافة تصنيف جديد
  Future<void> createCategory({
    required String storeId,
    required String name,
    int iconCode = 0xe148,
    int colorValue = 0xFFF5F5F5,
  }) async {
    await _remoteDatasource.createCategory(
      storeId: storeId,
      name: name,
      iconCode: iconCode,
      colorValue: colorValue,
    );
  }

  /// حذف تصنيف
  Future<void> deleteCategory({
    required String storeId,
    required String categoryId,
  }) async {
    await _remoteDatasource.deleteCategory(storeId: storeId, categoryId: categoryId);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 5. مراقبة وإدارة الإعلانات الترويجية (Banners CRUD) ─────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// مراقبة إعلانات المتجر
  Stream<List<StoreBannerEntity>> watchBanners(String storeId) {
    return _remoteDatasource
        .watchBanners(storeId)
        .map((list) => list.map(_mapBannerFromMap).toList());
  }

  /// إضافة إعلان ترويجي
  Future<void> createBanner({
    required String storeId,
    required String title,
    String subtitle = '',
    required String imageUrl,
  }) async {
    await _remoteDatasource.createBanner(
      storeId: storeId,
      title: title,
      subtitle: subtitle,
      imageUrl: imageUrl,
    );
  }

  /// حذف إعلان ترويجي
  Future<void> deleteBanner({
    required String storeId,
    required String bannerId,
  }) async {
    await _remoteDatasource.deleteBanner(storeId: storeId, bannerId: bannerId);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 6. ملف المتجر ونقل الملكية (Profile & Ownership) ───────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// جلب بيانات المتجر
  Future<StoreDashboardEntity?> getStoreById(String storeId) async {
    final data = await _remoteDatasource.getStoreById(storeId);
    if (data == null) return null;
    return _mapStoreFromMap(data);
  }

  /// مراقبة بيانات وتحديثات المتجر
  Stream<StoreDashboardEntity?> watchStore(String storeId) {
    return _remoteDatasource.watchStore(storeId).map((data) {
      if (data == null) return null;
      return _mapStoreFromMap(data);
    });
  }

  /// تحديث الملف التعريفي للمتجر
  Future<void> updateStoreProfile({
    required String storeId,
    required String name,
    String? logoUrl,
    String? coverUrl,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    await _remoteDatasource.updateStoreProfile(
      storeId: storeId,
      name: name,
      logoUrl: logoUrl,
      coverUrl: coverUrl,
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
  }

  /// نقل الملكية لمستخدم آخر عبر البريد
  Future<bool> transferStoreOwnership({
    required String storeId,
    required String targetEmail,
  }) async {
    return await _remoteDatasource.transferStoreOwnership(
      storeId: storeId,
      targetEmail: targetEmail,
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 7. محولات الكيانات الدفاعية (Defensive Domain Mappers) ──────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  StoreDashboardEntity _mapStoreFromMap(Map<String, dynamic> data) {
    return StoreDashboardEntity(
      storeId: data['id']?.toString() ?? data['storeId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      logoUrl: data['logoUrl']?.toString() ?? '',
      coverUrl: data['coverUrl']?.toString() ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      address: data['address']?.toString() ?? '',
      ownerId: data['ownerId']?.toString() ?? '',
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
      rawData: data,
    );
  }

  StoreOrderEntity _mapOrderFromMap(Map<String, dynamic> data) {
    final statusStr = data['status']?.toString() ?? 'pending';
    final itemsRaw = data['items'];
    final List<StoreOrderItemEntity> items = [];

    if (itemsRaw is List) {
      for (final it in itemsRaw) {
        if (it is Map) {
          items.add(StoreOrderItemEntity(
            itemId: it['itemId']?.toString() ?? it['id']?.toString() ?? '',
            name: it['name']?.toString() ?? '',
            price: (it['price'] as num? ?? 0.0).toDouble(),
            quantity: (it['quantity'] as num? ?? 1).toInt(),
            imageUrl: it['imageUrl']?.toString() ?? '',
            size: it['size']?.toString() ?? '',
            options: it['options']?.toString() ?? '',
            notes: it['notes']?.toString() ?? '',
          ));
        }
      }
    }

    final total = (data['total'] as num? ?? data['totalPrice'] as num? ?? 0.0).toDouble();

    return StoreOrderEntity(
      orderId: data['id']?.toString() ?? data['orderId']?.toString() ?? '',
      status: statusStr,
      orderStatus: StoreOrderStatus.fromString(statusStr),
      customerId: data['customerId']?.toString() ?? data['userId']?.toString() ?? '',
      customerName: data['customerName']?.toString() ?? '',
      customerPhone: data['customerPhone']?.toString() ?? data['phone']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      total: total < 0.0 || total.isNaN ? 0.0 : total,
      items: items,
      pointsEarned: (data['pointsEarned'] as num? ?? 0).toInt(),
      pointsUsed: (data['pointsUsed'] as num? ?? 0).toInt(),
      paymentStatus: data['paymentStatus']?.toString() ?? '',
      readByStore: data['readByStore'] == true,
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
      rawData: data,
    );
  }

  StoreProductEntity _mapProductFromMap(Map<String, dynamic> data) {
    final price = (data['price'] as num? ?? 0.0).toDouble();
    return StoreProductEntity(
      productId: data['id']?.toString() ?? data['productId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      price: price < 0.0 || price.isNaN ? 0.0 : price,
      description: data['description']?.toString() ?? '',
      category: data['category']?.toString() ?? 'عام',
      imageUrl: data['imageUrl']?.toString() ?? '',
      isAvailable: data['isAvailable'] != false,
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
      rawData: data,
    );
  }

  StoreCategoryEntity _mapCategoryFromMap(Map<String, dynamic> data) {
    return StoreCategoryEntity(
      categoryId: data['id']?.toString() ?? data['categoryId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      iconCode: (data['iconCode'] as num? ?? 0xe148).toInt(),
      colorValue: (data['colorValue'] as num? ?? 0xFFF5F5F5).toInt(),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  StoreBannerEntity _mapBannerFromMap(Map<String, dynamic> data) {
    return StoreBannerEntity(
      bannerId: data['id']?.toString() ?? data['bannerId']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      subtitle: data['subtitle']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
