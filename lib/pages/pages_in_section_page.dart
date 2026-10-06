import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'page_items_screen.dart';
import 'all_sections_page.dart';
import 'package:flutter/services.dart';

class PagesInSectionPage extends StatefulWidget {
  final String sectionId;
  final String sectionLabel;
  final Color sectionColor;
  final IconData sectionIcon;
  final bool isAdmin;

  const PagesInSectionPage({
    super.key,
    required this.sectionId,
    required this.sectionLabel,
    required this.sectionColor,
    required this.sectionIcon,
    this.isAdmin = false,
  });

  @override
  State<PagesInSectionPage> createState() => _PagesInSectionPageState();
}

class _PagesInSectionPageState extends State<PagesInSectionPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AllSectionsPage()),
          (route) => false,
        );
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: widget.sectionColor.withValues(alpha: 0.18),
                child: Icon(widget.sectionIcon, color: widget.sectionColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.sectionLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          foregroundColor: Colors.white,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.sectionColor.withValues(alpha: 0.85),
                  Colors.white.withValues(alpha: 0.85),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.sectionColor.withValues(alpha: 0.08), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              // شريط البحث
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 38, 18, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم الصفحة أو الوصف...',
                    prefixIcon: Icon(Icons.search, color: widget.sectionColor),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(),
                ),
              ),
              // العداد
              StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('sections')
                        .doc(widget.sectionId)
                        .collection('pages')
                        .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.docs.length ?? 0;
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 24, bottom: 6),
                      child: Text(
                        'عدد الصفحات: $count',
                        style: TextStyle(
                          color: widget.sectionColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
              // القائمة الرئيسية
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('sections')
                            .doc(widget.sectionId)
                            .collection('pages')
                            .orderBy('date', descending: true)
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('لا توجد صفحات في هذا القسم'));
                      }
                      final pages =
                          snapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = (data['name'] ?? '').toString();
                            final desc = (data['description'] ?? '').toString();
                            if (_searchQuery.isNotEmpty &&
                                !(name.contains(_searchQuery) || desc.contains(_searchQuery))) {
                              return false;
                            }
                            return true;
                          }).toList();
                      if (pages.isEmpty) {
                        return const Center(child: Text('ماكو نتائج حالياً مطابقة'));
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemCount: pages.length,
                        itemBuilder: (context, i) {
                          final data = pages[i].data() as Map<String, dynamic>;
                          final pageId = pages[i].id;
                          final pageName = data['name'] ?? 'بدون اسم';
                          final pageDesc = data['description'] ?? '';
                          final date = DateTime.tryParse(data['date'] ?? '') ?? DateTime.now();
                          final isNew = DateTime.now().difference(date).inHours < 24;
                          return Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            child: ListTile(
                              leading: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: widget.sectionColor.withAlpha(40),
                                    child: Icon(widget.sectionIcon, color: widget.sectionColor),
                                  ),
                                  if (isNew)
                                    Container(
                                      margin: const EdgeInsets.only(top: 2, right: 2),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green[400],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'جديد',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(
                                pageName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: pageDesc.isNotEmpty ? Text(pageDesc) : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.share, color: Colors.blueAccent),
                                    tooltip: 'مشاركة بيانات الصفحة',
                                    onPressed: () async {
                                      final msg = 'اسم الصفحة: $pageName\nالوصف: $pageDesc';
                                      await Clipboard.setData(ClipboardData(text: msg));
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('تم نسخ بيانات الصفحة!')),
                                      );
                                    },
                                  ),
                                  Icon(Icons.arrow_forward_ios_rounded, color: colorScheme.primary),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PageItemsScreen(
                                      sectionId: widget.sectionId,
                                      pageId: pageId,
                                      pageName: pageName,
                                      sectionColor: widget.sectionColor,
                                      sectionIcon: widget.sectionIcon,
                                      isAdmin: widget.isAdmin,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
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
