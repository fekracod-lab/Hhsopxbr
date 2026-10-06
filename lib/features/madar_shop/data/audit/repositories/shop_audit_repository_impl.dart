// تطبيق مستودع سجل التدقيق لمتجر مدار (MADAR SHOP Audit Repository Implementation)
// Data Layer — Production-Grade Firestore Audit Trail & Governance

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../domain/audit/contracts/shop_audit_repository.dart';
import '../../../domain/audit/entities/shop_audit_entry.dart';

class ShopAuditRepositoryImpl implements IShopAuditRepository {
  final FirebaseFirestore _firestore;
  final List<ShopAuditEntry> _localCache = [];

  ShopAuditRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> recordAuditEntry(ShopAuditEntry entry) async {
    _localCache.add(entry);
    try {
      await _firestore
          .collection('stores')
          .doc(entry.businessId)
          .collection('audit_logs')
          .doc(entry.auditId)
          .set({
        'auditId': entry.auditId,
        'businessId': entry.businessId,
        'branchId': entry.branchId,
        'terminalId': entry.terminalId,
        'userId': entry.userId,
        'userName': entry.userName,
        'action': entry.action.name,
        'referenceId': entry.referenceId,
        'timestamp': Timestamp.fromDate(entry.timestamp),
        'reason': entry.reason,
        'metadata': entry.metadata,
      });
    } catch (_) {
      // Non-blocking in offline / local scenarios
    }
  }

  @override
  Future<List<ShopAuditEntry>> getAuditEntries({
    required String businessId,
    required String branchId,
    ShopAuditAction? actionFilter,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('stores')
          .doc(businessId)
          .collection('audit_logs')
          .where('branchId', isEqualTo: branchId)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (actionFilter != null) {
        query = query.where('action', isEqualTo: actionFilter.name);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return ShopAuditEntry(
            auditId: doc.id,
            businessId: businessId,
            branchId: branchId,
            terminalId: data['terminalId']?.toString() ?? '',
            userId: data['userId']?.toString() ?? '',
            userName: data['userName']?.toString() ?? '',
            action: ShopAuditAction.values.firstWhere(
              (a) => a.name == data['action'],
              orElse: () => ShopAuditAction.staffPermissionChanged,
            ),
            referenceId: data['referenceId']?.toString(),
            timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            reason: data['reason']?.toString(),
            metadata: (data['metadata'] as Map<String, dynamic>?) ?? {},
          );
        }).toList();
      }
    } catch (_) {
      // Fallback to local cache
    }

    return _localCache
        .where((e) =>
            e.businessId == businessId &&
            e.branchId == branchId &&
            (actionFilter == null || e.action == actionFilter))
        .take(limit)
        .toList();
  }
}
