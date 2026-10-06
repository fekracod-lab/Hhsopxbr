import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/features/home/pages/home_page.dart';

class EditItemPage extends StatefulWidget {
  const EditItemPage({super.key});

  @override
  State<EditItemPage> createState() => _EditItemPageState();
}

class _EditItemPageState extends State<EditItemPage> {
  String? selectedSectionId;
  String? selectedItemId;
  Map<String, dynamic>? selectedItemData;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _mapsController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _specialtyController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _mapsController.dispose();
    super.dispose();
  }

  Future<List<QueryDocumentSnapshot>> _fetchSections() async {
    final snap = await FirebaseFirestore.instance.collection('sections').get();
    return snap.docs;
  }

  Future<List<QueryDocumentSnapshot>> _fetchItems(String sectionId) async {
    final snap =
        await FirebaseFirestore.instance
            .collection('sections')
            .doc(sectionId)
            .collection('items')
            .get();
    return snap.docs;
  }

  void _loadItemData(Map<String, dynamic> data) {
    _nameController.text = data['name'] ?? '';
    _specialtyController.text = data['specialty'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _addressController.text = data['address'] ?? '';
    _mapsController.text = data['maps'] ?? '';
  }

  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate() && selectedSectionId != null && selectedItemId != null) {
      await FirebaseFirestore.instance
          .collection('sections')
          .doc(selectedSectionId)
          .collection('items')
          .doc(selectedItemId)
          .update({
            'name': _nameController.text.trim(),
            'specialty': _specialtyController.text.trim(),
            'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'maps': _mapsController.text.trim(),
          });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات بنجاح')));
    }
  }

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
        appBar: AppBar(title: const Text('تعديل عنصر')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<List<QueryDocumentSnapshot>>(
                future: _fetchSections(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: selectedSectionId,
                    decoration: const InputDecoration(labelText: 'اختر القسم'),
                    items:
                        snapshot.data!.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem(value: doc.id, child: Text(data['label'] ?? ''));
                        }).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedSectionId = val;
                        selectedItemId = null;
                        selectedItemData = null;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              if (selectedSectionId != null)
                FutureBuilder<List<QueryDocumentSnapshot>>(
                  future: _fetchItems(selectedSectionId!),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: selectedItemId,
                      decoration: const InputDecoration(labelText: 'اختر العنصر'),
                      items:
                          snapshot.data!.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return DropdownMenuItem(value: doc.id, child: Text(data['name'] ?? ''));
                          }).toList(),
                      onChanged: (val) {
                        final doc = snapshot.data!.firstWhere((d) => d.id == val);
                        setState(() {
                          selectedItemId = val;
                          selectedItemData = doc.data() as Map<String, dynamic>;
                          _loadItemData(selectedItemData!);
                        });
                      },
                    );
                  },
                ),
              const SizedBox(height: 24),
              if (selectedItemData != null)
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'اسم العنصر'),
                        validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _specialtyController,
                        decoration: const InputDecoration(labelText: 'التخصص/المهنة'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'العنوان'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _mapsController,
                        decoration: const InputDecoration(labelText: 'رابط الخريطة'),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveItem,
                          child: const Text('حفظ التعديلات'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          label: const Text('حذف العنصر'),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder:
                                  (ctx) => AlertDialog(
                                    title: const Text('تأكيد الحذف'),
                                    content: const Text(
                                      'متأكد تريد تحذف هذا العنصر؟ لا يمكن التراجع عن هذه العملية!',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('إلغاء'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: const Text('حذف'),
                                      ),
                                    ],
                                  ),
                            );
                            if (confirm == true &&
                                selectedSectionId != null &&
                                selectedItemId != null) {
                              await FirebaseFirestore.instance
                                  .collection('sections')
                                  .doc(selectedSectionId)
                                  .collection('items')
                                  .doc(selectedItemId)
                                  .delete();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(const SnackBar(content: Text('تم حذف العنصر بنجاح')));
                              setState(() {
                                selectedItemId = null;
                                selectedItemData = null;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
