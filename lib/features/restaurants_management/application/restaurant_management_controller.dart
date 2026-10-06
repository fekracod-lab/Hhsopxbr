import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/entities/restaurant_management_models.dart';
import '../domain/services/restaurant_management_calculator.dart';
import '../data/repositories/restaurant_management_repository.dart';

/// متحكم إدارة المطاعم (Restaurant Management Controller)
class RestaurantManagementController extends ChangeNotifier {
  final RestaurantManagementRepository _repository;

  RestaurantManagementController({RestaurantManagementRepository? repository})
      : _repository = repository ?? RestaurantManagementRepository();

  String _query = '';
  bool _showMainCollection = true;
  bool _isLoading = true;
  bool _disposed = false;

  List<RestaurantRecord> _restaurants = [];
  StreamSubscription<List<RestaurantRecord>>? _restaurantsSub;

  String get query => _query;
  bool get showMainCollection => _showMainCollection;
  bool get isLoading => _isLoading;

  /// قائمة المطاعم المفلترة حسب نص البحث
  List<RestaurantRecord> get filteredRestaurants {
    return RestaurantManagementCalculator.filterRestaurants(_restaurants, _query);
  }

  /// تهيئة وبدء الاستماع لتدفق المطاعم
  void init() {
    _subscribeToStream();
  }

  void _subscribeToStream() {
    _isLoading = true;
    _notifySafely();

    _restaurantsSub?.cancel();
    _restaurantsSub = _repository
        .getRestaurantsStream(showMainCollection: _showMainCollection)
        .listen((list) {
      _restaurants = list;
      _isLoading = false;
      _notifySafely();
    }, onError: (_) {
      _isLoading = false;
      _notifySafely();
    });
  }

  /// تبديل مصدر البيانات (المجموعة الرئيسية مقابل العناصر)
  void toggleSource(bool showMain) {
    if (_showMainCollection == showMain) return;
    _showMainCollection = showMain;
    _subscribeToStream();
  }

  /// تحديث نص البحث
  void setQuery(String query) {
    _query = query.trim();
    _notifySafely();
  }

  /// تبديل حالة الحظر
  Future<bool> toggleSuspension(RestaurantRecord restaurant) async {
    try {
      await _repository.toggleSuspension(restaurant);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// تعديل بيانات المطعم
  Future<bool> updateRestaurant({
    required RestaurantRecord restaurant,
    required String name,
    required String imageUrl,
    required String status,
  }) async {
    try {
      await _repository.updateRestaurant(
        restaurant: restaurant,
        name: name,
        imageUrl: imageUrl,
        status: status,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// حذف المطعم
  Future<bool> deleteRestaurant(RestaurantRecord restaurant) async {
    try {
      await _repository.deleteRestaurant(restaurant);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// جلب حساب مالك المطعم
  Future<RestaurantOwnerRecord?> getOwnerUser(String ownerId) async {
    return await _repository.getOwnerUser(ownerId);
  }

  /// تغيير كلمة مرور المالك
  Future<bool> changeOwnerPassword(String ownerId, String newPassword) async {
    try {
      await _repository.changeOwnerPassword(ownerId, newPassword);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _restaurantsSub?.cancel();
    super.dispose();
  }
}
