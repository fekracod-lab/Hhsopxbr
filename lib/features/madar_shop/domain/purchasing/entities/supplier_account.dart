// حساب المورد المالي والرصيد المستحق (MADAR SHOP Supplier Account Entity)
// Pure Dart — Zero UI Dependencies

import '../../pos/value_objects/currency.dart';
import '../../pos/value_objects/money.dart';

class SupplierAccount {
  final String supplierId;
  final String businessId;
  final Money currentBalance; // الرصيد المستحق للمورد (Payable)
  final Currency currency;
  final int version; // التحكم في التزامن المتفائل OCC
  final DateTime updatedAt;

  const SupplierAccount({
    required this.supplierId,
    required this.businessId,
    required this.currentBalance,
    required this.currency,
    this.version = 1,
    required this.updatedAt,
  });

  factory SupplierAccount.initial({
    required String supplierId,
    required String businessId,
    Currency currency = Currency.iqd,
  }) {
    return SupplierAccount(
      supplierId: supplierId,
      businessId: businessId,
      currentBalance: Money.zero(currency),
      currency: currency,
      version: 1,
      updatedAt: DateTime.now(),
    );
  }

  SupplierAccount copyWith({
    Money? currentBalance,
    int? version,
    DateTime? updatedAt,
  }) {
    return SupplierAccount(
      supplierId: supplierId,
      businessId: businessId,
      currentBalance: currentBalance ?? this.currentBalance,
      currency: currency,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierAccount &&
          runtimeType == other.runtimeType &&
          supplierId == other.supplierId &&
          businessId == other.businessId &&
          version == other.version;

  @override
  int get hashCode => supplierId.hashCode ^ businessId.hashCode ^ version.hashCode;

  @override
  String toString() =>
      'SupplierAccount(supplierId: $supplierId, balance: $currentBalance, v$version)';
}
