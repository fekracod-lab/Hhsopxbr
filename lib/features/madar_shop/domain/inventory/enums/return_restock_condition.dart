// تصنيف حالة البضاعة المرتجعة لإعادة التخزين (MADAR SHOP Return Restock Condition Enum)
// Pure Dart — Zero UI Dependencies

enum ReturnRestockCondition {
  restock,       // سليم وصالح لإعادة التخزين والبيع المباشر
  damaged,       // تالف (يسجل حركة إتلاف ولا يضاف للمخزون الصالح)
  expired,       // منتهي الصلاحية
  nonResellable; // غير قابل لإعادة البيع لأسباب صحية أو فنية

  String toDbString() {
    switch (this) {
      case ReturnRestockCondition.restock:
        return 'restock';
      case ReturnRestockCondition.damaged:
        return 'damaged';
      case ReturnRestockCondition.expired:
        return 'expired';
      case ReturnRestockCondition.nonResellable:
        return 'non_resellable';
    }
  }

  bool get isRestockable => this == ReturnRestockCondition.restock;
}
