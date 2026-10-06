import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/restaurant_management_models.dart';
import '../../domain/services/restaurant_management_calculator.dart';
import '../datasources/restaurant_management_remote_datasource.dart';

/// مستودع إدارة المطاعم (Restaurant Management Repository)
class RestaurantManagementRepository {
  final RestaurantManagementRemoteDatasource _datasource;

  RestaurantManagementRepository({RestaurantManagementRemoteDatasource? datasource})
      : _datasource = datasource ?? RestaurantManagementRemoteDatasource();

  /// بث المطاعم حسب نوع المصدر المختار
  Stream<List<RestaurantRecord>> getRestaurantsStream({required bool showMainCollection}) {
    final stream = showMainCollection
        ? _datasource.getMainRestaurantsStream()
        : _datasource.getItemsGroupRestaurantsStream();

    return stream.map((list) => list.map(_mapToRestaurantRecord).toList());
  }

  /// حظر أو تفعيل المطعم
  Future<void> toggleSuspension(RestaurantRecord restaurant) async {
    await _datasource.toggleSuspension(restaurant.path, !restaurant.isSuspended);
  }

  /// تعديل بيانات المطعم
  Future<void> updateRestaurant({
    required RestaurantRecord restaurant,
    required String name,
    required String imageUrl,
    required String status,
  }) async {
    await _datasource.updateRestaurant(
      restaurant.path,
      name: name,
      imageUrl: imageUrl,
      status: status,
    );
  }

  /// حذف المطعم
  Future<void> deleteRestaurant(RestaurantRecord restaurant) async {
    await _datasource.deleteRestaurant(restaurant.path);
  }

  /// جلب حساب مالك المطعم
  Future<RestaurantOwnerRecord?> getOwnerUser(String ownerId) async {
    final data = await _datasource.getOwnerUserData(ownerId);
    if (data == null) return null;

    final historyList = <PasswordHistoryRecord>[];
    if (data['passwordHistory'] is List) {
      for (final item in data['passwordHistory'] as List) {
        if (item is Map) {
          historyList.add(PasswordHistoryRecord.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    DateTime? changedAt;
    if (data['passwordChangedAt'] is Timestamp) {
      changedAt = (data['passwordChangedAt'] as Timestamp).toDate();
    }

    return RestaurantOwnerRecord(
      id: ownerId,
      passwordHistory: historyList,
      passwordChangedAt: changedAt,
    );
  }

  /// تغيير كلمة مرور المالك
  Future<void> changeOwnerPassword(String ownerId, String newPassword) async {
    await _datasource.changeOwnerPassword(ownerId, newPassword);
  }

  RestaurantRecord _mapToRestaurantRecord(Map<String, dynamic> data) {
    final name = data['name']?.toString() ?? 'بدون اسم';
    final ownerId = data['ownerId']?.toString() ?? '';
    final imageUrl = data['imageUrl']?.toString() ?? data['image']?.toString() ?? '';
    final isSuspended = data['isSuspended'] == true;
    final rating = RestaurantManagementCalculator.parseRating(data['rating']);
    final status = data['status']?.toString() ?? '';

    return RestaurantRecord(
      id: data['_id']?.toString() ?? '',
      path: data['_path']?.toString() ?? 'restaurants/${data['_id']}',
      name: name,
      ownerId: ownerId,
      imageUrl: imageUrl,
      status: status,
      isSuspended: isSuspended,
      rating: rating,
      rawData: Map.unmodifiable(data),
    );
  }
}
