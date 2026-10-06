import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

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

class EmergencyServicesPage extends StatefulWidget {
  const EmergencyServicesPage({super.key});

  @override
  State<EmergencyServicesPage> createState() => _EmergencyServicesPageState();
}

class _EmergencyServicesPageState extends State<EmergencyServicesPage> {
  String search = '';
  String selectedCategory = 'الكل';
  final List<String> categories = [
    'الكل',
    'طوارئ طبية',
    'أمن وسلامة',
    'خدمات حكومية',
    'مكافحة الجرائم',
  ];

  // Emergency Services Data
  final List<Map<String, dynamic>> emergencyServices = [
    {
      'name': 'الإسعاف',
      'phone': '122',
      'icon': Icons.local_hospital,
      'color': Colors.red,
      'category': 'طوارئ طبية',
      'description': 'خدمات الإسعاف والطوارئ الطبية',
      'isEmergency': true,
      'priority': 1,
    },
    {
      'name': 'الدفاع المدني',
      'phone': '115',
      'icon': Icons.fire_truck,
      'color': Colors.orange,
      'category': 'أمن وسلامة',
      'description': 'إطفاء الحرائق والإنقاذ',
      'isEmergency': true,
      'priority': 2,
    },
    {
      'name': 'شرطة النجدة',
      'phone': '104',
      'icon': Icons.local_police,
      'color': Colors.blue,
      'category': 'أمن وسلامة',
      'description': 'شرطة النجدة والطوارئ الأمنية',
      'isEmergency': true,
      'priority': 3,
    },
    {
      'name': 'العمليات الداخلية',
      'phone': '130',
      'icon': Icons.security,
      'color': Colors.indigo,
      'category': 'خدمات حكومية',
      'description': 'العمليات الداخلية والأمنية',
      'isEmergency': false,
      'priority': 4,
    },
    {
      'name': 'جهاز الأمن الوطني',
      'phone': '131',
      'icon': Icons.shield,
      'color': Colors.purple,
      'category': 'أمن وسلامة',
      'description': 'جهاز الأمن الوطني (مخصص أيضاً لحالة الابتزاز)',
      'isEmergency': false,
      'priority': 5,
    },
    {
      'name': 'جهاز المخابرات الوطني',
      'phone': '400',
      'icon': Icons.visibility,
      'color': Colors.teal,
      'category': 'أمن وسلامة',
      'description': 'جهاز المخابرات الوطني',
      'isEmergency': false,
      'priority': 6,
    },
    {
      'name': 'مديرية مكافحة الإجرام',
      'phone': '533',
      'icon': Icons.gavel,
      'color': Colors.brown,
      'category': 'مكافحة الجرائم',
      'description': 'مديرية مكافحة الإجرام (مخصص أيضاً لحالة الابتزاز)',
      'isEmergency': false,
      'priority': 7,
    },
    {
      'name': 'مديرية مكافحة المتفجرات',
      'phone': '404',
      'icon': Icons.warning,
      'color': Colors.deepOrange,
      'category': 'أمن وسلامة',
      'description': 'مديرية مكافحة المتفجرات',
      'isEmergency': false,
      'priority': 8,
    },
    {
      'name': 'حماية الأسرة',
      'phone': '153',
      'icon': Icons.family_restroom,
      'color': Colors.pink,
      'category': 'خدمات حكومية',
      'description': 'حماية الأسرة والعنف الأسري',
      'isEmergency': false,
      'priority': 9,
    },
    {
      'name': 'الشرطة المجتمعية',
      'phone': '497',
      'icon': Icons.groups,
      'color': Colors.green,
      'category': 'أمن وسلامة',
      'description': 'الشرطة المجتمعية والخدمات المحلية',
      'isEmergency': false,
      'priority': 10,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentBgColor = isDark ? darkBackground : backgroundColor;
    final currentTextColor = isDark ? darkText : textColor;
    final iconColor = isDark ? darkText : theme.colorScheme.onSurface;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: currentBgColor,
        appBar: AppBar(
          title: Text(
            'أرقام الطوارئ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: currentTextColor,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: iconColor),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.share_location_outlined, color: primaryColor),
              tooltip: 'مشاركة موقعي',
              onPressed: _shareLocation,
            ),
          ],
        ),
        body: Column(
          children: [
            // Quick Access Section
            _buildQuickAccessSection(isDark),

            // Search and Filters
            _buildSearchAndFilters(isDark),

            // Warning Banner
            _buildWarningBanner(isDark),

            // Services List
            Expanded(child: _buildServicesList(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessSection(bool isDark) {
    final quickServices = emergencyServices.where((s) => s['priority'] <= 3).toList();

    final cardColor = isDark ? darkCard : Colors.white;
    final titleColor = isDark ? darkText : textColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'وصول سريع',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children:
                quickServices.map((service) {
                  return _buildQuickAccessButton(service, isDark);
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessButton(Map<String, dynamic> service, bool isDark) {
    final labelColor = isDark ? darkSubText : textColor;

    return Column(
      children: [
        InkWell(
          onTap: () => _makeCall(service['phone']),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: (service['color'] as Color).withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: (service['color'] as Color).withValues(alpha: 0.3)),
            ),
            child: Icon(service['icon'], color: service['color'], size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          service['name'],
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: labelColor,
          ),
        ),
        Text(
          service['phone'],
          style: TextStyle(
            fontSize: 12,
            color: service['color'],
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters(bool isDark) {
    final cardColor = isDark ? darkCard : Colors.white;
    final inputFillColor = isDark ? darkSurface : surfaceColor;
    final currentTextColor = isDark ? darkText : textColor;
    final currentHintColor = isDark ? darkHint : hintColor;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: inputFillColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث عن خدمة...',
                hintStyle: TextStyle(color: currentHintColor),
                prefixIcon: const Icon(Icons.search, color: primaryColor),
                suffixIcon:
                    search.isNotEmpty
                        ? IconButton(
                          icon: Icon(Icons.clear, color: currentHintColor),
                          onPressed: () => setState(() => search = ''),
                        )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              style: TextStyle(color: currentTextColor),
              onChanged: (val) => setState(() => search = val.trim()),
            ),
          ),

          const SizedBox(height: 12),

          // Categories
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = selectedCategory == category;

                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: FilterChip(
                    label: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : currentTextColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => selectedCategory = category);
                    },
                    backgroundColor: cardColor,
                    selectedColor: primaryColor,
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isSelected ? Colors.transparent : borderColor),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'للطوارئ فقط! الاستخدام الخاطئ يعرضك للمساءلة.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesList(bool isDark) {
    final filteredServices =
        emergencyServices.where((service) {
          bool matchesSearch =
              search.isEmpty ||
              service['name'].toString().toLowerCase().contains(search.toLowerCase()) ||
              service['phone'].toString().contains(search);

          bool matchesCategory =
              selectedCategory == 'الكل' || service['category'] == selectedCategory;

          return matchesSearch && matchesCategory;
        }).toList();

    if (filteredServices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: isDark ? darkHint : Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'ماكو نتائج حالياً',
              style: TextStyle(color: isDark ? darkSubText : Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: filteredServices.length,
      itemBuilder: (context, index) {
        return _buildServiceCard(filteredServices[index], isDark);
      },
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service, bool isDark) {
    final color = service['color'] as Color;
    final cardColor = isDark ? darkCard : Colors.white;
    final currentTextColor = isDark ? darkText : textColor;
    final currentSubTextColor = isDark ? darkSubText : subTextColor;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(service['icon'], color: color),
        ),
        title: Text(
          service['name'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: currentTextColor,
          ),
        ),
        subtitle: Text(
          service['description'],
          style: TextStyle(fontSize: 12, color: currentSubTextColor),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.copy, size: 20, color: isDark ? darkHint : Colors.grey),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: service['phone']));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم نسخ الرقم', style: TextStyle()),
                  ),
                );
              },
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                onPressed: () => _makeCall(service['phone']),
              ),
            ),
          ],
        ),
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: service['phone']));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم نسخ الرقم', style: TextStyle())),
          );
        },
      ),
    );
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن إجراء الاتصال', style: TextStyle()),
          ),
        );
      }
    }
  }

  void _shareLocation() {
    // Placeholder for location sharing functionality
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor:
                Theme.of(context).brightness == Brightness.dark ? darkCard : Colors.white,
            title: Text(
              'مشاركة الموقع',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? darkText : textColor,
              ),
            ),
            content: Text(
              'سيتم إضافة ميزة مشاركة الموقع قريباً لمساعدتك في إرسال موقعك لخدمات الطوارئ.',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? darkSubText : subTextColor,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'حسناً',
                  style: TextStyle(color: primaryColor),
                ),
              ),
            ],
          ),
    );
  }
}
