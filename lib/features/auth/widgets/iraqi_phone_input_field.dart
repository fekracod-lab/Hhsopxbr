import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

/// 🇮🇶 حقل إدخال رقم الهاتف العراقي الاحترافي والموحد
/// يمنع أي خربطة في اتجاه الأرقام (+964) ويوفر تجربة كتابة سلسة ومريحة للمستخدم
class IraqiPhoneInputField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final String? hintText;
  final bool autoFocus;

  const IraqiPhoneInputField({
    super.key,
    required this.controller,
    this.validator,
    this.onChanged,
    this.hintText,
    this.autoFocus = false,
  });

  @override
  State<IraqiPhoneInputField> createState() => _IraqiPhoneInputFieldState();
}

class _IraqiPhoneInputFieldState extends State<IraqiPhoneInputField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _isFocused = _focusNode.hasFocus);
      }
    });
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = app_colors.primaryColor;
    final cardBg = isDark ? app_colors.darkCard.withValues(alpha: 0.7) : Colors.white;
    final borderColor = _isFocused
        ? primary
        : (isDark ? app_colors.darkBorder : const Color(0xFFE2EBE9));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormField<String>(
          validator: widget.validator ??
              (val) {
                final text = widget.controller.text.trim().replaceAll(RegExp(r'\s+'), '');
                if (text.isEmpty) return 'يرجى إدخال رقم الهاتف';
                if (text.length < 10) return 'رقم الهاتف يجب أن يتكون من 10 أو 11 رقم';
                if (!text.startsWith('07') && !text.startsWith('7')) {
                  return 'يرجى إدخال رقم هاتف عراقي يبدأ بـ 07 أو 7';
                }
                return null;
              },
          builder: (formFieldState) {
            final hasError = formFieldState.hasError;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56.h,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: hasError ? Colors.redAccent : borderColor,
                      width: _isFocused || hasError ? 1.8 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isFocused
                            ? primary.withValues(alpha: isDark ? 0.2 : 0.08)
                            : Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                        blurRadius: _isFocused ? 10 : 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // 1. Iraqi Country Badge & Flag
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '🇮🇶',
                              style: TextStyle(fontSize: 20.sp),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              '+964',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                          ],
                        ),
                      ),

                      // 2. Vertical Divider
                      Container(
                        height: 24.h,
                        width: 1.2,
                        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      ),

                      SizedBox(width: 8.w),

                      // 3. Isolated LTR Phone Text Field (Guarantees zero numbers flipping)
                      Expanded(
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: TextField(
                            controller: widget.controller,
                            focusNode: _focusNode,
                            autofocus: widget.autoFocus,
                            keyboardType: TextInputType.phone,
                            textAlign: TextAlign.left,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                            decoration: InputDecoration(
                              hintText: widget.hintText ?? '0770 123 4567',
                              hintStyle: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.normal,
                                letterSpacing: 1.0,
                                color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 14.h),
                            ),
                            onChanged: (val) {
                              formFieldState.didChange(val);
                              if (widget.onChanged != null) widget.onChanged!(val);
                            },
                          ),
                        ),
                      ),

                      // 4. Quick Clear Button
                      if (widget.controller.text.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.cancel_rounded,
                            size: 18.sp,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          onPressed: () {
                            widget.controller.clear();
                            formFieldState.didChange('');
                            if (widget.onChanged != null) widget.onChanged!('');
                          },
                          splashRadius: 18.r,
                        )
                      else
                        Padding(
                          padding: EdgeInsets.only(left: 14.w),
                          child: Icon(
                            Icons.phone_iphone_rounded,
                            size: 19.sp,
                            color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                ),

                // Error Message
                if (hasError)
                  Padding(
                    padding: EdgeInsets.only(top: 6.h, right: 6.w),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, size: 14.sp, color: Colors.redAccent),
                        SizedBox(width: 4.w),
                        Text(
                          formFieldState.errorText ?? '',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
