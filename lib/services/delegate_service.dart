import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/delegate_request.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

class DelegateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionPath = 'delegate_requests';

  Future<String> createRequest(DelegateRequest request) async {
    final docRef = await _firestore.collection(collectionPath).add(request.toMap());
    return docRef.id;
  }

  Stream<List<DelegateRequest>> getPendingRequestsStream() {
    return _firestore
        .collection(collectionPath)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          final list = snapshot.docs
              .map((doc) => DelegateRequest.fromMap(doc.data(), doc.id))
              .where((req) => now.difference(req.createdAt).inMinutes < 30)
              .toList();
          // Sort client-side to avoid composite index requirement
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<DelegateRequest?> getRequestStream(String requestId) {
    return _firestore.collection(collectionPath).doc(requestId).snapshots().map((doc) {
      if (doc.exists) {
        return DelegateRequest.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  Future<bool> acceptRequest({
    required String requestId,
    required String driverId,
    required Map<String, dynamic> driverData,
  }) async {
    final reqRef = _firestore.collection(collectionPath).doc(requestId);
    final driverRef = _firestore.collection('drivers').doc(driverId);
    final userRef = _firestore.collection('users').doc(driverId);

    try {
      return await _firestore
          .runTransaction<bool>((tx) async {
            final snap = await tx.get(reqRef);
            if (!snap.exists) return false;

            final status = (snap.data() ?? {})['status'] as String? ?? 'pending';
            if (status != 'pending') return false;

            // تحديث الطلب
            tx.update(reqRef, {
              'status': 'accepted',
              'driverId': driverId,
              'driverName': driverData['name'] ?? 'كابتن',
              'driverPhone': driverData['phone'] ?? '',
              'driverImage': driverData['imageUrl'] ?? '',
              'acceptedAt': FieldValue.serverTimestamp(),
            });

            // تحديث السائق: يبقى متصل ولكنه غير متاح لاستلام طلبات جديدة حالياً
            final Map<String, dynamic> driverStatusUpdates = {
              'available': false,
              'onTripSince': FieldValue.serverTimestamp(),
              'lastStatusUpdate': FieldValue.serverTimestamp(),
            };

            tx.update(driverRef, driverStatusUpdates);
            tx.update(userRef, driverStatusUpdates);

            return true;
          })
          .then((result) async {
            if (result == true) {
              // Emit Event to Server
              await NotificationService.emitEvent(
                type: 'delegate_status_updated',
                payload: {'request_id': requestId, 'status': 'accepted'},
              );
            }
            return result;
          });
    } catch (e) {
      debugPrint('Error accepting delegate request: $e');
      return false;
    }
  }

  Future<void> updateStatus(String requestId, String status) async {
    final docRef = _firestore.collection(collectionPath).doc(requestId);

    await _firestore.runTransaction((tx) async {
      // 1. ALL READS FIRST
      final snap = await tx.get(docRef);
      if (!snap.exists) return;

      final data = snap.data() ?? {};
      final driverId = data['driverId'] as String?;

      // حالات انتهاء الرحلة
      const terminalStatuses = {'completed', 'cancelled'};

      final DocumentReference? driverRef = driverId != null ? _firestore.collection('drivers').doc(driverId) : null;
      DocumentSnapshot? driverSnap;
      if (driverRef != null && terminalStatuses.contains(status)) {
        driverSnap = await tx.get(driverRef);
      }

      // 2. PREPARE ALL MUTATIONS
      final Map<String, dynamic> resetStatus = {};
      if (driverId != null && terminalStatuses.contains(status)) {
        final driverData = (driverSnap != null && driverSnap.exists) 
            ? driverSnap.data() as Map<String, dynamic>? ?? {} 
            : {};
        final bool isOnlineMode = (driverData['availability'] ?? 'offline') == 'online';

        resetStatus['available'] = isOnlineMode;
        resetStatus['onTripSince'] = FieldValue.delete();
        resetStatus['lastStatusUpdate'] = FieldValue.serverTimestamp();
      }

      // 3. ALL WRITES AFTER ALL READS
      tx.update(docRef, {'status': status, 'updatedAt': FieldValue.serverTimestamp()});

      if (driverRef != null && resetStatus.isNotEmpty) {
        final userRef = _firestore.collection('users').doc(driverId);
        tx.update(driverRef, resetStatus);
        tx.update(userRef, resetStatus);
      }
    });

    // Emit Event to Server
    await NotificationService.emitEvent(
      type: 'delegate_status_updated',
      payload: {'request_id': requestId, 'status': status},
    );
  }

  Stream<List<DelegateRequest>> getUserRequestsStream(String userId) {
    return _firestore.collection(collectionPath).where('userId', isEqualTo: userId).snapshots().map(
      (snapshot) {
        final list =
            snapshot.docs.map((doc) => DelegateRequest.fromMap(doc.data(), doc.id)).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      },
    );
  }

  Stream<List<DelegateRequest>> getDriverActiveOrders(String driverId) {
    return _firestore
        .collection(collectionPath)
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['accepted', 'arrived_at_pickup', 'on_the_way', 'picked_up'])
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => DelegateRequest.fromMap(doc.data(), doc.id)).toList();
        });
  }

  Stream<List<DelegateRequest>> getDriverHistoryStream(String driverId) {
    return _firestore
        .collection(collectionPath)
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'completed')
        // Removed orderBy and limit to avoid index issues.
        // For history, fetching all and sorting locally is fine for reasonable dataset sizes.
        .snapshots()
        .map((snapshot) {
          final list =
              snapshot.docs.map((doc) => DelegateRequest.fromMap(doc.data(), doc.id)).toList();
          list.sort(
            // Sort client-side using createdAt as a fallback or if acceptedAt is missing from model getter
            (a, b) => b.createdAt.compareTo(a.createdAt),
          );
          return list;
        });
  }

  Stream<Map<String, dynamic>> getDriverDailyStatsStream(String driverId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return _firestore
        .collection(collectionPath)
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((snapshot) {
          double totalEarnings = 0;
          int count = 0;

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate() ?? 
                              (data['createdAt'] as Timestamp?)?.toDate();
            if (updatedAt != null && updatedAt.isAfter(startOfDay)) {
              count++;
              double p = (data['price'] ?? 0.0).toDouble();
              totalEarnings += p;
            }
          }

          return {'count': count, 'earnings': totalEarnings};
        });
  }

  // Helper helper to format start date to Timestamp securely
  Timestamp startOfDateForQuery(DateTime date) => Timestamp.fromDate(date);

  Future<int> getDriverTotalTrips(String driverId) async {
    try {
      final query = await _firestore
          .collection(collectionPath)
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'completed')
          .get();
      return query.docs.length;
    } catch (e) {
      debugPrint('Error getting driver total delegate trips: $e');
      return 0;
    }
  }

  Future<List<double>> getDriverWeeklyChartData(String driverId) async {
    List<double> dailyEarnings = List.filled(7, 0.0);
    final now = DateTime.now();

    try {
      for (int i = 0; i < 7; i++) {
        final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        final startOfDate = Timestamp.fromDate(date);
        final endOfDate = Timestamp.fromDate(date.add(const Duration(days: 1)));

        final query = await _firestore
            .collection(collectionPath)
            .where('driverId', isEqualTo: driverId)
            .where('status', isEqualTo: 'completed')
            .where('updatedAt', isGreaterThanOrEqualTo: startOfDate)
            .where('updatedAt', isLessThan: endOfDate)
            .get();

        double dayTotal = 0.0;
        for (var doc in query.docs) {
          final data = doc.data();
          double p = (data['price'] ?? 0.0).toDouble();
          dayTotal += p;
        }
        dailyEarnings[6 - i] = dayTotal;
      }
    } catch (e) {
      debugPrint('Error getting driver delegate weekly chart: $e');
    }
    return dailyEarnings;
  }
}
