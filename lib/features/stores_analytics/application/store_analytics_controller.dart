import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/entities/store_analytics_models.dart';
import '../domain/services/store_analytics_calculator.dart';
import '../data/repositories/store_analytics_repository.dart';

/// متحكم إدارة وتحليلات المتاجر (Store Analytics Controller)
class StoreAnalyticsController extends ChangeNotifier {
  final StoreAnalyticsRepository _repository;

  StoreAnalyticsController({StoreAnalyticsRepository? repository})
      : _repository = repository ?? StoreAnalyticsRepository();

  int _selectedTab = 0; // 0: Pending Requests, 1: Approved Stores
  String _searchQuery = '';
  bool _isLoading = true;
  bool _disposed = false;

  List<StoreRecord> _allStores = [];
  List<StoreRecord> _pendingRequests = [];
  List<StoreOrderRecord> _allOrders = [];
  Map<String, ({double totalSales, int completedCount})> _storeSalesMap = {};

  StreamSubscription? _storesSub;
  StreamSubscription? _pendingRequestsSub;
  StreamSubscription? _ordersSub;

  int get selectedTab => _selectedTab;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  /// قائمة طلبات الانضمام المفلترة حسب البحث
  List<StoreRecord> get filteredPendingRequests {
    return StoreAnalyticsCalculator.filterStores(_pendingRequests, _searchQuery);
  }

  /// قائمة المتاجر المسجلة المفلترة حسب البحث
  List<StoreRecord> get filteredStores {
    return StoreAnalyticsCalculator.filterStores(_allStores, _searchQuery);
  }

  /// ملخص الإحصائيات الشامل للبطاقات العلوية
  OverallStoreAnalyticsSummary get overallSummary {
    return StoreAnalyticsCalculator.calculateOverallSummary(
      allStores: _allStores,
      allOrders: _allOrders,
    );
  }

  /// الحصول على إحصائيات المبيعات لمتجر محدد
  ({double totalSales, int completedCount}) getSalesForStore(String storeId) {
    return _storeSalesMap[storeId] ?? (totalSales: 0.0, completedCount: 0);
  }

  /// بدء الاستماع للبيانات وتحديثها تلقائياً
  void init() {
    _isLoading = true;

    _storesSub = _repository.getRegisteredStoresStream().listen((stores) {
      _allStores = stores;
      _isLoading = false;
      _notifySafely();
    }, onError: (_) {
      _isLoading = false;
      _notifySafely();
    });

    _pendingRequestsSub = _repository.getPendingStoreRequestsStream().listen((pending) {
      _pendingRequests = pending;
      _notifySafely();
    });

    _ordersSub = _repository.getOrdersStream().listen((orders) {
      _allOrders = orders;
      _storeSalesMap = StoreAnalyticsCalculator.aggregateStoreSales(orders);
      _notifySafely();
    });
  }

  void setTab(int index) {
    if (_selectedTab == index) return;
    _selectedTab = index;
    _notifySafely();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    _notifySafely();
  }

  Future<bool> approveStore(String storeId) async {
    try {
      await _repository.approveStore(storeId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectStore(String storeId) async {
    try {
      await _repository.rejectStore(storeId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleStoreStatus(String storeId, bool isApproved) async {
    try {
      await _repository.toggleStoreStatus(storeId, isApproved);
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
    _storesSub?.cancel();
    _pendingRequestsSub?.cancel();
    _ordersSub?.cancel();
    super.dispose();
  }
}
