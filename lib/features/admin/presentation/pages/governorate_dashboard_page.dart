import 'package:flutter/material.dart';
import 'package:dalal_alqaim/pages/regions_management_page.dart';
import 'package:dalal_alqaim/pages/restaurant_requests_page.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

// ═══════════════════════════════════════════════════════════════
// الألوان والأنماط الأساسية للتطبيق (Mapped to App Design Tokens)
// ═══════════════════════════════════════════════════════════════
class AppTheme {
  static const Color primary = app_colors.primaryColor;
  static const Color primaryDark = app_colors.accentColor;
  static const Color backgroundLight = app_colors.backgroundColor;
  static const Color backgroundDark = app_colors.darkBackground;
  static const Color surfaceLight = app_colors.surfaceColor;
  static const Color surfaceDark = app_colors.darkCard;
  static const Color textLight = app_colors.textColor;
  static const Color textDark = app_colors.darkText;
  static const Color subtitleLight = app_colors.subTextColor;
  static const Color subtitleDark = app_colors.darkSubText;

  static BoxDecoration cardDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? surfaceDark : surfaceLight,
      borderRadius: BorderRadius.circular(24),
      boxShadow:
          isDark
              ? []
              : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
    );
  }
}

class GovernorateDashboardPage extends StatefulWidget {
  final String governorateId;
  final String governorateName;
  final String? regionId;
  final String? regionName;
  final bool isRegionManager;

  const GovernorateDashboardPage({
    super.key,
    required this.governorateId,
    required this.governorateName,
    this.regionId,
    this.regionName,
    this.isRegionManager = false,
  });

  @override
  State<GovernorateDashboardPage> createState() =>
      _GovernorateDashboardPageState();
}

class _GovernorateDashboardPageState extends State<GovernorateDashboardPage> {
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: Text(
            widget.isRegionManager
                ? 'لوحة تحكم منطقة ${widget.regionName}'
                : 'لوحة تحكم محافظة ${widget.governorateName}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.textDark : AppTheme.textLight,
            ),
          ),
          centerTitle: true,
          backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
          elevation: 0,
        ),
        body: Column(
          children: [
            // Tabs Bar
            Container(
              color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(0, 'نظرة عامة', Icons.dashboard_rounded, isDark),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTabButton(1, 'المناطق', Icons.map_rounded, isDark),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTabButton(2, 'الطلبات', Icons.assignment_rounded, isDark),
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: IndexedStack(
                index: _activeTab,
                children: [
                  _buildOverviewTab(isDark),
                  _buildRegionsTab(isDark),
                  _buildRequestsTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String title, IconData icon, bool isDark) {
    final isSelected = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : (isDark ? Colors.white10 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : (isDark ? AppTheme.textDark : AppTheme.textLight),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : (isDark ? AppTheme.textDark : AppTheme.textLight),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مؤشرات الأداء الرئيسية',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? AppTheme.textDark : AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard('إجمالي المحلات', '24', Icons.store_rounded, isDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard('طلبات التوصيل', '142', Icons.delivery_dining, isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegionsTab(bool isDark) {
    return RegionsManagementPage(
      governorateId: widget.governorateId,
      governorateName: widget.governorateName,
    );
  }

  Widget _buildRequestsTab(bool isDark) {
    return const RestaurantRequestsPage();
  }

  Widget _buildMetricCard(String title, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.textDark : AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.subtitleDark : AppTheme.subtitleLight,
            ),
          ),
        ],
      ),
    );
  }
}
