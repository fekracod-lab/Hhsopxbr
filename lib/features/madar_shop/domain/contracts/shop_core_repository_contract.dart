// عقود المستودع المركزي لمتجر مدار (MADAR SHOP Core Repository Contract)
// Pure Dart — Zero UI Dependencies

import '../identity/entities/shop_branch.dart';
import '../identity/entities/shop_business.dart';
import '../orders/entities/shop_order.dart';
import '../orders/entities/shop_order_status.dart';
import '../products/entities/shop_product.dart';
import '../state/entities/shop_availability_state.dart';

abstract class IShopCoreRepository {
  // ─── Business & Branches ───
  Future<ShopBusiness?> getBusinessProfile(String businessId);
  Future<void> saveBusinessProfile(ShopBusiness business);
  Future<List<ShopBranch>> getBranches(String businessId);

  // ─── Operating State ───
  Future<ShopAvailabilityState?> getAvailabilityState(String branchId);
  Future<void> updateAvailabilityState(ShopAvailabilityState state);

  // ─── Catalog & Products ───
  Future<List<ShopProduct>> getProducts({
    required String businessId,
    required String branchId,
    bool includeArchived = false,
  });
  Future<ShopProduct?> getProductById({
    required String businessId,
    required String branchId,
    required String productId,
  });
  Future<void> saveProduct(ShopProduct product);
  Future<void> updateStockQuantity({
    required String businessId,
    required String branchId,
    required String productId,
    required double newStock,
  });

  // ─── Orders ───
  Future<List<ShopOrder>> getActiveOrders({
    required String businessId,
    required String branchId,
  });
  Future<ShopOrder?> getOrderById({
    required String businessId,
    required String orderId,
  });
  Future<void> saveOrder(ShopOrder order);
  Future<void> updateOrderStatus({
    required String businessId,
    required String orderId,
    required ShopOrderStatus newStatus,
    String? reason,
  });
}
