import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/financial_account.dart';
import '../../domain/entities/financial_transaction.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../domain/entities/settlement_entity.dart';
import '../../domain/entities/refund_ledger_record.dart';
import '../../domain/enums/financial_enums.dart';
import '../../domain/services/double_entry_validator.dart';
import '../../domain/services/financial_invariant_checker.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

/// مصدر البيانات البعيد للعمليات المالية ودفتر الأستاذ (Financial Remote Datasource)
class FinancialRemoteDatasource {
  final FirebaseFirestore? _customFirestore;

  FinancialRemoteDatasource({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  /// جلب حساب مالي
  Future<FinancialAccount?> getAccount(String accountId) async {
    final doc = await _firestore.collection('financial_accounts').doc(accountId).get();
    if (!doc.exists || doc.data() == null) return null;
    return FinancialAccount.fromMap(doc.data()!, doc.id);
  }

  /// جلب أو إنشاء حساب مالي
  Future<FinancialAccount> getOrCreateAccount(String ownerId, FinancialAccountType type) async {
    final accountId = 'acc_${type.key}_$ownerId';
    final doc = await _firestore.collection('financial_accounts').doc(accountId).get();

    if (doc.exists && doc.data() != null) {
      return FinancialAccount.fromMap(doc.data()!, doc.id);
    }

    final newAccount = FinancialAccount(
      accountId: accountId,
      ownerId: ownerId,
      accountType: type,
      availableBalance: 0,
      pendingBalance: 0,
      heldBalance: 0,
      debt: 0,
      currency: 'IQD',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestore.collection('financial_accounts').doc(accountId).set(newAccount.toMap());
    return newAccount;
  }

  /// تنفيذ معاملة مالية ذرية مع توثيق قيود دفتر الأستاذ (Atomic Double-Entry Execution)
  Future<FinancialTransaction> executeTransaction(FinancialTransaction transaction) async {
    // 1. التحقق الصارم من توازن القيد المزدوج
    DoubleEntryValidator.validateTransaction(transaction);

    // 2. التحقق من عدم التكرار
    final isUnique = await verifyIdempotencyKey(transaction.idempotencyKey);
    if (!isUnique) {
      throw const SecurityViolationException(
        'تم تنفيذ هذه المعاملة المالية مسبقاً بنفس مفتاح المعاملة',
        type: SecurityViolationType.invalidIdempotency,
      );
    }

    final txDocRef = _firestore.collection('wallet_transactions').doc(transaction.id);

    // 3. التنفيذ الذري في Transaction واحدة
    await _firestore.runTransaction((tx) async {
      // أ. قراءة كافة الحسابات المعنية بالقيد
      final accountDocs = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final entry in transaction.entries) {
        if (!accountDocs.containsKey(entry.accountId)) {
          final docRef = _firestore.collection('financial_accounts').doc(entry.accountId);
          final snap = await tx.get(docRef);
          accountDocs[entry.accountId] = snap;
        }
      }

      // ب. تحديث الأرصدة والتحقق من عدم السحب على المكشوف
      for (final entry in transaction.entries) {
        final snap = accountDocs[entry.accountId];
        final currentAccount = (snap != null && snap.exists && snap.data() != null)
            ? FinancialAccount.fromMap(snap.data()!, snap.id)
            : FinancialAccount(
                accountId: entry.accountId,
                ownerId: entry.ownerId,
                accountType: entry.accountType,
                availableBalance: 0,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

        int updatedBalance = currentAccount.availableBalance;
        if (entry.isDebit) {
          if (updatedBalance < entry.amount && entry.accountType == FinancialAccountType.customer) {
            throw SecurityViolationException(
              'الرصيد المتاح غير كافٍ لإتمام عملية الخصم (${entry.amount} د.ع)',
              type: SecurityViolationType.unauthorizedFinancialMutation,
              fieldName: 'availableBalance',
            );
          }
          updatedBalance -= entry.amount;
        } else if (entry.isCredit) {
          updatedBalance += entry.amount;
        }

        final updatedAccount = currentAccount.copyWith(
          availableBalance: updatedBalance,
          updatedAt: DateTime.now(),
        );

        FinancialInvariantChecker.assertAccountInvariants(updatedAccount);

        final docRef = _firestore.collection('financial_accounts').doc(entry.accountId);
        tx.set(docRef, updatedAccount.toMap(), SetOptions(merge: true));

        // ج. كتابة قيد دفتر الأستاذ غير القابل للتعديل
        final ledgerDocRef = _firestore.collection('platform_ledger').doc(entry.id);
        tx.set(ledgerDocRef, entry.toMap());
      }

      // د. حفظ بيانات المعاملة المكتملة
      final completedTx = transaction.copyWith(
        status: FinancialTransactionStatus.committed,
        completedAt: DateTime.now(),
      );
      tx.set(txDocRef, completedTx.toMap());
    });

    return transaction.copyWith(
      status: FinancialTransactionStatus.committed,
      completedAt: DateTime.now(),
    );
  }

  /// توثيق تسوية مالية
  Future<SettlementEntity> recordSettlement(SettlementEntity settlement) async {
    final docRef = _firestore.collection('settlements').doc(settlement.id);
    final isUnique = await verifyIdempotencyKey(settlement.idempotencyKey);
    if (!isUnique) {
      throw const SecurityViolationException(
        'تم توثيق هذه التسوية المالية مسبقاً',
        type: SecurityViolationType.invalidIdempotency,
      );
    }

    final settled = SettlementEntity(
      id: settlement.id,
      orderId: settlement.orderId,
      orderSource: settlement.orderSource,
      customerId: settlement.customerId,
      driverId: settlement.driverId,
      merchantId: settlement.merchantId,
      grossOrderAmount: settlement.grossOrderAmount,
      deliveryFee: settlement.deliveryFee,
      merchantAmount: settlement.merchantAmount,
      driverAmount: settlement.driverAmount,
      platformCommission: settlement.platformCommission,
      paymentMethod: settlement.paymentMethod,
      status: SettlementStatus.settled,
      idempotencyKey: settlement.idempotencyKey,
      createdAt: settlement.createdAt,
      settledAt: DateTime.now(),
    );

    await docRef.set(settled.toMap());
    return settled;
  }

  /// معالجة استرداد مالي
  Future<RefundLedgerRecord> processRefund(RefundLedgerRecord refundRecord) async {
    final docRef = _firestore.collection('refund_ledger_records').doc(refundRecord.id);
    await docRef.set(refundRecord.toMap());
    return refundRecord;
  }

  /// جلب قيود دفتر الأستاذ لحساب
  Future<List<LedgerEntry>> getAccountLedgerEntries(String accountId, {int limit = 50}) async {
    final snap = await _firestore
        .collection('platform_ledger')
        .where('accountId', isEqualTo: accountId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((doc) => LedgerEntry.fromMap(doc.data(), doc.id)).toList();
  }

  /// التحقق من مفتاح عدم التكرار
  Future<bool> verifyIdempotencyKey(String idempotencyKey) async {
    final docRef = _firestore.collection('idempotency_keys').doc(idempotencyKey);
    final doc = await docRef.get();
    if (doc.exists) {
      return false;
    }
    await docRef.set({
      'key': idempotencyKey,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return true;
  }
}
