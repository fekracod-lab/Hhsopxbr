import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dalal_alqaim/services/onesignal_service.dart';

class RoleGuardService {
  static Future<void> validateRole({
    required BuildContext context,
    required String requiredRole,
    required VoidCallback onSuccess,
    required VoidCallback onPending,
    required String deniedMessage,
    String pendingMessage =
        'عذراً: حسابك قيد المراجعة حالياً. انتظر شوية... حتى الحصول على الموافقة.',
    String bannedMessage = 'تم حظر حسابك. يرجى التواصل مع الإدارة.',
    String rejectedMessage = 'لقد تم رفض طلبك. يرجى التواصل مع الإدارة لمزيد من المعلومات.',
  }) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;

    if (user == null) {
      _showError(context, 'انتهت الجلسة. سجّل دخولك أولاً مرة أخرى.');
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      Map<String, dynamic> data = doc.data() ?? {};
      String role = (data['role'] ?? '').toString().toLowerCase();
      String subRole = (data['subRole'] ?? '').toString().toLowerCase();
      String status = (data['status'] ?? 'pending').toString().toLowerCase();
      bool isApproved = data['isApproved'] as bool? ?? (status == 'active' || status == 'approved');

      // ── Cross-Collection Role Recovery & Verification ──
      if (requiredRole == 'restaurant') {
        try {
          final restDoc = await FirebaseFirestore.instance.collection('restaurants').doc(user.uid).get();
          if (restDoc.exists) {
            final restData = restDoc.data() ?? {};
            role = 'restaurant';
            final rStatus = (restData['status'] ?? '').toString().toLowerCase();
            final rApproved = restData['isApproved'] == true || rStatus == 'active' || rStatus == 'approved';
            if (rApproved) {
              status = 'active';
              isApproved = true;
            } else if (rStatus.isNotEmpty) {
              status = rStatus;
            }
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'role': 'restaurant',
              'status': status,
              'isApproved': isApproved,
            }, SetOptions(merge: true));
          }
        } catch (_) {}
      } else if (requiredRole == 'store') {
        try {
          final storeDoc = await FirebaseFirestore.instance.collection('stores').doc(user.uid).get();
          if (storeDoc.exists) {
            final stData = storeDoc.data() ?? {};
            role = 'store';
            final stStatus = (stData['status'] ?? '').toString().toLowerCase();
            final stApproved = stData['isApproved'] == true || stStatus == 'active' || stStatus == 'approved';
            if (stApproved) {
              status = 'active';
              isApproved = true;
            } else if (stStatus.isNotEmpty) {
              status = stStatus;
            }
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'role': 'store',
              'status': status,
              'isApproved': isApproved,
            }, SetOptions(merge: true));
          }
        } catch (_) {}
      } else if (requiredRole == 'captain' || requiredRole == 'driver' || requiredRole == 'taxi_captain') {
        try {
          final drDoc = await FirebaseFirestore.instance.collection('drivers').doc(user.uid).get();
          if (drDoc.exists) {
            final drData = drDoc.data() ?? {};
            role = 'driver';
            final drStatus = (drData['status'] ?? '').toString().toLowerCase();
            final drApproved = drData['isApproved'] == true || drStatus == 'active' || drStatus == 'approved';
            if (drApproved) {
              status = 'active';
              isApproved = true;
            } else if (drStatus.isNotEmpty) {
              status = drStatus;
            }
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'role': 'driver',
              'status': status,
              'isApproved': isApproved,
            }, SetOptions(merge: true));
          }
        } catch (_) {}
      } else if (requiredRole == 'delivery') {
        try {
          final delivDoc = await FirebaseFirestore.instance.collection('delivery_boys').doc(user.uid).get();
          if (delivDoc.exists) {
            final dlData = delivDoc.data() ?? {};
            role = 'delivery';
            final dlStatus = (dlData['status'] ?? '').toString().toLowerCase();
            final dlApproved = dlData['isApproved'] == true || dlStatus == 'active' || dlStatus == 'approved';
            if (dlApproved) {
              status = 'active';
              isApproved = true;
            } else if (dlStatus.isNotEmpty) {
              status = dlStatus;
            }
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'role': 'delivery',
              'status': status,
              'isApproved': isApproved,
            }, SetOptions(merge: true));
          }
        } catch (_) {}
      }

      if (!context.mounted) return;

      // Role check: flexible evaluation for each isolated role
      bool isRoleMatch = false;
      if (requiredRole == 'captain' || requiredRole == 'taxi_captain' || requiredRole == 'driver') {
        isRoleMatch = (role == 'captain' || role == 'taxi_captain' || role == 'driver' || subRole == 'captain' || subRole == 'driver');
      } else if (requiredRole == 'delivery' || requiredRole == 'delivery_captain' || requiredRole == 'delivery_boy') {
        isRoleMatch = (role == 'delivery' || role == 'delivery_captain' || role == 'delivery_boy' || subRole == 'delivery' || (role == 'driver' && data['isDelivery'] == true));
      } else if (requiredRole == 'restaurant') {
        isRoleMatch = (role == 'restaurant' || role == 'restaurant_owner' || role == 'merchant' || subRole == 'restaurant');
      } else if (requiredRole == 'store') {
        isRoleMatch = (role == 'store' || role == 'store_owner' || role == 'market' || subRole == 'store');
      } else if (requiredRole == 'customer') {
        isRoleMatch = (role == 'customer' || role.isEmpty);
      } else {
        isRoleMatch = (role == requiredRole);
      }

      if (!isRoleMatch) {
        await OneSignalService.logout();
        await auth.signOut();
        if (context.mounted) _showError(context, deniedMessage);
        return;
      }

      // Hard block statuses
      if (status == 'banned' || status == 'removed' || data['isBanned'] == true) {
        await OneSignalService.logout();
        await auth.signOut();
        if (context.mounted) _showError(context, bannedMessage);
        return;
      }

      if (status == 'rejected') {
        await OneSignalService.logout();
        await auth.signOut();
        if (context.mounted) _showError(context, rejectedMessage);
        return;
      }

      // Cache the validated role locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUserRole_${user.uid}', requiredRole);
      await prefs.setString('currentUserRole', requiredRole);
      await prefs.setString('currentUserId', user.uid);
      await OneSignalService.syncUserRole(user.uid);

      // Pending: allow session but route to status page via callback
      if (!isApproved || status == 'pending' || status == 'under_review' || status == 'waiting') {
        if (context.mounted) _showError(context, pendingMessage);
        onPending();
        return;
      }

      // Approved/Active
      if (status == 'approved' || status == 'active' || isApproved) {
        onSuccess();
        return;
      }

      // Unknown status: fallback to pending
      onPending();
    } catch (_) {
      await auth.signOut();
      if (context.mounted) _showError(context, 'خطأ في الشبكة. حاول مرة ثانية بعد شوية.');
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle()),
        behavior: SnackBarBehavior.fixed,
        backgroundColor: Colors.redAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
