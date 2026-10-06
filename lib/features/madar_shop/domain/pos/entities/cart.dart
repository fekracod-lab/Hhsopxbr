// كيان سلة المشتريات لنقطة البيع (MADAR SHOP POS Cart Entity)
// Pure Dart — Zero UI Dependencies

import '../value_objects/currency.dart';
import '../value_objects/discount.dart';
import '../value_objects/money.dart';
import 'cart_item.dart';

class Cart {
  final List<CartItem> items;
  final String? customerId;
  final String? customerName;
  final Discount cartDiscount;
  final String? notes;
  final Currency currency;

  const Cart({
    this.items = const [],
    this.customerId,
    this.customerName,
    this.cartDiscount = const Discount.none(),
    this.notes,
    this.currency = Currency.iqd,
  });

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get itemCount => items.length;

  /// إجمالي عدد الوحدات في السلة (يدعم الكسور للموزونات مثل 1.750 كغم)
  double get totalUnitsCount {
    return items.fold(0.0, (sum, item) => sum + item.quantity);
  }

  /// مجموع السلة قبل أي خصم
  Money get itemsSubtotal {
    if (items.isEmpty) return Money.zero(currency);
    return items.fold(Money.zero(currency), (sum, item) => sum + item.lineSubtotal);
  }

  /// إجمالي خصومات البنود
  Money get itemsDiscountTotal {
    if (items.isEmpty) return Money.zero(currency);
    return items.fold(Money.zero(currency), (sum, item) => sum + item.discountAmount);
  }

  /// قيمة الخصم العام المطبق على مستوى كامل السلة
  Money get cartLevelDiscountAmount {
    final remainingBase = itemsSubtotal - itemsDiscountTotal;
    if (remainingBase <= Money.zero(currency)) return Money.zero(currency);
    return cartDiscount.calculateDiscountAmount(remainingBase);
  }

  /// إجمالي كافة الخصومات (البنود + السلة)
  Money get totalDiscount => itemsDiscountTotal + cartLevelDiscountAmount;

  /// صافي السلة بعد الخصومات وقبل الضريبة
  Money get netBeforeTax {
    final net = itemsSubtotal - totalDiscount;
    return net.isNegative ? Money.zero(currency) : net;
  }

  /// إجمالي تكلفة البضاعة في السلة
  Money get totalCost {
    if (items.isEmpty) return Money.zero(currency);
    return items.fold(Money.zero(currency), (sum, item) => sum + item.totalCost);
  }

  /// صافي الربح المتوقع للسلة
  Money get expectedGrossProfit => netBeforeTax - totalCost;

  // ─── العمليات غير القابلة للتحريف (Immutable Operations) ───

  Cart addItem(CartItem newItem) {
    if (newItem.quantity <= 0) {
      throw ArgumentError('يجب أن تكون كمية البند أكبر من صفر.');
    }

    final existingIndex = items.indexWhere(
      (it) => it.productId == newItem.productId && it.variantId == newItem.variantId,
    );

    if (existingIndex >= 0) {
      final existing = items[existingIndex];
      final updatedItem = existing.copyWith(
        quantity: existing.quantity + newItem.quantity,
      );
      final updatedList = List<CartItem>.from(items)..[existingIndex] = updatedItem;
      return copyWith(items: updatedList);
    } else {
      return copyWith(items: [...items, newItem]);
    }
  }

  Cart removeItem(String itemId) {
    return copyWith(items: items.where((it) => it.itemId != itemId).toList());
  }

  Cart updateQuantity(String itemId, double newQuantity) {
    if (newQuantity <= 0) {
      return removeItem(itemId);
    }
    final updatedList = items.map((it) {
      if (it.itemId == itemId) {
        return it.copyWith(quantity: newQuantity);
      }
      return it;
    }).toList();
    return copyWith(items: updatedList);
  }

  Cart applyItemDiscount(String itemId, Discount discount) {
    final updatedList = items.map((it) {
      if (it.itemId == itemId) {
        return it.copyWith(lineDiscount: discount);
      }
      return it;
    }).toList();
    return copyWith(items: updatedList);
  }

  Cart applyCartDiscount(Discount discount) {
    return copyWith(cartDiscount: discount);
  }

  Cart setCustomer({String? id, String? name}) {
    return copyWith(customerId: id, customerName: name);
  }

  Cart clear() {
    return Cart(currency: currency);
  }

  Cart copyWith({
    List<CartItem>? items,
    String? customerId,
    String? customerName,
    Discount? cartDiscount,
    String? notes,
    Currency? currency,
  }) {
    return Cart(
      items: items ?? this.items,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      cartDiscount: cartDiscount ?? this.cartDiscount,
      notes: notes ?? this.notes,
      currency: currency ?? this.currency,
    );
  }
}
