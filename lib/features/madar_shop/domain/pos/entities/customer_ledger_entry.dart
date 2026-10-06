// قيد دفتر الأستاذ للعميل في البيع الآجل (MADAR SHOP Customer Ledger Entry)
// Pure Dart — Zero UI Dependencies

import '../value_objects/money.dart';

class CustomerLedgerEntry {
  final String entryId;
  final String customerId;
  final String saleId;
  final String businessId;
  final String branchId;
  final Money debit; // المبلغ المستحق (إجمالي الفاتورة المطلوب)
  final Money credit; // المبلغ المقبوض فعلياً
  final Money balanceDelta; // صافي التغير في الذمة = debit - credit
  final DateTime timestamp;
  final String reason;
  final Map<String, dynamic> metadata;

  const CustomerLedgerEntry({
    required this.entryId,
    required this.customerId,
    required this.saleId,
    required this.businessId,
    required this.branchId,
    required this.debit,
    required this.credit,
    required this.balanceDelta,
    required this.timestamp,
    required this.reason,
    this.metadata = const {},
  });

  /// إنشاء قيد ذمة جديد ناتج عن بيع آجل
  factory CustomerLedgerEntry.fromCreditSale({
    required String entryId,
    required String customerId,
    required String saleId,
    required String businessId,
    required String branchId,
    required Money grandTotal,
    required Money immediatePaid,
    required Money creditBalance,
    String? note,
  }) {
    return CustomerLedgerEntry(
      entryId: entryId,
      customerId: customerId,
      saleId: saleId,
      businessId: businessId,
      branchId: branchId,
      debit: grandTotal,
      credit: immediatePaid,
      balanceDelta: creditBalance,
      timestamp: DateTime.now(),
      reason: note ?? 'شراء آجل بموجب فاتورة نقطة البيع #$saleId',
    );
  }

  /// إنشاء قيد رصيد دائن ناتج عن استرجاع بضاعة بحساب العميل
  factory CustomerLedgerEntry.fromRefundCredit({
    required String entryId,
    required String customerId,
    required String returnId,
    required String businessId,
    required String branchId,
    required Money refundAmount,
    String? note,
  }) {
    return CustomerLedgerEntry(
      entryId: entryId,
      customerId: customerId,
      saleId: returnId,
      businessId: businessId,
      branchId: branchId,
      debit: Money.zero(refundAmount.currency),
      credit: refundAmount,
      balanceDelta: -refundAmount,
      timestamp: DateTime.now(),
      reason: note ?? 'رصيد دائن ناتج عن مرتجع مبيعات #$returnId',
      metadata: {'referenceType': 'RETURN_REFUND', 'returnId': returnId},
    );
  }
}
