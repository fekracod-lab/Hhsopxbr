import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/features/home/pages/home_page.dart';

class AddOrEditItemPage extends StatefulWidget {
  final String? itemId;
  final Map<String, dynamic>? initialData;
  const AddOrEditItemPage({super.key, this.itemId, this.initialData});

  @override
  State<AddOrEditItemPage> createState() => _AddOrEditItemPageState();
}

class _AddOrEditItemPageState extends State<AddOrEditItemPage> {
  String? selectedSectionId;
  String? selectedSectionLabel;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController specialtyController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController mapsUrlController = TextEditingController();

  // Governorate and Region
  String? selectedGovernorateId;
  String? selectedGovernorateName;
  String? selectedRegionId;
  String? selectedRegionName;
  List<Map<String, dynamic>> governorates = [];
  List<Map<String, dynamic>> regions = [];
  bool isLoadingGovernorates = true;
  bool isLoadingRegions = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      nameController.text = widget.initialData!['name'] ?? '';
      specialtyController.text = widget.initialData!['specialty'] ?? '';
      phoneController.text = widget.initialData!['phone'] ?? '';
      addressController.text = widget.initialData!['address'] ?? '';
      mapsUrlController.text = widget.initialData!['mapsUrl'] ?? '';
      selectedSectionId = widget.initialData!['sectionId'];
      selectedSectionLabel = widget.initialData!['sectionLabel'];
      selectedGovernorateId = widget.initialData!['governorateId'];
      selectedGovernorateName = widget.initialData!['governorateName'];
      selectedRegionId = widget.initialData!['regionId'];
      selectedRegionName = widget.initialData!['regionName'];
    }
    _fetchGovernorates();
    if (selectedGovernorateId != null) {
      _fetchRegions(selectedGovernorateId!, isInitial: true);
    }
  }

  Future<void> _fetchGovernorates() async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('governorates')
              .where('isActive', isEqualTo: true)
              .orderBy('name')
              .get();
      setState(() {
        governorates = snap.docs.map((d) => {'id': d.id, 'name': d.data()['name'] ?? ''}).toList();
        isLoadingGovernorates = false;
      });
    } catch (e) {
      debugPrint('Error fetching governorates: $e');
      setState(() => isLoadingGovernorates = false);
    }
  }

  Future<void> _fetchRegions(String govId, {bool isInitial = false}) async {
    if (!isInitial) {
      setState(() {
        isLoadingRegions = true;
        regions = [];
        selectedRegionId = null;
        selectedRegionName = null;
      });
    } else {
      setState(() => isLoadingRegions = true);
    }

    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('governorates')
              .doc(govId)
              .collection('regions')
              .where('isActive', isEqualTo: true)
              .orderBy('name')
              .get();
      setState(() {
        regions = snap.docs.map((d) => {'id': d.id, 'name': d.data()['name'] ?? ''}).toList();
        isLoadingRegions = false;
      });
    } catch (e) {
      debugPrint('Error fetching regions: $e');
      setState(() => isLoadingRegions = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    specialtyController.dispose();
    phoneController.dispose();
    addressController.dispose();
    mapsUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate() || selectedSectionId == null) return;
    final data = {
      'name': nameController.text.trim(),
      'specialty': specialtyController.text.trim(),
      'phone': phoneController.text.trim(),
      'merchantPhone': phoneController.text.trim(), // حفظ رقم التاجر بشكل صريح
      'address': addressController.text.trim(),
      'mapsUrl': mapsUrlController.text.trim(),
      'sectionId': selectedSectionId,
      'sectionLabel': selectedSectionLabel,
      'governorateId': selectedGovernorateId,
      'governorateName': selectedGovernorateName,
      'regionId': selectedRegionId,
      'regionName': selectedRegionName,
      'createdAt': FieldValue.serverTimestamp(),
    };
    final sectionRef = FirebaseFirestore.instance.collection('sections').doc(selectedSectionId);
    if (widget.itemId == null) {
      await sectionRef.collection('items').add(data);
    } else {
      await sectionRef.collection('items').doc(widget.itemId).update(data);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _deleteItem() async {
    if (widget.itemId != null && selectedSectionId != null) {
      final sectionRef = FirebaseFirestore.instance.collection('sections').doc(selectedSectionId);
      await sectionRef.collection('items').doc(widget.itemId).delete();
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(
          context,
        ).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomePage()), (route) => false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.itemId == null ? 'إضافة عنصر' : 'تعديل عنصر'),
          actions:
              widget.itemId != null
                  ? [
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: _deleteItem,
                      tooltip: 'حذف',
                    ),
                  ]
                  : null,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('sections').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    final docs = snapshot.data!.docs;
                    return DropdownButtonFormField<String>(
                      initialValue: selectedSectionId,
                      decoration: const InputDecoration(labelText: 'القسم'),
                      items:
                          docs.map((doc) {
                            final label = doc['label'] ?? '';
                            return DropdownMenuItem<String>(value: doc.id, child: Text(label));
                          }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedSectionId = val;
                          selectedSectionLabel = docs.firstWhere((d) => d.id == val)['label'];
                        });
                      },
                      validator: (val) => val == null ? 'اختر القسم' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (isLoadingGovernorates)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<String>(
                    initialValue: selectedGovernorateId,
                    decoration: const InputDecoration(labelText: 'المحافظة'),
                    items:
                        governorates.map((g) {
                          return DropdownMenuItem<String>(value: g['id'], child: Text(g['name']));
                        }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedGovernorateId = val;
                          selectedGovernorateName =
                              governorates.firstWhere((g) => g['id'] == val)['name'];
                        });
                        _fetchRegions(val);
                      }
                    },
                  ),
                const SizedBox(height: 16),
                if (selectedGovernorateId != null)
                  if (isLoadingRegions)
                    const Center(child: CircularProgressIndicator())
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selectedRegionId,
                      decoration: const InputDecoration(labelText: 'المنطقة'),
                      items:
                          regions.map((r) {
                            return DropdownMenuItem<String>(value: r['id'], child: Text(r['name']));
                          }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            selectedRegionId = val;
                            selectedRegionName = regions.firstWhere((r) => r['id'] == val)['name'];
                          });
                        }
                      },
                    ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                  validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: specialtyController,
                  decoration: const InputDecoration(labelText: 'التخصص/المهنة'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'العنوان'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: mapsUrlController,
                  decoration: const InputDecoration(labelText: 'رابط خرائط جوجل'),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: Icon(Icons.save),
                  label: Text(widget.itemId == null ? 'إضافة' : 'حفظ التعديلات'),
                  onPressed: _saveItem,
                  style: ElevatedButton.styleFrom(minimumSize: Size(120, 48)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
