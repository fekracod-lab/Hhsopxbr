import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';
import '../../domain/entities/store_dashboard_models.dart';

/// قسم البانرات الترويجية للمتجر (Store Banners Section)
/// يعرض قائمة البانرات الترويجية وزر إنشاء بانر جديد وحذفه
class StoreBannersSection extends StatelessWidget {
  final List<StoreBannerEntity> banners;
  final bool isLoading;
  final bool isDark;
  final VoidCallback onAddBanner;
  final Function(String bannerId) onDeleteBanner;

  const StoreBannersSection({
    super.key,
    required this.banners,
    this.isLoading = false,
    required this.isDark,
    required this.onAddBanner,
    required this.onDeleteBanner,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 2,
              ),
            )
          : banners.isEmpty
              ? _buildEmptyState(
                  Icons.ads_click_rounded,
                  'لا توجد بانرات ترويجية — أنشئ أول بانر',
                )
              : ListView.separated(
                  padding: EdgeInsets.all(20.r),
                  physics: const BouncingScrollPhysics(),
                  itemCount: banners.length,
                  separatorBuilder: (_, __) => SizedBox(height: 16.h),
                  itemBuilder: (context, index) {
                    final banner = banners[index];
                    return _buildBannerCard(banner);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onAddBanner,
        backgroundColor: AppTheme.primaryColor,
        elevation: 8,
        label: const Text(
          'إضافة بانر',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildBannerCard(StoreBannerEntity banner) {
    return Container(
      height: 140.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                banner.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12.h,
              left: 16.w,
              right: 16.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    banner.title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (banner.subtitle.isNotEmpty)
                    Text(
                      banner.subtitle,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Positioned(
              top: 8.h,
              left: 8.w,
              child: GestureDetector(
                onTap: () => onDeleteBanner(banner.bannerId),
                child: Container(
                  padding: EdgeInsets.all(6.r),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.white,
                    size: 18.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48.sp,
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
