import 'package:flutter/material.dart';

/// Global navigator key to access NavigatorState without BuildContext
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Global notifier for theme mode (Dark/Light)
final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(false);

/// Global variables to store clicked notification data if the app was launched from a background notification
String? pendingIncomingCallType;
Map<String, dynamic>? pendingIncomingCallData;

/// Global flag to prevent auto-navigation during app startup
bool isAppStarting = true;

/// Global variable to store current user role (cached for navigation)
String? currentUserRole;

/// Notifier to track if we are in the admin dashboard flow
final ValueNotifier<bool> isAdminFlowNotifier = ValueNotifier<bool>(false);

/// Custom navigator observer to keep track of the route history stack
final AppRouteObserver appRouteObserver = AppRouteObserver();

class AppRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> _history = [];

  List<Route<dynamic>> get history => _history;

  bool get isInAdminFlow {
    return _history.any((route) {
      final name = route.settings.name;
      return name != null && name.contains('admin');
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _history.add(route);
    _updateAdminStatus();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _history.remove(route);
    _updateAdminStatus();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _history.remove(route);
    _updateAdminStatus();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute != null) {
      _history.remove(oldRoute);
    }
    if (newRoute != null) {
      _history.add(newRoute);
    }
    _updateAdminStatus();
  }

  void _updateAdminStatus() {
    isAdminFlowNotifier.value = isInAdminFlow;
  }
}
