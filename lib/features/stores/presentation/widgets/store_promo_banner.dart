import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../utils/theme_constants.dart';
import '../../domain/entities/store_dashboard_models.dart';

/// شريط الإعلانات الترويجية للمتجر (Store Promo Banner Carousel)
class StorePromoBanner extends StatefulWidget {
  final List<StoreBannerEntity> banners;
  final String storeName;
  final ValueChanged<StoreBannerEntity>? onBannerTap;

  const StorePromoBanner({
    super.key,
    required this.banners,
    required this.storeName,
    this.onBannerTap,
  });

  @override
  State<StorePromoBanner> createState() => _StorePromoBannerState();
}

class _StorePromoBannerState extends State<StorePromoBanner> {
  late final PageController _pageController;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
        child: Container(
          height: 160.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.8),
                AppTheme.primaryColor,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront_rounded, color: Colors.white, size: 40.r),
                SizedBox(height: 8.h),
                Text(
                  'أهلاً بك في ${widget.storeName.isNotEmpty ? widget.storeName :'متجر مدار'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 180.h,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentPageIndex = idx),
            itemCount: widget.banners.length,
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return Padding(
                padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
                child: GestureDetector(
                  onTap: () => widget.onBannerTap?.call(banner),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20.r),
                      image: banner.imageUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(banner.imageUrl),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(
                                Colors.black.withValues(alpha: 0.2),
                                BlendMode.darken,
                              ),
                            )
                          : null,
                      color: banner.imageUrl.isEmpty ? AppTheme.primaryColor : null,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(24.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (banner.title.isNotEmpty)
                            Text(
                              banner.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          if (banner.subtitle.isNotEmpty)
                            Text(
                              banner.subtitle,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.banners.length, (index) {
            final isSelected = _currentPageIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isSelected ? 16.w : 6.w,
              height: 6.h,
              margin: EdgeInsets.symmetric(horizontal: 2.w),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
      ],
    );
  }
}
