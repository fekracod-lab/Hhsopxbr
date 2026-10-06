// حالة المورد في نظام مشتريات مدار (MADAR SHOP Supplier Status)
// Pure Dart — Zero UI Dependencies

enum SupplierStatus {
  active,
  inactive,
  blocked;

  bool get isActive => this == SupplierStatus.active;
  bool get isInactive => this == SupplierStatus.inactive;
  bool get isBlocked => this == SupplierStatus.blocked;

  bool get canTransact => this == SupplierStatus.active;

  static SupplierStatus fromString(String? value) {
    if (value == null) return SupplierStatus.active;
    switch (value.trim().toLowerCase()) {
      case 'inactive':
        return SupplierStatus.inactive;
      case 'blocked':
        return SupplierStatus.blocked;
      case 'active':
      default:
        return SupplierStatus.active;
    }
  }
}
