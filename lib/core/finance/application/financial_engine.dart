import 'dart:math';
import '../domain/entities/financial_transaction.dart';
import '../domain/entities/ledger_entry.dart';
import '../domain/entities/settlement_entity.dart';
import '../domain/enums/financial_enums.dart';
import '../domain/repositories/i_financial_repository.dart';
import '../domain/services/refund_calculator.dart';
import '../data/repositories/financial_repository.dart';

/// المحرك المالي المركزي لمنظومة مدار (MADAR Financial Engine & Double-Entry Coordinator)
class FinancialEngine {
  static FinancialEngine? _instance;
  static FinancialEngine get instance => _instance ??= FinancialEngine();

  final IFinancialRepository _repository;

  FinancialEngine({IFinancialRepository? repository})
      : _repository = repository ?? FinancialRepository();

  /// توليد مفتاح عدم تكرار مالي فريد
  String generateIdempotencyKey({String prefix = 'fin'}) {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}-$hex';
  }

  /// تنفيذ عملية دفع طلب من المحفظة (Order Payment from Wallet)
  Future<FinancialTransaction> executeOrderPayment({
    required String orderId,
    required String orderSource,
    required String customerId,
    required int amount,
    String? idempotencyKey,
  }) async {
    final effectiveKey = idempotencyKey ?? generateIdempotencyKey(prefix: 'pay');
    final txId = 'tx-pay-$orderId-${DateTime.now().millisecondsSinceEpoch}';

    final customerAcc = await _repository.getOrCreateAccount(customerId, FinancialAccountType.customer);
    final platformAcc = await _repository.getOrCreateAccount('madar_platform', FinancialAccountType.platform);

    final entries = [
      LedgerEntry(
        id: 'ent-deb-$txId',
        transactionId: txId,
        accountId: customerAcc.accountId,
        ownerId: customerId,
        accountType: FinancialAccountType.customer,
        entryType: LedgerEntryType.debit,
        amount: amount,
        description: 'خصم قيمة الطلب ($orderId) من محفظة العميل',
        createdAt: DateTime.now(),
      ),
      LedgerEntry(
        id: 'ent-crd-$txId',
        transactionId: txId,
        accountId: platformAcc.accountId,
        ownerId: 'madar_platform',
        accountType: FinancialAccountType.platform,
        entryType: LedgerEntryType.credit,
        amount: amount,
        description: 'إيداع قيمة الطلب ($orderId) في حساب المنصة المعلق',
        createdAt: DateTime.now(),
      ),
    ];

    final transaction = FinancialTransaction(
      id: txId,
      idempotencyKey: effectiveKey,
      category: TransactionCategory.orderPayment,
      orderId: orderId,
      orderSource: orderSource,
      entries: entries,
      totalAmount: amount,
      createdAt: DateTime.now(),
    );

    return await _repository.executeTransaction(transaction);
  }

  /// تنفيذ تسوية مالية متعددة الأطراف (Multi-Party Delivery Settlement)
  Future<FinancialTransaction> executeSettlement({
    required SettlementEntity settlement,
    String? idempotencyKey,
  }) async {
    final effectiveKey = idempotencyKey ?? settlement.idempotencyKey;
    final txId = 'tx-stl-${settlement.orderId}-${DateTime.now().millisecondsSinceEpoch}';

    final platformAcc = await _repository.getOrCreateAccount('madar_platform', FinancialAccountType.platform);
    final entries = <LedgerEntry>[];

    // إذا تم الدفع مسبقاً بالمحفظة، يتم الخصم من حساب المنصة المعلق وتوزيعه
    if (settlement.paymentMethod == 'wallet' || settlement.paymentMethod == 'paid_online') {
      entries.add(
        LedgerEntry(
          id: 'ent-deb-plt-$txId',
          transactionId: txId,
          accountId: platformAcc.accountId,
          ownerId: 'madar_platform',
          accountType: FinancialAccountType.platform,
          entryType: LedgerEntryType.debit,
          amount: settlement.grossOrderAmount,
          description: 'تسوية مستحقات الطلب (${settlement.orderId}) من أموال المنصة المعلقة',
          createdAt: DateTime.now(),
        ),
      );

      if (settlement.merchantId != null && settlement.merchantAmount > 0) {
        final merchantAcc = await _repository.getOrCreateAccount(settlement.merchantId!, FinancialAccountType.restaurant);
        entries.add(
          LedgerEntry(
            id: 'ent-crd-mer-$txId',
            transactionId: txId,
            accountId: merchantAcc.accountId,
            ownerId: settlement.merchantId!,
            accountType: FinancialAccountType.restaurant,
            entryType: LedgerEntryType.credit,
            amount: settlement.merchantAmount,
            description: 'إيداع أرباح التاجر للطلب (${settlement.orderId})',
            createdAt: DateTime.now(),
          ),
        );
      }

      if (settlement.driverId != null && settlement.driverAmount > 0) {
        final driverAcc = await _repository.getOrCreateAccount(settlement.driverId!, FinancialAccountType.driver);
        entries.add(
          LedgerEntry(
            id: 'ent-crd-drv-$txId',
            transactionId: txId,
            accountId: driverAcc.accountId,
            ownerId: settlement.driverId!,
            accountType: FinancialAccountType.driver,
            entryType: LedgerEntryType.credit,
            amount: settlement.driverAmount,
            description: 'إيداع أجور توصيل الكابتن للطلب (${settlement.orderId})',
            createdAt: DateTime.now(),
          ),
        );
      }

      if (settlement.platformCommission > 0) {
        entries.add(
          LedgerEntry(
            id: 'ent-crd-com-$txId',
            transactionId: txId,
            accountId: platformAcc.accountId,
            ownerId: 'madar_platform',
            accountType: FinancialAccountType.platform,
            entryType: LedgerEntryType.credit,
            amount: settlement.platformCommission,
            description: 'إيراد عمولة المنصة الصافية للطلب (${settlement.orderId})',
            createdAt: DateTime.now(),
          ),
        );
      }
    } else {
      // الدفع نقد عند الاستلام (Cash on Delivery): الكابتن استلم الكاش
      // الكابتن مدين بعمولة المنصة
      if (settlement.driverId != null && settlement.platformCommission > 0) {
        final driverAcc = await _repository.getOrCreateAccount(settlement.driverId!, FinancialAccountType.driver);
        entries.add(
          LedgerEntry(
            id: 'ent-deb-drv-com-$txId',
            transactionId: txId,
            accountId: driverAcc.accountId,
            ownerId: settlement.driverId!,
            accountType: FinancialAccountType.driver,
            entryType: LedgerEntryType.debit,
            amount: settlement.platformCommission,
            description: 'خصم عمولة المنصة المستحقة من الكابتن نقداً للطلب (${settlement.orderId})',
            createdAt: DateTime.now(),
          ),
        );
        entries.add(
          LedgerEntry(
            id: 'ent-crd-plt-com-$txId',
            transactionId: txId,
            accountId: platformAcc.accountId,
            ownerId: 'madar_platform',
            accountType: FinancialAccountType.platform,
            entryType: LedgerEntryType.credit,
            amount: settlement.platformCommission,
            description: 'تسجيل عمولة المنصة من تحصيل الكاش للطلب (${settlement.orderId})',
            createdAt: DateTime.now(),
          ),
        );
      }
    }

    if (entries.isEmpty) {
      return FinancialTransaction(
        id: txId,
        idempotencyKey: effectiveKey,
        category: TransactionCategory.merchantSettlement,
        status: FinancialTransactionStatus.committed,
        entries: const [],
        totalAmount: 0,
        createdAt: DateTime.now(),
      );
    }

    final totalAmount = entries.where((e) => e.isDebit).fold<int>(0, (sum, e) => sum + e.amount);

    final transaction = FinancialTransaction(
      id: txId,
      idempotencyKey: effectiveKey,
      category: TransactionCategory.merchantSettlement,
      orderId: settlement.orderId,
      orderSource: settlement.orderSource,
      entries: entries,
      totalAmount: totalAmount,
      createdAt: DateTime.now(),
    );

    // توثيق التسوية
    await _repository.recordSettlement(settlement);

    // تنفيذ قيود دفتر الأستاذ
    return await _repository.executeTransaction(transaction);
  }

  /// تنفيذ استرداد مالي موثق (Process Refund & Credit Customer Wallet)
  Future<FinancialTransaction> executeRefund({
    required String refundRequestId,
    required String orderId,
    required String orderSource,
    required String customerId,
    required int amount,
    int points = 0,
    required int originalOrderAmount,
    required int totalPreviouslyRefundedAmount,
    required String reason,
    String? idempotencyKey,
  }) async {
    final effectiveKey = idempotencyKey ?? generateIdempotencyKey(prefix: 'ref-tx');

    // 1. التحقق الصارم من عدم تجاوز قيمة الطلب
    final refundRecord = RefundCalculator.calculateValidRefund(
      refundRequestId: refundRequestId,
      orderId: orderId,
      orderSource: orderSource,
      customerId: customerId,
      requestedRefundAmount: amount,
      requestedRefundPoints: points,
      originalOrderAmount: originalOrderAmount,
      totalPreviouslyRefundedAmount: totalPreviouslyRefundedAmount,
      reason: reason,
      idempotencyKey: effectiveKey,
    );

    final txId = 'tx-ref-$orderId-${DateTime.now().millisecondsSinceEpoch}';
    final customerAcc = await _repository.getOrCreateAccount(customerId, FinancialAccountType.customer);
    final platformAcc = await _repository.getOrCreateAccount('madar_platform', FinancialAccountType.platform);

    final entries = [
      LedgerEntry(
        id: 'ent-deb-plt-ref-$txId',
        transactionId: txId,
        accountId: platformAcc.accountId,
        ownerId: 'madar_platform',
        accountType: FinancialAccountType.platform,
        entryType: LedgerEntryType.debit,
        amount: amount,
        description: 'خصم مبلغ الاسترداد للطلب ($orderId) من حساب المنصة',
        createdAt: DateTime.now(),
      ),
      LedgerEntry(
        id: 'ent-crd-cus-ref-$txId',
        transactionId: txId,
        accountId: customerAcc.accountId,
        ownerId: customerId,
        accountType: FinancialAccountType.customer,
        entryType: LedgerEntryType.credit,
        amount: amount,
        description: 'إيداع مبلغ الاسترداد للطلب ($orderId) في محفظة العميل',
        createdAt: DateTime.now(),
      ),
    ];

    final transaction = FinancialTransaction(
      id: txId,
      idempotencyKey: effectiveKey,
      category: TransactionCategory.orderRefund,
      orderId: orderId,
      orderSource: orderSource,
      entries: entries,
      totalAmount: amount,
      createdAt: DateTime.now(),
    );

    // توثيق سجل الاسترداد
    await _repository.processRefund(refundRecord);

    // تنفيذ حركة دفتر الأستاذ الذرية
    return await _repository.executeTransaction(transaction);
  }
}
