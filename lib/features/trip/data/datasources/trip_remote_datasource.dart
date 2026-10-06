import 'package:cloud_firestore/cloud_firestore.dart';

class TripRemoteDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<Map<String, dynamic>> listenToTrip(String tripId) {
    return _firestore
        .collection('ride_requests')
        .doc(tripId)
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }

  Stream<Map<String, dynamic>> listenToDriver(String driverId) {
    return _firestore
        .collection('drivers')
        .doc(driverId)
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }

  Future<void> updateTripStatus(String tripId, String status) async {
    await _firestore.runTransaction((transaction) async {
      final docRef = _firestore.collection('ride_requests').doc(tripId);
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception("Trip does not exist!");
      }

      // Check for valid transitions if needed here
      transaction.update(docRef, {'status': status});
    });
  }

  Future<void> cancelTrip(String tripId, {String? reason}) async {
    await _firestore.runTransaction((transaction) async {
      final docRef = _firestore.collection('ride_requests').doc(tripId);
      final snapshot = await transaction.get(docRef);

      if (snapshot.exists) {
        final currentStatus = snapshot.data()?['status'];
        if (currentStatus != 'completed' && currentStatus != 'cancelled') {
          transaction.update(docRef, {
            'status': 'cancelled',
            'cancelReason': reason,
            'cancelledAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }

  Future<void> submitDriverRating(String driverId, String tripId, double rating) async {
    await _firestore.runTransaction((transaction) async {
      final driverRef = _firestore.collection('drivers').doc(driverId);
      final driverSnap = await transaction.get(driverRef);

      if (driverSnap.exists) {
        // Atomic update using ratingSum and ratingCount
        transaction.update(driverRef, {
          'ratingSum': FieldValue.increment(rating),
          'ratingCount': FieldValue.increment(1),
        });

        // Mark trip as rated to prevent multiple ratings for same trip
        final tripRef = _firestore.collection('ride_requests').doc(tripId);
        transaction.update(tripRef, {'isRated': true});
      }
    });
  }

  Future<void> completeTrip(String rideId, double rating, String feedback) async {
    await _firestore.runTransaction((transaction) async {
      final tripRef = _firestore.collection('ride_requests').doc(rideId);
      final tripSnap = await transaction.get(tripRef);

      if (tripSnap.exists) {
        final driverId = tripSnap.data()?['driverId'];
        transaction.update(tripRef, {
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });

        if (driverId != null) {
          final driverRef = _firestore.collection('drivers').doc(driverId);
          transaction.update(driverRef, {
            'ratingSum': FieldValue.increment(rating),
            'ratingCount': FieldValue.increment(1),
          });
        }
      }
    });
  }

  Future<String> createRideRequest(Map<String, dynamic> rideData) async {
    final docRef = await _firestore.collection('ride_requests').add(rideData);
    return docRef.id;
  }
}
