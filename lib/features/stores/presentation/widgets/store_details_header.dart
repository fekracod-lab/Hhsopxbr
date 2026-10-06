import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// شريط الترويسة والبحث لمتجر مدار (Store Details Header & Search Bar)
class StoreDetailsHeader extends StatelessWidget {
  final String storeName;
  final TextEditingController searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onBack;
  final VoidCallback? onNotificationsTap;

  const StoreDetailsHeader({
    super.key,
    required this.storeName,
    required this.searchController,
    this.onSearchChanged,
    this.onBack,
    this.onNotificationsTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: Column(
        children: [
          // ── Minimalist Top Bar ──
          Container(
            color: isDark ? const Color(0xFF1A1D26) : Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: isDark ? Colors.white : Colors.black87,
                      size: 20.sp,
                    ),
                    onPressed: onBack ?? () => Navigator.maybePop(context),
                  ),
                  Expanded(
                    child: Text(
                      storeName.isNotEmpty ? storeName : 'متجر مدار',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1A1D26),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Badge(
                      label: const Text('2', style: TextStyle(fontSize: 10)),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    onPressed: onNotificationsTap ?? () {},
                  ),
                ],
              ),
            ),
          ),

          // ── Search Bar ──
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
            child: Container(
              height: 54.h,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D26) : Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                ],
              ),
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                style: TextStyle(fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: 'ابحث عن منتجات...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white24 : Colors.grey,
                    fontSize: 14.sp,
                  ),
                  suffixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark ? Colors.white54 : Colors.grey,
                    size: 24.sp,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
