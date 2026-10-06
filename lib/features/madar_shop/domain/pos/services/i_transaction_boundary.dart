// تجريد الحدود الذرية للمعاملات (MADAR SHOP POS Transaction Boundary Abstraction)
// Pure Dart — Zero UI Dependencies

abstract class ITransactionBoundary {
  /// تنفيذ مجموعة من العمليات داخل نطاق معاملاتي ذري
  Future<T> runTransaction<T>(Future<T> Function() operation);
}

class DefaultLocalTransactionBoundary implements ITransactionBoundary {
  const DefaultLocalTransactionBoundary();

  @override
  Future<T> runTransaction<T>(Future<T> Function() operation) async {
    return await operation();
  }
}
