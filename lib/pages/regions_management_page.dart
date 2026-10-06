import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegionsManagementPage extends StatefulWidget {
  final String governorateId;
  final String governorateName;
  final bool canDelete;

  const RegionsManagementPage({
    super.key,
    required this.governorateId,
    required this.governorateName,
    this.canDelete = false,
  });

  @override
  State<RegionsManagementPage> createState() => _RegionsManagementPageState();
}

class _RegionsManagementPageState extends State<RegionsManagementPage> {
  final Color primaryColor = const Color(0xFF26A69A);
  final Color darkBackground = const Color(0xFF07191A);
  final Color darkSurface = const Color(0xFF0F2323);
  final Color darkCard = const Color(0xFF113033);
  final Color darkText = const Color(0xFFE0F2F1);
  final Color darkSubText = const Color(0xFF80CBC4);

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
            content: Text('تم تحديث ترتيب المناطق بنجاح', style: TextStyle()),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error committing regions reorder batch: $e');
    }
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
          hintText: 'البحث عن منطقة...',
          hintStyle: TextStyle(
            fontSize: 14,
            color: isDark ? darkSubText.withValues(alpha: 0.5) : Colors.grey[400],
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? darkSubText : Colors.grey[400],
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
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

  Widget _buildRegionCard({
    Key? key,
    required BuildContext context,
    required int index,
    required String docId,
    required String name,
    required bool isActive,
    required String? managerName,
    required String? managerUid,
    required Color cardColor,
    required Color textColor,
    required bool isDark,
    required bool isReorderEnabled,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: primaryColor.withValues(alpha: 0.1),
              ),
              child: Icon(Icons.location_on_rounded, color: primaryColor, size: 22),
            ),
          ],
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isActive ? textColor : textColor.withValues(alpha: 0.5),
            decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isActive ? 'نشط' : 'معطل',
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.green : Colors.red,
              ),
            ),
            if (managerName != null) ...[
              const SizedBox(height: 4),
              Text(
                'المسؤول: $managerName',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? darkSubText : Colors.grey[700],
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _actionButton(
              icon: isActive ? Icons.visibility_off : Icons.visibility,
              color: isActive ? Colors.orange : Colors.green,
              onTap: () => _toggleStatus(docId, isActive),
              tooltip: isActive ? 'تعطيل' : 'تفعيل',
            ),
            const SizedBox(width: 8),
            _actionButton(
              icon: Icons.edit,
              color: Colors.blue,
              onTap: () => _showAddEditDialog(docId: docId, oldName: name),
              tooltip: 'تعديل الاسم',
            ),
            const SizedBox(width: 8),
            _actionButton(
              icon: Icons.person_add_rounded,
              color: Colors.purple,
              onTap: () => _showAssignManagerDialog(docId, name, managerUid),
              tooltip: 'تعيين مسؤول',
            ),
            if (widget.canDelete) ...[
              const SizedBox(width: 8),
              _actionButton(
                icon: Icons.delete,
                color: Colors.red,
                onTap: () => _confirmDelete(docId, name),
                tooltip: 'حذف المنطقة',
              ),
            ],
          ],
        ),
      ),
    );
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
          title: Text(
            'إدارة مناطق ${widget.governorateName}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: isDark ? darkSurface : primaryColor,
          elevation: 0,
        ),
        body: Column(
          children: [
            _buildSearchBar(isDark, cardColor),
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
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('governorates')
                    .doc(widget.governorateId)
                    .collection('regions')
                    .snapshots(),
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
                            Icons.location_city_outlined,
                            size: 80,
                            color: isDark ? darkSubText : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد مناطق مضافة لهذه المحافظة',
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
                        'لا توجد مناطق مطابقة للبحث',
                        style: TextStyle(
                          color: isDark ? darkSubText : Colors.grey,
                        ),
                      ),
                    );
                  }

                  if (_searchQuery.isNotEmpty) {
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final String docId = doc.id;
                        final String name = data['name'] ?? '';
                        final bool isActive = data['isActive'] ?? true;
                        final String? managerName = data['managerName'];
                        final String? managerUid = data['managerUid'];

                        return _buildRegionCard(
                          context: context,
                          index: index,
                          docId: docId,
                          name: name,
                          isActive: isActive,
                          managerName: managerName,
                          managerUid: managerUid,
                          cardColor: cardColor,
                          textColor: textColor,
                          isDark: isDark,
                          isReorderEnabled: false,
                        );
                      },
                    );
                  } else {
                    return ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: filteredDocs.length,
                      onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, filteredDocs),
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final String docId = doc.id;
                        final String name = data['name'] ?? '';
                        final bool isActive = data['isActive'] ?? true;
                        final String? managerName = data['managerName'];
                        final String? managerUid = data['managerUid'];

                        return _buildRegionCard(
                          key: ValueKey(docId),
                          context: context,
                          index: index,
                          docId: docId,
                          name: name,
                          isActive: isActive,
                          managerName: managerName,
                          managerUid: managerUid,
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
            'إضافة منطقة',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
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

  Future<void> _showAddEditDialog({String? docId, String? oldName}) async {
    final controller = TextEditingController(text: oldName);
    final isEdit = docId != null;

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor:
                Theme.of(context).brightness == Brightness.dark ? darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              isEdit ? 'تعديل منطقة' : 'إضافة منطقة جديدة',
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? darkText : Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: 'اسم المنطقة',
                labelStyle: const TextStyle(),
                hintText: 'أدخل الاسم (مثلاً: الرمادي)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle()),
              ),
              ElevatedButton(
                onPressed: () => _saveRegion(ctx, docId, controller.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  isEdit ? 'حفظ' : 'إضافة',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _saveRegion(BuildContext ctx, String? docId, String name) async {
    if (name.isEmpty) return;

    try {
      // Duplicate Check
      final duplicate =
          await FirebaseFirestore.instance
              .collection('governorates')
              .doc(widget.governorateId)
              .collection('regions')
              .where('name', isEqualTo: name)
              .get();

      if (duplicate.docs.isNotEmpty && (docId == null || duplicate.docs.first.id != docId)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'هذه المنطقة موجودة بالفعل في هذه المحافظة',
              style: TextStyle(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (docId == null) {
        // Find highest orderIndex
        final querySnap = await FirebaseFirestore.instance
            .collection('governorates')
            .doc(widget.governorateId)
            .collection('regions')
            .orderBy('orderIndex', descending: true)
            .limit(1)
            .get();
        int maxIndex = 0;
        if (querySnap.docs.isNotEmpty) {
          final data = querySnap.docs.first.data();
          maxIndex = (data['orderIndex'] as num? ?? 0).toInt() + 1;
        } else {
          final countSnap = await FirebaseFirestore.instance
              .collection('governorates')
              .doc(widget.governorateId)
              .collection('regions')
              .get();
          maxIndex = countSnap.docs.length;
        }

        // Add
        await FirebaseFirestore.instance
            .collection('governorates')
            .doc(widget.governorateId)
            .collection('regions')
            .add({
              'name': name,
              'isActive': true,
              'orderIndex': maxIndex,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } else {
        // Edit
        await FirebaseFirestore.instance
            .collection('governorates')
            .doc(widget.governorateId)
            .collection('regions')
            .doc(docId)
            .update({'name': name, 'updatedAt': FieldValue.serverTimestamp()});
      }

      if (!ctx.mounted) return;
      Navigator.pop(ctx);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            docId == null ? 'تمت إضافة المنطقة بنجاح' : 'تم تحديث المنطقة',
            style: const TextStyle(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error saving region: $e');
    }
  }

  Future<void> _toggleStatus(String docId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('governorates')
          .doc(widget.governorateId)
          .collection('regions')
          .doc(docId)
          .update({'isActive': !currentStatus, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('Error toggling status: $e');
    }
  }

  Future<void> _confirmDelete(String docId, String name) async {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor:
                Theme.of(context).brightness == Brightness.dark ? darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'تأكيد الحذف',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'متأكد تريد تحذف منطقة "$name" نهائياً؟',
              style: const TextStyle(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle()),
              ),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('governorates')
                      .doc(widget.governorateId)
                      .collection('regions')
                      .doc(docId)
                      .delete();
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('تم حذف المنطقة')));
                  }
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

  void _showAssignManagerDialog(String regionId, String regionName, String? currentManagerUid) {
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
                  'تعيين مسؤول لمنطقة $regionName',
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
                                    await _assignManager(regionId, regionName, uId, name, email, phone, currentManagerUid);
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
                        await _removeManager(regionId, currentManagerUid);
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
    String regionId,
    String regionName,
    String userUid,
    String userName,
    String userEmail,
    String userPhone,
    String? oldManagerUid,
  ) async {
    try {
      // 1. If there's an old manager, reset their role/region
      if (oldManagerUid != null && oldManagerUid != userUid) {
        await FirebaseFirestore.instance.collection('users').doc(oldManagerUid).update({
          'role': 'user',
          'assignedGovernorateId': FieldValue.delete(),
          'assignedGovernorateName': FieldValue.delete(),
          'assignedRegionId': FieldValue.delete(),
          'assignedRegionName': FieldValue.delete(),
        });
      }

      // 2. Update the new manager's user doc
      await FirebaseFirestore.instance.collection('users').doc(userUid).update({
        'role': 'region_manager',
        'assignedGovernorateId': widget.governorateId,
        'assignedGovernorateName': widget.governorateName,
        'assignedRegionId': regionId,
        'assignedRegionName': regionName,
      });

      // 3. Update the region doc
      await FirebaseFirestore.instance
          .collection('governorates')
          .doc(widget.governorateId)
          .collection('regions')
          .doc(regionId)
          .update({
        'managerUid': userUid,
        'managerName': userName,
        'managerEmail': userEmail,
        'managerPhone': userPhone,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تعيين $userName مسؤولاً لمنطقة $regionName بنجاح',
            style: const TextStyle(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error assigning region manager: $e');
    }
  }

  Future<void> _removeManager(String regionId, String managerUid) async {
    try {
      // 1. Reset manager's user doc
      await FirebaseFirestore.instance.collection('users').doc(managerUid).update({
        'role': 'user',
        'assignedGovernorateId': FieldValue.delete(),
        'assignedGovernorateName': FieldValue.delete(),
        'assignedRegionId': FieldValue.delete(),
        'assignedRegionName': FieldValue.delete(),
      });

      // 2. Update region doc
      await FirebaseFirestore.instance
          .collection('governorates')
          .doc(widget.governorateId)
          .collection('regions')
          .doc(regionId)
          .update({
        'managerUid': FieldValue.delete(),
        'managerName': FieldValue.delete(),
        'managerEmail': FieldValue.delete(),
        'managerPhone': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تمت إزالة مسؤول المنطقة بنجاح',
            style: TextStyle(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error removing region manager: $e');
    }
  }
}
