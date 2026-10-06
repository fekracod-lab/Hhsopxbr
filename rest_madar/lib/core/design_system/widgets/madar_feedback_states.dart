import 'package:flutter/material.dart';
import '../madar_colors.dart';
import '../madar_radius.dart';
import '../madar_typography.dart';
import 'madar_buttons.dart';

/// =====================================================================
///  Madar Design System — حالات الواجهة المؤسسية (Empty, Loading, Error)
/// =====================================================================

/// الحالة الفارغة الموحدة (Empty State)
class MadarEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MadarEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: MadarColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: MadarColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: MadarTypography.sectionTitle(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                message,
                style: MadarTypography.caption(
                  color: MadarColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              MadarPrimaryButton(
                label: actionLabel!,
                onPressed: onAction,
                height: 42,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// حالة التحميل المؤسسية (Loading State)
class MadarLoadingState extends StatelessWidget {
  final String? message;

  const MadarLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: MadarColors.primary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 14),
              Text(
                message!,
                style: MadarTypography.caption(
                  color: MadarColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// حالة الخطأ الواضحة مع زر إعادة المحاولة (Error State)
class MadarErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const MadarErrorState({
    super.key,
    this.title = 'تعذر تحميل البيانات',
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: MadarColors.dangerSoft,
          borderRadius: MadarRadius.md,
          border: Border.all(color: MadarColors.danger.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: MadarColors.danger,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: MadarTypography.sectionTitle(color: MadarColors.danger),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: MadarTypography.caption(color: MadarColors.danger),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              MadarSecondaryButton(
                label: 'إعادة المحاولة',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
                height: 40,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
