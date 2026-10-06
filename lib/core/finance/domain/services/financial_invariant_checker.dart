import '../entities/financial_account.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

/// فاحص ثوابت الحسابات المالية (Financial Invariant Checker)
class FinancialInvariantChecker {
  const FinancialInvariantChecker();

  /// التحقق من سلامة وثوابت الحساب المالي
  static void assertAccountInvariants(FinancialAccount account) {
    if (account.availableBalance < 0) {
      throw SecurityViolationException(
        'انتهاك أمني: الرصيد المتاح في الحساب (${account.accountId}) أصبح سالباً: ${account.availableBalance}',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'availableBalance',
      );
    }

    if (account.heldBalance < 0) {
      throw SecurityViolationException(
        'انتهاك أمني: الرصيد المحجوز في الحساب (${account.accountId}) أصبح سالباً: ${account.heldBalance}',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'heldBalance',
      );
    }

    if (account.pendingBalance < 0) {
      throw SecurityViolationException(
        'انتهاك أمني: الرصيد المعلق في الحساب (${account.accountId}) أصبح سالباً: ${account.pendingBalance}',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'pendingBalance',
      );
    }

    if (account.debt < 0) {
      throw SecurityViolationException(
        'انتهاك أمني: حقل الديون في الحساب (${account.accountId}) أصبح سالباً: ${account.debt}',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'debt',
      );
    }
  }
}
