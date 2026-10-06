import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../../domain/entities/restaurant_management_models.dart';
import '../../domain/services/restaurant_management_calculator.dart';

/// نافذة إدارة وتغيير كلمة مرور مالك المطعم (Restaurant Owner Password Dialog)
class RestaurantOwnerPasswordDialog extends StatefulWidget {
  final String ownerId;
  final String restaurantName;
  final RestaurantOwnerRecord ownerRecord;
  final Future<bool> Function(String ownerId, String newPassword) onChangePassword;

  const RestaurantOwnerPasswordDialog({
    super.key,
    required this.ownerId,
    required this.restaurantName,
    required this.ownerRecord,
    required this.onChangePassword,
  });

  static void show(
    BuildContext context, {
    required String ownerId,
    required String restaurantName,
    required RestaurantOwnerRecord ownerRecord,
    required Future<bool> Function(String ownerId, String newPassword) onChangePassword,
  }) {
    showDialog(
      context: context,
      builder: (_) => RestaurantOwnerPasswordDialog(
        ownerId: ownerId,
        restaurantName: restaurantName,
        ownerRecord: ownerRecord,
        onChangePassword: onChangePassword,
      ),
    );
  }

  @override
  State<RestaurantOwnerPasswordDialog> createState() => _RestaurantOwnerPasswordDialogState();
}

class _RestaurantOwnerPasswordDialogState extends State<RestaurantOwnerPasswordDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.withValues(alpha: 0.15), Colors.deepPurple.withValues(alpha: 0.05)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset_rounded, color: Colors.deepPurple, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إدارة كلمة مرور المالك',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      widget.restaurantName,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // عرض كلمة المرور الحالية
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.key_rounded, size: 18, color: Colors.amber[700]),
                          const SizedBox(width: 8),
                          Text(
                            'كلمة المرور الحالية',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber[700]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              'محمية بموجب سياسة خصوصية أبل',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // سجل كلمات المرور القديمة
                if (widget.ownerRecord.passwordHistory.isNotEmpty)
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Row(
                        children: [
                          Icon(Icons.history_rounded, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          const Text(
                            'سجل كلمات المرور السابقة',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      children: [
                        Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: widget.ownerRecord.passwordHistory.length,
                            itemBuilder: (context, i) {
                              final hist = widget.ownerRecord.passwordHistory.reversed.toList()[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    SelectableText(
                                      hist.password,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      intl.DateFormat('yyyy/MM/dd').format(hist.changedAt),
                                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),

                // حقل كلمة المرور الجديدة
                const Text(
                  'كلمة مرور جديدة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'أدخل كلمة المرور الجديدة (6 أحرف على الأقل)',
                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.deepPurple, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.deepPurple)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 20, color: Colors.white),
                  label: Text(
                    _isLoading ? 'جاري التغيير...' : 'تغيير كلمة المرور',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isLoading ? null : _handleChangePassword,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleChangePassword() async {
    final newPass = _passwordController.text.trim();
    if (!RestaurantManagementCalculator.validatePassword(newPass)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل', style: TextStyle()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final success = await widget.onChangePassword(widget.ownerId, newPass);
      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تغيير كلمة مرور المالك بنجاح!', style: TextStyle()),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل تغيير كلمة المرور', style: TextStyle()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تغيير كلمة المرور: $e', style: const TextStyle()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }
  }
}
