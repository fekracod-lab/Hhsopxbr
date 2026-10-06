// عقد مستودع استرداد الأموال (MADAR SHOP Refund Repository Interface)
// Pure Dart — Zero UI Dependencies

import '../entities/refund.dart';

abstract class IRefundRepository {
  Future<Refund?> getRefundById({
    required String refundId,
  });

  Future<List<Refund>> getRefundsForReturn({
    required String returnId,
  });

  Future<List<Refund>> getRefundsForSale({
    required String saleId,
  });

  Future<void> saveRefund(Refund refund);
}
