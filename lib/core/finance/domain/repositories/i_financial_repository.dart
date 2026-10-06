import '../entities/financial_account.dart';
import '../entities/financial_transaction.dart';
import '../entities/ledger_entry.dart';
import '../entities/settlement_entity.dart';
import '../entities/refund_ledger_record.dart';
import '../enums/financial_enums.dart';

/// العقد التجريدي لمستودع العمليات ودفتر الأستاذ المالي (IFinancialRepository)
abstract class IFinancialRepository {
  /// جلب حساب مالي بمعرّف الحساب
  Future<FinancialAccount?> getAccount(String accountId);

  /// جلب أو إنشاء حساب مالي لمالك محدد
  Future<FinancialAccount> getOrCreateAccount(String ownerId, FinancialAccountType type);

  /// تنفيذ معاملة مالية ذرية وتوثيق قيود دفتر الأستاذ
  Future<FinancialTransaction> executeTransaction(FinancialTransaction transaction);

  /// توثيق تسوية مالية متعددة الأطراف
  Future<SettlementEntity> recordSettlement(SettlementEntity settlement);

  /// معالجة وتوثيق استرداد مالي
  Future<RefundLedgerRecord> processRefund(RefundLedgerRecord refundRecord);

  /// جلب سجل قيود دفتر الأستاذ لحساب معين
  Future<List<LedgerEntry>> getAccountLedgerEntries(String accountId, {int limit = 50});

  /// التحقق من مفتاح عدم التكرار
  Future<bool> verifyIdempotencyKey(String idempotencyKey);
}
