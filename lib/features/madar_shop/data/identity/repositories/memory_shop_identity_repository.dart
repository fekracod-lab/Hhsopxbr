// مستودع الهوية والجلسات في الذاكرة (MADAR SHOP Memory Identity Repository)
// Data Layer — Fast & Deterministic Persistence for Windows/POS local operations

import '../../../domain/identity/contracts/i_shop_identity_repository.dart';
import '../../../domain/identity/entities/shop_branch.dart';
import '../../../domain/identity/entities/shop_business.dart';
import '../../../domain/identity/entities/shop_session.dart';
import '../../../domain/identity/entities/shop_user.dart';

class MemoryShopIdentityRepository implements IShopIdentityRepository {
  final Map<String, ShopUser> _users = {};
  final Map<String, String> _credentials = {}; // loginIdentifier -> secret
  final Map<String, String> _identifierToUserId = {}; // loginIdentifier -> userId
  final Map<String, ShopBusiness> _businesses = {};
  final Map<String, List<ShopBranch>> _branches = {}; // businessId -> branches
  final Map<String, ShopSession> _sessions = {};

  /// تهيئة مستخدم مع بيانات اعتماده
  void seedUser({
    required ShopUser user,
    required String loginIdentifier,
    required String secret,
  }) {
    _users[user.userId] = user;
    final normalized = loginIdentifier.trim().toLowerCase();
    _credentials[normalized] = secret;
    _identifierToUserId[normalized] = user.userId;
  }

  /// تهيئة نشاط تجاري وفروعه
  void seedBusiness({
    required ShopBusiness business,
    List<ShopBranch> branches = const [],
  }) {
    _businesses[business.businessId] = business;
    _branches[business.businessId] = List.from(branches);
  }

  @override
  Future<ShopUser?> getUserByCredentials({
    required String loginIdentifier,
    required String secret,
  }) async {
    final normalized = loginIdentifier.trim().toLowerCase();
    final expectedSecret = _credentials[normalized];
    if (expectedSecret == null || expectedSecret != secret) {
      return null;
    }
    final userId = _identifierToUserId[normalized];
    if (userId == null) return null;
    return _users[userId];
  }

  @override
  Future<ShopUser?> getUserById(String userId) async {
    return _users[userId];
  }

  @override
  Future<ShopBusiness?> getBusinessById(String businessId) async {
    return _businesses[businessId];
  }

  @override
  Future<ShopBranch?> getBranchById({
    required String businessId,
    required String branchId,
  }) async {
    final list = _branches[businessId];
    if (list == null) return null;
    for (final b in list) {
      if (b.branchId == branchId) return b;
    }
    return null;
  }

  @override
  Future<void> saveUser(ShopUser user) async {
    _users[user.userId] = user;
  }

  @override
  Future<void> saveSession(ShopSession session) async {
    _sessions[session.sessionId] = session;
  }

  @override
  Future<ShopSession?> getSession(String sessionId) async {
    return _sessions[sessionId];
  }

  @override
  Future<void> terminateSession(String sessionId) async {
    final s = _sessions[sessionId];
    if (s != null) {
      _sessions[sessionId] = s.copyWith(status: ShopSessionStatus.terminated);
    }
  }

  void clear() {
    _users.clear();
    _credentials.clear();
    _identifierToUserId.clear();
    _businesses.clear();
    _branches.clear();
    _sessions.clear();
  }
}
