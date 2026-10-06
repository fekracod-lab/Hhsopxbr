import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/delivery_execution_models.dart';
import '../../domain/services/delivery_status_machine.dart';
import '../../data/repositories/delivery_execution_repository.dart';
import '../../application/delivery_execution_controller.dart';
import '../widgets/delivery_execution_map_view.dart';
import '../widgets/delivery_status_stepper.dart';
import '../widgets/delivery_action_button.dart';
import '../widgets/delivery_info_card.dart';
import '../widgets/delivery_privacy_shield_card.dart';
import '../widgets/delivery_eta_badge.dart';

/// شاشة تنفيذ التوصيل الميداني للكابتن (Order Delivery Execution Page)
class OrderDeliveryExecutionPage extends StatefulWidget {
  final String orderId;
  final OrderDeliverySource source;
  final DeliveryDriverInfo driverInfo;
  final DeliveryExecutionController? controller;

  const OrderDeliveryExecutionPage({
    super.key,
    required this.orderId,
    required this.source,
    required this.driverInfo,
    this.controller,
  });

  @override
  State<OrderDeliveryExecutionPage> createState() => _OrderDeliveryExecutionPageState();
}

class _OrderDeliveryExecutionPageState extends State<OrderDeliveryExecutionPage> {
  late final DeliveryExecutionController _controller;
  bool _isInternalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = DeliveryExecutionController(
        repository: DeliveryExecutionRepository(),
      );
      _isInternalController = true;
    }

    _controller.initialize(
      orderId: widget.orderId,
      source: widget.source,
      driverInfo: widget.driverInfo,
    );
  }

  @override
  void dispose() {
    if (_isInternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _launchNavigation(double lat, double lng) async {
    final url = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    try {
      final bool launched = await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
      if (!launched) {
        final webUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      final webUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _showCancelDialog(BuildContext context) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Text(
            'إلغاء مهمة التوصيل',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16.sp),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'يرجى توضيح سبب الإلغاء ليتم إعادة تعيين الطلب لكابتن آخر:',
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.sp),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'اكتب سبب الإلغاء هنا...',
                  hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12.sp),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('رجوع', style: GoogleFonts.ibmPlexSansArabic(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final reason = reasonCtrl.text.trim().isNotEmpty
                    ? reasonCtrl.text.trim()
                    : 'إلغاء من قبل الكابتن';
                final success = await _controller.cancelDelivery(reason);
                if (success && mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text('تأكيد الإلغاء', style: GoogleFonts.ibmPlexSansArabic()),
            ),
          ],
        ),
      ),
    );
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
                      Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48.sp),
                      SizedBox(height: 16.h),
                      Text(
                        _controller.errorMessage ?? 'تعذر العثور على بيانات الطلب',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14.sp,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('العودة للوحة القيادة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final activeTarget = delivery.activeTargetPoint;

            return Stack(
              children: [
                // 1. خريطة الملاحة الحية التفاعلية
                Positioned.fill(
                  child: DeliveryExecutionMapView(
                    driverLocation: _controller.currentDriverLocation,
                    pickupPoint: delivery.pickupPoint,
                    dropoffPoint: delivery.dropoffPoint,
                    route: _controller.currentRoute,
                    status: delivery.status,
                  ),
                ),

                // 2. شريط الأدوات العلوي والرجوع
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10.h,
                  right: 16.w,
                  left: 16.w,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'exec_back_fab',
                        backgroundColor: (isDark ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.9),
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        child: const Icon(Icons.arrow_forward_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                      DeliveryEtaBadge(
                        route: _controller.currentRoute,
                        status: delivery.status,
                      ),
                      if (DeliveryStatusMachine.canCancel(delivery.status))
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                            foregroundColor: Colors.redAccent,
                          ),
                          icon: const Icon(Icons.cancel_outlined),
                          tooltip: 'إلغاء الطلب',
                          onPressed: () => _showCancelDialog(context),
                        )
                      else
                        const SizedBox(width: 40),
                    ],
                  ),
                ),

                // 3. زر إعادة التوجيه السريع للخريطة الخارجية
                if (activeTarget.isValid)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 70.h,
                    left: 16.w,
                    child: FloatingActionButton.extended(
                      heroTag: 'launch_nav_fab',
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.navigation_rounded, size: 20),
                      label: Text(
                        'ملاحة Google',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.sp, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _launchNavigation(activeTarget.latitude, activeTarget.longitude),
                    ),
                  ),

                // 4. النافذة السفلية المنبثقة للتفاصيل والإجراء الأساسي (Draggable Sheet)
                DraggableScrollableSheet(
                  initialChildSize: 0.42,
                  minChildSize: 0.28,
                  maxChildSize: 0.88,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.98) : Colors.white.withValues(alpha: 0.98),
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
                          SizedBox(height: 14.h),

                          // زر الإجراء الأساسي المباشر
                          DeliveryActionButton(
                            status: delivery.status,
                            isProcessing: _controller.isActionProcessing,
                            onAction: () async {
                              final ok = await _controller.executeNextAction();
                              if (ok && delivery.status == DeliveryExecutionStatus.arrivedAtCustomer && mounted) {
                                Navigator.pop(context);
                              }
                            },
                          ),
                          SizedBox(height: 16.h),

                          // شريط الخطوات
                          DeliveryStatusStepper(status: delivery.status),
                          SizedBox(height: 16.h),

                          // درع الخصوصية لبيانات الزبون
                          DeliveryPrivacyShieldCard(delivery: delivery),
                          SizedBox(height: 16.h),

                          // بطاقة معلومات الطلب والمتجر
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
