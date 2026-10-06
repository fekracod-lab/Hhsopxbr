// مصفوفة تفويض الصلاحيات ومحرك الأمان (MADAR SHOP Permission Matrix Engine)
// Pure Dart — Zero UI Dependencies

import 'shop_permission.dart';
import 'shop_role.dart';

class ShopPermissionMatrix {
  const ShopPermissionMatrix._();

  /// قائمة الصلاحيات الافتراضية لكل دور تشغيلي
  static Set<ShopPermission> getDefaultPermissions(ShopRole role) {
    switch (role) {
      case ShopRole.owner:
        return Set.unmodifiable(ShopPermission.values);

      case ShopRole.generalManager:
        return Set.unmodifiable({
          // Sales & POS
          ShopPermission.accessPos,
          ShopPermission.createSalesOrder,
          ShopPermission.voidOrderItem,
          ShopPermission.voidEntireOrder,
          ShopPermission.applyItemDiscount,
          ShopPermission.applyCartDiscount,
          ShopPermission.overrideItemPrice,
          ShopPermission.processRefund,
          ShopPermission.reprintReceipt,
          ShopPermission.openCashDrawer,
          // Lifecycle & Marketplace
          ShopPermission.viewIncomingOrders,
          ShopPermission.acceptOrder,
          ShopPermission.rejectOrder,
          ShopPermission.markOrderReady,
          ShopPermission.dispatchOrder,
          ShopPermission.cancelActiveOrder,
          ShopPermission.toggleShopAvailability,
          // Products & Stock
          ShopPermission.viewProducts,
          ShopPermission.createProduct,
          ShopPermission.editProductInfo,
          ShopPermission.editSellingPrice,
          ShopPermission.viewCostPrice,
          ShopPermission.editCostPrice,
          ShopPermission.deleteProduct,
          ShopPermission.adjustInventoryStock,
          ShopPermission.performStocktaking,
          ShopPermission.publishToMarketplace,
          // Staff & Branches
          ShopPermission.viewStaff,
          ShopPermission.createStaff,
          ShopPermission.editStaff,
          ShopPermission.assignRoles,
          ShopPermission.deactivateStaff,
          ShopPermission.manageBranches,
          // Reports
          ShopPermission.viewDailySalesReport,
          ShopPermission.viewFinancialLedger,
          ShopPermission.viewProfitAndMarginReports,
          ShopPermission.viewInventoryValuation,
          ShopPermission.viewAuditLogs,
          // Purchasing & Suppliers
          ShopPermission.viewPurchases,
          ShopPermission.createPurchase,
          ShopPermission.submitPurchase,
          ShopPermission.approvePurchase,
          ShopPermission.receivePurchasedGoods,
          ShopPermission.cancelPurchase,
          ShopPermission.viewSuppliers,
          ShopPermission.createSupplier,
          ShopPermission.editSupplier,
          ShopPermission.blockSupplier,
          ShopPermission.createSupplierPayment,
          ShopPermission.viewSupplierLedger,
          // S5 Finance & Returns
          ShopPermission.viewFinanceSummary,
          ShopPermission.adjustFinancialEntry,
          ShopPermission.reconcileFinance,
          ShopPermission.createReturnOrder,
          ShopPermission.approveReturnOrder,
          ShopPermission.receiveReturnOrder,
          ShopPermission.refundReturnOrder,
          ShopPermission.createSupplierReturn,
          ShopPermission.approveSupplierReturn,
          // Settings
          ShopPermission.configureTaxAndCurrency,
        });

      case ShopRole.branchManager:
        return Set.unmodifiable({
          // Sales & POS
          ShopPermission.accessPos,
          ShopPermission.createSalesOrder,
          ShopPermission.voidOrderItem,
          ShopPermission.voidEntireOrder,
          ShopPermission.applyItemDiscount,
          ShopPermission.applyCartDiscount,
          ShopPermission.reprintReceipt,
          ShopPermission.openCashDrawer,
          // Lifecycle & Marketplace
          ShopPermission.viewIncomingOrders,
          ShopPermission.acceptOrder,
          ShopPermission.rejectOrder,
          ShopPermission.markOrderReady,
          ShopPermission.dispatchOrder,
          ShopPermission.cancelActiveOrder,
          ShopPermission.toggleShopAvailability,
          // Products & Stock
          ShopPermission.viewProducts,
          ShopPermission.createProduct,
          ShopPermission.editProductInfo,
          ShopPermission.editSellingPrice,
          ShopPermission.viewCostPrice,
          ShopPermission.adjustInventoryStock,
          ShopPermission.performStocktaking,
          ShopPermission.publishToMarketplace,
          // Purchasing & Suppliers
          ShopPermission.viewPurchases,
          ShopPermission.createPurchase,
          ShopPermission.submitPurchase,
          ShopPermission.approvePurchase,
          ShopPermission.receivePurchasedGoods,
          ShopPermission.cancelPurchase,
          ShopPermission.viewSuppliers,
          ShopPermission.createSupplier,
          ShopPermission.editSupplier,
          // S5 Finance & Returns
          ShopPermission.viewFinanceSummary,
          ShopPermission.createReturnOrder,
          ShopPermission.approveReturnOrder,
          ShopPermission.receiveReturnOrder,
          ShopPermission.refundReturnOrder,
          ShopPermission.createSupplierReturn,
          ShopPermission.approveSupplierReturn,
          // Staff
          ShopPermission.viewStaff,
          // Reports
          ShopPermission.viewDailySalesReport,
          ShopPermission.viewInventoryValuation,
          ShopPermission.viewProfitAndMarginReports,
        });

      case ShopRole.cashier:
        return Set.unmodifiable({
          // Sales & POS
          ShopPermission.accessPos,
          ShopPermission.createSalesOrder,
          ShopPermission.voidOrderItem, // حذف بند قيد الطلب قبل إتمام الدفع
          ShopPermission.reprintReceipt,
          ShopPermission.openCashDrawer,
          // S5 Returns (Request only)
          ShopPermission.createReturnOrder,
          // Orders & Lifecycle
          ShopPermission.viewIncomingOrders,
          ShopPermission.acceptOrder,
          ShopPermission.markOrderReady,
          ShopPermission.dispatchOrder,
          // Products
          ShopPermission.viewProducts,
        });

      case ShopRole.inventoryClerk:
        return Set.unmodifiable({
          ShopPermission.viewProducts,
          ShopPermission.createProduct,
          ShopPermission.editProductInfo,
          ShopPermission.adjustInventoryStock,
          ShopPermission.performStocktaking,
          ShopPermission.viewInventoryValuation,
          // Purchasing
          ShopPermission.viewPurchases,
          ShopPermission.receivePurchasedGoods,
          // S5 Returns
          ShopPermission.receiveReturnOrder,
          ShopPermission.createSupplierReturn,
        });

      case ShopRole.accountant:
        return Set.unmodifiable({
          ShopPermission.viewDailySalesReport,
          ShopPermission.viewFinancialLedger,
          ShopPermission.viewProfitAndMarginReports,
          ShopPermission.viewInventoryValuation,
          ShopPermission.viewAuditLogs,
          ShopPermission.viewCostPrice,
          ShopPermission.viewProducts,
          // Purchasing & Suppliers
          ShopPermission.viewPurchases,
          ShopPermission.viewSuppliers,
          ShopPermission.createSupplierPayment,
          ShopPermission.viewSupplierLedger,
          // S5 Finance & Returns
          ShopPermission.viewFinanceSummary,
          ShopPermission.adjustFinancialEntry,
          ShopPermission.reconcileFinance,
          ShopPermission.refundReturnOrder,
          ShopPermission.approveSupplierReturn,
        });

      case ShopRole.custom:
        return const <ShopPermission>{};
    }
  }

  /// التحقق الصارم من توفر الصلاحية
  static bool hasPermission({
    required ShopRole role,
    required ShopPermission permission,
    Set<ShopPermission>? customPermissions,
  }) {
    if (role == ShopRole.owner) return true;

    final effectivePermissions = customPermissions ?? getDefaultPermissions(role);
    return effectivePermissions.contains(permission);
  }

  /// التحقق من امتلاك كافة الصلاحيات الممررة (All required)
  static bool hasAllPermissions({
    required ShopRole role,
    required Iterable<ShopPermission> permissions,
    Set<ShopPermission>? customPermissions,
  }) {
    if (role == ShopRole.owner) return true;

    for (final perm in permissions) {
      if (!hasPermission(
        role: role,
        permission: perm,
        customPermissions: customPermissions,
      )) {
        return false;
      }
    }
    return true;
  }
}
