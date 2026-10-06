// سياسة استلام كميات فائضة عن أمر الشراء (MADAR SHOP Over Receiving Policy)
// Pure Dart — Zero UI Dependencies

enum OverReceivingPolicy {
  /// منع الاستلام الزائد تماماً (الافتراضي الصارم)
  block,

  /// السماح بالاستلام الزائد فقط عند وجود موافقة صريحة
  allowWithApproval,

  /// السماح بالاستلام الزائد دون قيود
  allow;

  bool get isBlock => this == OverReceivingPolicy.block;
  bool get isAllowWithApproval => this == OverReceivingPolicy.allowWithApproval;
  bool get isAllow => this == OverReceivingPolicy.allow;

  static OverReceivingPolicy fromString(String? value) {
    if (value == null) return OverReceivingPolicy.block;
    switch (value.trim().toLowerCase()) {
      case 'allowwithapproval':
      case 'allow_with_approval':
        return OverReceivingPolicy.allowWithApproval;
      case 'allow':
        return OverReceivingPolicy.allow;
      case 'block':
      default:
        return OverReceivingPolicy.block;
    }
  }
}
