// محرك وحاسبة تكلفة البضاعة المباعة (MADAR SHOP COGS Calculator)
// Pure Dart — Zero UI Dependencies

import '../../inventory/value_objects/stock_quantity.dart';
import '../../pos/value_objects/currency.dart';
import '../../pos/value_objects/money.dart';
import '../value_objects/inventory_cost_layer.dart';

class FifoCogsResult {
  final Money totalCogs;
  final StockQuantity totalConsumedQuantity;
  final List<InventoryCostLayer> updatedLayers;
  final List<({String layerId, StockQuantity consumedQty, Money layerCost})> consumedBreakdown;

  const FifoCogsResult({
    required this.totalCogs,
    required this.totalConsumedQuantity,
    required this.updatedLayers,
    required this.consumedBreakdown,
  });
}

class CogsCalculator {
  const CogsCalculator._();

  /// حساب المتوسط المرجح التراكمي الجديد للتكلفة (Weighted Average Cost Formula)
  /// المعادلة:
  /// New Average Cost = (Existing Quantity × Existing Average Cost + Received Quantity × Received Cost) / Total Quantity
  static Money calculateNewWeightedAverageCost({
    required StockQuantity existingQuantity,
    required Money existingAverageCost,
    required StockQuantity receivedQuantity,
    required Money receivedCost,
  }) {
    if (receivedQuantity.milliUnits <= 0) return existingAverageCost;
    if (existingQuantity.milliUnits <= 0) return receivedCost;

    final existingMilli = existingQuantity.milliUnits;
    final receivedMilli = receivedQuantity.milliUnits;
    final totalMilli = existingMilli + receivedMilli;

    if (totalMilli <= 0) return receivedCost;

    // الحساب الدقيق عبر الملي-وحدات والوحدات الصغرى لتفادي Float Drift
    final existingTotalUnits = (existingMilli * existingAverageCost.minorUnits) ~/ 1000;
    final receivedTotalUnits = (receivedMilli * receivedCost.minorUnits) ~/ 1000;
    final totalUnits = existingTotalUnits + receivedTotalUnits;

    // قسمة مع تقريب صحيح لأقرب وحدة صغرى
    final newAvgUnits = ((totalUnits * 1000) + (totalMilli ~/ 2)) ~/ totalMilli;

    return Money.fromMinorUnits(newAvgUnits, existingAverageCost.currency);
  }

  /// حساب تكلفة البضاعة المباعة بطريقة المتوسط المرجح
  static Money calculateWeightedAverageCogs({
    required StockQuantity quantitySold,
    required Money averageCost,
  }) {
    if (quantitySold.milliUnits <= 0) return Money.zero(averageCost.currency);
    return averageCost * quantitySold.toDouble();
  }

  /// حساب تكلفة البضاعة المباعة واستهلاك الطبقات بطريقة FIFO (الوارد أولاً يصرف أولاً)
  static FifoCogsResult consumeFifoCostLayers({
    required List<InventoryCostLayer> layers,
    required StockQuantity quantityToConsume,
  }) {
    if (quantityToConsume.milliUnits <= 0 || layers.isEmpty) {
      return FifoCogsResult(
        totalCogs: Money.zero(layers.isNotEmpty ? layers.first.currency : Currency.iqd),
        totalConsumedQuantity: StockQuantity.zero(quantityToConsume.unit),
        updatedLayers: layers,
        consumedBreakdown: const [],
      );
    }

    // فرز الطبقات حسب تاريخ الإنشاء تصاعدياً (الأقدم أولاً)
    final sortedLayers = [...layers]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    StockQuantity remainingToConsume = quantityToConsume;
    Money totalCogs = Money.zero(sortedLayers.first.currency);
    final updatedLayers = <InventoryCostLayer>[];
    final breakdown = <({String layerId, StockQuantity consumedQty, Money layerCost})>[];

    for (final layer in sortedLayers) {
      if (remainingToConsume.milliUnits <= 0 || layer.isExhausted) {
        updatedLayers.add(layer);
        continue;
      }

      final consumeResult = layer.consume(remainingToConsume);
      updatedLayers.add(consumeResult.updatedLayer);
      totalCogs += consumeResult.costOfConsumed;
      remainingToConsume -= consumeResult.consumedQty;

      breakdown.add((
        layerId: layer.id,
        consumedQty: consumeResult.consumedQty,
        layerCost: consumeResult.costOfConsumed,
      ));
    }

    final totalConsumed = quantityToConsume - remainingToConsume;

    return FifoCogsResult(
      totalCogs: totalCogs,
      totalConsumedQuantity: totalConsumed,
      updatedLayers: updatedLayers,
      consumedBreakdown: breakdown,
    );
  }
}
