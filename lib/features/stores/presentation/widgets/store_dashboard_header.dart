import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';
import '../../domain/entities/store_dashboard_models.dart';

/// ترويسة لوحة تحكم المتجر (Store Dashboard Header Widget)
/// واجهة عرض صافية لبيانات المتجر وحالته وزر تسجيل الخروج
class StoreDashboardHeader extends StatelessWidget {
  final StoreDashboardEntity? store;
  final String fallbackName;
  final String? fallbackLogoUrl;
  final bool isDark;

  const StoreDashboardHeader({
    super.key,
    this.store,
    this.fallbackName = 'المتجر',
    this.fallbackLogoUrl,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final name = store?.name.isNotEmpty == true ? store!.name : fallbackName;
    final logoUrl = store?.logoUrl.isNotEmpty == true ? store!.logoUrl : fallbackLogoUrl;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.75),
            const Color(0xFF00897B),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 60.h),
          child: Row(
            children: [
              // Store Logo
              Container(
                width: 60.r,
                height: 60.r,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18.r),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18.r),
                  child: logoUrl != null && logoUrl.isNotEmpty
                      ? Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.storefront_rounded,
                            color: AppTheme.primaryColor,
                            size: 30.sp,
                          ),
                        )
                      : Icon(
                          Icons.storefront_rounded,
                          color: AppTheme.primaryColor,
                          size: 30.sp,
                        ),
                ),
              ),
              SizedBox(width: 16.w),
              // Store Name & Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7.r,
                            height: 7.r,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'متجر نشط',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
