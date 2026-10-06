// لقطة التكلفة غير القابلة للتغيير (MADAR SHOP Cost Snapshot Value Object)
// Pure Dart — Zero UI Dependencies

import '../../pos/value_objects/currency.dart';
import '../../pos/value_objects/money.dart';

class CostSnapshot {
  final Money unitCost;
  final Money discountPerUnit;
  final Money taxPerUnit;
  final Money netUnitCost;
  final DateTime effectiveAt;
  final Currency currency;

  CostSnapshot({
    required this.unitCost,
    Money? discountPerUnit,
    Money? taxPerUnit,
    DateTime? effectiveAt,
  })  : discountPerUnit = discountPerUnit ?? Money.zero(unitCost.currency),
        taxPerUnit = taxPerUnit ?? Money.zero(unitCost.currency),
        effectiveAt = effectiveAt ?? DateTime.now(),
        currency = unitCost.currency,
        netUnitCost = unitCost - (discountPerUnit ?? Money.zero(unitCost.currency)) + (taxPerUnit ?? Money.zero(unitCost.currency));

  CostSnapshot copyWith({
    Money? unitCost,
    Money? discountPerUnit,
    Money? taxPerUnit,
    DateTime? effectiveAt,
  }) {
    return CostSnapshot(
      unitCost: unitCost ?? this.unitCost,
      discountPerUnit: discountPerUnit ?? this.discountPerUnit,
      taxPerUnit: taxPerUnit ?? this.taxPerUnit,
      effectiveAt: effectiveAt ?? this.effectiveAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CostSnapshot &&
          runtimeType == other.runtimeType &&
          unitCost == other.unitCost &&
          discountPerUnit == other.discountPerUnit &&
          taxPerUnit == other.taxPerUnit &&
          netUnitCost == other.netUnitCost &&
          currency == other.currency;

  @override
  int get hashCode =>
      unitCost.hashCode ^
      discountPerUnit.hashCode ^
      taxPerUnit.hashCode ^
      netUnitCost.hashCode ^
      currency.hashCode;

  @override
  String toString() =>
      'CostSnapshot(unitCost: $unitCost, netUnitCost: $netUnitCost, effectiveAt: $effectiveAt)';
}
