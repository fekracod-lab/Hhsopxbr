import 'package:cloud_firestore/cloud_firestore.dart';
import '../entities/security_event.dart';
import '../entities/security_readiness_result.dart';

/// مصدر البيانات السحابي لسجلات ونتائج الأمان (Security Remote Datasource)
class SecurityRemoteDatasource {
  final FirebaseFirestore? firestore;

  const SecurityRemoteDatasource({this.firestore});

  Future<void> persistSecurityEvent(SecurityEventRecord event) async {
    if (firestore == null) return;
    await firestore!.collection('security_events').doc(event.eventId).set(event.toMap());
  }

  Future<void> persistReadinessAudit(SecurityReadinessResult result) async {
    if (firestore == null) return;
    await firestore!.collection('security_readiness_audits').doc(result.auditId).set(result.toMap());
  }
}
