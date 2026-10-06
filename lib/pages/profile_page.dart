import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'my_orders_page.dart';
import 'package:dalal_alqaim/services/onesignal_service.dart';
import 'package:dalal_alqaim/services/user_service.dart';
import 'package:dalal_alqaim/core/app_globals.dart';

class ProfilePage extends StatelessWidget {
  final void Function(bool)? onThemeChanged;
  final bool isDarkMode;
  const ProfilePage({super.key, this.onThemeChanged, required this.isDarkMode});

  // static BannerAd? _bannerAd;
  // static bool _isBannerAdReady = false;
  static bool _adInitialized = false;

  void _initAd() {
    if (_adInitialized) return;
    // _bannerAd = BannerAd(
    // adUnitId: 'ca-app-pub-8219352249730033/1531452323',
    // size: AdSize.banner,
    // request: AdRequest(),
    // listener: BannerAdListener(
    // onAdLoaded: (_) => _isBannerAdReady = true,
    // onAdFailedToLoad: (ad, error) {
    // ad.dispose();
    // _isBannerAdReady = false;
    // },
    // ),
    // )..load();
    _adInitialized = true;
  }

  Future<String?> _fetchAnnouncement() async {
    final doc = await FirebaseFirestore.instance.collection('app_data').doc('announcement').get();
    return doc.data()?['text'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    _initAd();
    final isDark = isDarkMode;
    final user = FirebaseAuth.instance.currentUser;
    final username = user?.displayName ?? 'اسم المستخدم';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // إعلان أو تنبيه أعلى الصفحة
            FutureBuilder<String?>(
              future: _fetchAnnouncement(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null && snapshot.data!.trim().isNotEmpty) {
                  return Card(
                    color: Colors.amber[100],
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.campaign, color: Colors.orange),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              snapshot.data!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            // محتوى الصفحة
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // صورة رمزية مع تدرج وظل
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0ED2F7), Color(0xFF009688)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withValues(alpha: 0.13),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            (username.isNotEmpty) ? username[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 48,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        username,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF009688),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF607D8B),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // قسم الإعدادات مع الأزرار
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(
                                  Icons.star_rate_rounded,
                                  color: Color(0xFFFFA726),
                                ),
                                title: const Text(
                                  'قيّم تطبيقنا وانطينا رأيك',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onTap: () => _showRatingDialog(context),
                              ),
                              const Divider(),
                              ListTile(
                                leading: const Icon(Icons.share_rounded, color: Color(0xFF2196F3)),
                                title: const Text(
                                  'شارك التطبيق ويا حبايبك',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onTap: () async {
                                  await Share.share(
                                    'حمّل تطبيق مدار - دليلك وخدماتك الذكية في القائم والعراق 🇮🇶\nhttps://madar-iq.web.app',
                                  );
                                },
                              ),
                              const Divider(),
                              ListTile(
                                leading: const Icon(
                                  Icons.shopping_bag_rounded,
                                  color: Color(0xFF26A69A),
                                ),
                                title: const Text(
                                  'مشاويري وطلباتي السابقة',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const MyOrdersPage()),
                                  );
                                },
                              ),
                              const Divider(),
                              ListTile(
                                leading: const Icon(
                                  Icons.lock_reset_rounded,
                                  color: Color(0xFF009688),
                                ),
                                title: const Text(
                                  'تغيير الرمز السري',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onTap: _showChangePasswordDialog,
                              ),
                              const Divider(),
                              ListTile(
                                leading: const Icon(Icons.logout, color: Color(0xFF009688)),
                                title: const Text(
                                  'تسجيل الخروج',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onTap: _signOut,
                              ),
                              const Divider(),
                              ListTile(
                                leading: const Icon(Icons.delete_forever, color: Colors.red),
                                title: const Text(
                                  'حذف الحساب نهائياً',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onTap: _showDeleteAccountDialog,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'تطبيق مدار - دليل القائم المتكامل 🇮🇶',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // زر الوضع الليلي في الأعلى يمين الصفحة
            if (onThemeChanged != null)
              Positioned(
                top: 18,
                right: 18,
                child: IconButton(
                  icon: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    color: isDark ? Colors.amber : Colors.blueGrey,
                    size: 30,
                  ),
                  tooltip: isDark ? 'الوضع الليلي' : 'الوضع الفاتح',
                  onPressed: () => onThemeChanged!(!isDark),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // إضافة تعريفات الدوال الناقصة
  void _showChangePasswordDialog() {
    final context = appNavigatorKey.currentContext!;
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text(
              'تغيير كلمة المرور',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPasswordField(
                      controller: currentPasswordController,
                      label: 'كلمة المرور الحالية',
                      validator: (v) => (v == null || v.isEmpty) ? 'يرجى إدخال كلمة المرور الحالية' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: newPasswordController,
                      label: 'كلمة المرور الجديدة',
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'يرجى إدخال كلمة المرور الجديدة';
                        if (v.length < 6) return 'لازم تكون 6 أحرف أو أكثر';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: confirmPasswordController,
                      label: 'تأكيد كلمة المرور الجديدة',
                      validator: (v) {
                        if (v != newPasswordController.text) return 'كلمات المرور مو متطابقة';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setState(() => isLoading = true);
                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null && user.email != null) {
                              // 1. Re-authenticate
                              AuthCredential credential = EmailAuthProvider.credential(
                                email: user.email!,
                                password: currentPasswordController.text.trim(),
                              );
                              await user.reauthenticateWithCredential(credential);

                              // 2. Update Password in Auth
                              await user.updatePassword(newPasswordController.text.trim());

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('عاشت إيدك، تم تغيير الرمز السري بنجاح'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          } on FirebaseAuthException catch (e) {
                            String message = 'صار خلل أثناء تغيير كلمة المرور';
                            if (e.code == 'wrong-password') message = 'كلمة المرور الحالية مو صحيحة';
                            
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(message),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('صار خلل غير متوقع، حاول بعدين'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) setState(() => isLoading = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF009688)),
                child: isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('حفظ التغيير', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.lock_outline),
      ),
      validator: validator,
    );
  }


  Future<void> _signOut() async {
    await UserService.signOut();
  }

  void _showDeleteAccountDialog([BuildContext? context]) {
    final navContext = context ?? appNavigatorKey.currentContext;
    if (navContext == null) return;
    showDialog(
      context: navContext,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                SizedBox(width: 8),
                Text('حذف الحساب نهائياً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: const Text(
              'متأكد تريد تحذف حسابك وكل بياناتك نهائياً؟ ما راح تكدر ترجعه بعد الحذف عيوني.',
              style: TextStyle(fontSize: 13),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final uid = user.uid;
                    try {
                      await FirebaseFirestore.instance.collection('users').doc(uid).delete().catchError((_) {});
                      await FirebaseFirestore.instance.collection('drivers').doc(uid).delete().catchError((_) {});
                      await FirebaseFirestore.instance.collection('restaurants').doc(uid).delete().catchError((_) {});
                      await FirebaseFirestore.instance.collection('delivery_boys').doc(uid).delete().catchError((_) {});
                      await OneSignalService.logout();
                      await user.delete();
                    } on FirebaseAuthException catch (e) {
                      if (e.code == 'requires-recent-login') {
                        if (navContext.mounted) {
                          ScaffoldMessenger.of(navContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'لأسباب أمنية، يرجى تسجيل الخروج والدخول من جديد وبعدين احذف الحساب.',
                              ),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                        return;
                      }
                      await _signOut();
                    } catch (_) {
                      await _signOut();
                    }
                  }
                },
                child: const Text('احذف الحساب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
    );
  }

  void _showRatingDialog(BuildContext context) {
    int selectedRating = 5;
    final feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.star_rounded, color: Color(0xFFFFA726), size: 28),
              SizedBox(width: 8),
              Text(
                'تقييم تطبيق مدار',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'رأيك يهمنا ويساعدنا نطور خدماتنا في القائم والعراق 🇮🇶',
                  style: TextStyle(fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final star = index + 1;
                    return IconButton(
                      icon: Icon(
                        star <= selectedRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: const Color(0xFFFFA726),
                        size: 32,
                      ),
                      onPressed: () {
                        setModalState(() {
                          selectedRating = star;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: feedbackController,
                  maxLines: 3,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'اكتب ملاحظتك أو رأيك هنا (اختياري)...',
                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha: 0.05),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009688),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                final text = feedbackController.text.trim();
                try {
                  await FirebaseFirestore.instance.collection('app_ratings').add({
                    'userId': user?.uid ?? 'anonymous',
                    'userName': user?.displayName ?? 'مستخدم مدار',
                    'rating': selectedRating,
                    'feedback': text,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                } catch (_) {}
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('شكراً جزيلاً لتقييمك ودعمك لتطبيق مدار 🌟'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text(
                'إرسال التقييم',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
