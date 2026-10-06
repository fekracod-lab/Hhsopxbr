// مصدر بيانات إدارة رحلات التكسي عن بُعد (Taxi Ride Management Remote Datasource)
// Clean Architecture — Data Layer: Firestore Integration & Cloud Operations

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/services/driver_service.dart';

class RideManagementRemoteDatasource {
  final FirebaseFirestore? _firestoreInstance;
  final DriverService? _driverServiceInstance;

  FirebaseFirestore get _firestore => _firestoreInstance ?? FirebaseFirestore.instance;
  DriverService get _driverService => _driverServiceInstance ?? DriverService();

  RideManagementRemoteDatasource({
    FirebaseFirestore? firestore,
    DriverService? driverService,
  }) : _firestoreInstance = firestore,
        _driverServiceInstance = driverService;

  /// تدفق الكباتن النشطين فقط (تاكسي حصراً)
  Stream<List<Map<String, dynamic>>> watchActiveDrivers() {
    return _firestore
        .collection('drivers')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) {
            final data = doc.data();
            return data['subRole'] != 'delivery' &&
                data['type'] != 'delivery' &&
                data['isDelivery'] != true;
          })
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            return data;
          })
          .toList();
    });
  }

  /// تدفق كافة الكباتن المسجلين (تاكسي حصراً)
  Stream<List<Map<String, dynamic>>> watchAllDrivers() {
    return _firestore.collection('drivers').snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) {
            final data = doc.data();
            return data['subRole'] != 'delivery' &&
                data['type'] != 'delivery' &&
                data['isDelivery'] != true;
          })
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            return data;
          })
          .toList();
    });
  }

  /// تدفق كافة طلبات الرحلات الحية
  Stream<List<Map<String, dynamic>>> watchAllRideRequests() {
    return _firestore.collection('ride_requests').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// تدفق الرحلات النشطة للرادار (searching, accepted, arrived, in_progress)
  Stream<List<Map<String, dynamic>>> watchActiveRideRequests() {
    return _firestore
        .collection('ride_requests')
        .where('status', whereIn: ['searching', 'accepted', 'arrived', 'in_progress'])
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// تدفق الرحلات حسب الفلتر
  Stream<List<Map<String, dynamic>>> watchFilteredRideRequests(String statusFilter) {
    Query query = _firestore.collection('ride_requests');
    if (statusFilter != 'all') {
      query = query.where('status', isEqualTo: statusFilter);
    }
    return query
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// تدفق سجل الرحلات المكتملة
  Stream<List<Map<String, dynamic>>> watchCompletedRidesHistory() {
    return _firestore
        .collection('ride_requests')
        .where('status', isEqualTo: 'completed')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// تدفق التقييمات والآراء
  Stream<List<Map<String, dynamic>>> watchAllReviews() {
    return _driverService.getAllReviewsStream().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// إلغاء الرحلة إدارياً
  Future<void> cancelRide({
    required String rideId,
    String? reason,
  }) async {
    await _firestore.collection('ride_requests').doc(rideId).update({
      'status': 'cancelled',
      'cancelledBy': 'admin',
      'cancelledAt': FieldValue.serverTimestamp(),
      if (reason != null && reason.isNotEmpty) 'cancelReason': reason,
    });
  }

  /// تعيين كابتن للرحلة إدارياً
  Future<void> assignDriverToRide({
    required String rideId,
    required String driverId,
    required String driverName,
    required String driverPhone,
    required String driverCar,
  }) async {
    await _firestore.collection('ride_requests').doc(rideId).update({
      'status': 'accepted',
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'driverCar': driverCar,
      'assignedByAdmin': true,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  /// تفعيل/إلغاء استثناء مديونية الكابتن
  Future<void> toggleDriverCommissionException({
    required String driverId,
    required bool allowException,
  }) async {
    await _driverService.toggleDriverCommissionException(
      driverId: driverId,
      allowException: allowException,
    );
  }

  /// تصفير محفظة الكابتن بالكامل
  Future<void> resetDriverWalletCompletely({
    required String driverId,
    String? reason,
  }) async {
    await _driverService.resetDriverWalletCompletely(
      driverId: driverId,
      reason: reason ?? 'تصفير شامل وفك القفل من قبل الإدارة',
    );
  }

  /// تسوية جزء من عمولة الكابتن
  Future<void> settleDriverCommission({
    required String driverId,
    required double amountPaid,
    String? adminNotes,
  }) async {
    await _driverService.settleDriverCommission(
      driverId: driverId,
      amountPaid: amountPaid,
      adminNotes: adminNotes,
    );
  }

  /// تعديل سقف مديونية الكابتن
  Future<void> updateDriverCommissionLimit({
    required String driverId,
    required double newLimit,
  }) async {
    await _driverService.updateDriverCommissionLimit(
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
  }) async {
    await _driverService.sendAdminReviewAction(
      reviewId: reviewId,
      driverId: driverId,
      actionType: actionType,
      note: note,
    );
  }
}
