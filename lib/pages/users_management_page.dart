import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notification_service.dart';
import 'package:dalal_alqaim/features/home/pages/home_page.dart';

// --- Palette ---
const Color primaryColor = Color(0xFF26A69A);
const Color surfaceColor = Color(0xFFF8F9FA);
const Color textColor = Color(0xFF333333);
const Color subTextColor = Color(0xFF757575);
const Color hintColor = Color(0xFF9E9E9E);

const Color darkBackground = Color(0xFF07191A);
const Color darkSurface = Color(0xFF0F2323);
const Color darkCard = Color(0xFF113033);
const Color darkText = Color(0xFFE0F2F1);
const Color darkSubText = Color(0xFF80CBC4);
const Color darkHint = Color(0xFF4DB6AC);

class UsersManagementPage extends StatefulWidget {
  const UsersManagementPage({super.key});

  @override
  State<UsersManagementPage> createState() => _UsersManagementPageState();
}

class _UsersManagementPageState extends State<UsersManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _roleFilter = 'all';
  String _currentUserRole = 'user';

  final List<String> _roles = [
    'all',
    'user',
    'taxi_captain',
    'transport_captain',
    'delivery',
    'merchant',
    'restaurant',
    'support',
    'complaints_admin',
    'limited_admin',
    'admin',
    'main_admin'
  ];
  final Map<String, String> _rolesLabels = {
    'all': 'الكل',
    'user': 'مستخدم عادي',
    'taxi_captain': 'كابتن تكسي (سائق)',
    'transport_captain': 'كابتن نقل (شاحنة/أثاث)',
    'delivery': 'كابتن توصيل (مندوب)',
    'merchant': 'تاجر / متجر',
    'restaurant': 'صاحب مطعم',
    'support': 'فريق الدعم',
    'complaints_admin': 'أدمن الشكاوى فقط',
    'limited_admin': 'أدمن محدود',
    'admin': 'أدمن كامل',
    'main_admin': 'مسؤول الأدمن (المدير العام)',
  };

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserRole();
  }

  Future<void> _fetchCurrentUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _currentUserRole = doc.data()?['role'] ?? 'user';
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _changeUserRole(String uid, String newRole) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final userSnap = await userRef.get();
    final userData = userSnap.data() ?? {};

    Map<String, dynamic> updateData = {
      'role': newRole,
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (newRole == 'taxi_captain' || newRole == 'driver' || newRole == 'captain') {
      updateData['isDriver'] = true;
      await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
        'uid': uid,
        'fullName': userData['fullName'] ?? userData['name'] ?? userData['username'] ?? 'كابتن تكسي',
        'phone': userData['phone'] ?? '',
        'status': 'active',
        'available': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else if (newRole == 'transport_captain') {
      updateData['isTransportDriver'] = true;
    } else if (newRole == 'delivery') {
      updateData['isDelivery'] = true;
    }

    await userRef.update(updateData);

    try {
      final actor = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('admin_actions').add({
        'action': 'assign_roles',
        'actorUid': actor?.uid,
        'actorEmail': actor?.email,
        'targetUid': uid,
        'newRole': newRole,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _toggleBan(String uid, bool currentlyBanned) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'banned': !currentlyBanned,
    });
    try {
      final actor = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('admin_actions').add({
        'action': 'ban_toggle',
        'actorUid': actor?.uid,
        'actorEmail': actor?.email,
        'targetUid': uid,
        'banned': !currentlyBanned,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _deleteUser(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
    try {
      final actor = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('admin_actions').add({
        'action': 'delete_user',
        'actorUid': actor?.uid,
        'actorEmail': actor?.email,
        'targetUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _sendNotificationToUser(String uid, String title, String body) async {
    await NotificationService.emitEvent(
      type: 'user_notification',
      payload: {
        'user_id': uid,
        'title': title,
        'body': body,
        'data': {'type': 'admin_message'},
      },
    );
  }

  void _exportEmails(List<QueryDocumentSnapshot> users) {
    final emails = users
        .map((d) => ((d.data() as Map<String, dynamic>)['email'] ?? ''))
        .where((e) => e != '')
        .join(', ');
    Clipboard.setData(ClipboardData(text: emails));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الإيميلات'), behavior: SnackBarBehavior.fixed));
  }

  void _exportPhones(List<QueryDocumentSnapshot> users) {
    final phones = users
        .map((d) => ((d.data() as Map<String, dynamic>)['phone'] ?? ''))
        .where((e) => e != '')
        .join('\n');
    Clipboard.setData(ClipboardData(text: phones));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ أرقام الهواتف'), behavior: SnackBarBehavior.fixed));
  }

  Future<void> _sendWhatsAppBroadcast() async {
    final tC = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إرسال رسالة للجميع عبر واتساب', style: TextStyle()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'سيتم فتح تطبيق واتساب. يمكنك لصق أرقام المستخدمين المنسوخة سابقاً كمجموعة أو إعادة توجيه الرسالة.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tC,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'اكتب رسالتك هنا...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle()),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send, color: Colors.white),
            label: const Text('فتح واتساب', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final text = tC.text.trim();
              if (text.isEmpty) return;
              final url = 'whatsapp://send?text=${Uri.encodeComponent(text)}';
              try {
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما قدرنا نفتح تطبيق واتساب. يرجى التأكد من تثبيتة.'), behavior: SnackBarBehavior.fixed));
              }
            },
          ),
        ],
      ),
    );
  }

  void _showChangeRoleDialog(BuildContext context, String uid, String currentRole) async {
    String selected = currentRole;
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('تغيير دور وصلاحية الحساب', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: StatefulBuilder(
                  builder:
                      (context, setState) => SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('حساب عام:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                            RadioListTile<String>(
                              value: 'user',
                              groupValue: selected,
                              title: const Text('مستخدم عادي', style: TextStyle()),
                              onChanged: (v) => setState(() => selected = v ?? selected),
                            ),
                            const Divider(),
                            const Text('أدوار أسطول الخدمات والتوصيل:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                            RadioListTile<String>(
                              value: 'taxi_captain',
                              groupValue: selected,
                              title: const Text('كابتن تكسي (سائق)', style: TextStyle()),
                              onChanged: (v) => setState(() => selected = v ?? selected),
                            ),
                            RadioListTile<String>(
                              value: 'transport_captain',
                              groupValue: selected,
                              title: const Text('كابتن نقل (شاحنة/أثاث)', style: TextStyle()),
                              onChanged: (v) => setState(() => selected = v ?? selected),
                            ),
                            RadioListTile<String>(
                              value: 'delivery',
                              groupValue: selected,
                              title: const Text('كابتن توصيل (مندوب)', style: TextStyle()),
                              onChanged: (v) => setState(() => selected = v ?? selected),
                            ),
                            const Divider(),
                            const Text('أدوار التجارة والخدمات:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                            RadioListTile<String>(
                              value: 'merchant',
                              groupValue: selected,
                              title: const Text('تاجر / متجر', style: TextStyle()),
                              onChanged: (v) => setState(() => selected = v ?? selected),
                            ),
                            RadioListTile<String>(
                              value: 'restaurant',
                              groupValue: selected,
                              title: const Text('صاحب مطعم', style: TextStyle()),
                              onChanged: (v) => setState(() => selected = v ?? selected),
                            ),
                            const Divider(),
                            const Text('أدوار الإدارة والإشراف:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                            RadioListTile<String>(
                              value: 'support',
                              groupValue: selected,
                              title: const Text('فريق الدعم', style: TextStyle()),
                              onChanged: (v) => setState(() => selected = v ?? selected),
                            ),
                            RadioListTile<String>(
                              value: 'complaints_admin',
                              groupValue: selected,
                              title: const Text('أدمن الشكاوى فقط', style: TextStyle()),
                              onChanged: (v) => setState(() => selected = v ?? selected),
                            ),
                            RadioListTile<String>(
                              value: 'limited_admin',
                              groupValue: selected,
                              title: const Text('أدمن محدود', style: TextStyle()),
                              onChanged: (v) => setState(() => selected = v ?? selected),
                            ),
                            if (_currentUserRole == 'main_admin') ...[
                              RadioListTile<String>(
                                value: 'admin',
                                groupValue: selected,
                                title: const Text('أدمن كامل', style: TextStyle()),
                                onChanged: (v) => setState(() => selected = v ?? selected),
                              ),
                              RadioListTile<String>(
                                value: 'main_admin',
                                groupValue: selected,
                                title: const Text('مسؤول الأدمن (المدير العام)', style: TextStyle()),
                                onChanged: (v) => setState(() => selected = v ?? selected),
                              ),
                            ],
                          ],
                        ),
                      ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إلغاء', style: TextStyle())),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    try {
                      final navigator = Navigator.of(ctx);
                      final messenger = ScaffoldMessenger.of(context);
                      await _changeUserRole(uid, selected);
                      if (!mounted) return;
                      navigator.pop();
                      messenger.showSnackBar(const SnackBar(content: Text('تم تحديث الدور والصلاحية بنجاح'), behavior: SnackBarBehavior.fixed));
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), behavior: SnackBarBehavior.fixed));
                    }
                  },
                  child: const Text('حفظ', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
    );
  }

  String _generateRandomPassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = math.Random();
    return String.fromCharCodes(Iterable.generate(
        8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  void _showChangePasswordDialog(BuildContext context, String uid, String email) async {
    final passwordC = TextEditingController();
    bool isLoading = false;
    bool obscure = true;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userData = userDoc.data();
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: isDark ? darkCard : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor.withValues(alpha: 0.15), primaryColor.withValues(alpha: 0.05)],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_reset_rounded, color: primaryColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'إدارة كلمة المرور',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // خيار إرسال رابط إعادة التعيين (الأكثر أماناً وموثوقية)
                      Card(
                        elevation: 0,
                        color: Colors.blue.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.blue.withValues(alpha: 0.2)),
                        ),
                        child: ListTile(
                          onTap: isLoading ? null : () async {
                            if (email.isEmpty || !email.contains('@')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('البريد الإلكتروني لهذا المستخدم غير صالح أو مفقود', style: TextStyle()), backgroundColor: Colors.orange),
                              );
                              return;
                            }
                            setDialogState(() => isLoading = true);
                            try {
                              await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('تم إرسال رابط إعادة التعيين إلى: $email\nيرجى التحقق من البريد الوارد أو المزعج (Spam).', style: const TextStyle(fontSize: 13)),
                                    backgroundColor: Colors.blue,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              }
                            } catch (e) {
                              String errorMsg = 'خطأ: $e';
                              if (e.toString().contains('user-not-found')) errorMsg = 'المستخدم غير موجود في سجلات Auth';
                              
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(errorMsg, style: const TextStyle()), backgroundColor: Colors.red),
                                );
                              }
                            } finally {
                              if (context.mounted) setDialogState(() => isLoading = false);
                            }
                          },

                          leading: const Icon(Icons.mark_email_read_outlined, color: Colors.blue),
                          title: const Text('إرسال رابط إعادة تعيين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: const Text('سيصل رابط للمستخدم على إيميله لتغيير كلمة المرور بنفسه', style: TextStyle(fontSize: 11)),
                          trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Colors.blue),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('أو تغييرها يدوياً', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // عرض كلمة المرور الحالية
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
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
                      
                      // حقل كلمة المرور الجديدة
                      const Text(
                        'كلمة مرور جديدة',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: passwordC,
                        obscureText: obscure,
                        style: const TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'أدخل كلمة المرور الجديدة (6 أحرف على الأقل)',
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                          prefixIcon: const Icon(Icons.lock_outline, color: primaryColor, size: 20),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setDialogState(() {
                                    passwordC.text = _generateRandomPassword();
                                    obscure = false;
                                  });
                                },
                                child: const Text('توليد', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              IconButton(
                                icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey, size: 20),
                                onPressed: () => setDialogState(() => obscure = !obscure),
                              ),
                            ],
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryColor)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // خيار الإرسال عبر واتساب
                      if (userData?['phone'] != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 8),
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.chat_outlined, size: 18, color: Color(0xFF25D366)),
                            label: const Text('إرسال كلمة المرور عبر واتساب', style: TextStyle(fontSize: 12, color: Color(0xFF25D366))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF25D366)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final pass = passwordC.text.trim();
                              if (pass.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى كتابة أو توليد كلمة مرور أولاً')));
                                return;
                              }
                              String phone = userData!['phone'].toString().replaceAll(RegExp(r'[^0-9]'), '');
                              if (!phone.startsWith('964')) phone = '964$phone';
                              
                              final msg = 'مرحباً،\nلقد تم تعيين كلمة مرور جديدة لحسابك في تطبيق مدار:\n\nكلمة المرور: $pass\n\nيرجى استخدامها لتسجيل الدخول وتغييرها لاحقاً من الملف الشخصي.';
                              final url = 'whatsapp://send?phone=+$phone&text=${Uri.encodeComponent(msg)}';
                              
                              try {
                                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                              } catch (e) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما قدرنا نفتح واتساب')));
                              }
                            },
                          ),
                        ),

                      const SizedBox(height: 8),
                      const Text(
                        'ملاحظة: التغيير اليدوي قد لا يعمل إذا لم يتم تفعيل Cloud Functions. يفضل استخدام رابط إعادة التعيين.',
                        style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
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
                        onPressed: isLoading ? null : () => Navigator.pop(ctx),
                        child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: isLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_rounded, size: 20, color: Colors.white),
                        label: Text(
                          isLoading ? 'جاري التغيير...' : 'حفظ كلمة المرور',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: isLoading ? null : () async {
                          final newPass = passwordC.text.trim();
                          if (newPass.isEmpty || newPass.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل', style: TextStyle()),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.fixed,
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isLoading = true);
                          try {
                            // 1. محاولة تغيير كلمة المرور في نظام جوجل (Cloud Function)
                            try {
                              // استخدام المرجع التلقائي للدالة
                              final callable = FirebaseFunctions.instance.httpsCallable('adminChangePassword');
                              
                              final result = await callable.call({
                                'uid': uid, 
                                'newPassword': newPass
                              });
                              
                              debugPrint('Cloud Function Success: ${result.data}');
                            } catch (e) {
                              debugPrint('Cloud Function Final Error: $e');
                              throw 'فشل الاتصال بالدالة. \nالخطأ: $e';
                            }
                            
                            await FirebaseFirestore.instance.collection('users').doc(uid).update({
                              'passwordChangedAt': FieldValue.serverTimestamp(),
                            });
                            
                            // تحديث أيضاً في مجموعة drivers إن وجد
                            try {
                              final driverDoc = await FirebaseFirestore.instance.collection('drivers').doc(uid).get();
                              if (driverDoc.exists) {
                                await FirebaseFirestore.instance.collection('drivers').doc(uid).update({
                                  'passwordChangedAt': FieldValue.serverTimestamp(),
                                });
                              }
                            } catch (_) {}
                            
                            if (!context.mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تحديث كلمة المرور في جوجل وقاعدة البيانات بنجاح!', style: TextStyle()),
                                backgroundColor: primaryColor,
                                behavior: SnackBarBehavior.fixed,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isLoading = false);
                            if (!context.mounted) return;
                            
                            // إظهار الخطأ الحقيقي للأدمن
                            showDialog(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('خطأ في التزامن', style: TextStyle(color: Colors.red)),
                                content: Text(e.toString(), style: const TextStyle()),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c), child: const Text('حسناً'))
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
      ),
    );
  }


  void _showUserDetails(BuildContext context, String uid, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(data['username'] ?? data['name'] ?? data['email'] ?? 'مستخدم', style: TextStyle()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.email_outlined, 'البريد', data['email'] ?? '-'),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.admin_panel_settings_outlined, 'الصلاحية', _rolesLabels[data['role'] ?? 'user'] ?? (data['role'] ?? 'user')),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.security_outlined, 'محظور', data['banned'] == true ? 'نعم' : 'لا'),
                if (data['phone'] != null && data['phone'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.phone_outlined, 'الهاتف', data['phone'].toString()),
                ],
                const SizedBox(height: 12),
                _buildInfoRow(Icons.lock_outlined, 'كلمة المرور', '********'),
              ],
            ),
            actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إغلاق', style: TextStyle()))
            ],
          ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 20),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(value, style: const TextStyle())),
      ],
    );
  }

  void _showNotificationDialog(BuildContext context, String uid) {
    final tC = TextEditingController();
    final bC = TextEditingController();
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('إرسال إشعار للمستخدم', style: TextStyle()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tC,
                  decoration: InputDecoration(
                    labelText: 'عنوان الإشعار',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bC,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'نص الإشعار',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  await _sendNotificationToUser(uid, tC.text.trim(), bC.text.trim());
                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إرسال الإشعار بنجاح'), behavior: SnackBarBehavior.fixed),
                  );
                },
                child: const Text('إرسال', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  void _showAssignSectionDialog(BuildContext context, String uid) async {
    final sectionsSnap = await FirebaseFirestore.instance.collection('sections').get();
    final sections = sectionsSnap.docs;

    final List<Map<String, dynamic>> allPages = [];
    for (final s in sections) {
      final secData = s.data();
      final pagesSnap = await FirebaseFirestore.instance
          .collection('sections')
          .doc(s.id)
          .collection('pages')
          .get();
      for (final p in pagesSnap.docs) {
        final pData = p.data();
        allPages.add({
          'sectionId': s.id,
          'sectionLabel': secData['label'] ?? '',
          'sectionColor': secData['color'],
          'sectionIcon': secData['icon']?.toString(),
          'pageId': p.id,
          'pageName': pData['name'] ?? '',
        });
      }
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final existing = userDoc.exists ? (userDoc.data()?['assignedPages'] as List<dynamic>?) : null;
    final Set<String> preSelected = {};
    if (existing != null) {
      for (final e in existing) {
        try {
          final map = Map<String, dynamic>.from(e);
          preSelected.add('${map['sectionId']}::${map['pageId']}');
        } catch (_) {}
      }
    }

    final selected = <String>{...preSelected};

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('تعيين صفحات للأدمن', style: TextStyle()),
            content: SizedBox(
              width: double.maxFinite,
              child: StatefulBuilder(
                builder: (context, setState) {
                  if (allPages.isEmpty) return const Text('لا توجد صفحات متاحة', style: TextStyle());
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: allPages.length,
                    itemBuilder: (context, i) {
                      final entry = allPages[i];
                      final key = '${entry['sectionId']}::${entry['pageId']}';
                      final label = '${entry['sectionLabel']} / ${entry['pageName']}';
                      final chosen = selected.contains(key);
                      return CheckboxListTile(
                        value: chosen,
                        title: Text(label, style: const TextStyle(fontSize: 13)),
                        activeColor: primaryColor,
                        onChanged: (v) => setState(
                              () => v == true ? selected.add(key) : selected.remove(key),
                            ),
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  final assignedPages = <Map<String, dynamic>>[];
                  for (final key in selected) {
                    final parts = key.split('::');
                    if (parts.length != 2) continue;
                    final secId = parts[0];
                    final pageId = parts[1];
                    final e = allPages.firstWhere(
                      (el) => el['sectionId'] == secId && el['pageId'] == pageId,
                      orElse: () => {},
                    );
                    if (e.isNotEmpty) {
                      assignedPages.add({
                        'sectionId': e['sectionId'],
                        'sectionLabel': e['sectionLabel'],
                        'pageId': e['pageId'],
                        'pageName': e['pageName'],
                        'sectionColor': e['sectionColor'],
                        'sectionIcon': e['sectionIcon'],
                      });
                    }
                  }

                  await FirebaseFirestore.instance.collection('users').doc(uid).set({
                    'role': 'limited_admin',
                    'assignedPages': assignedPages,
                  }, SetOptions(merge: true));

                  try {
                    final actor = FirebaseAuth.instance.currentUser;
                    await FirebaseFirestore.instance.collection('admin_actions').add({
                      'action': 'assign_pages',
                      'actorUid': actor?.uid,
                      'actorEmail': actor?.email,
                      'targetUid': uid,
                      'assignedCount': assignedPages.length,
                      'assignedPages': assignedPages,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  } catch (_) {}
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الصفحات بنجاح'), behavior: SnackBarBehavior.fixed));
                  setState(() {});
                },
                child: const Text('حفظ', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  void _confirmDelete(BuildContext context, String uid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('تأكيد الحذف', style: TextStyle()),
            content: const Text('متأكد تريد تحذف هذا المستخدم؟ لا يمكن التراجع.', style: TextStyle()),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('حذف', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
    if (ok == true) {
      await _deleteUser(uid);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المستخدم بنجاح')));
    }
  }

  void _showUserActionsSheet(BuildContext context, String uid, Map<String, dynamic> data) {
    final role = data['role'] ?? 'user';
    final banned = data['banned'] == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.only(top: 20, bottom: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                child: Text(
                  (data['username'] ?? data['name'] ?? data['email'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                ),
              ),
              title: Text(
                data['username'] ?? data['name'] ?? data['email'] ?? 'مستخدم',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(data['email'] ?? '', style: const TextStyle()),
            ),
            const Divider(),
            _buildActionTile(
              icon: Icons.info_outline,
              title: 'عرض التفاصيل',
              onTap: () {
                Navigator.pop(ctx);
                _showUserDetails(context, uid, data);
              },
              isDark: isDark,
            ),
            _buildActionTile(
              icon: Icons.admin_panel_settings_outlined,
              title: 'تعديل الصلاحية',
              onTap: () {
                Navigator.pop(ctx);
                if ((role == 'admin' || role == 'main_admin') && _currentUserRole != 'main_admin') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('عذراً، فقط المدير العام (مسؤول الأدمن) يمكنه تعديل صلاحيات المسؤولين.', style: TextStyle()),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.fixed,
                    ),
                  );
                  return;
                }
                _showChangeRoleDialog(context, uid, role);
              },
              isDark: isDark,
            ),
            _buildActionTile(
              icon: Icons.key_outlined,
              title: 'إعادة تعيين كلمة المرور',
              onTap: () {
                Navigator.pop(ctx);
                if ((role == 'admin' || role == 'main_admin') && _currentUserRole != 'main_admin') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('عذراً، فقط المدير العام (مسؤول الأدمن) يمكنه إعادة تعيين كلمة مرور المسؤولين.', style: TextStyle()),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.fixed,
                    ),
                  );
                  return;
                }
                _showChangePasswordDialog(context, uid, data['email'] ?? '');
              },
              isDark: isDark,
            ),
            _buildActionTile(
              icon: Icons.view_comfy_alt_outlined,
              title: 'تعيين قسم (أدمن محدود)',
              onTap: () {
                Navigator.pop(ctx);
                _showAssignSectionDialog(context, uid);
              },
              isDark: isDark,
            ),
            _buildActionTile(
              icon: Icons.notifications_active_outlined,
              title: 'إرسال إشعار',
              onTap: () {
                Navigator.pop(ctx);
                _showNotificationDialog(context, uid);
              },
              isDark: isDark,
            ),
            if (data['phone'] != null && data['phone'].toString().isNotEmpty)
              _buildActionTile(
                icon: Icons.chat_outlined,
                title: 'مراسلة واتساب',
                color: const Color(0xFF25D366),
                onTap: () async {
                  Navigator.pop(ctx);
                  String phone = data['phone'].toString().replaceAll(RegExp(r'[^0-9]'), '');
                  if (!phone.startsWith('964')) phone = '964$phone';
                  final url = 'whatsapp://send?phone=+$phone';
                  try {
                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  } catch (e) {
                    if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما قدرنا نفتح واتساب. يرجى التأكد من تثبيته.')));
                    }
                  }
                },
                isDark: isDark,
              ),
            _buildActionTile(
              icon: banned ? Icons.lock_open : Icons.lock_outline,
              title: banned ? 'إلغاء الحظر' : 'حظر المستخدم',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(ctx);
                if ((role == 'admin' || role == 'main_admin') && _currentUserRole != 'main_admin') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('عذراً، فقط المدير العام (مسؤول الأدمن) يمكنه حظر حسابات المسؤولين.', style: TextStyle()),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.fixed,
                    ),
                  );
                  return;
                }
                _toggleBan(uid, banned);
              },
              isDark: isDark,
            ),
            _buildActionTile(
              icon: Icons.delete_outline,
              title: 'حذف المستخدم',
              color: Colors.red,
              onTap: () {
                Navigator.pop(ctx);
                if ((role == 'admin' || role == 'main_admin') && _currentUserRole != 'main_admin') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('عذراً، فقط المدير العام (مسؤول الأدمن) يمكنه حذف حسابات المسؤولين.', style: TextStyle()),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.fixed,
                    ),
                  );
                  return;
                }
                _confirmDelete(context, uid);
              },
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isDark,
    Color? color,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? primaryColor).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color ?? (isDark ? darkText : textColor), size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? (isDark ? darkText : textColor),
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentBg = isDark ? darkBackground : surfaceColor;
    final currentCardBg = isDark ? darkCard : Colors.white;
    final currentText = isDark ? darkText : textColor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomePage()), (route) => false);
      },
      child: Scaffold(
        backgroundColor: currentBg,
        appBar: AppBar(
          backgroundColor: isDark ? darkSurface : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomePage()), (route) => false),
          ),
          title: Text('إدارة المستخدمين', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          centerTitle: true,
          actions: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                return PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (val) {
                    if (val == 'whatsapp') {
                      _sendWhatsAppBroadcast();
                    } else if (val == 'phones' && snapshot.hasData) {
                      _exportPhones(snapshot.data!.docs);
                    } else if (val == 'emails' && snapshot.hasData) {
                      _exportEmails(snapshot.data!.docs);
                    } else if (val == 'refresh') {
                      setState(() {});
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'whatsapp',
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline, color: const Color(0xFF25D366), size: 20),
                          const SizedBox(width: 8),
                          const Text('رسالة واتساب للجميع', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'phones',
                      child: Row(
                        children: [
                          Icon(Icons.phone_android_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('نسخ جميع الأرقام', style: TextStyle()),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'emails',
                      child: Row(
                        children: [
                          Icon(Icons.email_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('نسخ جميع الإيميلات', style: TextStyle()),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 20),
                          SizedBox(width: 8),
                          Text('تحديث القائمة', style: TextStyle()),
                        ],
                      ),
                    ),
                  ],
                );
              }
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Search & Filter (OUTSIDE StreamBuilder to prevent reload) ──
            Container(
              color: isDark ? darkSurface : Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? darkBackground : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: currentText),
                      decoration: InputDecoration(
                        hintText: 'ابحث باسم أو بريد...',
                        hintStyle: TextStyle(color: isDark ? darkHint : hintColor),
                        prefixIcon: Icon(Icons.search, color: isDark ? darkHint : Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _roles.map((role) {
                        final isSelected = _roleFilter == role;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text(_rolesLabels[role]!, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            selected: isSelected,
                            onSelected: (v) => setState(() => _roleFilter = role),
                            selectedColor: primaryColor.withValues(alpha: 0.2),
                            backgroundColor: isDark ? darkBackground : Colors.grey[100],
                            labelStyle: TextStyle(color: isSelected ? primaryColor : (isDark ? darkSubText : subTextColor)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? primaryColor.withValues(alpha: 0.5) : Colors.transparent)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            // ── Users List (INSIDE StreamBuilder) ──
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: primaryColor));
                  }

                  final allDocs = snapshot.data?.docs ?? [];
                  final docs = allDocs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final q = _searchController.text.trim().toLowerCase();
                    if (q.isNotEmpty) {
                      final name = ((data['username'] ?? data['name']) ?? '').toString().toLowerCase();
                      final email = (data['email'] ?? '').toString().toLowerCase();
                      if (!name.contains(q) && !email.contains(q)) return false;
                    }
                    if (_roleFilter != 'all') {
                      if ((data['role'] ?? 'user') != _roleFilter) return false;
                    }
                    return true;
                  }).toList();

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_off_outlined, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('ماكو نتائج حالياً', style: TextStyle(fontSize: 18, color: Colors.grey[500])),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      final data = d.data() as Map<String, dynamic>;
                      final uid = d.id;
                      final email = data['email'] ?? '';
                      final name = (data['username'] ?? data['name']) ?? '';
                      final role = data['role'] ?? 'user';
                      final banned = data['banned'] == true;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: currentCardBg,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showUserActionsSheet(context, uid, data),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                                  child: Text(
                                    (name.isNotEmpty ? name[0] : email.isNotEmpty ? email[0] : '?').toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name.isNotEmpty ? name : email,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: currentText),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        email,
                                        style: TextStyle(fontSize: 13, color: isDark ? darkSubText : subTextColor),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: role == 'admin' ? Colors.red.withValues(alpha: 0.1) : role == 'limited_admin' ? Colors.blue.withValues(alpha: 0.1) : role == 'complaints_admin' ? Colors.purple.withValues(alpha: 0.1) : role == 'support' ? Colors.teal.withValues(alpha: 0.1) : primaryColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _rolesLabels[role] ?? role,
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: role == 'admin' ? Colors.red : role == 'limited_admin' ? Colors.blue : role == 'complaints_admin' ? Colors.purple : role == 'support' ? Colors.teal : primaryColor),
                                            ),
                                          ),
                                          if (banned) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'محظور',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange),
                                              ),
                                            ),
                                          ],
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                                // زر وصول سريع لإدارة كلمة المرور
                                IconButton(
                                  icon: const Icon(Icons.key_rounded, color: Colors.amber, size: 22),
                                  tooltip: 'إدارة كلمة المرور',
                                  onPressed: () => _showChangePasswordDialog(context, uid, email),
                                ),
                                Icon(Icons.more_vert, color: Colors.grey[400]),

                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
