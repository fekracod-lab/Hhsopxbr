// كيان سجل التدقيق والحوكمة غير القابل للتعديل (MADAR SHOP Immutable Audit Entry)
// Pure Dart — Zero UI Dependencies

enum ShopAuditAction {
  priceOverride,            // تعديل سعر بيع بند يدوياً أثناء البيع
  itemDiscountApplied,      // تطبيق خصم على بند معين
  cartDiscountApplied,      // تطبيق خصم عام على الفاتورة
  orderVoided,              // إلغاء فاتورة بعد البدء بها
  orderRefunded,            // استرجاع نقود أو إرجاع بضاعة
  manualStockAdjustment,    // تعديل كمية المخزون يدوياً (عجز / تلف / زيادة)
  costPriceEdited,          // تعديل سعر تكلفة السلعة
  shopStateToggled,         // فتح / إغلاق / إيقاف مؤقت للمتجر
  cashDrawerManualOpen,     // فتح درج الكاشير يدوياً بدون عملية بيع
  staffPermissionChanged,   // تعديل صلاحيات أو دور أحد الموظفين
  // Purchasing & Suppliers
  purchaseCreated,
  purchaseSubmitted,
  purchaseApproved,
  purchaseReceived,
  purchaseCancelled,
  supplierCreated,
  supplierUpdated,
  supplierBlocked,
  supplierPaymentCompleted,
  supplierAdjustment,
  // S5 Returns & Finance
  saleRevenuePosted,
  cogsPosted,
  returnCreated,
  returnApproved,
  returnReceived,
  refundCompleted,
  supplierReturn,
  creditNoteCreated,
  inventoryValuationCalculated,
  financeReconciliationMismatch;
}


class ShopAuditEntry {
  final String auditId;
  final String businessId;
  final String branchId;
  final String userId;
  final String userName;
  final String terminalId;
  final ShopAuditAction action;
  final String? referenceId; // orderId or productId
  final Map<String, dynamic> beforeState;
  final Map<String, dynamic> afterState;
  final String? reason;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const ShopAuditEntry({
    required this.auditId,
    required this.businessId,
    required this.branchId,
    required this.userId,
    required this.userName,
    required this.terminalId,
    required this.action,
    this.referenceId,
    this.beforeState = const {},
    this.afterState = const {},
    this.reason,
    required this.timestamp,
    this.metadata = const {},
  });
}
