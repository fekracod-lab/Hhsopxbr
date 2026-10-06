// مستودع استرداد الأموال في الذاكرة (MADAR SHOP Memory Refund Repository)
// Pure Dart — Zero UI Dependencies

import '../../../domain/returns/entities/refund.dart';
import '../../../domain/returns/repositories/i_refund_repository.dart';

class MemoryRefundRepository implements IRefundRepository {
  final Map<String, Refund> _store = {};

  @override
  Future<Refund?> getRefundById({required String refundId}) async {
    return _store[refundId];
  }

  @override
  Future<List<Refund>> getRefundsForReturn({required String returnId}) async {
    return _store.values.where((r) => r.returnId == returnId).toList();
  }

  @override
  Future<List<Refund>> getRefundsForSale({required String saleId}) async {
    return _store.values.where((r) => r.saleId == saleId).toList();
  }

  @override
  Future<void> saveRefund(Refund refund) async {
    _store[refund.id] = refund;
  }

  void clear() => _store.clear();
}
