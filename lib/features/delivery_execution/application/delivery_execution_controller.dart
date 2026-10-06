import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/entities/delivery_execution_models.dart';
import '../domain/repositories/i_delivery_execution_repository.dart';
import '../domain/services/delivery_status_machine.dart';
import '../domain/services/delivery_execution_calculator.dart';
import '../domain/services/delivery_route_engine.dart';
import '../data/datasources/delivery_location_datasource.dart';

/// متحكم تنفيذ التوصيل الميداني للكابتن (Driver Delivery Execution Controller)
class DeliveryExecutionController extends ChangeNotifier {
  final IDeliveryExecutionRepository _repository;
  final DeliveryLocationDatasource _locationDatasource;

  DeliveryExecutionEntity? _delivery;
  DeliveryLocationEntity? _currentDriverLocation;
  DeliveryRouteEntity? _currentRoute;
  bool _isLoading = true;
  bool _isActionProcessing = false;
  String? _errorMessage;

  // Streams & Mutex Guards
  StreamSubscription<DeliveryExecutionEntity?>? _deliverySubscription;
  StreamSubscription<DeliveryLocationEntity>? _locationSubscription;
  int _actionGeneration = 0;
  bool _isDisposed = false;

  // Last route calculation references for throttling
  DeliveryLocationEntity? _lastCalculatedDriverLocation;
  DeliveryPoint? _lastCalculatedDestination;

  DeliveryExecutionController({
    required IDeliveryExecutionRepository repository,
    DeliveryLocationDatasource? locationDatasource,
  }) : _repository = repository,
        _locationDatasource = locationDatasource ?? DeliveryLocationDatasource();

  DeliveryExecutionEntity? get delivery => _delivery;
  DeliveryLocationEntity? get currentDriverLocation => _currentDriverLocation;
  DeliveryRouteEntity? get currentRoute => _currentRoute;
  bool get isLoading => _isLoading;
  bool get isActionProcessing => _isActionProcessing;
  String? get errorMessage => _errorMessage;

  /// تهيئة الجلسة والبدء بالاستماع للطلب وموقع السائق
  Future<void> initialize({
    required String orderId,
    required OrderDeliverySource source,
    required DeliveryDriverInfo driverInfo,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. جلب البيانات الأولية
      _delivery = await _repository.getDelivery(orderId, source);

      // 2. الحصول على الموقع الحالي فوراً
      _currentDriverLocation = await _locationDatasource.getCurrentLocation();
      if (_currentDriverLocation != null && _delivery != null) {
        await _calculateRouteInternal(
          _currentDriverLocation!,
          _delivery!.activeTargetPoint,
        );
      }

      // 3. الاستماع للتحديثات الحية لمستند الطلب
      _deliverySubscription?.cancel();
      _deliverySubscription = _repository.streamActiveDelivery(orderId, source).listen(
        (updatedDelivery) {
          if (updatedDelivery != null) {
            final oldStatus = _delivery?.status;
            _delivery = updatedDelivery;

            // إذا تغيرت الحالة وتغيرت النقطة المستهدفة (من المحل إلى الزبون)، أعد حساب المسار
            if (oldStatus != updatedDelivery.status && _currentDriverLocation != null) {
              _calculateRouteInternal(
                _currentDriverLocation!,
                updatedDelivery.activeTargetPoint,
              );
            }
            notifyListeners();
          }
        },
        onError: (err) {
          _errorMessage = 'خطأ في مزامنة بيانات الطلب: $err';
          notifyListeners();
        },
      );

      // 4. الاستماع لتدفق الـ GPS الحي وتحديث السيرفر وحساب المسار
      _locationSubscription?.cancel();
      _locationSubscription = _locationDatasource.getLiveLocationStream().listen(
        (newLoc) {
          _onLocationUpdated(newLoc, driverInfo.id);
        },
        onError: (err) {
          debugPrint(' [DeliveryExecutionController] Location stream error: $err');
        },
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'تعذر بدء جلسة التوصيل: $e';
      notifyListeners();
    }
  }

  /// معالجة تحديثات الموقع الذكية مع كبح الاستدعاءات الزائدة (Intelligent GPS Handling)
  void _onLocationUpdated(DeliveryLocationEntity newLocation, String driverId) async {
    _currentDriverLocation = newLocation;

    if (_delivery == null) {
      notifyListeners();
      return;
    }

    // مزامنة موقع السائق مع قاعدة البيانات
    _repository.syncDriverLocation(
      driverId: driverId,
      location: newLocation,
      activeOrderId: _delivery!.orderId,
      activeSource: _delivery!.source,
    );

    // فحص الحاجة لإعادة حساب المسار
    final targetDestination = _delivery!.activeTargetPoint;
    final bool shouldRecalc = DeliveryRouteEngine.shouldRecalculateRoute(
      currentDriverLocation: newLocation,
      targetDestination: targetDestination,
      existingRoute: _currentRoute,
      lastCalculatedDriverLocation: _lastCalculatedDriverLocation,
      lastCalculatedDestination: _lastCalculatedDestination,
    );

    if (shouldRecalc) {
      await _calculateRouteInternal(newLocation, targetDestination);
    } else {
      notifyListeners();
    }
  }

  /// حساب المسار داخلياً وتخزين النقاط المرجعية
  Future<void> _calculateRouteInternal(
    DeliveryLocationEntity driverLoc,
    DeliveryPoint destination,
  ) async {
    if (!driverLoc.isValid || !destination.isValid) return;

    try {
      final route = await _repository.calculateRoute(
        start: driverLoc,
        destination: destination,
      );
      if (_isDisposed) return;
      _currentRoute = route;
      _lastCalculatedDriverLocation = driverLoc;
      _lastCalculatedDestination = destination;
      notifyListeners();
    } catch (e) {
      if (!_isDisposed) {
        debugPrint(' [DeliveryExecutionController] Error calculating route: $e');
      }
    }
  }

  /// تنفيذ الإجراء التالي للكابتن ذرّياً (Single Primary Driver Action)
  Future<bool> executeNextAction() async {
    if (_delivery == null || _isActionProcessing) return false;

    final nextStatus = DeliveryStatusMachine.getNextAction(_delivery!.status);
    if (nextStatus == null) return false;

    final currentGen = ++_actionGeneration;
    _isActionProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.updateDeliveryStatus(
        orderId: _delivery!.orderId,
        source: _delivery!.source,
        newStatus: nextStatus,
        driverId: _delivery!.driverInfo?.id ?? '',
      );

      if (currentGen != _actionGeneration) return false;

      if (!success) {
        _errorMessage = 'ما قدرنا نحدث حالة الطلب. يرجى التحقق من اتصال الإنترنت.';
      }

      _isActionProcessing = false;
      notifyListeners();
      return success;
    } catch (e) {
      if (currentGen != _actionGeneration) return false;
      _isActionProcessing = false;
      _errorMessage = 'صار خطأ، حاول مرة ثانية: $e';
      notifyListeners();
      return false;
    }
  }

  /// إلغاء الطلب مع توثيق السبب
  Future<bool> cancelDelivery(String reason) async {
    if (_delivery == null || _isActionProcessing) return false;

    final currentGen = ++_actionGeneration;
    _isActionProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.cancelDelivery(
        orderId: _delivery!.orderId,
        source: _delivery!.source,
        driverId: _delivery!.driverInfo?.id ?? '',
        reason: reason,
      );

      if (currentGen != _actionGeneration) return false;
      _isActionProcessing = false;
      notifyListeners();
      return success;
    } catch (e) {
      if (currentGen != _actionGeneration) return false;
      _isActionProcessing = false;
      _errorMessage = 'فشل إلغاء الطلب: $e';
      notifyListeners();
      return false;
    }
  }

  /// إعادة حساب المسار يدوياً عند رغبة السائق
  Future<void> recalculateRouteManually() async {
    if (_currentDriverLocation != null && _delivery != null) {
      await _calculateRouteInternal(
        _currentDriverLocation!,
        _delivery!.activeTargetPoint,
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _deliverySubscription?.cancel();
    _locationSubscription?.cancel();
    _locationDatasource.dispose();
    super.dispose();
  }
}
