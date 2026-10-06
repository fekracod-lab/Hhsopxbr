// طبقة تكلفة المخزون لحساب الوارد أولاً يصرف أولاً والتقييم (MADAR SHOP Inventory Cost Layer)
// Pure Dart — Zero UI Dependencies

import '../../inventory/value_objects/stock_quantity.dart';
import '../../pos/value_objects/currency.dart';
import '../../pos/value_objects/money.dart';

class InventoryCostLayer {
  final String id;
  final String businessId;
  final String branchId;
  final String productId;
  final String? variantId;
  final String sourceType;
  final String sourceId;
  final StockQuantity quantity;
  final StockQuantity remainingQuantity;
  final Money unitCost;
  final Currency currency;
  final DateTime createdAt;
  final int version;

  const InventoryCostLayer({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.productId,
    this.variantId,
    required this.sourceType,
    required this.sourceId,
    required this.quantity,
    required this.remainingQuantity,
    required this.unitCost,
    this.currency = Currency.iqd,
    required this.createdAt,
    this.version = 1,
  });

  /// هل نفذت طبقة التكلفة بالكامل
  bool get isExhausted => remainingQuantity.milliUnits <= 0;

  /// القيمة المالية الحالية المتبقية في هذه الطبقة
  Money get remainingTotalValue => unitCost * remainingQuantity.toDouble();

  /// استهلاك كمية من هذه الطبقة (لـ FIFO COGS)
  ({InventoryCostLayer updatedLayer, StockQuantity consumedQty, Money costOfConsumed}) consume(
    StockQuantity requestedQty,
  ) {
    if (isExhausted) {
      return (
        updatedLayer: this,
        consumedQty: StockQuantity.zero(quantity.unit),
        costOfConsumed: Money.zero(currency),
      );
    }

    final toTake = requestedQty > remainingQuantity ? remainingQuantity : requestedQty;
    final newRemaining = remainingQuantity - toTake;
    final cost = unitCost * toTake.toDouble();

    final updated = copyWith(
      remainingQuantity: newRemaining,
      version: version + 1,
    );

    return (
      updatedLayer: updated,
      consumedQty: toTake,
      costOfConsumed: cost,
    );
  }

  InventoryCostLayer copyWith({
    String? id,
    String? businessId,
    String? branchId,
    String? productId,
    String? variantId,
    String? sourceType,
    String? sourceId,
    StockQuantity? quantity,
    StockQuantity? remainingQuantity,
    Money? unitCost,
    Currency? currency,
    DateTime? createdAt,
    int? version,
  }) {
    return InventoryCostLayer(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      branchId: branchId ?? this.branchId,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      quantity: quantity ?? this.quantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      unitCost: unitCost ?? this.unitCost,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      version: version ?? this.version,
    );
  }
}
