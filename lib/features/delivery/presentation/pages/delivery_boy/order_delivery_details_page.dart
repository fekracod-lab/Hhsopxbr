import 'package:flutter/material.dart';
import '../../../../delivery_execution/domain/entities/delivery_execution_models.dart';
import '../../../../delivery_execution/presentation/pages/order_delivery_execution_page.dart';

import '../../../../delivery_execution/application/delivery_execution_controller.dart';

/// غلاف متوافق مع المنظومة القديمة يوجه إلى المحرك المعماري الجديد
/// (Thin Coordinator Delegating to Phase 7 Clean Architecture Engine)
class OrderDeliveryDetailsPage extends StatelessWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic> driverData;
  final DeliveryExecutionController? controller;

  const OrderDeliveryDetailsPage({
    super.key,
    required this.order,
    required this.driverData,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final orderId = (order['id'] ?? order['orderId'] ?? order['requestId'] ?? '').toString();
    final source = OrderDeliverySource.fromString(order['type']?.toString());

    final driverInfo = DeliveryDriverInfo(
      id: (driverData['id'] ?? driverData['uid'] ?? '').toString(),
      name: (driverData['fullName'] ?? driverData['name'] ?? 'كابتن مدار').toString(),
      phone: (driverData['phone'] ?? '').toString(),
      imageUrl: (driverData['imageUrl'] ?? '').toString(),
      vehicleType: (driverData['carType'] ?? driverData['vehicleType'] ?? 'دراجة نارية').toString(),
      vehiclePlate: (driverData['carNumber'] ?? driverData['vehiclePlate'] ?? '').toString(),
      rating: (driverData['rating'] as num?)?.toDouble() ?? 5.0,
    );

    return OrderDeliveryExecutionPage(
      orderId: orderId,
      source: source,
      driverInfo: driverInfo,
      controller: controller,
    );
  }
}
