import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dalal_alqaim/services/onesignal_service.dart';

/// Web Session Security Guard: Auto Log-out on inactivity (15 mins default)
class WebSessionGuard extends StatefulWidget {
  final Widget child;
  final Duration inactivityDuration;

  const WebSessionGuard({
    super.key,
    required this.child,
    this.inactivityDuration = const Duration(minutes: 15),
  });

  @override
  State<WebSessionGuard> createState() => _WebSessionGuardState();
}

class _WebSessionGuardState extends State<WebSessionGuard> {
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  void _resetTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(widget.inactivityDuration, _handleInactivityLogout);
  }

  Future<void> _handleInactivityLogout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      debugPrint(' [WebSessionGuard] Admin session timed out due to 15 mins inactivity.');
      
      await OneSignalService.logout();
      await FirebaseAuth.instance.signOut();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('currentUserRole');
      await prefs.remove('currentUserId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم إنهاء الجلسة تلقائياً لعدم النشاط لحماية الحساب الإداري.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      onPointerHover: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
