import 'package:flutter/foundation.dart';
import '../domain/entities/delivery_accounting_models.dart';
import '../data/repositories/delivery_accounting_repository.dart';

/// متحكم حالة شاشة المحاسبة الأسبوعية (Delivery Accounting Controller)
class DeliveryAccountingController extends ChangeNotifier {
  final DeliveryAccountingRepository _repository;
  final String? driverId;
  final String? govId;
  final String? regionId;

  DeliveryAccountingController({
    DeliveryAccountingRepository? repository,
    this.driverId,
    this.govId,
    this.regionId,
  }) : _repository = repository ?? DeliveryAccountingRepository();

  bool _isLoading = true;
  String _errorMessage = '';
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get hasError => _errorMessage.isNotEmpty;
  bool get isManagerMode => govId != null;

  // Driver mode data
  List<WeeklySummaryEntity> _driverModeSummaries = const [];
  List<WeeklySummaryEntity> get driverModeSummaries => _driverModeSummaries;

  // Manager mode data
  Map<String, Map<String, dynamic>> _driversMap = const {};
  Map<String, String> _restaurantNamesMap = const {};
  Map<String, String> _storeNamesMap = const {};
  Map<String, PaymentStatusRecord> _paymentsStatusMap = const {};

  List<WeeklySummaryEntity> _managerDriverSummaries = const [];
  List<WeeklySummaryEntity> _managerRestaurantSummaries = const [];
  List<WeeklySummaryEntity> _managerStoreSummaries = const [];

  Map<String, Map<String, dynamic>> get driversMap => _driversMap;
  Map<String, String> get restaurantNamesMap => _restaurantNamesMap;
  Map<String, String> get storeNamesMap => _storeNamesMap;
  Map<String, PaymentStatusRecord> get paymentsStatusMap => _paymentsStatusMap;

  List<WeeklySummaryEntity> get managerDriverSummaries => _managerDriverSummaries;
  List<WeeklySummaryEntity> get managerRestaurantSummaries => _managerRestaurantSummaries;
  List<WeeklySummaryEntity> get managerStoreSummaries => _managerStoreSummaries;

  /// بدء تحميل البيانات
  Future<void> fetchData() async {
    _isLoading = true;
    _errorMessage = '';
    _notifySafely();

    try {
      if (isManagerMode) {
        final data = await _repository.getManagerAccountingData(
          govId: govId!,
          regionId: regionId,
        );

        _driversMap = data.driversMap;
        _restaurantNamesMap = data.restaurantNamesMap;
        _storeNamesMap = data.storeNamesMap;
        _paymentsStatusMap = data.paymentsStatusMap;
        _managerDriverSummaries = data.driverSummaries;
        _managerRestaurantSummaries = data.restaurantSummaries;
        _managerStoreSummaries = data.storeSummaries;
      } else if (driverId != null) {
        _driverModeSummaries = await _repository.getDriverWeeklySummaries(driverId!);
      }
      _isLoading = false;
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء تحميل البيانات: $e';
      _isLoading = false;
    }

    _notifySafely();
  }

  /// تحديث حالة المحاسبة الأسبوعية
  Future<bool> updatePaymentStatus({
    required String tabName,
    required DateTime weekStart,
    required String newStatus,
    DateTime? postponedToDate,
  }) async {
    if (govId == null) return false;

    final dateKey = '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    final key = '${tabName}_$dateKey';

    try {
      await _repository.updatePaymentStatus(
        govId: govId!,
        key: key,
        newStatus: newStatus,
        postponedToDate: postponedToDate,
      );

      final updatedMap = Map<String, PaymentStatusRecord>.from(_paymentsStatusMap);
      updatedMap[key] = PaymentStatusRecord(
        status: newStatus,
        postponedTo: postponedToDate,
        updatedAt: DateTime.now(),
      );
      _paymentsStatusMap = updatedMap;

      _notifySafely();
      return true;
    } catch (e) {
      return false;
    }
  }

  PaymentStatusRecord getStatusForWeek(String tabName, DateTime weekStart) {
    final dateKey = '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    final key = '${tabName}_$dateKey';
    return _paymentsStatusMap[key] ?? PaymentStatusRecord.unpaid();
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
