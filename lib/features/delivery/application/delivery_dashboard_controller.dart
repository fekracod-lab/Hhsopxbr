// متحكم لوحة تحكم مندوب التوصيل (Delivery Dashboard Application Controller)
// Clean Architecture Application Layer — Zero Firestore / UI / BuildContext Imports

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/entities/delivery_dashboard_models.dart';
import '../domain/services/delivery_dashboard_calculator.dart';
import '../data/repositories/delivery_dashboard_repository.dart';

/// نتيجة محاولة قبول طلب التوصيل الموحدة
enum OrderAcceptanceResult {
  success,
  alreadyLocked,
  notEligible,
  serverRejected,
  error,
  disposed;

  bool get isSuccess => this == OrderAcceptanceResult.success;
}

/// المتحكم الرئيسي في دورة حياة وحالة لوحة تحكم المندوب
class DeliveryDashboardController extends ChangeNotifier {
  final String driverId;
  final DeliveryDashboardRepository _repository;

  // ────────────────────────────────────────────
  // 1. إدارة دورة الحياة وحصانة الأجيال (Generation Guards)
  // ────────────────────────────────────────────
  int _generation = 0;
  bool _isDisposed = false;
  bool _isLoading = true;
  String? _errorMessage;

  // ────────────────────────────────────────────
  // 2. حالة السائق والتوفر والملف الشخصي
  // ────────────────────────────────────────────
  Map<String, dynamic> _driverProfile = {};
  DriverAvailabilityState _availabilityState = DriverAvailabilityState.offline;
  bool _isTogglingAvailability = false;

  // ────────────────────────────────────────────
  // 3. قوائم الطلبات الخام (Raw Merged Streams)
  // ────────────────────────────────────────────
  List<DeliveryOrderEntity> _availableMersal = const [];
  List<DeliveryOrderEntity> _availableFood = const [];
  List<DeliveryOrderEntity> _availableStore = const [];

  List<DeliveryOrderEntity> _activeMersal = const [];
  List<DeliveryOrderEntity> _activeFood = const [];
  List<DeliveryOrderEntity> _activeStore = const [];

  List<DeliveryOrderEntity> _historyMersal = const [];
  List<DeliveryOrderEntity> _historyFood = const [];
  List<DeliveryOrderEntity> _historyStore = const [];

  // ────────────────────────────────────────────
  // 4. الفلاتر والبحث وقفل التزامن الحبيبي
  // ────────────────────────────────────────────
  DeliveryFilterType _selectedFilter = DeliveryFilterType.all;
  String _searchQuery = '';
  final Set<String> _activeOrderLocks = <String>{};
  final Set<String> _knownPendingOrderIds = <String>{};
  bool _isInitialLoadCompleted = false;

  // ────────────────────────────────────────────
  // 5. خطافات التنبيه الصوتي (Audio Alarm Hooks)
  // ────────────────────────────────────────────
  void Function(DeliveryOrderEntity order)? onNewIncomingOrder;
  void Function(String orderId)? onOrderNoLongerPending;

  // ────────────────────────────────────────────
  // 6. اشتراكات التدفقات السحابية
  // ────────────────────────────────────────────
  StreamSubscription? _profileSub;
  StreamSubscription? _availableMersalSub;
  StreamSubscription? _availableFoodSub;
  StreamSubscription? _availableStoreSub;

  StreamSubscription? _activeMersalSub;
  StreamSubscription? _activeFoodSub;
  StreamSubscription? _activeStoreSub;

  StreamSubscription? _historyMersalSub;
  StreamSubscription? _historyFoodSub;
  StreamSubscription? _historyStoreSub;

  DeliveryDashboardController({
    required this.driverId,
    DeliveryDashboardRepository? repository,
    this.onNewIncomingOrder,
    this.onOrderNoLongerPending,
  }) : _repository = repository ?? DeliveryDashboardRepository() {
    initialize();
  }

  // ────────────────────────────────────────────
  // Getters العامة (Public Read-Only State)
  // ────────────────────────────────────────────
  bool get isLoading => _isLoading;
  bool get isDisposed => _isDisposed;
  String? get errorMessage => _errorMessage;
  int get generation => _generation;

  Map<String, dynamic> get driverProfile => Map.unmodifiable(_driverProfile);
  DriverAvailabilityState get availabilityState => _availabilityState;
  bool get isOnline => _availabilityState.isWorking;
  bool get isTogglingAvailability => _isTogglingAvailability;

  String get driverName =>
      _driverProfile['name'] ?? _driverProfile['fullName'] ?? 'مندوب مدار';
  String get driverPhone =>
      _driverProfile['phone'] ?? _driverProfile['phoneNumber'] ?? '';
  double get appDebt => (_driverProfile['appDebt'] as num?)?.toDouble() ?? 0.0;
  double get rating => (_driverProfile['rating'] as num?)?.toDouble() ?? 5.0;

  DeliveryFilterType get selectedFilter => _selectedFilter;
  String get searchQuery => _searchQuery;

  /// جميع الطلبات المتاحة مدمجة ومرتبة زمنياً
  List<DeliveryOrderEntity> get allAvailableOrders {
    final merged = <DeliveryOrderEntity>[
      ..._availableMersal,
      ..._availableFood,
      ..._availableStore,
    ];
    merged.sort((a, b) {
      final tA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tB.compareTo(tA);
    });
    return List.unmodifiable(merged);
  }

  /// الطلبات المتاحة بعد تطبيق الفلترة والبحث الحالي
  List<DeliveryOrderEntity> get filteredAvailableOrders {
    return DeliveryDashboardCalculator.filterOrders(
      orders: allAvailableOrders,
      filter: _selectedFilter,
      searchQuery: _searchQuery,
    );
  }

  /// جميع المهام النشطة للسائق مدمجة ومرتبة زمنياً
  List<DeliveryOrderEntity> get activeTasks {
    final merged = <DeliveryOrderEntity>[
      ..._activeMersal,
      ..._activeFood,
      ..._activeStore,
    ];
    merged.sort((a, b) {
      final tA = a.acceptedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tB = b.acceptedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tB.compareTo(tA);
    });
    return List.unmodifiable(merged);
  }

  /// جميع الطلبات المكتملة في السجل مدمجة ومرتبة زمنياً
  List<DeliveryOrderEntity> get historyOrders {
    final merged = <DeliveryOrderEntity>[
      ..._historyMersal,
      ..._historyFood,
      ..._historyStore,
    ];
    merged.sort((a, b) {
      final tA = a.completedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tB = b.completedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tB.compareTo(tA);
    });
    return List.unmodifiable(merged);
  }

  /// إحصائيات اللوحة الشاملة محسوبة عبر النطاق الصافي
  DeliveryDashboardStatistics get statistics {
    final allOrders = <DeliveryOrderEntity>[
      ...allAvailableOrders,
      ...activeTasks,
      ...historyOrders,
    ];
    return DeliveryDashboardCalculator.calculateDashboardStatistics(
      orders: allOrders,
      referenceDate: DateTime.now(),
      appDebt: appDebt,
    );
  }

  /// نسبة تقدم تحدي اليوم
  DeliveryQuestProgress get questProgress => statistics.questProgress;

  /// التحقق مما إذا كان الطلب مقفلاً حالياً لعملية قبول قيد التنفيذ
  bool isOrderLocked(String orderId) => _activeOrderLocks.contains(orderId);

  // ────────────────────────────────────────────
  // التهيئة وإلغاء التدفقات (Initialization & Streams)
  // ────────────────────────────────────────────
  void initialize() {
    _cancelAllSubscriptions();
    _generation++;
    final currentGen = _generation;
    _isLoading = true;
    _errorMessage = null;

    if (driverId.isEmpty) {
      _isLoading = false;
      _errorMessage = 'معرف المندوب غير صالح';
      _safeNotifyListeners();
      return;
    }

    // 1. تدفق بيانات السائق
    _profileSub = _repository.watchDriverProfile(driverId).listen(
      (profile) {
        if (_isStale(currentGen)) return;
        _driverProfile = profile;
        _availabilityState = DriverAvailabilityState.fromString(profile['availability']?.toString());
        _isLoading = false;
        _safeNotifyListeners();
      },
      onError: (e) => _handleStreamError('DriverProfile', e, currentGen),
    );

    // 2. تدفقات الطلبات المتاحة (Available Orders)
    _availableMersalSub = _repository.watchPendingMersalOrders().listen(
      (orders) {
        if (_isStale(currentGen)) return;
        _availableMersal = orders;
        _processAvailableOrdersAlarm(orders);
        _safeNotifyListeners();
      },
      onError: (e) => _handleStreamError('AvailableMersal', e, currentGen),
    );

    _availableFoodSub = _repository.watchAvailableFoodOrders().listen(
      (orders) {
        if (_isStale(currentGen)) return;
        _availableFood = orders;
        _processAvailableOrdersAlarm(orders);
        _safeNotifyListeners();
      },
      onError: (e) => _handleStreamError('AvailableFood', e, currentGen),
    );

    _availableStoreSub = _repository.watchAvailableStoreOrders().listen(
      (orders) {
        if (_isStale(currentGen)) return;
        _availableStore = orders;
        _processAvailableOrdersAlarm(orders);
        _safeNotifyListeners();
      },
      onError: (e) => _handleStreamError('AvailableStore', e, currentGen),
    );

    // 3. تدفقات المهام النشطة (Active Tasks)
    _activeMersalSub = _repository.watchActiveMersalOrders(driverId).listen(
      (orders) {
        if (_isStale(currentGen)) return;
        _activeMersal = orders;
        _safeNotifyListeners();
      },
      onError: (e) => _handleStreamError('ActiveMersal', e, currentGen),
    );

    _activeFoodSub = _repository.watchActiveFoodOrders(driverId).listen(
      (orders) {
        if (_isStale(currentGen)) return;
        _activeFood = orders;
        _safeNotifyListeners();
      },
      onError: (e) => _handleStreamError('ActiveFood', e, currentGen),
    );

    _activeStoreSub = _repository.watchActiveStoreOrders(driverId).listen(
      (orders) {
        if (_isStale(currentGen)) return;
        _activeStore = orders;
        _safeNotifyListeners();
      },
      onError: (e) => _handleStreamError('ActiveStore', e, currentGen),
    );

    // 4. تدفقات سجل الطلبات (History)
    _historyMersalSub = _repository.watchHistoryMersalOrders(driverId).listen(
      (orders) {
        if (_isStale(currentGen)) return;
        _historyMersal = orders;
        _safeNotifyListeners();
      },
      onError: (e) => _handleStreamError('HistoryMersal', e, currentGen),
    );

    _historyFoodSub = _repository.watchHistoryFoodOrders(driverId).listen(
      (orders) {
        if (_isStale(currentGen)) return;
        _historyFood = orders;
        _safeNotifyListeners();
      },
      onError: (e) => _handleStreamError('HistoryFood', e, currentGen),
    );

    _historyStoreSub = _repository.watchHistoryStoreOrders(driverId).listen(
      (orders) {
        if (_isStale(currentGen)) return;
        _historyStore = orders;
        _safeNotifyListeners();
      },
      onError: (e) => _handleStreamError('HistoryStore', e, currentGen),
    );
  }

  // ────────────────────────────────────────────
  // العمليات والأوامر (Commands & Actions)
  // ────────────────────────────────────────────

  /// تعيين نوع فلترة الطلبات
  void setFilter(DeliveryFilterType filter) {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
    _safeNotifyListeners();
  }

  /// تعيين نص البحث السريع
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _safeNotifyListeners();
  }

  /// تبديل حالة اتصال السائق (Online ⇄ Offline) مع قفل تزامن
  Future<bool> toggleAvailability() async {
    if (_isDisposed || _isTogglingAvailability) return false;

    _isTogglingAvailability = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      final target = DeliveryDashboardCalculator.getNextAvailabilityState(_availabilityState);
      await _repository.setDriverAvailability(
        driverId: driverId,
        availabilityState: target,
      );
      _availabilityState = target;
      return true;
    } catch (e) {
      _errorMessage = 'فشل تغيير حالة التوفر: $e';
      return false;
    } finally {
      _isTogglingAvailability = false;
      _safeNotifyListeners();
    }
  }

  /// قبول طلب توصيل موحد لجميع المصادر مع قفل تزامن حبيبي لكل طلب
  Future<OrderAcceptanceResult> acceptOrder({
    required DeliveryOrderEntity order,
    String? agreedPrice,
  }) async {
    if (_isDisposed) return OrderAcceptanceResult.disposed;

    // 1. التحقق من القفل المحلي لمنع الضغط المزدوج
    if (_activeOrderLocks.contains(order.id)) {
      return OrderAcceptanceResult.alreadyLocked;
    }

    // 2. التحقق من أهلية الطلب والسائق عبر النطاق
    final canAccept = DeliveryDashboardCalculator.canAcceptOrder(
      availability: _availabilityState,
      order: order,
    );
    if (!canAccept) {
      return OrderAcceptanceResult.notEligible;
    }

    _activeOrderLocks.add(order.id);
    _safeNotifyListeners();

    try {
      bool success = false;
      switch (order.source) {
        case DeliveryOrderSource.mersal:
          success = await _repository.acceptMersalOrder(
            requestId: order.id,
            driverId: driverId,
            driverData: _driverProfile,
            agreedPrice: agreedPrice ?? (order.deliveryFee > 0 ? order.deliveryFee.toInt().toString() : '2000'),
          );
          break;
        case DeliveryOrderSource.food:
          success = await _repository.acceptFoodOrder(
            orderId: order.id,
            driverId: driverId,
            driverData: _driverProfile,
          );
          break;
        case DeliveryOrderSource.store:
          final storeId = order.rawData['storeId']?.toString() ?? '';
          success = await _repository.acceptStoreOrder(
            storeId: storeId,
            orderId: order.id,
            driverId: driverId,
            driverData: _driverProfile,
          );
          break;
        case DeliveryOrderSource.unknown:
          success = false;
          break;
      }

      if (success) {
        onOrderNoLongerPending?.call(order.id);
        return OrderAcceptanceResult.success;
      } else {
        return OrderAcceptanceResult.serverRejected;
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء قبول الطلب: $e';
      return OrderAcceptanceResult.error;
    } finally {
      _activeOrderLocks.remove(order.id);
      _safeNotifyListeners();
    }
  }

  // ────────────────────────────────────────────
  // دوال مساعدة داخلية (Private Internal Helpers)
  // ────────────────────────────────────────────
  bool _isStale(int gen) => _isDisposed || gen != _generation;

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _handleStreamError(String streamName, dynamic error, int gen) {
    if (_isStale(gen)) return;
    debugPrint('DeliveryDashboardController: Stream error in $streamName: $error');
    _errorMessage = 'خطأ في مزامنة البيانات: $streamName';
    _safeNotifyListeners();
  }

  void _processAvailableOrdersAlarm(List<DeliveryOrderEntity> orders) {
    for (final order in orders) {
      if (order.id.isEmpty) continue;
      if (order.status.isAvailableForPickup) {
        if (_isInitialLoadCompleted && !_knownPendingOrderIds.contains(order.id)) {
          _knownPendingOrderIds.add(order.id);
          onNewIncomingOrder?.call(order);
        } else {
          _knownPendingOrderIds.add(order.id);
        }
      } else {
        _knownPendingOrderIds.add(order.id);
        onOrderNoLongerPending?.call(order.id);
      }
    }
    _isInitialLoadCompleted = true;
  }

  void _cancelAllSubscriptions() {
    _profileSub?.cancel();
    _availableMersalSub?.cancel();
    _availableFoodSub?.cancel();
    _availableStoreSub?.cancel();
    _activeMersalSub?.cancel();
    _activeFoodSub?.cancel();
    _activeStoreSub?.cancel();
    _historyMersalSub?.cancel();
    _historyFoodSub?.cancel();
    _historyStoreSub?.cancel();

    _profileSub = null;
    _availableMersalSub = null;
    _availableFoodSub = null;
    _availableStoreSub = null;
    _activeMersalSub = null;
    _activeFoodSub = null;
    _activeStoreSub = null;
    _historyMersalSub = null;
    _historyFoodSub = null;
    _historyStoreSub = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _generation++;
    _cancelAllSubscriptions();
    _activeOrderLocks.clear();
    _knownPendingOrderIds.clear();
    super.dispose();
  }
}
