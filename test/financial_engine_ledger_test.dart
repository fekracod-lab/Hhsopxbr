import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/finance/domain/enums/financial_enums.dart';
import 'package:dalal_alqaim/core/finance/domain/entities/financial_account.dart';
import 'package:dalal_alqaim/core/finance/domain/entities/ledger_entry.dart';
import 'package:dalal_alqaim/core/finance/domain/entities/financial_transaction.dart';
import 'package:dalal_alqaim/core/finance/domain/entities/settlement_entity.dart';
import 'package:dalal_alqaim/core/finance/domain/entities/refund_ledger_record.dart';
import 'package:dalal_alqaim/core/finance/domain/services/double_entry_validator.dart';
import 'package:dalal_alqaim/core/finance/domain/services/settlement_calculator.dart';
import 'package:dalal_alqaim/core/finance/domain/services/refund_calculator.dart';
import 'package:dalal_alqaim/core/finance/domain/services/financial_invariant_checker.dart';
import 'package:dalal_alqaim/core/finance/domain/repositories/i_financial_repository.dart';
import 'package:dalal_alqaim/core/finance/application/financial_engine.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

class MockFinancialRepository implements IFinancialRepository {
  final Map<String, FinancialAccount> accounts = {};
  final List<FinancialTransaction> transactions = [];
  final List<SettlementEntity> settlements = [];
  final List<RefundLedgerRecord> refunds = [];
  final List<LedgerEntry> ledger = [];
  final Set<String> usedIdempotencyKeys = {};

  @override
  Future<FinancialAccount?> getAccount(String accountId) async {
    return accounts[accountId];
  }

  @override
  Future<FinancialAccount> getOrCreateAccount(String ownerId, FinancialAccountType type) async {
    final accountId = 'acc_${type.key}_$ownerId';
    if (accounts.containsKey(accountId)) {
      return accounts[accountId]!;
    }
    final acc = FinancialAccount(
      accountId: accountId,
      ownerId: ownerId,
      accountType: type,
      availableBalance: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    accounts[accountId] = acc;
    return acc;
  }

  @override
  Future<FinancialTransaction> executeTransaction(FinancialTransaction transaction) async {
    DoubleEntryValidator.validateTransaction(transaction);

    if (usedIdempotencyKeys.contains(transaction.idempotencyKey)) {
      throw const SecurityViolationException(
        'تم تنفيذ المعاملة مسبقاً بنفس مفتاح المعاملة',
        type: SecurityViolationType.invalidIdempotency,
      );
    }
    usedIdempotencyKeys.add(transaction.idempotencyKey);

    // Apply ledger entries to accounts
    for (final entry in transaction.entries) {
      final acc = accounts[entry.accountId] ??
          FinancialAccount(
            accountId: entry.accountId,
            ownerId: entry.ownerId,
            accountType: entry.accountType,
            availableBalance: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      int updated = acc.availableBalance;
      if (entry.isDebit) {
        if (updated < entry.amount && entry.accountType == FinancialAccountType.customer) {
          throw SecurityViolationException(
            'الرصيد المتاح غير كافٍ: $updated < ${entry.amount}',
            type: SecurityViolationType.unauthorizedFinancialMutation,
          );
        }
        updated -= entry.amount;
      } else if (entry.isCredit) {
        updated += entry.amount;
      }

      final newAcc = acc.copyWith(availableBalance: updated, updatedAt: DateTime.now());
      FinancialInvariantChecker.assertAccountInvariants(newAcc);
      accounts[entry.accountId] = newAcc;
      ledger.add(entry);
    }

    final completed = transaction.copyWith(
      status: FinancialTransactionStatus.committed,
      completedAt: DateTime.now(),
    );
    transactions.add(completed);
    return completed;
  }

  @override
  Future<SettlementEntity> recordSettlement(SettlementEntity settlement) async {
    settlements.add(settlement);
    return settlement;
  }

  @override
  Future<RefundLedgerRecord> processRefund(RefundLedgerRecord refundRecord) async {
    refunds.add(refundRecord);
    return refundRecord;
  }

  @override
  Future<List<LedgerEntry>> getAccountLedgerEntries(String accountId, {int limit = 50}) async {
    return ledger.where((e) => e.accountId == accountId).toList();
  }

  @override
  Future<bool> verifyIdempotencyKey(String idempotencyKey) async {
    if (usedIdempotencyKeys.contains(idempotencyKey)) {
      return false;
    }
    usedIdempotencyKeys.add(idempotencyKey);
    return true;
  }
}

void main() {
  group('Financial Engine & Unified Double-Entry Ledger Comprehensive Tests', () {
    // 1. Entities & Domain Models
    test('1. FinancialAccount creation, minor units arithmetic, and invariants', () {
      final now = DateTime.now();
      final account = FinancialAccount(
        accountId: 'acc_cus_123',
        ownerId: 'usr_123',
        accountType: FinancialAccountType.customer,
        availableBalance: 25000,
        heldBalance: 5000,
        debt: 0,
        createdAt: now,
        updatedAt: now,
      );

      expect(account.totalFunds, equals(30000));
      expect(account.hasSufficientFunds(20000), isTrue);
      expect(account.hasSufficientFunds(25000), isTrue);
      expect(account.hasSufficientFunds(25001), isFalse);
      expect(account.hasSufficientFunds(-100), isFalse);
      expect(account.hasSufficientFunds(0), isFalse);
    });

    test('2. LedgerEntry debit/credit flags and serialization', () {
      final entry = LedgerEntry(
        id: 'ent_1',
        transactionId: 'tx_1',
        accountId: 'acc_cus_1',
        ownerId: 'usr_1',
        accountType: FinancialAccountType.customer,
        entryType: LedgerEntryType.debit,
        amount: 12000,
        description: 'خصم قيمة الطلب',
        createdAt: DateTime.now(),
      );

      expect(entry.isDebit, isTrue);
      expect(entry.isCredit, isFalse);
      expect(entry.amount, equals(12000));
      final map = entry.toMap();
      expect(map['entryType'], equals('debit'));
      expect(map['amount'], equals(12000));
    });

    test('3. FinancialTransaction balance computation (isBalanced)', () {
      final now = DateTime.now();
      final balancedTx = FinancialTransaction(
        id: 'tx_100',
        idempotencyKey: 'idemp_100',
        category: TransactionCategory.orderPayment,
        entries: [
          LedgerEntry(
            id: 'e1',
            transactionId: 'tx_100',
            accountId: 'acc_cus_1',
            ownerId: 'u1',
            accountType: FinancialAccountType.customer,
            entryType: LedgerEntryType.debit,
            amount: 15000,
            description: 'خصم من العميل',
            createdAt: now,
          ),
          LedgerEntry(
            id: 'e2',
            transactionId: 'tx_100',
            accountId: 'acc_plt_1',
            ownerId: 'platform',
            accountType: FinancialAccountType.platform,
            entryType: LedgerEntryType.credit,
            amount: 15000,
            description: 'إيداع في المنصة',
            createdAt: now,
          ),
        ],
        totalAmount: 15000,
        createdAt: now,
      );

      expect(balancedTx.totalDebits, equals(15000));
      expect(balancedTx.totalCredits, equals(15000));
      expect(balancedTx.isBalanced, isTrue);

      final unbalancedTx = balancedTx.copyWith(
        entries: [
          balancedTx.entries.first,
          balancedTx.entries.last.copyWith(amount: 14000),
        ],
      );
      expect(unbalancedTx.isBalanced, isFalse);
    });

    test('4. SettlementEntity financial consistency verification', () {
      final validSettlement = SettlementEntity(
        id: 'stl_1',
        orderId: 'ord_1',
        orderSource: 'food',
        customerId: 'c1',
        driverId: 'd1',
        merchantId: 'm1',
        grossOrderAmount: 12000, // 10,000 items + 2,000 delivery
        deliveryFee: 2000,
        merchantAmount: 10000,
        driverAmount: 1500,
        platformCommission: 500,
        paymentMethod: 'wallet',
        idempotencyKey: 'idemp_stl_1',
        createdAt: DateTime.now(),
      );

      expect(validSettlement.isFinanciallyConsistent, isTrue);

      final inconsistentSettlement = SettlementEntity(
        id: 'stl_2',
        orderId: 'ord_2',
        orderSource: 'food',
        customerId: 'c1',
        grossOrderAmount: 12000,
        merchantAmount: 10000,
        driverAmount: 1000, // Missing 1000 IQD!
        platformCommission: 0,
        paymentMethod: 'wallet',
        idempotencyKey: 'idemp_stl_2',
        createdAt: DateTime.now(),
      );
      expect(inconsistentSettlement.isFinanciallyConsistent, isFalse);
    });

    // 2. DoubleEntryValidator
    test('5. DoubleEntryValidator rejects unbalanced debits != credits', () {
      final now = DateTime.now();
      final unbalancedEntries = [
        LedgerEntry(
          id: 'e1',
          transactionId: 'tx_unb',
          accountId: 'acc_1',
          ownerId: 'u1',
          accountType: FinancialAccountType.customer,
          entryType: LedgerEntryType.debit,
          amount: 10000,
          description: 'Debit',
          createdAt: now,
        ),
        LedgerEntry(
          id: 'e2',
          transactionId: 'tx_unb',
          accountId: 'acc_2',
          ownerId: 'u2',
          accountType: FinancialAccountType.platform,
          entryType: LedgerEntryType.credit,
          amount: 9000, // 1000 missing!
          description: 'Credit',
          createdAt: now,
        ),
      ];

      expect(
        () => DoubleEntryValidator.validateTransactionEntries(unbalancedEntries),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('6. DoubleEntryValidator rejects zero, negative, or single entries', () {
      final now = DateTime.now();
      expect(
        () => DoubleEntryValidator.validateTransactionEntries([]),
        throwsA(isA<SecurityViolationException>()),
      );

      final singleEntry = [
        LedgerEntry(
          id: 'e1',
          transactionId: 'tx_single',
          accountId: 'acc_1',
          ownerId: 'u1',
          accountType: FinancialAccountType.customer,
          entryType: LedgerEntryType.debit,
          amount: 5000,
          description: 'Single',
          createdAt: now,
        ),
      ];
      expect(
        () => DoubleEntryValidator.validateTransactionEntries(singleEntry),
        throwsA(isA<SecurityViolationException>()),
      );

      final negativeEntries = [
        LedgerEntry(
          id: 'e1',
          transactionId: 'tx_neg',
          accountId: 'acc_1',
          ownerId: 'u1',
          accountType: FinancialAccountType.customer,
          entryType: LedgerEntryType.debit,
          amount: -5000,
          description: 'Negative',
          createdAt: now,
        ),
        LedgerEntry(
          id: 'e2',
          transactionId: 'tx_neg',
          accountId: 'acc_2',
          ownerId: 'u2',
          accountType: FinancialAccountType.platform,
          entryType: LedgerEntryType.credit,
          amount: -5000,
          description: 'Negative',
          createdAt: now,
        ),
      ];
      expect(
        () => DoubleEntryValidator.validateTransactionEntries(negativeEntries),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    // 3. SettlementCalculator
    test('7. SettlementCalculator calculates delivery settlement with 500 IQD platform commission', () {
      final settlement = SettlementCalculator.calculateDeliverySettlement(
        orderId: 'ord_food_10',
        orderSource: 'food',
        customerId: 'cus_1',
        driverId: 'drv_1',
        merchantId: 'rest_1',
        subtotal: 18000,
        deliveryFee: 3000,
        paymentMethod: 'wallet',
        idempotencyKey: 'key_stl_10',
      );

      expect(settlement.grossOrderAmount, equals(21000));
      expect(settlement.merchantAmount, equals(18000));
      expect(settlement.platformCommission, equals(500));
      expect(settlement.driverAmount, equals(2500));
      expect(settlement.isFinanciallyConsistent, isTrue);
    });

    test('8. SettlementCalculator calculates taxi ride settlement with 10% commission', () {
      final taxiSettlement = SettlementCalculator.calculateTaxiSettlement(
        rideId: 'ride_99',
        customerId: 'cus_1',
        driverId: 'drv_taxi_1',
        grossFare: 10000,
        commissionRate: 0.10,
        paymentMethod: 'wallet',
        idempotencyKey: 'key_taxi_99',
      );

      expect(taxiSettlement.grossOrderAmount, equals(10000));
      expect(taxiSettlement.platformCommission, equals(1000));
      expect(taxiSettlement.driverAmount, equals(9000));
      expect(taxiSettlement.merchantAmount, equals(0));
      expect(taxiSettlement.isFinanciallyConsistent, isTrue);
    });

    // 4. RefundCalculator
    test('9. RefundCalculator permits valid partial and full refunds', () {
      final refund = RefundCalculator.calculateValidRefund(
        refundRequestId: 'req_1',
        orderId: 'ord_ref_1',
        orderSource: 'store',
        customerId: 'cus_1',
        requestedRefundAmount: 7000,
        requestedRefundPoints: 20,
        originalOrderAmount: 15000,
        totalPreviouslyRefundedAmount: 0,
        reason: 'منتج غير متوفر',
        idempotencyKey: 'ref_idemp_1',
      );

      expect(refund.refundAmount, equals(7000));
      expect(refund.refundPoints, equals(20));
      expect(refund.isValidRefundAmount, isTrue);
    });

    test('10. RefundCalculator strictly blocks over-refunding', () {
      expect(
        () => RefundCalculator.calculateValidRefund(
          refundRequestId: 'req_2',
          orderId: 'ord_ref_2',
          orderSource: 'store',
          customerId: 'cus_1',
          requestedRefundAmount: 10000,
          requestedRefundPoints: 0,
          originalOrderAmount: 15000,
          totalPreviouslyRefundedAmount: 10000, // Remaining is only 5,000!
          reason: 'استرداد مبالغ فيه',
          idempotencyKey: 'ref_idemp_2',
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    // 5. FinancialInvariantChecker
    test('11. FinancialInvariantChecker throws on negative availableBalance or heldBalance', () {
      final now = DateTime.now();
      final invalidAccount = FinancialAccount(
        accountId: 'acc_neg',
        ownerId: 'u_neg',
        accountType: FinancialAccountType.customer,
        availableBalance: -500,
        createdAt: now,
        updatedAt: now,
      );

      expect(
        () => FinancialInvariantChecker.assertAccountInvariants(invalidAccount),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    // 6. FinancialEngine End-to-End Orchestration
    test('12. FinancialEngine.executeOrderPayment deducts customer and credits platform atomically', () async {
      final mockRepo = MockFinancialRepository();
      final engine = FinancialEngine(repository: mockRepo);

      // Give customer initial 30,000 IQD
      final customerAcc = await mockRepo.getOrCreateAccount('cus_100', FinancialAccountType.customer);
      mockRepo.accounts[customerAcc.accountId] = customerAcc.copyWith(availableBalance: 30000);

      final tx = await engine.executeOrderPayment(
        orderId: 'ord_pay_1',
        orderSource: 'store',
        customerId: 'cus_100',
        amount: 12000,
      );

      expect(tx.status, equals(FinancialTransactionStatus.committed));
      expect(mockRepo.accounts[customerAcc.accountId]!.availableBalance, equals(18000));
      expect(mockRepo.accounts['acc_platform_madar_platform']!.availableBalance, equals(12000));
    });

    test('13. FinancialEngine.executeOrderPayment rejects when customer has insufficient balance', () async {
      final mockRepo = MockFinancialRepository();
      final engine = FinancialEngine(repository: mockRepo);

      final customerAcc = await mockRepo.getOrCreateAccount('cus_poor', FinancialAccountType.customer);
      mockRepo.accounts[customerAcc.accountId] = customerAcc.copyWith(availableBalance: 5000);

      expect(
        () => engine.executeOrderPayment(
          orderId: 'ord_fail',
          orderSource: 'store',
          customerId: 'cus_poor',
          amount: 12000,
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('14. FinancialEngine.executeSettlement distributes funds to Merchant, Driver, and Platform', () async {
      final mockRepo = MockFinancialRepository();
      final engine = FinancialEngine(repository: mockRepo);

      // Platform holds 21,000 IQD from customer payment
      final platformAcc = await mockRepo.getOrCreateAccount('madar_platform', FinancialAccountType.platform);
      mockRepo.accounts[platformAcc.accountId] = platformAcc.copyWith(availableBalance: 21000);

      final settlement = SettlementCalculator.calculateDeliverySettlement(
        orderId: 'ord_del_20',
        orderSource: 'food',
        customerId: 'cus_20',
        driverId: 'drv_20',
        merchantId: 'rest_20',
        subtotal: 18000,
        deliveryFee: 3000,
        paymentMethod: 'wallet',
        idempotencyKey: 'idemp_del_20',
      );

      final tx = await engine.executeSettlement(settlement: settlement);

      expect(tx.status, equals(FinancialTransactionStatus.committed));
      expect(mockRepo.accounts['acc_restaurant_rest_20']!.availableBalance, equals(18000));
      expect(mockRepo.accounts['acc_driver_drv_20']!.availableBalance, equals(2500));
      expect(mockRepo.accounts[platformAcc.accountId]!.availableBalance, equals(500)); // 21,000 - 18,000 - 2,500 = 500 profit
    });

    test('15. FinancialEngine.executeRefund restores funds to Customer wallet with idempotency', () async {
      final mockRepo = MockFinancialRepository();
      final engine = FinancialEngine(repository: mockRepo);

      final platformAcc = await mockRepo.getOrCreateAccount('madar_platform', FinancialAccountType.platform);
      mockRepo.accounts[platformAcc.accountId] = platformAcc.copyWith(availableBalance: 50000);

      final customerAcc = await mockRepo.getOrCreateAccount('cus_refunded', FinancialAccountType.customer);
      mockRepo.accounts[customerAcc.accountId] = customerAcc.copyWith(availableBalance: 0);

      final refundTx = await engine.executeRefund(
        refundRequestId: 'req_ref_55',
        orderId: 'ord_ref_55',
        orderSource: 'store',
        customerId: 'cus_refunded',
        amount: 15000,
        originalOrderAmount: 15000,
        totalPreviouslyRefundedAmount: 0,
        reason: 'إلغاء الطلب من قبل المتجر',
      );

      expect(refundTx.status, equals(FinancialTransactionStatus.committed));
      expect(mockRepo.accounts[customerAcc.accountId]!.availableBalance, equals(15000));
      expect(mockRepo.accounts[platformAcc.accountId]!.availableBalance, equals(35000));
      expect(mockRepo.refunds.length, equals(1));

      // Attempting duplicate refund with the same idempotency key throws exception
      expect(
        () => engine.executeRefund(
          refundRequestId: 'req_ref_55',
          orderId: 'ord_ref_55',
          orderSource: 'store',
          customerId: 'cus_refunded',
          amount: 15000,
          originalOrderAmount: 15000,
          totalPreviouslyRefundedAmount: 0,
          reason: 'إلغاء مكرر',
          idempotencyKey: refundTx.idempotencyKey,
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('16. Double payment prevention via unique idempotency keys', () async {
      final mockRepo = MockFinancialRepository();
      final engine = FinancialEngine(repository: mockRepo);

      final customerAcc = await mockRepo.getOrCreateAccount('cus_double', FinancialAccountType.customer);
      mockRepo.accounts[customerAcc.accountId] = customerAcc.copyWith(availableBalance: 50000);

      const fixedKey = 'idemp_fixed_key_12345';

      await engine.executeOrderPayment(
        orderId: 'ord_double_test',
        orderSource: 'store',
        customerId: 'cus_double',
        amount: 10000,
        idempotencyKey: fixedKey,
      );

      expect(mockRepo.accounts[customerAcc.accountId]!.availableBalance, equals(40000));

      // Second identical payment with same idempotency key MUST be rejected
      expect(
        () => engine.executeOrderPayment(
          orderId: 'ord_double_test',
          orderSource: 'store',
          customerId: 'cus_double',
          amount: 10000,
          idempotencyKey: fixedKey,
        ),
        throwsA(isA<SecurityViolationException>()),
      );

      // Balance remains intact (not double charged)
      expect(mockRepo.accounts[customerAcc.accountId]!.availableBalance, equals(40000));
    });

    test('17. Cash on Delivery settlement debits driver platform commission', () async {
      final mockRepo = MockFinancialRepository();
      final engine = FinancialEngine(repository: mockRepo);

      final driverAcc = await mockRepo.getOrCreateAccount('drv_cod', FinancialAccountType.driver);
      mockRepo.accounts[driverAcc.accountId] = driverAcc.copyWith(availableBalance: 5000);

      final settlement = SettlementEntity(
        id: 'stl_cod_1',
        orderId: 'ord_cod_1',
        orderSource: 'store',
        customerId: 'cus_cod',
        driverId: 'drv_cod',
        merchantId: 'store_cod',
        grossOrderAmount: 20000,
        deliveryFee: 3000,
        merchantAmount: 17000,
        driverAmount: 2500,
        platformCommission: 500,
        paymentMethod: 'cash',
        idempotencyKey: 'idemp_cod_1',
        createdAt: DateTime.now(),
      );

      final tx = await engine.executeSettlement(settlement: settlement);

      expect(tx.status, equals(FinancialTransactionStatus.committed));
      expect(mockRepo.accounts[driverAcc.accountId]!.availableBalance, equals(4500)); // 5,000 - 500 = 4,500
      expect(mockRepo.accounts['acc_platform_madar_platform']!.availableBalance, equals(500));
    });

    test('18. Consecutive partial refunds accumulate and block excess', () async {
      final mockRepo = MockFinancialRepository();
      final engine = FinancialEngine(repository: mockRepo);

      final platformAcc = await mockRepo.getOrCreateAccount('madar_platform', FinancialAccountType.platform);
      mockRepo.accounts[platformAcc.accountId] = platformAcc.copyWith(availableBalance: 100000);

      final customerAcc = await mockRepo.getOrCreateAccount('cus_accum', FinancialAccountType.customer);
      mockRepo.accounts[customerAcc.accountId] = customerAcc.copyWith(availableBalance: 0);

      // Refund 1: 5,000 of 20,000
      await engine.executeRefund(
        refundRequestId: 'req_1',
        orderId: 'ord_accum',
        orderSource: 'food',
        customerId: 'cus_accum',
        amount: 5000,
        originalOrderAmount: 20000,
        totalPreviouslyRefundedAmount: 0,
        reason: 'بند أول غير متوفر',
      );
      expect(mockRepo.accounts[customerAcc.accountId]!.availableBalance, equals(5000));

      // Refund 2: 10,000 of 20,000 (total refunded becomes 15,000)
      await engine.executeRefund(
        refundRequestId: 'req_2',
        orderId: 'ord_accum',
        orderSource: 'food',
        customerId: 'cus_accum',
        amount: 10000,
        originalOrderAmount: 20000,
        totalPreviouslyRefundedAmount: 5000,
        reason: 'بند ثاني غير متوفر',
      );
      expect(mockRepo.accounts[customerAcc.accountId]!.availableBalance, equals(15000));

      // Refund 3: Trying to refund 6,000 (Remaining is only 5,000) -> MUST FAIL
      expect(
        () => engine.executeRefund(
          refundRequestId: 'req_3',
          orderId: 'ord_accum',
          orderSource: 'food',
          customerId: 'cus_accum',
          amount: 6000,
          originalOrderAmount: 20000,
          totalPreviouslyRefundedAmount: 15000,
          reason: 'محاولة تجاوز الحد',
        ),
        throwsA(isA<SecurityViolationException>()),
      );

      // Final customer balance unchanged
      expect(mockRepo.accounts[customerAcc.accountId]!.availableBalance, equals(15000));
    });

    test('19. Immutable ledger records retrieval via repository', () async {
      final mockRepo = MockFinancialRepository();
      final engine = FinancialEngine(repository: mockRepo);

      final customerAcc = await mockRepo.getOrCreateAccount('cus_hist', FinancialAccountType.customer);
      mockRepo.accounts[customerAcc.accountId] = customerAcc.copyWith(availableBalance: 50000);

      await engine.executeOrderPayment(
        orderId: 'ord_h1',
        orderSource: 'food',
        customerId: 'cus_hist',
        amount: 10000,
      );

      await engine.executeOrderPayment(
        orderId: 'ord_h2',
        orderSource: 'store',
        customerId: 'cus_hist',
        amount: 15000,
      );

      final entries = await mockRepo.getAccountLedgerEntries(customerAcc.accountId);
      expect(entries.length, equals(2));
      expect(entries.every((e) => e.isDebit), isTrue);
      expect(entries.fold<int>(0, (sum, e) => sum + e.amount), equals(25000));
    });

    test('20. FinancialInvariantChecker rejects negative debt', () {
      final now = DateTime.now();
      final corruptAccount = FinancialAccount(
        accountId: 'acc_corrupt',
        ownerId: 'u_corrupt',
        accountType: FinancialAccountType.driver,
        availableBalance: 10000,
        debt: -100, // Invalid negative debt!
        createdAt: now,
        updatedAt: now,
      );

      expect(
        () => FinancialInvariantChecker.assertAccountInvariants(corruptAccount),
        throwsA(isA<SecurityViolationException>()),
      );
    });
  });
}
