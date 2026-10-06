import '../entities/ledger_entry.dart';
import '../entities/financial_transaction.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

/// مدقق القيد المزدوج المحاسبي الصارم (Double-Entry Balance & Invariant Validator)
class DoubleEntryValidator {
  const DoubleEntryValidator();

  /// التحقق الصارم من توازن القيود: مجموع المدين == مجموع الدائن
  static void validateTransactionEntries(List<LedgerEntry> entries) {
    if (entries.isEmpty) {
      throw const SecurityViolationException(
        'لا يمكن تنفيذ معاملة مالية بدون قيود دفتر أستاذ',
        type: SecurityViolationType.unauthorizedFinancialMutation,
      );
    }

    if (entries.length < 2) {
      throw const SecurityViolationException(
        'نظام القيد المزدوج يتطلب قيدين على الأقل (مدين ودائن)',
        type: SecurityViolationType.unauthorizedFinancialMutation,
      );
    }

    int totalDebits = 0;
    int totalCredits = 0;

    for (final entry in entries) {
      // 1. فحص سلامة المبلغ
      if (entry.amount <= 0) {
        throw SecurityViolationException(
          'مبلغ القيد المحاسبي (${entry.id}) يجب أن يكون أكبر من الصفر: ${entry.amount}',
          type: SecurityViolationType.unauthorizedFinancialMutation,
          fieldName: 'amount',
        );
      }

      if (entry.accountId.trim().isEmpty) {
        throw SecurityViolationException(
          'معرّف الحساب المالي مفقود في القيد (${entry.id})',
          type: SecurityViolationType.tamperedPayload,
          fieldName: 'accountId',
        );
      }

      if (entry.isDebit) {
        totalDebits += entry.amount;
      } else if (entry.isCredit) {
        totalCredits += entry.amount;
      }
    }

    // 2. التحقق الجوهري من توازن القيد المزدوج
    if (totalDebits != totalCredits) {
      throw SecurityViolationException(
        'اختلال في توازن القيد المزدوج: إجمالي المدين ($totalDebits) != إجمالي الدائن ($totalCredits)',
        type: SecurityViolationType.unauthorizedFinancialMutation,
      );
    }
  }

  /// التحقق من سلامة المعاملة المالية بالكامل
  static void validateTransaction(FinancialTransaction transaction) {
    if (transaction.idempotencyKey.trim().length < 8) {
      throw const SecurityViolationException(
        'مفتاح عدم التكرار (Idempotency Key) غير صالح في المعاملة المالية',
        type: SecurityViolationType.invalidIdempotency,
      );
    }

    validateTransactionEntries(transaction.entries);

    if (transaction.totalAmount <= 0) {
      throw const SecurityViolationException(
        'المبلغ الإجمالي للمعاملة يجب أن يكون أكبر من الصفر',
        type: SecurityViolationType.unauthorizedFinancialMutation,
      );
    }
  }
}
