// صفحة إدارة وتوزيع رحلات التكسي (Taxi Ride Management Coordinator Page)
// Clean Architecture Presentation Layer — Pure Thin Coordinator

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/ride_management_models.dart';
import '../../domain/services/ride_management_calculator.dart';
import '../../application/ride_management_controller.dart';
import '../widgets/ride_management_header.dart';
import '../widgets/ride_management_kpi_bar.dart';
import '../widgets/ride_fleet_radar_tab.dart';
import '../widgets/ride_active_trips_tab.dart';
import '../widgets/ride_history_analytics_tab.dart';
import '../widgets/ride_captains_wallet_tab.dart';
import '../widgets/ride_reviews_tab.dart';

class RideManagementPage extends StatefulWidget {
  final RideManagementController? controller;

  const RideManagementPage({
    super.key,
    this.controller,
  });

  @override
  State<RideManagementPage> createState() => _RideManagementPageState();
}

class _RideManagementPageState extends State<RideManagementPage>
    with SingleTickerProviderStateMixin {
  late final RideManagementController _controller;
  bool _isControllerLocal = false;
  late final TabController _tabController;

  static const Color _primaryColor = Color(0xFF00BFA5);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    if (widget.controller != null) {
      _controller = widget.controller!;
      _isControllerLocal = false;
    } else {
      _controller = RideManagementController();
      _isControllerLocal = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_isControllerLocal) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: isDark ? const Color(0xFF07181A) : const Color(0xFFF8FAFC),
            appBar: RideManagementHeader(
              isDark: isDark,
              onRefresh: () => _controller.initialize(),
            ),
            body: Column(
              children: [
                // شريط مؤشرات الأداء السريعة (KPI Bar)
                RideManagementKpiBar(
                  metrics: _controller.kpiMetrics,
                  isDark: isDark,
                ),

                // شريط التبويبات الرئيسي
                _buildTabBar(isDark),

                // محتوى التبويب النشط
                Expanded(
                  child: _controller.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: _primaryColor),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            // Tab 0: الرادار والأسطول
                            RideFleetRadarTab(
                              drivers: _controller.allDrivers,
                              activeRides: _controller.activeRides,
                              selectedDriver: _controller.selectedDriver,
                              selectedRide: _controller.selectedRide,
                              onDriverSelected: (d) => _controller.selectDriver(d),
                              onRideSelected: (r) => _controller.selectRide(r),
                              onClearSelection: () => _controller.clearSelection(),
                              onAssignDriver: _showAssignDriverDialog,
                              onCancelRide: _showCancelRideDialog,
                              onCallPhone: _makePhoneCall,
                              isDark: isDark,
                            ),

                            // Tab 1: الرحلات الحية
                            RideActiveTripsTab(
                              rides: _controller.filteredRides,
                              selectedFilter: _controller.statusFilter,
                              searchQuery: _controller.searchQuery,
                              onFilterChanged: (f) => _controller.setStatusFilter(f),
                              onSearchChanged: (q) => _controller.setSearchQuery(q),
                              onAssignDriver: _showAssignDriverDialog,
                              onCancelRide: _showCancelRideDialog,
                              onCallPhone: _makePhoneCall,
                              onOpenNavigation: _openNavigation,
                              isDark: isDark,
                            ),

                            // Tab 2: الإحصائيات والأرشيف
                            RideHistoryAnalyticsTab(
                              historyRides: _controller.historyRides,
                              analytics: _controller.historyAnalytics,
                              onCallPhone: _makePhoneCall,
                              isDark: isDark,
                            ),

                            // Tab 3: المحافظ والعمولات
                            RideCaptainsWalletTab(
                              drivers: _controller.filteredDrivers,
                              selectedFilter: _controller.driverDebtFilter,
                              searchQuery: _controller.driverSearchQuery,
                              onFilterChanged: (f) => _controller.setDriverDebtFilter(f),
                              onSearchChanged: (q) => _controller.setDriverSearchQuery(q),
                              onSettleCommission: (d) => _showSettleCommissionDialog(d, isDark),
                              onResetWallet: (d) => _showResetWalletDialog(d, isDark),
                              onEditLimit: (d) => _showEditLimitDialog(d, isDark),
                              onToggleException: (d, allow) => _handleToggleException(d, allow),
                              onCallPhone: _makePhoneCall,
                              isDark: isDark,
                            ),

                            // Tab 4: التقييمات والآراء
                            RideReviewsTab(
                              reviews: _controller.filteredReviews,
                              selectedFilter: _controller.reviewFilter,
                              searchQuery: _controller.reviewSearchQuery,
                              onFilterChanged: (f) => _controller.setReviewFilter(f),
                              onSearchChanged: (q) => _controller.setReviewSearchQuery(q),
                              onWarnDriver: (r) => _showAdminReviewActionDialog(r, 'warn_driver', isDark),
                              onPraiseDriver: (r) => _showAdminReviewActionDialog(r, 'praise_driver', isDark),
                              onDeleteReview: (r) => _handleDeleteReview(r),
                              isDark: isDark,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0C2428) : Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: _primaryColor,
        indicatorWeight: 3,
        labelColor: _primaryColor,
        unselectedLabelColor: isDark ? Colors.white60 : Colors.grey.shade600,
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5.sp),
        unselectedLabelStyle: TextStyle(fontSize: 11.sp),
        tabs: const [
          Tab(text: 'الرادار'),
          Tab(text: 'الرحلات الحية'),
          Tab(text: 'الإحصائيات'),
          Tab(text: 'المحافظ والعمولات'),
          Tab(text: 'التقييمات والآراء'),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  // أوامر وإجراءات المنسق (Coordinator Dialogs & Actions)
  // ────────────────────────────────────────────

  void _showCancelRideDialog(RideAdminEntity ride) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text(
            'إلغاء الرحلة #${ride.id.substring(0, ride.id.length.clamp(0, 6))}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'متأكد تريد تلغي رحلة الزبون ${ride.passengerName}؟',
                style: TextStyle(fontSize: 12.sp),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: reasonController,
                style: TextStyle(fontSize: 12.sp),
                decoration: InputDecoration(
                  labelText: 'سبب الإلغاء (اختياري)',
                  labelStyle: const TextStyle(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('تراجع', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                final reason = reasonController.text.trim();
                final res = await _controller.cancelRide(rideId: ride.id, reason: reason.isNotEmpty ? reason : null);

                if (!mounted) return;
                if (res == RideManagementActionStatus.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إلغاء الرحلة بنجاح', style: TextStyle()), backgroundColor: Colors.green),
                  );
                } else if (res == RideManagementActionStatus.locked) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('جاري معالجة الرحلة بالفعل...', style: TextStyle()), backgroundColor: Colors.blue),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('فشل إلغاء الرحلة، حاول مرة ثانية', style: TextStyle()), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('تأكيد الإلغاء', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignDriverDialog(RideAdminEntity ride) {
    final activeDrivers = _controller.activeDrivers.isNotEmpty
        ? _controller.activeDrivers
        : _controller.allDrivers.where((d) => d.status.toLowerCase() == 'active').toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: 0.65.sh,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'تعيين كابتن للرحلة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Text(
                'الزبون: ${ride.passengerName} • الأجرة: ${RideManagementCalculator.formatIraqiCurrency(ride.fare)}',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade700),
              ),
              const Divider(),
              Expanded(
                child: activeDrivers.isEmpty
                    ? const Center(
                        child: Text('ماكو كباتن حالياً متصلون أو متاحون حالياً', style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        itemCount: activeDrivers.length,
                        itemBuilder: (c, idx) {
                          final driver = activeDrivers[idx];
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 4.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _primaryColor.withValues(alpha: 0.15),
                                child: Icon(Icons.person, color: _primaryColor, size: 18.r),
                              ),
                              title: Text(driver.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp)),
                              subtitle: Text('${driver.carModel} • ${driver.phone}', style: TextStyle(fontSize: 10.sp, color: Colors.grey)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white),
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  final res = await _controller.assignDriverToRide(rideId: ride.id, driver: driver);

                                  if (!mounted) return;
                                  if (res == RideManagementActionStatus.success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('تم تعيين الكابتن ${driver.name} للرحلة بنجاح', style: const TextStyle()),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('فشل تعيين الكابتن، حاول ثانية', style: TextStyle()), backgroundColor: Colors.red),
                                    );
                                  }
                                },
                                child: const Text('تعيين', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettleCommissionDialog(TaxiDriverAdminEntity driver, bool isDark) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0C2428) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text(
            'تسوية عمولة الكابتن ${driver.name}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5.sp, color: isDark ? Colors.white : Colors.black87),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('إجمالي المديونية الحالية:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      RideManagementCalculator.formatIraqiCurrency(driver.appDebt),
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 12.sp, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'المبلغ المستلم للتسوية (د.ع)',
                  hintText: 'مثال: 5000',
                  labelStyle: const TextStyle(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
              ),
              SizedBox(height: 8.h),
              TextField(
                controller: notesController,
                style: TextStyle(fontSize: 12.sp, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'ملاحظات السند (اختياري)',
                  labelStyle: const TextStyle(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white),
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (amount <= 0) return;

                Navigator.pop(ctx);
                final res = await _controller.settleDriverCommission(
                  driverId: driver.id,
                  amountPaid: amount,
                  adminNotes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                );

                if (!mounted) return;
                if (res == RideManagementActionStatus.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تسوية مبلغ ${RideManagementCalculator.formatIraqiCurrency(amount)} بنجاح', style: const TextStyle()),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('حدث خطأ أثناء التسوية', style: TextStyle()), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('تسوية المبلغ', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetWalletDialog(TaxiDriverAdminEntity driver, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0C2428) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text(
            'تصفير شامل لمحفظة الكابتن',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5.sp),
          ),
          content: Text(
            'هل أنت متأكد من تصفير محفظة الكابتن ${driver.name} بالكامل (0 د.ع) وفك الحظر المالي فوراً؟',
            style: TextStyle(fontSize: 12.sp),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _controller.resetDriverWalletCompletely(driverId: driver.id);

                if (!mounted) return;
                if (res == RideManagementActionStatus.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تصفير محفظة ${driver.name} وفك الحظر بنجاح', style: const TextStyle()),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('تصفير 0 د.ع', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditLimitDialog(TaxiDriverAdminEntity driver, bool isDark) {
    final limitController = TextEditingController(text: driver.commissionLimit.toInt().toString());

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0C2428) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text(
            'تعديل سقف مديونية ${driver.name}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5.sp),
          ),
          content: TextField(
            controller: limitController,
            keyboardType: TextInputType.number,
            style: TextStyle(fontSize: 12.sp),
            decoration: InputDecoration(
              labelText: 'السقف الجديد (د.ع)',
              labelStyle: const TextStyle(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white),
              onPressed: () async {
                final newLimit = double.tryParse(limitController.text.trim()) ?? 0.0;
                if (newLimit <= 0) return;

                Navigator.pop(ctx);
                final res = await _controller.updateDriverCommissionLimit(driverId: driver.id, newLimit: newLimit);

                if (!mounted) return;
                if (res == RideManagementActionStatus.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تعديل سقف المديونية إلى ${RideManagementCalculator.formatIraqiCurrency(newLimit)}', style: const TextStyle()),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('حفظ السقف', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminReviewActionDialog(DriverReviewAdminEntity review, String actionType, bool isDark) {
    final noteController = TextEditingController();
    final isWarn = actionType == 'warn_driver';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0C2428) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text(
            isWarn ? 'توجيه تنبيه للكابتن ${review.driverName}' : 'إرسال شكر للكابتن ${review.driverName}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5.sp),
          ),
          content: TextField(
            controller: noteController,
            maxLines: 3,
            style: TextStyle(fontSize: 12.sp),
            decoration: InputDecoration(
              labelText: 'نص الملاحظة / الرسالة',
              hintText: isWarn ? 'مثال: يرجى الالتزام بالمسار المحدد والسرعة القانونية...' : 'شكراً لك على التزامك وحسن تعاملك مع الزبائن!',
              labelStyle: const TextStyle(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isWarn ? Colors.orange : const Color(0xFF00C853),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _controller.sendAdminReviewAction(
                  reviewId: review.id,
                  driverId: review.driverId,
                  actionType: actionType,
                  note: noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
                );

                if (!mounted) return;
                if (res == RideManagementActionStatus.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isWarn ? 'تم إرسال التنبيه للكابتن' : 'تم إرسال الشكر والتقدير للكابتن', style: const TextStyle()),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('إرسال', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleToggleException(TaxiDriverAdminEntity driver, bool allow) async {
    final res = await _controller.toggleDriverCommissionException(driverId: driver.id, allowException: allow);

    if (!mounted) return;
    if (res == RideManagementActionStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(allow ? 'تم تفعيل الاستثناء المالي للكابتن ${driver.name}' : 'تم إلغاء الاستثناء المالي للكابتن ${driver.name}', style: const TextStyle()),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleDeleteReview(DriverReviewAdminEntity review) async {
    final res = await _controller.sendAdminReviewAction(
      reviewId: review.id,
      driverId: review.driverId,
      actionType: 'delete_review',
    );

    if (!mounted) return;
    if (res == RideManagementActionStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف التقييم بنجاح', style: TextStyle()), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return;

    final Uri phoneUri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _openNavigation(double lat, double lng) async {
    final Uri navUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    if (await canLaunchUrl(navUri)) {
      await launchUrl(navUri);
    } else {
      final Uri webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    }
  }
}
