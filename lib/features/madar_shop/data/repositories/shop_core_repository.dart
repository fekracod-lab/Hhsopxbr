// تطبيق المستودع المركزي لمتجر مدار (MADAR SHOP Core Repository Implementation)
// Data Layer — Firestore Integration with Sound Null Safety

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/contracts/shop_core_repository_contract.dart';
import '../../domain/identity/entities/shop_branch.dart';
import '../../domain/identity/entities/shop_business.dart';
import '../../domain/orders/entities/shop_order.dart';
import '../../domain/orders/entities/shop_order_status.dart';
import '../../domain/products/entities/shop_product.dart';
import '../../domain/state/entities/shop_availability_state.dart';
import '../models/shop_business_model.dart';
import '../models/shop_order_model.dart';
import '../models/shop_product_model.dart';

class ShopCoreRepositoryImpl implements IShopCoreRepository {
  final FirebaseFirestore _firestore;

  ShopCoreRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 1. Business & Branches ─────────────────────────────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Future<ShopBusiness?> getBusinessProfile(String businessId) async {
    final doc = await _firestore.collection('stores').doc(businessId).get();
    if (!doc.exists || doc.data() == null) return null;
    return ShopBusinessModel.fromJson(doc.data()!, id: doc.id);
  }

  @override
  Future<void> saveBusinessProfile(ShopBusiness business) async {
    final model = ShopBusinessModel(
      businessId: business.businessId,
      tradeName: business.tradeName,
      legalName: business.legalName,
      taxNumber: business.taxNumber,
      defaultCurrency: business.defaultCurrency,
      phone: business.phone,
      email: business.email,
      logoUrl: business.logoUrl,
      coverUrl: business.coverUrl,
      isVerified: business.isVerified,
      isActive: business.isActive,
      createdAt: business.createdAt,
      updatedAt: DateTime.now(),
      metadata: business.metadata,
    );

    await _firestore
        .collection('stores')
        .doc(business.businessId)
        .set(model.toJson(), SetOptions(merge: true));
  }

  @override
  Future<List<ShopBranch>> getBranches(String businessId) async {
    final snapshot = await _firestore
        .collection('stores')
        .doc(businessId)
        .collection('branches')
        .get();

    if (snapshot.docs.isEmpty) {
      // فرع افتراضي يمثل المحل الرئيسي
      return [
        ShopBranch(
          branchId: businessId,
          businessId: businessId,
          name: 'الفرع الرئيسي',
          code: 'MAIN',
          address: '',
          phone: '',
          isMainBranch: true,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
    }

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return ShopBranch(
        branchId: doc.id,
        businessId: businessId,
        name: (data['name'] ?? 'فرع').toString(),
        code: (data['code'] ?? 'BR').toString(),
        address: (data['address'] ?? '').toString(),
        phone: (data['phone'] ?? '').toString(),
        isMainBranch: data['isMainBranch'] == true,
        isActive: data['isActive'] != false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }).toList();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 2. Operating State ─────────────────────────────────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Future<ShopAvailabilityState?> getAvailabilityState(String branchId) async {
    final doc = await _firestore
        .collection('stores')
        .doc(branchId)
        .collection('settings')
        .doc('availability')
        .get();

    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;

    DateTime? parseTimestamp(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    return ShopAvailabilityState(
      branchId: branchId,
      availability: ShopAvailability.fromString(data['availability']?.toString()),
      operationalLoad: ShopOperationalLoad.fromString(data['operationalLoad']?.toString()),
      pauseReason: data['pauseReason']?.toString(),
      pauseUntil: parseTimestamp(data['pauseUntil']),
      lastHeartbeatAt: parseTimestamp(data['lastHeartbeatAt']),
      autoAcceptMarketplaceOrders: data['autoAcceptMarketplaceOrders'] == true,
      basePrepTimeMinutes: (data['basePrepTimeMinutes'] as num?)?.toInt() ?? 20,
      busyLoadBufferMinutes:
          (data['busyLoadBufferMinutes'] as num?)?.toInt() ?? 15,
      highLoadBufferMinutes:
          (data['highLoadBufferMinutes'] as num?)?.toInt() ?? 30,
      acceptingCash: data['acceptingCash'] != false,
      acceptingOnlinePayment: data['acceptingOnlinePayment'] != false,
      updatedAt: parseTimestamp(data['updatedAt']) ?? DateTime.now(),
      updatedByUserId: (data['updatedByUserId'] ?? 'SYSTEM').toString(),
    );
  }

  @override
  Future<void> updateAvailabilityState(ShopAvailabilityState state) async {
    await _firestore
        .collection('stores')
        .doc(state.branchId)
        .collection('settings')
        .doc('availability')
        .set({
      'branchId': state.branchId,
      'availability': state.availability.toDbString(),
      'operationalLoad': state.operationalLoad.toDbString(),
      'pauseReason': state.pauseReason,
      'pauseUntil': state.pauseUntil != null ? Timestamp.fromDate(state.pauseUntil!) : null,
      'lastHeartbeatAt': state.lastHeartbeatAt != null ? Timestamp.fromDate(state.lastHeartbeatAt!) : null,
      'autoAcceptMarketplaceOrders': state.autoAcceptMarketplaceOrders,
      'basePrepTimeMinutes': state.basePrepTimeMinutes,
      'busyLoadBufferMinutes': state.busyLoadBufferMinutes,
      'highLoadBufferMinutes': state.highLoadBufferMinutes,
      'acceptingCash': state.acceptingCash,
      'acceptingOnlinePayment': state.acceptingOnlinePayment,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUserId': state.updatedByUserId,
    }, SetOptions(merge: true));
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 3. Catalog & Products ──────────────────────────────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Future<List<ShopProduct>> getProducts({
    required String businessId,
    required String branchId,
    bool includeArchived = false,
  }) async {
    final snapshot = await _firestore
        .collection('stores')
        .doc(businessId)
        .collection('products')
        .get();

    return snapshot.docs
        .map((doc) => ShopProductModel.fromJson(doc.data(), id: doc.id))
        .where((p) => includeArchived || !p.isArchived)
        .toList();
  }

  @override
  Future<ShopProduct?> getProductById({
    required String businessId,
    required String branchId,
    required String productId,
  }) async {
    final doc = await _firestore
        .collection('stores')
        .doc(businessId)
        .collection('products')
        .doc(productId)
        .get();

    if (!doc.exists || doc.data() == null) return null;
    return ShopProductModel.fromJson(doc.data()!, id: doc.id);
  }

  @override
  Future<void> saveProduct(ShopProduct product) async {
    final model = ShopProductModel(
      productId: product.productId,
      businessId: product.businessId,
      branchId: product.branchId,
      categoryId: product.categoryId,
      name: product.name,
      description: product.description,
      sku: product.sku,
      barcode: product.barcode,
      costPrice: product.costPrice,
      sellingPrice: product.sellingPrice,
      stockQuantity: product.stockQuantity,
      minStockAlert: product.minStockAlert,
      unitOfMeasure: product.unitOfMeasure,
      isWeighable: product.isWeighable,
      imageUrl: product.imageUrl,
      variants: product.variants,
      isArchived: product.isArchived,
      createdAt: product.createdAt,
      updatedAt: DateTime.now(),
      customAttributes: product.customAttributes,
    );

    await _firestore
        .collection('stores')
        .doc(product.businessId)
        .collection('products')
        .doc(product.productId)
        .set(model.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> updateStockQuantity({
    required String businessId,
    required String branchId,
    required String productId,
    required double newStock,
  }) async {
    await _firestore
        .collection('stores')
        .doc(businessId)
        .collection('products')
        .doc(productId)
        .update({
      'stockQuantity': newStock,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 4. Orders ──────────────────────────────────────────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Future<List<ShopOrder>> getActiveOrders({
    required String businessId,
    required String branchId,
  }) async {
    final snapshot = await _firestore
        .collection('orders')
        .where('storeId', isEqualTo: businessId)
        .get();

    return snapshot.docs
        .map((doc) => ShopOrderModel.fromJson(doc.data(), id: doc.id))
        .where((order) => order.status.isActive)
        .toList();
  }

  @override
  Future<ShopOrder?> getOrderById({
    required String businessId,
    required String orderId,
  }) async {
    final doc = await _firestore.collection('orders').doc(orderId).get();
    if (!doc.exists || doc.data() == null) return null;
    return ShopOrderModel.fromJson(doc.data()!, id: doc.id);
  }

  @override
  Future<void> saveOrder(ShopOrder order) async {
    final model = ShopOrderModel(
      orderId: order.orderId,
      orderNumber: order.orderNumber,
      businessId: order.businessId,
      branchId: order.branchId,
      source: order.source,
      channel: order.channel,
      fulfillment: order.fulfillment,
      status: order.status,
      version: order.version,
      idempotencyKey: order.idempotencyKey,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      deliveryAddress: order.deliveryAddress,
      items: order.items,
      cartDiscountAmount: order.cartDiscountAmount,
      deliveryFee: order.deliveryFee,
      taxAmount: order.taxAmount,
      isPaid: order.isPaid,
      paymentMethod: order.paymentMethod,
      cashierUserId: order.cashierUserId,
      driverId: order.driverId,
      cancelOrRejectReason: order.cancelOrRejectReason,
      internalNotes: order.internalNotes,
      createdAt: order.createdAt,
      updatedAt: DateTime.now(),
    );

    await _firestore
        .collection('orders')
        .doc(order.orderId)
        .set(model.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> updateOrderStatus({
    required String businessId,
    required String orderId,
    required ShopOrderStatus newStatus,
    String? reason,
  }) async {
    final Map<String, dynamic> updates = {
      'status': newStatus.toDbString(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (reason != null && reason.isNotEmpty) {
      updates['cancelOrRejectReason'] = reason;
    }

    await _firestore.collection('orders').doc(orderId).update(updates);
  }
}
