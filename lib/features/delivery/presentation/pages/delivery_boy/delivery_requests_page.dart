import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dalal_alqaim/core/delivery/data/repositories/mersal_kyc_repository.dart';

// --- Palette ---
const Color primaryColor = Color(0xFF00BFA5);
const Color darkBackground = Color(0xFF07191A);
const Color darkSurface = Color(0xFF0F2323);
const Color darkCard = Color(0xFF113033);
const Color darkText = Color(0xFFE0F2F1);
const Color darkSubText = Color(0xFF80CBC4);

class DeliveryRequestsPage extends StatefulWidget {
  const DeliveryRequestsPage({super.key});

  @override
  State<DeliveryRequestsPage> createState() => _DeliveryRequestsPageState();
}

class _DeliveryRequestsPageState extends State<DeliveryRequestsPage> {
  final MersalKycRepository _mersalKycRepository = MersalKycRepository();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: darkBackground,
        appBar: AppBar(
          backgroundColor: darkSurface,
          title: const Text(
            'طلبات فريق الدليفري / مرسال',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: _mersalKycRepository.streamPendingMersalKycRequests(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primaryColor));
            }
            final docs = snapshot.data ?? [];
            if (docs.isEmpty) {
              return _emptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                return _requestCard(doc.id, data);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.done_all_rounded, size: 80, color: darkSubText.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          const Text(
            'ماكو طلبات حالياً دليفري معلقة',
            style: TextStyle(color: darkSubText, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(String docId, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: darkSubText.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: data['photoUrl'] != null ? NetworkImage(data['photoUrl']) : null,
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                child:
                    data['photoUrl'] == null ? const Icon(Icons.person, color: primaryColor) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? 'بدون اسم',
                      style: const TextStyle(
                        color: darkText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      data['phone'] ?? 'بدون رقم',
                      style: const TextStyle(color: darkSubText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.phone, color: Colors.green, size: 20),
                onPressed: () => launchUrl(Uri.parse("tel:${data['phone']}")),
              ),
            ],
          ),
          const Divider(height: 24, color: Colors.white10),
          _infoRow(Icons.two_wheeler_rounded, 'وسيلة التوصيل', '${data['vehicleType'] ?? data['carType'] ?? '-'}'),
          _infoRow(Icons.palette_outlined, 'اللون والموديل', '${data['carType'] ?? ''} - ${data['carColor'] ?? '-'}'),
          _infoRow(
            Icons.confirmation_number_outlined,
            'لوحة التسجيل',
            (data['fullCarPlate'] != null && (data['fullCarPlate'] as String).isNotEmpty)
                ? '${data['fullCarPlate']}'
                : '${data['carNumber'] ?? '-'}',
          ),
          _infoRow(
            Icons.location_on_outlined,
            'نطاق التوصيل',
            [
              data['governorateName'] ?? data['governorate'] ?? '',
              data['regionName'] ?? '',
              data['subRegionName'] ?? '',
            ].where((s) => s.toString().trim().isNotEmpty).join(' - '),
          ),
          if ((data['idCardPhotoUrl'] != null && (data['idCardPhotoUrl'] as String).isNotEmpty) ||
              (data['vehiclePhotoUrl'] != null && (data['vehiclePhotoUrl'] as String).isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  if (data['vehiclePhotoUrl'] != null && (data['vehiclePhotoUrl'] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ActionChip(
                        avatar: const Icon(Icons.two_wheeler_rounded, size: 16, color: primaryColor),
                        label: const Text('صورة المركبة', style: TextStyle(fontSize: 11, color: darkText)),
                        backgroundColor: darkSurface,
                        side: BorderSide(color: darkSubText.withValues(alpha: 0.2)),
                        onPressed: () => _showImageDialog(context, data['vehiclePhotoUrl'], 'صورة وسيلة التوصيل'),
                      ),
                    ),
                  if (data['idCardPhotoUrl'] != null && (data['idCardPhotoUrl'] as String).isNotEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.badge_rounded, size: 16, color: primaryColor),
                      label: const Text('صورة الهوية', style: TextStyle(fontSize: 11, color: darkText)),
                      backgroundColor: darkSurface,
                      side: BorderSide(color: darkSubText.withValues(alpha: 0.2)),
                      onPressed: () => _showImageDialog(context, data['idCardPhotoUrl'], 'صورة البطاقة الوطنية / الهوية'),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleRequest(docId, data, 'rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('رفض', style: TextStyle()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleRequest(docId, data, 'approved'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'قبول',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: darkSubText),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: darkSubText, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: darkText,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRequest(String docId, Map<String, dynamic> data, String status) async {
    final uid = data['uid'] ?? docId;

    try {
      if (status == 'approved') {
        await _mersalKycRepository.approveMersalKyc(docId: docId, requestData: data);
      } else {
        await _mersalKycRepository.rejectMersalKyc(docId: docId, uid: uid);
      }

      // Notify via OneSignal (optional/existing logic)
      final heading = status == 'approved' ? "تم قبول طلبك!" : "تحديث حالة الطلب";
      final content =
          status == 'approved'
              ? "أهلاً بك في فريق الدليفري. يمكنك البدء الآن."
              : "نعتذر، لم يتم قبول طلبك حالياً.";

      // Emit Notification Event to Server
      await NotificationService.emitEvent(
        type: 'user_notification',
        payload: {
          'user_id': uid,
          'title': heading,
          'body': content,
          'data': {"type": "registration_$status", "role": "delivery"},
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'approved' ? 'تم قبول طلب الدليفري بنجاح' : 'تم رفض الطلب'),
            backgroundColor: status == 'approved' ? primaryColor : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  void _showImageDialog(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.image_outlined, color: primaryColor, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: darkText),
              ),
            ),
          ],
        ),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: primaryColor)),
              );
            },
            errorBuilder: (_, __, ___) => const SizedBox(
              height: 100,
              child: Center(child: Text('تعذر تحميل الصورة', style: TextStyle(color: darkSubText))),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
