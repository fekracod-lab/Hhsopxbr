import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/repositories/restaurant_repository.dart';
import '../domain/entities/restaurant_models.dart';
import '../domain/services/restaurant_calculator.dart';

/// حالات تحكم صفحة المطاعم
enum RestaurantControllerStatus {
  initial,
  loading,
  ready,
  refreshing,
  error,
}

/// متحكم صفحة المطاعم وتجربة العميل (Restaurant Presentation Controller)
class RestaurantController extends ChangeNotifier {
  final RestaurantRepository _repository;

  RestaurantController({
    required RestaurantRepository repository,
  }) : _repository = repository;

  // ─── الحالة الداخلية (Private State) ───────────────────────────────────────────
  RestaurantControllerStatus _status = RestaurantControllerStatus.initial;
  List<RestaurantEntity> _restaurants = [];
  String _selectedCategory = 'الكل';
  bool _onlyOpen = false;
  bool _onlyFreeDelivery = false;
  bool _sortByRating = false;
  bool _sortByDeliveryTime = false;
  final Set<String> _favoriteIds = {};

  CartSummaryEntity _cartSummary = CartSummaryEntity.empty();
  ActiveOrderEntity? _activeOrder;
  ActiveOrderEntity? _lastOrder;
  String? _errorMessage;

  bool _isDisposed = false;
  bool _isInitialized = false;
  String? _currentUid;
  String _currentUserName = '';
  String? _currentEffectiveCartId;
  Future<List<Map<String, dynamic>>>? _popularMealsFuture;

  // ─── إدارة التزامن والاشتراكات (Subscriptions & Concurrency) ───────────────────
  int _loadGeneration = 0;
  StreamSubscription<List<CartItemEntity>>? _cartSubscription;
  StreamSubscription<List<ActiveOrderEntity>>? _activeOrdersSubscription;

  // ─── الحقول العامة المقروءة فقط (Public Read-Only Getters) ──────────────────────
  RestaurantControllerStatus get status => _status;
  bool get isLoading => _status == RestaurantControllerStatus.loading;
  bool get isLoadingRestaurants => isLoading;
  bool get isRefreshing => _status == RestaurantControllerStatus.refreshing;
  bool get isReady => _status == RestaurantControllerStatus.ready;
  bool get hasError => _status == RestaurantControllerStatus.error;
  String? get errorMessage => _errorMessage;

  List<RestaurantEntity> get restaurants => List.unmodifiable(_restaurants);
  String get selectedCategory => _selectedCategory;
  bool get onlyOpen => _onlyOpen;
  bool get onlyFreeDelivery => _onlyFreeDelivery;
  bool get sortByRating => _sortByRating;
  bool get sortByDeliveryTime => _sortByDeliveryTime;
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

  CartSummaryEntity get cartSummary => _cartSummary;
  ActiveOrderEntity? get activeOrder => _activeOrder;
  ActiveOrderEntity? get lastOrder => _lastOrder;
  String get currentUserName => _currentUserName;
  bool get isDisposed => _isDisposed;
  bool get isInitialized => _isInitialized;
  Future<List<Map<String, dynamic>>> get popularMealsFuture =>
      _popularMealsFuture ??= _repository.getPopularMealsRaw();

  /// قائمة المطاعم المفلترة والمرتبة عبر محرك الحسابات المجرد (RestaurantCalculator)
  List<RestaurantEntity> get filteredRestaurants {
    return RestaurantCalculator.filterAndSortRestaurants(
      restaurants: _restaurants,
      selectedCategory: _selectedCategory,
      onlyOpen: _onlyOpen,
      onlyFreeDelivery: _onlyFreeDelivery,
      sortByRating: _sortByRating,
      sortByDeliveryTime: _sortByDeliveryTime,
    );
  }

  // ─── التهيئة والتحميل (Initialization & Data Loading) ──────────────────────────

  /// تهيئة المتحكم وربط تيارات البيانات الحية
  Future<void> initialize({
    required String uid,
    String? effectiveCartId,
  }) async {
    if (_isDisposed) return;
    _currentUid = uid;
    _currentEffectiveCartId = effectiveCartId ?? uid;

    _status = RestaurantControllerStatus.loading;
    _errorMessage = null;
    _safeNotifyListeners();

    await loadRestaurants();
    _subscribeToCart(_currentEffectiveCartId!);
    _subscribeToActiveOrders(uid);
    await fetchLatestOrder(uid);

    _isInitialized = true;
  }

  /// جلب قائمة المطاعم مع حماية من تداخل الطلبات غير المتزامنة (Async Race Guard)
  Future<void> loadRestaurants() async {
    if (_isDisposed) return;
    final generation = ++_loadGeneration;

    try {
      final fetched = await _repository.getRestaurants();
      if (_isDisposed || generation != _loadGeneration) return;

      _restaurants = fetched;
      _status = RestaurantControllerStatus.ready;
      _errorMessage = null;
      _safeNotifyListeners();
    } catch (e) {
      if (_isDisposed || generation != _loadGeneration) return;
      _status = RestaurantControllerStatus.error;
      _errorMessage = e.toString();
      _safeNotifyListeners();
    }
  }

  /// تحديث البيانات بسلاسة دون إلغاء التيارات المستقرة (Pull-to-refresh)
  Future<void> refresh() async {
    if (_isDisposed) return;
    _status = RestaurantControllerStatus.refreshing;
    _safeNotifyListeners();

    await loadRestaurants();

    if (_currentUid != null && !_isDisposed) {
      await fetchLatestOrder(_currentUid!);
    }
  }

  /// جلب آخر طلب مسجل للعميل
  Future<void> fetchLatestOrder(String uid) async {
    if (_isDisposed) return;
    try {
      final order = await _repository.getLatestOrder(uid);
      if (_isDisposed) return;
      _lastOrder = order;
      _safeNotifyListeners();
    } catch (_) {
      // Ignored defensively as missing last order is non-fatal
    }
  }

  // ─── إدارة الفلاتر والتصنيفات (Filters & Sorting) ──────────────────────────────

  void setSelectedCategory(String category) {
    if (_selectedCategory == category || _isDisposed) return;
    _selectedCategory = category;
    _safeNotifyListeners();
  }

  void setOnlyOpen(bool value) {
    if (_onlyOpen == value || _isDisposed) return;
    _onlyOpen = value;
    _safeNotifyListeners();
  }

  void setOnlyFreeDelivery(bool value) {
    if (_onlyFreeDelivery == value || _isDisposed) return;
    _onlyFreeDelivery = value;
    _safeNotifyListeners();
  }

  void setSortByRating(bool value) {
    if (_sortByRating == value || _isDisposed) return;
    _sortByRating = value;
    if (value) _sortByDeliveryTime = false;
    _safeNotifyListeners();
  }

  void setSortByDeliveryTime(bool value) {
    if (_sortByDeliveryTime == value || _isDisposed) return;
    _sortByDeliveryTime = value;
    if (value) _sortByRating = false;
    _safeNotifyListeners();
  }

  void toggleOnlyOpen() => setOnlyOpen(!_onlyOpen);
  void toggleOnlyFreeDelivery() => setOnlyFreeDelivery(!_onlyFreeDelivery);
  void toggleSortByRating() => setSortByRating(!_sortByRating);
  void toggleSortByDeliveryTime() => setSortByDeliveryTime(!_sortByDeliveryTime);

  Future<void> refreshRestaurants() => refresh();

  void setCurrentUserName(String name) {
    if (_currentUserName == name || _isDisposed) return;
    _currentUserName = name;
    _safeNotifyListeners();
  }

  void resetFilters() {
    if (_isDisposed) return;
    _selectedCategory = 'الكل';
    _onlyOpen = false;
    _onlyFreeDelivery = false;
    _sortByRating = false;
    _sortByDeliveryTime = false;
    _safeNotifyListeners();
  }

  // ─── إدارة المفضلة (Favorites Management) ─────────────────────────────────────

  bool isFavorite(String restaurantId) {
    return _favoriteIds.contains(restaurantId);
  }

  void toggleFavorite(String restaurantId) {
    if (restaurantId.trim().isEmpty || _isDisposed) return;
    if (_favoriteIds.contains(restaurantId)) {
      _favoriteIds.remove(restaurantId);
    } else {
      _favoriteIds.add(restaurantId);
    }
    _safeNotifyListeners();
  }

  void setFavorites(Iterable<String> ids) {
    if (_isDisposed) return;
    _favoriteIds.clear();
    _favoriteIds.addAll(ids);
    _safeNotifyListeners();
  }

  // ─── إدارة تيارات السلة والطلبات (Live Stream Subscriptions) ───────────────────

  /// تحديث معرّف السلة الفعّال وإعادة الاشتراك عند تغييره (مثل الانضمام لسلة جماعية)
  void updateEffectiveCartId(String effectiveCartId) {
    if (effectiveCartId.trim().isEmpty || _isDisposed) return;
    if (_currentEffectiveCartId == effectiveCartId) return;
    _currentEffectiveCartId = effectiveCartId;
    _subscribeToCart(effectiveCartId);
  }

  void _subscribeToCart(String cartId) {
    _cartSubscription?.cancel();
    _cartSubscription = _repository.watchCartItems(cartId).listen(
      (items) {
        if (_isDisposed) return;
        _cartSummary = RestaurantCalculator.computeCartSummary(items);
        _safeNotifyListeners();
      },
      onError: (_) {
        if (_isDisposed) return;
        _cartSummary = CartSummaryEntity.empty();
        _safeNotifyListeners();
      },
    );
  }

  void _subscribeToActiveOrders(String uid) {
    _activeOrdersSubscription?.cancel();
    _activeOrdersSubscription = _repository.watchActiveOrders(uid).listen(
      (orders) {
        if (_isDisposed) return;
        ActiveOrderEntity? foundActive;
        for (final order in orders) {
          if (RestaurantCalculator.isActiveOrderStatus(order.status)) {
            foundActive = order;
            break;
          }
        }
        _activeOrder = foundActive;
        _safeNotifyListeners();
      },
      onError: (_) {
        if (_isDisposed) return;
        _activeOrder = null;
        _safeNotifyListeners();
      },
    );
  }

  // ─── دورة الحياة والتخلص (Lifecycle & Disposal) ────────────────────────────────

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _loadGeneration++;
    _cartSubscription?.cancel();
    _activeOrdersSubscription?.cancel();
    _cartSubscription = null;
    _activeOrdersSubscription = null;
    super.dispose();
  }
}
