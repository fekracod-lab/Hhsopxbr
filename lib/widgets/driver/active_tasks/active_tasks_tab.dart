import 'package:flutter/material.dart';
import 'package:dalal_alqaim/models/mersal_request.dart';
import 'package:dalal_alqaim/models/parcel_delivery_request.dart';
import 'package:dalal_alqaim/models/delegate_request.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/mersal_order_details_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/parcel_management_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delegate_order_details_page.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActiveTasksTab extends StatelessWidget {
  final Stream<List<MersalRequest>>? mersalOrdersStream;
  final Stream<List<ParcelDeliveryRequest>>? parcelOrdersStream;
  final Stream<List<DelegateRequest>>? delegateOrdersStream;
  final Stream<QuerySnapshot>? taxiRidesStream;
  final Stream<List<Map<String, dynamic>>>? foodOrdersStream;
  final Map<String, dynamic> driverData;
  final bool isDark;
  final String? driverUid;
  final Widget Function({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  })
  emptyStateBuilder;

  const ActiveTasksTab({
    super.key,
    this.mersalOrdersStream,
    this.parcelOrdersStream,
    this.delegateOrdersStream,
    this.taxiRidesStream,
    this.foodOrdersStream,
    required this.driverData,
    required this.isDark,
    required this.driverUid,
    required this.emptyStateBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MersalRequest>>(
      stream: mersalOrdersStream ?? const Stream.empty(),
      builder: (context, mersalSnapshot) {
        return StreamBuilder<List<ParcelDeliveryRequest>>(
          stream: parcelOrdersStream ?? const Stream.empty(),
          builder: (context, parcelSnapshot) {
            return StreamBuilder<List<DelegateRequest>>(
              stream: delegateOrdersStream ?? const Stream.empty(),
              builder: (context, delegateSnapshot) {
                List<Widget> activeItems = [];

                if (mersalSnapshot.hasData) {
                  activeItems.addAll(
                    mersalSnapshot.data!.map((req) => _buildActiveMersalOrderCard(context, req)),
                  );
                }

                if (parcelSnapshot.hasData) {
                  activeItems.addAll(
                    parcelSnapshot.data!.map((req) => _buildActiveParcelOrderCard(context, req)),
                  );
                }

                if (delegateSnapshot.hasData) {
                  activeItems.addAll(
                    delegateSnapshot.data!.map(
                      (req) => _buildActiveDelegateOrderCard(context, req),
                    ),
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: taxiRidesStream ?? const Stream.empty(),
                  builder: (context, taxiSnapshot) {
                    if (taxiSnapshot.hasData) {
                      activeItems.addAll(
                        taxiSnapshot.data!.docs.map(
                          (doc) => _buildActiveTaxiRideCard(context, doc.id, doc.data() as Map<String, dynamic>),
                        ),
                      );
                    }

                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: foodOrdersStream ?? const Stream.empty(),
                      builder: (context, foodSnapshot) {
                        if (foodSnapshot.hasData) {
                          activeItems.addAll(
                            foodSnapshot.data!.map(
                              (order) => _buildActiveFoodOrderCard(context, order),
                            ),
                          );
                        }

                        if (activeItems.isEmpty) {
                          return emptyStateBuilder(
                            icon: Icons.directions_car_outlined,
                            title: 'لا توجد مهام نشطة',
                            subtitle: 'الطلبات الجارية تظهر هنا',
                            isDark: isDark,
                          );
                        }

                        return ListView(padding: const EdgeInsets.all(16), children: activeItems);
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildActiveMersalOrderCard(BuildContext context, MersalRequest req) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? AppTheme.darkSurface : Colors.white,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.shopping_bag, color: Colors.orange),
            title: Text(
              'طلب مرسال: ${req.userName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('الحالة: ${req.status}', style: const TextStyle()),
            trailing: Text(
              req.price ?? 'قيد الاتفاق',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => MersalOrderDetailsPage(request: req, driverData: driverData),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('إدارة الطلب', style: TextStyle()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveParcelOrderCard(BuildContext context, ParcelDeliveryRequest req) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? AppTheme.darkSurface : Colors.white,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.inventory_2, color: AppTheme.successColor),
            title: Text(
              'شحنة: ${req.userName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('الحالة: ${req.status}', style: const TextStyle()),
            trailing: Text(
              '${req.price.toInt()} د.ع',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.successColor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ParcelManagementPage(driverId: driverUid),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('إدارة الشحنة', style: TextStyle()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDelegateOrderCard(BuildContext context, DelegateRequest req) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? AppTheme.darkSurface : Colors.white,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.delivery_dining, color: AppTheme.primaryColor),
            title: Text(
              'طلب دليفري: ${req.userName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('الحالة: ${req.status}', style: const TextStyle()),
            trailing: Text(
              '${req.price} د.ع',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              DelegateOrderDetailsPage(request: req, driverData: driverData),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('إدارة الطلب', style: TextStyle()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTaxiRideCard(BuildContext context, String rideId, Map<String, dynamic> data) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? AppTheme.darkSurface : Colors.white,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.local_taxi_rounded, color: Colors.amber),
            title: Text(
              'رحلة تكسي: ${data['userName'] ?? 'عميل'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('الحالة: ${data['status']}', style: const TextStyle()),
            trailing: Text(
              '${data['estimatedPrice'] ?? '---'} د.ع',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/trip', arguments: rideId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('افتح الرحلة', style: TextStyle()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFoodOrderCard(BuildContext context, Map<String, dynamic> order) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? AppTheme.darkSurface : Colors.white,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.restaurant_rounded, color: Colors.redAccent),
            title: Text(
              'طلب مطعم: ${order['restaurantName'] ?? 'مطعم'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('الحالة: ${order['status']}', style: const TextStyle()),
            trailing: Text(
              '${order['deliveryFee'] ?? '---'} د.ع',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // No specific detail page yet for food, navigate to dash
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('إدارة الطلب', style: TextStyle()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
