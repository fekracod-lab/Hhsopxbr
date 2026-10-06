// صفحة تسجيل دخول موظفي المتجر (MADAR SHOP Employee Login Screen)
// Presentation Layer — Fast Windows Keyboard-Friendly Auth

import 'package:flutter/material.dart';
import '../../application/auth/madar_shop_auth_service.dart';
import '../../domain/identity/entities/shop_session.dart';
import '../../domain/identity/entities/shop_user.dart';

class MadarShopLoginPage extends StatefulWidget {
  final MadarShopAuthService authService;
  final void Function(ShopUser user, ShopSession session) onLoginSuccess;
  final String initialBusinessId;
  final String initialBranchId;
  final String initialTerminalId;

  const MadarShopLoginPage({
    super.key,
    required this.authService,
    required this.onLoginSuccess,
    this.initialBusinessId = 'BIZ-01',
    this.initialBranchId = 'BR-01',
    this.initialTerminalId = 'POS-WIN-01',
  });

  @override
  State<MadarShopLoginPage> createState() => _MadarShopLoginPageState();
}

class _MadarShopLoginPageState extends State<MadarShopLoginPage> {
  late final TextEditingController _businessCtrl;
  late final TextEditingController _branchCtrl;
  late final TextEditingController _terminalCtrl;
  late final TextEditingController _identifierCtrl;
  late final TextEditingController _secretCtrl;

  bool _obscureSecret = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _businessCtrl = TextEditingController(text: widget.initialBusinessId);
    _branchCtrl = TextEditingController(text: widget.initialBranchId);
    _terminalCtrl = TextEditingController(text: widget.initialTerminalId);
    _identifierCtrl = TextEditingController();
    _secretCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _businessCtrl.dispose();
    _branchCtrl.dispose();
    _terminalCtrl.dispose();
    _identifierCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    final identifier = _identifierCtrl.text.trim();
    final secret = _secretCtrl.text.trim();
    final businessId = _businessCtrl.text.trim();
    final branchId = _branchCtrl.text.trim();
    final terminalId = _terminalCtrl.text.trim();

    if (identifier.isEmpty || secret.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى إدخال اسم المستخدم وكلمة المرور/الرمز السري.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.authService.loginAndOpenSession(
        loginIdentifier: identifier,
        secret: secret,
        businessId: businessId,
        branchId: branchId,
        terminalId: terminalId,
        installationId: 'WIN-INSTALL-01',
        requirePosAccess: true,
      );

      if (!mounted) return;

      if (result.isAllowed && result.user != null && result.session != null) {
        widget.onLoginSuccess(result.user!, result.session!);
      } else {
        setState(() {
          _errorMessage = result.messageAr ?? 'تعذر تسجيل الدخول؛ يرجى التحقق من البيانات.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ غير متوقع: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF4F6F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D27) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 80 : 25),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // الشعار والعنوان
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withAlpha(30),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.point_of_sale_rounded,
                      color: Color(0xFF1E88E5),
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'MADAR SHOP — نقطة البيع',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'تسجيل دخول الموظفين والكاشير',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 24),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // حقل اسم المستخدم
                TextField(
                  controller: _identifierCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'اسم المستخدم أو البريد أو الهاتف',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 14),

                // حقل كلمة المرور / الرمز السري
                TextField(
                  controller: _secretCtrl,
                  obscureText: _obscureSecret,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitLogin(),
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور أو الرمز السري (PIN)',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureSecret ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      ),
                      onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 14),

                // إعدادات المحطة والفرع (قابلة للتعديل عند التهيئة)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _branchCtrl,
                        decoration: InputDecoration(
                          labelText: 'الفرع',
                          prefixIcon: const Icon(Icons.storefront_outlined, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _terminalCtrl,
                        decoration: InputDecoration(
                          labelText: 'المحطة',
                          prefixIcon: const Icon(Icons.computer_rounded, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // زر تسجيل الدخول
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text(
                            'تسجيل الدخول وفتح نقطة البيع',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
