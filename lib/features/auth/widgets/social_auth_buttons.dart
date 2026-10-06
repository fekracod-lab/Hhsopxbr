import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class SocialAuthButtons extends StatelessWidget {
  final VoidCallback onGoogleTap;
  final VoidCallback? onAppleTap;
  final bool isLoading;

  const SocialAuthButtons({
    super.key,
    required this.onGoogleTap,
    this.onAppleTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? app_colors.darkBorder : app_colors.borderColor;

    return Row(
      children: [
        // Apple Button First if available on iOS (Per Apple App Store Guideline 4.8)
        if (onAppleTap != null) ...[
          Expanded(
            child: _buildAppleBtn(
              context: context,
              onTap: isLoading ? null : onAppleTap,
              isDark: isDark,
            ),
          ),
          SizedBox(width: 12.w),
        ],

        // Google Button
        Expanded(
          child: _buildGoogleBtn(
            context: context,
            onTap: isLoading ? null : onGoogleTap,
            borderColor: borderColor,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  /// Official Apple HIG Compliant Button
  Widget _buildAppleBtn({
    required BuildContext context,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    final bg = isDark ? Colors.white : Colors.black;
    final fg = isDark ? Colors.black : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 13.h),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.apple_rounded,
                size: 24.r,
                color: fg,
              ),
              SizedBox(width: 8.w),
              Text(
                'Apple',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Google Button
  Widget _buildGoogleBtn({
    required BuildContext context,
    required VoidCallback? onTap,
    required Color borderColor,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 13.h),
          decoration: BoxDecoration(
            color: isDark
                ? app_colors.darkCard.withValues(alpha: 0.7)
                : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'imges/google.png',
                height: 22.r,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.g_mobiledata_rounded,
                  size: 28.r,
                  color: Colors.redAccent,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                'Google',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? app_colors.darkText : app_colors.textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
