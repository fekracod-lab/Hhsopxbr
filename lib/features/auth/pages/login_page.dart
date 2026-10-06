import 'package:flutter/material.dart';
import 'package:dalal_alqaim/features/auth/pages/unified_login_page.dart';
import 'package:dalal_alqaim/features/auth/widgets/role_selector_tab.dart';

export 'package:dalal_alqaim/features/auth/pages/unified_login_page.dart';

class EnhancedLoginPage extends StatelessWidget {
  final void Function(bool)? onThemeChanged;
  final UserRole initialRole;

  const EnhancedLoginPage({
    super.key,
    this.onThemeChanged,
    this.initialRole = UserRole.customer,
  });

  @override
  Widget build(BuildContext context) {
    return UnifiedLoginPage(
      initialRole: initialRole,
      onThemeChanged: onThemeChanged,
    );
  }
}
