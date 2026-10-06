// كائن قيمة النقود الحسابية الدقيقة المقاومة للانحراف العشري (MADAR SHOP Money Value Object)
// Pure Dart — Zero UI Dependencies

import 'dart:math' as math;
import 'currency.dart';

class Money implements Comparable<Money> {
  final int minorUnits;
  final Currency currency;

  const Money._(this.minorUnits, this.currency);

  /// إنشاء مبلغ من الوحدات الصغرى (مثلاً بالفلس أو بأصغر وحدة نقدية)
  const Money.fromMinorUnits(this.minorUnits, [this.currency = Currency.iqd]);

  /// إنشاء كائن نقدي من قيمة عشرية مع التحويل الحسابي الآمن لمنع تشوهات الفاصلة العائمة
  factory Money.fromAmount(double amount, [Currency currency = Currency.iqd]) {
    if (amount.isNaN || amount.isInfinite) {
      throw ArgumentError('قيمة المبلغ غير صالحة (NaN أو Infinite).');
    }
    final factor = math.pow(10, currency.decimalDigits).toInt();
    final units = (amount * factor).round();
    return Money._(units, currency);
  }

  /// مبلغ صفر
  factory Money.zero([Currency currency = Currency.iqd]) => Money._(0, currency);

  /// تحويل الوحدات الصغرى إلى قيمة عشرية قابلة للعرض
  double toAmount() {
    final factor = math.pow(10, currency.decimalDigits).toDouble();
    return minorUnits / factor;
  }

  // ─── العمليات الحسابية الآمنة ───

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money._(minorUnits + other.minorUnits, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money._(minorUnits - other.minorUnits, currency);
  }

  Money operator *(num factor) {
    if (factor.isNaN || factor.isInfinite) {
      throw ArgumentError('معامل الضرب غير صالح.');
    }
    return Money._((minorUnits * factor).round(), currency);
  }

  Money operator -() {
    return Money._(-minorUnits, currency);
  }

  // ─── المقارنات ───

  bool operator <(Money other) {
    _assertSameCurrency(other);
    return minorUnits < other.minorUnits;
  }

  bool operator <=(Money other) {
    _assertSameCurrency(other);
    return minorUnits <= other.minorUnits;
  }

  bool operator >(Money other) {
    _assertSameCurrency(other);
    return minorUnits > other.minorUnits;
  }

  bool operator >=(Money other) {
    _assertSameCurrency(other);
    return minorUnits >= other.minorUnits;
  }

  bool get isZero => minorUnits == 0;
  bool get isPositive => minorUnits > 0;
  bool get isNegative => minorUnits < 0;

  /// تقريب المبلغ لمضاعفات معينة (مثل التقريب لأقرب 250 دينار عراقي في الدفع النقدي)
  Money roundToNearest(int stepInMinorUnits) {
    if (stepInMinorUnits <= 0) return this;
    final remainder = minorUnits % stepInMinorUnits;
    if (remainder == 0) return this;
    if (remainder >= stepInMinorUnits / 2) {
      return Money._(minorUnits + (stepInMinorUnits - remainder), currency);
    } else {
      return Money._(minorUnits - remainder, currency);
    }
  }

  void _assertSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
        'لا يمكن إجراء عمليات حسابية بين عملتين مختلفتين: ${currency.code} و ${other.currency.code}',
      );
    }
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          runtimeType == other.runtimeType &&
          minorUnits == other.minorUnits &&
          currency == other.currency;

  @override
  int get hashCode => minorUnits.hashCode ^ currency.hashCode;

  @override
  String toString() {
    if (currency.decimalDigits == 0) {
      return '$minorUnits ${currency.symbol}';
    }
    return '${toAmount().toStringAsFixed(currency.decimalDigits)} ${currency.symbol}';
  }
}
