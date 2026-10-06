import 'package:cloud_firestore/cloud_firestore.dart';

/// مستودع طلبات مرسال والطرود المنفصل (Mersal Jobs Repository)
/// يستعلم حصرياً من مجموعة mersal_requests فقط دون دمج مع رحلات التكسي أو طلبات المطاعم.
class MersalJobsRepository {
  final FirebaseFirestore _firestore;

  MersalJobsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// دفق جميع طلبات مرسال مع إمكانية الفلترة بالحالة
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMersalJobs({String? status}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('mersal_requests')
        .orderBy('createdAt', descending: true);

    if (status != null && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots();
  }

  /// جلب طلب مرسال محدد
  Future<DocumentSnapshot<Map<String, dynamic>>?> getMersalJob(String jobId) async {
    final doc = await _firestore.collection('mersal_requests').doc(jobId).get();
    if (!doc.exists) return null;
    return doc;
  }

  /// تحديث حالة طلب مرسال
  Future<void> updateMersalJobStatus(String jobId, String newStatus, {Map<String, dynamic>? extraData}) async {
    final payload = <String, dynamic>{
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (extraData != null) {
      payload.addAll(extraData);
    }
    await _firestore.collection('mersal_requests').doc(jobId).update(payload);
  }

  /// دفق عدد طلبات مرسال حسب الحالة
  Stream<int> streamMersalJobsCount({String? status}) {
    Query<Map<String, dynamic>> query = _firestore.collection('mersal_requests');
    if (status != null && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots().map((s) => s.docs.length);
  }
}
