import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../services/firestore_sync_service.dart';

import 'add_food_page.dart';

// --- Palette (teal/turquoise theme matching Dalal Alqaim) ---
const Color _primary = Color(0xFF26A69A);
const Color _darkBg = Color(0xFF07191A);
const Color _darkCard = Color(0xFF113033);
const Color _darkText = Color(0xFFE0F2F1);
const Color _darkSub = Color(0xFF80CBC4);

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: ThemeData.dark().copyWith(
          textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(ThemeData.dark().textTheme),
        ),
        child: Scaffold(
          backgroundColor: _darkBg,
          appBar: AppBar(
            backgroundColor: _darkCard,
            elevation: 0,
            title: Text(
              'قائمة وجبات مطعمي',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: _primary),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddFoodPage()),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: GoogleFonts.ibmPlexSansArabic(color: _darkText),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن وجبة...',
                    hintStyle: GoogleFonts.ibmPlexSansArabic(color: _darkSub.withValues(alpha: 0.4)),
                    prefixIcon: const Icon(Icons.search, color: _primary),
                    filled: true,
                    fillColor: _darkCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Products list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('merchant_products')
                      .doc(_uid)
                      .collection('products')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: _primary));
                    }

                    final docs = snapshot.data?.docs ?? [];
                    final filteredDocs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery.toLowerCase());
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restaurant_menu_rounded,
                                size: 64, color: _darkSub.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'قائمة وجباتك فارغة حالياً'
                                  : 'ماكو وجبات حالياً تطابق البحث',
                              style: GoogleFonts.ibmPlexSansArabic(color: _darkSub),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] ?? 'بدون اسم';
                        final price = data['sellingPrice'] ?? 0.0;
                        final imageUrl = data['imageUrl'] ?? '';
                        final desc = data['description'] ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _darkCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 70,
                                        height: 70,
                                        color: Colors.white10,
                                        child: const Icon(Icons.image, color: Colors.white30),
                                      ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontWeight: FontWeight.bold,
                                        color: _darkText,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (desc.isNotEmpty)
                                      Text(
                                        desc,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          color: _darkSub.withValues(alpha: 0.5),
                                          fontSize: 11,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'السعر للزبون: $price د.ع',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        color: _primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, color: _primary),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddFoodPage(
                                        foodDocId: doc.id,
                                        initialData: data,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: AlertDialog(
                                        backgroundColor: _darkCard,
                                        title: Text('حذف الوجبة', style: GoogleFonts.ibmPlexSansArabic(color: _darkText, fontWeight: FontWeight.bold)),
                                        content: Text('متأكد تريد تحذف "$name" من قائمة وجباتك؟', style: GoogleFonts.ibmPlexSansArabic(color: _darkSub)),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(c, false),
                                            child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: _darkSub)),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                            onPressed: () => Navigator.pop(c, true),
                                            child: Text('حذف', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );

                                  if (confirm == true) {
                                    await FirebaseFirestore.instance
                                        .collection('merchant_products')
                                        .doc(_uid)
                                        .collection('products')
                                        .doc(doc.id)
                                        .delete();
                                    
                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('stores')
                                          .doc(_uid)
                                          .collection('products')
                                          .doc(doc.id)
                                          .delete();
                                    } catch (_) {}

                                    try {
                                      await FirestoreSyncService.syncDeleteMeal(_uid, doc.id);
                                    } catch (_) {}
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
