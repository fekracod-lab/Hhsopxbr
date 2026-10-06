import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dalal_alqaim/services/user_service.dart';

/// Service for logging critical admin actions and security audit trails
class AuditLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Log an administrative action to Firestore for security audit
  static Future<void> logAction({
    required String action,
    required String targetId,
    required String targetType,
    Map<String, dynamic>? details,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final userService = UserService();

      final logData = {
        'action': action,
        'targetId': targetId,
        'targetType': targetType,
        'adminUid': currentUser?.uid ?? 'unknown',
        'adminName': userService.name,
        'adminRole': userService.roleStr,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : 'mobile',
        'details': details ?? {},
      };

      await _firestore.collection('admin_audit_logs').add(logData);
      debugPrint(' [AuditLog] Action logged: $action on $targetType ($targetId)');
    } catch (e) {
      debugPrint(' [AuditLog Error] Failed to record audit log: $e');
    }
  }

  /// Stream of audit logs for Admin Web Monitoring
  static Stream<QuerySnapshot<Map<String, dynamic>>> getAuditLogsStream({int limit = 50}) {
    return _firestore
        .collection('admin_audit_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }
}
