import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/repositories/restaurant_repository.dart';
import '../domain/entities/restaurant_models.dart';
import '../domain/entities/restaurant_details_models.dart';
import '../domain/services/restaurant_details_calculator.dart';

/// متحكم صفحة تفاصيل المطعم والمنيو والسلة والتقييمات (Restaurant Details Controller)
class RestaurantDetailsController extends ChangeNotifier {
  final RestaurantRepository _repository;
  final String restaurantId;
  final String restaurantName;
  final String imageUrl;

  RestaurantDetailsController({
    required RestaurantRepository repository,
    required this.restaurantId,
    this.restaurantName = 'مطعم',
    this.imageUrl = '',
  }) : _repository = repository;

  // ─── الحالة الداخلية (Private State) ───────────────────────────────────────────
  bool _isDisposed = false;
  bool _isInitialized = false;
  int _generation = 0;
  String? _errorMessage;

  // تفاصيل المطعم والتصنيفات
  String _cuisine = 'مطبخ عربي • مشويات • مقبلات';
  String? _sectionId;
  String? _catalogItemId;
  List<MenuCategoryEntity> _categories = [];
  String _selectedCategory = 'الكل';
  bool _loadingCategories = true;
  String _sortBy = 'default';

  // المنيو وقائمة الوجبات
  List<MenuItemDetailsEntity> _menuItems = [];
  bool _loadingMenuItems = true;

  // سلة التسوق
  final Map<String, int> _cartItems = {};
  final Map<String, double> _cartPrices = {};
  int _totalCount = 0;
  double _totalPrice = 0.0;
  String? _currentEffectiveCartId;
  final Set<String> _lockedCartItemIds = {};

  // التقييمات والمراجعات
  List<RestaurantReviewEntity> _reviews = [];
  ReviewStatisticsEntity _reviewStatistics = ReviewStatisticsEntity.empty();
  bool _loadingReviews = true;
  bool _isSubmittingReview = false;
  final Set<String> _lockedReviewIds = {};

  // حالة تخصيص الوجبة الحالية (Meal Customization State)
  String _customizationItemId = '';
  String _customizationName = '';
  double _customizationBasePrice = 0.0;
  String? _customizationImageUrl;
  String _selectedSize = 'عادي (وسط)';
  double _selectedSizeExtra = 0.0;
  final Set<String> _selectedAddons = {};
  final Map<String, double> _availableAddonPrices = {
    'جبن إضافي': 1000.0,
    'صوص خاص (مدار)': 500.0,
    'مشروب غازي بارد': 750.0,
    'مقبلات إضافية': 1500.0,
  };
  int _customizationQuantity = 1;
  String _customizationNotes = '';

  // ─── الاشتراكات والتيارات (Stream Subscriptions) ────────────────────────────────
  StreamSubscription<List<MenuItemDetailsEntity>>? _menuSubscription;
  StreamSubscription<List<CartItemEntity>>? _cartSubscription;
  StreamSubscription<List<RestaurantReviewEntity>>? _reviewsSubscription;

  // ─── الحقول العامة المقروءة فقط (Public Read-Only Getters) ──────────────────────
  bool get isDisposed => _isDisposed;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;

  String get cuisine => _cuisine;
  String? get sectionId => _sectionId;
  String? get catalogItemId => _catalogItemId;
  List<MenuCategoryEntity> get categories => List.unmodifiable(_categories);
  String get selectedCategory => _selectedCategory;
  bool get loadingCategories => _loadingCategories;
  String get sortBy => _sortBy;

  List<MenuItemDetailsEntity> get menuItems => List.unmodifiable(_menuItems);
  bool get loadingMenuItems => _loadingMenuItems;

  Map<String, int> get cartItems => Map.unmodifiable(_cartItems);
  Map<String, double> get cartPrices => Map.unmodifiable(_cartPrices);
  int get totalCount => _totalCount;
  double get totalPrice => _totalPrice;
  String? get currentEffectiveCartId => _currentEffectiveCartId;

  List<RestaurantReviewEntity> get reviews => List.unmodifiable(_reviews);
  ReviewStatisticsEntity get reviewStatistics => _reviewStatistics;
  bool get loadingReviews => _loadingReviews;
  bool get isSubmittingReview => _isSubmittingReview;

  // Getters لتخصيص الوجبة
  String get customizationItemId => _customizationItemId;
  String get customizationName => _customizationName;
  double get customizationBasePrice => _customizationBasePrice;
  String? get customizationImageUrl => _customizationImageUrl;
  String get selectedSize => _selectedSize;
  double get selectedSizeExtra => _selectedSizeExtra;
  Set<String> get selectedAddons => Set.unmodifiable(_selectedAddons);
  int get customizationQuantity => _customizationQuantity;
  String get customizationNotes => _customizationNotes;

  /// سعر الوحدة بعد إضافة الحجم والإضافات المختارة
  double get customizationUnitPrice {
    final List<double> addonPrices = _selectedAddons
        .map((a) => _availableAddonPrices[a] ?? 0.0)
        .toList();
    return RestaurantDetailsCalculator.calculateItemPrice(
      basePrice: _customizationBasePrice,
      sizeExtra: _selectedSizeExtra,
      addonPrices: addonPrices,
    );
  }

  /// إجمالي سعر الوجبة حسب الكمية
  double get customizationTotalPrice {
    return RestaurantDetailsCalculator.calculateTotalPrice(
      unitPrice: customizationUnitPrice,
      quantity: _customizationQuantity,
    );
  }

  // ─── التهيئة والعمليات الأساسية (Initialization) ───────────────────────────────

  /// تهيئة المتحكم وربط كافة البيانات الخاصة بالمطعم والسلة
  Future<void> initialize({
    required String uid,
    String? effectiveCartId,
  }) async {
    if (_isDisposed) return;
    final generation = ++_generation;

    final cartId = effectiveCartId ?? GroupCartManager.getEffectiveCartId(uid);
    _currentEffectiveCartId = cartId;

    _subscribeToCart(cartId);
    _subscribeToReviews();

    await Future.wait([
      _fetchRestaurantDetails(generation),
      _fetchCategories(generation),
    ]);

    if (_isDisposed || generation != _generation) return;
    _isInitialized = true;
    _safeNotifyListeners();
  }

  /// تحديث معرّف السلة الفعّال عند تغير حالة السلة الجماعية
  void updateEffectiveCartId(String cartId) {
    if (_isDisposed || cartId.trim().isEmpty || _currentEffectiveCartId == cartId) return;
    _currentEffectiveCartId = cartId;
    _subscribeToCart(cartId);
    _safeNotifyListeners();
  }

  // ─── جلب التفاصيل والتصنيفات (Categories Discovery) ────────────────────────────

  Future<void> _fetchRestaurantDetails(int generation) async {
    try {
      final restaurant = await _repository.getRestaurantById(restaurantId);
      if (_isDisposed || generation != _generation) return;
      if (restaurant != null) {
        final raw = restaurant.rawData;
        _cuisine = raw['cuisine']?.toString() ?? 'مطبخ عربي • مشويات • مقبلات';
      }
    } catch (_) {}
  }

  Future<void> _fetchCategories(int generation) async {
    _loadingCategories = true;
    _safeNotifyListeners();

    try {
      final context = await _repository.getRestaurantMenuContext(restaurantId);
      if (_isDisposed || generation != _generation) return;

      if (context != null && context.categories.isNotEmpty) {
        _sectionId = context.sectionId;
        _catalogItemId = context.itemId;

        _categories = [
          const MenuCategoryEntity(name: 'الكل', iconCode: 0xe5c3),
          ...context.categories,
          const MenuCategoryEntity(name: 'التقييمات', iconCode: 0xe56c),
        ];
      } else {
        // لم يتوفر سياق sections — نكتشف التصنيفات ديناميكياً من الوجبات المخزنة
        _categories = await _discoverCategoriesFromDirectMenu();
      }

      _loadingCategories = false;
      _subscribeToMenu();
      _safeNotifyListeners();
    } catch (e) {
      if (_isDisposed || generation != _generation) return;
      _categories = await _discoverCategoriesFromDirectMenu();
      _loadingCategories = false;
      _errorMessage = e.toString();
      _subscribeToMenu();
      _safeNotifyListeners();
    }
  }

  /// اكتشاف التصنيفات ديناميكياً من وجبات المطعم المحفوظة في Firestore
  Future<List<MenuCategoryEntity>> _discoverCategoriesFromDirectMenu() async {
    final Set<String> foundCategories = {};

    try {
      // جلب عينة من الوجبات لاستخراج أسماء التصنيفات
      final items = await _repository.watchMenuItemsDirect(
        restaurantId: restaurantId,
      ).first;

      for (final item in items) {
        final cat = item.category;
        if (cat.isNotEmpty && cat != 'الكل') {
          foundCategories.add(cat);
        }
      }
    } catch (_) {}

    final List<MenuCategoryEntity> result = [
      const MenuCategoryEntity(name: 'الكل', iconCode: 0xe5c3),
    ];

    if (foundCategories.isNotEmpty) {
      // نبني التصنيفات من البيانات الحقيقية
      const categoryIcons = <String, int>{
        'برجر': 0xe544,
        'بيتزا': 0xe3fd,
        'شاورما': 0xf05e6,
        'مشاوي': 0xf05e6,
        'دجاج': 0xe540,
        'مقبلات': 0xe532,
        'مشروبات': 0xe3e6,
        'حلويات': 0xe110,
        'قهوة': 0xe3e2,
        'وجبات رئيسية': 0xe532,
        'وجبات سريعة': 0xe544,
        'سمك': 0xe532,
        'فطور': 0xe544,
      };

      for (final cat in foundCategories) {
        final lower = cat.toLowerCase();
        int iconCode = 0xe2aa; // default icon
        for (final entry in categoryIcons.entries) {
          if (lower.contains(entry.key)) {
            iconCode = entry.value;
            break;
          }
        }
        result.add(MenuCategoryEntity(name: cat, iconCode: iconCode));
      }
    } else {
      // لا توجد وجبات — تصنيفات افتراضية
      result.addAll(const [
        MenuCategoryEntity(name: 'مشويات وكباب', iconCode: 0xf05e6),
        MenuCategoryEntity(name: 'بيتزا ومعجنات', iconCode: 0xe3fd),
        MenuCategoryEntity(name: 'دجاج ومقرمشات', iconCode: 0xe540),
        MenuCategoryEntity(name: 'برغر وسندويشات', iconCode: 0xe544),
        MenuCategoryEntity(name: 'عصائر ومشروبات', iconCode: 0xe3e6),
        MenuCategoryEntity(name: 'حلويات وكافيهات', iconCode: 0xe110),
        MenuCategoryEntity(name: 'مأكولات شرقية', iconCode: 0xe532),
      ]);
    }

    result.add(const MenuCategoryEntity(name: 'التقييمات', iconCode: 0xe56c));
    return result;
  }

  /// تغيير التصنيف المختار وإعادة ربط تيار الوجبات
  void selectCategory(String category) {
    if (_isDisposed || _selectedCategory == category) return;
    _selectedCategory = category;
    _subscribeToMenu();
    _safeNotifyListeners();
  }

  /// تغيير طريقة الترتيب
  void setSortBy(String sortBy) {
    if (_isDisposed || _sortBy == sortBy) return;
    _sortBy = sortBy;
    _subscribeToMenu();
    _safeNotifyListeners();
  }

  // ─── إدارة تيار المنيو (Menu Items Streaming) ─────────────────────────────────

  void _subscribeToMenu() {
    _menuSubscription?.cancel();
    if (_selectedCategory == 'التقييمات') {
      _loadingMenuItems = false;
      return;
    }

    _loadingMenuItems = true;

    // إذا كان المطعم مسجل في النظام القديم (sections/items) — استخدم المسار القديم
    if (_sectionId != null && _sectionId!.isNotEmpty &&
        _catalogItemId != null && _catalogItemId!.isNotEmpty) {
      _menuSubscription = _repository
          .watchMenuItems(
            sectionId: _sectionId!,
            itemId: _catalogItemId!,
            category: _selectedCategory,
            sortBy: _sortBy,
          )
          .listen(
            (items) {
              if (_isDisposed) return;
              // إذا النتيجة فاضية، جرّب المسار المباشر كـ fallback
              if (items.isEmpty) {
                _subscribeToMenuDirect();
              } else {
                _menuItems = items;
                _loadingMenuItems = false;
                _safeNotifyListeners();
              }
            },
            onError: (e) {
              if (_isDisposed) return;
              // عند فشل المسار القديم، جرّب المسار المباشر
              _subscribeToMenuDirect();
            },
          );
    } else {
      // المسار المباشر: restaurants/{id}/menu أو merchant_products/{id}/products
      _subscribeToMenuDirect();
    }
  }

  /// الاشتراك المباشر بالمنيو من مسار المطعم الجديد (fallback)
  void _subscribeToMenuDirect() {
    _menuSubscription?.cancel();
    _loadingMenuItems = true;

    _menuSubscription = _repository
        .watchMenuItemsDirect(
          restaurantId: restaurantId,
          category: _selectedCategory,
          sortBy: _sortBy,
        )
        .listen(
          (items) {
            if (_isDisposed) return;
            _menuItems = items;
            _loadingMenuItems = false;
            _safeNotifyListeners();
          },
          onError: (e) {
            if (_isDisposed) return;
            _menuItems = [];
            _loadingMenuItems = false;
            _safeNotifyListeners();
          },
        );
  }

  // ─── إدارة تيار السلة والعمليات المالية (Cart Operations) ──────────────────────

  void _subscribeToCart(String cartId) {
    _cartSubscription?.cancel();
    if (cartId.trim().isEmpty) return;

    _cartSubscription = _repository.watchCartItems(cartId).listen(
      (items) {
        if (_isDisposed) return;
        _cartItems.clear();
        _cartPrices.clear();

        for (final item in items) {
          _cartItems[item.id] = item.quantity;
          _cartPrices[item.id] = item.price;
        }

        final summary = RestaurantDetailsCalculator.calculateCartSummary(
          quantities: _cartItems,
          prices: _cartPrices,
        );
        _totalCount = summary.totalCount;
        _totalPrice = summary.totalPrice;

        _safeNotifyListeners();
      },
      onError: (_) {},
    );
  }

  /// إضافة وجبة إلى السلة مع قفل الإجراء (Action Lock)
  Future<bool> addItem({
    required String id,
    required double price,
    required String name,
    String? imageUrl,
    int quantity = 1,
    String size = '',
    String options = '',
    String notes = '',
    String? addedByName,
  }) async {
    if (_isDisposed || _lockedCartItemIds.contains(id)) return false;
    final cartId = _currentEffectiveCartId;
    if (cartId == null || cartId.trim().isEmpty) return false;

    _lockedCartItemIds.add(id);
    try {
      await _repository.addCartItem(
        cartId: cartId,
        itemId: id,
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
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _safeNotifyListeners();
      return false;
    } finally {
      _lockedCartItemIds.remove(id);
    }
  }

  /// إنقاص كمية وجبة أو حذفها من السلة مع قفل الإجراء
  Future<bool> removeItem(String id) async {
    if (_isDisposed || _lockedCartItemIds.contains(id)) return false;
    final cartId = _currentEffectiveCartId;
    if (cartId == null || cartId.trim().isEmpty) return false;

    _lockedCartItemIds.add(id);
    try {
      await _repository.removeCartItem(
        cartId: cartId,
        itemId: id,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _safeNotifyListeners();
      return false;
    } finally {
      _lockedCartItemIds.remove(id);
    }
  }

  // ─── إدارة التقييمات والمراجعات (Reviews Management) ──────────────────────────

  void _subscribeToReviews() {
    _reviewsSubscription?.cancel();
    _loadingReviews = true;

    _reviewsSubscription = _repository.watchRestaurantReviews(restaurantId).listen(
      (reviews) {
        if (_isDisposed) return;
        _reviews = reviews;
        _reviewStatistics = RestaurantDetailsCalculator.calculateReviewStatistics(reviews);
        _loadingReviews = false;
        _safeNotifyListeners();
      },
      onError: (e) {
        if (_isDisposed) return;
        _loadingReviews = false;
        _errorMessage = e.toString();
        _safeNotifyListeners();
      },
    );
  }

  /// إرسال تقييم جديد مع قفل الإجراء والتحقق من صحة المدخلات
  Future<bool> submitReview({
    required String userId,
    required String userName,
    required double rating,
    required String comment,
  }) async {
    if (_isDisposed || _isSubmittingReview) return false;
    if (userId.trim().isEmpty || rating <= 0 || rating > 5) return false;

    _isSubmittingReview = true;
    _safeNotifyListeners();

    try {
      await _repository.addRestaurantReview(
        restaurantId: restaurantId,
        rating: rating,
        comment: comment.trim(),
        userId: userId,
        userName: userName,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmittingReview = false;
      _safeNotifyListeners();
    }
  }

  /// حذف تقييم للمطعم
  Future<bool> deleteReview(String reviewId) async {
    if (_isDisposed || _lockedReviewIds.contains(reviewId)) return false;

    _lockedReviewIds.add(reviewId);
    try {
      await _repository.deleteRestaurantReview(
        restaurantId: restaurantId,
        reviewId: reviewId,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _safeNotifyListeners();
      return false;
    } finally {
      _lockedReviewIds.remove(reviewId);
    }
  }

  // ─── إدارة تخصيص الوجبة (Meal Customization State) ─────────────────────────────

  /// تهيئة نافذة تخصيص الوجبة
  void initCustomization({
    required String id,
    required String name,
    required double basePrice,
    String? imageUrl,
    Map<String, double>? availableAddons,
  }) {
    _customizationItemId = id;
    _customizationName = name;
    _customizationBasePrice = basePrice;
    _customizationImageUrl = imageUrl;
    _selectedSize = 'عادي (وسط)';
    _selectedSizeExtra = 0.0;
    _selectedAddons.clear();
    if (availableAddons != null) {
      _availableAddonPrices.clear();
      _availableAddonPrices.addAll(availableAddons);
    }
    _customizationQuantity = 1;
    _customizationNotes = '';
    _safeNotifyListeners();
  }

  /// اختيار حجم الوجبة
  void selectSize(String sizeName, double extraPrice) {
    if (_isDisposed) return;
    _selectedSize = sizeName;
    _selectedSizeExtra = extraPrice;
    _safeNotifyListeners();
  }

  /// تفعيل أو تعطيل إضافة معينة
  void toggleAddon(String addonName) {
    if (_isDisposed) return;
    if (_selectedAddons.contains(addonName)) {
      _selectedAddons.remove(addonName);
    } else {
      _selectedAddons.add(addonName);
    }
    _safeNotifyListeners();
  }

  /// تعديل كمية الوجبة في نافذة التخصيص
  void setCustomizationQuantity(int quantity) {
    if (_isDisposed || quantity < 1) return;
    _customizationQuantity = quantity;
    _safeNotifyListeners();
  }

  /// كتابة ملاحظات خاصة على الوجبة
  void setCustomizationNotes(String notes) {
    if (_isDisposed) return;
    _customizationNotes = notes;
    _safeNotifyListeners();
  }

  /// إعادة ضبط حالة التخصيص
  void resetCustomization() {
    _customizationItemId = '';
    _customizationName = '';
    _customizationBasePrice = 0.0;
    _customizationImageUrl = null;
    _selectedSize = 'عادي (وسط)';
    _selectedSizeExtra = 0.0;
    _selectedAddons.clear();
    _customizationQuantity = 1;
    _customizationNotes = '';
    _safeNotifyListeners();
  }

  // ─── تفريغ الموارد ودوال الأمان (Disposal & Guards) ────────────────────────────

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _menuSubscription?.cancel();
    _cartSubscription?.cancel();
    _reviewsSubscription?.cancel();
    _lockedCartItemIds.clear();
    _lockedReviewIds.clear();
    super.dispose();
  }
}
