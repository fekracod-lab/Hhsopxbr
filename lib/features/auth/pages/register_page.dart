import 'package:flutter/material.dart';
import 'package:dalal_alqaim/features/auth/pages/unified_login_page.dart';
import 'package:dalal_alqaim/features/auth/widgets/role_selector_tab.dart';

export 'package:dalal_alqaim/features/auth/pages/unified_login_page.dart';

/// Unified Register Screen Wrapper
/// Delegates directly to [UnifiedLoginPage] with `initialIsRegisterMode = true`
/// providing a single, cohesive, modern authentication experience for all roles.
class EnhancedRegisterPage extends StatelessWidget {
  final UserRole initialRole;
  final void Function(bool)? onThemeChanged;

  const EnhancedRegisterPage({
    super.key,
    this.initialRole = UserRole.customer,
    this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return UnifiedLoginPage(
      initialRole: initialRole,
      initialIsRegisterMode: true,
      onThemeChanged: onThemeChanged,
    );
  }
}
