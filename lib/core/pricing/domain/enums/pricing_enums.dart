/// نوع الخدمة في محرك التسعير
enum PricingServiceType {
  taxi('taxi'),
  food('food'),
  store('store'),
  mersal('mersal');

  final String key;
  const PricingServiceType(this.key);

  static PricingServiceType fromString(String? val) {
    if (val == null || val.isEmpty) return PricingServiceType.food;
    final normalized = val.trim().toLowerCase();
    for (final type in PricingServiceType.values) {
      if (type.key == normalized) return type;
    }
    return PricingServiceType.food;
  }
}

/// مستوى زيادة الطلب (Surge Level)
enum SurgeLevel {
  normal('normal', 1.0),
  elevated('elevated', 1.2),
  high('high', 1.4),
  veryHigh('very_high', 1.7),
  critical('critical', 2.0);

  final String key;
  final double defaultMultiplier;
  const SurgeLevel(this.key, this.defaultMultiplier);

  static SurgeLevel fromMultiplier(double multiplier) {
    if (multiplier <= 1.05) return SurgeLevel.normal;
    if (multiplier <= 1.25) return SurgeLevel.elevated;
    if (multiplier <= 1.55) return SurgeLevel.high;
    if (multiplier <= 1.85) return SurgeLevel.veryHigh;
    return SurgeLevel.critical;
  }
}

/// وحدة التقريب المالي بالدينار العراقي (IQD Rounding Unit)
enum RoundingUnit {
  none(1),
  fifty(50),
  hundred(100),
  twoFifty(250),
  fiveHundred(500);

  final int value;
  const RoundingUnit(this.value);
}

/// تصنيف حجم الطرد في خدمة مرسال
enum PackageSize {
  small('small', 0),
  medium('medium', 500),
  large('large', 1500),
  bulk('bulk', 3000);

  final String key;
  final int defaultSurcharge; // IQD
  const PackageSize(this.key, this.defaultSurcharge);

  static PackageSize fromString(String? val) {
    if (val == null || val.isEmpty) return PackageSize.small;
    final normalized = val.trim().toLowerCase();
    for (final size in PackageSize.values) {
      if (size.key == normalized) return size;
    }
    return PackageSize.small;
  }
}
