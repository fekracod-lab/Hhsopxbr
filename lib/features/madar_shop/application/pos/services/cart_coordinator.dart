// منسق سلة الشراء بنقطة البيع مع فحص الصلاحيات (MADAR SHOP Cart Coordinator)
// Pure Dart — Zero UI Dependencies

import '../../../domain/identity/rbac/shop_permission.dart';
import '../../../domain/pos/calculators/pricing_calculator.dart';
import '../../../domain/pos/calculators/tax_policy.dart';
import '../../../domain/pos/entities/cart.dart';
import '../../../domain/pos/entities/cart_item.dart';
import '../../../domain/pos/entities/resolved_product.dart';
import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/discount.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../shop_identity_coordinator.dart';
import '../failures/pos_failures.dart';

class CartCoordinator {
  final ShopIdentityCoordinator _identityCoordinator;
  Cart _cart;

  CartCoordinator({
    required ShopIdentityCoordinator identityCoordinator,
    Currency currency = Currency.iqd,
  })  : _identityCoordinator = identityCoordinator,
        _cart = Cart(currency: currency);

  Cart get currentCart => _cart;

  /// إضافة منتج محلول إلى السلة
  Cart addResolvedProduct({
    required ResolvedProduct product,
    double quantity = 1.0,
    Money? manualOverridePrice,
    String? overrideReason,
    Discount discount = const Discount.none(),
    TaxPolicy? taxPolicy,
  }) {
    if (quantity <= 0) {
      throw const InvalidQuantityFailure('يجب أن تكون الكمية أكبر من صفر.');
    }

    if (!product.isAvailable) {
      throw ProductUnavailableFailure('المنتج "${product.name}" غير متوفر للبيع حالياً.');
    }

    // التحقق من صلاحية تعديل السعر يدوياً
    if (manualOverridePrice != null) {
      if (!_identityCoordinator.hasPermission(ShopPermission.overrideItemPrice)) {
        throw const UnauthorizedCashierFailure(
          'ليس لديك صلاحية لتعديل سعر المنتج يدوياً.',
        );
      }
    }

    // التحقق من صلاحية تطبيق الخصم
    if (!discount.isZero) {
      if (!_identityCoordinator.hasPermission(ShopPermission.applyItemDiscount)) {
        throw const UnauthorizedCashierFailure(
          'ليس لديك صلاحية لمنح خصم على مستوى البند.',
        );
      }
    }

    final pricingSnapshot = PricingCalculator.createSnapshotForItem(
      product: product,
      manualOverridePrice: manualOverridePrice,
      overrideReason: overrideReason,
      discount: discount,
      taxPolicy: taxPolicy,
    );

    final item = CartItem(
      itemId: '${product.productId}-${product.variantId ?? "main"}-${DateTime.now().microsecondsSinceEpoch}',
      productId: product.productId,
      variantId: product.variantId,
      variantTitle: product.variantTitle,
      sku: product.sku,
      barcode: product.barcode,
      name: product.name,
      unitPrice: pricingSnapshot.unitPrice,
      costPrice: pricingSnapshot.costPrice,
      quantity: quantity,
      unitOfMeasure: product.unitOfMeasure,
      isWeighable: product.isWeighable,
      lineDiscount: discount,
      pricingSnapshot: pricingSnapshot,
    );

    _cart = _cart.addItem(item);
    return _cart;
  }

  /// حذف بند من السلة
  Cart removeItem(String itemId) {
    _cart = _cart.removeItem(itemId);
    return _cart;
  }

  /// تعديل كمية بند في السلة
  Cart updateQuantity(String itemId, double newQuantity) {
    if (newQuantity <= 0) {
      return removeItem(itemId);
    }
    _cart = _cart.updateQuantity(itemId, newQuantity);
    return _cart;
  }

  /// تطبيق خصم على بند مع فحص الصلاحية
  Cart applyItemDiscount(String itemId, Discount discount) {
    if (!_identityCoordinator.hasPermission(ShopPermission.applyItemDiscount)) {
      throw const UnauthorizedCashierFailure('ليس لديك صلاحية لتطبيق خصم على البند.');
    }
    _cart = _cart.applyItemDiscount(itemId, discount);
    return _cart;
  }

  /// تطبيق خصم عام على السلة مع فحص الصلاحية
  Cart applyCartDiscount(Discount discount) {
    if (!_identityCoordinator.hasPermission(ShopPermission.applyCartDiscount)) {
      throw const UnauthorizedCashierFailure('ليس لديك صلاحية لتطبيق خصم عام على الفاتورة.');
    }
    _cart = _cart.applyCartDiscount(discount);
    return _cart;
  }

  /// تعيين بيانات العميل
  Cart setCustomer({String? customerId, String? customerName}) {
    _cart = _cart.setCustomer(id: customerId, name: customerName);
    return _cart;
  }

  /// تفريغ السلة
  void clear() {
    _cart = _cart.clear();
  }
}
