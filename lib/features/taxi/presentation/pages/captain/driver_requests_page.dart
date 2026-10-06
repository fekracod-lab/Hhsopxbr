import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' as intl;
import 'package:dalal_alqaim/services/notification_service.dart';
import 'package:dalal_alqaim/core/taxi/data/repositories/taxi_kyc_repository.dart';

const Color _primary = Color(0xFF26A69A);
const Color _surfaceColor = Color(0xFFF8F9FA);
const Color _darkSurface = Color(0xFF0F2323);
const Color _darkBg = Color(0xFF0A1A1A);
const Color _darkText = Colors.white;
const Color _lightCard = Colors.white;
const Color _lightText = Color(0xFF2C3E50);
const Color _lightSub = Color(0xFF7F8C8D);



class DriverRequestsPage extends StatefulWidget {
  const DriverRequestsPage({super.key});

  @override
  State<DriverRequestsPage> createState() => _DriverRequestsPageState();
}

class _DriverRequestsPageState extends State<DriverRequestsPage> {
  final TaxiKycRepository _taxiKycRepository = TaxiKycRepository();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? _darkBg : _surfaceColor,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: isDark ? _darkSurface : Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? _darkText : Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: Text(
                  'طلبات كباتن التاكسي',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDark ? _darkText : Colors.black87,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [_darkSurface, _darkBg]
                          : [Colors.white, _surfaceColor],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Center(
                    child: Opacity(
                      opacity: 0.05,
                      child: Icon(
                        Icons.local_taxi_rounded,
                        size: 80,
                        color: _primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                stream: _taxiKycRepository.streamPendingTaxiKycRequests(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const SliverToBoxAdapter(
                      child: Center(child: Text('حدث خطأ في جلب البيانات', style: TextStyle(color: Colors.red))),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: _primary)),
                    );
                  }

                  final docs = snapshot.data ?? [];

                  if (docs.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.done_all_rounded, size: 80, color: Colors.grey.withValues(alpha: 0.2)),
                            const SizedBox(height: 16),
                            const Text(
                              'ماكو طلبات حالياً معلقة',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const Text(
                              'تمت معالجة جميع طلبات انضمام كباتن التاكسي بنجاح',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        return _buildModernRequestCard(doc.id, data, isDark);
                      },
                      childCount: docs.length,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernRequestCard(String docId, Map<String, dynamic> data, bool isDark) {
    final cardColor = isDark ? _lightCard : Colors.white;
    final textColor = isDark ? _lightText : Colors.black87;
    final subTextColor = isDark ? _lightSub : Colors.grey[600];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _primary.withValues(alpha: 0.1),
                  backgroundImage: data['photoUrl'] != null && (data['photoUrl'] as String).isNotEmpty
                      ? NetworkImage(data['photoUrl'])
                      : null,
                  child: data['photoUrl'] == null || (data['photoUrl'] as String).isEmpty
                      ? const Icon(Icons.person, color: _primary, size: 30)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['fullName'] ?? data['name'] ?? 'بدون اسم',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                      ),
                      Text(
                        data['phone'] ?? '-',
                        style: TextStyle(fontSize: 13, color: subTextColor),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _iconAction(Icons.call, Colors.blue, () => _callPhone(data['phone'])),
                    const SizedBox(width: 8),
                    _iconAction(Icons.chat_bubble_outline, const Color(0xFF25D366), () => _whatsappPhone(data['phone'])),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _infoGridItem(Icons.directions_car, 'ماركة المركبة', '${data['carType'] ?? '-'}', isDark),
                const SizedBox(height: 8),
                _infoGridItem(Icons.model_training, 'موديل المركبة', '${data['carModel'] ?? '-'} (${data['carYear'] ?? '-'})', isDark),
                const SizedBox(height: 8),
                _infoGridItem(
                  Icons.confirmation_number_outlined,
                  'لوحة السيارة',
                  (data['fullCarPlate'] != null && (data['fullCarPlate'] as String).isNotEmpty)
                      ? '${data['fullCarPlate']}'
                      : (data['plateGovernorate'] != null
                          ? '${data['plateGovernorate']} ${data['carNumber'] ?? '-'}'
                          : '${data['carNumber'] ?? '-'}'),
                  isDark,
                ),
                const SizedBox(height: 8),
                if (data['serviceType'] != null && (data['serviceType'] as String).isNotEmpty) ...[
                  _infoGridItem(Icons.local_taxi_rounded, 'فئة الخدمة', '${data['serviceType']}', isDark),
                  const SizedBox(height: 8),
                ],
                _infoGridItem(
                  Icons.location_on_outlined,
                  'الموقع والمنطقة',
                  [
                    data['governorateName'] ?? data['governorate'] ?? '',
                    data['regionName'] ?? '',
                    data['subRegionName'] ?? '',
                  ].where((s) => s.toString().trim().isNotEmpty).join(' - '),
                  isDark,
                ),
                const SizedBox(height: 8),
                _infoGridItem(Icons.calendar_today_outlined, 'التاريخ', 
                  data['createdAt'] != null ? intl.DateFormat('yyyy-MM-dd HH:mm').format((data['createdAt'] as Timestamp).toDate()) : '-', 
                  isDark),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectRequest(docId, data['uid']),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.redAccent, width: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('رفض الطلب', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showApprovalSteps(docId, data),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('خطوات القبول', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconAction(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _infoGridItem(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _primary),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 12, color: isDark ? _lightSub : Colors.grey[600])),
        Expanded(
          child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? _lightText : Colors.black87)),
        ),
      ],
    );
  }

  void _showApprovalSteps(String docId, Map<String, dynamic> data) async {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('مراجعة بيانات السائق', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('يرجى التأكد من صحة البيانات التالية قبل التفعيل:', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              _reviewItem('الاسم الكامل', data['fullName'] ?? data['name'] ?? '-'),
              _reviewItem('رقم الهاتف', data['phone'] ?? '-'),
              _reviewItem('ماركة السيارة', data['carType'] ?? '-'),
              _reviewItem('الموديل والسنة', '${data['carModel'] ?? '-'} (${data['carYear'] ?? '-'})'),
              _reviewItem('رقم السيارة', data['carNumber'] ?? '-'),
              _reviewItem('المحافظة', data['governorateName'] ?? data['governorate'] ?? '-'),
              const SizedBox(height: 16),
              const Text('ملاحظة: تفعيل الحساب سيسمح للسائق باستلام طلبات الركاب فوراً.', 
                style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                Navigator.pop(ctx);
                _approveRequest(docId, data);
              },
              child: const Text('تأكيد القبول والتفعيل', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewItem(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _callPhone(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final url = Uri.parse("tel:$phone");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _whatsappPhone(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    String p = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!p.startsWith('964')) p = '964$p';
    final url = Uri.parse("whatsapp://send?phone=+$p");
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما قدرنا نفتح واتساب')));
    }
  }

  Future<void> _approveRequest(String docId, Map<String, dynamic> data) async {
    try {
      final uid = data['uid'] ?? data['id'] ?? docId;
      await _taxiKycRepository.approveTaxiKyc(docId: docId, requestData: data);

      if (uid.isNotEmpty) {
        try {
          await NotificationService.emitEvent(
            type: 'user_notification',
            payload: {
              'user_id': uid,
              'title': "تهانينا!",
              'body': "تم قبول طلب انضمامك ككابتن. يمكنك الآن البدء بالعمل!",
              'data': {"type": "registration_approved", "role": "driver"},
            },
          );
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم قبول كابتن التاكسي وتفعيل حسابه بنجاح', style: TextStyle()), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: const TextStyle()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectRequest(String docId, String? uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الرفض', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من رفض هذا الطلب؟', style: TextStyle()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع', style: TextStyle())),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('رفض', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await _taxiKycRepository.rejectTaxiKyc(docId: docId, uid: uid ?? docId);

      if (uid != null && uid.isNotEmpty) {
        try {
          await NotificationService.emitEvent(
            type: 'user_notification',
            payload: {
              'user_id': uid,
              'title': "تحديث حالة الطلب",
              'body': "نعتذر، لم يتم قبول طلب انضمامك حالياً.",
              'data': {"type": "registration_rejected", "role": "driver"},
            },
          );
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض الطلب بنجاح', style: TextStyle()), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: const TextStyle()), backgroundColor: Colors.red),
        );
      }
    }
  }
}

