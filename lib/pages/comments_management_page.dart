import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CommentsManagementPage extends StatefulWidget {
  const CommentsManagementPage({super.key});

  @override
  State<CommentsManagementPage> createState() => _CommentsManagementPageState();
}

class _CommentsManagementPageState extends State<CommentsManagementPage> {
  String _search = '';
  String _filterType = 'all'; // all, item, vacancy

  void _confirmDelete(DocumentReference docRef) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('متأكد تريد تحذف هذا التعليق؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await docRef.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف التعليق')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة التعليقات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث بنص التعليق أو اسم المستخدم أو القسم...'),
                    onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _filterType,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('الكل')),
                    DropdownMenuItem(value: 'item', child: Text('تعليقات عناصر')),
                    DropdownMenuItem(value: 'vacancy', child: Text('تعليقات وظائف')),
                  ],
                  onChanged: (v) => setState(() => _filterType = v ?? 'all'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // use collectionGroup to include comments stored as subcollections (older data)
                stream: FirebaseFirestore.instance.collectionGroup('comments').orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snap.data!.docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    if (_filterType != 'all') {
                      final t = (data['type'] ?? '').toString();
                      if (_filterType == 'item' && t != 'item') return false;
                      if (_filterType == 'vacancy' && t != 'vacancy') return false;
                    }
                    if (_search.isNotEmpty) {
                      final content = (data['content'] ?? '').toString().toLowerCase();
                      final author = (data['authorName'] ?? '').toString().toLowerCase();
                      final section = (data['sectionLabel'] ?? '').toString().toLowerCase();
                      if (!content.contains(_search) && !author.contains(_search) && !section.contains(_search)) return false;
                    }
                    return true;
                  }).toList();

                  if (docs.isEmpty) return const Center(child: Text('لا توجد تعليقات مطابقة'));
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      final data = d.data() as Map<String, dynamic>;
                      final docRef = d.reference;
                      final content = data['content'] ?? '';
                      final author = data['authorName'] ?? data['authorEmail'] ?? 'مستخدم';
                      final createdAt = data['createdAt'];
                      final sectionLabel = data['sectionLabel'] ?? '';
                      final type = data['type'] ?? 'item';
                      return ListTile(
                        title: Text(author),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(content),
                            const SizedBox(height: 6),
                            Row(children: [
                              Chip(label: Text(type == 'vacancy' ? 'وظيفة' : 'عنصر')),
                              const SizedBox(width: 6),
                              if (sectionLabel != null && sectionLabel.toString().isNotEmpty) Text('القسم: $sectionLabel', style: const TextStyle(fontSize: 12)),
                              const Spacer(),
                              if (createdAt != null)
                                Text((createdAt is Timestamp) ? createdAt.toDate().toString().split(' ')[0] : createdAt.toString(), style: const TextStyle(fontSize: 12)),
                            ])
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          tooltip: 'حذف التعليق',
                          onPressed: () => _confirmDelete(docRef),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
