// سياسة التعامل مع المخزون السالب (MADAR SHOP Negative Stock Policy)
// Pure Dart — Zero UI Dependencies

enum NegativeStockPolicy {
  block,     // منع أي حركة تؤدي إلى رصيد سالب منعاً باتاً (الافتراضي الصارم)
  allow,     // السماح بالرصيد السالب مع توثيق الفارق
  backorder; // تحويل العجز إلى طلب توريد مؤجل

  String toDbString() {
    switch (this) {
      case NegativeStockPolicy.block:
        return 'block';
      case NegativeStockPolicy.allow:
        return 'allow';
      case NegativeStockPolicy.backorder:
        return 'backorder';
    }
  }

  static NegativeStockPolicy fromString(String? val) {
    if (val == null) return NegativeStockPolicy.block;
    switch (val.trim().toLowerCase()) {
      case 'allow':
        return NegativeStockPolicy.allow;
      case 'backorder':
        return NegativeStockPolicy.backorder;
      case 'block':
      default:
        return NegativeStockPolicy.block;
    }
  }
}
