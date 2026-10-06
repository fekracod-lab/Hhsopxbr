// مستودع الهوية والجلسات المعتمد على Firebase (MADAR SHOP Firebase Identity Repository)
// Data Layer — Production-Grade Firebase Auth + Firestore RBAC & Multi-Branch Binding

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../domain/identity/contracts/i_shop_identity_repository.dart';
import '../../../domain/identity/entities/shop_branch.dart';
import '../../../domain/identity/entities/shop_business.dart';
import '../../../domain/identity/entities/shop_session.dart';
import '../../../domain/identity/entities/shop_user.dart';
import '../../../domain/identity/rbac/shop_permission.dart';
import '../../../domain/identity/rbac/shop_role.dart';

class FirebaseShopIdentityRepository implements IShopIdentityRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  FirebaseShopIdentityRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<ShopUser?> getUserByCredentials({
    required String loginIdentifier,
    required String secret,
  }) async {
    final identifier = loginIdentifier.trim();
    // 1. التحقق الفعلي عبر Firebase Auth (بدون أي حسابات تجريبية أو كلمات مرور ثابتة)
    final email = identifier.contains('@') ? identifier : '$identifier@madar.iq';

    final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: secret,
    );

    final fbUser = userCredential.user;
    if (fbUser == null) return null;

    // 2. جلب الملف التعريفي وعضوية المتجر من Firestore
    return await getUserById(fbUser.uid);
  }

  @override
  Future<ShopUser?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data() ?? {};

      final roleStr = data['role']?.toString();
      final role = ShopRole.fromString(roleStr);

      final businessId = data['businessId']?.toString() ?? data['storeId']?.toString() ?? '';
      final branchList = (data['assignedBranchIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (data['branches'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          <String>[];

      final customPerms = (data['customPermissions'] as List<dynamic>?)
          ?.map((e) => ShopPermission.values.firstWhere(
                (p) => p.name == e.toString() || p.toString() == e.toString(),
                orElse: () => ShopPermission.accessPos,
              ))
          .toSet();

      final createdAtRaw = data['createdAt'];
      final createdAt = createdAtRaw is Timestamp
          ? createdAtRaw.toDate()
          : (createdAtRaw is String ? DateTime.tryParse(createdAtRaw) ?? DateTime.now() : DateTime.now());

      return ShopUser(
        userId: userId,
        businessId: businessId,
        fullName: data['fullName']?.toString() ?? data['name']?.toString() ?? 'Shop Employee',
        phone: data['phone']?.toString() ?? '',
        email: data['email']?.toString() ?? '',
        role: role,
        customPermissions: customPerms,
        isActive: data['isActive'] == true || data['status'] == 'active',
        assignedBranchIds: branchList,
        createdAt: createdAt,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ShopBusiness?> getBusinessById(String businessId) async {
    try {
      final doc = await _firestore.collection('stores').doc(businessId).get();
      if (!doc.exists) return null;
      final data = doc.data() ?? {};

      return ShopBusiness(
        businessId: businessId,
        tradeName: data['name']?.toString() ?? data['tradeName']?.toString() ?? 'Store',
        legalName: data['legalName']?.toString() ?? data['name']?.toString() ?? 'Store LLC',
        phone: data['phone']?.toString() ?? '',
        email: data['email']?.toString() ?? '',
        taxNumber: data['taxNumber']?.toString(),
        defaultCurrency: data['currency']?.toString() ?? 'IQD',
        isActive: data['isActive'] != false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ShopBranch?> getBranchById({
    required String businessId,
    required String branchId,
  }) async {
    try {
      final doc = await _firestore
          .collection('stores')
          .doc(businessId)
          .collection('branches')
          .doc(branchId)
          .get();
      if (!doc.exists) return null;
      final data = doc.data() ?? {};

      return ShopBranch(
        branchId: branchId,
        businessId: businessId,
        name: data['name']?.toString() ?? 'Branch',
        code: data['code']?.toString() ?? branchId,
        address: data['address']?.toString() ?? '',
        phone: data['phone']?.toString() ?? '',
        isMainBranch: data['isMainBranch'] == true,
        isActive: data['isActive'] != false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveUser(ShopUser user) async {
    await _firestore.collection('users').doc(user.userId).set({
      'businessId': user.businessId,
      'fullName': user.fullName,
      'phone': user.phone,
      'email': user.email,
      'role': user.role.toDbString(),
      'isActive': user.isActive,
      'assignedBranchIds': user.assignedBranchIds,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> saveSession(ShopSession session) async {
    await _firestore
        .collection('stores')
        .doc(session.businessId)
        .collection('sessions')
        .doc(session.sessionId)
        .set({
      'sessionId': session.sessionId,
      'userId': session.userId,
      'branchId': session.activeBranchId,
      'terminalId': session.terminalId,
      'installationId': session.installationId,
      'startedAt': Timestamp.fromDate(session.startedAt),
      'expiresAt': Timestamp.fromDate(session.expiresAt),
      'status': session.status.name,
    }, SetOptions(merge: true));
  }

  @override
  Future<ShopSession?> getSession(String sessionId) async {
    try {
      final query = await _firestore
          .collectionGroup('sessions')
          .where('sessionId', isEqualTo: sessionId)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      final data = query.docs.first.data();

      return ShopSession(
        sessionId: sessionId,
        installationId: data['installationId']?.toString() ?? '',
        terminalId: data['terminalId']?.toString() ?? '',
        userId: data['userId']?.toString() ?? '',
        businessId: data['businessId']?.toString() ?? '',
        activeBranchId: data['branchId']?.toString() ?? '',
        startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        lastHeartbeatAt: DateTime.now(),
        expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 12)),
        status: ShopSessionStatus.values.firstWhere(
          (s) => s.name == data['status'],
          orElse: () => ShopSessionStatus.active,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> terminateSession(String sessionId) async {
    try {
      final query = await _firestore
          .collectionGroup('sessions')
          .where('sessionId', isEqualTo: sessionId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({
          'status': ShopSessionStatus.terminated.name,
          'terminatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }
}
