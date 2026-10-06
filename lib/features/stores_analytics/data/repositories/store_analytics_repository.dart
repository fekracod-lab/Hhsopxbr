import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/store_analytics_models.dart';
import '../../domain/services/store_analytics_calculator.dart';
import '../datasources/store_analytics_remote_datasource.dart';

/// مستودع إدارة وتحليلات المتاجر (Store Analytics Repository)
class StoreAnalyticsRepository {
  final StoreAnalyticsRemoteDatasource _datasource;

  StoreAnalyticsRepository({StoreAnalyticsRemoteDatasource? datasource})
      : _datasource = datasource ?? StoreAnalyticsRemoteDatasource();

  /// بث سجلات الطلبات المالية للمتاجر
  Stream<List<StoreOrderRecord>> getOrdersStream() {
    return _datasource.getStoreOrdersStream().map((list) {
      return list.map(_mapToOrderRecord).toList();
    });
  }

  /// بث قائمة المتاجر المسجلة والمعتمدة
  Stream<List<StoreRecord>> getRegisteredStoresStream() {
    return _datasource.getStoreUsersStream().map((list) {
      return list.map((d) => _mapToStoreRecord(d, StoreRequestSource.users)).toList();
    });
  }

  /// بث طلبات الانضمام المعلقة بانتظار الموافقة مدمجة من كلا المصدرين
  Stream<List<StoreRecord>> getPendingStoreRequestsStream() {
    return _datasource.getStoreRequestsStream().asyncMap((requestDocs) async {
      final Map<String, StoreRecord> combinedMap = {};

      // 1. Add from store_requests collection
      for (final raw in requestDocs) {
        final record = _mapToStoreRecord(raw, StoreRequestSource.storeRequests);
        if (record.isPending) {
          combinedMap[record.id] = record;
        }
      }

      // 2. Add from users collection
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['store', 'merchant', 'store_owner'])
          .get();

      for (final doc in usersSnap.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final record = _mapToStoreRecord(data, StoreRequestSource.users);
        if (record.isPending) {
          combinedMap[record.id] = record;
        }
      }

      return combinedMap.values.toList();
    });
  }

  /// اعتماد وموافقة على متجر
  Future<void> approveStore(String storeId) async {
    await _datasource.approveStore(storeId);
  }

  /// رفض طلب انضمام متجر
  Future<void> rejectStore(String storeId) async {
    await _datasource.rejectStore(storeId);
  }

  /// تغيير حالة المتجر
  Future<void> toggleStoreStatus(String storeId, bool isApproved) async {
    await _datasource.toggleStoreStatus(storeId, isApproved);
  }

  StoreOrderRecord _mapToOrderRecord(Map<String, dynamic> data) {
    final price = StoreAnalyticsCalculator.parseOrderPrice(
      data['totalPrice'] ?? data['totalAmount'] ?? data['price'],
    );
    final rawDate = data['createdAt'];
    DateTime? createdAt;
    if (rawDate is Timestamp) createdAt = rawDate.toDate();
    if (rawDate is DateTime) createdAt = rawDate;

    return StoreOrderRecord(
      id: data['id']?.toString() ?? '',
      storeId: data['storeId']?.toString() ?? '',
      totalPrice: price,
      status: data['status']?.toString() ?? '',
      createdAt: createdAt,
      rawData: Map.unmodifiable(data),
    );
  }

  StoreRecord _mapToStoreRecord(Map<String, dynamic> data, StoreRequestSource source) {
    final st = (data['status'] ?? 'pending').toString().toLowerCase();
    final isAppr = data['isApproved'] as bool? ?? (st == 'active' || st == 'approved');

    return StoreRecord(
      id: data['id']?.toString() ?? '',
      storeName: data['storeName']?.toString() ?? data['name']?.toString() ?? data['fullName']?.toString() ?? 'متجر مدار',
      ownerName: data['name']?.toString() ?? data['fullName']?.toString() ?? 'غير محدد',
      phone: data['phone']?.toString() ?? data['phoneNumber']?.toString() ?? 'غير محدد',
      email: data['email']?.toString() ?? 'غير محدد',
      category: data['category']?.toString() ?? data['storeCategory']?.toString() ?? 'عام',
      governorateName: data['governorateName']?.toString() ?? 'غير محدد',
      regionName: data['regionName']?.toString() ?? '',
      address: data['address']?.toString() ?? 'غير محدد',
      workingHours: data['workingHours']?.toString() ?? 'من 9:00 ص إلى 11:00 م',
      isApproved: isAppr,
      status: st,
      logoUrl: data['logoUrl']?.toString() ?? data['storeImage']?.toString() ?? data['imageUrl']?.toString(),
      source: source,
      rawData: Map.unmodifiable(data),
    );
  }
}
