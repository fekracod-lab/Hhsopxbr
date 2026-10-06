import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/delivery_execution_models.dart';

/// مصدر بيانات تحديد المواقع الحية (Live GPS Location Datasource)
class DeliveryLocationDatasource {
  StreamSubscription<Position>? _positionSubscription;

  /// الحصول على الموقع الحالي للسائق
  Future<DeliveryLocationEntity?> getCurrentLocation() async {
    try {
      final hasPermission = await _checkAndRequestPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return DeliveryLocationEntity(
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading,
        speed: position.speed,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
      );
    } catch (e) {
      debugPrint(' [DeliveryLocationDatasource] getCurrentLocation error: $e');
      return null;
    }
  }

  /// تدفق مستمر لإحداثيات السائق مع فلترة المسافة (10 أمتار)
  Stream<DeliveryLocationEntity> getLiveLocationStream({
    int distanceFilterMeters = 10,
  }) {
    late StreamController<DeliveryLocationEntity> controller;

    void onListen() async {
      final hasPermission = await _checkAndRequestPermission();
      if (!hasPermission) {
        controller.addError('Location permission denied');
        return;
      }

      _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilterMeters,
        ),
      ).listen(
        (pos) {
          final entity = DeliveryLocationEntity(
            latitude: pos.latitude,
            longitude: pos.longitude,
            heading: pos.heading,
            speed: pos.speed,
            accuracy: pos.accuracy,
            timestamp: pos.timestamp,
          );
          if (!controller.isClosed) {
            controller.add(entity);
          }
        },
        onError: (err) {
          if (!controller.isClosed) controller.addError(err);
        },
      );
    }

    void onCancel() {
      _positionSubscription?.cancel();
      _positionSubscription = null;
    }

    controller = StreamController<DeliveryLocationEntity>.broadcast(
      onListen: onListen,
      onCancel: onCancel,
    );

    return controller.stream;
  }

  Future<bool> _checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  void dispose() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
