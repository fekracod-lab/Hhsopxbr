import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'regions_management_page.dart';
import '../core/utils/iraq_data_seeder.dart';
import 'governorate_dashboard_page.dart';

class GovernoratesManagementPage extends StatefulWidget {
  final bool canDelete;
  const GovernoratesManagementPage({super.key, this.canDelete = false});

  @override
  State<GovernoratesManagementPage> createState() => _GovernoratesManagementPageState();
}

class _GovernoratesManagementPageState extends State<GovernoratesManagementPage> {
  final Color primaryColor = const Color(0xFF26A69A);
  final Color darkBackground = const Color(0xFF07191A);
  final Color darkSurface = const Color(0xFF0F2323);
  final Color darkCard = const Color(0xFF113033);
  final Color darkText = const Color(0xFFE0F2F1);
  final Color darkSubText = const Color(0xFF80CBC4);
  File? _selectedImage;
  bool _isUploading = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onReorder(int oldIndex, int newIndex, List<QueryDocumentSnapshot> list) async {
    if (newIndex > oldIndex) newIndex -= 1;

    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < list.length; i++) {
      batch.update(list[i].reference, {'orderIndex': i});
    }

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الترتيب بنجاح', style: TextStyle()),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error committing reorder batch: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? darkBackground : Colors.grey[100];
    final cardColor = isDark ? darkCard : Colors.white;
    final textColor = isDark ? darkText : Colors.black87;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text(
            'إدارة المحافظات',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: isDark ? darkSurface : primaryColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: Colors.white),
              tooltip: 'تعبئة كافة محافظات ومناطق العراق',
              onPressed: () => _seedData(context),
            ),
          ],
        ),
        body: Column(
          children: [
            // Modern Search Bar
            _buildSearchBar(isDark, cardColor),
            
            // Warnings / Info (Disabled reordering alert)
            if (_searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.amber[800], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ملاحظة: السحب وإعادة الترتيب غير متاحين أثناء البحث والفلترة.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.amber[200] : Colors.amber[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Main List Content
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('governorates').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 80,
                            color: isDark ? darkSubText : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد محافظات مضافة حالياً',
                            style: TextStyle(
                              color: isDark ? darkSubText : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // 1. Sort in-memory to handle legacy documents without orderIndex
                  final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
                  sortedDocs.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aOrder = aData['orderIndex'] ?? 999999;
                    final bOrder = bData['orderIndex'] ?? 999999;

                    if (aOrder != bOrder) {
                      return aOrder.compareTo(bOrder);
                    }
                    final aName = (aData['name'] ?? '').toString();
                    final bName = (bData['name'] ?? '').toString();
                    return aName.compareTo(bName);
                  });

                  // 2. Filter in-memory for search query
                  final filteredDocs = sortedDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery.toLowerCase());
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Text(
                        'لا توجد محافظات مطابقة للبحث',
                        style: TextStyle(
                          color: isDark ? darkSubText : Colors.grey,
                        ),
                      ),
                    );
                  }

                  if (_searchQuery.isNotEmpty) {
                    // Standard ListView without reordering during search
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildGovernorateCard(
                          context: context,
                          index: index,
                          docId: doc.id,
                          name: data['name'] ?? '',
                          isActive: data['isActive'] ?? true,
                          data: data,
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                          isReorderEnabled: false,
                        );
                      },
                    );
                  } else {
                    // Reorderable List
                    return ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: filteredDocs.length,
                      onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, filteredDocs),
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildGovernorateCard(
                          context: context,
                          index: index,
                          docId: doc.id,
                          name: data['name'] ?? '',
                          isActive: data['isActive'] ?? true,
                          data: data,
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                          isReorderEnabled: true,
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddEditDialog(),
          backgroundColor: primaryColor,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'إضافة محافظة',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color cardColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: TextStyle(
          fontSize: 14,
          color: isDark ? darkText : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: 'البحث عن محافظة...',
          hintStyle: TextStyle(
            fontSize: 14,
            color: isDark ? darkSubText.withValues(alpha: 0.5) : Colors.grey[400],
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? darkSubText : primaryColor,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'نشط' : 'معطل',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreActionsMenu({
    required String docId,
    required String name,
    required bool isActive,
    required Map<String, dynamic> data,
    required bool isDark,
    required Color cardColor,
  }) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: isDark ? darkSubText : Colors.grey[600]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      onSelected: (value) {
        if (value == 'assign') {
          _showAssignManagerDialog(docId, name, data['managerUid']);
        } else if (value == 'toggle') {
          _toggleStatus(docId, isActive);
        } else if (value == 'edit') {
          _showAddEditDialog(
            docId: docId,
            oldName: name,
            initialImageUrl: data['imageUrl'],
          );
        } else if (value == 'delete') {
          _confirmDelete(docId, name);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'assign',
          child: Row(
            children: [
              Icon(Icons.assignment_ind_rounded, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text('تعيين مسؤول', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: Row(
            children: [
              Icon(isActive ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(isActive ? 'تعطيل' : 'تفعيل', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, color: Colors.teal, size: 20),
              SizedBox(width: 8),
              Text('تعديل الاسم/الصورة', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        if (widget.canDelete)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Text('حذف', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGovernorateCard({
    required BuildContext context,
    required int index,
    required String docId,
    required String name,
    required bool isActive,
    required Map<String, dynamic> data,
    required Color cardColor,
    required Color textColor,
    required bool isDark,
    required bool isReorderEnabled,
  }) {
    final hasManager = data['managerName'] != null;
    final managerName = data['managerName'] ?? '';
    final imageUrl = data['imageUrl'] as String?;

    return Container(
      key: ValueKey(docId),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            if (isReorderEnabled)
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0, right: 4.0),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: isDark ? darkSubText.withValues(alpha: 0.6) : Colors.grey[400],
                    size: 24,
                  ),
                ),
              ),

            // Image / Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: primaryColor.withValues(alpha: 0.1),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.map_rounded, color: primaryColor, size: 24),
                      ),
                    )
                  : Icon(Icons.map_rounded, color: primaryColor, size: 24),
            ),
          ],
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isActive ? textColor : textColor.withValues(alpha: 0.5),
            decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                _buildStatusBadge(isActive),
                if (hasManager) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isDark ? darkSubText : primaryColor).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_pin_rounded,
                          size: 14,
                          color: isDark ? darkSubText : primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'المسؤول: $managerName',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? darkSubText : primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (!hasManager) ...[
              const SizedBox(height: 4),
              Text(
                'لا يوجد مسؤول معين حالياً',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? darkSubText.withValues(alpha: 0.5) : Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _actionButton(
              icon: Icons.dashboard_rounded,
              color: Colors.orange,
              tooltip: 'لوحة التحكم',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GovernorateDashboardPage(
                    governorateId: docId,
                    governorateName: name,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _actionButton(
              icon: Icons.location_city_rounded,
              color: Colors.teal,
              tooltip: 'إدارة المناطق',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RegionsManagementPage(
                    governorateId: docId,
                    governorateName: name,
                    canDelete: widget.canDelete,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _buildMoreActionsMenu(
              docId: docId,
              name: name,
              isActive: isActive,
              data: data,
              isDark: isDark,
              cardColor: cardColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return InkWell(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  Future<void> _showAddEditDialog({String? docId, String? oldName, String? initialImageUrl}) async {
    final controller = TextEditingController(text: oldName);
    final isEdit = docId != null;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: isDark ? darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              isEdit ? 'تعديل محافظة' : 'إضافة محافظة جديدة',
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: StatefulBuilder(
              builder:
                  (context, setDialogState) => SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final picker = ImagePicker();
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 70,
                            );
                            if (image != null) {
                              setDialogState(() {
                                _selectedImage = File(image.path);
                              });
                            }
                          },
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: isDark ? darkSurface : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? darkSubText : Colors.grey[400]!),
                            ),
                            child:
                                _selectedImage != null
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                                    )
                                    : (initialImageUrl != null)
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(initialImageUrl, fit: BoxFit.cover),
                                    )
                                    : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_a_photo,
                                          color: isDark ? darkSubText : Colors.grey,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'إضافة صورة',
                                          style: TextStyle(
                                            color: isDark ? darkSubText : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                        TextField(
                          controller: controller,
                          autofocus: true,
                          style: TextStyle(
                            color: isDark ? darkText : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: 'اسم المحافظة',
                            labelStyle: const TextStyle(),
                            hintText: 'أدخل الاسم (مثلاً: محافظة كركوك)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        if (_isUploading)
                          const Padding(
                            padding: EdgeInsets.only(top: 16.0),
                            child: CircularProgressIndicator(),
                          ),
                      ],
                    ),
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _selectedImage = null;
                  Navigator.pop(ctx);
                },
                child: const Text('إلغاء', style: TextStyle()),
              ),
              StatefulBuilder(
                builder:
                    (context, setButtonState) => ElevatedButton(
                      onPressed:
                          _isUploading
                              ? null
                              : () async {
                                setButtonState(() {
                                  _isUploading = true;
                                });
                                await _saveGovernorate(ctx, docId, controller.text.trim());
                                if (mounted) {
                                  setState(() {
                                    _isUploading = false;
                                    _selectedImage = null;
                                  });
                                }
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        isEdit ? 'حفظ' : 'إضافة',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
              ),
            ],
          ),
    );
  }

  Future<void> _saveGovernorate(BuildContext ctx, String? docId, String name) async {
    if (name.isEmpty) return;

    try {
      // Duplicate Check
      final duplicate =
          await FirebaseFirestore.instance
              .collection('governorates')
              .where('name', isEqualTo: name)
              .get();

      String? imageUrl;
      if (_selectedImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('governorates')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      if (duplicate.docs.isNotEmpty && (docId == null || duplicate.docs.first.id != docId)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هذه المحافظة موجودة بالفعل', style: TextStyle()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (docId == null) {
        // Fetch highest orderIndex for new governorate
        final govCountQuery = await FirebaseFirestore.instance
            .collection('governorates')
            .orderBy('orderIndex', descending: true)
            .limit(1)
            .get();
        int nextOrderIndex = 0;
        if (govCountQuery.docs.isNotEmpty) {
          final data = govCountQuery.docs.first.data();
          nextOrderIndex = ((data['orderIndex'] ?? 0) as num).toInt() + 1;
        } else {
          final allGovs = await FirebaseFirestore.instance.collection('governorates').get();
          nextOrderIndex = allGovs.docs.length;
        }

        // Add
        await FirebaseFirestore.instance.collection('governorates').add({
          'name': name,
          'imageUrl': imageUrl,
          'isActive': true,
          'orderIndex': nextOrderIndex,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Edit
        final updateData = <String, dynamic>{
          'name': name,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (imageUrl != null) {
          updateData['imageUrl'] = imageUrl;
        }
        await FirebaseFirestore.instance.collection('governorates').doc(docId).update(updateData);
      }

      if (!ctx.mounted) return;
      Navigator.pop(ctx);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            docId == null ? 'تمت إضافة المحافظة بنجاح' : 'تم تحديث المحافظة',
            style: const TextStyle(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error saving governorate: $e');
    }
  }

  Future<void> _toggleStatus(String docId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('governorates').doc(docId).update({
        'isActive': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error toggling status: $e');
    }
  }

  Future<void> _confirmDelete(String docId, String name) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'تأكيد الحذف',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'متأكد تريد تحذف محافظة "$name" نهائياً؟',
          style: const TextStyle(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle()),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('governorates').doc(docId).delete();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حذف المحافظة')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'حذف',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _seedData(BuildContext context) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? darkCard : Colors.white,
        title: const Text('تعبئة البيانات الشاملة', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('سيتم إضافة كافة محافظات وأقضية العراق الآن. قد تستغرق العملية لحظات...', 
              style: TextStyle(fontSize: 13)),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );

    try {
      await IraqiDataSeeder.seedIraqData();
      if (!context.mounted) return;
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت إضافة كافة المحافظات والمناطق بنجاح!', style: TextStyle()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء التعبئة: $e')),
      );
    }
  }

  void _showAssignManagerDialog(String govId, String govName, String? currentManagerUid) {
    String searchQuery = '';
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: isDark ? darkCard : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(
                  'تعيين مسؤول لمحافظة $govName',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: Column(
                    children: [
                      TextField(
                        onChanged: (v) => setStateDialog(() => searchQuery = v),
                        style: TextStyle(color: isDark ? darkText : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'بحث بالاسم، الإيميل أو الهاتف...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('users').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final allUsers = snapshot.data!.docs;
                            final filtered = allUsers.where((doc) {
                              final uData = doc.data() as Map<String, dynamic>;
                              final name = (uData['username'] ?? uData['name'] ?? '').toString().toLowerCase();
                              final email = (uData['email'] ?? '').toString().toLowerCase();
                              final phone = (uData['phone'] ?? '').toString();
                              final query = searchQuery.toLowerCase();
                              return name.contains(query) || email.contains(query) || phone.contains(query);
                            }).toList();

                            if (filtered.isEmpty) {
                              return const Center(
                                child: Text('ماكو نتائج حالياً مطابقة', style: TextStyle()),
                              );
                            }

                            return ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, idx) {
                                final uDoc = filtered[idx];
                                final uData = uDoc.data() as Map<String, dynamic>;
                                final uId = uDoc.id;
                                final name = uData['username'] ?? uData['name'] ?? uData['email'] ?? 'بدون اسم';
                                final email = uData['email'] ?? '';
                                final phone = uData['phone'] ?? '';
                                final isCurrent = uId == currentManagerUid;

                                return ListTile(
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                      color: isCurrent ? primaryColor : (isDark ? darkText : Colors.black87),
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$email\n$phone',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: isCurrent
                                      ? const Icon(Icons.check_circle, color: Colors.green)
                                      : const Icon(Icons.chevron_left),
                                  onTap: () async {
                                    await _assignManager(govId, govName, uId, name, email, phone, currentManagerUid);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  if (currentManagerUid != null)
                    TextButton(
                      onPressed: () async {
                        await _removeManager(govId, currentManagerUid);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text(
                        'إزالة المسؤول الحالي',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إلغاء', style: TextStyle()),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _assignManager(
    String govId,
    String govName,
    String userUid,
    String userName,
    String userEmail,
    String userPhone,
    String? oldManagerUid,
  ) async {
    try {
      // 1. If there's an old manager, reset their role/governorate
      if (oldManagerUid != null && oldManagerUid != userUid) {
        await FirebaseFirestore.instance.collection('users').doc(oldManagerUid).update({
          'role': 'user',
          'assignedGovernorateId': FieldValue.delete(),
          'assignedGovernorateName': FieldValue.delete(),
        });
      }

      // 2. Update the new manager's user doc
      await FirebaseFirestore.instance.collection('users').doc(userUid).update({
        'role': 'governorate_manager',
        'assignedGovernorateId': govId,
        'assignedGovernorateName': govName,
      });

      // 3. Update the governorate doc
      await FirebaseFirestore.instance.collection('governorates').doc(govId).update({
        'managerUid': userUid,
        'managerName': userName,
        'managerEmail': userEmail,
        'managerPhone': userPhone,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تعيين $userName مسؤولاً لمحافظة $govName بنجاح', style: const TextStyle()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error assigning manager: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء التعيين: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _removeManager(String govId, String managerUid) async {
    try {
      // 1. Reset user role
      await FirebaseFirestore.instance.collection('users').doc(managerUid).update({
        'role': 'user',
        'assignedGovernorateId': FieldValue.delete(),
        'assignedGovernorateName': FieldValue.delete(),
      });

      // 2. Reset governorate info
      await FirebaseFirestore.instance.collection('governorates').doc(govId).update({
        'managerUid': FieldValue.delete(),
        'managerName': FieldValue.delete(),
        'managerEmail': FieldValue.delete(),
        'managerPhone': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت إزالة المسؤول بنجاح', style: TextStyle()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error removing manager: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء إزالة المسؤول: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
