import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/services/user_service.dart';
import 'package:dalal_alqaim/services/ahyxi_otp_service.dart';

import 'package:dalal_alqaim/features/auth/widgets/otp_verification_dialog.dart';

/// Reusable Enterprise Phone Duplicate Check & OTP Verification Service
class PhoneVerificationService {
  /// Check phone duplicate and perform live OTP verification
  static Future<bool> verifyPhoneWithOtp({
    required BuildContext context,
    required String rawPhone,
  }) async {
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleanPhone.length < 10) {
      _showSnackBar(context, 'يرجى إدخال رقم هاتف عراقي صالح', isError: true);
      return false;
    }

    // 1. Pre-Check Duplicate in Firestore
    final check = await UserService.checkPhoneRegistration(cleanPhone);
    if (!context.mounted) return false;
    if (check != null && check['exists'] == true) {
      _showSnackBar(
        context,
        'رقم الهاتف مسجل بالفعل في منصة مدار. سجّل دخولك أولاً أو استخدام رقم هاتف آخر.',
        isError: true,
      );
      return false;
    }

    // 2. Send OTP via WhatsApp / Ahyxi OTP Service and open verification modal
    final otpRes = await AhyxiOtpService.sendOtp(phoneNumber: cleanPhone);
    if (!context.mounted) return false;

    if (!otpRes.isSuccess) {
      _showSnackBar(
        context,
        otpRes.message.isNotEmpty ? otpRes.message : 'ما قدرنا نرسل رمز التحقق. حاول مرة ثانية بعد شوية.',
        isError: true,
      );
      return false;
    }

    final verified = await OtpVerificationDialog.show(
      context: context,
      phoneNumber: cleanPhone,
    );

    return verified == true;
  }

  static void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle()),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
    );
  }
}
