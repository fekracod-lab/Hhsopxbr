import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';

class ServiceTrackingPage extends StatelessWidget {
  final String requestId;
  final String serviceType; // 'mersal' or 'delegate'

  const ServiceTrackingPage({super.key, required this.requestId, required this.serviceType});

  @override
  Widget build(BuildContext context) {
    final collection = serviceType == 'mersal' ? 'mersal_requests' : 'delegate_requests';
    final title = serviceType == 'mersal' ? 'تتبع مرسال' : 'تتبع المندوب';

    return Scaffold(
      backgroundColor: const Color(0xFF07191A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection(collection).doc(requestId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF26A69A)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'الطلب غير موجود',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'pending';
          final driverName = data['driverName'];
          final driverPhone = data['driverPhone'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildStatusLottie(status),
                const SizedBox(height: 30),
                _buildStatusCard(status),
                const SizedBox(height: 20),
                if (driverName != null) _buildDriverCard(driverName, driverPhone),
                const SizedBox(height: 20),
                _buildDetailsCard(data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusLottie(String status) {
    String url = 'https://assets10.lottiefiles.com/packages/lf20_9w8vuniz.json'; // Default
    if (status == 'delivered' || status == 'completed') {
      url = 'https://assets2.lottiefiles.com/packages/lf20_pqnfmone.json';
    } else if (status == 'on_the_way' || status == 'accepted') {
      url = 'https://assets5.lottiefiles.com/packages/lf20_T6374H.json';
    }

    return Center(
      child: Lottie.network(
        url,
        height: 200,
        errorBuilder:
            (context, error, stackTrace) =>
                const Icon(Icons.local_shipping, size: 100, color: Color(0xFF26A69A)),
      ),
    );
  }

  Widget _buildStatusCard(String status) {
    String text = 'جاري البحث عن مندوب...';
    Color color = Colors.orange;

    if (status == 'accepted') {
      text = 'تم قبول طلبك، المندوب يجهز الطلب الآن';
      color = Colors.blue;
    } else if (status == 'on_the_way') {
      text = 'المندوب في الطريق إليك الآن';
      color = Colors.indigo;
    } else if (status == 'delivered' || status == 'completed') {
      text = 'تم توصيل الطلب بنجاح، شكراً لك!';
      color = Colors.green;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF113033),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            'حالة الطلب',
            style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(String? name, String? phone) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF113033),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF26A69A),
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name ?? 'المندوب',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'كابتن مدار',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
          if (phone != null)
            IconButton(
              onPressed: () => launchUrl(Uri.parse('tel:$phone')),
              icon: const Icon(Icons.call, color: Colors.greenAccent),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF113033),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تفاصيل الطلب',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF80CBC4),
            ),
          ),
          const Divider(color: Colors.white10),
          _detailItem('الوصف', data['requestDescription'] ?? '...'),
          if (data['storeName'] != null) _detailItem('من', data['storeName']),
          _detailItem('إلى', data['dropoffAddress'] ?? '...'),
          if (data['price'] != null) _detailItem('الأجرة المتفق عليها', '${data['price']} د.ع'),
        ],
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white54),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
