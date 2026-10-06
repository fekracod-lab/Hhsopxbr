// كائن كمية المخزون الحسابي الدقيق (MADAR SHOP Stock Quantity Value Object)
// Pure Dart — Zero UI Dependencies

import 'stock_unit.dart';

class StockQuantity implements Comparable<StockQuantity> {
  static const int precisionFactor = 1000; // 3 خانات عشرية لدقة الأوزان والأحجام (مثلاً 1.750 كغم = 1750 ملي وحدة)

  final int milliUnits;
  final StockUnit unit;

  const StockQuantity._(this.milliUnits, this.unit);

  /// إنشاء كمية بالوحدات الصحيحة (قطع / صناديق)
  factory StockQuantity.discrete(int units, [StockUnit unit = StockUnit.piece]) {
    return StockQuantity._(units * precisionFactor, unit);
  }

  /// إنشاء كمية للأوزان أو القياسات العشرية (مثل 1.750 كغم أو 0.500 لتر)
  factory StockQuantity.fromDouble(double value, [StockUnit unit = StockUnit.piece]) {
    if (value.isNaN || value.isInfinite) {
      throw ArgumentError('قيمة الكمية غير صالحة (NaN أو Infinite).');
    }
    final millis = (value * precisionFactor).round();
    return StockQuantity._(millis, unit);
  }

  /// إنشاء كمية من الملي وحدات مباشرة
  const StockQuantity.fromMilliUnits(this.milliUnits, [this.unit = StockUnit.piece]);

  /// كمية صفرية
  factory StockQuantity.zero([StockUnit unit = StockUnit.piece]) {
    return StockQuantity._(0, unit);
  }

  double toDouble() => milliUnits / precisionFactor;

  bool get isZero => milliUnits == 0;
  bool get isPositive => milliUnits > 0;
  bool get isNegative => milliUnits < 0;

  // ─── العمليات الحسابية الآمنة ───

  StockQuantity operator +(StockQuantity other) {
    _assertSameUnit(other);
    return StockQuantity._(milliUnits + other.milliUnits, unit);
  }

  StockQuantity operator -(StockQuantity other) {
    _assertSameUnit(other);
    return StockQuantity._(milliUnits - other.milliUnits, unit);
  }

  StockQuantity operator *(num factor) {
    if (factor.isNaN || factor.isInfinite) {
      throw ArgumentError('معامل الضرب غير صالح.');
    }
    return StockQuantity._((milliUnits * factor).round(), unit);
  }

  StockQuantity operator -() {
    return StockQuantity._(-milliUnits, unit);
  }

  // ─── المقارنات ───

  bool operator <(StockQuantity other) {
    _assertSameUnit(other);
    return milliUnits < other.milliUnits;
  }

  bool operator <=(StockQuantity other) {
    _assertSameUnit(other);
    return milliUnits <= other.milliUnits;
  }

  bool operator >(StockQuantity other) {
    _assertSameUnit(other);
    return milliUnits > other.milliUnits;
  }

  bool operator >=(StockQuantity other) {
    _assertSameUnit(other);
    return milliUnits >= other.milliUnits;
  }

  void _assertSameUnit(StockQuantity other) {
    if (unit != other.unit) {
      throw ArgumentError(
        'لا يمكن إجراء عمليات حسابية بين وحدات قياس مختلفة: ${unit.displayNameAr} و ${other.unit.displayNameAr}',
      );
    }
  }

  @override
  int compareTo(StockQuantity other) {
    _assertSameUnit(other);
    return milliUnits.compareTo(other.milliUnits);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockQuantity &&
          runtimeType == other.runtimeType &&
          milliUnits == other.milliUnits &&
          unit == other.unit;

  @override
  int get hashCode => milliUnits.hashCode ^ unit.hashCode;

  @override
  String toString() {
    if (milliUnits % precisionFactor == 0) {
      return '${milliUnits ~/ precisionFactor} ${unit.displayNameAr}';
    }
    return '${toDouble().toStringAsFixed(3)} ${unit.displayNameAr}';
  }
}
