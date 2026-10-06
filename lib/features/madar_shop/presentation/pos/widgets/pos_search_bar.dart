// شريط البحث وقارئ الباركود لنقطة البيع (MADAR SHOP POS Search & Barcode Bar)
// Presentation Layer — Instant Keyboard Wedge Scan & Debounced Search

import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/windows_pos_controller.dart';

class PosSearchBar extends StatefulWidget {
  final WindowsPosController controller;
  final FocusNode focusNode;

  const PosSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  @override
  State<PosSearchBar> createState() => _PosSearchBarState();
}

class _PosSearchBarState extends State<PosSearchBar> {
  final TextEditingController _textCtrl = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _textCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      widget.controller.setSearchQuery(value);
    });
  }

  Future<void> _onSubmitted(String value) async {
    final clean = value.trim();
    if (clean.isEmpty) return;

    // مسح الحقل فوراً لاستقبال القراءة التالية من الماسح
    _textCtrl.clear();
    widget.controller.setSearchQuery('');

    // محاولة الإضافة المباشرة عبر محرك حل الباركود
    final success = await widget.controller.scanBarcode(clean);
    if (!success) {
      widget.controller.setSearchQuery(clean);
      _textCtrl.text = clean;
    }

    // إعادة التركيز على الحقل لضمان التقاط الماسح اللاسلكي/السلكي
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.focusNode.hasFocus
              ? const Color(0xFF1E88E5)
              : (isDark ? Colors.white10 : Colors.black12),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _textCtrl,
        focusNode: widget.focusNode,
        onChanged: _onChanged,
        onSubmitted: _onSubmitted,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14, fontFamily: 'Cairo'),
        decoration: InputDecoration(
          hintText: 'امسح الباركود، أو ابحث بالاسم / الرمز (F1)...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.black38,
            fontFamily: 'Cairo',
          ),
          prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 22, color: Color(0xFF1E88E5)),
          suffixIcon: _textCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _textCtrl.clear();
                    widget.controller.setSearchQuery('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
