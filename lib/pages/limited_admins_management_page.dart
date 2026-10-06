// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart' as intl;

class LimitedAdminsManagementPage extends StatefulWidget {
  const LimitedAdminsManagementPage({super.key});

  @override
  State<LimitedAdminsManagementPage> createState() => _LimitedAdminsManagementPageState();
}

class _LimitedAdminsManagementPageState extends State<LimitedAdminsManagementPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الأدمن المحدودين')),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'limited_admin')
                .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('لا يوجد أدمن محدود حالياً'));
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final d = docs[i];
              final raw = d.data();
              final data = raw is Map ? raw as Map<String, dynamic> : <String, dynamic>{};
              final name = (data['username'] ?? data['name'] ?? data['email']) ?? 'مستخدم';
              final assignedPages = (data['assignedPages'] as List<dynamic>?) ?? [];
              final assignedGov = data['assignedGovernorateName'] ?? 'لم يتم التعيين';
              final permissionsCount = (data['permissions'] as List<dynamic>?)?.length ?? 0;

              return ListTile(
                title: Text(name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الصفحات المخصصة: ${assignedPages.length}'),
                    Text(
                      'المحافظة المخصصة: $assignedGov',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                    Text(
                      'عدد الصلاحيات الإضافية: $permissionsCount',
                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit_pages') {
                      await _editAssignments(d.id);
                    } else if (v == 'edit_gov') {
                      await _editGovernorateAssignment(d.id);
                    } else if (v == 'edit_perms') {
                      await _editPermissions(d.id);
                    } else if (v == 'password') {
                      _showAdminPasswordDialog(d.id, data);
                    } else if (v == 'remove') {
                      await FirebaseFirestore.instance.collection('users').doc(d.id).set({
                        'role': 'user',
                        'assignedPages': FieldValue.delete(),
                        'assignedGovernorateId': FieldValue.delete(),
                        'assignedGovernorateName': FieldValue.delete(),
                        'permissions': FieldValue.delete(),
                      }, SetOptions(merge: true));
                    }
                    setState(() {});
                  },
                  itemBuilder:
                      (ctx) => [
                        const PopupMenuItem(value: 'edit_pages', child: Text('تعديل الصفحات')),
                        const PopupMenuItem(value: 'edit_gov', child: Text('تعيين محافظة')),
                        const PopupMenuItem(
                          value: 'edit_perms',
                          child: Text('تعديل الصلاحيات العامة'),
                        ),
                        const PopupMenuItem(value: 'password', child: Text('تغيير كلمة المرور')),
                        const PopupMenuItem(value: 'remove', child: Text('سحب صلاحيات الأدمن')),
                      ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static const Map<String, String> _availablePermissions = {
    'driver_requests': 'طلبات السائقين',
    'delivery_requests': 'طلبات الدليفري',
    'transport_requests': 'طلبات سيارات النقل',
    'ride_management': 'إدارة الرحلات',
    'restaurant_analytics': 'تحليلات المطاعم',
    'delivery_management': 'إدارة فريق الدليفري',
    'transport_management': 'إدارة أسطول النقل',
    'restaurant_requests': 'طلبات المطاعم',
    'restaurants': 'إدارة المطاعم',
    'places': 'إدارة الأماكن',
    'pages_management': 'إدارة الأقسام والصفحات',
    'taxi_settings': 'إعدادات أسعار التكسي',
    'users_management': 'إدارة المستخدمين',
    'governorates': 'إدارة المحافظات',
    'complaints_management': 'إدارة الشكاوى والاقتراحات',
  };

  Future<void> _editPermissions(String uid) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final currentPerms = (userDoc.data()?['permissions'] as List<dynamic>?)?.cast<String>() ?? [];
    final Set<String> selected = {...currentPerms};

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('تعديل صلاحيات الأدمن المحدود'),
            content: SizedBox(
              width: double.maxFinite,
              child: StatefulBuilder(
                builder:
                    (context, setStateDialog) => ListView(
                      shrinkWrap: true,
                      children:
                          _availablePermissions.entries.map((e) {
                            return CheckboxListTile(
                              title: Text(e.value),
                              value: selected.contains(e.key),
                              onChanged:
                                  (v) => setStateDialog(
                                    () => v == true ? selected.add(e.key) : selected.remove(e.key),
                                  ),
                            );
                          }).toList(),
                    ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('users').doc(uid).update({
                    'permissions': selected.toList(),
                  });
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('تم تحديث الصلاحيات')));
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
    );
  }

  Future<void> _editAssignments(String uid) async {
    final sectionsSnap = await FirebaseFirestore.instance.collection('sections').get();
    final List<Map<String, dynamic>> allPages = [];
    for (final s in sectionsSnap.docs) {
      final secData = s.data();
      final pagesSnap = await s.reference.collection('pages').get();
      for (final p in pagesSnap.docs) {
        final pData = p.data();
        allPages.add({
          'sectionId': s.id,
          'sectionLabel': secData['label'] ?? '',
          'pageId': p.id,
          'pageName': pData['name'] ?? '',
        });
      }
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final existing = userDoc.data()?['assignedPages'] as List<dynamic>?;
    final Set<String> selected = {};
    if (existing != null) {
      for (final e in existing) {
        selected.add('${e['sectionId']}::${e['pageId']}');
      }
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('تعديل صفحات الأدمن المحدود'),
            content: SizedBox(
              width: double.maxFinite,
              child: StatefulBuilder(
                builder: (context, setStateDialog) {
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: allPages.length,
                    itemBuilder: (context, i) {
                      final e = allPages[i];
                      final key = '${e['sectionId']}::${e['pageId']}';
                      return CheckboxListTile(
                        value: selected.contains(key),
                        title: Text('${e['sectionLabel']} / ${e['pageName']}'),
                        onChanged:
                            (v) => setStateDialog(
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
                onPressed: () async {
                  final List<Map<String, dynamic>> finalPages = [];
                  for (final key in selected) {
                    final parts = key.split('::');
                    final e = allPages.firstWhere(
                      (el) => el['sectionId'] == parts[0] && el['pageId'] == parts[1],
                    );
                    finalPages.add(e);
                  }
                  await FirebaseFirestore.instance.collection('users').doc(uid).update({
                    'assignedPages': finalPages,
                  });
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('تم تحديث الصفحات')));
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
    );
  }

  Future<void> _editGovernorateAssignment(String uid) async {
    final govSnap = await FirebaseFirestore.instance.collection('governorates').get();
    final govs = govSnap.docs;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    String? selectedGovId = userDoc.data()?['assignedGovernorateId'];

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('تعيين محافظة للأدمن'),
            content: SizedBox(
              width: double.maxFinite,
              child: StatefulBuilder(
                builder: (context, setStateDialog) {
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: govs.length,
                    itemBuilder: (context, i) {
                      final g = govs[i];
                      final name = g.data()['name'] ?? 'بدون اسم';
                      return RadioListTile<String>(
                        title: Text(name),
                        value: g.id,
                        groupValue: selectedGovId,
                        onChanged: (v) => setStateDialog(() => selectedGovId = v),
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  String? govName;
                  if (selectedGovId != null) {
                    govName = govs.firstWhere((g) => g.id == selectedGovId).data()['name'];
                  }
                  await FirebaseFirestore.instance.collection('users').doc(uid).update({
                    'assignedGovernorateId': selectedGovId,
                    'assignedGovernorateName': govName,
                  });
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('تم تحديث المحافظة')));
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
    );
  }

  void _showAdminPasswordDialog(String uid, Map<String, dynamic> data) {
    final passwordC = TextEditingController();
    bool isLoading = false;
    bool obscure = true;
    final primaryColor = Colors.teal;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                      child: const Icon(Icons.lock_reset_rounded, color: Colors.teal, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'إدارة كلمة المرور',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            (data['username'] ?? data['name'] ?? data['email']) ?? 'أدمن',
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
                      if (data['passwordHistory'] != null && (data['passwordHistory'] as List).isNotEmpty)
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
                                  itemCount: (data['passwordHistory'] as List).length,
                                  itemBuilder: (context, i) {
                                    final hist = (data['passwordHistory'] as List).reversed.toList()[i];
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
                                            hist['password']?.toString() ?? '',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                          Text(
                                            intl.DateFormat('yyyy/MM/dd').format(DateTime.parse(hist['changedAt'])),
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
                        controller: passwordC,
                        obscureText: obscure,
                        style: const TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'أدخل كلمة المرور الجديدة (6 أحرف على الأقل)',
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                          prefixIcon: const Icon(Icons.lock_outline, color: Colors.teal, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey, size: 20),
                            onPressed: () => setDialogState(() => obscure = !obscure),
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.teal)),
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
                          isLoading ? 'جاري التغيير...' : 'تغيير كلمة المرور',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
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
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isLoading = true);
                          try {
                            final callable = FirebaseFunctions.instance.httpsCallable('adminChangePassword');
                            await callable.call({'uid': uid, 'newPassword': newPass});

                            await FirebaseFirestore.instance.collection('users').doc(uid).update({
                              'passwordChangedAt': FieldValue.serverTimestamp(),
                            });

                            if (!context.mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تغيير كلمة المرور بنجاح!', style: TextStyle()),
                                backgroundColor: Colors.teal,
                                behavior: SnackBarBehavior.fixed,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isLoading = false);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('فشل تغيير كلمة المرور: $e', style: const TextStyle()),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.fixed,
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
        },
      ),
    );
  }
}
