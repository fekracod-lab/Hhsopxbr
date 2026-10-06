import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/pricing_policy.dart';
import '../../domain/entities/pricing_snapshot.dart';
import '../../domain/enums/pricing_enums.dart';

/// مصدر البيانات البعيد لسياسات ولقطات التسعير (Pricing Remote Datasource)
class PricingRemoteDatasource {
  final FirebaseFirestore? _customFirestore;

  PricingRemoteDatasource({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  /// جلب سياسة التسعير الفعالة مع Fallback حتمي
  Future<PricingPolicy> getActivePolicy(PricingServiceType serviceType) async {
    try {
      final doc = await _firestore
          .collection('pricing_policies')
          .doc(serviceType.key)
          .get();

      if (doc.exists && doc.data() != null) {
        return PricingPolicy.fromMap(doc.data()!, doc.id);
      }
    } catch (_) {
      // Fallback to default in-memory policy
    }

    switch (serviceType) {
      case PricingServiceType.taxi:
        return PricingPolicy.defaultTaxiPolicy;
      case PricingServiceType.food:
        return PricingPolicy.defaultFoodPolicy;
      case PricingServiceType.store:
        return PricingPolicy.defaultStorePolicy;
      case PricingServiceType.mersal:
        return PricingPolicy.defaultMersalPolicy;
    }
  }

  /// حفظ لقطة تسعير في فايرستور
  Future<PricingSnapshot> saveSnapshot(PricingSnapshot snapshot) async {
    final docRef = _firestore.collection('pricing_snapshots').doc(snapshot.snapshotId);
    await docRef.set(snapshot.toMap());
    return snapshot;
  }

  /// جلب لقطة تسعير سابقة
  Future<PricingSnapshot?> getSnapshot(String snapshotId) async {
    final doc = await _firestore.collection('pricing_snapshots').doc(snapshotId).get();
    if (!doc.exists || doc.data() == null) return null;
    return PricingSnapshot.fromMap(doc.data()!, doc.id);
  }

  /// التحقق من مفتاح عدم التكرار
  Future<bool> verifyIdempotencyKey(String idempotencyKey) async {
    final docRef = _firestore.collection('idempotency_keys').doc(idempotencyKey);
    final doc = await docRef.get();
    if (doc.exists) {
      return false;
    }
    await docRef.set({
      'key': idempotencyKey,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return true;
  }
}
