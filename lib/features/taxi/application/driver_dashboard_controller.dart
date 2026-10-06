import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../../../services/taxi_background_service.dart';
import '../domain/entities/driver_dashboard_models.dart';
import '../domain/services/driver_dashboard_calculator.dart';
import '../data/repositories/driver_dashboard_repository.dart';

/// متحكم لوحة تحكم الكابتن (Driver Dashboard Controller)
class DriverDashboardController extends ChangeNotifier {
  final DriverDashboardRepository _repository;
  final String? driverUid;

  DriverDashboardController({
    DriverDashboardRepository? repository,
    required this.driverUid,
  }) : _repository = repository ?? DriverDashboardRepository();

  // State Variables
  int _currentTab = 0;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _disposed = false;

  DriverProfileEntity? _driverProfile;
  List<RideRequestEntity> _allPendingRequests = [];
  RideRequestEntity? _activeRide;
  List<RideRequestEntity> _historyTrips = [];
  int _unreadNotificationsCount = 0;

  final Set<String> _locallyRejectedIds = {};
  String? _myWayDestination;
  bool _isMyWayActive = false;

  // GPS & Map State
  LatLng? _initialDriverPosition;
  LatLng? _liveDriverPosition;
  bool _shouldFollowDriver = true;
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _carIcon;
  DateTime? _lastLocationWriteAt;

  // Stream Subscriptions
  StreamSubscription<DriverProfileEntity?>? _driverSub;
  StreamSubscription<List<RideRequestEntity>>? _requestsSub;
  StreamSubscription<List<RideRequestEntity>>? _currentRideSub;
  StreamSubscription<List<RideRequestEntity>>? _historySub;
  StreamSubscription<int>? _notifCountSub;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription? _serverMsgSub;

  // Getters
  int get currentTab => _currentTab;
  bool get isLoading => _isLoading;
  bool get isProcessing => _isProcessing;
  DriverProfileEntity? get driverProfile => _driverProfile;
  RideRequestEntity? get activeRide => _activeRide;
  int get unreadNotificationsCount => _unreadNotificationsCount;
  bool get isMyWayActive => _isMyWayActive;
  String? get myWayDestination => _myWayDestination;
  LatLng? get initialDriverPosition => _initialDriverPosition;
  LatLng? get liveDriverPosition => _liveDriverPosition;
  bool get shouldFollowDriver => _shouldFollowDriver;
  Set<Polyline> get polylines => _polylines;
  BitmapDescriptor? get carIcon => _carIcon;

  /// قائمة الطلبات المعلقة الطازجة والمفلترة
  List<RideRequestEntity> get filteredPendingRequests {
    var fresh = DriverDashboardCalculator.filterFreshPendingRequests(
      _allPendingRequests,
      currentDriverUid: driverUid,
      locallyRejectedIds: _locallyRejectedIds,
    );

    if (_isMyWayActive && _myWayDestination != null) {
      fresh = DriverDashboardCalculator.filterMyWayRequests(fresh, _myWayDestination);
    }

    return fresh;
  }

  /// إحصائيات وأرباح الكابتن المحسوبة
  DriverStatsEntity get driverStats {
    final completedTrips = _historyTrips.where((t) => t.status == RideStatus.completed).toList();
    final cancelledTrips = _historyTrips.where((t) => t.status == RideStatus.cancelled).toList();

    final weeklyEarnings = DriverDashboardCalculator.computeWeeklyEarningsArray(completedTrips);
    final cancellationRate = DriverDashboardCalculator.calculateCancellationRate(
      totalTrips: _historyTrips.length,
      cancelledTrips: cancelledTrips.length,
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayTrips = completedTrips.where((t) {
      if (t.createdAt == null) return false;
      final tripDate = DateTime(t.createdAt!.year, t.createdAt!.month, t.createdAt!.day);
      return tripDate == today;
    }).toList();

    final todayEarnings = todayTrips.fold(0.0, (sum, t) => sum + t.estimatedFare);

    return DriverStatsEntity(
      weeklyEarnings: weeklyEarnings,
      totalTripsCount: completedTrips.length,
      cancellationRate: cancellationRate,
      todayCompletedTrips: todayTrips.length,
      todayEarningsTotal: todayEarnings,
    );
  }

  /// بدء الاستماع لكافة تدفقات الكابتن وإدارة دورة الحياة
  void init() {
    if (driverUid == null) return;
    _isLoading = true;

    // 1. الاستماع لبيانات الكابتن
    _driverSub = _repository.getDriverProfileStream(driverUid!).listen((profile) {
      _driverProfile = profile;
      _isLoading = false;
      _notifySafely();

      // إدارة GPS التلقائية حسب حالة الاتصال
      if (profile != null && (profile.isOnline || profile.isOnTrip)) {
        _startLiveLocationTracking();
      } else {
        _stopLiveLocationTracking();
      }
    }, onError: (_) {
      _isLoading = false;
      _notifySafely();
    });

    // 2. الاستماع للطلبات المتاحة
    _requestsSub = _repository.getPendingRequestsStream().listen((requests) {
      _allPendingRequests = requests;
      _notifySafely();
    });

    // 3. الاستماع للرحلة الحالية
    _currentRideSub = _repository.getCurrentRideStream(driverUid!).listen((rides) {
      _activeRide = rides.isNotEmpty ? rides.first : null;
      _notifySafely();
    });

    // 4. الاستماع لسجل الرحلات
    _historySub = _repository.getRideHistoryStream(driverUid!).listen((history) {
      _historyTrips = history;
      _notifySafely();
    });

    // 5. الاستماع للإشعارات
    _notifCountSub = _repository.getUnreadNotificationsCountStream(driverUid!).listen((count) {
      _unreadNotificationsCount = count;
      _notifySafely();
    });

    // 6. الاستماع لنقر الإشعار من الخدمة الخلفية
    try {
      _serverMsgSub = FlutterBackgroundService().on('notification_clicked').listen((_) {
        _currentTab = 0;
        _notifySafely();
      });
    } catch (_) {}

    _fetchInitialLocation();
  }

  void setTab(int index) {
    if (_currentTab == index) return;
    _currentTab = index;
    _notifySafely();
  }

  void setCarIcon(BitmapDescriptor icon) {
    _carIcon = icon;
    _notifySafely();
  }

  void setPolylines(Set<Polyline> polylines) {
    _polylines = polylines;
    _notifySafely();
  }

  void setShouldFollowDriver(bool value) {
    _shouldFollowDriver = value;
    _notifySafely();
  }

  void toggleMyWay(bool active, String? destination) {
    _isMyWayActive = active;
    _myWayDestination = destination;
    _notifySafely();
  }

  /// تبديل حالة الاتصال (Online / Offline) مع إدارة الخدمة الخلفية وموقع GPS
  Future<void> toggleOnlineAvailability() async {
    if (driverUid == null || _driverProfile == null) return;
    final target = _driverProfile!.isOnline ? DriverAvailability.offline : DriverAvailability.online;

    await _repository.setDriverAvailability(driverUid!, target);

    if (target == DriverAvailability.online) {
      try {
        await TaxiBackgroundService.startDriverOnline(
          serverUrl: '',
          token: '',
          userId: driverUid!,
        );
      } catch (e) {
        debugPrint('[DriverDashboardController] Background service error: $e');
      }
      _startLiveLocationTracking();
    } else {
      try {
        TaxiBackgroundService.stop();
      } catch (_) {}
      _stopLiveLocationTracking();
    }
  }

  /// قبول الطلب بحماية ذرية لمنع القبول المزدوج
  Future<bool> acceptRide(RideRequestEntity request) async {
    if (driverUid == null || _isProcessing) return false;
    _isProcessing = true;
    _notifySafely();

    try {
      final success = await _repository.acceptRideAtomic(
        requestId: request.id,
        driverId: driverUid!,
        driverData: _driverProfile?.rawData ?? {},
      );

      if (success) {
        try {
          TaxiBackgroundService.stopRingtone();
        } catch (_) {}
      }

      _isProcessing = false;
      _notifySafely();
      return success;
    } catch (_) {
      _isProcessing = false;
      _notifySafely();
      return false;
    }
  }

  /// رفض الطلب
  Future<void> rejectRide(RideRequestEntity request) async {
    _locallyRejectedIds.add(request.id);
    try {
      TaxiBackgroundService.stopRingtone();
    } catch (_) {}
    _notifySafely();

    if (driverUid != null) {
      await _repository.rejectRideForDriver(request.id, driverUid!);
    }
  }

  /// تحديث حالة الرحلة
  Future<void> updateRideStatus(String status, {double? finalFare}) async {
    if (_activeRide == null || driverUid == null) return;
    await _repository.updateRideStatus(
      requestId: _activeRide!.id,
      status: status,
      driverId: driverUid!,
      finalFare: finalFare,
    );
  }

  /// جلب الموقع الأولي بشكل آمن وسريع بدون تعليق
  Future<void> _fetchInitialLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _initialDriverPosition = const LatLng(33.3152, 44.3661);
        _liveDriverPosition = _initialDriverPosition;
        _notifySafely();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        _initialDriverPosition = const LatLng(33.3152, 44.3661);
        _liveDriverPosition = _initialDriverPosition;
        _notifySafely();
        return;
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _initialDriverPosition = LatLng(lastKnown.latitude, lastKnown.longitude);
        _liveDriverPosition = _initialDriverPosition;
        _notifySafely();
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );
      _initialDriverPosition = LatLng(pos.latitude, pos.longitude);
      _liveDriverPosition = _initialDriverPosition;
      _notifySafely();
    } catch (e) {
      debugPrint('[DriverDashboardController] Initial location fallback: $e');
      if (_initialDriverPosition == null) {
        _initialDriverPosition = const LatLng(33.3152, 44.3661);
        _liveDriverPosition = _initialDriverPosition;
        _notifySafely();
      }
    }
  }

  /// بدء تتبع GPS بدقة وإرسال التحديثات Throttled إلى Firestore مع التحقق المسبق من الصلاحيات
  Future<void> _startLiveLocationTracking() async {
    _positionSub?.cancel();
    _positionSub = null;
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[DriverDashboardController] Location service disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        debugPrint('[DriverDashboardController] Location permission not granted: $permission');
        return;
      }

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 5,
        ),
      ).handleError((err) {
        debugPrint('[DriverDashboardController] Live position stream error handled: $err');
      }).listen((position) {
        _liveDriverPosition = LatLng(position.latitude, position.longitude);
        _notifySafely();

        if (driverUid != null) {
          final now = DateTime.now();
          final isOnTrip = _driverProfile?.isOnTrip ?? false;
          final int threshold = isOnTrip ? 3 : 10; // 3s on trip, 10s idle online

          if (_lastLocationWriteAt == null ||
              now.difference(_lastLocationWriteAt!).inSeconds >= threshold) {
            _lastLocationWriteAt = now;
            _repository.updateDriverLocation(
              driverId: driverUid!,
              latitude: position.latitude,
              longitude: position.longitude,
              heading: position.heading,
            );
          }
        }
      }, onError: (err) {
        debugPrint('[DriverDashboardController] Live position stream error: $err');
      });
    } catch (e) {
      debugPrint('[DriverDashboardController] Could not start location stream: $e');
    }
  }

  /// إيقاف تتبع GPS
  void _stopLiveLocationTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    _lastLocationWriteAt = null;
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _driverSub?.cancel();
    _requestsSub?.cancel();
    _currentRideSub?.cancel();
    _historySub?.cancel();
    _notifCountSub?.cancel();
    _serverMsgSub?.cancel();
    _stopLiveLocationTracking();
    super.dispose();
  }
}
