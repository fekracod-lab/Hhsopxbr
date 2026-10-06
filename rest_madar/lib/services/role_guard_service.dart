import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'offline_auth_service.dart';

class RoleGuardService {
  static Future<void> validateRole({
    required BuildContext context,
    required String requiredRole,
    required VoidCallback onSuccess,
    required VoidCallback onPending,
    required String deniedMessage,
    String pendingMessage =
        'عذراً: حساب مطعمك قيد المراجعة حالياً. انتظر شوية... حتى الحصول على الموافقة من الإدارة.',
    String bannedMessage = 'تم حظر حساب المطعم الخاص بك. يرجى التواصل مع الإدارة.',
    String rejectedMessage = 'لقد تم رفض طلب انضمام مطعمك. يرجى التواصل مع الإدارة.',
  }) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;

    if (user == null) {
      // فحص ما إذا كان هناك جلسة أوفلاين نشطة بالفعل
      final isOffline = await OfflineAuthService.instance.hasActiveOfflineSession();
      if (isOffline) {
        onSuccess();
        return;
      }
      if (!context.mounted) return;
      _showError(context, 'انتهت الجلسة. سجّل دخولك أولاً مرة أخرى.');
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (!context.mounted) return;
      if (!doc.exists) {
        await auth.signOut();
        if (context.mounted) _showError(context, 'بيانات الحساب غير موجودة.');
        return;
      }

      final data = doc.data();
      final role = data?['role'];
      final status = (data?['status'] ?? 'pending').toString().toLowerCase();

      // Role check: support 'merchant', 'restaurant', 'restaurant_owner', and 'admin'
      final isRestaurantRole = role == 'merchant' ||
          role == 'restaurant' ||
          role == 'restaurant_owner' ||
          role == 'admin';
      final isRoleAllowed = (requiredRole == 'merchant' || requiredRole == 'restaurant')
          ? isRestaurantRole
          : role == requiredRole;

      if (!isRoleAllowed) {
        await auth.signOut();
        if (context.mounted) _showError(context, deniedMessage);
        return;
      }

      // Hard block statuses
      if (status == 'banned' || status == 'removed') {
        await auth.signOut();
        if (context.mounted) _showError(context, bannedMessage);
        return;
      }

      if (status == 'rejected') {
        await auth.signOut();
        if (context.mounted) _showError(context, rejectedMessage);
        return;
      }

      // Pending
      if (status == 'pending') {
        if (context.mounted) _showError(context, pendingMessage);
        onPending();
        return;
      }

      // Approved/Active
      if (status == 'approved' || status == 'active') {
        onSuccess();
        return;
      }

      // Unknown status
      await auth.signOut();
      if (context.mounted) _showError(context, 'تم رفض الوصول.');
    } catch (_) {
      // عند انقطاع الإنترنت أو تعذر الوصول لـ Firestore لا يتم تسجيل الخروج قسرياً
      // إذا كان المطعم مخزناً محلياً كحساب نشط ومقبول
      final isCached = OfflineAuthService.instance.isMerchantCached(user.uid);
      final isOfflineActive = await OfflineAuthService.instance.hasActiveOfflineSession();

      if (isCached || isOfflineActive) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'تم الدخول في وضع عدم الاتصال (أوفلاين) عبر البيانات المحفوظة محلياً.',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              backgroundColor: Colors.amber.shade800,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        onSuccess();
        return;
      }

      // في حال لم يكن الحساب محفوظاً إطلاقاً
      await auth.signOut();
      if (context.mounted) _showError(context, 'خطأ في الاتصال بالشبكة. حاول مرة ثانية.');
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent.shade700,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
