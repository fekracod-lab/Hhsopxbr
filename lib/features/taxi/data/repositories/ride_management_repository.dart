// مستودع إدارة رحلات التكسي (Taxi Ride Management Repository)
// Clean Architecture — Data Layer: Contract Implementation & Entity Mapping

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/ride_management_models.dart';
import '../datasources/ride_management_remote_datasource.dart';

class RideManagementRepository {
  final RideManagementRemoteDatasource _datasource;

  RideManagementRepository({
    RideManagementRemoteDatasource? datasource,
  }) : _datasource = datasource ?? RideManagementRemoteDatasource();

  /// تدفق الكباتن النشطين
  Stream<List<TaxiDriverAdminEntity>> watchActiveDrivers() {
    return _datasource.watchActiveDrivers().map((list) {
      return list.map(_mapToTaxiDriverAdminEntity).toList();
    });
  }

  /// تدفق كافة الكباتن
  Stream<List<TaxiDriverAdminEntity>> watchAllDrivers() {
    return _datasource.watchAllDrivers().map((list) {
      return list.map(_mapToTaxiDriverAdminEntity).toList();
    });
  }

  /// تدفق كافة طلبات الرحلات
  Stream<List<RideAdminEntity>> watchAllRideRequests() {
    return _datasource.watchAllRideRequests().map((list) {
      return list.map(_mapToRideAdminEntity).toList();
    });
  }

  /// تدفق الرحلات النشطة
  Stream<List<RideAdminEntity>> watchActiveRideRequests() {
    return _datasource.watchActiveRideRequests().map((list) {
      return list.map(_mapToRideAdminEntity).toList();
    });
  }

  /// تدفق الرحلات حسب الفلتر
  Stream<List<RideAdminEntity>> watchFilteredRideRequests(String statusFilter) {
    return _datasource.watchFilteredRideRequests(statusFilter).map((list) {
      return list.map(_mapToRideAdminEntity).toList();
    });
  }

  /// تدفق سجل الرحلات المكتملة
  Stream<List<RideAdminEntity>> watchCompletedRidesHistory() {
    return _datasource.watchCompletedRidesHistory().map((list) {
      return list.map(_mapToRideAdminEntity).toList();
    });
  }

  /// تدفق التقييمات
  Stream<List<DriverReviewAdminEntity>> watchAllReviews() {
    return _datasource.watchAllReviews().map((list) {
      return list.map(_mapToDriverReviewAdminEntity).toList();
    });
  }

  /// إلغاء رحلة إدارياً
  Future<void> cancelRide({required String rideId, String? reason}) {
    return _datasource.cancelRide(rideId: rideId, reason: reason);
  }

  /// تعيين كابتن للرحلة
  Future<void> assignDriverToRide({
    required String rideId,
    required String driverId,
    required String driverName,
    required String driverPhone,
    required String driverCar,
  }) {
    return _datasource.assignDriverToRide(
      rideId: rideId,
      driverId: driverId,
      driverName: driverName,
      driverPhone: driverPhone,
      driverCar: driverCar,
    );
  }

  /// تفعيل/إلغاء استثناء مديونية الكابتن
  Future<void> toggleDriverCommissionException({
    required String driverId,
    required bool allowException,
  }) {
    return _datasource.toggleDriverCommissionException(
      driverId: driverId,
      allowException: allowException,
    );
  }

  /// تصفير محفظة الكابتن بالكامل
  Future<void> resetDriverWalletCompletely({
    required String driverId,
    String? reason,
  }) {
    return _datasource.resetDriverWalletCompletely(
      driverId: driverId,
      reason: reason,
    );
  }

  /// تسوية جزء من عمولة الكابتن
  Future<void> settleDriverCommission({
    required String driverId,
    required double amountPaid,
    String? adminNotes,
  }) {
    return _datasource.settleDriverCommission(
      driverId: driverId,
      amountPaid: amountPaid,
      adminNotes: adminNotes,
    );
  }

  /// تعديل سقف مديونية الكابتن
  Future<void> updateDriverCommissionLimit({
    required String driverId,
    required double newLimit,
  }) {
    return _datasource.updateDriverCommissionLimit(
      driverId: driverId,
      newLimit: newLimit,
    );
  }

  /// إرسال إجراء إداري على التقييم
  Future<void> sendAdminReviewAction({
    required String reviewId,
    required String driverId,
    required String actionType,
    String? note,
  }) {
    return _datasource.sendAdminReviewAction(
      reviewId: reviewId,
      driverId: driverId,
      actionType: actionType,
      note: note,
    );
  }

  // ────────────────────────────────────────────
  // دوال التحويل والتخطيط الدفاعية (Mappers)
  // ────────────────────────────────────────────

  RideAdminEntity _mapToRideAdminEntity(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? '';
    final pName = data['passengerName']?.toString() ??
        data['userName']?.toString() ??
        data['clientName']?.toString() ??
        'زبون';
    final pPhone = data['passengerPhone']?.toString() ??
        data['userPhone']?.toString() ??
        data['clientPhone']?.toString() ??
        '';
    final pId = data['passengerId']?.toString() ?? data['userId']?.toString();

    final dId = data['driverId']?.toString();
    final dName = data['driverName']?.toString();
    final dPhone = data['driverPhone']?.toString();
    final dCar = data['driverCar']?.toString() ?? data['carModel']?.toString();

    final pickup = data['pickupAddress']?.toString() ??
        data['from']?.toString() ??
        data['origin']?.toString() ??
        'الموقع الحالي';
    final dropoff = data['dropoffAddress']?.toString() ??
        data['to']?.toString() ??
        data['destination']?.toString() ??
        'الوجهة المحددة';

    final fare = _parseDouble(data['fare'] ?? data['price'] ?? data['totalFare']);
    final statusStr = data['status']?.toString();
    final status = statusStr != null
        ? RideStatusEnum.fromString(statusStr)
        : RideStatusEnum.searching;

    final paymentMethod = data['paymentMethod']?.toString() ?? 'cash';
    final notes = data['notes']?.toString() ?? data['note']?.toString();

    final createdAt = _parseTimestamp(data['createdAt']);
    final acceptedAt = _parseTimestamp(data['acceptedAt']);
    final arrivedAt = _parseTimestamp(data['arrivedAt']);
    final completedAt = _parseTimestamp(data['completedAt']);
    final cancelledAt = _parseTimestamp(data['cancelledAt']);
    final cancelledBy = data['cancelledBy']?.toString();
    final assignedByAdmin = data['assignedByAdmin'] == true;

    final pickupLoc = _parseGeoPoint(data['pickupLocation'] ?? data['pickupLatLng'] ?? data['fromLatLng']);
    final dropoffLoc = _parseGeoPoint(data['dropoffLocation'] ?? data['dropoffLatLng'] ?? data['toLatLng']);

    return RideAdminEntity(
      id: id,
      passengerName: pName,
      passengerPhone: pPhone,
      passengerId: pId,
      driverId: dId,
      driverName: dName,
      driverPhone: dPhone,
      driverCar: dCar,
      pickupAddress: pickup,
      pickupLocation: pickupLoc,
      dropoffAddress: dropoff,
      dropoffLocation: dropoffLoc,
      fare: fare,
      status: status,
      paymentMethod: paymentMethod,
      notes: notes,
      createdAt: createdAt,
      acceptedAt: acceptedAt,
      arrivedAt: arrivedAt,
      completedAt: completedAt,
      cancelledAt: cancelledAt,
      cancelledBy: cancelledBy,
      assignedByAdmin: assignedByAdmin,
      rawData: data,
    );
  }

  TaxiDriverAdminEntity _mapToTaxiDriverAdminEntity(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? '';
    final name = data['name']?.toString() ?? data['driverName']?.toString() ?? 'كابتن تكسي';
    final phone = data['phone']?.toString() ?? data['driverPhone']?.toString() ?? '';
    final carModel = data['carModel']?.toString() ?? data['vehicle']?.toString() ?? 'غير محدد';
    final carNumber = data['carNumber']?.toString() ?? data['plateNumber']?.toString() ?? '';
    final carColor = data['carColor']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'active';

    final isOnline = data['isOnline'] == true ||
        data['availability']?.toString().toLowerCase() == 'online' ||
        data['driverStatus']?.toString().toLowerCase() == 'online';

    final appDebt = _parseDouble(data['appDebt'] ?? data['debt'] ?? data['commissionDebt']);
    final limit = _parseDouble(data['commissionLimit'] ?? data['debtLimit'] ?? 10000.0);
    final allowException = data['allowCommissionException'] == true || data['commissionException'] == true;

    final totalRides = (data['totalRides'] is num)
        ? (data['totalRides'] as num).toInt()
        : (int.tryParse(data['totalRides']?.toString() ?? '0') ?? 0);

    final rating = _parseDouble(data['rating'] ?? data['driverRating'] ?? 5.0);
    final location = _parseGeoPoint(data['location'] ?? data['latLng'] ?? data['currentLocation']);

    return TaxiDriverAdminEntity(
      id: id,
      name: name,
      phone: phone,
      carModel: carModel,
      carNumber: carNumber,
      carColor: carColor,
      status: status,
      isOnline: isOnline,
      appDebt: appDebt,
      commissionLimit: limit > 0 ? limit : 10000.0,
      allowCommissionException: allowException,
      totalRides: totalRides,
      rating: rating,
      location: location,
      rawData: data,
    );
  }

  DriverReviewAdminEntity _mapToDriverReviewAdminEntity(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? '';
    final driverId = data['driverId']?.toString() ?? '';
    final driverName = data['driverName']?.toString() ?? 'كابتن';
    final customerId = data['customerId']?.toString() ?? data['userId']?.toString() ?? '';
    final customerName = data['customerName']?.toString() ?? data['userName']?.toString() ?? 'زبون';
    final rating = _parseDouble(data['rating'] ?? 5.0);
    final comment = data['comment']?.toString() ?? data['review']?.toString() ?? '';
    final rideId = data['rideId']?.toString() ?? '';
    final createdAt = _parseTimestamp(data['createdAt']);

    return DriverReviewAdminEntity(
      id: id,
      driverId: driverId,
      driverName: driverName,
      customerId: customerId,
      customerName: customerName,
      rating: rating,
      comment: comment,
      rideId: rideId,
      createdAt: createdAt,
      rawData: data,
    );
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  DateTime? _parseTimestamp(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  PureGeoPoint? _parseGeoPoint(dynamic val) {
    if (val == null) return null;
    if (val is GeoPoint) {
      return PureGeoPoint(latitude: val.latitude, longitude: val.longitude);
    }
    if (val is Map) {
      final lat = _parseDouble(val['latitude'] ?? val['lat']);
      final lng = _parseDouble(val['longitude'] ?? val['lng']);
      if (lat != 0.0 || lng != 0.0) {
        return PureGeoPoint(latitude: lat, longitude: lng);
      }
    }
    return null;
  }
}
