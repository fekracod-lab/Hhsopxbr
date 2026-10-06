// مصفوفة الصلاحيات الحبيبية لمتجر مدار (MADAR SHOP Permissions Enum)
// Pure Dart — Zero UI Dependencies

enum ShopPermission {
  // ─── POS & Sales Operations (نقاط البيع والمبيعات) ───
  accessPos,
  createSalesOrder,
  voidOrderItem,
  voidEntireOrder,
  applyItemDiscount,
  applyCartDiscount,
  overrideItemPrice,
  processRefund,
  reprintReceipt,
  openCashDrawer,

  // ─── Order Lifecycle & Marketplace (إدارة الطلبات والماركت بليس) ───
  viewIncomingOrders,
  acceptOrder,
  rejectOrder,
  markOrderReady,
  dispatchOrder,
  cancelActiveOrder,
  toggleShopAvailability,

  // ─── Products & Inventory (المنتجات والمخزون والتسعير) ───
  viewProducts,
  createProduct,
  editProductInfo,
  editSellingPrice,
  viewCostPrice,
  editCostPrice,
  deleteProduct,
  adjustInventoryStock,
  performStocktaking,
  publishToMarketplace,

  // ─── Staff & Branch Management (إدارة الفروع والموظفين) ───
  viewStaff,
  createStaff,
  editStaff,
  assignRoles,
  deactivateStaff,
  manageBranches,

  // ─── Financials & Reporting (التقارير والحسابات) ───
  viewDailySalesReport,
  viewFinancialLedger,
  viewProfitAndMarginReports,
  viewInventoryValuation,
  viewAuditLogs,
  viewFinanceSummary,
  adjustFinancialEntry,
  reconcileFinance,

  // ─── Customer & Supplier Returns (المرتجعات) ───
  createReturnOrder,
  approveReturnOrder,
  receiveReturnOrder,
  refundReturnOrder,
  createSupplierReturn,
  approveSupplierReturn,

  // ─── Purchasing & Suppliers (المشتريات والموردين) ───
  viewPurchases,
  createPurchase,
  submitPurchase,
  approvePurchase,
  receivePurchasedGoods,
  cancelPurchase,
  viewSuppliers,
  createSupplier,
  editSupplier,
  blockSupplier,
  createSupplierPayment,
  viewSupplierLedger,

  // ─── System & Settings (الإعدادات العامة) ───
  editBusinessProfile,
  configureTaxAndCurrency,
  manageIntegrations,
}

