import 'package:flutter/material.dart';

/// حارس النظام لمنع الانهيارات والتقاط الاستثناءات في كاشير مدار (Shop Crash Guard)
class ShopCrashGuard {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static void init() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('[ShopCrashGuard] FlutterError: ${details.exceptionAsString()}');
    };
  }

  static void reportUnhandledError(Object error, StackTrace? stack, [String? contextTag]) {
    debugPrint('[ShopCrashGuard] Unhandled Error in $contextTag: $error');
    if (stack != null) {
      debugPrint('[ShopCrashGuard] StackTrace: $stack');
    }
  }

  static Widget appBuilder(BuildContext context, Widget? child) {
    return child ?? const SizedBox.shrink();
  }
}
