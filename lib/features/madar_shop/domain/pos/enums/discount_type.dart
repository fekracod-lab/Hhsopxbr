// أنواع الخصومات في نقطة البيع (MADAR SHOP Discount Type)
// Pure Dart — Zero UI Dependencies

enum DiscountType {
  percentage,
  fixed;

  String toDbString() {
    switch (this) {
      case DiscountType.percentage:
        return 'percentage';
      case DiscountType.fixed:
        return 'fixed';
    }
  }
}
