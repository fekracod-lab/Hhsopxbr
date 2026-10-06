import '../../domain/entities/financial_account.dart';
import '../../domain/entities/financial_transaction.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../domain/entities/settlement_entity.dart';
import '../../domain/entities/refund_ledger_record.dart';
import '../../domain/enums/financial_enums.dart';
import '../../domain/repositories/i_financial_repository.dart';
import '../datasources/financial_remote_datasource.dart';

/// تطبيق مستودع العمليات المالية ودفتر الأستاذ (FinancialRepository)
class FinancialRepository implements IFinancialRepository {
  final FinancialRemoteDatasource _remoteDatasource;

  FinancialRepository({FinancialRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? FinancialRemoteDatasource();

  @override
  Future<FinancialAccount?> getAccount(String accountId) {
    return _remoteDatasource.getAccount(accountId);
  }

  @override
  Future<FinancialAccount> getOrCreateAccount(String ownerId, FinancialAccountType type) {
    return _remoteDatasource.getOrCreateAccount(ownerId, type);
  }

  @override
  Future<FinancialTransaction> executeTransaction(FinancialTransaction transaction) {
    return _remoteDatasource.executeTransaction(transaction);
  }

  @override
  Future<SettlementEntity> recordSettlement(SettlementEntity settlement) {
    return _remoteDatasource.recordSettlement(settlement);
  }

  @override
  Future<RefundLedgerRecord> processRefund(RefundLedgerRecord refundRecord) {
    return _remoteDatasource.processRefund(refundRecord);
  }

  @override
  Future<List<LedgerEntry>> getAccountLedgerEntries(String accountId, {int limit = 50}) {
    return _remoteDatasource.getAccountLedgerEntries(accountId, limit: limit);
  }

  @override
  Future<bool> verifyIdempotencyKey(String idempotencyKey) {
    return _remoteDatasource.verifyIdempotencyKey(idempotencyKey);
  }
}
