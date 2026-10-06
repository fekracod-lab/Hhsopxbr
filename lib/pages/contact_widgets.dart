import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dalal_alqaim/shared/app_constants.dart';

// --- Palette requested by the user ---
const Color primaryColor = Color(0xFF26A69A);
const Color accentColor = Color(0xFF00796B);
const Color backgroundColor = Color(0xFFFFFFFF);
const Color textColor = Color(0xFF333333); // لون النص الأساسي
const Color hintColor = Color(0xFF9E9E9E); // لون النص التلميحي
const Color subTextColor = Color(0xFF757575); // لون النص الثانوي
const Color surfaceColor = Color(0xFFF8F9FA); // لون السطح

// Dark Mode Palette
const Color darkBackground = Color(0xFF07191A);
const Color darkSurface = Color(0xFF0F2323);
const Color darkCard = Color(0xFF113033);
const Color darkText = Color(0xFFE0F2F1);
const Color darkSubText = Color(0xFF80CBC4);
const Color darkHint = Color(0xFF4DB6AC);

class ContactBottomSheet extends StatelessWidget {
  const ContactBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? darkBackground : Colors.white;
    final handleColor = isDark ? Colors.grey[700] : Colors.grey[300];
    final titleColor = isDark ? darkText : primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 50,
              height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_business_rounded, color: primaryColor, size: 28),
                ),
                const SizedBox(width: 16),
                Text(
                  'إضافة نشاطك التجاري',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: titleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Flexible(child: SingleChildScrollView(child: ContactUsForm())),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class ContactUsForm extends StatefulWidget {
  const ContactUsForm({super.key});
  @override
  State<ContactUsForm> createState() => _ContactUsFormState();
}

class _ContactUsFormState extends State<ContactUsForm> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _mapsController = TextEditingController();

  // New Fields Controllers
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _workingHoursController = TextEditingController();
  final TextEditingController _socialLinkController = TextEditingController();

  String? _selectedSection;
  String? _selectedPage;
  List<String> _sections = [];
  List<String> _pages = [];

  bool _loadingSections = true;
  bool _loadingPages = false;
  bool _showDetailsForm = false;

  @override
  void initState() {
    super.initState();
    _fetchSections();
  }

  Future<void> _fetchSections() async {
    setState(() => _loadingSections = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('sections').get();
      setState(() {
        _sections =
            snap.docs
                .map((doc) => doc['label']?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .toList();
        _loadingSections = false;
      });
    } catch (e) {
      setState(() => _loadingSections = false);
    }
  }

  Future<void> _fetchPagesForSection(String sectionLabel) async {
    setState(() {
      _loadingPages = true;
      _pages = [];
      _selectedPage = null;
    });
    try {
      final sectionSnap =
          await FirebaseFirestore.instance
              .collection('sections')
              .where('label', isEqualTo: sectionLabel)
              .get();

      if (sectionSnap.docs.isNotEmpty) {
        final sectionId = sectionSnap.docs.first.id;
        final itemsSnap =
            await FirebaseFirestore.instance
                .collection('sections')
                .doc(sectionId)
                .collection('pages') // Assuming pages are subcollection
                .get();

        // Also check items directly if structure differs, keeping it generic for now
        // If your pages are stored differently, adjust here.
        // Based on previous context, pages are documents inside a subcollection or items.
        // Let's assume 'pages' collection exists inside sections based on previous files.

        setState(() {
          _pages =
              itemsSnap.docs
                  .map((doc) => (doc['name'] ?? doc['label'] ?? '').toString())
                  .where((s) => s.isNotEmpty)
                  .toList();
          _loadingPages = false;
        });
      } else {
        setState(() {
          _pages = [];
          _loadingPages = false;
        });
      }
    } catch (e) {
      setState(() {
        _pages = [];
        _loadingPages = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specialtyController.dispose();
    _phoneController.dispose();
    _mapsController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _workingHoursController.dispose();
    _socialLinkController.dispose();
    super.dispose();
  }

  void _sendToWhatsApp() async {
    if (!_formKey.currentState!.validate()) return;

    final msg = '''
*طلب إضافة تخصص جديد - ${AppConstants.appName}* 

*القسم:* ${_selectedSection ?? 'غير محدد'}
*الصفحة:* ${_selectedPage ?? 'غير محدد'}

 *الاسم:* ${_nameController.text.trim()}
 *التخصص:* ${_specialtyController.text.trim()}
 *الهاتف:* ${_phoneController.text.trim()}
 *العنوان:* ${_addressController.text.trim()}

 *نبذة:* ${_descriptionController.text.trim()}
 *أوقات العمل:* ${_workingHoursController.text.trim()}

 *رابط التواصل:* ${_socialLinkController.text.trim()}
 *الموقع (خرائط):* ${_mapsController.text.trim()}
''';

    final url = Uri.parse('https://wa.me/9647819436408?text=${Uri.encodeComponent(msg)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for web or if launch fails
        await launchUrl(url);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ما قدرنا نفتح تطبيق واتساب', style: TextStyle()),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? darkText : Colors.black87;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step 1: Selection
          if (!_showDetailsForm) ...[
            Text(
              'الخطوة 1: اختر التصنيف المناسب',
              style: TextStyle(
                fontSize: 16,
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _loadingSections
                ? const Center(child: CircularProgressIndicator(color: primaryColor))
                : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _sections.map((section) {
                        final isSelected = _selectedSection == section;
                        return ChoiceChip(
                          label: Text(
                            section,
                            style: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? darkText : Colors.black),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: primaryColor,
                          backgroundColor: isDark ? darkCard : Colors.grey[100],
                          onSelected: (selected) {
                            setState(() {
                              _selectedSection = selected ? section : null;
                              if (selected) _fetchPagesForSection(section);
                            });
                          },
                        );
                      }).toList(),
                ),

            if (_selectedSection != null && _pages.isNotEmpty) ...[
              const SizedBox(height: 16),
              _loadingPages
                  ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2),
                    ),
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الصفحة الفرعية:',
                        style: TextStyle(
                          color: isDark ? darkSubText : subTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _pages.map((page) {
                              final isSelected = _selectedPage == page;
                              return ChoiceChip(
                                label: Text(
                                  page,
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : (isDark ? darkText : Colors.black),
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: accentColor,
                                backgroundColor: isDark ? darkCard : Colors.grey[100],
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedPage = selected ? page : null;
                                  });
                                },
                              );
                            }).toList(),
                      ),
                    ],
                  ),
            ],

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed:
                  _selectedSection != null ? () => setState(() => _showDetailsForm = true) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'التالي: إضافة التفاصيل',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ]
          // Step 2: Details Form
          else ...[
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _showDetailsForm = false),
                  icon: Icon(Icons.arrow_back, color: isDark ? darkSubText : Colors.grey),
                ),
                Text(
                  'الخطوة 2: تفاصيل النشاط',
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // حقول أساسية
            _buildModernTextField(
              controller: _nameController,
              label: 'اسم النشاط / الشخص',
              icon: Icons.business,
              isDark: isDark,
              validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildModernTextField(
                    controller: _specialtyController,
                    label: 'التخصص',
                    icon: Icons.work_outline,
                    isDark: isDark,
                    validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModernTextField(
                    controller: _phoneController,
                    label: 'رقم الهاتف',
                    icon: Icons.phone,
                    isDark: isDark,
                    keyboardType: TextInputType.phone,
                    validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildModernTextField(
              controller: _addressController,
              label: 'العنوان',
              icon: Icons.location_on_outlined,
              isDark: isDark,
              validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
            ),

            // حقول إضافية جديدة
            const SizedBox(height: 12),
            _buildModernTextField(
              controller: _descriptionController,
              label: 'نبذة / وصف النشاط (اختياري)',
              icon: Icons.description_outlined,
              isDark: isDark,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            _buildModernTextField(
              controller: _workingHoursController,
              label: 'أوقات العمل (مثال: 9 ص - 10 م)',
              icon: Icons.access_time,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildModernTextField(
              controller: _socialLinkController,
              label: 'رابط فيسبوك / انستغرام (اختياري)',
              icon: Icons.link,
              isDark: isDark,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            _buildModernTextField(
              controller: _mapsController,
              label: 'رابط خرائط جوجل (اختياري)',
              icon: Icons.map_outlined,
              isDark: isDark,
              keyboardType: TextInputType.url,
            ),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _sendToWhatsApp,
              icon: const Icon(Icons.send, color: Colors.white),
              label: const Text(
                'إرسال الطلب عبر واتساب',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366), // WhatsApp Color
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final bgColor = isDark ? darkCard : surfaceColor;
    final txtColor = isDark ? darkText : textColor;
    final hintCol = isDark ? darkHint : hintColor;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: txtColor),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: hintCol, fontSize: 14),
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        filled: true,
        fillColor: bgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
