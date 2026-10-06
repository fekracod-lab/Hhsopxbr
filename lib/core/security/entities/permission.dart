import 'package:flutter/foundation.dart';

/// كيان الصلاحية الدقيقة (Granular Permission Entity)
@immutable
class GranularPermission {
  final String key;
  final String resource;
  final String action;
  final String description;

  const GranularPermission({
    required this.key,
    required this.resource,
    required this.action,
    required this.description,
  });

  // Standard Granular Permissions in MADAR
  static const usersRead = GranularPermission(key: 'users.read', resource: 'users', action: 'read', description: 'قراءة بيانات المستخدمين');
  static const usersUpdate = GranularPermission(key: 'users.update', resource: 'users', action: 'update', description: 'تعديل بيانات المستخدمين');
  static const usersDelete = GranularPermission(key: 'users.delete', resource: 'users', action: 'delete', description: 'حذف أو حظر المستخدمين');

  static const driversRead = GranularPermission(key: 'drivers.read', resource: 'drivers', action: 'read', description: 'قراءة بيانات وسجلات السائقين');
  static const driversUpdate = GranularPermission(key: 'drivers.update', resource: 'drivers', action: 'update', description: 'تعديل وتحديث وثائق السائقين');
  static const driversAssign = GranularPermission(key: 'drivers.assign', resource: 'drivers', action: 'assign', description: 'إسناد الرحلات والطلبات للسائقين');

  static const ordersRead = GranularPermission(key: 'orders.read', resource: 'orders', action: 'read', description: 'قراءة الطلبات');
  static const ordersCreate = GranularPermission(key: 'orders.create', resource: 'orders', action: 'create', description: 'إنشاء طلبات جديدة');
  static const ordersUpdate = GranularPermission(key: 'orders.update', resource: 'orders', action: 'update', description: 'تحديث حالة الطلبات');
  static const ordersCancel = GranularPermission(key: 'orders.cancel', resource: 'orders', action: 'cancel', description: 'إلغاء الطلبات');

  static const walletRead = GranularPermission(key: 'wallet.read', resource: 'wallet', action: 'read', description: 'الاطلاع على رصيد ومعاملات المحفظة');
  static const walletDebit = GranularPermission(key: 'wallet.debit', resource: 'wallet', action: 'debit', description: 'خصم من المحفظة');
  static const walletCredit = GranularPermission(key: 'wallet.credit', resource: 'wallet', action: 'credit', description: 'إيداع وشحن المحفظة');

  static const refundCreate = GranularPermission(key: 'refund.create', resource: 'refund', action: 'create', description: 'طلب استرجاع مالي');
  static const refundApprove = GranularPermission(key: 'refund.approve', resource: 'refund', action: 'approve', description: 'الموافقة على الاسترجاع المالي');

  static const merchantManage = GranularPermission(key: 'merchant.manage', resource: 'merchant', action: 'manage', description: 'إدارة المتجر والمنتجات والأسعار');
  static const adminManage = GranularPermission(key: 'admin.manage', resource: 'admin', action: 'manage', description: 'الإدارة التشغيلية والإعدادات');
  static const auditRead = GranularPermission(key: 'audit.read', resource: 'audit', action: 'read', description: 'قراءة سجلات المراقبة والتدقيق');
  static const securityManage = GranularPermission(key: 'security.manage', resource: 'security', action: 'manage', description: 'إدارة السياسات الأمنية وحظر التهديدات');

  static const List<GranularPermission> all = [
    usersRead, usersUpdate, usersDelete,
    driversRead, driversUpdate, driversAssign,
    ordersRead, ordersCreate, ordersUpdate, ordersCancel,
    walletRead, walletDebit, walletCredit,
    refundCreate, refundApprove,
    merchantManage, adminManage, auditRead, securityManage,
  ];

  Map<String, dynamic> toMap() => {
    'key': key,
    'resource': resource,
    'action': action,
    'description': description,
  };

  factory GranularPermission.fromMap(Map<String, dynamic> map) => GranularPermission(
    key: map['key']?.toString() ?? '',
    resource: map['resource']?.toString() ?? '',
    action: map['action']?.toString() ?? '',
    description: map['description']?.toString() ?? '',
  );

  @override
  bool operator ==(Object other) => identical(this, other) || other is GranularPermission && runtimeType == other.runtimeType && key == other.key;

  @override
  int get hashCode => key.hashCode;
}
