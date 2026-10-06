// نموذج بيانات المورد وحسابه (MADAR SHOP Supplier Data Models)
// Pure Dart — Zero UI Dependencies

import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/purchasing/entities/supplier.dart';
import '../../../domain/purchasing/entities/supplier_account.dart';
import '../../../domain/purchasing/enums/supplier_status.dart';

class SupplierModel {
  static Map<String, dynamic> toMap(Supplier supplier) {
    return {
      'id': supplier.id,
      'businessId': supplier.businessId,
      'name': supplier.name,
      'phone': supplier.phone,
      'email': supplier.email,
      'address': supplier.address,
      'taxId': supplier.taxId,
      'status': supplier.status.name,
      'createdAt': supplier.createdAt.toIso8601String(),
      'updatedAt': supplier.updatedAt.toIso8601String(),
      'metadata': supplier.metadata,
    };
  }

  static Supplier fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      email: map['email'] as String?,
      address: map['address'] as String?,
      taxId: map['taxId'] as String?,
      status: SupplierStatus.fromString(map['status'] as String?),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }
}

class SupplierAccountModel {
  static Map<String, dynamic> toMap(SupplierAccount account) {
    return {
      'supplierId': account.supplierId,
      'businessId': account.businessId,
      'currentBalanceMinorUnits': account.currentBalance.minorUnits,
      'currency': account.currency.code,
      'version': account.version,
      'updatedAt': account.updatedAt.toIso8601String(),
    };
  }

  static SupplierAccount fromMap(Map<String, dynamic> map) {
    final currency = Currency.fromCode(map['currency'] as String?);
    return SupplierAccount(
      supplierId: map['supplierId'] as String,
      businessId: map['businessId'] as String,
      currentBalance: Money.fromMinorUnits(
        map['currentBalanceMinorUnits'] as int? ?? 0,
        currency,
      ),
      currency: currency,
      version: map['version'] as int? ?? 1,
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
