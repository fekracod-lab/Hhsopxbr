import '../entities/delivery_execution_models.dart';

/// عقد مستودع تنفيذ التوصيل الميداني (Repository Interface Contract)
abstract class IDeliveryExecutionRepository {
  /// تدفق حي لمستند الطلب والتحديثات اللحظية
  Stream<DeliveryExecutionEntity?> streamActiveDelivery(
    String orderId,
    OrderDeliverySource source,
  );

  /// تدفق حي لموقع السائق المكلف
  Stream<DeliveryLocationEntity?> streamDriverLocation(String driverId);

  /// جلب بيانات الطلب لمرة واحدة
  Future<DeliveryExecutionEntity?> getDelivery(
    String orderId,
    OrderDeliverySource source,
  );

  /// قبول الطلب وتعيين الكابتن ذرّياً
  Future<bool> acceptDelivery({
    required String orderId,
    required OrderDeliverySource source,
    required DeliveryDriverInfo driverInfo,
  });

  /// تحديث حالة التوصيل مع تطبيق قواعد الانتقال والتسوية المالية
  Future<bool> updateDeliveryStatus({
    required String orderId,
    required OrderDeliverySource source,
    required DeliveryExecutionStatus newStatus,
    required String driverId,
    String cancelReason = '',
  });

  /// مزامنة موقع السائق مع كولكشن السائقين ومستند الطلب النشط
  Future<void> syncDriverLocation({
    required String driverId,
    required DeliveryLocationEntity location,
    String? activeOrderId,
    OrderDeliverySource? activeSource,
  });

  /// حساب مسار الملاحة عبر OSRM
  Future<DeliveryRouteEntity> calculateRoute({
    required DeliveryLocationEntity start,
    required DeliveryPoint destination,
  });

  /// إلغاء الطلب
  Future<bool> cancelDelivery({
    required String orderId,
    required OrderDeliverySource source,
    required String driverId,
    required String reason,
  });
}
