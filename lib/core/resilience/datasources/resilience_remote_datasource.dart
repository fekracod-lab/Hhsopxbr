import 'package:cloud_firestore/cloud_firestore.dart';
import '../entities/recovery_checkpoint.dart';
import '../entities/circuit_breaker_record.dart';
import '../entities/integrity_violation.dart';
import '../entities/disaster_recovery_snapshot.dart';
import '../entities/production_readiness_result.dart';

/// مصدر البيانات البعيد للصمود والتعافي (Resilience Remote DataSource - Firestore)
class ResilienceRemoteDatasource {
  final FirebaseFirestore? _firestore;

  ResilienceRemoteDatasource({FirebaseFirestore? firestore})
      : _firestore = firestore;

  Future<void> saveCheckpoint(RecoveryCheckpoint checkpoint) async {
    if (_firestore == null) return;
    await _firestore
        .collection('resilience_checkpoints')
        .doc(checkpoint.operationId)
        .set(checkpoint.toMap(), SetOptions(merge: true));
  }

  Future<RecoveryCheckpoint?> getCheckpoint(String operationId) async {
    if (_firestore == null) return null;
    final doc = await _firestore.collection('resilience_checkpoints').doc(operationId).get();
    if (!doc.exists || doc.data() == null) return null;
    return RecoveryCheckpoint.fromMap(doc.data()!, doc.id);
  }

  Future<void> saveCircuitBreaker(CircuitBreakerRecord breaker) async {
    if (_firestore == null) return;
    await _firestore
        .collection('circuit_breakers')
        .doc(breaker.serviceKey)
        .set(breaker.toMap(), SetOptions(merge: true));
  }

  Future<CircuitBreakerRecord?> getCircuitBreaker(String serviceKey) async {
    if (_firestore == null) return null;
    final doc = await _firestore.collection('circuit_breakers').doc(serviceKey).get();
    if (!doc.exists || doc.data() == null) return null;
    return CircuitBreakerRecord.fromMap(doc.data()!, doc.id);
  }

  Future<void> saveIntegrityViolation(IntegrityViolation violation) async {
    if (_firestore == null) return;
    await _firestore
        .collection('integrity_violations')
        .doc(violation.violationId)
        .set(violation.toMap(), SetOptions(merge: true));
  }

  Future<List<IntegrityViolation>> getIntegrityViolations() async {
    if (_firestore == null) return [];
    final snap = await _firestore.collection('integrity_violations').get();
    return snap.docs
        .map((doc) => IntegrityViolation.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> saveDisasterRecoverySnapshot(DisasterRecoverySnapshot snapshot) async {
    if (_firestore == null) return;
    await _firestore
        .collection('disaster_recovery_snapshots')
        .doc(snapshot.snapshotId)
        .set(snapshot.toMap(), SetOptions(merge: true));
  }

  Future<DisasterRecoverySnapshot?> getLatestDisasterRecoverySnapshot(String domain) async {
    if (_firestore == null) return null;
    final snap = await _firestore
        .collection('disaster_recovery_snapshots')
        .where('domain', isEqualTo: domain)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return DisasterRecoverySnapshot.fromMap(doc.data(), doc.id);
  }

  Future<void> saveProductionReadinessResult(ProductionReadinessResult result) async {
    if (_firestore == null) return;
    await _firestore
        .collection('production_readiness_audits')
        .doc('latest')
        .set(result.toMap(), SetOptions(merge: true));
  }

  Future<ProductionReadinessResult?> getLatestProductionReadinessResult() async {
    if (_firestore == null) return null;
    final doc = await _firestore.collection('production_readiness_audits').doc('latest').get();
    if (!doc.exists || doc.data() == null) return null;
    return ProductionReadinessResult.fromMap(doc.data()!);
  }
}
