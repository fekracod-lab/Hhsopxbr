import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:dalal_alqaim/services/ahyxi_otp_service.dart';

/// حوار وشيت إدخال رمز OTP عصري، سريع، ويدعم الملء التلقائي واللصق الذكي
class OtpVerificationDialog {
  /// عرض الشيت المخصص للتحقق مع معالجة آمنة للملاحة ومنع أي توقف (Crash-Proof)
  static Future<bool> show({
    required BuildContext context,
    required String phoneNumber,
    String? verificationId,
    String? userName,
    String? userRole,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (sheetCtx) => _OtpSheetContent(
        phoneNumber: phoneNumber,
        verificationId: verificationId,
        userName: userName,
        userRole: userRole,
      ),
    );

    return result == true;
  }
}

class _OtpSheetContent extends StatefulWidget {
  final String phoneNumber;
  final String? verificationId;
  final String? userName;
  final String? userRole;

  const _OtpSheetContent({
    required this.phoneNumber,
    this.verificationId,
    this.userName,
    this.userRole,
  });

  @override
  State<_OtpSheetContent> createState() => _OtpSheetContentState();
}

class _OtpSheetContentState extends State<_OtpSheetContent> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final TextEditingController _hiddenAutoFillController = TextEditingController();

  bool _isVerifying = false;
  String? _errorMessage;
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Auto-focus first box after sheet animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft > 0) {
        if (mounted) setState(() => _secondsLeft--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _hiddenAutoFillController.dispose();
    super.dispose();
  }

  String get _currentCode => _controllers.map((c) => c.text.trim()).join();

  void _handleDigitChange(int index, String value) {
    if (value.length > 1) {
      // User pasted or auto-filled multiple digits into this box
      _fillFromFullString(value);
      return;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        // If all 6 filled, auto-verify!
        if (_currentCode.length == 6) {
          _submitVerification();
        }
      }
    }
    setState(() => _errorMessage = null);
  }

  void _handleBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
    setState(() => _errorMessage = null);
  }

  void _fillFromFullString(String text) {
    final clean = text.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return;

    for (int i = 0; i < 6; i++) {
      if (i < clean.length) {
        _controllers[i].text = clean[i];
      } else {
        _controllers[i].clear();
      }
    }

    if (clean.length >= 6) {
      _focusNodes[5].unfocus();
      HapticFeedback.mediumImpact();
      _submitVerification();
    } else {
      _focusNodes[clean.length.clamp(0, 5)].requestFocus();
    }
    setState(() {});
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _fillFromFullString(data.text!);
    }
  }

  Future<void> _submitVerification() async {
    final code = _currentCode;
    if (code.length != 6) {
      setState(() => _errorMessage = 'يرجى إدخال كافة أرقام رمز التحقق (6 أرقام)');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      // 1. التحقق عبر خدمة Ahyxi OTP
      final verifyRes = await AhyxiOtpService.verifyOtp(
        phoneNumber: widget.phoneNumber,
        otp: code,
      );

      if (verifyRes.isSuccess) {
        // إكمال تسجيل الدخول ومزامنة الحساب بالتوكن الرسمي
        await AhyxiOtpService.completeFirebaseLoginWithVerifiedPhone(
          phoneNumber: widget.phoneNumber,
          name: widget.userName,
          role: widget.userRole,
          customToken: verifyRes.customToken,
        );

        _timer?.cancel();
        if (mounted) {
          Navigator.of(context).pop(true); // Return success safely
        }
        return;
      }

      // 2. Fallback: إذا كان الإرسال تم عبر Firebase Phone Auth
      if (widget.verificationId != null) {
        try {
          final cred = PhoneAuthProvider.credential(
            verificationId: widget.verificationId!,
            smsCode: code,
          );
          await FirebaseAuth.instance.signInWithCredential(cred);
          _timer?.cancel();
          if (mounted) {
            Navigator.of(context).pop(true);
          }
          return;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = verifyRes.message.isNotEmpty
              ? verifyRes.message
              : 'رمز التحقق غير صحيح أو منتهي الصلاحية';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'حدث خطأ أثناء التحقق: $e';
        });
      }
    }
  }

  Future<void> _resendCode() async {
    if (_secondsLeft > 0) return;
    _startCountdown();
    final res = await AhyxiOtpService.sendOtp(phoneNumber: widget.phoneNumber);
    if (!mounted) return;
    if (res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت إعادة إرسال رمز التحقق بنجاح', style: GoogleFonts.ibmPlexSansArabic()),
          backgroundColor: app_colors.primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() => _errorMessage = res.message.isNotEmpty ? res.message : 'تعذر إعادة الإرسال حالياً');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = app_colors.primaryColor;
    final surfaceColor = isDark ? const Color(0xFF0C1D1D) : Colors.white;

    return Container(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 16.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2EBE9),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag Handle ──
          Center(
            child: Container(
              width: 40.w,
              height: 4.5.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // ── Header Icon ──
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(alpha: isDark ? 0.15 : 0.1),
              border: Border.all(color: primary.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Icon(Icons.shield_outlined, color: primary, size: 32.sp),
          ),
          SizedBox(height: 12.h),

          Text(
            'تأكيد رمز التحقق',
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w800,
              fontSize: 19.sp,
              color: isDark ? Colors.white : const Color(0xFF112525),
            ),
          ),
          SizedBox(height: 6.h),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'أرسلنا الرمز إلى',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? Colors.white60 : const Color(0xFF5A7A7A),
                  fontSize: 13.sp,
                ),
              ),
              Text(
                widget.phoneNumber,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.bold,
                  color: primary,
                  fontSize: 13.5.sp,
                ),
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
          SizedBox(height: 20.h),

          // ── Paste Code Shortcut Button ──
          InkWell(
            onTap: _pasteFromClipboard,
            borderRadius: BorderRadius.circular(20.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F8F7),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.content_paste_rounded, size: 14.sp, color: primary),
                  SizedBox(width: 6.w),
                  Text(
                    'لصق الرمز المنسوخ',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 18.h),

          // ── 6 OTP Input Boxes ──
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final isCurrent = _focusNodes[index].hasFocus;
                final hasValue = _controllers[index].text.isNotEmpty;

                return Container(
                  width: 44.w,
                  height: 52.h,
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  decoration: BoxDecoration(
                    color: isDark
                        ? (hasValue ? const Color(0xFF143030) : Colors.white.withValues(alpha: 0.04))
                        : (hasValue ? const Color(0xFFE6F5F3) : const Color(0xFFF8FAFB)),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: isCurrent
                          ? primary
                          : (hasValue
                              ? primary.withValues(alpha: 0.5)
                              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
                      width: isCurrent ? 2.0 : 1.2,
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: primary.withValues(alpha: isDark ? 0.3 : 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: (event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.backspace &&
                            _controllers[index].text.isEmpty) {
                          _handleBackspace(index);
                        }
                      },
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6), // Allow paste up to 6
                        ],
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F2020),
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          counterText: '',
                        ),
                        onChanged: (val) => _handleDigitChange(index, val),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // ── Error Message ──
          if (_errorMessage != null) ...[
            SizedBox(height: 14.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, size: 15.sp, color: Colors.redAccent),
                  SizedBox(width: 6.w),
                  Flexible(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 16.h),

          // ── Resend Countdown / Button ──
          _secondsLeft > 0
              ? Text(
                  'إعادة إرسال الرمز خلال $_secondsLeft ثانية',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5.sp,
                    color: isDark ? Colors.white38 : const Color(0xFF64748B),
                  ),
                )
              : TextButton.icon(
                  onPressed: _resendCode,
                  icon: Icon(Icons.refresh_rounded, size: 16.sp, color: primary),
                  label: Text(
                    'إعادة إرسال الرمز الآن',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                      color: primary,
                    ),
                  ),
                ),

          SizedBox(height: 20.h),

          // ── Submit Verification Button ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _submitVerification,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                elevation: 0,
              ),
              child: _isVerifying
                  ? SizedBox(
                      height: 20.r,
                      width: 20.r,
                      child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                    )
                  : Text(
                      'تأكيد ودخول',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
