import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/store_dashboard_models.dart';
import '../../domain/entities/store_cart_item_entity.dart';
import '../../domain/entities/store_checkout_models.dart';
import '../datasources/store_details_remote_datasource.dart';

/// مستودع بيانات تفاصيل المتجر والطلب (Store Details Repository Implementation)
/// يقوم بربط وتحويل البيانات الخام من StoreDetailsRemoteDatasource إلى كيانات النطاق الصافية
class StoreDetailsRepository {
  final StoreDetailsRemoteDatasource _remoteDatasource;

  StoreDetailsRepository({StoreDetailsRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? StoreDetailsRemoteDatasource();

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 1. التدفقات واسترجاع البيانات (Streams & Queries) ──────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// مراقبة قائمة المنتجات
  Stream<List<StoreProductEntity>> watchProducts(String storeId) {
    return _remoteDatasource
        .watchProducts(storeId)
        .map((list) => list.map(_mapProductFromMap).toList());
  }

  /// مراقبة قائمة الأقسام
  Stream<List<StoreCategoryEntity>> watchCategories(String storeId) {
    return _remoteDatasource
        .watchCategories(storeId)
        .map((list) => list.map(_mapCategoryFromMap).toList());
  }

  /// مراقبة قائمة الإعلانات
  Stream<List<StoreBannerEntity>> watchBanners(String storeId) {
    return _remoteDatasource
        .watchBanners(storeId)
        .map((list) => list.map(_mapBannerFromMap).toList());
  }

  /// جلب بيانات المتجر
  Future<StoreDashboardEntity?> getStore(String storeId) async {
    final raw = await _remoteDatasource.getStore(storeId);
    if (raw == null) return null;
    return _mapStoreFromMap(raw);
  }

  /// جلب بيانات المستخدم
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    return _remoteDatasource.getUserProfile(userId);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 2. إتمام الطلب ذرياً (Atomic Checkout) ─────────────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// إتمام الطلب ذرياً عبر Datasource Transaction
  Future<bool> placeOrderAtomic({
    required String storeId,
    required String userId,
    required String orderId,
    required String customerName,
    required String customerPhone,
    required String address,
    required String notes,
    double? latitude,
    double? longitude,
    required Map<String, dynamic> storeData,
    required List<StoreCartItemEntity> items,
    required StoreCheckoutSummaryEntity summary,
  }) async {
    return _remoteDatasource.placeOrderAtomic(
      storeId: storeId,
      userId: userId,
      orderId: orderId,
      customerName: customerName,
      customerPhone: customerPhone,
      address: address,
      notes: notes,
      latitude: latitude,
      longitude: longitude,
      storeData: storeData,
      items: items,
      summary: summary,
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 3. إدارة المنتجات والأقسام للأدمن/المالك ───────────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> createProduct({
    required String storeId,
    required Map<String, dynamic> productData,
  }) async {
    await _remoteDatasource.createProduct(
      storeId: storeId,
      productData: productData,
    );
  }

  Future<void> updateProduct({
    required String storeId,
    required String productId,
    required Map<String, dynamic> productData,
  }) async {
    await _remoteDatasource.updateProduct(
      storeId: storeId,
      productId: productId,
      productData: productData,
    );
  }

  Future<void> deleteProduct({
    required String storeId,
    required String productId,
  }) async {
    await _remoteDatasource.deleteProduct(
      storeId: storeId,
      productId: productId,
    );
  }

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

  Future<void> updateCategory({
    required String storeId,
    required String categoryId,
    required Map<String, dynamic> categoryData,
  }) async {
    await _remoteDatasource.updateCategory(
      storeId: storeId,
      categoryId: categoryId,
      categoryData: categoryData,
    );
  }

  Future<void> deleteCategory({
    required String storeId,
    required String categoryId,
  }) async {
    await _remoteDatasource.deleteCategory(
      storeId: storeId,
      categoryId: categoryId,
    );
  }

  Future<void> addBanner({
    required String storeId,
    required String imageUrl,
  }) async {
    await _remoteDatasource.addBanner(
      storeId: storeId,
      imageUrl: imageUrl,
    );
  }

  Future<void> deleteBanner({
    required String storeId,
    required String bannerId,
  }) async {
    await _remoteDatasource.deleteBanner(
      storeId: storeId,
      bannerId: bannerId,
    );
  }

  Future<void> migrateOldCategories(String storeId) async {
    await _remoteDatasource.migrateOldCategories(storeId);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 4. الخدمات الخارجية (Cloudinary & Geolocation) ─────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<String?> uploadImageToCloudinary({
    required String filePath,
  }) async {
    return _remoteDatasource.uploadImageToCloudinary(filePath: filePath);
  }

  Future<Map<String, dynamic>?> getCurrentLocationAndAddress() async {
    return _remoteDatasource.getCurrentLocationAndAddress();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 5. دوال التحويل الصافية (Defensive Mappers) ─────────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  StoreProductEntity _mapProductFromMap(Map<String, dynamic> data) {
    final rawPrice = data['price'];
    double parsedPrice = 0.0;
    if (rawPrice is num) {
      parsedPrice = rawPrice.toDouble();
    } else if (rawPrice is String) {
      final sanitized = rawPrice.replaceAll(RegExp(r'[^0-9.]'), '');
      parsedPrice = double.tryParse(sanitized) ?? 0.0;
    }

    return StoreProductEntity(
      productId: (data['id'] ?? data['productId'] ?? '').toString(),
      name: (data['name'] ?? data['title'] ?? '').toString(),
      price: parsedPrice < 0.0 || parsedPrice.isNaN ? 0.0 : parsedPrice,
      description: (data['description'] ?? '').toString(),
      category: (data['category'] ?? 'عام').toString(),
      imageUrl: (data['imageUrl'] ?? data['image'] ?? '').toString(),
      isAvailable: data['isAvailable'] != false,
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
      rawData: data,
    );
  }

  StoreCategoryEntity _mapCategoryFromMap(Map<String, dynamic> data) {
    return StoreCategoryEntity(
      categoryId: (data['id'] ?? data['categoryId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      iconCode: (data['iconCode'] as num? ?? 0xe148).toInt(),
      colorValue: (data['colorValue'] as num? ?? 0xFFF5F5F5).toInt(),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  StoreBannerEntity _mapBannerFromMap(Map<String, dynamic> data) {
    return StoreBannerEntity(
      bannerId: (data['id'] ?? data['bannerId'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      subtitle: (data['subtitle'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? data['image'] ?? '').toString(),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  StoreDashboardEntity _mapStoreFromMap(Map<String, dynamic> data) {
    return StoreDashboardEntity(
      storeId: (data['id'] ?? data['storeId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      logoUrl: (data['logoUrl'] ?? '').toString(),
      coverUrl: (data['coverUrl'] ?? '').toString(),
      address: (data['address'] ?? data['location'] ?? '').toString(),
      ownerId: (data['ownerId'] ?? '').toString(),
      latitude: (data['latitude'] ?? data['lat'] as num?)?.toDouble(),
      longitude: (data['longitude'] ?? data['lng'] as num?)?.toDouble(),
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
      rawData: data,
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
