import 'package:flutter/material.dart';
import '../features/delivery/application/delivery_accounting_controller.dart';
import '../features/delivery/domain/entities/delivery_accounting_models.dart';
import '../features/delivery/presentation/widgets/accounting_week_card.dart';

/// شاشة الحسابات والمحاسبة الأسبوعية لمنظومة التوصيل (Delivery Weekly Accounting Page)
/// تم تحويلها إلى بنية نظيفة مفصولة الطبقات (Clean Pilot Architecture).
class DeliveryWeeklyAccountingPage extends StatefulWidget {
  final String? driverId;
  final String? govId;
  final String? govName;
  final String? regionId;
  final String? regionName;

  const DeliveryWeeklyAccountingPage({
    super.key,
    this.driverId,
    this.govId,
    this.govName,
    this.regionId,
    this.regionName,
  });

  @override
  State<DeliveryWeeklyAccountingPage> createState() => _DeliveryWeeklyAccountingPageState();
}

class _DeliveryWeeklyAccountingPageState extends State<DeliveryWeeklyAccountingPage> {
  late final DeliveryAccountingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DeliveryAccountingController(
      driverId: widget.driverId,
      govId: widget.govId,
      regionId: widget.regionId,
    );
    _controller.fetchData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark || !_controller.isManagerMode;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        Widget bodyWidget;

        if (_controller.isLoading) {
          bodyWidget = Center(
            child: CircularProgressIndicator(
              color: isDark ? const Color(0xFF00BFA5) : const Color(0xFF00897B),
            ),
          );
        } else if (_controller.hasError) {
          bodyWidget = _buildErrorWidget(isDark);
        } else if (!_controller.isManagerMode) {
          bodyWidget = _controller.driverModeSummaries.isEmpty
              ? _buildEmptyWidget(isDark)
              : _buildWeeklyList(isDark, 'drivers', _controller.driverModeSummaries);
        } else {
          bodyWidget = TabBarView(
            children: [
              _buildWeeklyList(isDark, 'drivers', _controller.managerDriverSummaries),
              _buildWeeklyList(isDark, 'restaurants', _controller.managerRestaurantSummaries),
              _buildWeeklyList(isDark, 'stores', _controller.managerStoreSummaries),
            ],
          );
        }

        if (_controller.isManagerMode) {
          return DefaultTabController(
            length: 3,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                appBar: AppBar(
                  title: const Text(
                    'الحسابات والمحاسبة الأسبوعية',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  centerTitle: true,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF00BFA5),
                  bottom: const TabBar(
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: [
                      Tab(text: 'الكباتن', icon: Icon(Icons.delivery_dining_rounded, size: 18)),
                      Tab(text: 'المطاعم', icon: Icon(Icons.restaurant_rounded, size: 18)),
                      Tab(text: 'المتاجر', icon: Icon(Icons.storefront_rounded, size: 18)),
                    ],
                  ),
                ),
                body: bodyWidget,
              ),
            ),
          );
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            appBar: AppBar(
              title: const Text(
                'المحاسبة الأسبوعية',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF00BFA5),
            ),
            body: bodyWidget,
          ),
        );
      },
    );
  }

  Widget _buildWeeklyList(bool isDark, String tabName, List<WeeklySummaryEntity> summaries) {
    if (summaries.isEmpty) {
      return _buildEmptyWidget(isDark);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: summaries.length,
      itemBuilder: (context, index) {
        final summary = summaries[index];
        final status = _controller.getStatusForWeek(tabName, summary.weekStart);

        return AccountingWeekCard(
          summary: summary,
          index: index,
          tabName: tabName,
          isDark: isDark,
          isManagerMode: _controller.isManagerMode,
          paymentStatus: status,
          driversMap: _controller.driversMap,
          restaurantNamesMap: _controller.restaurantNamesMap,
          storeNamesMap: _controller.storeNamesMap,
          govName: widget.govName,
          onUpdateStatus: (newStatus, postponedToDate) async {
            final success = await _controller.updatePaymentStatus(
              tabName: tabName,
              weekStart: summary.weekStart,
              newStatus: newStatus,
              postponedToDate: postponedToDate,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success ? 'تم تحديث حالة المحاسبة بنجاح' : 'فشل تحديث حالة المحاسبة',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: success ? const Color(0xFF00BFA5) : Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildEmptyWidget(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: isDark ? const Color(0xFF00BFA5) : const Color(0xFF00897B),
              size: 72,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'ماكو عمليات حالياً مكتملة في آخر 60 يوم.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Text(
              _controller.errorMessage,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _controller.fetchData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('حاول مرة ثانية', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF00BFA5) : const Color(0xFF00897B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
