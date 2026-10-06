import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// حقل بحث معياري موحّد بجميع الشاشات (بحث الوجبات، الأقسام، الطلبات، الأصناف)
class PosSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String hintText;
  final double width;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final void Function()? onSubmitted;

  const PosSearchField({
    super.key,
    required this.onChanged,
    this.hintText = 'بحث سريع...',
    this.width = 260,
    this.controller,
    this.focusNode,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: (_) => onSubmitted?.call(),
        style: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: GoogleFonts.ibmPlexSansArabic(
            color: c.textDisabled,
            fontSize: 12,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: c.primary.withValues(alpha: 0.8),
            size: 20,
          ),
          suffixIcon: IconButton(
            onPressed: () {
              controller?.clear();
              onChanged('');
            },
            icon: Icon(
              Icons.close_rounded,
              size: 16,
              color: c.textDisabled,
            ),
            tooltip: 'مسح البحث',
          ),
          filled: true,
          fillColor: c.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}