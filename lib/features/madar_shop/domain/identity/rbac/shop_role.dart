// الأدوار الوظيفية لمتجر مدار (MADAR SHOP Roles)
// Pure Dart — Zero UI Dependencies

enum ShopRole {
  owner,           // المالك: كامل الصلاحيات دون قيود
  generalManager,  // المدير العام: إدارة العمليات، الفروع، والموظفين والتقارير
  branchManager,   // مدير الفرع: إدارة فرع محدد، مبيعاته، مخزونه، وموظفيه
  cashier,         // الكاشير: عمليات البيع المباشر وقبول الطلبات والقبض
  inventoryClerk,  // أمين المخزن: إدارة الجرد والواردات وتعديل الكميات
  accountant,      // المحاسب: الاطلاع على الحسابات والتقارير المالية والتدقيق
  custom;          // دور مخصص بصلاحيات محددة يدوياً

  static ShopRole fromString(String? role) {
    if (role == null) return ShopRole.cashier;
    switch (role.trim().toLowerCase()) {
      case 'owner':
        return ShopRole.owner;
      case 'general_manager':
      case 'generalmanager':
        return ShopRole.generalManager;
      case 'branch_manager':
      case 'branchmanager':
      case 'manager':
        return ShopRole.branchManager;
      case 'cashier':
        return ShopRole.cashier;
      case 'inventory_clerk':
      case 'inventoryclerk':
      case 'stock_manager':
        return ShopRole.inventoryClerk;
      case 'accountant':
        return ShopRole.accountant;
      default:
        return ShopRole.custom;
    }
  }

  String toDbString() {
    switch (this) {
      case ShopRole.owner:
        return 'owner';
      case ShopRole.generalManager:
        return 'general_manager';
      case ShopRole.branchManager:
        return 'branch_manager';
      case ShopRole.cashier:
        return 'cashier';
      case ShopRole.inventoryClerk:
        return 'inventory_clerk';
      case ShopRole.accountant:
        return 'accountant';
      case ShopRole.custom:
        return 'custom';
    }
  }

  String get displayNameAr {
    switch (this) {
      case ShopRole.owner:
        return 'المالك';
      case ShopRole.generalManager:
        return 'المدير العام';
      case ShopRole.branchManager:
        return 'مدير الفرع';
      case ShopRole.cashier:
        return 'كاشير';
      case ShopRole.inventoryClerk:
        return 'أمين المخزن';
      case ShopRole.accountant:
        return 'محاسب';
      case ShopRole.custom:
        return 'مخصص';
    }
  }
}
