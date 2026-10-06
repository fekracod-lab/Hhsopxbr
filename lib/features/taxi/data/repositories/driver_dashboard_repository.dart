import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/driver_dashboard_models.dart';
import '../datasources/driver_dashboard_remote_datasource.dart';

/// مستودع لوحة تحكم الكابتن (Driver Dashboard Repository)
class DriverDashboardRepository {
  final DriverDashboardRemoteDatasource _datasource;

  DriverDashboardRepository({DriverDashboardRemoteDatasource? datasource})
      : _datasource = datasource ?? DriverDashboardRemoteDatasource();

  /// بث بيانات بروفايل الكابتن
  Stream<DriverProfileEntity?> getDriverProfileStream(String driverId) {
    return _datasource.getDriverDocStream(driverId).map((data) {
      if (data == null) return null;
      return _mapToDriverProfile(data);
    });
  }

  /// بث قائمة الطلبات المعلقة المتاحة
  Stream<List<RideRequestEntity>> getPendingRequestsStream() {
    return _datasource.getPendingRequestsStream().map((list) {
      return list.map(_mapToRideRequest).toList();
    });
  }

  /// بث الرحلة النشطة الحالية للكابتن
  Stream<List<RideRequestEntity>> getCurrentRideStream(String driverId) {
    return _datasource.getCurrentRideStream(driverId).map((list) {
      return list.map(_mapToRideRequest).toList();
    });
  }

  /// بث سجل الرحلات السابقة للكابتن
  Stream<List<RideRequestEntity>> getRideHistoryStream(String driverId) {
    return _datasource.getRideHistoryStream(driverId).map((list) {
      return list.map(_mapToRideRequest).toList();
    });
  }

  /// بث عدد الإشعارات غير المقروءة
  Stream<int> getUnreadNotificationsCountStream(String driverId) {
    return _datasource.getUnreadNotificationsCountStream(driverId);
  }

  /// قبول الطلب ذرياً
  Future<bool> acceptRideAtomic({
    required String requestId,
    required String driverId,
    required Map<String, dynamic> driverData,
  }) async {
    return await _datasource.acceptRideAtomic(
      requestId: requestId,
      driverId: driverId,
      driverData: driverData,
    );
  }

  /// رفض الطلب
  Future<void> rejectRideForDriver(String requestId, String driverId) async {
    await _datasource.rejectRideForDriver(requestId, driverId);
  }

  /// تحديث حالة الرحلة
  Future<void> updateRideStatus({
    required String requestId,
    required String status,
    required String driverId,
    double? finalFare,
  }) async {
    await _datasource.updateRideStatus(
      requestId: requestId,
      status: status,
      driverId: driverId,
      finalFare: finalFare,
    );
  }

  /// تغيير حالة الاتصال (Online / Offline)
  Future<void> setDriverAvailability(String driverId, DriverAvailability availability) async {
    await _datasource.setDriverAvailability(driverId, availability.toDbString());
  }

  /// تحديث إحداثيات موقع الكابتن
  Future<void> updateDriverLocation({
    required String driverId,
    required double latitude,
    required double longitude,
    required double heading,
  }) async {
    await _datasource.updateDriverLocation(
      driverId: driverId,
      latitude: latitude,
      longitude: longitude,
      heading: heading,
    );
  }

  DriverProfileEntity _mapToDriverProfile(Map<String, dynamic> data) {
    final rawAvailability = data['availability']?.toString();
    final isAvailBool = data['available'] == true;
    final balance = (data['walletBalance'] ?? data['balance'] ?? 0.0);
    final debt = (data['debtAmount'] ?? data['debt'] ?? 0.0);

    return DriverProfileEntity(
      uid: data['uid']?.toString() ?? '',
      name: data['name']?.toString() ?? data['fullName']?.toString() ?? 'كابتن مدار',
      phone: data['phone']?.toString() ?? '',
      carNumber: data['carNumber']?.toString() ?? '',
      carType: data['carType']?.toString() ?? '',
      carModel: data['carModel']?.toString() ?? '',
      carColor: data['carColor']?.toString() ?? '',
      photoUrl: data['photoUrl']?.toString() ?? data['profileImage']?.toString(),
      availability: DriverAvailability.fromString(rawAvailability),
      available: isAvailBool,
      rating: (data['rating'] is num) ? (data['rating'] as num).toDouble() : 5.0,
      totalTrips: (data['totalTrips'] is int) ? data['totalTrips'] as int : 0,
      walletBalance: (balance is num) ? balance.toDouble() : 0.0,
      debtAmount: (debt is num) ? debt.toDouble() : 0.0,
      rawData: Map.unmodifiable(data),
    );
  }

  RideRequestEntity _mapToRideRequest(Map<String, dynamic> data) {
    final price = (data['estimatedPrice'] ?? data['price'] ?? data['fare'] ?? data['estimatedFare'] ?? 0);
    final dist = (data['distanceKm'] ?? data['distance'] ?? 0);
    final rejectedList = <String>[];
    if (data['rejectedDrivers'] is List) {
      rejectedList.addAll((data['rejectedDrivers'] as List).map((e) => e.toString()));
    }

    final rawCreatedAt = data['createdAt'] ?? data['timestamp'];
    DateTime? createdAt;
    if (rawCreatedAt is Timestamp) createdAt = rawCreatedAt.toDate();
    if (rawCreatedAt is DateTime) createdAt = rawCreatedAt;

    return RideRequestEntity(
      id: data['id']?.toString() ?? '',
      passengerId: data['userId']?.toString() ?? data['passengerId']?.toString(),
      passengerName: data['userName']?.toString() ?? data['passengerName']?.toString() ?? 'راكب مدار',
      passengerPhone: data['userPhone']?.toString() ?? data['passengerPhone']?.toString() ?? '',
      pickupAddress: data['pickupAddress']?.toString() ?? 'موقع الانطلاق',
      pickupLat: (data['pickupLat'] is num) ? (data['pickupLat'] as num).toDouble() : 0.0,
      pickupLng: (data['pickupLng'] is num) ? (data['pickupLng'] as num).toDouble() : 0.0,
      destinationAddress: data['destinationAddress']?.toString() ?? 'الوجهة',
      destinationLat: (data['destinationLat'] is num) ? (data['destinationLat'] as num).toDouble() : 0.0,
      destinationLng: (data['destinationLng'] is num) ? (data['destinationLng'] as num).toDouble() : 0.0,
      estimatedFare: (price is num) ? price.toDouble() : 0.0,
      distanceKm: (dist is num) ? dist.toDouble() : 0.0,
      status: RideStatus.fromString(data['status']?.toString()),
      driverId: data['driverId']?.toString(),
      createdAt: createdAt,
      rejectedDrivers: rejectedList,
      rawData: Map.unmodifiable(data),
    );
  }
}
