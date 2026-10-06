import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';
import 'idempotency_engine.dart';

/// محرك السلامة المالية ومنع الخصم المزدوج والأرصدة السالبة (Financial Integrity Engine)
class FinancialIntegrityEngine {
  final IdempotencyEngine idempotencyEngine;
  final Map<String, int> _walletBalances = {}; // walletId -> balance in minor units (IQD fils / cents)
  final Set<String> _processedTransactions = {};
  final Map<String, int> _couponRedemptions = {}; // couponCode -> count
  final Map<String, int> _refundedAmounts = {}; // originalTxId -> totalRefundedSoFar

  FinancialIntegrityEngine({IdempotencyEngine? idempotencyEngine})
      : idempotencyEngine = idempotencyEngine ?? IdempotencyEngine();

  Map<String, int> get walletBalances => Map.unmodifiable(_walletBalances);

  void setInitialBalance(String walletId, int balanceMinor) {
    _walletBalances[walletId] = balanceMinor;
  }

  int getBalance(String walletId) => _walletBalances[walletId] ?? 0;

  /// الخصم الذري المحمي من المحفظة مع ضمان عدم الوصول لرصيد سالب (Atomic Safe Debit)
  Future<(int newBalance, bool success, String? error)> atomicWalletDebit({
    required String walletId,
    required int amountMinor,
    required String transactionId,
    required String idempotencyKey,
  }) async {
    if (amountMinor <= 0) {
      throw const SecurityViolationException(
        'Financial debit amount must be strictly positive',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'amountMinor',
      );
    }

    return idempotencyEngine.executeIdempotent<(int, bool, String?)>(
      idempotencyKey: idempotencyKey,
      operation: () async {
        if (_processedTransactions.contains(transactionId)) {
          throw SecurityViolationException(
            'Duplicate financial transaction ID detected: $transactionId',
            type: SecurityViolationType.invalidIdempotency,
            fieldName: 'transactionId',
          );
        }

        final currentBalance = _walletBalances[walletId] ?? 0;

        // فحص كفاية الرصيد ومنع الرصيد السالب بشكل قطعي (Zero Negative Balance Guarantee)
        if (currentBalance < amountMinor) {
          return (currentBalance, false, 'Insufficient wallet balance. Requested: $amountMinor, Available: $currentBalance');
        }

        final updatedBalance = currentBalance - amountMinor;
        _walletBalances[walletId] = updatedBalance;
        _processedTransactions.add(transactionId);

        return (updatedBalance, true, null);
      },
    );
  }

  /// الإيداع الذري المحمي في المحفظة (Atomic Safe Credit)
  Future<(int newBalance, bool success, String? error)> atomicWalletCredit({
    required String walletId,
    required int amountMinor,
    required String transactionId,
    required String idempotencyKey,
  }) async {
    if (amountMinor <= 0) {
      throw const SecurityViolationException(
        'Financial credit amount must be strictly positive',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'amountMinor',
      );
    }

    return idempotencyEngine.executeIdempotent<(int, bool, String?)>(
      idempotencyKey: idempotencyKey,
      operation: () async {
        if (_processedTransactions.contains(transactionId)) {
          throw SecurityViolationException(
            'Duplicate financial transaction ID detected: $transactionId',
            type: SecurityViolationType.invalidIdempotency,
            fieldName: 'transactionId',
          );
        }

        final currentBalance = _walletBalances[walletId] ?? 0;
        final updatedBalance = currentBalance + amountMinor;
        _walletBalances[walletId] = updatedBalance;
        _processedTransactions.add(transactionId);

        return (updatedBalance, true, null);
      },
    );
  }

  /// استرجاع الأموال الذري مع منع الاسترجاع المزدوج أو تجاوز المبلغ الأصلي (Atomic Safe Refund)
  Future<(bool success, String? error)> atomicRefund({
    required String originalTransactionId,
    required int originalAmountMinor,
    required int refundAmountMinor,
    required String refundTransactionId,
    required String idempotencyKey,
  }) async {
    if (refundAmountMinor <= 0 || refundAmountMinor > originalAmountMinor) {
      throw const SecurityViolationException(
        'Refund amount must be positive and cannot exceed original transaction amount',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'refundAmountMinor',
      );
    }

    return idempotencyEngine.executeIdempotent<(bool, String?)>(
      idempotencyKey: idempotencyKey,
      operation: () async {
        final alreadyRefunded = _refundedAmounts[originalTransactionId] ?? 0;

        if (alreadyRefunded + refundAmountMinor > originalAmountMinor) {
          return (false, 'Total refund amount would exceed original transaction amount');
        }

        _refundedAmounts[originalTransactionId] = alreadyRefunded + refundAmountMinor;
        _processedTransactions.add(refundTransactionId);

        return (true, null);
      },
    );
  }

  /// استهلاك القسيمة ذرياً مع منع تجاوز الحد الأقصى للاستخدام تحت التزامن (Atomic Coupon Redemption)
  Future<(bool success, String? error)> atomicCouponRedeem({
    required String couponCode,
    required String userId,
    required int maxGlobalUses,
    required String idempotencyKey,
  }) async {
    return idempotencyEngine.executeIdempotent<(bool, String?)>(
      idempotencyKey: idempotencyKey,
      operation: () async {
        final currentUses = _couponRedemptions[couponCode] ?? 0;

        if (currentUses >= maxGlobalUses) {
          return (false, 'Coupon global usage limit ($maxGlobalUses) reached');
        }

        _couponRedemptions[couponCode] = currentUses + 1;
        return (true, null);
      },
    );
  }

  void reset() {
    _walletBalances.clear();
    _processedTransactions.clear();
    _couponRedemptions.clear();
    _refundedAmounts.clear();
  }
}
