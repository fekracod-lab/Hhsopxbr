import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' as intl;

// --- Palette ---
const Color primaryColor = Color(0xFF26A69A);
const Color darkBackground = Color(0xFF07191A);
const Color darkSurface = Color(0xFF0F2323);
const Color darkCard = Color(0xFF113033);
const Color darkText = Color(0xFFE0F2F1);
const Color darkSubText = Color(0xFF80CBC4);

class TransportManagementPage extends StatefulWidget {
  const TransportManagementPage({super.key});

  @override
  State<TransportManagementPage> createState() => _TransportManagementPageState();
}

class _TransportManagementPageState extends State<TransportManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: darkBackground,
        appBar: AppBar(
          backgroundColor: darkSurface,
          elevation: 0,
          title: const Text(
            'إدارة أسطول النقل',
            style: TextStyle(fontWeight: FontWeight.bold, color: darkText),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: _searchBar()),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'transport_captain')
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primaryColor));
            }

            final docs = snapshot.data?.docs ?? [];
            final filteredDocs =
                docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name =
                      (data['username'] ?? data['name'] ?? data['fullName'] ?? '')
                          .toString()
                          .toLowerCase();
                  final phone = (data['phone'] ?? '').toString();
                  return name.contains(_searchQuery.toLowerCase()) || phone.contains(_searchQuery);
                }).toList();

            if (filteredDocs.isEmpty) {
              return _emptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredDocs.length,
              itemBuilder: (context, index) {
                final doc = filteredDocs[index];
                final data = doc.data() as Map<String, dynamic>;
                return _transportCard(doc.id, data);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _searchQuery = v),
      style: const TextStyle(color: darkText),
      decoration: InputDecoration(
        hintText: 'بحث باسم الكابتن أو الهاتف...',
        hintStyle: const TextStyle(color: darkSubText, fontSize: 13),
        prefixIcon: const Icon(Icons.search, color: darkSubText),
        filled: true,
        fillColor: darkBackground,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping_outlined, size: 80, color: darkSubText.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          const Text(
            'ماكو كباتن حالياً نقل مسجلين حالياً',
            style: TextStyle(color: darkSubText),
          ),
        ],
      ),
    );
  }

  Widget _transportCard(String docId, Map<String, dynamic> data) {
    final banned = data['banned'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: banned ? Colors.redAccent.withValues(alpha: 0.3) : darkSubText.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 25,
          backgroundImage: data['photoUrl'] != null ? NetworkImage(data['photoUrl']) : null,
          backgroundColor: primaryColor.withValues(alpha: 0.1),
          child: data['photoUrl'] == null ? const Icon(Icons.person, color: primaryColor) : null,
        ),
        title: Text(
          data['username'] ?? data['name'] ?? data['fullName'] ?? 'كابتن نقل',
          style: const TextStyle(color: darkText, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['phone'] ?? '-', style: const TextStyle(color: darkSubText, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                _badge('كابتن نقل لوجستي', primaryColor),
                const SizedBox(width: 4),
                if (banned) _badge('محظور', Colors.redAccent),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: darkSubText),
          onSelected: (v) => _handleAction(docId, v, banned),
          itemBuilder:
              (ctx) => [
                const PopupMenuItem(value: 'call', child: Text('اتصال')),
                const PopupMenuItem(value: 'stats', child: Text('الإحصائيات والرحلات')),
                const PopupMenuItem(value: 'password', child: Text('تغيير كلمة المرور')),
                PopupMenuItem(value: 'ban', child: Text(banned ? 'رفع الحظر' : 'حظر')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('حذف الصلاحية', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _handleAction(String docId, String action, bool banned) async {
    if (action == 'call') {
      final snap = await FirebaseFirestore.instance.collection('users').doc(docId).get();
      final phone = snap.data()?['phone'];
      if (phone != null) launchUrl(Uri.parse("tel:$phone"));
    } else if (action == 'ban') {
      await FirebaseFirestore.instance.collection('users').doc(docId).update({'banned': !banned});
    } else if (action == 'password') {
      final snap = await FirebaseFirestore.instance.collection('users').doc(docId).get();
      final data = snap.data();
      if (data != null) {
        _showTransportPasswordDialog(docId, data);
      }
    } else if (action == 'stats') {
      final snap = await FirebaseFirestore.instance.collection('users').doc(docId).get();
      final data = snap.data();
      if (data != null) {
        _showTransportStats(docId, data['username'] ?? data['name'] ?? data['fullName'] ?? 'كابتن');
      }
    } else if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: darkSurface,
              title: const Text(
                'سحب الصلاحية',
                style: TextStyle(color: darkText),
              ),
              content: const Text(
                'هل أنت متأكد من سحب صلاحية كابتن النقل من هذا المستخدم؟',
                style: TextStyle(color: darkSubText),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('سحب الصلاحية', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
      );
      if (confirm == true) {
        await FirebaseFirestore.instance.collection('users').doc(docId).update({
          'role': 'user',
          'isTransportApproved': false,
        });
      }
    }
  }

  Future<void> _showTransportStats(String uid, String name) async {
    showDialog(
      context: context,
      builder:
          (ctx) => Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: darkSurface,
              title: Text(
                'تحليلات كابتن $name',
                style: const TextStyle(color: darkText),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchTransportTrips(uid),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: primaryColor));
                    }
                    final items = snap.data ?? [];

                    double totalRevenue = 0;
                    int completedCount = 0;

                    for (var item in items) {
                      if (item['status'] == 'delivered') {
                        totalRevenue += item['price'] ?? 0;
                        completedCount++;
                      }
                    }

                    return Column(
                      children: [
                        _statsSummary(completedCount, totalRevenue),
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'آخر رحلات النقل اللوجستي:',
                            style: TextStyle(
                              color: darkSubText,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child:
                              items.isEmpty
                                  ? const Center(
                                    child: Text(
                                      'ماكو رحلات حالياً مسجلة',
                                      style: TextStyle(color: darkSubText),
                                    ),
                                  )
                                  : ListView.builder(
                                    itemCount: items.length,
                                    itemBuilder: (context, i) {
                                      final item = items[i];
                                      return _tripHistoryItem(item);
                                    },
                                  ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'إغلاق',
                    style: TextStyle(color: primaryColor),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _statsSummary(int count, double revenue) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('نقلات مكتملة', '$count', Icons.local_shipping_outlined, Colors.green),
          _summaryItem(
            'أرباح النقل',
            '${intl.NumberFormat('#,###').format(revenue)} د.ع',
            Icons.account_balance_wallet_outlined,
            primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: darkSubText, fontSize: 10)),
        Text(value, style: TextStyle(color: darkText, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _tripHistoryItem(Map<String, dynamic> item) {
    final price = item['price'] ?? 0.0;
    final date = item['date'] as DateTime?;
    final status = item['status']?.toString() ?? 'غير محدد';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: darkCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.inventory_2_outlined, color: primaryColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'نقلة شحنة فريت',
                  style: TextStyle(
                    color: darkText,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  date != null ? intl.DateFormat('yyyy/MM/dd HH:mm').format(date) : '-',
                  style: const TextStyle(color: darkSubText, fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${intl.NumberFormat('#,###').format(price)} د.ع',
                style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                status == 'delivered' ? 'مكتملة' : status,
                style: TextStyle(
                  color: status == 'delivered' ? Colors.green : Colors.orange,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTransportTrips(String uid) async {
    final snap =
        await FirebaseFirestore.instance
            .collection('parcel_delivery_requests')
            .where('driverId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      return {
        'status': data['status'],
        'price': _parsePrice(data['price']),
        'date': (data['createdAt'] as Timestamp?)?.toDate(),
        'id': doc.id,
      };
    }).toList();
  }

  double _parsePrice(dynamic p) {
    if (p == null) return 0;
    if (p is num) return p.toDouble();
    String s = p.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(s) ?? 0;
  }

  void _showTransportPasswordDialog(String uid, Map<String, dynamic> data) {
    final passwordC = TextEditingController();
    bool isLoading = false;
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: darkCard,
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
                            'إدارة كلمة المرور',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: darkText),
                          ),
                          Text(
                            data['username'] ?? data['name'] ?? data['fullName'] ?? 'كابتن',
                            style: const TextStyle(fontSize: 12, color: darkSubText),
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
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                            Row(
                              children: [
                                const Expanded(
                                  child: SelectableText(
                                    'محمية بموجب سياسة خصوصية أبل',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: darkSubText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // حقل كلمة المرور الجديدة
                      const Text(
                        'كلمة مرور جديدة',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: darkSubText),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: passwordC,
                        obscureText: obscure,
                        style: const TextStyle(fontSize: 15, color: darkText),
                        decoration: InputDecoration(
                          hintText: 'أدخل كلمة المرور الجديدة (6 أحرف على الأقل)',
                          hintStyle: const TextStyle(fontSize: 12, color: darkSubText),
                          prefixIcon: const Icon(Icons.lock_outline, color: primaryColor, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: darkSubText, size: 20),
                            onPressed: () => setDialogState(() => obscure = !obscure),
                          ),
                          filled: true,
                          fillColor: darkBackground,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryColor)),
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
                        child: const Text('إلغاء', style: TextStyle(color: darkSubText)),
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
                          backgroundColor: Colors.deepPurple,
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
                            final callable = FirebaseFunctions.instance.httpsCallable('adminChangePassword');
                            await callable.call({'uid': uid, 'newPassword': newPass});

                            await FirebaseFirestore.instance.collection('users').doc(uid).update({
                              'passwordChangedAt': FieldValue.serverTimestamp(),
                            });

                            if (!context.mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تغيير كلمة مرور الكابتن بنجاح!', style: TextStyle()),
                                backgroundColor: primaryColor,
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
