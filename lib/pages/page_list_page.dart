import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dalal_alqaim/services/app_location_service.dart';
import 'package:dalal_alqaim/shared/section_utils.dart';
import 'section_admin_page.dart';

// Local palette for professional admin UI
class AppPalette {
  static const Color primaryColor = Color(0xFF26A69A);
  static const Color accentColor = Color(0xFF00796B);
  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF333333);
  static const Color hintColor = Color(0xFF9E9E9E);
  static const Color subTextColor = Color(0xFF757575);
  static const Color surfaceColor = Color(0xFFF8F9FA);
}

class PageListPage extends StatefulWidget {
  const PageListPage({super.key});

  @override
  State<PageListPage> createState() => _PageListPageState();
}

class _PageListPageState extends State<PageListPage> {
  Map<String, dynamic>? _userData;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted) {
          setState(() {
            _userData = doc.data();
            _isLoadingUser = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingUser = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppPalette.surfaceColor,
        appBar: AppBar(
          backgroundColor: AppPalette.surfaceColor,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'إدارة الأقسام',
            style: TextStyle(
              color: AppPalette.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppPalette.textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        floatingActionButton:
            _isLoadingUser
                ? null
                : FloatingActionButton.extended(
                  onPressed: () => _showAddSectionDialog(context, _userData),
                  backgroundColor: AppPalette.primaryColor,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'أضف قسماً',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
        body:
            _isLoadingUser
                ? const Center(child: CircularProgressIndicator(color: AppPalette.primaryColor))
                : ListenableBuilder(
                  listenable: AppLocationService(),
                  builder: (context, child) {
                    return StreamBuilder<QuerySnapshot>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('sections')
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: AppPalette.primaryColor),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return _buildEmptyState();
                        }

                        final docs = snapshot.data!.docs;

                        if (docs.isEmpty) {
                          return _buildEmptyState(message: 'لا توجد أقسام في هذا الموقع حالياً');
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: docs.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            final docId = docs[index].id;
                            return _buildSectionTile(context, docId, data);
                          },
                        );
                      },
                    );
                  },
                ),
      ),
    );
  }

  Widget _buildSectionTile(BuildContext context, String docId, Map<String, dynamic> data) {
    final label = data['label'] ?? 'بدون اسم';
    final iconName = data['icon'];
    final colorValue = data['color'] as int?;
    final govName = data['governorateName'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (colorValue != null ? Color(colorValue) : AppPalette.primaryColor).withValues(
              alpha: 0.1,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            sectionIconFromString(iconName),
            color: colorValue != null ? Color(colorValue) : AppPalette.primaryColor,
          ),
        ),
        title: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppPalette.textColor,
          ),
        ),
        subtitle:
            govName != null
                ? Row(
                  children: [
                    const Icon(Icons.location_on, size: 12, color: AppPalette.subTextColor),
                    const SizedBox(width: 4),
                    Text(
                      govName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppPalette.subTextColor,
                      ),
                    ),
                  ],
                )
                : const Text(
                  'قسم عام (كل العراق)',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppPalette.hintColor),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => SectionAdminPage(
                    sectionId: docId,
                    sectionLabel: label,
                    sectionIcon: sectionIconFromString(iconName),
                    sectionColor: colorValue != null ? Color(colorValue) : AppPalette.primaryColor,
                    isAdmin:
                        _userData?['role'] == 'admin' ||
                        _userData?['role'] == 'main_admin' ||
                        _userData?['role'] == 'limited_admin',
                  ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({String message = 'لا توجد أقسام مضافة حالياً'}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.category_outlined,
            size: 80,
            color: AppPalette.hintColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: AppPalette.subTextColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSectionDialog(BuildContext context, Map<String, dynamic>? userData) {
    final labelController = TextEditingController();
    final role = userData?['role'] as String?;
    final assignedGovId = userData?['assignedGovernorateId'] as String?;
    final assignedGovName = userData?['assignedGovernorateName'] as String?;
    final isLimitedAdmin = role == 'limited_admin';

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'إضافة قسم جديد',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اسم القسم:',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppPalette.subTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: labelController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'مثلاً: مطاعم الفلوجة',
                    hintStyle: const TextStyle(fontSize: 14),
                    filled: true,
                    fillColor: AppPalette.surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (isLimitedAdmin && assignedGovName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppPalette.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppPalette.primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppPalette.primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'سيتم ربط هذا القسم تلقائياً بمحافظة: $assignedGovName',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppPalette.accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: AppPalette.subTextColor),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () async {
                  if (labelController.text.trim().isNotEmpty) {
                    final Map<String, dynamic> newDoc = {
                      'label': labelController.text.trim(),
                      'createdAt': FieldValue.serverTimestamp(),
                      'icon': 'category',
                      'color': AppPalette.primaryColor.toARGB32(),
                    };

                    if (isLimitedAdmin && assignedGovId != null) {
                      newDoc['governorateId'] = assignedGovId;
                      newDoc['governorateName'] = assignedGovName;
                    }

                    await FirebaseFirestore.instance.collection('sections').add(newDoc);

                    // Log Action
                    try {
                      final actor = FirebaseAuth.instance.currentUser;
                      await FirebaseFirestore.instance
                          .collection('admin_actions')
                          .add(<String, dynamic>{
                            'action': 'limited_admin_add_section',
                            'actorUid': actor?.uid,
                            'actorEmail': actor?.email,
                            'sectionLabel': labelController.text.trim(),
                            'governorateId': assignedGovId,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                    } catch (_) {}

                    if (context.mounted) Navigator.pop(ctx);
                  }
                },
                child: const Text(
                  'إضافة',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }
}
