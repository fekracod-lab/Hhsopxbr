// واجهة مستودع عمليات نقطة البيع (MADAR SHOP POS Repository Contract)
// Pure Dart — Zero UI Dependencies

import '../entities/customer_ledger_entry.dart';
import '../entities/inventory_movement_intent.dart';
import '../entities/receipt_snapshot.dart';
import '../entities/sale.dart';

abstract class IShopPosRepository {
  /// حفظ معاملة البيع المكتملة
  Future<void> saveSale(Sale sale);

  /// استرجاع معاملة بيع بالمعرف
  Future<Sale?> getSaleById({
    required String businessId,
    required String branchId,
    required String saleId,
  });

  /// حفظ قيد دفتر الأستاذ للعميل في البيع الآجل
  Future<void> recordCustomerLedgerEntry(CustomerLedgerEntry entry);

  /// تسجيل نية حركة المخزون الناتجة عن عملية البيع
  Future<void> recordInventoryMovementIntent(InventoryMovementIntent intent);

  /// حفظ لقطة الإيصال الجاهزة للطباعة
  Future<void> saveReceiptSnapshot(ReceiptSnapshot receipt);

  /// استرجاع مبيعات الجلسة الحالية
  Future<List<Sale>> getSalesForSession({
    required String businessId,
    required String branchId,
    required String sessionId,
  });

  /// استرجاع المبيعات مع إمكانية الفلترة للفرع والفترة الزمنية
  Future<List<Sale>> getSales({
    required String businessId,
    String? branchId,
    DateTime? from,
    DateTime? to,
  });
}
