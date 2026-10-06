import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:dalal_alqaim/core/taxi/data/repositories/taxi_captain_repository.dart';

const Color _primary = Color(0xFF26A69A);
const Color _surfaceColor = Color(0xFFF8F9FA);
const Color _darkBg = Color(0xFF07191A);
const Color _darkSurface = Color(0xFF0F2323);
const Color _darkCard = Color(0xFF113033);
const Color _darkText = Color(0xFFE0F2F1);
const Color _darkSub = Color(0xFF80CBC4);

class DriversManagementPage extends StatefulWidget {
  const DriversManagementPage({super.key});

  @override
  State<DriversManagementPage> createState() => _DriversManagementPageState();
}

class _DriversManagementPageState extends State<DriversManagementPage> {
  final TaxiCaptainRepository _taxiCaptainRepository = TaxiCaptainRepository();
  String _q = '';
  String _statusFilter = 'all'; 

  final List<String> _roles = ['all', 'active', 'pending', 'banned', 'removed'];
  final Map<String, List<String>> _carMakesAndModels = {
    'تويوتا (Toyota)': ['Corolla', 'Camry', 'Avalon', 'Land Cruiser', 'Hilux', 'RAV4', 'Prado'],
    'هيونداي (Hyundai)': ['Elantra', 'Sonata', 'Accent', 'Tucson', 'Santa Fe', 'Kona'],
    'كيا (Kia)': ['Sportage', 'Sorento', 'Optima', 'Cerato', 'Rio', 'Picanto'],
    'نيسان (Nissan)': ['Altima', 'Sentra', 'Sunny', 'Patrol', 'Pathfinder', 'X-Terra'],
    'ام جي (MG)': ['MG5', 'MG6', 'ZS', 'RX5', 'RX8'],
    'شيري (Chery)': ['Tiggo 7', 'Tiggo 8', 'Arrizo 6', 'Tiggo 4'],
    'هوندا (Honda)': ['Civic', 'Accord', 'CR-V'],
    'مازدا (Mazda)': ['Mazda 3', 'Mazda 6', 'CX-5'],
    'فورد (Ford)': ['Taurus', 'Explorer', 'Expedition', 'Edge'],
    'شيفروليه (Chevrolet)': ['Malibu', 'Tahoe', 'Silverado', 'Cruze'],
    'بي ام دبليو (BMW)': ['Series 3', 'Series 5', 'Series 7', 'X5'],
    'مرسيدس (Mercedes)': ['C-Class', 'E-Class', 'S-Class', 'GLE'],
    'أخرى (Other)': ['موديل آخر'],
  };
  final Map<String, String> _rolesLabels = {
    'all': 'الكل',
    'active': 'نشط',
    'pending': 'قيد الانتظار',
    'banned': 'محظور',
    'removed': 'معطل/مزيل',
  };

  Stream<QuerySnapshot<Map<String, dynamic>>> _driversStream() {
    return _taxiCaptainRepository.streamTaxiCaptains();
  }

  Future<void> _setDriverStatus({
    required String uid,
    required String newStatus, 
  }) async {
    try {
      await _taxiCaptainRepository.updateTaxiCaptainStatus(uid: uid, newStatus: newStatus);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'تم تحديث حالة كابتن التاكسي بنجاح',
            style: TextStyle(),
          ),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل التحديث: $e', style: const TextStyle()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }
  }

  Future<void> _deleteDriverPermanently(String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تأكيد الحذف النهائي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          content: const Text('متأكد تريد تحذف هذا السائق نهائياً من النظام؟ سيتم حذف بيانات السائق وحسابه بالكامل ولا يمكن التراجع عن هذا الإجراء.', 
            style: TextStyle(fontSize: 14)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف نهائي', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    batch.delete(db.collection('users').doc(uid));
    batch.delete(db.collection('drivers').doc(uid));

    try {
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف السائق وحسابه نهائياً', style: TextStyle()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الحذف: $e', style: const TextStyle()), backgroundColor: Colors.red, behavior: SnackBarBehavior.fixed),
      );
    }
  }

  Future<void> _callDriver(String phone) async {
      String p = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      final url = 'tel:$p';
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إجراء المكالمة'), behavior: SnackBarBehavior.fixed));
      }
  }

  Future<void> _updateDriverData({
    required String uid,
    required Map<String, dynamic> newData,
  }) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    final userRef = db.collection('users').doc(uid);
    final driverRef = db.collection('drivers').doc(uid);

    batch.update(userRef, {...newData, 'updatedAt': FieldValue.serverTimestamp()});
    batch.update(driverRef, {...newData, 'updatedAt': FieldValue.serverTimestamp()});

    try {
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث البيانات بنجاح', style: TextStyle()),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في التحديث: $e', style: const TextStyle()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }
  }

  void _showEditDriverDialog(String uid, Map<String, dynamic> data) {
    final nameC = TextEditingController(text: (data['fullName'] ?? data['name'] ?? '').toString());
    final phoneC = TextEditingController(text: (data['phone'] ?? '').toString());
    final carNumberC = TextEditingController(text: (data['carNumber'] ?? '').toString());
    final carColorC = TextEditingController(text: (data['carColor'] ?? '').toString());

    String? selectedMake = data['carType'];
    String? selectedModel = data['carModel'];
    String? selectedYear = data['carYear'];
    String? selectedGovId = data['governorateId'];
    String? selectedGovName = data['governorateName'] ?? data['governorate'];
    String? selectedRegId = data['regionId'];
    String? selectedRegName = data['regionName'];

    List<Map<String, dynamic>> dialogRegions = [];
    bool isRegionsLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: isDark ? _darkCard : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit_rounded, color: _primary),
                    const SizedBox(width: 12),
                    const Text(
                      'تعديل معلومات السائق',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      _buildEditField(nameC, 'الاسم الكامل', Icons.person),
                      const SizedBox(height: 16),
                      _buildEditField(phoneC, 'رقم الهاتف', Icons.phone, keyboard: TextInputType.phone),
                      const SizedBox(height: 16),
                      
                      const Divider(height: 32),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text('معلومات المركبة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _primary)),
                      ),
                      const SizedBox(height: 12),
                      
                      _buildEditField(carNumberC, 'رقم السيارة', Icons.confirmation_number),
                      const SizedBox(height: 16),
                      
                      _buildEditDropdown(
                        label: 'ماركة السيارة',
                        icon: Icons.directions_car,
                        value: selectedMake,
                        items: _carMakesAndModels.keys.toList(),
                        onChanged: (v) {
                          setDialogState(() {
                            selectedMake = v;
                            selectedModel = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      _buildEditDropdown(
                        label: 'موديل السيارة',
                        icon: Icons.model_training,
                        value: selectedModel,
                        items: selectedMake != null ? _carMakesAndModels[selectedMake!]! : [],
                        onChanged: selectedMake == null ? null : (v) => setDialogState(() => selectedModel = v),
                        hint: selectedMake == null ? 'اختر الماركة أولاً' : 'اختر الموديل',
                      ),
                      const SizedBox(height: 16),
                      
                      _buildEditDropdown(
                        label: 'سنة الصنع',
                        icon: Icons.calendar_today,
                        value: selectedYear,
                        items: List.generate(
                          DateTime.now().year - 1999,
                          (index) => (DateTime.now().year - index + 1).toString(),
                        ),
                        onChanged: (v) => setDialogState(() => selectedYear = v),
                      ),
                      const SizedBox(height: 16),
                      
                      _buildEditField(carColorC, 'اللون', Icons.palette),
                      
                      const Divider(height: 32),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text('موقع العمل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _primary)),
                      ),
                      const SizedBox(height: 12),
                      
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('governorates').where('isActive', isEqualTo: true).snapshots(),
                        builder: (context, snapshot) {
                          List<String> items = [];
                          final docs = snapshot.data?.docs ?? [];
                          items = docs.map((d) => d['name'].toString()).toList();
                          
                          return _buildEditDropdown(
                            label: 'المحافظة',
                            icon: Icons.map,
                            value: selectedGovName,
                            items: items,
                            onChanged: (v) async {
                              if (v != null) {
                                final doc = docs.firstWhere((d) => d['name'] == v);
                                setDialogState(() {
                                  selectedGovName = v;
                                  selectedGovId = doc.id;
                                  selectedRegId = null;
                                  selectedRegName = null;
                                  isRegionsLoading = true;
                                });
                                
                                // Fetch regions
                                try {
                                  final rSnap = await FirebaseFirestore.instance
                                      .collection('governorates')
                                      .doc(doc.id)
                                      .collection('regions')
                                      .where('isActive', isEqualTo: true)
                                      .get();
                                  setDialogState(() {
                                    dialogRegions = rSnap.docs.map((d) => {'id': d.id, 'name': d['name']}).toList();
                                    isRegionsLoading = false;
                                  });
                                } catch (_) {
                                  setDialogState(() => isRegionsLoading = false);
                                }
                              }
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      _buildEditDropdown(
                        label: 'المنطقة',
                        icon: Icons.location_city,
                        value: selectedRegName,
                        items: dialogRegions.map((r) => r['name'].toString()).toList(),
                        onChanged: isRegionsLoading ? null : (v) {
                          if (v != null) {
                            final reg = dialogRegions.firstWhere((r) => r['name'] == v);
                            setDialogState(() {
                              selectedRegName = v;
                              selectedRegId = reg['id'];
                            });
                          }
                        },
                        hint: isRegionsLoading ? 'جاري التحميل...' : (selectedGovName == null ? 'اختر المحافظة أولاً' : 'اختر المنطقة'),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _updateDriverData(
                            uid: uid,
                            newData: {
                              'fullName': nameC.text.trim(),
                              'phone': phoneC.text.trim(),
                              'carNumber': carNumberC.text.trim(),
                              'carType': selectedMake,
                              'carModel': selectedModel,
                              'carYear': selectedYear,
                              'carColor': carColorC.text.trim(),
                              'governorateId': selectedGovId,
                              'governorateName': selectedGovName,
                              'regionId': selectedRegId,
                              'regionName': selectedRegName,
                            },
                          );
                        },
                        child: const Text('حفظ التعديلات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: _primary, size: 20),
            filled: true,
            fillColor: Colors.grey.withValues(alpha: 0.1),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary)),
          ),
        ),
      ],
    );
  }

  Widget _buildEditDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
    String? hint,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: onChanged,
          dropdownColor: isDark ? _darkCard : Colors.white,
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
            prefixIcon: Icon(icon, color: _primary, size: 20),
            filled: true,
            fillColor: Colors.grey.withValues(alpha: 0.1),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary)),
          ),
        ),
      ],
    );
  }

  Future<void> _whatsappDriver(String phone) async {
      String p = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (!p.startsWith('964')) p = '964$p';
      final url = 'whatsapp://send?phone=+$p';
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما قدرنا نفتح واتساب. يرجى التأكد من تثبيته.'), behavior: SnackBarBehavior.fixed));
      }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilterSort(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final q = _q.trim().toLowerCase();
    final filter = _statusFilter;

    final filtered = docs.where((d) {
      final data = d.data();
      final name = (data['fullName'] ?? data['name'] ?? '').toString().toLowerCase();
      final phone = (data['phone'] ?? '').toString().toLowerCase();
      final car = (data['carNumber'] ?? '').toString().toLowerCase();
      String st = (data['status'] ?? (data['banned'] == true ? 'banned' : 'active')).toString().toLowerCase();
      if (st == 'approved') st = 'active';

      final matchesQuery = q.isEmpty || name.contains(q) || phone.contains(q) || car.contains(q);
      final matchesStatus = filter == 'all' || st == filter;

      return matchesQuery && matchesStatus;
    }).toList();

    const order = {'pending': 0, 'active': 1, 'banned': 2, 'removed': 3};
    filtered.sort((a, b) {
      final sa = (a.data()['status'] ?? 'pending').toString().toLowerCase();
      final sb = (b.data()['status'] ?? 'pending').toString().toLowerCase();
      final ra = order[sa] ?? 99;
      final rb = order[sb] ?? 99;
      if (ra != rb) return ra.compareTo(rb);

      final na = (a.data()['fullName'] ?? a.data()['name'] ?? '').toString();
      final nb = (b.data()['fullName'] ?? b.data()['name'] ?? '').toString();
      return na.compareTo(nb);
    });

    return filtered;
  }

  void _showDriverTrips(String driverUid, String driverName, bool isDark) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? _darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('ride_requests')
                    .where('driverId', isEqualTo: driverUid)
                    .orderBy('createdAt', descending: true)
                    .limit(100)
                    .get(),
                builder: (context, snap) {
                  final docs = snap.data?.docs ?? [];
                  double total = 0;
                  int count = 0;
                  for (var d in docs) {
                    final data = d.data() as Map<String, dynamic>;
                    final status = (data['status'] ?? '').toString();
                    if (status == 'completed' || status == 'finished' || status == 'paid') {
                      final price = (data['price'] is num) ? (data['price'] as num).toDouble() : double.tryParse(data['price']?.toString() ?? '0') ?? 0.0;
                      total += price;
                      count++;
                    }
                  }

                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('تحليلات رحلات: $driverName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          if (snap.connectionState == ConnectionState.done && docs.isNotEmpty)
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy_all_rounded, color: Colors.blue),
                                  onPressed: () {
                                    String summary = "تقرير رحلات السائق: $driverName\n"
                                        "عدد الرحلات المكتملة: $count\n"
                                        "إجمالي الأرباح: ${total.toStringAsFixed(0)} د.ع\n"
                                        "تطبيق مدار";
                                    Clipboard.setData(ClipboardData(text: summary));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('تم نسخ الملخص بنجاح', style: TextStyle()), backgroundColor: Colors.blue, behavior: SnackBarBehavior.fixed),
                                    );
                                  },
                                  tooltip: 'نسخ الملخص',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                                  onPressed: () => _printDriverReport(driverName, total, count, docs),
                                  tooltip: 'تصدير PDF',
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (snap.connectionState == ConnectionState.waiting)
                        const Center(child: CircularProgressIndicator())
                      else if (docs.isEmpty)
                        const Center(child: Text('ماكو رحلات حالياً مسجلة', style: TextStyle()))
                      else
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [_primary, Color(0xFF00796B)]),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _summaryMiniItem('الرحلات', count.toString(), Icons.route),
                                    _summaryMiniItem('إجمالي الأرباح', total.toStringAsFixed(0), Icons.payments_outlined),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Align(
                                  alignment: Alignment.centerRight,
                                  child: Text('سجل الرحلات الأخيرة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: docs.length,
                                  itemBuilder: (context, index) {
                                    final d = docs[index];
                                    final data = d.data() as Map<String, dynamic>;
                                    final price = (data['price'] is num) ? (data['price'] as num).toDouble() : double.tryParse(data['price']?.toString() ?? '0') ?? 0.0;
                                    final status = (data['status'] ?? '').toString();
                                    final isCompleted = (status == 'completed' || status == 'finished' || status == 'paid');

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: isDark ? _darkSurface : Colors.grey[50],
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!)
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('رحلة #${d.id.substring(0, 6)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text(
                                                (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate().toString().split('.')[0] : '',
                                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                              )
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text('${price.toStringAsFixed(0)} د.ع', style: TextStyle(fontWeight: FontWeight.bold, color: _primary)),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                    color: isCompleted ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8)
                                                ),
                                                child: Text(status, style: TextStyle(fontSize: 10, color: isCompleted ? Colors.green : Colors.orange)),
                                              )
                                            ],
                                          )
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }



  void _showDriverDetailsSheet(BuildContext context, String uid, Map<String, dynamic> data, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? _darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Profile Picture Head
                      Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                              CircleAvatar(
                                  radius: 50,
                                  backgroundColor: _primary.withValues(alpha:0.1),
                                  backgroundImage: data['photoUrl'] != null && data['photoUrl'].toString().isNotEmpty 
                                      ? NetworkImage(data['photoUrl']) 
                                      : null,
                                  child: data['photoUrl'] == null || data['photoUrl'].toString().isEmpty
                                      ? const Icon(Icons.person, size: 50, color: _primary)
                                      : null,
                              ),
                              if ((data['status'] ?? '') == 'active')
                                  Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                      child: const Icon(Icons.verified, color: Colors.white, size: 16),
                                  )
                          ],
                      ),
                      const SizedBox(height: 12),
                      Text(data['fullName'] ?? data['name'] ?? 'بدون اسم', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(data['email'] ?? '', style: TextStyle(fontSize: 13, color: isDark ? _darkSub : Colors.grey[600])),
                      const SizedBox(height: 24),
                      
                      // Full Information Grid
                      Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: isDark ? _darkSurface : Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!)
                          ),
                          child: Column(
                              children: [
                                  _infoRow(Icons.phone_outlined, 'الهاتف', data['phone'] ?? '-'),
                                  const Divider(),
                                  FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                                    builder: (context, snapshot) {
                                      String email = data['email'] ?? 'غير متوفر';
                                      if (snapshot.hasData && snapshot.data!.exists) {
                                        final userData = snapshot.data!.data() as Map<String, dynamic>?;
                                        if (userData != null && userData.containsKey('email')) {
                                          email = userData['email']?.toString() ?? email;
                                        }
                                      }
                                      return Column(
                                        children: [
                                          _infoRow(
                                            Icons.email_outlined, 
                                            'البريد الإلكتروني', 
                                            email,
                                            trailing: IconButton(
                                              icon: const Icon(Icons.copy_rounded, size: 18, color: _primary),
                                              onPressed: () {
                                                Clipboard.setData(ClipboardData(text: email));
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('تم نسخ البريد الإلكتروني'), behavior: SnackBarBehavior.fixed)
                                                );
                                              },
                                            ),
                                          ),
                                          const Divider(),
                                        ],
                                      );
                                    },
                                  ),
                                  const Divider(),
                                  _infoRow(Icons.directions_car_outlined, 'الماركة والموديل', '${data['carType'] ?? '-'} ${data['carModel'] ?? ''}'),
                                  const Divider(),
                                  _infoRow(Icons.calendar_today_outlined, 'سنة الصنع', data['carYear'] ?? '-'),
                                  const Divider(),
                                  _infoRow(Icons.confirmation_number_outlined, 'رقم السيارة', data['carNumber'] ?? '-'),
                                  const Divider(),
                                  _infoRow(Icons.palette_outlined, 'اللون', data['carColor'] ?? '-'),
                                  const Divider(),
                                  _infoRow(Icons.map_outlined, 'المحافظة', data['governorateName'] ?? data['governorate'] ?? '-'),
                                  const Divider(),
                                  _infoRow(Icons.location_city_outlined, 'المنطقة', data['regionName'] ?? '-'),
                                  const Divider(),
                                  _infoRow(Icons.lock_outlined, 'كلمة المرور', '********'),
                              ],
                          ),
                      ),
                      const SizedBox(height: 24),
                      const Align(alignment: Alignment.centerRight, child: Text('إجراءات لوحة التحكم', style: TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(height: 12),
                      Wrap(
                          spacing: 12, runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                              _actionCard(Icons.local_taxi_outlined, 'تحليلات\nالرحلات', Colors.blue, () { Navigator.pop(ctx); _showDriverTrips(uid, data['fullName'] ?? 'السائق', isDark); }, isDark),
                              _actionCard(Icons.edit_note_outlined, 'تعديل\nالمعلومات', _primary, () { Navigator.pop(ctx); _showEditDriverDialog(uid, data); }, isDark),
                              _actionCard(Icons.lock_reset_rounded, 'كلمة\nالمرور', Colors.deepPurple, () { Navigator.pop(ctx); _showDriverPasswordDialog(uid, data); }, isDark),
                              if ((data['status'] ?? '') != 'active' && (data['status'] ?? '') != 'banned' && (data['status'] ?? '') != 'removed')
                                  _actionCard(Icons.check_circle_outline, 'قبول وتفعيل\nالحساب', Colors.green, () { Navigator.pop(ctx); _setDriverStatus(uid: uid, newStatus: 'active'); }, isDark),
                              if ((data['status'] ?? '') == 'active')
                                  _actionCard(Icons.block, 'حظر\nالسائق', Colors.orange, () { Navigator.pop(ctx); _setDriverStatus(uid: uid, newStatus: 'banned'); }, isDark),
                              if ((data['status'] ?? '') == 'banned' || (data['status'] ?? '') == 'removed')
                                  _actionCard(Icons.refresh, 'استعادة\nنشاط السائق', Colors.green, () { Navigator.pop(ctx); _setDriverStatus(uid: uid, newStatus: 'active'); }, isDark),
                              
                              _actionCard(Icons.delete_forever_outlined, 'تعطيل\nوإزالة', Colors.red, () { Navigator.pop(ctx); _setDriverStatus(uid: uid, newStatus: 'removed'); }, isDark),
                              _actionCard(Icons.delete_outline, 'حذف\nنهائي', Colors.black, () { Navigator.pop(ctx); _deleteDriverPermanently(uid); }, isDark),
                          ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showDriverPasswordDialog(String uid, Map<String, dynamic> data) {
    final passwordC = TextEditingController();
    bool isLoading = false;
    bool obscure = true;


    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: isDark ? _darkCard : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple.withValues(alpha: 0.15), Colors.deepPurple.withValues(alpha: 0.05)],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_reset_rounded, color: Colors.deepPurple, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'إدارة كلمة المرور',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            data['fullName'] ?? data['name'] ?? 'السائق',
                            style: TextStyle(fontSize: 12, color: isDark ? _darkSub : Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // عرض كلمة المرور الحالية
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.key_rounded, size: 18, color: Colors.amber[700]),
                                const SizedBox(width: 8),
                                Text(
                                  'كلمة المرور الحالية',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber[700]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    'محمية بموجب سياسة خصوصية أبل',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                        const SizedBox(height: 16),

                        // سجل كلمات المرور القديمة
                        if (data['passwordHistory'] != null && (data['passwordHistory'] as List).isNotEmpty)
                          Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: Row(
                                children: [
                                  Icon(Icons.history_rounded, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'سجل كلمات المرور السابقة',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              children: [
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 150),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: (data['passwordHistory'] as List).length,
                                    itemBuilder: (context, i) {
                                      final hist = (data['passwordHistory'] as List).reversed.toList()[i];
                                      return Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        margin: const EdgeInsets.only(bottom: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.03),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            SelectableText(
                                              hist['password']?.toString() ?? '',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                                            ),
                                            Text(
                                              () {
                                                try {
                                                  final val = hist['changedAt'];
                                                  if (val is Timestamp) {
                                                    return intl.DateFormat('yyyy/MM/dd').format(val.toDate());
                                                  } else if (val is String) {
                                                    return intl.DateFormat('yyyy/MM/dd').format(DateTime.parse(val));
                                                  }
                                                  return val?.toString() ?? '';
                                                } catch (_) {
                                                  return hist['changedAt']?.toString() ?? '';
                                                }
                                              }(),
                                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),

                      // البريد الإلكتروني للمرجع
                      if (data['email'] != null && data['email'].toString().isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  data['email'].toString(),
                                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // حقل كلمة المرور الجديدة
                      const Text(
                        'كلمة مرور جديدة',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: passwordC,
                        obscureText: obscure,
                        style: const TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'أدخل كلمة المرور الجديدة (6 أحرف على الأقل)',
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                          prefixIcon: const Icon(Icons.lock_outline, color: _primary, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey, size: 20),
                            onPressed: () => setDialogState(() => obscure = !obscure),
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _primary)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: isLoading ? null : () => Navigator.pop(ctx),
                        child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: isLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_rounded, size: 20, color: Colors.white),
                        label: Text(
                          isLoading ? 'جاري التغيير...' : 'تغيير كلمة المرور',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: isLoading ? null : () async {
                          final newPass = passwordC.text.trim();
                          if (newPass.isEmpty || newPass.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل', style: TextStyle()),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.fixed,
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isLoading = true);
                          try {
                            // تغيير كلمة مرور الكابتن عبر Cloud Function
                            final callable = FirebaseFunctions.instance.httpsCallable('adminChangePassword');
                            await callable.call({'uid': uid, 'newPassword': newPass});

                            if (!context.mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تغيير كلمة مرور السائق بنجاح!', style: TextStyle()),
                                backgroundColor: _primary,
                                behavior: SnackBarBehavior.fixed,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isLoading = false);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('فشل تغيير كلمة المرور: $e', style: const TextStyle()),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.fixed,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Widget? trailing}) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
              children: [
                  Icon(icon, size: 20, color: _primary),
                  const SizedBox(width: 12),
                  Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const Spacer(),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing,
                  ],
              ],
          ),
      );
  }

  Widget _actionCard(IconData icon, String label, Color color, VoidCallback onTap, bool isDark) {
      return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
              width: 100,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                  color: color.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha:0.3))
              ),
              child: Column(
                  children: [
                      Icon(icon, color: color, size: 28),
                      const SizedBox(height: 8),
                      Text(label, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
              ),
          ),
      );
  }




  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentBg = isDark ? _darkBg : _surfaceColor;
    final currentCard = isDark ? _darkCard : Colors.white;
    final currentText = isDark ? _darkText : Colors.black87;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: currentBg,
        appBar: AppBar(
          backgroundColor: isDark ? _darkSurface : Colors.white,
          elevation: 0,
          title: Text('إدارة السائقين', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          centerTitle: true,
          iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _driversStream(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _primary));
            }

            final docs = snap.data?.docs ?? [];
            final filtered = _applyFilterSort(docs);

            int activeCount = docs.where((d) => (d.data()['status'] ?? '') == 'active').length;
            int pendingCount = docs.where((d) => (d.data()['status'] ?? '') == 'pending').length;

            return Column(
              children: [
                // Head Overview Dashboard
                Container(
                    color: isDark ? _darkSurface : Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                        children: [
                            Row(
                                children: [
                                    Expanded(
                                        child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(color: Colors.green.withValues(alpha:0.1), borderRadius: BorderRadius.circular(12)),
                                            child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                    const Text('سائق نشط', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                                    Text('$activeCount', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                                                ],
                                            ),
                                        )
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(color: Colors.amber.withValues(alpha:0.15), borderRadius: BorderRadius.circular(12)),
                                            child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                    Text('قيد الانتظار', style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.bold)),
                                                    Text('$pendingCount', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
                                                ],
                                            ),
                                        )
                                    ),
                                ],
                            ),
                            const SizedBox(height: 16),
                            // Search and filter
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? _darkBg : Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: TextField(
                                onChanged: (v) => setState(() => _q = v),
                                style: TextStyle(color: currentText),
                                decoration: const InputDecoration(
                                  hintText: 'ابحث عن سائق، رقم سيارة...',
                                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                    children: _roles.map((role) {
                                        final isSelected = _statusFilter == role;
                                        return Padding(
                                            padding: const EdgeInsets.only(left: 8),
                                            child: ChoiceChip(
                                                label: Text(_rolesLabels[role]!, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                                selected: isSelected,
                                                onSelected: (v) => setState(() => _statusFilter = role),
                                                selectedColor: _primary.withValues(alpha:0.2),
                                                backgroundColor: isDark ? _darkBg : Colors.grey[100],
                                                labelStyle: TextStyle(color: isSelected ? _primary : Colors.grey),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? _primary.withValues(alpha:0.5) : Colors.transparent)),
                                            ),
                                        );
                                    }).toList(),
                                ),
                            )
                        ],
                    ),
                ),
                Expanded(
                    child: filtered.isEmpty 
                    ? const Center(child: Text('لا يوجد سائقين مطابقين للبحث', style: TextStyle()))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                            final d = filtered[i];
                            final data = d.data();
                            final uid = d.id;
                            final name = (data['fullName'] ?? data['name'] ?? 'بدون اسم').toString();
                            final phone = (data['phone'] ?? '').toString();
                            final carNumber = (data['carNumber'] ?? '-').toString();
                            final carType = (data['carType'] ?? '-').toString();
                            String status = (data['status'] ?? (data['banned'] == true ? 'banned' : 'active')).toString();
                            if (status == 'approved') status = 'active';
                            final photoUrl = data['photoUrl']?.toString();

                            Color stColor;
                            String stLabel;
                            if (status == 'active') { stColor = Colors.green; stLabel = 'نشط'; }
                            else if (status == 'banned') { stColor = Colors.orange; stLabel = 'محظور'; }
                            else if (status == 'removed') { stColor = Colors.red; stLabel = 'معطل'; }
                            else if (status == 'pending' || status.isEmpty) { stColor = Colors.amber.shade800; stLabel = 'قيد المراجعة'; }
                            else { stColor = Colors.grey; stLabel = 'غير معروف'; }

                            return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                    color: currentCard,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius: 10, offset: const Offset(0, 4))]
                                ),
                                child: InkWell(
                                    onTap: () => _showDriverDetailsSheet(context, uid, data, isDark),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                            children: [
                                                Row(
                                                    children: [
                                                        CircleAvatar(
                                                            radius: 30,
                                                            backgroundColor: _primary.withValues(alpha:0.1),
                                                            backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                                            child: photoUrl == null || photoUrl.isEmpty ? const Icon(Icons.person, color: _primary) : null,
                                                        ),
                                                        const SizedBox(width: 12),
                                                        Expanded(
                                                            child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                    Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: currentText)),
                                                                    const SizedBox(height: 4),
                                                                    Row(
                                                                        children: [
                                                                            Icon(Icons.directions_car_outlined, size: 14, color: Colors.grey[500]),
                                                                            const SizedBox(width: 4),
                                                                            Text('$carType • $carNumber', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                                                        ],
                                                                    ),
                                                                ],
                                                            )
                                                        ),
                                                        Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                            decoration: BoxDecoration(color: stColor.withValues(alpha:0.1), borderRadius: BorderRadius.circular(12)),
                                                            child: Text(stLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: stColor)),
                                                        )
                                                    ],
                                                ),
                                                if (phone.isNotEmpty) ...[
                                                    const SizedBox(height: 12),
                                                    Row(
                                                        children: [
                                                            Expanded(
                                                                child: OutlinedButton.icon(
                                                                    onPressed: () => _callDriver(phone),
                                                                    icon: const Icon(Icons.call, size: 18),
                                                                    label: const Text('اتصال', style: TextStyle()),
                                                                    style: OutlinedButton.styleFrom(
                                                                        foregroundColor: _primary,
                                                                        side: BorderSide(color: _primary.withValues(alpha:0.3)),
                                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                                                    ),
                                                                )
                                                            ),
                                                            const SizedBox(width: 12),
                                                            Expanded(
                                                                child: ElevatedButton.icon(
                                                                    onPressed: () => _whatsappDriver(phone),
                                                                    icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.white),
                                                                    label: const Text('واتساب', style: TextStyle(color: Colors.white)),
                                                                    style: ElevatedButton.styleFrom(
                                                                        backgroundColor: const Color(0xFF25D366),
                                                                        elevation: 0,
                                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                                                    ),
                                                                )
                                                            ),
                                                        ],
                                                    )
                                                ]
                                            ],
                                        ),
                                    )
                                ),
                            );
                        }
                    )
                )
              ],
            );
          },
        ),
      ),
    );
  }
  Widget _summaryMiniItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Future<void> _printDriverReport(String driverName, double total, int count, List<QueryDocumentSnapshot> docs) async {
    try {
      final fontData = await rootBundle.load('Cairo-Regular.ttf');
      final ttf = pw.Font.ttf(fontData);

      final pdf = pw.Document();
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: ttf, bold: ttf),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('تقرير رحلات وأرباح السائق', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.teal700)),
                        pw.Text('السائق: $driverName', style: const pw.TextStyle(fontSize: 16)),
                        pw.Text('تاريخ التقرير: ${intl.DateFormat('yyyy-MM-dd').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('مدار', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.orange)),
                        pw.Text('نظام تطبيقات مدار', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Stats Cards in PDF
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
                    child: pw.Column(
                      children: [
                        pw.Text('إجمالي الرحلات', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('$count', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
                    child: pw.Column(
                      children: [
                        pw.Text('صافي الأرباح', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('${total.toStringAsFixed(0)} د.ع', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal50),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: ['ت', 'رقم الرحلة', 'التاريخ والوقت', 'المبلغ', 'الحالة'],
                data: List<List<dynamic>>.generate(docs.length, (index) {
                  final d = docs[index];
                  final data = d.data() as Map<String, dynamic>;
                  final price = (data['price'] is num) ? (data['price'] as num).toStringAsFixed(0) : data['price']?.toString() ?? '0';
                  final status = data['status']?.toString() ?? '-';
                  final date = (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate().toString().split('.')[0] : '-';
                  return [
                    index + 1,
                    d.id.substring(0, 6),
                    date,
                    '$price د.ع',
                    status,
                  ];
                }),
              ),
            ];
          },
          footer: (pw.Context context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          ),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'report_${driverName}_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      debugPrint('PDF Error: $e');
    }
  }
}
