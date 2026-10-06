import 'package:flutter/foundation.dart';
import '../domain/entities/security_models.dart';
import 'permission.dart';

/// تعريف الدور والصلاحيات المرتبطة به (Role Definition Entity)
@immutable
class RoleDefinition {
  final MadarRole role;
  final String title;
  final int hierarchyLevel;
  final Set<String> permissions;

  const RoleDefinition({
    required this.role,
    required this.title,
    required this.hierarchyLevel,
    required this.permissions,
  });

  bool hasPermission(String permissionKey) {
    if (role == MadarRole.superAdmin || role == MadarRole.mainAdmin) {
      return true; // Super admin has universal access
    }
    return permissions.contains(permissionKey);
  }

  bool canManageRole(MadarRole targetRole) {
    if (role == MadarRole.superAdmin || role == MadarRole.mainAdmin) {
      return true;
    }
    final targetDef = defaultRoles[targetRole];
    if (targetDef == null) return false;
    return hierarchyLevel > targetDef.hierarchyLevel;
  }

  // Pre-configured Enterprise Role Hierarchy & Capability Matrix
  static final Map<MadarRole, RoleDefinition> defaultRoles = {
    MadarRole.superAdmin: RoleDefinition(
      role: MadarRole.superAdmin,
      title: 'مدير النظام الأعلى (Super Admin)',
      hierarchyLevel: 100,
      permissions: {for (var p in GranularPermission.all) p.key},
    ),
    MadarRole.mainAdmin: RoleDefinition(
      role: MadarRole.mainAdmin,
      title: 'المدير العام (Main Admin)',
      hierarchyLevel: 90,
      permissions: {for (var p in GranularPermission.all) p.key},
    ),
    MadarRole.admin: const RoleDefinition(
      role: MadarRole.admin,
      title: 'مدير تشغيلي (Admin)',
      hierarchyLevel: 80,
      permissions: {
        'users.read', 'users.update',
        'drivers.read', 'drivers.update', 'drivers.assign',
        'orders.read', 'orders.update', 'orders.cancel',
        'wallet.read', 'wallet.credit',
        'refund.create', 'refund.approve',
        'merchant.manage', 'admin.manage', 'audit.read',
      },
    ),
    MadarRole.complaintsAdmin: const RoleDefinition(
      role: MadarRole.complaintsAdmin,
      title: 'مسؤول الشكاوى والدعم (Support & Complaints)',
      hierarchyLevel: 50,
      permissions: {
        'users.read', 'drivers.read', 'orders.read', 'wallet.read', 'refund.create', 'audit.read',
      },
    ),
    MadarRole.limitedAdmin: const RoleDefinition(
      role: MadarRole.limitedAdmin,
      title: 'مدير بمهام محددة (Limited Admin)',
      hierarchyLevel: 40,
      permissions: {
        'drivers.read', 'orders.read', 'orders.update',
      },
    ),
    MadarRole.merchant: const RoleDefinition(
      role: MadarRole.merchant,
      title: 'شريك المتجر/المطعم (Merchant)',
      hierarchyLevel: 20,
      permissions: {
        'orders.read', 'orders.update', 'merchant.manage', 'wallet.read',
      },
    ),
    MadarRole.store: const RoleDefinition(
      role: MadarRole.store,
      title: 'متجر (Store)',
      hierarchyLevel: 20,
      permissions: {
        'orders.read', 'orders.update', 'merchant.manage', 'wallet.read',
      },
    ),
    MadarRole.restaurant: const RoleDefinition(
      role: MadarRole.restaurant,
      title: 'مطعم (Restaurant)',
      hierarchyLevel: 20,
      permissions: {
        'orders.read', 'orders.update', 'merchant.manage', 'wallet.read',
      },
    ),
    MadarRole.driver: const RoleDefinition(
      role: MadarRole.driver,
      title: 'كابتن وسائق (Driver)',
      hierarchyLevel: 10,
      permissions: {
        'orders.read', 'orders.update', 'wallet.read',
      },
    ),
    MadarRole.taxiCaptain: const RoleDefinition(
      role: MadarRole.taxiCaptain,
      title: 'كابتن تكسي (Taxi Captain)',
      hierarchyLevel: 10,
      permissions: {
        'orders.read', 'orders.update', 'wallet.read',
      },
    ),
    MadarRole.delivery: const RoleDefinition(
      role: MadarRole.delivery,
      title: 'مندوب توصيل (Delivery)',
      hierarchyLevel: 10,
      permissions: {
        'orders.read', 'orders.update', 'wallet.read',
      },
    ),
    MadarRole.deliveryCaptain: const RoleDefinition(
      role: MadarRole.deliveryCaptain,
      title: 'كابتن توصيل (Delivery Captain)',
      hierarchyLevel: 10,
      permissions: {
        'orders.read', 'orders.update', 'wallet.read',
      },
    ),
    MadarRole.customer: const RoleDefinition(
      role: MadarRole.customer,
      title: 'عميل (Customer)',
      hierarchyLevel: 1,
      permissions: {
        'orders.read', 'orders.create', 'orders.cancel', 'wallet.read', 'refund.create',
      },
    ),
  };
}
