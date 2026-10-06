import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/store_profile.dart';
import '../../data/services/store_auth_service.dart';

/// شاشة اختيار المتجر لتشغيل نقطة البيع (Store Selector & Activation Page)
class StoreSelectorPage extends StatefulWidget {
  final Function(StoreProfile store) onStoreSelected;

  const StoreSelectorPage({super.key, required this.onStoreSelected});

  @override
  State<StoreSelectorPage> createState() => _StoreSelectorPageState();
}

class _StoreSelectorPageState extends State<StoreSelectorPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  List<StoreProfile> _stores = [];
  bool _isLoading = true;
  bool _isLoggingIn = false;
  bool _showLoginForm = false;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() => _isLoading = true);
    final list = await StoreAuthService.instance.fetchStores();
    if (mounted) {
      setState(() {
        _stores = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleEmailLogin() async {
    final email = _emailCtrl.text.trim();
    final pwd = _passwordCtrl.text.trim();
    if (email.isEmpty || pwd.isEmpty) return;

    setState(() => _isLoggingIn = true);
    try {
      final store = await StoreAuthService.instance.loginWithEmail(email: email, password: pwd);
      if (store != null && mounted) {
        widget.onStoreSelected(store);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على متجر مرتبط بهذا الحساب'), backgroundColor: ShopColors.warning),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تسجيل الدخول: $e'), backgroundColor: ShopColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = _searchCtrl.text.trim().toLowerCase();
    final filteredStores = _stores.where((s) {
      return s.name.toLowerCase().contains(query) ||
          s.category.toLowerCase().contains(query) ||
          s.phone.contains(query);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Container(
            width: 760,
            height: 640,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? ShopColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: isDark ? ShopColors.darkBorder : ShopColors.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header Logo & Title ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [ShopColors.primary, ShopColors.primaryDark]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'نظام كاشير المتاجر — منظومة مدار',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 20),
                          ),
                          Text(
                            'حدد المتجر المراد تفعيل الكاشير والمزامنة الفورية لمنتجاته معه',
                            style: GoogleFonts.cairo(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _showLoginForm = !_showLoginForm),
                      icon: Icon(_showLoginForm ? Icons.grid_view_rounded : Icons.login_rounded, size: 18),
                      label: Text(
                        _showLoginForm ? 'قائمة المتاجر' : 'دخول بحساب المتجر',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),

                if (_showLoginForm) ...[
                  // ── Form Login ──
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 420,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? ShopColors.darkCard : ShopColors.lightBg,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'تسجيل الدخول بحساب المتجر في مدار',
                              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _emailCtrl,
                              decoration: InputDecoration(
                                labelText: 'البريد الإلكتروني للتاجر',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passwordCtrl,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'كلمة المرور',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              onPressed: _isLoggingIn ? null : _handleEmailLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ShopColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: _isLoggingIn
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.login_rounded, color: Colors.white),
                              label: Text('دخول وتشغيل الكاشير', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // ── Search Bar ──
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'ابحث عن اسم المتجر أو القسم أو الهاتف...',
                      prefixIcon: const Icon(Icons.search_rounded, color: ShopColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // ── Stores Grid ──
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: ShopColors.primary))
                        : filteredStores.isEmpty
                            ? Center(
                                child: Text('لم يتم العثور على أي متجر مسجل', style: GoogleFonts.cairo(color: Colors.grey)),
                              )
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: 2.5,
                                ),
                                itemCount: filteredStores.length,
                                itemBuilder: (ctx, i) {
                                  final store = filteredStores[i];
                                  return _buildStoreCard(context, store, isDark);
                                },
                              ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreCard(BuildContext context, StoreProfile store, bool isDark) {
    return InkWell(
      onTap: () {
        StoreAuthService.instance.setActiveStore(store);
        widget.onStoreSelected(store);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? ShopColors.darkCard : ShopColors.lightBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? ShopColors.darkBorder : ShopColors.lightBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isDark ? ShopColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: store.logoUrl.isNotEmpty
                    ? Image.network(store.logoUrl, fit: BoxFit.cover, errorBuilder: (_, err, stack) => const Icon(Icons.storefront_rounded, color: ShopColors.primary))
                    : const Icon(Icons.storefront_rounded, color: ShopColors.primary),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    store.name,
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'القسم: ${store.category} • ${store.phone}',
                    style: GoogleFonts.cairo(color: Colors.grey, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: ShopColors.primary),
          ],
        ),
      ),
    );
  }
}
