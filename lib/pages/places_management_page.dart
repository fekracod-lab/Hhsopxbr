import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_place_page.dart';

class PlacesManagementPage extends StatefulWidget {
  const PlacesManagementPage({super.key});

  @override
  State<PlacesManagementPage> createState() => _PlacesManagementPageState();
}

class _PlacesManagementPageState extends State<PlacesManagementPage> {
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isAdmin = false;
  bool _isLimitedAdmin = false;
  bool _loadingRole = true;

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
  }

  Future<void> _checkAdminRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isAdmin = false;
        _isLimitedAdmin = false;
        _loadingRole = false;
      });
      return;
    }
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final role = doc.data()?['role'];
    setState(() {
      _isAdmin = role == 'admin';
      _isLimitedAdmin = role == 'limited_admin';
      _loadingRole = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_loadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAdmin && !_isLimitedAdmin) {
      return const Scaffold(body: Center(child: Text('غير مصرح لك بالدخول')));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الأماكن'),
        backgroundColor: isDark ? Colors.teal[700] : Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPlacePage()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _query = val.trim()),
              decoration: InputDecoration(
                hintText: 'ابحث عن مكان بالاسم',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('places').orderBy('name').snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Center(child: Text('ماكو أماكن حالياً مضافة.'));
                }
                final docs =
                    snap.data!.docs.where((d) {
                      if (_query.isEmpty) return true;
                      final data = d.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      return name.contains(_query.toLowerCase());
                    }).toList();
                if (docs.isEmpty) {
                  return const Center(child: Text('ماكو نتائج حالياً مطابقة'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'بدون اسم';
                    final type = data['type'] ?? 'غير محدد';
                    final lat = data['lat'];
                    final lng = data['lng'];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.withValues(alpha: 0.1),
                          child: const Icon(Icons.place, color: Colors.teal),
                        ),
                        title: Text(name),
                        subtitle: Text(
                          '$type\n$lat, $lng\nالمحافظة: ${data['governorateName'] ?? 'غير محدد'}\nالمنطقة: ${data['regionName'] ?? 'غير محدد'}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => AddPlacePage(
                                        editId: doc.id,
                                        initialData: {
                                          'name': name,
                                          'type': type,
                                          'lat': lat,
                                          'lng': lng,
                                          'governorateId': data['governorateId'],
                                          'governorateName': data['governorateName'],
                                          'regionId': data['regionId'],
                                          'regionName': data['regionName'],
                                        },
                                      ),
                                ),
                              );
                            } else if (value == 'delete') {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder:
                                    (_) => AlertDialog(
                                      title: const Text('تأكيد الحذف'),
                                      content: const Text('متأكد تريد تحذف هذا المكان؟'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('إلغاء'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text(
                                            'حذف',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                              );
                              if (ok == true) {
                                await doc.reference.delete();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(const SnackBar(content: Text('تم الحذف')));
                                }
                              }
                            }
                          },
                          itemBuilder:
                              (_) => [
                                const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('حذف', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
