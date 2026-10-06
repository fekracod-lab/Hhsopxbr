import 'package:flutter/material.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class FormTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;
  final bool obscureText;
  final Widget? suffixIcon;

  const FormTextField({
    super.key,
    this.controller,
    required this.label,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: app_colors.darkText,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          obscureText: obscureText,
          style: const TextStyle(color: app_colors.darkText),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: app_colors.darkSubText),
            prefixIcon: Icon(prefixIcon, color: app_colors.darkSubText),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: app_colors.darkCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: app_colors.primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: maxLines > 1 ? 16 : 12),
          ),
          validator: validator,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
