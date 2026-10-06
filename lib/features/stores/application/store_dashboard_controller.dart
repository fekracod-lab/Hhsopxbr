import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/entities/store_dashboard_models.dart';
import '../domain/services/store_financial_calculator.dart';
import '../data/repositories/store_repository.dart';

/// متحكم لوحة تحكم المتجر (Store Dashboard Controller)
/// المسؤول عن إدارة الحالة وتنسيق التدفقات البرمجية والتحقق من قواعد الأعمال
/// خالي تماماً من أي اعتماديات على Firebase أو UI مباشرة
class StoreDashboardController extends ChangeNotifier {
  final String storeId;
  final StoreRepository _repository;

  StoreDashboardController({
    required this.storeId,
    StoreRepository? repository,
  }) : _repository = repository ?? StoreRepository();

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 1. الحالة الداخلية والاشتراكات (State & Subscriptions) ─────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  StoreDashboardEntity? _store;
  List<StoreOrderEntity> _allOrders = [];
  List<StoreOrderEntity> _ordersList = [];
  List<StoreOrderEntity> _pendingOrders = [];
  List<StoreProductEntity> _products = [];
  List<StoreCategoryEntity> _categories = [];
  List<StoreBannerEntity> _banners = [];

  String _selectedCategoryFilter = 'الكل';
  String _selectedOrderStatusFilter = 'all';

  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDisposed = false;
  int _generation = 0;

  // أقفال العمليات لتفادي التكرار (Action Locks)
  final Set<String> _lockedOrderIds = {};
  final Set<String> _lockedProductIds = {};
  final Set<String> _lockedCategoryIds = {};
  final Set<String> _lockedBannerIds = {};

  bool _isOrderStatusMutating = false;
  bool _isProductMutating = false;
  bool _isCategoryMutating = false;
  bool _isBannerMutating = false;
  bool _isStoreProfileMutating = false;
  bool _isOwnershipTransferring = false;
  bool _isMigrating = false;

  // الاشتراكات في تيارات البيانات
  StreamSubscription<StoreDashboardEntity?>? _storeSub;
  StreamSubscription<List<StoreOrderEntity>>? _pendingOrdersSub;
  StreamSubscription<List<StoreOrderEntity>>? _allOrdersSub;
  StreamSubscription<List<StoreOrderEntity>>? _ordersListSub;
  StreamSubscription<List<StoreProductEntity>>? _productsSub;
  StreamSubscription<List<StoreCategoryEntity>>? _categoriesSub;
  StreamSubscription<List<StoreBannerEntity>>? _bannersSub;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 2. المخرجات الآمنة والقراءات المشتقة (Getters & Derived State) ─────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  StoreDashboardEntity? get store => _store;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isDisposed => _isDisposed;

  String get selectedCategoryFilter => _selectedCategoryFilter;
  String get selectedOrderStatusFilter => _selectedOrderStatusFilter;

  List<StoreOrderEntity> get allOrders => List.unmodifiable(_allOrders);
  List<StoreOrderEntity> get ordersList => List.unmodifiable(_ordersList);
  List<StoreOrderEntity> get pendingOrders => List.unmodifiable(_pendingOrders);
  List<StoreProductEntity> get products => List.unmodifiable(_products);
  List<StoreCategoryEntity> get categories => List.unmodifiable(_categories);
  List<StoreBannerEntity> get banners => List.unmodifiable(_banners);

  int get pendingOrderCount => _pendingOrders.length;

  /// إحصائيات الطلبات العامة (محسوبة نقياً عبر StoreFinancialCalculator)
  StoreOrderStatisticsEntity get orderStatistics =>
      StoreFinancialCalculator.calculateOrderStatistics(_allOrders);

  /// إجمالي الإيرادات المكتملة
  double get totalRevenue =>
      StoreFinancialCalculator.calculateTotalRevenue(_allOrders);

  /// إيرادات اليوم
  double get todayRevenue =>
      StoreFinancialCalculator.calculateTodayRevenue(
        _allOrders,
        referenceDate: DateTime.now(),
      );

  /// تعداد منتجات الأقسام (محسوب في الذاكرة دون N+1 Queries)
  Map<String, int> get categoryProductCounts =>
      StoreFinancialCalculator.calculateCategoryProductCounts(
        categories: _categories,
        products: _products,
      );

  /// قائمة الطلبات المفلترة حسب الحالة المحددة
  List<StoreOrderEntity> get filteredOrders {
    if (_selectedOrderStatusFilter == 'all') {
      return List.unmodifiable(_ordersList);
    }
    return List.unmodifiable(
      _ordersList.where((o) => o.status == _selectedOrderStatusFilter),
    );
  }

  /// قائمة المنتجات المفلترة حسب القسم المحدد
  List<StoreProductEntity> get filteredProducts {
    if (_selectedCategoryFilter == 'الكل') {
      return List.unmodifiable(_products);
    }
    return List.unmodifiable(
      _products.where((p) => p.category == _selectedCategoryFilter),
    );
  }

  // أقفال العمليات الجارية
  bool get isOrderStatusMutating => _isOrderStatusMutating;
  bool get isProductMutating => _isProductMutating;
  bool get isCategoryMutating => _isCategoryMutating;
  bool get isBannerMutating => _isBannerMutating;
  bool get isStoreProfileMutating => _isStoreProfileMutating;
  bool get isOwnershipTransferring => _isOwnershipTransferring;
  bool get isMigrating => _isMigrating;

  bool isOrderLocked(String orderId) => _lockedOrderIds.contains(orderId);
  bool isProductLocked(String productId) => _lockedProductIds.contains(productId);
  bool isCategoryLocked(String categoryId) => _lockedCategoryIds.contains(categoryId);
  bool isBannerLocked(String bannerId) => _lockedBannerIds.contains(bannerId);

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 3. التهيئة وإدارة التدفقات (Initialization & Streams) ──────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// بدء الاستماع لكافة التدفقات الخاصة بلوحة تحكم المتجر
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;
    _isInitialized = true;
    _isLoading = true;
    _errorMessage = null;
    _safeNotifyListeners();

    final currentGen = ++_generation;

    try {
      _cancelSubscriptions();

      // 1. مراقبة بيانات المتجر
      _storeSub = _repository.watchStore(storeId).listen(
        (storeData) {
          if (_generation != currentGen || _isDisposed) return;
          _store = storeData;
          _isLoading = false;
          _safeNotifyListeners();
        },
        onError: (err) {
          if (_generation != currentGen || _isDisposed) return;
          _errorMessage = err.toString();
          _isLoading = false;
          _safeNotifyListeners();
        },
      );

      // 2. مراقبة شارة الطلبات المعلقة
      _pendingOrdersSub = _repository.watchPendingOrders(storeId).listen(
        (orders) {
          if (_generation != currentGen || _isDisposed) return;
          _pendingOrders = orders;
          _safeNotifyListeners();
        },
        onError: (err) => _handleStreamError(err, currentGen),
      );

      // 3. مراقبة كافة الطلبات لحساب الإحصائيات
      _allOrdersSub = _repository.watchAllOrders(storeId).listen(
        (orders) {
          if (_generation != currentGen || _isDisposed) return;
          _allOrders = orders;
          _safeNotifyListeners();
        },
        onError: (err) => _handleStreamError(err, currentGen),
      );

      // 4. مراقبة قائمة الطلبات المعروضة
      _ordersListSub = _repository.watchOrders(storeId).listen(
        (orders) {
          if (_generation != currentGen || _isDisposed) return;
          _ordersList = orders;
          _safeNotifyListeners();
        },
        onError: (err) => _handleStreamError(err, currentGen),
      );

      // 5. مراقبة المنتجات
      _productsSub = _repository.watchProducts(storeId).listen(
        (prods) {
          if (_generation != currentGen || _isDisposed) return;
          _products = prods;
          _safeNotifyListeners();
        },
        onError: (err) => _handleStreamError(err, currentGen),
      );

      // 6. مراقبة التصنيفات
      _categoriesSub = _repository.watchCategories(storeId).listen(
        (cats) {
          if (_generation != currentGen || _isDisposed) return;
          _categories = cats;
          _safeNotifyListeners();
        },
        onError: (err) => _handleStreamError(err, currentGen),
      );

      // 7. مراقبة الإعلانات
      _bannersSub = _repository.watchBanners(storeId).listen(
        (bans) {
          if (_generation != currentGen || _isDisposed) return;
          _banners = bans;
          _safeNotifyListeners();
        },
        onError: (err) => _handleStreamError(err, currentGen),
      );
    } catch (e) {
      if (_generation == currentGen && !_isDisposed) {
        _errorMessage = e.toString();
        _isLoading = false;
        _safeNotifyListeners();
      }
    }
  }

  void _handleStreamError(dynamic err, int currentGen) {
    if (_generation != currentGen || _isDisposed) return;
    _errorMessage = err.toString();
    _safeNotifyListeners();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 4. تصفية العرض والتحكم (Filters) ───────────────────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void setCategoryFilter(String category) {
    if (_selectedCategoryFilter == category || _isDisposed) return;
    _selectedCategoryFilter = category;
    _safeNotifyListeners();
  }

  void setOrderStatusFilter(String statusFilter) {
    if (_selectedOrderStatusFilter == statusFilter || _isDisposed) return;
    _selectedOrderStatusFilter = statusFilter;
    _safeNotifyListeners();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 5. العمليات على الطلبات (Order Operations) ─────────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// تعليم الطلب كمقروء
  Future<void> markOrderAsRead(String orderId) async {
    if (orderId.trim().isEmpty || _isDisposed) return;
    if (_lockedOrderIds.contains(orderId)) return;

    _lockedOrderIds.add(orderId);
    try {
      await _repository.markOrderAsRead(storeId: storeId, orderId: orderId);
    } finally {
      _lockedOrderIds.remove(orderId);
    }
  }

  /// تحديث حالة الطلب مع التحقق من صحة الانتقال وحفظ الذرية (P0 Order Status Transition)
  Future<bool> updateOrderStatus({
    required String orderId,
    required String nextStatus,
  }) async {
    if (orderId.trim().isEmpty || _isDisposed) return false;
    if (_lockedOrderIds.contains(orderId) || _isOrderStatusMutating) return false;

    // البحث عن الطلب للتحقق من الحالة السابقة
    final order = _ordersList.cast<StoreOrderEntity?>().firstWhere(
          (o) => o?.orderId == orderId,
          orElse: () => _allOrders.cast<StoreOrderEntity?>().firstWhere(
                (o) => o?.orderId == orderId,
                orElse: () => null,
              ),
        );

    if (order != null) {
      final currentStatus = StoreOrderStatus.fromString(order.status);
      final targetStatus = StoreOrderStatus.fromString(nextStatus);
      if (!StoreFinancialCalculator.canTransitionOrderStatus(
        currentStatus: currentStatus,
        nextStatus: targetStatus,
      )) {
        return false; // انتقالة غير مسموحة وفق آلة الحالة
      }
    }

    _lockedOrderIds.add(orderId);
    _isOrderStatusMutating = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      await _repository.updateOrderStatus(
        storeId: storeId,
        orderId: orderId,
        nextStatus: nextStatus,
      );
      return true;
    } catch (e) {
      if (!_isDisposed) {
        _errorMessage = e.toString();
        _safeNotifyListeners();
      }
      return false;
    } finally {
      _lockedOrderIds.remove(orderId);
      _isOrderStatusMutating = false;
      _safeNotifyListeners();
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 6. عمليات المنتجات والتصنيفات والإعلانات (CRUD Operations) ──────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// إنشاء منتج جديد
  Future<bool> createProduct({
    required String name,
    required double price,
    String description = '',
    String category = 'عام',
    String imageUrl = '',
    bool isAvailable = true,
  }) async {
    if (_isDisposed || _isProductMutating) return false;
    if (name.trim().isEmpty) return false;

    _isProductMutating = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      await _repository.createProduct(
        storeId: storeId,
        name: name,
        price: price,
        description: description,
        category: category,
        imageUrl: imageUrl,
        isAvailable: isAvailable,
      );
      return true;
    } catch (e) {
      if (!_isDisposed) {
        _errorMessage = e.toString();
        _safeNotifyListeners();
      }
      return false;
    } finally {
      _isProductMutating = false;
      _safeNotifyListeners();
    }
  }

  /// تعديل منتج
  Future<bool> updateProduct({
    required String productId,
    required String name,
    required double price,
    String description = '',
    String category = 'عام',
    String imageUrl = '',
    bool isAvailable = true,
  }) async {
    if (productId.trim().isEmpty || _isDisposed) return false;
    if (_lockedProductIds.contains(productId) || _isProductMutating) return false;
    if (name.trim().isEmpty) return false;

    _lockedProductIds.add(productId);
    _isProductMutating = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      await _repository.updateProduct(
        storeId: storeId,
        productId: productId,
        name: name,
        price: price,
        description: description,
        category: category,
        imageUrl: imageUrl,
        isAvailable: isAvailable,
      );
      return true;
    } catch (e) {
      if (!_isDisposed) {
        _errorMessage = e.toString();
        _safeNotifyListeners();
      }
      return false;
    } finally {
      _lockedProductIds.remove(productId);
      _isProductMutating = false;
      _safeNotifyListeners();
    }
  }

  /// حذف منتج
  Future<bool> deleteProduct(String productId) async {
    if (productId.trim().isEmpty || _isDisposed) return false;
    if (_lockedProductIds.contains(productId) || _isProductMutating) return false;

    _lockedProductIds.add(productId);
    _isProductMutating = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      await _repository.deleteProduct(storeId: storeId, productId: productId);
      return true;
    } catch (e) {
      if (!_isDisposed) {
        _errorMessage = e.toString();
        _safeNotifyListeners();
      }
      return false;
    } finally {
      _lockedProductIds.remove(productId);
      _isProductMutating = false;
      _safeNotifyListeners();
    }
  }

  /// إضافة تصنيف
  Future<bool> createCategory({
    required String name,
    int iconCode = 0xe148,
    int colorValue = 0xFFF5F5F5,
  }) async {
    if (_isDisposed || _isCategoryMutating) return false;
    if (name.trim().isEmpty) return false;

    _isCategoryMutating = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      await _repository.createCategory(
        storeId: storeId,
        name: name,
        iconCode: iconCode,
        colorValue: colorValue,
      );
      return true;
    } catch (e) {
      if (!_isDisposed) {
        _errorMessage = e.toString();
        _safeNotifyListeners();
      }
      return false;
    } finally {
      _isCategoryMutating = false;
      _safeNotifyListeners();
    }
  }

  /// حذف تصنيف
  Future<bool> deleteCategory(String categoryId) async {
    if (categoryId.trim().isEmpty || _isDisposed) return false;
    if (_lockedCategoryIds.contains(categoryId) || _isCategoryMutating) return false;

    _lockedCategoryIds.add(categoryId);
    _isCategoryMutating = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      await _repository.deleteCategory(storeId: storeId, categoryId: categoryId);
      return true;
    } catch (e) {
      if (!_isDisposed) {
        _errorMessage = e.toString();
        _safeNotifyListeners();
      }
      return false;
    } finally {
      _lockedCategoryIds.remove(categoryId);
      _isCategoryMutating = false;
      _safeNotifyListeners();
    }
  }

  /// إضافة إعلان ترويجي
  Future<bool> createBanner({
    required String title,
    String subtitle = '',
    required String imageUrl,
  }) async {
    if (_isDisposed || _isBannerMutating) return false;
    if (title.trim().isEmpty || imageUrl.trim().isEmpty) return false;

    _isBannerMutating = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      await _repository.createBanner(
        storeId: storeId,
        title: title,
        subtitle: subtitle,
        imageUrl: imageUrl,
      );
      return true;
    } catch (e) {
      if (!_isDisposed) {
        _errorMessage = e.toString();
        _safeNotifyListeners();
      }
      return false;
    } finally {
      _isBannerMutating = false;
      _safeNotifyListeners();
    }
  }

  /// حذف إعلان ترويجي
  Future<bool> deleteBanner(String bannerId) async {
    if (bannerId.trim().isEmpty || _isDisposed) return false;
    if (_lockedBannerIds.contains(bannerId) || _isBannerMutating) return false;

    _lockedBannerIds.add(bannerId);
    _isBannerMutating = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      await _repository.deleteBanner(storeId: storeId, bannerId: bannerId);
      return true;
    } catch (e) {
      if (!_isDisposed) {
        _errorMessage = e.toString();
        _safeNotifyListeners();
      }
      return false;
    } finally {
      _lockedBannerIds.remove(bannerId);
      _isBannerMutating = false;
      _safeNotifyListeners();
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 7. الملف التعريفي ونقل الملكية والترحيل (Profile & Ownership) ───────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// تحديث الملف التعريفي للمتجر
  Future<bool> updateStoreProfile({
    required String name,
    String? logoUrl,
    String? coverUrl,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    if (_isDisposed || _isStoreProfileMutating) return false;
    if (name.trim().isEmpty) return false;

    _isStoreProfileMutating = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      await _repository.updateStoreProfile(
        storeId: storeId,
        name: name,
        logoUrl: logoUrl,
        coverUrl: coverUrl,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
      return true;
    } catch (e) {
      if (!_isDisposed) {
        _errorMessage = e.toString();
        _safeNotifyListeners();
      }
      return false;
    } finally {
      _isStoreProfileMutating = false;
      _safeNotifyListeners();
    }
  }

  /// نقل ملكية المتجر لمستخدم آخر (P0 Security Operation)
  Future<bool> transferStoreOwnership(String targetEmail) async {
    if (_isDisposed || _isOwnershipTransferring) return false;
    if (targetEmail.trim().isEmpty || !targetEmail.contains('@')) return false;

    _isOwnershipTransferring = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      final success = await _repository.transferStoreOwnership(
        storeId: storeId,
        targetEmail: targetEmail.trim(),
      );
      if (!success && !_isDisposed) {
        _errorMessage = 'لم يتم العثور على مستخدم بهذا البريد الإلكتروني';
      }
      return success;
    } catch (e) {
      if (!_isDisposed) {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      _isOwnershipTransferring = false;
      _safeNotifyListeners();
    }
  }

  /// ترحيل وتحديث البيانات القديمة
  Future<void> migrateOldData() async {
    if (_isDisposed || _isMigrating) return;
    _isMigrating = true;
    _safeNotifyListeners();

    try {
      await _repository.migrateOldData(storeId);
    } finally {
      _isMigrating = false;
      _safeNotifyListeners();
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 8. إدارة دورة الحياة والإنهاء الآمن (Lifecycle & Cleanup) ───────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _cancelSubscriptions() {
    _storeSub?.cancel();
    _pendingOrdersSub?.cancel();
    _allOrdersSub?.cancel();
    _ordersListSub?.cancel();
    _productsSub?.cancel();
    _categoriesSub?.cancel();
    _bannersSub?.cancel();

    _storeSub = null;
    _pendingOrdersSub = null;
    _allOrdersSub = null;
    _ordersListSub = null;
    _productsSub = null;
    _categoriesSub = null;
    _bannersSub = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _generation++;
    _cancelSubscriptions();
    _lockedOrderIds.clear();
    _lockedProductIds.clear();
    _lockedCategoryIds.clear();
    _lockedBannerIds.clear();
    super.dispose();
  }
}
