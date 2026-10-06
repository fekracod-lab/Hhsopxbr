// طرق تسعير وتكلفة المخزون المعتمدة (MADAR SHOP Inventory Costing Method Enum)
// Pure Dart — Zero UI Dependencies

enum CostingMethod {
  /// المتوسط المرجح التراكمي للتكلفة (Weighted Average Cost)
  weightedAverage,

  /// الوارد أولاً يصرف أولاً (First-In, First-Out عبر طبقات التكلفة)
  fifo;

  bool get isWeightedAverage => this == CostingMethod.weightedAverage;
  bool get isFifo => this == CostingMethod.fifo;

  static CostingMethod fromString(String? val) {
    if (val == null) return CostingMethod.weightedAverage;
    switch (val.trim().toLowerCase()) {
      case 'fifo':
        return CostingMethod.fifo;
      case 'weighted_average':
      case 'weightedaverage':
      case 'average':
      default:
        return CostingMethod.weightedAverage;
    }
  }
}
