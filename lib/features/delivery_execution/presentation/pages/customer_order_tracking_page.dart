import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/delivery_execution_models.dart';
import '../../data/repositories/delivery_execution_repository.dart';
import '../../application/customer_order_tracking_controller.dart';
import '../widgets/delivery_execution_map_view.dart';
import '../widgets/delivery_eta_badge.dart';
import '../widgets/customer_driver_card.dart';
import '../widgets/customer_tracking_timeline.dart';
import '../widgets/delivery_info_card.dart';

/// شاشة تتبع الطلب المباشر للزبون (Customer Live Order Tracking Page)
class CustomerOrderTrackingPage extends StatefulWidget {
  final String orderId;
  final OrderDeliverySource source;
  final CustomerOrderTrackingController? controller;

  const CustomerOrderTrackingPage({
    super.key,
    required this.orderId,
    required this.source,
    this.controller,
  });

  @override
  State<CustomerOrderTrackingPage> createState() => _CustomerOrderTrackingPageState();
}

class _CustomerOrderTrackingPageState extends State<CustomerOrderTrackingPage> {
  late final CustomerOrderTrackingController _controller;
  bool _isInternalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = CustomerOrderTrackingController(
        repository: DeliveryExecutionRepository(),
      );
      _isInternalController = true;
    }

    _controller.initialize(
      orderId: widget.orderId,
      source: widget.source,
    );
  }

  @override
  void dispose() {
    if (_isInternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            if (_controller.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00BFA5)),
              );
            }

            final delivery = _controller.delivery;
            if (delivery == null) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(24.r),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off_rounded, color: Colors.orangeAccent, size: 48.sp),
                      SizedBox(height: 16.h),
                      Text(
                        _controller.errorMessage ?? 'جاري انتظار تحديثات التوصيل...',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14.sp,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('رجوع'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Stack(
              children: [
                // 1. الخريطة التفاعلية مع مسار التوصيل المباشر
                Positioned.fill(
                  child: DeliveryExecutionMapView(
                    driverLocation: _controller.driverLocation,
                    pickupPoint: delivery.pickupPoint,
                    dropoffPoint: delivery.dropoffPoint,
                    route: _controller.routeToCustomer,
                    status: delivery.status,
                  ),
                ),

                // 2. الشريط العلوي مع زر الرجوع وشارة الـ ETA
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10.h,
                  right: 16.w,
                  left: 16.w,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'tracking_back_fab',
                        backgroundColor: (isDark ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.9),
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        child: const Icon(Icons.arrow_forward_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                      DeliveryEtaBadge(
                        route: _controller.routeToCustomer,
                        status: delivery.status,
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                // 3. النافذة السفلية لتفاصيل الطلب والمندوب والخط الزمني
                DraggableScrollableSheet(
                  initialChildSize: 0.40,
                  minChildSize: 0.25,
                  maxChildSize: 0.85,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A).withValues(alpha: 0.98)
                            : Colors.white.withValues(alpha: 0.98),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(28.r),
                          topRight: Radius.circular(28.r),
                        ),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 2),
                        ],
                      ),
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                        children: [
                          // مقبض السحب
                          Center(
                            child: Container(
                              width: 44.w,
                              height: 4.h,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),

                          // بطاقة الكابتن وخيارات الاتصال
                          CustomerDriverCard(driver: delivery.driverInfo),
                          SizedBox(height: 16.h),

                          // الخط الزمني لمراحل التوصيل
                          CustomerTrackingTimeline(status: delivery.status),
                          SizedBox(height: 16.h),

                          // ملخص تفاصيل الطلب
                          DeliveryInfoCard(delivery: delivery),
                          SizedBox(height: 20.h),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
