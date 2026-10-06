import 'package:dalal_alqaim/core/pricing/application/pricing_engine.dart';
import 'package:dalal_alqaim/core/pricing/domain/repositories/i_pricing_repository.dart';
import 'package:dalal_alqaim/core/pricing/domain/entities/pricing_policy.dart';
import 'package:dalal_alqaim/core/pricing/domain/entities/pricing_snapshot.dart';
import 'package:dalal_alqaim/core/pricing/domain/enums/pricing_enums.dart';

import 'package:dalal_alqaim/core/dispatch/application/dispatch_engine.dart';
import 'package:dalal_alqaim/core/dispatch/domain/repositories/i_dispatch_repository.dart';
import 'package:dalal_alqaim/core/dispatch/domain/entities/dispatch_candidate.dart';
import 'package:dalal_alqaim/core/dispatch/domain/entities/dispatch_session.dart';
import 'package:dalal_alqaim/core/dispatch/domain/entities/dispatch_offer.dart';
import 'package:dalal_alqaim/core/dispatch/domain/enums/dispatch_enums.dart';

import 'package:dalal_alqaim/core/notifications/application/notification_engine.dart';
import 'package:dalal_alqaim/core/notifications/domain/repositories/i_notification_repository.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_event.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_message.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_delivery.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_preference.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_policy.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_audit_record.dart';

import 'package:dalal_alqaim/core/finance/application/financial_engine.dart';
import 'package:dalal_alqaim/core/finance/domain/repositories/i_financial_repository.dart';
import 'package:dalal_alqaim/core/finance/domain/entities/financial_account.dart';
import 'package:dalal_alqaim/core/finance/domain/entities/financial_transaction.dart';
import 'package:dalal_alqaim/core/finance/domain/entities/ledger_entry.dart';
import 'package:dalal_alqaim/core/finance/domain/entities/settlement_entity.dart';
import 'package:dalal_alqaim/core/finance/domain/entities/refund_ledger_record.dart';
import 'package:dalal_alqaim/core/finance/domain/enums/financial_enums.dart';

import 'package:dalal_alqaim/core/orchestration/application/madar_transaction_engine.dart';
import 'package:dalal_alqaim/core/orchestration/domain/repositories/i_transaction_repository.dart';

class MockPricingRepo implements IPricingRepository {
  final Map<String, PricingSnapshot> snapshots = {};

  @override
  Future<PricingPolicy> getActivePolicy(PricingServiceType serviceType) async {
    return serviceType == PricingServiceType.taxi
        ? PricingPolicy.defaultTaxiPolicy
        : serviceType == PricingServiceType.food
            ? PricingPolicy.defaultFoodPolicy
            : serviceType == PricingServiceType.store
                ? PricingPolicy.defaultStorePolicy
                : PricingPolicy.defaultMersalPolicy;
  }

  @override
  Future<PricingSnapshot> saveSnapshot(PricingSnapshot snapshot) async {
    snapshots[snapshot.snapshotId] = snapshot;
    return snapshot;
  }

  @override
  Future<PricingSnapshot?> getSnapshot(String snapshotId) async => snapshots[snapshotId];

  @override
  Future<bool> verifyIdempotencyKey(String idempotencyKey) async => true;
}

class MockDispatchRepo implements IDispatchRepository {
  final List<DispatchCandidate> drivers = [
    DispatchCandidate(
      driverId: 'drv_test_captain_1',
      name: 'علي الكابتن',
      phone: '07700000001',
      latitude: 33.3160,
      longitude: 44.3670,
      rating: 4.9,
      acceptanceRate: 0.95,
      isOnline: true,
      isApproved: true,
      lastLocationUpdate: DateTime.now(),
    ),
  ];

  @override
  Future<List<DispatchCandidate>> getOnlineDrivers({required DispatchType dispatchType}) async => drivers;

  @override
  Future<DispatchSession> createSession(DispatchSession session) async => session;

  @override
  Future<DispatchSession?> getSession(String sessionId) async => null;

  @override
  Future<DispatchOffer> createOffer(DispatchOffer offer) async => offer;

  @override
  Future<DispatchOffer?> getOffer(String offerId) async => null;

  @override
  Future<bool> acceptOfferAtomic({
    required String offerId,
    required String driverId,
    required String orderId,
    required DispatchType dispatchType,
  }) async => true;

  @override
  Future<bool> rejectOffer({
    required String offerId,
    required String driverId,
    required String reason,
  }) async => true;

  @override
  Future<void> updateSessionStatus(String sessionId, DispatchStatus status) async {}
}

class MockNotificationRepo implements INotificationRepository {
  @override
  Future<NotificationEvent> saveEvent(NotificationEvent event) async => event;

  @override
  Future<NotificationDelivery> saveDelivery(NotificationDelivery delivery) async => delivery;

  @override
  Future<NotificationDelivery?> getDelivery(String deliveryId) async => null;

  @override
  Future<NotificationPreference> getPreference(String userId) async => NotificationPreference(userId: userId);

  @override
  Future<void> savePreference(NotificationPreference preference) async {}

  @override
  Future<NotificationPolicy> getPolicy() async => const NotificationPolicy();

  @override
  Future<void> saveAuditRecord(NotificationAuditRecord record) async {}

  @override
  Future<bool> verifyIdempotencyKey(String idempotencyKey) async => true;

  @override
  Future<bool> deliverViaChannel({
    required NotificationDelivery delivery,
    required NotificationMessage message,
  }) async => true;
}

class MockFinancialRepo implements IFinancialRepository {
  final Map<String, FinancialAccount> accounts = {};

  @override
  Future<FinancialAccount> getOrCreateAccount(String ownerId, FinancialAccountType type) async {
    final accountId = 'acc_${type.key}_$ownerId';
    return accounts.putIfAbsent(
      accountId,
      () => FinancialAccount(
        accountId: accountId,
        ownerId: ownerId,
        accountType: type,
        availableBalance: 500000, // 500,000 IQD available balance
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<FinancialAccount?> getAccount(String accountId) async => accounts[accountId];

  @override
  Future<FinancialTransaction> executeTransaction(FinancialTransaction transaction) async => transaction;

  @override
  Future<SettlementEntity> recordSettlement(SettlementEntity settlement) async => settlement;

  @override
  Future<RefundLedgerRecord> processRefund(RefundLedgerRecord refundRecord) async => refundRecord;

  @override
  Future<List<LedgerEntry>> getAccountLedgerEntries(String accountId, {int limit = 50}) async => [];

  @override
  Future<bool> verifyIdempotencyKey(String idempotencyKey) async => true;
}

/// Helper لإنشاء محرك معاملات مهيأ للاختبارات بذاكرة محلية معزولة
MadarTransactionEngine createTestTransactionEngine({
  required ITransactionRepository repository,
  FinancialEngine? financialEngine,
}) {
  return MadarTransactionEngine(
    repository: repository,
    pricingEngine: PricingEngine(repository: MockPricingRepo()),
    dispatchEngine: DispatchEngine(repository: MockDispatchRepo()),
    notificationEngine: NotificationEngine(repository: MockNotificationRepo()),
    financialEngine: financialEngine ?? FinancialEngine(repository: MockFinancialRepo()),
  );
}
