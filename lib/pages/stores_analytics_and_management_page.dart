import 'package:flutter/material.dart';
import '../features/stores_analytics/application/store_analytics_controller.dart';
import '../features/stores_analytics/domain/entities/store_analytics_models.dart';
import '../features/stores_analytics/presentation/widgets/store_analytics_summary_cards.dart';
import '../features/stores_analytics/presentation/widgets/store_pending_requests_list.dart';
import '../features/stores_analytics/presentation/widgets/store_sales_table.dart';

/// Admin Store Management, Approval Requests & Sales Analytics
/// تم تحويلها إلى معمارية نظيفة مفصولة الطبقات (Clean Architecture Conformance).
class StoresAnalyticsAndManagementPage extends StatefulWidget {
  const StoresAnalyticsAndManagementPage({super.key});

  @override
  State<StoresAnalyticsAndManagementPage> createState() => _StoresAnalyticsAndManagementPageState();
}

class _StoresAnalyticsAndManagementPageState extends State<StoresAnalyticsAndManagementPage> {
  late final StoreAnalyticsController _controller;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = StoreAnalyticsController()..init();
    _searchController.addListener(() {
      _controller.setSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page Header Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'طلبات انضمام المتاجر وإدارة المبيعات',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'مراجعة طلبات التسجيل، الموافقة على المتاجر الجدد، ومتابعة الأرباح والمبيعات',
                          style: TextStyle(fontSize: 13, color: Colors.white60),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _controller.init(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('تحديث البيانات', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFA5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Top Sales & Requests Overview Cards
                StoreAnalyticsSummaryCards(summary: _controller.overallSummary),
                const SizedBox(height: 24),

                // Tab Navigation Selector
                Row(
                  children: [
                    _buildTabButton(0, 'طلبات الانضمام بانتظار الموافقة', Icons.pending_actions_rounded),
                    const SizedBox(width: 12),
                    _buildTabButton(1, 'المتاجر المعتمدة وتحليل المبيعات', Icons.storefront_rounded),
                  ],
                ),
                const SizedBox(height: 20),

                // Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'البحث باسم المحل، صاحب المتجر، أو رقم الهاتف...',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF00BFA5)),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Content Table depending on selected tab
                _controller.isLoading
                    ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFF00BFA5))))
                    : _controller.selectedTab == 0
                        ? StorePendingRequestsList(
                            pendingItems: _controller.filteredPendingRequests,
                            onApprove: _handleApproveStore,
                            onReject: _handleRejectStore,
                          )
                        : StoreSalesTable(
                            stores: _controller.filteredStores,
                            getStoreSales: _controller.getSalesForStore,
                            onToggleStatus: _handleToggleStatus,
                          ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _controller.selectedTab == index;
    return InkWell(
      onTap: () => _controller.setTab(index),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00BFA5) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? const Color(0xFF00BFA5) : const Color(0xFF334155)),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF00BFA5).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white60, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApproveStore(StoreRecord store) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await _controller.approveStore(store.id);
    if (mounted && success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('تمت الموافقة على متجر (${store.storeName}) وتفعيل حسابه بنجاح', style: const TextStyle()),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _handleRejectStore(StoreRecord store) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await _controller.rejectStore(store.id);
    if (mounted && success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('تم رفض طلب انضمام متجر (${store.storeName})', style: const TextStyle()),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _handleToggleStatus(StoreRecord store, bool isApproved) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await _controller.toggleStoreStatus(store.id, isApproved);
    if (mounted && success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('تم ${isApproved ? "تفعيل" : "تجميد"} حساب متجر (${store.storeName})', style: const TextStyle()),
          backgroundColor: isApproved ? Colors.green : Colors.orange,
        ),
      );
    }
  }
}
