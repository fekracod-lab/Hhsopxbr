import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notification_service.dart';

class RestaurantRequestsPage extends StatefulWidget {
  final String? governorateId;
  const RestaurantRequestsPage({super.key, this.governorateId});

  @override
  State<RestaurantRequestsPage> createState() => _RestaurantRequestsPageState();
}

class _RestaurantRequestsPageState extends State<RestaurantRequestsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'طلبات تسجيل المطاعم',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange.shade800,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: widget.governorateId != null
            ? FirebaseFirestore.instance
                .collection('restaurant_requests')
                .where('status', isEqualTo: 'pending')
                .where('governorateId', isEqualTo: widget.governorateId)
                .snapshots()
            : FirebaseFirestore.instance
                .collection('restaurant_requests')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('ماكو طلبات حالياً معلقة', style: TextStyle(fontSize: 18, color: Colors.grey)),
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
              return _buildRequestCard(doc.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(String docId, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
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
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child:
                      data['imageUrl'] != null && (data['imageUrl'] as String).isNotEmpty
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.network(data['imageUrl'], fit: BoxFit.cover),
                          )
                          : const Icon(Icons.restaurant, color: Colors.orange, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['restaurantName'] ?? 'بدون اسم',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'المالك: ${data['ownerName'] ?? ''}',
                        style: TextStyle(
                          color: Colors.grey[600],
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
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone, color: Colors.green, size: 20),
                  ),
                  onPressed: () => _callPhone(data['phone']),
                ),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
            _buildInfoRow(Icons.category_outlined, 'النشاط', data['type'] ?? 'غير محدد'),
            const SizedBox(height: 10),
            _buildInfoRow(Icons.location_on_outlined, 'العنوان', data['address'] ?? 'غير محدد'),
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
                      side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(value)),
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
      // 1. Update request status
      await FirebaseFirestore.instance.collection('restaurant_requests').doc(docId).update({
        'status': 'approved',
        'processedAt': FieldValue.serverTimestamp(),
      });

      // 2. Add to restaurants collection
      if (data['uid'] != null) {
        // Map registration type to display category for restaurants_page.dart
        String category = 'المطاعم'; // Default
        String type = data['type'] ?? 'مطعم';
        if (type == 'مطعم') {
          category = 'المطاعم';
        } else if (type == 'حلويات') {
          category = 'الحلويات';
        } else if (type == 'كافيه') {
          category = 'العصائر';
        } else if (type == 'منزلي') {
          category = 'المنزلية';
        }

        await FirebaseFirestore.instance.collection('restaurants').doc(data['uid']).set({
          'uid': data['uid'],
          'ownerName': data['ownerName'],
          'name': data['restaurantName'] ?? data['name'],
          'restaurantName': data['restaurantName'] ?? data['name'],
          'phone': data['phone'],
          'address': data['address'],
          'type': data['type'],
          'category': category, // Added for filtering in restaurants_page.dart
          'isOpen': false,
          'rating': 5.0,
          'status': 'active',
          'isApproved': true,
          'approvedAt': FieldValue.serverTimestamp(),
          'governorateId': data['governorateId'],
          'governorateName': data['governorateName'],
          'regionId': data['regionId'],
          'regionName': data['regionName'],
          if (data['subRegion'] != null) 'subRegion': data['subRegion'],
          if (data['neighborhood'] != null) 'neighborhood': data['neighborhood'],
          if (data['imageUrl'] != null) 'imageUrl': data['imageUrl'],
          if (data['logoUrl'] != null) 'logoUrl': data['logoUrl'],
          if (data['latitude'] != null) 'latitude': data['latitude'],
          if (data['longitude'] != null) 'longitude': data['longitude'],
          if (data['deliveryTime'] != null) 'deliveryTime': data['deliveryTime'],
          if (data['minOrderAmount'] != null) 'minOrderAmount': data['minOrderAmount'],
          if (data['whatsappPhone'] != null) 'whatsappPhone': data['whatsappPhone'],
        }, SetOptions(merge: true));

        // 3. Create a placeholder item in 'sections' -> 'items' so it appears in the app
        // Find or Create 'Restaurants' section
        String sectionId;
        final sections =
            await FirebaseFirestore.instance
                .collection('sections')
                .where('label', isEqualTo: 'مطاعم')
                .limit(1)
                .get();

        if (sections.docs.isNotEmpty) {
          sectionId = sections.docs.first.id;
        } else {
          // Create section if not exists
          final newSection = await FirebaseFirestore.instance.collection('sections').add({
            'label': 'مطاعم',
            'icon': 'restaurant',
            'color': 0xFFFF5722, // Orange
            'order': 1,
            'createdAt': FieldValue.serverTimestamp(),
          });
          sectionId = newSection.id;
        }

        // Map registration type to display specialty
        String specialty = data['type'] ?? 'مطاعم';
        if (specialty == 'مطعم') specialty = 'مطاعم';
        if (specialty == 'كافيه') specialty = 'كافيهات';

        // Add item to the section
        await FirebaseFirestore.instance
            .collection('sections')
            .doc(sectionId)
            .collection('items')
            .add({
              'name': data['restaurantName'] ?? data['name'],
              'address': data['address'],
              'phone': data['phone'],
              'specialty': specialty,
              'category': category, // Added for consistency
              'type': 'restaurant',
              'rating': 5.0,
              'isOpen': false,
              'ownerId': data['uid'], // Link to owner
              'imageUrl': data['imageUrl'] ?? data['logoUrl'] ?? '',
              'createdAt': FieldValue.serverTimestamp(),
              'governorateId': data['governorateId'],
              'governorateName': data['governorateName'],
              'regionId': data['regionId'],
              'regionName': data['regionName'],
              if (data['subRegion'] != null) 'subRegion': data['subRegion'],
              if (data['latitude'] != null) 'latitude': data['latitude'],
              if (data['longitude'] != null) 'longitude': data['longitude'],
            });

        // 4. Update users collection status and role
        await FirebaseFirestore.instance.collection('users').doc(data['uid']).set({
          'role': 'restaurant',
          'subRole': 'restaurant',
          'status': 'active',
          'isApproved': true,
          'approvedAt': FieldValue.serverTimestamp(),
          'governorateId': data['governorateId'],
          'governorateName': data['governorateName'],
          'regionId': data['regionId'],
          'regionName': data['regionName'],
        }, SetOptions(merge: true));

        // 5. Send Notification
        try {
          // Emit Notification Event to Server
          await NotificationService.emitEvent(
            type: 'user_notification',
            payload: {
              'user_id': data['uid'],
              'title': "تهانينا!",
              'body': "تمت الموافقة على طلب انضمام مطعمك. يمكنك الآن البدء باستقبال الطلبات.",
              'data': {"type": "registration_approved", "role": "restaurant"},
            },
          );
        } catch (e) {
          debugPrint("Notification error (Approve): $e");
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم قبول المطعم بنجاح'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _rejectRequest(String docId, String? uid) async {
    try {
      await FirebaseFirestore.instance.collection('restaurant_requests').doc(docId).update({
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
          // Emit Notification Event to Server
          await NotificationService.emitEvent(
            type: 'user_notification',
            payload: {
              'user_id': uid,
              'title': "تحديث حالة الطلب",
              'body': "نعتذر، لم يتم قبول طلب انضمام مطعمك في الوقت الحالي.",
              'data': {"type": "registration_rejected", "role": "merchant"},
            },
          );
        } catch (e) {
          debugPrint("Notification error (Reject): $e");
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض الطلب')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
