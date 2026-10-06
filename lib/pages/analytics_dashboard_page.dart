import 'package:flutter/material.dart';
import 'package:dalal_alqaim/features/home/pages/home_page.dart';
// لاحقاً: استيراد مكتبات fl_chart وخرائط إذا لزم الأمر

class AnalyticsDashboardPage extends StatelessWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('لوحة التحليلات')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'المستخدمون النشطون (يومي/شهري)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 200, child: Center(child: Text('رسم بياني هنا'))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'الخريطة الحرارية للأقسام',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 200, child: Center(child: Text('خريطة حرارية هنا'))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('التحليل الديموغرافي', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 200, child: Center(child: Text('رسم بياني ديموغرافي هنا'))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('مسارات المستخدمين', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 200, child: Center(child: Text('تتبع المسارات هنا'))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
