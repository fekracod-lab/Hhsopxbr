import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/entities/store_cart_item_entity.dart';
import '../domain/entities/store_checkout_models.dart';
import '../domain/entities/store_dashboard_models.dart';
import '../domain/services/store_details_calculator.dart';
import '../data/repositories/store_details_repository.dart';

/// متحكم شاشة تفاصيل وسلة المتجر وإتمام الطلب (Store Details & Cart Controller)
/// المسؤول عن إدارة الحالة وتنسيق التدفقات وتأمين عمليات الشراء ومعاملات المحفظة والنقاط
/// خالي تماماً من أي اعتماديات على Firebase أو UI مباشرة
class StoreDetailsController extends ChangeNotifier {
  final String storeId;
  final Map<String, dynamic> initialStoreData;
  final StoreDetailsRepository _repository;

  StoreDetailsController({
    required this.storeId,
    required this.initialStoreData,
    StoreDetailsRepository? repository,
  }) : _repository = repository ?? StoreDetailsRepository();

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 1. الحالة والبيانات الداخلية (State & Subscriptions) ───────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  StoreDashboardEntity? _store;
  List<StoreProductEntity> _products = [];
  List<StoreCategoryEntity> _categories = [];
  List<StoreBannerEntity> _banners = [];
  final List<StoreCartItemEntity> _cartItems = [];

  String _selectedCategory = 'الكل';
  String _searchQuery = '';

  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDisposed = false;
  int _generation = 0;

  // أقفال التزامن لمنع تكرار الطلب (Double-Checkout Mutex)
  bool _isCheckoutProcessing = false;
  bool _isActionMutating = false;
  bool _isUploadingImage = false;
  bool _isFetchingLocation = false;

  // إعدادات الدفع والنقاط
  StorePaymentMethod _selectedPaymentMethod = StorePaymentMethod.cash;
  bool _usePoints = false;
  int _requestedPoints = 0;
  Map<String, dynamic>? _userProfile;

  // اشتراكات التدفقات
  StreamSubscription<List<StoreProductEntity>>? _productsSub;
  StreamSubscription<List<StoreCategoryEntity>>? _categoriesSub;
  StreamSubscription<List<StoreBannerEntity>>? _bannersSub;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 2. القراءات والـ Getters ───────────────────────────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  StoreDashboardEntity? get store => _store;
  List<StoreProductEntity> get products => List.unmodifiable(_products);
  List<StoreCategoryEntity> get categories => List.unmodifiable(_categories);
  List<StoreBannerEntity> get banners => List.unmodifiable(_banners);
  List<StoreCartItemEntity> get cartItems => List.unmodifiable(_cartItems);

  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isDisposed => _isDisposed;

  bool get isCheckoutProcessing => _isCheckoutProcessing;
  bool get isActionMutating => _isActionMutating;
  bool get isUploadingImage => _isUploadingImage;
  bool get isFetchingLocation => _isFetchingLocation;

  String get storeName =>
      _store?.name ?? (initialStoreData['name'] ?? 'المتجر').toString();
  String get storePhone =>
      _store?.rawData['phone']?.toString() ??
      (initialStoreData['phone'] ?? '').toString();
  String get ownerId =>
      _store?.ownerId ?? (initialStoreData['ownerId'] ?? '').toString();

  bool get hasAdminAccess =>
      _userProfile?['role'] == 'admin' ||
      _userProfile?['role'] == 'main_admin' ||
      _userProfile?['role'] == 'limited_admin' ||
      (_userProfile?['uid'] != null && _userProfile!['uid'] == ownerId);

  int get cartCount => cartItemCount;

  String get userName =>
      _userProfile?['fullName']?.toString() ??
      (_userProfile?['name']?.toString() ?? '');
  String get userPhone => _userProfile?['phone']?.toString() ?? '';
  String get userAddress => _userProfile?['address']?.toString() ?? '';

  StorePaymentMethod get selectedPaymentMethod => _selectedPaymentMethod;
  bool get usePoints => _usePoints;
  int get requestedPoints => _requestedPoints;
  Map<String, dynamic>? get userProfile => _userProfile;

  double get userBalance =>
      (userProfile?['balance'] as num? ?? 0.0).toDouble();
  int get userPoints => (userProfile?['points'] as num? ?? 0).toInt();

  /// إجمالي عدد القطع في السلة
  int get cartItemCount =>
      _cartItems.fold(0, (sum, it) => sum + it.quantity);

  /// الإجمالي الفرعي لسعر السلة
  double get cartSubtotal =>
      StoreDetailsCalculator.calculateCartSubtotal(_cartItems);

  /// رسوم التوصيل
  double get deliveryFee => StoreDetailsCalculator.calculateDeliveryFee(
        storeDeliveryFee: (initialStoreData['deliveryFee'] as num?)?.toDouble(),
      );

  /// قائمة المنتجات المفلترة حسب القسم والبحث
  List<StoreProductEntity> get filteredProducts {
    var list = _products;
    if (_selectedCategory != 'الكل' && _selectedCategory.trim().isNotEmpty) {
      list = list.where((p) => p.category == _selectedCategory).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(query) ||
              p.description.toLowerCase().contains(query))
          .toList();
    }
    return List.unmodifiable(list);
  }

  /// ملخص الحسابات المالية لإتمام الطلب
  StoreCheckoutSummaryEntity get checkoutSummary {
    return StoreDetailsCalculator.buildCheckoutSummary(
      items: _cartItems,
      storeDeliveryFee: (initialStoreData['deliveryFee'] as num?)?.toDouble(),
      availablePoints: userPoints,
      requestedPoints: _requestedPoints,
      usePoints: _usePoints,
      paymentMethod: _selectedPaymentMethod,
      userBalance: userBalance,
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 3. التهيئة وتدفقات البيانات (Initialization & Streams) ─────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// تهيئة المتحكم وبدء الاستماع لكافة التدفقات
  Future<void> initialize({String? userId}) async {
    if (_isInitialized || _isDisposed) return;
    _isInitialized = true;
    _isLoading = true;
    _errorMessage = null;
    final currentGen = ++_generation;
    _safeNotifyListeners();

    try {
      // 1. جلب بيانات المتجر والمستخدم
      final storeFuture = _repository.getStore(storeId);
      final userFuture = userId != null && userId.isNotEmpty
          ? _repository.getUserProfile(userId)
          : Future<Map<String, dynamic>?>.value(null);

      final results = await Future.wait([storeFuture, userFuture]);
      if (_generation != currentGen || _isDisposed) return;

      _store = results[0] as StoreDashboardEntity?;
      _userProfile = results[1] as Map<String, dynamic>?;

      // 2. مراقبة المنتجات
      _productsSub = _repository.watchProducts(storeId).listen(
        (prods) {
          if (_generation != currentGen || _isDisposed) return;
          _products = prods;
          _safeNotifyListeners();
        },
        onError: (err) => _handleStreamError(err, currentGen),
      );

      // 3. مراقبة الأقسام
      _categoriesSub = _repository.watchCategories(storeId).listen(
        (cats) {
          if (_generation != currentGen || _isDisposed) return;
          _categories = cats;
          _safeNotifyListeners();
        },
        onError: (err) => _handleStreamError(err, currentGen),
      );

      // 4. مراقبة الإعلانات
      _bannersSub = _repository.watchBanners(storeId).listen(
        (bans) {
          if (_generation != currentGen || _isDisposed) return;
          _banners = bans;
          _safeNotifyListeners();
        },
        onError: (err) => _handleStreamError(err, currentGen),
      );

      _isLoading = false;
      _safeNotifyListeners();
    } catch (e) {
      if (_generation == currentGen && !_isDisposed) {
        _isLoading = false;
        _errorMessage = 'فشل في تحميل بيانات المتجر';
        _safeNotifyListeners();
      }
    }
  }

  void _handleStreamError(dynamic err, int gen) {
    if (_generation == gen && !_isDisposed) {
      _errorMessage = 'خطأ في تحديث البيانات المباشرة';
      _safeNotifyListeners();
    }
  }

  /// تحديث ملف المستخدم
  Future<void> refreshUserProfile(String userId) async {
    if (userId.trim().isEmpty || _isDisposed) return;
    try {
      final data = await _repository.getUserProfile(userId);
      if (!_isDisposed && data != null) {
        _userProfile = data;
        _safeNotifyListeners();
      }
    } catch (_) {}
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 4. عمليات السلة وتصفية المنتجات (Cart & Filters) ────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void setSelectedCategory(String category) {
    if (_selectedCategory == category || _isDisposed) return;
    _selectedCategory = category;
    _safeNotifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query || _isDisposed) return;
    _searchQuery = query;
    _safeNotifyListeners();
  }

  /// إضافة منتج إلى السلة أو زيادة كميته
  void addToCart(StoreCartItemEntity item) {
    if (_isDisposed) return;
    final index = _cartItems.indexWhere((it) => it.productId == item.productId);
    if (index >= 0) {
      final current = _cartItems[index];
      _cartItems[index] = current.copyWith(quantity: current.quantity + item.quantity);
    } else {
      _cartItems.add(item);
    }
    _safeNotifyListeners();
  }

  /// حذف منتج من السلة نهائياً
  void removeFromCart(String productId) {
    if (_isDisposed) return;
    _cartItems.removeWhere((it) => it.productId == productId);
    _safeNotifyListeners();
  }

  /// زيادة كمية منتج في السلة بمقدار 1
  void incrementCartItem(String productId) {
    if (_isDisposed) return;
    final index = _cartItems.indexWhere((it) => it.productId == productId);
    if (index >= 0) {
      final current = _cartItems[index];
      _cartItems[index] = current.copyWith(quantity: current.quantity + 1);
      _safeNotifyListeners();
    }
  }

  /// تقليل كمية منتج في السلة بمقدار 1 أو حذفه إذا أصبحت الكمية 0
  void decrementCartItem(String productId) {
    if (_isDisposed) return;
    final index = _cartItems.indexWhere((it) => it.productId == productId);
    if (index >= 0) {
      final current = _cartItems[index];
      if (current.quantity > 1) {
        _cartItems[index] = current.copyWith(quantity: current.quantity - 1);
      } else {
        _cartItems.removeAt(index);
      }
      _safeNotifyListeners();
    }
  }

  /// تفريغ السلة بالكامل
  void clearCart() {
    if (_isDisposed) return;
    _cartItems.clear();
    _safeNotifyListeners();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 5. إعدادات الدفع والنقاط (Payment & Points Configuration) ───────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void setPaymentMethod(StorePaymentMethod method) {
    if (_selectedPaymentMethod == method || _isDisposed) return;
    _selectedPaymentMethod = method;
    _safeNotifyListeners();
  }

  void setUsePoints(bool value) {
    if (_usePoints == value || _isDisposed) return;
    _usePoints = value;
    if (!value) {
      _requestedPoints = 0;
    } else {
      _requestedPoints = StoreDetailsCalculator.calculateMaxUsablePoints(
        availablePoints: userPoints,
        maxEligibleAmount: cartSubtotal,
      );
    }
    _safeNotifyListeners();
  }

  void setRequestedPoints(int points) {
    if (_requestedPoints == points || _isDisposed) return;
    final maxPts = StoreDetailsCalculator.calculateMaxUsablePoints(
      availablePoints: userPoints,
      maxEligibleAmount: cartSubtotal,
    );
    _requestedPoints = points.clamp(0, maxPts);
    _safeNotifyListeners();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 6. تنفيذ إتمام الطلب ذرياً (Atomic Checkout Flow) ──────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// إتمام الطلب ذرياً مع الحماية ضد الضغط المتكرر (Mutex Locked)
  Future<StoreCheckoutValidationResult> checkout({
    required String userId,
    required String customerName,
    required String customerPhone,
    required String address,
    required String notes,
    double? latitude,
    double? longitude,
  }) async {
    if (_isCheckoutProcessing || _isDisposed) {
      return StoreCheckoutValidationResult.invalid(
        message: 'عملية الشراء قيد المعالجة، انتظر شوية...',
        code: 'CHECKOUT_ALREADY_IN_PROGRESS',
      );
    }

    final summary = checkoutSummary;

    // 1. التحقق المسبق عبر حاسبة النطاق
    final validation = StoreDetailsCalculator.validateCheckout(
      items: _cartItems,
      customerName: customerName,
      customerPhone: customerPhone,
      address: address,
      paymentMethod: _selectedPaymentMethod,
      userBalance: userBalance,
      finalTotal: summary.finalTotal,
    );

    if (!validation.isValid) {
      return validation;
    }

    _isCheckoutProcessing = true;
    _safeNotifyListeners();

    try {
      final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      final success = await _repository.placeOrderAtomic(
        storeId: storeId,
        userId: userId,
        orderId: orderId,
        customerName: customerName.trim(),
        customerPhone: customerPhone.trim(),
        address: address.trim(),
        notes: notes.trim(),
        latitude: latitude,
        longitude: longitude,
        storeData: initialStoreData,
        items: _cartItems,
        summary: summary,
      );

      if (success && !_isDisposed) {
        _cartItems.clear();
        _usePoints = false;
        _requestedPoints = 0;
        _isCheckoutProcessing = false;
        _safeNotifyListeners();
        return StoreCheckoutValidationResult.valid;
      } else {
        _isCheckoutProcessing = false;
        _safeNotifyListeners();
        return StoreCheckoutValidationResult.invalid(
          message: 'ما قدرنا نرسل الطلب، حاول مرة ثانية بعد شوية',
          code: 'CHECKOUT_FAILED',
        );
      }
    } catch (e) {
      _isCheckoutProcessing = false;
      _safeNotifyListeners();
      return StoreCheckoutValidationResult.invalid(
        message: 'حدث خطأ أثناء إتمام الطلب: ${e.toString()}',
        code: 'CHECKOUT_EXCEPTION',
      );
    }
  }

  /// إتمام الطلب من واجهة المستخدم مع تحويل النتيجة لـ record مبسط
  Future<({bool success, String? orderId, String? errorMessage})> placeOrder({
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String notes,
    required bool usePoints,
    required bool useWallet,
  }) async {
    final userId = _userProfile?['uid']?.toString() ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';
    final generatedOrderId = 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    setUsePoints(usePoints);
    setPaymentMethod(useWallet ? StorePaymentMethod.wallet : StorePaymentMethod.cash);

    final result = await checkout(
      userId: userId,
      customerName: customerName,
      customerPhone: customerPhone,
      address: customerAddress,
      notes: notes,
    );

    if (result.isValid) {
      return (success: true, orderId: generatedOrderId, errorMessage: null);
    } else {
      return (success: false, orderId: null, errorMessage: result.errorMessage);
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 7. عمليات الأدمن والخدمات الخارجية ─────────────────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> init({String? userId}) => initialize(userId: userId);

  Future<void> refresh() {
    _isInitialized = false;
    return initialize();
  }

  Future<void> createProduct(Map<String, dynamic> productData) async {
    if (_isActionMutating || _isDisposed) return;
    _isActionMutating = true;
    _safeNotifyListeners();
    try {
      await _repository.createProduct(storeId: storeId, productData: productData);
    } finally {
      _isActionMutating = false;
      _safeNotifyListeners();
    }
  }

  Future<void> createProductDirect({
    required String name,
    required double price,
    required String category,
    String imageUrl = '',
  }) async {
    await createProduct({
      'name': name,
      'price': price,
      'category': category,
      'imageUrl': imageUrl,
      'description': '',
      'isAvailable': true,
    });
  }

  Future<void> updateProduct({
    required String productId,
    required String name,
    required double price,
    required String category,
    String imageUrl = '',
  }) async {
    if (_isActionMutating || _isDisposed) return;
    _isActionMutating = true;
    _safeNotifyListeners();
    try {
      await _repository.updateProduct(
        storeId: storeId,
        productId: productId,
        productData: {
          'name': name,
          'price': price,
          'category': category,
          'imageUrl': imageUrl,
        },
      );
    } finally {
      _isActionMutating = false;
      _safeNotifyListeners();
    }
  }

  Future<void> deleteProduct(String productId) async {
    if (_isActionMutating || _isDisposed) return;
    _isActionMutating = true;
    _safeNotifyListeners();
    try {
      await _repository.deleteProduct(storeId: storeId, productId: productId);
    } finally {
      _isActionMutating = false;
      _safeNotifyListeners();
    }
  }

  Future<void> createCategory(String name, {int iconCode = 0xe148, int colorValue = 0xFFF5F5F5}) async {
    if (_isActionMutating || _isDisposed) return;
    _isActionMutating = true;
    _safeNotifyListeners();
    try {
      await _repository.createCategory(storeId: storeId, name: name, iconCode: iconCode, colorValue: colorValue);
    } finally {
      _isActionMutating = false;
      _safeNotifyListeners();
    }
  }

  Future<void> updateCategory({
    required String categoryId,
    required String name,
    int iconCode = 0xe148,
    int colorValue = 0xFFF5F5F5,
  }) async {
    if (_isActionMutating || _isDisposed) return;
    _isActionMutating = true;
    _safeNotifyListeners();
    try {
      await _repository.updateCategory(
        storeId: storeId,
        categoryId: categoryId,
        categoryData: {
          'name': name,
          'iconCode': iconCode,
          'colorValue': colorValue,
        },
      );
    } finally {
      _isActionMutating = false;
      _safeNotifyListeners();
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    if (_isActionMutating || _isDisposed) return;
    _isActionMutating = true;
    _safeNotifyListeners();
    try {
      await _repository.deleteCategory(storeId: storeId, categoryId: categoryId);
    } finally {
      _isActionMutating = false;
      _safeNotifyListeners();
    }
  }

  Future<void> addBanner(String imageUrl) async {
    if (_isActionMutating || _isDisposed) return;
    _isActionMutating = true;
    _safeNotifyListeners();
    try {
      await _repository.addBanner(storeId: storeId, imageUrl: imageUrl);
    } finally {
      _isActionMutating = false;
      _safeNotifyListeners();
    }
  }

  Future<void> deleteBanner(String bannerId) async {
    if (_isActionMutating || _isDisposed) return;
    _isActionMutating = true;
    _safeNotifyListeners();
    try {
      await _repository.deleteBanner(storeId: storeId, bannerId: bannerId);
    } finally {
      _isActionMutating = false;
      _safeNotifyListeners();
    }
  }

  Future<void> migrateOldCategories() async {
    if (_isDisposed) return;
    await _repository.migrateOldCategories(storeId);
  }

  Future<String?> uploadImage(String filePath) async {
    if (_isUploadingImage || _isDisposed) return null;
    _isUploadingImage = true;
    _safeNotifyListeners();
    try {
      return await _repository.uploadImageToCloudinary(filePath: filePath);
    } finally {
      _isUploadingImage = false;
      _safeNotifyListeners();
    }
  }

  Future<Map<String, dynamic>?> fetchCurrentLocationAndAddress() async {
    if (_isFetchingLocation || _isDisposed) return null;
    _isFetchingLocation = true;
    _safeNotifyListeners();
    try {
      return await _repository.getCurrentLocationAndAddress();
    } finally {
      _isFetchingLocation = false;
      _safeNotifyListeners();
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 8. الإغلاق والتنظيف (Disposal & Cleanup) ───────────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _generation++;
    _productsSub?.cancel();
    _categoriesSub?.cancel();
    _bannersSub?.cancel();
    super.dispose();
  }
}
