import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/finance/domain/entities/payment_intent.dart';
import 'package:dalal_alqaim/core/finance/domain/entities/payment_result.dart';
import 'package:dalal_alqaim/core/finance/data/adapters/zaincash_payment_adapter.dart';
import 'package:dalal_alqaim/core/finance/data/adapters/qicard_payment_adapter.dart';
import 'package:dalal_alqaim/core/finance/data/repositories/payment_gateway_repository_impl.dart';

void main() {
  group('PaymentGateway Adapter & Registry Comprehensive Unit Tests', () {
    test('1. PaymentIntent initialization and map conversion', () {
      final now = DateTime(2026, 9, 5, 12, 0);
      final intent = PaymentIntent(
        id: 'intent-101',
        orderId: 'order-999',
        userId: 'user-777',
        amountMinorUnits: 5000,
        providerType: PaymentGatewayProviderType.zainCash,
        status: PaymentIntentStatus.initiated,
        createdAt: now,
      );

      expect(intent.amountMajorUnits, 5000.0);
      expect(intent.currency, 'IQD');
      expect(intent.providerType, PaymentGatewayProviderType.zainCash);
      expect(intent.status, PaymentIntentStatus.initiated);

      final map = intent.toMap();
      expect(map['id'], 'intent-101');
      expect(map['amountMinorUnits'], 5000);
      expect(map['providerType'], 'zainCash');

      final updated = intent.copyWith(
        status: PaymentIntentStatus.pendingUserConfirmation,
        redirectUrl: 'https://test.zaincash.iq/pay/101',
      );
      expect(updated.status, PaymentIntentStatus.pendingUserConfirmation);
      expect(updated.redirectUrl, 'https://test.zaincash.iq/pay/101');
    });

    test('2. PaymentResult factory constructors', () {
      final successResult = PaymentResult.success(
        intentId: 'intent-101',
        transactionId: 'txn-555',
      );
      expect(successResult.isSuccess, true);
      expect(successResult.status, PaymentIntentStatus.succeeded);
      expect(successResult.transactionId, 'txn-555');

      final failureResult = PaymentResult.failure(
        intentId: 'intent-102',
        errorCode: 'INSUFFICIENT_FUNDS',
        errorMessageIraqi: 'رصيد المحفظة غير كافٍ لإتمام العملية',
      );
      expect(failureResult.isSuccess, false);
      expect(failureResult.status, PaymentIntentStatus.failed);
      expect(failureResult.errorCode, 'INSUFFICIENT_FUNDS');
      expect(failureResult.errorMessageIraqi, 'رصيد المحفظة غير كافٍ لإتمام العملية');
    });

    test('3. ZainCash adapter handles unconfigured credentials safely', () async {
      const adapter = ZainCashPaymentAdapter(); // No credentials provided
      expect(adapter.isConfigured, false);
      expect(adapter.providerType, PaymentGatewayProviderType.zainCash);

      final intent = PaymentIntent(
        id: 'intent-zc-1',
        orderId: 'order-1',
        userId: 'user-1',
        amountMinorUnits: 10000,
        providerType: PaymentGatewayProviderType.zainCash,
        status: PaymentIntentStatus.initiated,
        createdAt: DateTime.now(),
      );

      final result = await adapter.createPaymentIntent(intent);
      expect(result.isSuccess, false);
      expect(result.errorCode, 'ZAINCASH_CREDENTIALS_MISSING');
      expect(result.errorMessageIraqi, contains('مفاتيح التاجر'));

      final verifyResult = await adapter.verifyPayment(
        intentId: 'intent-zc-1',
        transactionReference: 'ref-1',
      );
      expect(verifyResult.isSuccess, false);
      expect(verifyResult.errorCode, 'ZAINCASH_CREDENTIALS_MISSING');

      final refundResult = await adapter.refundPayment(
        intentId: 'intent-zc-1',
        transactionReference: 'ref-1',
        amountMinorUnits: 5000,
        reason: 'Customer return',
      );
      expect(refundResult.isSuccess, false);
      expect(refundResult.errorCode, 'ZAINCASH_CREDENTIALS_MISSING');
    });

    test('4. QiCard adapter handles unconfigured credentials safely', () async {
      const adapter = QiCardPaymentAdapter(); // No credentials
      expect(adapter.isConfigured, false);
      expect(adapter.providerType, PaymentGatewayProviderType.qiCard);

      final intent = PaymentIntent(
        id: 'intent-qi-1',
        orderId: 'order-2',
        userId: 'user-2',
        amountMinorUnits: 15000,
        providerType: PaymentGatewayProviderType.qiCard,
        status: PaymentIntentStatus.initiated,
        createdAt: DateTime.now(),
      );

      final result = await adapter.createPaymentIntent(intent);
      expect(result.isSuccess, false);
      expect(result.errorCode, 'QICARD_CREDENTIALS_MISSING');
      expect(result.errorMessageIraqi, contains('معرف المحطة'));
    });

    test('5. PaymentGatewayRepository manages and routes to registered providers', () async {
      final repo = PaymentGatewayRepositoryImpl(
        providers: [
          const ZainCashPaymentAdapter(),
          const QiCardPaymentAdapter(),
        ],
      );

      expect(repo.getProvider(PaymentGatewayProviderType.zainCash), isNotNull);
      expect(repo.getProvider(PaymentGatewayProviderType.qiCard), isNotNull);
      expect(repo.getProvider(PaymentGatewayProviderType.wallet), isNull);

      final intent = PaymentIntent(
        id: 'intent-route-1',
        orderId: 'order-3',
        userId: 'user-3',
        amountMinorUnits: 25000,
        providerType: PaymentGatewayProviderType.zainCash,
        status: PaymentIntentStatus.initiated,
        createdAt: DateTime.now(),
      );

      final result = await repo.processPayment(intent);
      expect(result.isSuccess, false);
      expect(result.errorCode, 'ZAINCASH_CREDENTIALS_MISSING');

      // Unsupported provider returns clean error
      final unsupportedIntent = PaymentIntent(
        id: 'intent-unsupported',
        orderId: 'order-4',
        userId: 'user-4',
        amountMinorUnits: 1000,
        providerType: PaymentGatewayProviderType.wallet,
        status: PaymentIntentStatus.initiated,
        createdAt: DateTime.now(),
      );

      final unsupportedResult = await repo.processPayment(unsupportedIntent);
      expect(unsupportedResult.isSuccess, false);
      expect(unsupportedResult.errorCode, 'UNSUPPORTED_PROVIDER');
    });
  });
}
