// كيان المورد في نظام مشتريات مدار (MADAR SHOP Supplier Entity)
// Pure Dart — Zero UI Dependencies

import '../enums/supplier_status.dart';

class Supplier {
  final String id;
  final String businessId;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final String? taxId;
  final SupplierStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  const Supplier({
    required this.id,
    required this.businessId,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.taxId,
    this.status = SupplierStatus.active,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  bool get isActive => status == SupplierStatus.active;
  bool get isBlocked => status == SupplierStatus.blocked;
  bool get isInactive => status == SupplierStatus.inactive;

  Supplier copyWith({
    String? name,
    String? phone,
    String? email,
    String? address,
    String? taxId,
    SupplierStatus? status,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Supplier(
      id: id,
      businessId: businessId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      taxId: taxId ?? this.taxId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Supplier &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          businessId == other.businessId;

  @override
  int get hashCode => id.hashCode ^ businessId.hashCode;

  @override
  String toString() => 'Supplier(id: $id, name: $name, status: $status)';
}
