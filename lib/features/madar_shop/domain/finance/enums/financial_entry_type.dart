// أنواع القيود المالية التشغيلية (MADAR SHOP Operational Financial Entry Type)
// Pure Dart — Zero UI Dependencies

enum FinancialEntryType {
  /// إيراد مبيعات محقق من نقاط البيع
  saleRevenue,

  /// تكلفة البضاعة المباعة للصنف
  saleCogs,

  /// استرداد مالي أو رصيد دائن لمرتجع مبيعات
  customerRefund,

  /// شراء بضاعة وتوريدها للمخزن (التزام مورد)
  supplierPurchase,

  /// إرجاع بضاعة للمورد بموجب إشعار دائن
  supplierReturn,

  /// تسوية مالية لفروقات المخزون (عجز / زيادة / تلف)
  inventoryAdjustment,

  /// سداد دفعة للمورد أو قبض من العميل
  payment;

  String get displayNameAr {
    switch (this) {
      case FinancialEntryType.saleRevenue:
        return 'إيراد مبيعات';
      case FinancialEntryType.saleCogs:
        return 'تكلفة بضاعة مباعة (COGS)';
      case FinancialEntryType.customerRefund:
        return 'استرداد مرتجع زبون';
      case FinancialEntryType.supplierPurchase:
        return 'توريد مشتريات مورد';
      case FinancialEntryType.supplierReturn:
        return 'مرتجع لمورد';
      case FinancialEntryType.inventoryAdjustment:
        return 'تسوية فروقات مخزون';
      case FinancialEntryType.payment:
        return 'دفعة مالية';
    }
  }

  static FinancialEntryType fromString(String? val) {
    if (val == null) return FinancialEntryType.saleRevenue;
    switch (val.trim().toLowerCase()) {
      case 'cogs':
      case 'salecogs':
      case 'sale_cogs':
        return FinancialEntryType.saleCogs;
      case 'refund':
      case 'customerrefund':
      case 'customer_refund':
        return FinancialEntryType.customerRefund;
      case 'purchase':
      case 'supplierpurchase':
      case 'supplier_purchase':
        return FinancialEntryType.supplierPurchase;
      case 'supplierreturn':
      case 'supplier_return':
        return FinancialEntryType.supplierReturn;
      case 'adjustment':
      case 'inventoryadjustment':
      case 'inventory_adjustment':
        return FinancialEntryType.inventoryAdjustment;
      case 'payment':
        return FinancialEntryType.payment;
      case 'revenue':
      case 'salerevenue':
      case 'sale_revenue':
      default:
        return FinancialEntryType.saleRevenue;
    }
  }
}
