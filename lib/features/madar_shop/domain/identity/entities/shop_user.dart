// كيان مستخدم منظومة المتجر (MADAR SHOP User Entity)
// Pure Dart — Zero UI Dependencies

import '../rbac/shop_permission.dart';
import '../rbac/shop_permission_matrix.dart';
import '../rbac/shop_role.dart';

class ShopUser {
  final String userId;
  final String businessId;
  final String fullName;
  final String phone;
  final String email;
  final ShopRole role;
  final List<String> assignedBranchIds;
  final Set<ShopPermission>? customPermissions;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const ShopUser({
    required this.userId,
    required this.businessId,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.role,
    this.assignedBranchIds = const [],
    this.customPermissions,
    this.isActive = true,
    required this.createdAt,
    this.lastLoginAt,
  });

  /// التحقق السريع مما إذا كان المستخدم يملك صلاحية معينة
  bool hasPermission(ShopPermission permission) {
    if (!isActive) return false;
    return ShopPermissionMatrix.hasPermission(
      role: role,
      permission: permission,
      customPermissions: customPermissions,
    );
  }

  /// التحقق مما إذا كان المستخدم يملك حق الوصول إلى فرع محدد
  bool canAccessBranch(String branchId) {
    if (!isActive) return false;
    if (role == ShopRole.owner || role == ShopRole.generalManager) return true;
    return assignedBranchIds.contains(branchId);
  }

  ShopUser copyWith({
    String? userId,
    String? businessId,
    String? fullName,
    String? phone,
    String? email,
    ShopRole? role,
    List<String>? assignedBranchIds,
    Set<ShopPermission>? customPermissions,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return ShopUser(
      userId: userId ?? this.userId,
      businessId: businessId ?? this.businessId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      assignedBranchIds: assignedBranchIds ?? this.assignedBranchIds,
      customPermissions: customPermissions ?? this.customPermissions,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
