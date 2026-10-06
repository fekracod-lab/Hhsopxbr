import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notification_service.dart';

class StoreRequestsPage extends StatefulWidget {
  final String? governorateId;
  const StoreRequestsPage({super.key, this.governorateId});

  @override
  State<StoreRequestsPage> createState() => _StoreRequestsPageState();
}

class _StoreRequestsPageState extends State<StoreRequestsPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Colors.purple.shade700;

    Query query = FirebaseFirestore.instance
        .collection('store_requests')
        .where('status', isEqualTo: 'pending');

    if (widget.governorateId != null) {
      query = query.where('governorateId', isEqualTo: widget.governorateId);
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F13) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'طلبات تسجيل المتاجر',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}', style: const TextStyle()));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.purple));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.purple.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  const Text('ماكو طلبات حالياً معلقة', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildRequestCard(doc.id, data, isDark, primaryColor);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(String docId, Map<String, dynamic> data, bool isDark, Color primaryColor) {
    final cardBg = isDark ? const Color(0xFF1E1E24) : Colors.white;
    final txtColor = isDark ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child:
                      data['imageUrl'] != null && (data['imageUrl'] as String).isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.network(data['imageUrl'], fit: BoxFit.cover),
                            )
                          : const Icon(Icons.storefront, color: Colors.purple, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['storeName'] ?? 'بدون اسم',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: txtColor,
                        ),
                      ),
                      Text(
                        'المالك: ${data['ownerName'] ?? ''}',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone, color: Colors.green, size: 20),
                  ),
                  onPressed: () => _callPhone(data['phone']),
                ),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
            _buildInfoRow(Icons.category_outlined, 'النشاط', data['category'] ?? 'غير محدد', isDark),
            const SizedBox(height: 10),
            _buildInfoRow(Icons.location_on_outlined, 'العنوان', data['address'] ?? 'غير محدد', isDark),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveRequest(docId, data),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'قبول الطلب',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectRequest(docId, data['uid']),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'رفض',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(value, style: const TextStyle())),
      ],
    );
  }

  Future<void> _callPhone(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final url = Uri.parse("tel:$phone");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _approveRequest(String docId, Map<String, dynamic> data) async {
    try {
      final uid = data['uid'];
      if (uid == null) throw 'معرف المستخدم غير متوفر';

      // 1. Update request status
      await FirebaseFirestore.instance.collection('store_requests').doc(docId).update({
        'status': 'approved',
        'processedAt': FieldValue.serverTimestamp(),
      });

      // 2. Add to stores collection
      await FirebaseFirestore.instance.collection('stores').doc(uid).set({
        'name': data['storeName'],
        'category': data['category'] ?? 'سوبر ماركت',
        'rating': 5.0,
        'ownerId': uid,
        'logoUrl': data['imageUrl'] ?? '',
        'coverUrl': data['imageUrl'] ?? '',
        'governorateId': data['governorateId'],
        'governorateName': data['governorateName'],
        'regionId': data['regionId'],
        'regionName': data['regionName'],
        'address': data['address'] ?? '',
        'isOpen': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Update users collection status and role
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'role': 'store_owner',
        'status': 'active',
        'approvedAt': FieldValue.serverTimestamp(),
        'governorateId': data['governorateId'],
        'governorateName': data['governorateName'],
        'regionId': data['regionId'],
        'regionName': data['regionName'],
      });

      // 4. Send Notification
      try {
        await NotificationService.emitEvent(
          type: 'user_notification',
          payload: {
            'user_id': uid,
            'title': "تهانينا!",
            'body': "تمت الموافقة على طلب انضمام متجرك. يمكنك الآن البدء باستقبال وإدارة الطلبات.",
            'data': {"type": "registration_approved", "role": "store_owner"},
          },
        );
      } catch (e) {
        debugPrint("Notification error (Approve Store): $e");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم قبول وتفعيل المتجر بنجاح', style: TextStyle()), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e', style: const TextStyle()), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _rejectRequest(String docId, String? uid) async {
    try {
      await FirebaseFirestore.instance.collection('store_requests').doc(docId).update({
        'status': 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
      });

      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
        });

        // Send Notification
        try {
          await NotificationService.emitEvent(
            type: 'user_notification',
            payload: {
              'user_id': uid,
              'title': "تحديث حالة الطلب",
              'body': "نعتذر، لم يتم قبول طلب انضمام متجرك في الوقت الحالي.",
              'data': {"type": "registration_rejected", "role": "store_owner"},
            },
          );
        } catch (e) {
          debugPrint("Notification error (Reject Store): $e");
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض الطلب', style: TextStyle())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e', style: const TextStyle()), backgroundColor: Colors.red));
      }
    }
  }
}
