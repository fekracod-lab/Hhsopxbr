import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/delivery_accounting_models.dart';
import '../../domain/services/accounting_calculator.dart';
import '../datasources/delivery_accounting_remote_datasource.dart';

/// مستودع إدارة بيانات المحاسبة الأسبوعية (Delivery Accounting Repository)
class DeliveryAccountingRepository {
  final DeliveryAccountingRemoteDatasource _datasource;

  DeliveryAccountingRepository({DeliveryAccountingRemoteDatasource? datasource})
      : _datasource = datasource ?? DeliveryAccountingRemoteDatasource();

  /// جلب ملخصات المحاسبة الأسبوعية للسائق
  Future<List<WeeklySummaryEntity>> getDriverWeeklySummaries(String driverId) async {
    final startLimit = DateTime.now().subtract(const Duration(days: 60));

    final foodOrders = await _datasource.fetchDriverFoodOrders(driverId, startLimit);
    final storeOrders = await _datasource.fetchDriverStoreOrders(driverId, startLimit);
    final rideDeliveries = await _datasource.fetchDriverRideDeliveries(driverId, startLimit);

    final allRaw = [...foodOrders, ...storeOrders, ...rideDeliveries];
    final records = allRaw.map(_mapToRecord).toList();

    return AccountingCalculator.groupOrdersByWeek(records);
  }

  /// جلب حزمة بيانات المحاسبة الأسبوعية للمدير
  Future<({
    Map<String, Map<String, dynamic>> driversMap,
    Map<String, String> restaurantNamesMap,
    Map<String, String> storeNamesMap,
    Map<String, PaymentStatusRecord> paymentsStatusMap,
    List<WeeklySummaryEntity> driverSummaries,
    List<WeeklySummaryEntity> restaurantSummaries,
    List<WeeklySummaryEntity> storeSummaries,
  })> getManagerAccountingData({
    required String govId,
    String? regionId,
  }) async {
    final startLimit = DateTime.now().subtract(const Duration(days: 60));

    // 1. Fetch metadata
    final driversMap = await _datasource.fetchDrivers(govId, regionId: regionId);
    final restaurantNamesMap = await _datasource.fetchRestaurants(govId, regionId: regionId);
    final storeNamesMap = await _datasource.fetchStores(govId, regionId: regionId);
    final rawStatusMap = await _datasource.fetchPaymentsStatus(govId);

    final paymentsStatusMap = <String, PaymentStatusRecord>{};
    rawStatusMap.forEach((key, data) {
      final postponedTo = (data['postponedTo'] as Timestamp?)?.toDate();
      final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
      paymentsStatusMap[key] = PaymentStatusRecord(
        status: data['status']?.toString() ?? 'unpaid',
        postponedTo: postponedTo,
        updatedAt: updatedAt,
      );
    });

    // 2. Fetch orders in parallel
    final driverOrdersFuture = _datasource.fetchManagerDriverOrders(driversMap.keys.toSet(), startLimit);
    final restaurantOrdersFuture = _datasource.fetchManagerRestaurantOrders(restaurantNamesMap.keys.toList(), startLimit);
    final storeOrdersFuture = _datasource.fetchManagerStoreOrders(storeNamesMap.keys.toSet(), startLimit);

    final results = await Future.wait([driverOrdersFuture, restaurantOrdersFuture, storeOrdersFuture]);

    final driverRecords = (results[0]).map(_mapToRecord).toList();
    final restaurantRecords = (results[1]).map(_mapToRecord).toList();
    final storeRecords = (results[2]).map(_mapToRecord).toList();

    return (
      driversMap: driversMap,
      restaurantNamesMap: restaurantNamesMap,
      storeNamesMap: storeNamesMap,
      paymentsStatusMap: paymentsStatusMap,
      driverSummaries: AccountingCalculator.groupOrdersByWeek(driverRecords),
      restaurantSummaries: AccountingCalculator.groupOrdersByWeek(restaurantRecords),
      storeSummaries: AccountingCalculator.groupOrdersByWeek(storeRecords),
    );
  }

  /// تحديث حالة الدفع للأسبوع
  Future<void> updatePaymentStatus({
    required String govId,
    required String key,
    required String newStatus,
    DateTime? postponedToDate,
  }) async {
    await _datasource.updatePaymentStatus(
      govId: govId,
      key: key,
      newStatus: newStatus,
      postponedToDate: postponedToDate,
    );
  }

  /// تحويل كائن Firestore الخام إلى Domain Entity
  DeliveryOrderRecord _mapToRecord(Map<String, dynamic> data) {
    final typeString = data['type']?.toString();
    final type = DeliveryOrderType.fromString(typeString);

    final rawDate = data['completedAt'] ?? data['createdAt'];
    DateTime createdAt = DateTime.now();
    if (rawDate is Timestamp) createdAt = rawDate.toDate();
    if (rawDate is DateTime) createdAt = rawDate;

    return DeliveryOrderRecord(
      id: data['id']?.toString() ?? '',
      type: type,
      totalAmount: AccountingCalculator.parseOrderTotal(
        data['total'] ?? data['totalPrice'] ?? data['grandTotal'] ?? data['itemsPrice'],
      ),
      deliveryFee: AccountingCalculator.parseDeliveryFee(
        data['deliveryFee'] ?? data['price'],
      ),
      createdAt: createdAt,
      customerName: data['customerName']?.toString() ?? data['userName']?.toString() ?? 'زبون',
      driverId: data['driverId']?.toString(),
      restaurantId: data['restaurantId']?.toString(),
      storeId: data['storeId']?.toString(),
      rawData: Map.unmodifiable(data),
    );
  }
}
