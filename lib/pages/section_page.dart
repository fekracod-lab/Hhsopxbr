import 'package:flutter/material.dart';
import 'package:dalal_alqaim/services/firestore_service.dart';
import 'package:dalal_alqaim/widgets/item_card.dart';
import 'package:dalal_alqaim/services/app_location_service.dart';

class SectionPage extends StatelessWidget {
  final String sectionId;
  final String sectionTitle;

  const SectionPage({super.key, required this.sectionId, required this.sectionTitle});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(sectionTitle)),
        body: ListenableBuilder(
          listenable: AppLocationService(),
          builder: (context, child) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: service.streamItemsByCategorySimple(sectionId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                }

                var items = snapshot.data ?? [];

                // Location filtering disabled: show all items

                if (items.isEmpty) {
                  return Center(
                    child: Text('ماكو نتائج حالياً في قسم "$sectionTitle" لهيب الموقع المحدد'),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) => ItemCard(item: items[index]),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
