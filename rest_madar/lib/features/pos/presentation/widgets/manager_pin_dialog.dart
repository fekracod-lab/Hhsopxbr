import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/audit_log_service.dart';

class ManagerAuthResult {
  final bool success;
  final String reason;

  ManagerAuthResult({required this.success, required this.reason});
}

/// نافذة تحقق ومصادقة المشرف / المدير (Manager PIN & Reason Dialog)
/// تستخدم لحماية الإجراءات الحساسة: حذف طلب، تعديل سعر، إلغاء صنف، فتح الدرج
class ManagerPinDialog extends StatefulWidget {
  final String title;
  final String actionDescription;
  final bool requireReason;

  const ManagerPinDialog({
    super.key,
    required this.title,
    required this.actionDescription,
    this.requireReason = true,
  });

  static Future<ManagerAuthResult?> show(
    BuildContext context, {
    required String title,
    required String actionDescription,
    bool requireReason = true,
  }) {
    return showDialog<ManagerAuthResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ManagerPinDialog(
        title: title,
        actionDescription: actionDescription,
        requireReason: requireReason,
      ),
    );
  }

  @override
  State<ManagerPinDialog> createState() => _ManagerPinDialogState();
}

class _ManagerPinDialogState extends State<ManagerPinDialog> {
  final _pinController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndSubmit() async {
    final pin = _pinController.text.trim();
    final reason = _reasonController.text.trim();

    if (pin.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال رمز PIN الخاص بالمدير');
      return;
    }

    if (widget.requireReason && reason.isEmpty) {
      setState(() => _errorMessage = 'يرجى كتابة سبب الإجراء لتوثيقه في السجل');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isValid = await AuditLogService.instance.verifyManagerPin(pin);

    if (!mounted) return;

    if (isValid) {
      Navigator.of(context).pop(ManagerAuthResult(
        success: true,
        reason: reason.isNotEmpty ? reason : 'تمت الموافقة برمز المدير',
      ));
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'رمز PIN غير صحيح! تأكد من صلاحيات الإدارة';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: PosTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width.clamp(300.0, 440.0),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // العنوان مع أيقونة القفل
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_outlined, color: Colors.amber, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: PosTheme.textLight,
                          ),
                        ),
                        Text(
                          widget.actionDescription,
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: PosTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // حقل كود المدير PIN
              Text(
                'رمز PIN للمدير / المشرف:',
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.w600, color: PosTheme.textLight),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                autofocus: true,
                style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 18, letterSpacing: 6),
                decoration: InputDecoration(
                  hintText: '••••',
                  hintStyle: const TextStyle(color: PosTheme.textMuted, letterSpacing: 4),
                  filled: true,
                  fillColor: PosTheme.sidebarDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.lock_outline, color: PosTheme.primary),
                ),
                onSubmitted: (_) => _verifyAndSubmit(),
              ),
              const SizedBox(height: 14),

              // حقل سبب الإجراء
              if (widget.requireReason) ...[
                Text(
                  'سبب الإجراء (للتوثيق في سجل التدقيق):',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.w600, color: PosTheme.textLight),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _reasonController,
                  maxLines: 2,
                  style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'مثال: خطأ في تسجيل الصنف، طلب الزبون إلغاء، خصم خاص...',
                    hintStyle: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textMuted, fontSize: 12),
                    filled: true,
                    fillColor: PosTheme.sidebarDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // رسالة الخطأ
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // أزرار التحكم
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(null),
                    child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textMuted)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _verifyAndSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PosTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            'تأكيد ومتابعة',
                            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
