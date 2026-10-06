import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

// Shared
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

// Feature Pages
import 'package:dalal_alqaim/features/home/pages/search_page.dart';
import 'package:dalal_alqaim/features/home/pages/favorites_page.dart';
import 'package:dalal_alqaim/features/home/pages/settings_page.dart';

// Feature Widgets
import 'package:dalal_alqaim/features/home/widgets/home_main_content.dart';
import 'package:dalal_alqaim/features/home/widgets/glass_bottom_nav_bar.dart';
import 'package:dalal_alqaim/core/automation/smart_assistant_fab.dart';

import 'package:dalal_alqaim/core/observability/observability.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final List<bool> _visitedTabs = [true, false, false, false];

  @override
  void initState() {
    super.initState();
    PerformanceTracker.startTrace('home_first_build');
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _visitedTabs[index] = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    Widget mainContent = IndexedStack(
      index: _selectedIndex,
      children: [
        const HomeMainContent(),
        _visitedTabs[1] ? const SearchPage() : const SizedBox.shrink(),
        _visitedTabs[2] ? const FavoritesPage() : const SizedBox.shrink(),
        _visitedTabs[3] ? const SettingsPage() : const SizedBox.shrink(),
      ],
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (PerformanceTracker.getDuration('home_first_build') == null) {
        PerformanceTracker.stopTrace('home_first_build');
        final homeBuild = PerformanceTracker.getDuration('home_first_build');
        debugPrint('[Madar Benchmark] HOME_FIRST_BUILD: ${homeBuild}ms');
      }
    });

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? app_colors.darkBackground : app_colors.backgroundColor,
        extendBody: !isDesktop,
        body: isDesktop
            ? Stack(
                children: [
                  Row(
                    children: [
                      NavigationRail(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: _onItemTapped,
                        labelType: NavigationRailLabelType.all,
                        backgroundColor: isDark ? app_colors.darkCard : Colors.white,
                        selectedIconTheme: const IconThemeData(color: app_colors.primaryColor),
                        unselectedIconTheme: IconThemeData(color: isDark ? Colors.white54 : Colors.grey),
                        selectedLabelTextStyle: GoogleFonts.ibmPlexSansArabic(color: app_colors.primaryColor, fontWeight: FontWeight.w700),
                        unselectedLabelTextStyle: GoogleFonts.ibmPlexSansArabic(color: isDark ? Colors.white54 : Colors.grey, fontWeight: FontWeight.w500),
                        destinations: const [
                          NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: Text('الرئيسية')),
                          NavigationRailDestination(icon: Icon(Icons.search), label: Text('بحث')),
                          NavigationRailDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: Text('المفضلة')),
                          NavigationRailDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: Text('حسابي')),
                        ],
                      ),
                      VerticalDivider(thickness: 1, width: 1, color: isDark ? Colors.white10 : Colors.black12),
                      Expanded(child: mainContent),
                    ],
                  ),
                  const Positioned(
                    bottom: 24,
                    left: 24,
                    child: SmartAssistantFAB(),
                  ),
                ],
              )
            : Stack(
                children: [
                  mainContent,
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16.h,
                    child: GlassBottomNavBar(selectedIndex: _selectedIndex, onTap: _onItemTapped),
                  ),
                  Positioned(
                    bottom: 96.h,
                    left: 16.w,
                    child: const SmartAssistantFAB(),
                  ),
                ],
              ),
      ),
    );
  }
}
