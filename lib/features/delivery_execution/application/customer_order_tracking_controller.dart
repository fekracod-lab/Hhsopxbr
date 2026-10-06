import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/entities/delivery_execution_models.dart';
import '../domain/repositories/i_delivery_execution_repository.dart';
import '../domain/services/delivery_route_engine.dart';

/// متحكم تتبع الطلب المباشر من جهة الزبون (Customer Order Live Tracking Controller)
class CustomerOrderTrackingController extends ChangeNotifier {
  final IDeliveryExecutionRepository _repository;

  DeliveryExecutionEntity? _delivery;
  DeliveryLocationEntity? _driverLocation;
  DeliveryRouteEntity? _routeToCustomer;
  bool _isLoading = true;
  String? _errorMessage;

  StreamSubscription<DeliveryExecutionEntity?>? _orderSubscription;
  StreamSubscription<DeliveryLocationEntity?>? _driverLocationSubscription;

  // Last route calculation references for customer-side throttling
  DeliveryLocationEntity? _lastCalculatedDriverLoc;
  DeliveryPoint? _lastCalculatedDropoff;

  CustomerOrderTrackingController({
    required IDeliveryExecutionRepository repository,
  }) : _repository = repository;

  DeliveryExecutionEntity? get delivery => _delivery;
  DeliveryLocationEntity? get driverLocation => _driverLocation;
  DeliveryRouteEntity? get routeToCustomer => _routeToCustomer;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// تهيئة تتبع الطلب
  Future<void> initialize({
    required String orderId,
    required OrderDeliverySource source,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. جلب البيانات الأولية
      _delivery = await _repository.getDelivery(orderId, source);

      if (_delivery == null) {
        _errorMessage = 'الطلب غير موجود أو تم إلغاؤه';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 2. بدء الاستماع لتحديثات الطلب
      _orderSubscription?.cancel();
      _orderSubscription = _repository.streamActiveDelivery(orderId, source).listen(
        (updatedDelivery) {
          if (updatedDelivery != null) {
            final oldDriverId = _delivery?.driverInfo?.id;
            _delivery = updatedDelivery;

            // إذا تم تعيين سائق أو تغير السائق، ابدأ الاستماع لموقعه
            final newDriverId = updatedDelivery.driverInfo?.id;
            if (newDriverId != null && newDriverId.isNotEmpty && newDriverId != oldDriverId) {
              _listenToDriverLocation(newDriverId);
            }
            notifyListeners();
          }
        },
        onError: (err) {
          _errorMessage = 'ما قدرنا نحدث بيانات الطلب: $err';
          notifyListeners();
        },
      );

      // 3. الاستماع للسائق إذا كان معيناً بالفعل
      if (_delivery?.driverInfo?.id != null && _delivery!.driverInfo!.id.isNotEmpty) {
        _listenToDriverLocation(_delivery!.driverInfo!.id);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'حدث خطأ في تحميل مسار التتبع: $e';
      notifyListeners();
    }
  }

  void _listenToDriverLocation(String driverId) {
    _driverLocationSubscription?.cancel();
    _driverLocationSubscription = _repository.streamDriverLocation(driverId).listen(
      (driverLoc) {
        if (driverLoc != null) {
          _driverLocation = driverLoc;
          _onDriverLocationChanged(driverLoc);
        }
      },
      onError: (err) {
        debugPrint(' [CustomerOrderTrackingController] Driver location error: $err');
      },
    );
  }

  void _onDriverLocationChanged(DeliveryLocationEntity loc) async {
    if (_delivery == null) {
      notifyListeners();
      return;
    }

    final targetDropoff = _delivery!.dropoffPoint;
    final bool shouldRecalc = DeliveryRouteEngine.shouldRecalculateRoute(
      currentDriverLocation: loc,
      targetDestination: targetDropoff,
      existingRoute: _routeToCustomer,
      lastCalculatedDriverLocation: _lastCalculatedDriverLoc,
      lastCalculatedDestination: _lastCalculatedDropoff,
    );

    if (shouldRecalc && targetDropoff.isValid) {
      try {
        final route = await _repository.calculateRoute(
          start: loc,
          destination: targetDropoff,
        );
        _routeToCustomer = route;
        _lastCalculatedDriverLoc = loc;
        _lastCalculatedDropoff = targetDropoff;
        notifyListeners();
      } catch (_) {
        notifyListeners();
      }
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    super.dispose();
  }
}
