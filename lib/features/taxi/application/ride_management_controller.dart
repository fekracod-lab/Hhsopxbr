// متحكم إدارة رحلات التكسي (Taxi Ride Management Application Controller)
// Clean Architecture — Application Layer: State Management, Concurrency & Stream Lifecycle

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/entities/ride_management_models.dart';
import '../domain/services/ride_management_calculator.dart';
import '../data/repositories/ride_management_repository.dart';

enum RideManagementActionStatus {
  idle,
  loading,
  success,
  failed,
  locked,
}

class RideManagementController extends ChangeNotifier {
  final RideManagementRepository _repository;

  // حراس الجلسة ودورة الحياة
  int _currentGeneration = 0;
  bool _isDisposed = false;
  bool _isLoading = true;

  // أقفال التزامن لمنع التكرار (Action Mutex Locks)
  final Set<String> _activeActionLocks = <String>{};

  // اشتراكات التدفقات
  StreamSubscription<List<TaxiDriverAdminEntity>>? _activeDriversSub;
  StreamSubscription<List<TaxiDriverAdminEntity>>? _allDriversSub;
  StreamSubscription<List<RideAdminEntity>>? _allRidesSub;
  StreamSubscription<List<RideAdminEntity>>? _activeRidesSub;
  StreamSubscription<List<RideAdminEntity>>? _filteredRidesSub;
  StreamSubscription<List<RideAdminEntity>>? _historyRidesSub;
  StreamSubscription<List<DriverReviewAdminEntity>>? _reviewsSub;

  // بيانات الحالة الحية
  List<TaxiDriverAdminEntity> _activeDrivers = [];
  List<TaxiDriverAdminEntity> _allDrivers = [];
  List<RideAdminEntity> _allRides = [];
  List<RideAdminEntity> _activeRides = [];
  List<RideAdminEntity> _queriedRides = [];
  List<RideAdminEntity> _historyRides = [];
  List<DriverReviewAdminEntity> _reviews = [];

  // الفلاتر والاستعلامات
  String _statusFilter = 'all';
  String _searchQuery = '';

  String _driverDebtFilter = 'all'; // 'all', 'blocked', 'exception', 'active'
  String _driverSearchQuery = '';

  String _reviewFilter = 'all'; // 'all', '5_star', '4_star', 'low'
  String _reviewSearchQuery = '';

  // التحديد على الخريطة
  TaxiDriverAdminEntity? _selectedDriver;
  RideAdminEntity? _selectedRide;
  String? _selectedRideId;

  RideManagementController({
    RideManagementRepository? repository,
  }) : _repository = repository ?? RideManagementRepository() {
    initialize();
  }

  // ────────────────────────────────────────────
  // Getters
  // ────────────────────────────────────────────

  bool get isDisposed => _isDisposed;
  bool get isLoading => _isLoading;

  List<TaxiDriverAdminEntity> get activeDrivers => _activeDrivers;
  List<TaxiDriverAdminEntity> get allDrivers => _allDrivers;
  List<RideAdminEntity> get allRides => _allRides;
  List<RideAdminEntity> get activeRides => _activeRides;
  List<RideAdminEntity> get historyRides => _historyRides;
  List<DriverReviewAdminEntity> get reviews => _reviews;

  String get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;

  String get driverDebtFilter => _driverDebtFilter;
  String get driverSearchQuery => _driverSearchQuery;

  String get reviewFilter => _reviewFilter;
  String get reviewSearchQuery => _reviewSearchQuery;

  TaxiDriverAdminEntity? get selectedDriver => _selectedDriver;
  RideAdminEntity? get selectedRide => _selectedRide;
  String? get selectedRideId => _selectedRideId;

  bool isActionLocked(String id) => _activeActionLocks.contains(id);

  // الحسابات المشتقة عبر الدومين
  RideManagementKpiMetrics get kpiMetrics =>
      RideManagementCalculator.calculateKpiMetrics(
        drivers: _allDrivers.isNotEmpty ? _allDrivers : _activeDrivers,
        rides: _allRides.isNotEmpty ? _allRides : _activeRides,
      );

  RideHistoryAnalyticsMetrics get historyAnalytics =>
      RideManagementCalculator.calculateHistoryAnalytics(_historyRides);

  List<RideAdminEntity> get filteredRides {
    final baseList = _statusFilter == 'all' ? _allRides : _queriedRides;
    return RideManagementCalculator.filterRides(
      rides: baseList.isNotEmpty ? baseList : _allRides,
      statusFilter: _statusFilter,
      query: _searchQuery,
    );
  }

  List<TaxiDriverAdminEntity> get filteredDrivers =>
      RideManagementCalculator.filterDrivers(
        drivers: _allDrivers,
        debtFilter: _driverDebtFilter,
        query: _driverSearchQuery,
      );

  List<DriverReviewAdminEntity> get filteredReviews =>
      RideManagementCalculator.filterReviews(
        reviews: _reviews,
        starFilter: _reviewFilter,
        query: _reviewSearchQuery,
      );

  // ────────────────────────────────────────────
  // تهيئة التدفقات (Stream Initialization)
  // ────────────────────────────────────────────

  void initialize() {
    _currentGeneration++;
    final gen = _currentGeneration;

    _cancelSubscriptions();
    _isLoading = true;

    // 1. الكباتن النشطين
    _activeDriversSub = _repository.watchActiveDrivers().listen((list) {
      if (_isDisposed || gen != _currentGeneration) return;
      _activeDrivers = list;
      _isLoading = false;
      notifyListeners();
    });

    // 2. كافة الكباتن
    _allDriversSub = _repository.watchAllDrivers().listen((list) {
      if (_isDisposed || gen != _currentGeneration) return;
      _allDrivers = list;
      notifyListeners();
    });

    // 3. كافة الرحلات
    _allRidesSub = _repository.watchAllRideRequests().listen((list) {
      if (_isDisposed || gen != _currentGeneration) return;
      _allRides = list;
      notifyListeners();
    });

    // 4. الرحلات النشطة
    _activeRidesSub = _repository.watchActiveRideRequests().listen((list) {
      if (_isDisposed || gen != _currentGeneration) return;
      _activeRides = list;
      notifyListeners();
    });

    // 5. الرحلات المفلترة
    _listenToFilteredRides(gen);

    // 6. سجل الرحلات المكتملة
    _historyRidesSub = _repository.watchCompletedRidesHistory().listen((list) {
      if (_isDisposed || gen != _currentGeneration) return;
      _historyRides = list;
      notifyListeners();
    });

    // 7. التقييمات
    _reviewsSub = _repository.watchAllReviews().listen((list) {
      if (_isDisposed || gen != _currentGeneration) return;
      _reviews = list;
      notifyListeners();
    });
  }

  void _listenToFilteredRides(int gen) {
    _filteredRidesSub?.cancel();
    _filteredRidesSub = _repository
        .watchFilteredRideRequests(_statusFilter)
        .listen((list) {
      if (_isDisposed || gen != _currentGeneration) return;
      _queriedRides = list;
      notifyListeners();
    });
  }

  // ────────────────────────────────────────────
  // إجراءات التصفية والاختيار (Filters & Selections)
  // ────────────────────────────────────────────

  void setStatusFilter(String filter) {
    if (_statusFilter == filter) return;
    _statusFilter = filter;
    _listenToFilteredRides(_currentGeneration);
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setDriverDebtFilter(String filter) {
    if (_driverDebtFilter == filter) return;
    _driverDebtFilter = filter;
    notifyListeners();
  }

  void setDriverSearchQuery(String query) {
    _driverSearchQuery = query;
    notifyListeners();
  }

  void setReviewFilter(String filter) {
    if (_reviewFilter == filter) return;
    _reviewFilter = filter;
    notifyListeners();
  }

  void setReviewSearchQuery(String query) {
    _reviewSearchQuery = query;
    notifyListeners();
  }

  void selectDriver(TaxiDriverAdminEntity? driver) {
    _selectedDriver = driver;
    _selectedRide = null;
    _selectedRideId = null;
    notifyListeners();
  }

  void selectRide(RideAdminEntity? ride) {
    _selectedRide = ride;
    _selectedRideId = ride?.id;
    _selectedDriver = null;
    notifyListeners();
  }

  void clearSelection() {
    _selectedDriver = null;
    _selectedRide = null;
    _selectedRideId = null;
    notifyListeners();
  }

  // ────────────────────────────────────────────
  // العمليات الإدارية المحمية بالأقفال (Locked Admin Operations)
  // ────────────────────────────────────────────

  /// إلغاء رحلة إدارياً مع قفل الإجراء
  Future<RideManagementActionStatus> cancelRide({
    required String rideId,
    String? reason,
  }) async {
    if (_activeActionLocks.contains(rideId)) {
      return RideManagementActionStatus.locked;
    }

    _activeActionLocks.add(rideId);
    notifyListeners();

    try {
      await _repository.cancelRide(rideId: rideId, reason: reason);
      if (_selectedRideId == rideId) {
        clearSelection();
      }
      return RideManagementActionStatus.success;
    } catch (_) {
      return RideManagementActionStatus.failed;
    } finally {
      _activeActionLocks.remove(rideId);
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  /// تعيين كابتن للرحلة مع قفل الإجراء
  Future<RideManagementActionStatus> assignDriverToRide({
    required String rideId,
    required TaxiDriverAdminEntity driver,
  }) async {
    if (_activeActionLocks.contains(rideId)) {
      return RideManagementActionStatus.locked;
    }

    _activeActionLocks.add(rideId);
    notifyListeners();

    try {
      await _repository.assignDriverToRide(
        rideId: rideId,
        driverId: driver.id,
        driverName: driver.name,
        driverPhone: driver.phone,
        driverCar: driver.carModel,
      );
      return RideManagementActionStatus.success;
    } catch (_) {
      return RideManagementActionStatus.failed;
    } finally {
      _activeActionLocks.remove(rideId);
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  /// تفعيل/إلغاء استثناء مديونية الكابتن
  Future<RideManagementActionStatus> toggleDriverCommissionException({
    required String driverId,
    required bool allowException,
  }) async {
    if (_activeActionLocks.contains(driverId)) {
      return RideManagementActionStatus.locked;
    }

    _activeActionLocks.add(driverId);
    notifyListeners();

    try {
      await _repository.toggleDriverCommissionException(
        driverId: driverId,
        allowException: allowException,
      );
      return RideManagementActionStatus.success;
    } catch (_) {
      return RideManagementActionStatus.failed;
    } finally {
      _activeActionLocks.remove(driverId);
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  /// تصفير محفظة الكابتن
  Future<RideManagementActionStatus> resetDriverWalletCompletely({
    required String driverId,
    String? reason,
  }) async {
    if (_activeActionLocks.contains(driverId)) {
      return RideManagementActionStatus.locked;
    }

    _activeActionLocks.add(driverId);
    notifyListeners();

    try {
      await _repository.resetDriverWalletCompletely(
        driverId: driverId,
        reason: reason,
      );
      return RideManagementActionStatus.success;
    } catch (_) {
      return RideManagementActionStatus.failed;
    } finally {
      _activeActionLocks.remove(driverId);
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  /// تسوية جزء من عمولة الكابتن
  Future<RideManagementActionStatus> settleDriverCommission({
    required String driverId,
    required double amountPaid,
    String? adminNotes,
  }) async {
    if (_activeActionLocks.contains(driverId)) {
      return RideManagementActionStatus.locked;
    }

    _activeActionLocks.add(driverId);
    notifyListeners();

    try {
      await _repository.settleDriverCommission(
        driverId: driverId,
        amountPaid: amountPaid,
        adminNotes: adminNotes,
      );
      return RideManagementActionStatus.success;
    } catch (_) {
      return RideManagementActionStatus.failed;
    } finally {
      _activeActionLocks.remove(driverId);
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  /// تعديل سقف مديونية الكابتن
  Future<RideManagementActionStatus> updateDriverCommissionLimit({
    required String driverId,
    required double newLimit,
  }) async {
    if (_activeActionLocks.contains(driverId)) {
      return RideManagementActionStatus.locked;
    }

    _activeActionLocks.add(driverId);
    notifyListeners();

    try {
      await _repository.updateDriverCommissionLimit(
        driverId: driverId,
        newLimit: newLimit,
      );
      return RideManagementActionStatus.success;
    } catch (_) {
      return RideManagementActionStatus.failed;
    } finally {
      _activeActionLocks.remove(driverId);
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  /// إرسال إجراء إداري على التقييم
  Future<RideManagementActionStatus> sendAdminReviewAction({
    required String reviewId,
    required String driverId,
    required String actionType,
    String? note,
  }) async {
    final lockKey = 'review_$reviewId';
    if (_activeActionLocks.contains(lockKey)) {
      return RideManagementActionStatus.locked;
    }

    _activeActionLocks.add(lockKey);
    notifyListeners();

    try {
      await _repository.sendAdminReviewAction(
        reviewId: reviewId,
        driverId: driverId,
        actionType: actionType,
        note: note,
      );
      return RideManagementActionStatus.success;
    } catch (_) {
      return RideManagementActionStatus.failed;
    } finally {
      _activeActionLocks.remove(lockKey);
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  // ────────────────────────────────────────────
  // إلغاء الاشتراكات ودورة الحياة (Lifecycle & Disposal)
  // ────────────────────────────────────────────

  void _cancelSubscriptions() {
    _activeDriversSub?.cancel();
    _allDriversSub?.cancel();
    _allRidesSub?.cancel();
    _activeRidesSub?.cancel();
    _filteredRidesSub?.cancel();
    _historyRidesSub?.cancel();
    _reviewsSub?.cancel();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelSubscriptions();
    super.dispose();
  }
}
