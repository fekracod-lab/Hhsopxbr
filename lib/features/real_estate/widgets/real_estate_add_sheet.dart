import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import '../services/real_estate_service.dart';

class RealEstateAddSheet extends StatefulWidget {
  final bool isDark;

  const RealEstateAddSheet({
    super.key,
    required this.isDark,
  });

  @override
  State<RealEstateAddSheet> createState() => _RealEstateAddSheetState();
}

class _RealEstateAddSheetState extends State<RealEstateAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final RealEstateService _service = RealEstateService();

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _areaCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _bedroomsCtrl = TextEditingController();
  final TextEditingController _bathroomsCtrl = TextEditingController();
  final TextEditingController _streetCtrl = TextEditingController();

  String _selectedType = 'للبيع';
  String _selectedCategory = 'بيت ومنازل';
  String _selectedCurrency = 'IQD';
  String _selectedGovernorate = 'الأنبار';
  String _selectedCity = 'القائم';
  final List<XFile> _selectedImages = [];
  final List<String> _selectedFeatures = [];
  bool _isPublishing = false;
  bool _isGeneratingAI = false;

  final List<String> _types = ['للبيع', 'للإيجار'];
  final List<String> _categories = [
    'بيت ومنازل',
    'شقق وعمارات',
    'أراضي وعرصات',
    'محلات ومكاتب',
    'بساتين ومزارع',
    'شاليهات واستراحات',
  ];

  static const List<String> _governorates = [
    'بغداد',
    'الأنبار',
    'البصرة',
    'أربيل',
    'نينوى (الموصل)',
    'كركوك',
    'كربلاء المقدسة',
    'النجف الأشرف',
    'بابل (الحلة)',
    'ديالى',
    'صلاح الدين',
    'واسط',
    'ميسان',
    'ذي قار',
    'المثنى',
    'الديوانية',
    'دهوك',
    'السليمانية',
  ];

  static List<String> _getCitiesForGov(String gov) {
    switch (gov) {
      case 'الأنبار':
        return ['القائم', 'الرمادي', 'الفلوجة', 'هيت', 'حديثة', 'عانة', 'راوة', 'الرطبة', 'الكرمة', 'الخالدية', 'حصيبة', 'الرمانة', 'العبيدي'];
      case 'بغداد':
        return ['الكرخ', 'الرصافة', 'المنصور', 'الكرادة', 'الأعظمية', 'الكاظمية', 'الدورة', 'الشعب', 'مدينة الصدر', 'السيدية', 'العامرية', 'الغزالية'];
      case 'البصرة':
        return ['المركز (العشار)', 'الجبيلة', 'الجمهورية', 'القرنة', 'الزبير', 'شط العرب', 'أبي الخصيب', 'الفاو'];
      case 'نينوى (الموصل)':
        return ['الموصل الأيمن', 'الموصل الأيسر', 'تلعفر', 'الحمدانية', 'سنجار'];
      case 'أربيل':
        return ['المركز', 'عنكاوا', 'سوران', 'شقلاوة', 'كويسنجق'];
      case 'كربلاء المقدسة':
        return ['المركز', 'حي الحسين', 'حي العباس', 'الهندية', 'عين التمر'];
      case 'النجف الأشرف':
        return ['المدينة القديمة', 'الكوفة', 'حي الغدير', 'حي الأمير', 'المناذرة'];
      default:
        return ['المركز', 'حي المعلمين', 'السوق الكبير', 'حي الزهور'];
    }
  }

  final List<String> _availableFeatures = [
    'طابو صرف ملك صرف',
    'ماء إسالة دائم',
    'كهرباء وطنية ومولدة',
    'شارع مبلط',
    'كراج سيارة',
    'حديقة خاصة',
    'واجهة حجر فاخرة',
    'مجاري وخدمات بلدية',
    'إنترنت فايبر ضوئي',
  ];

  @override
  void initState() {
    super.initState();
    final user = _service.currentUser;
    if (user != null) {
      _phoneCtrl.text = user.phoneNumber ?? '';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _areaCtrl.dispose();
    _locationCtrl.dispose();
    _phoneCtrl.dispose();
    _descCtrl.dispose();
    _bedroomsCtrl.dispose();
    _bathroomsCtrl.dispose();
    _streetCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> imgs = await picker.pickMultiImage(imageQuality: 85);
    if (imgs.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(imgs);
      });
    }
  }

  Future<void> _generateAIDescription() async {
    if (_titleCtrl.text.trim().isEmpty && _locationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة عنوان العقار أو الحي لمساعدة سكوزمي', style: TextStyle()),
          backgroundColor: app_colors.primaryColor,
        ),
      );
      return;
    }

    setState(() => _isGeneratingAI = true);
    try {
      final text = await _service.generateRealEstateTextWithAI(
        prompt: 'صيغلي إعلان تسويقي عراقي جذاب جداً لـ ${_titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text : _selectedCategory}',
        propertyType: _selectedType,
        category: _selectedCategory,
        location: _locationCtrl.text.trim().isNotEmpty ? _locationCtrl.text.trim() : _selectedCity,
        area: _areaCtrl.text.trim(),
        price: '${_priceCtrl.text.trim()} ${_selectedCurrency == "USD" ? "\$" : "د.ع"}',
      );
      setState(() {
        _descCtrl.text = text;
      });
    } catch (e) {
      // Fallback
    } finally {
      if (mounted) setState(() => _isGeneratingAI = false);
    }
  }

  Future<void> _submitProperty() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار صورة واحدة على الأقل للعقار', style: TextStyle()),
          backgroundColor: app_colors.primaryColor,
        ),
      );
      return;
    }

    setState(() => _isPublishing = true);
    try {
      await _service.addProperty(
        title: _titleCtrl.text.trim(),
        type: _selectedType,
        category: _selectedCategory,
        price: _priceCtrl.text.trim(),
        currency: _selectedCurrency,
        area: _areaCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        governorate: _selectedGovernorate,
        city: _selectedCity,
        phone: _phoneCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        features: _selectedFeatures,
        images: _selectedImages,
        bedrooms: int.tryParse(_bedroomsCtrl.text.trim()),
        bathrooms: int.tryParse(_bathroomsCtrl.text.trim()),
        streetWidth: _streetCtrl.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم نشر إعلان عقارك بنجاح في مدار!', style: TextStyle()),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل النشر: $e', style: const TextStyle()),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final availableCities = _getCitiesForGov(_selectedGovernorate);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF07191B) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        ),
        child: Column(
          children: [
            // Handle Bar
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Container(
                width: 44.w,
                height: 4.5.h,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),

            // Sheet Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: app_colors.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: const Icon(Icons.add_home_work_rounded, color: app_colors.primaryColor, size: 22),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نشر إعلان عقار جديد',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                            color: isDark ? Colors.white : const Color(0xFF0C2428),
                          ),
                        ),
                        Text(
                          'اعرض بيتك أو شقتك أو أرضك في كل مدن العراق',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(color: isDark ? Colors.white10 : Colors.grey.shade200),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 1. Deal Type & Category Selection ──
                      Row(
                        children: _types.map((type) {
                          final isSelected = _selectedType == type;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4.w),
                              child: ChoiceChip(
                                label: Center(
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.sp,
                                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (_) => setState(() => _selectedType = type),
                                selectedColor: app_colors.primaryColor,
                                backgroundColor: isDark ? const Color(0xFF113035) : Colors.grey.shade100,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 12.h),

                      // Category Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories.map((cat) {
                            final isSelected = _selectedCategory == cat;
                            return Padding(
                              padding: EdgeInsets.only(left: 6.w),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                onSelected: (_) => setState(() => _selectedCategory = cat),
                                selectedColor: app_colors.primaryColor,
                                backgroundColor: isDark ? const Color(0xFF113035) : Colors.grey.shade100,
                                labelStyle: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  fontSize: 11.sp,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(height: 14.h),

                      // ── 2. Governorate & City ──
                      Text(
                        'المحافظة والمدينة بالعراق 🇮🇶:',
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _governorates.map((gov) {
                            final isSel = _selectedGovernorate == gov;
                            return Padding(
                              padding: EdgeInsets.only(left: 6.w),
                              child: ChoiceChip(
                                label: Text(gov),
                                selected: isSel,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedGovernorate = gov;
                                    final cities = _getCitiesForGov(gov);
                                    _selectedCity = cities.isNotEmpty ? cities.first : gov;
                                  });
                                },
                                selectedColor: app_colors.primaryColor,
                                backgroundColor: isDark ? const Color(0xFF113035) : Colors.grey.shade100,
                                labelStyle: TextStyle(
                                  fontSize: 10.5.sp,
                                  color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: availableCities.map((c) {
                            final isSel = _selectedCity == c;
                            return Padding(
                              padding: EdgeInsets.only(left: 6.w),
                              child: ActionChip(
                                label: Text(c),
                                backgroundColor: isSel ? app_colors.primaryColor.withValues(alpha: 0.2) : (isDark ? const Color(0xFF113035) : Colors.grey.shade100),
                                side: BorderSide(color: isSel ? app_colors.primaryColor : Colors.transparent),
                                labelStyle: TextStyle(
                                  fontSize: 10.5.sp,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  color: isSel ? app_colors.primaryColor : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                onPressed: () => setState(() => _selectedCity = c),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(height: 12.h),

                      // ── Title Field ──
                      _buildTextField(
                        controller: _titleCtrl,
                        label: 'عنوان الإعلان (مثال: بيت طابو صرف 200م شارع 15)',
                        icon: Icons.title_rounded,
                        isDark: isDark,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة عنوان الإعلان' : null,
                      ),
                      SizedBox(height: 12.h),

                      // ── Price & Currency ──
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildTextField(
                              controller: _priceCtrl,
                              label: 'السعر المطلوب',
                              icon: Icons.payments_rounded,
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى تحديد السعر' : null,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F2D32) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCurrency,
                                  dropdownColor: isDark ? const Color(0xFF0F2D32) : Colors.white,
                                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                                  items: const [
                                    DropdownMenuItem(value: 'IQD', child: Text('دينار عراقي')),
                                    DropdownMenuItem(value: 'USD', child: Text('دولار (\$)')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedCurrency = val);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),

                      // ── Area & District Selection ──
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _areaCtrl,
                              label: 'المساحة (م²)',
                              icon: Icons.aspect_ratio_rounded,
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'اكتب المساحة' : null,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: _buildTextField(
                              controller: _phoneCtrl,
                              label: 'رقم الواتساب والاتصال',
                              icon: Icons.phone_rounded,
                              isDark: isDark,
                              keyboardType: TextInputType.phone,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'اكتب رقم الهاتف' : null,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),

                      // ── Location / District ──
                      _buildTextField(
                        controller: _locationCtrl,
                        label: 'اسم الحي / الشارع (مثال: حي الجمعية، شارع المحطة، قرب جامع...)',
                        icon: Icons.location_on_rounded,
                        isDark: isDark,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى تحديد الحي أو اسم الشارع' : null,
                      ),
                      SizedBox(height: 12.h),

                      // ── Bedrooms, Bathrooms, Street ──
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _bedroomsCtrl,
                              label: 'غرف النوم',
                              icon: Icons.bed_rounded,
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: _buildTextField(
                              controller: _bathroomsCtrl,
                              label: 'الحمامات',
                              icon: Icons.bathtub_rounded,
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: _buildTextField(
                              controller: _streetCtrl,
                              label: 'عرض الشارع (م)',
                              icon: Icons.add_road_rounded,
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 14.h),

                      // ── Photo Picker ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'صور العقار (${_selectedImages.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(Icons.add_photo_alternate_rounded, color: app_colors.primaryColor),
                            label: const Text('إضافة صور', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      if (_selectedImages.isNotEmpty)
                        SizedBox(
                          height: 80.h,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedImages.length,
                            itemBuilder: (context, index) {
                              return Stack(
                                children: [
                                  Container(
                                    width: 80.r,
                                    height: 80.r,
                                    margin: EdgeInsets.only(left: 8.w),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(color: app_colors.primaryColor.withValues(alpha: 0.4)),
                                      image: DecorationImage(
                                        image: NetworkImage(_selectedImages[index].path),
                                        fit: BoxFit.cover,
                                        onError: (_, __) {},
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 10,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedImages.removeAt(index)),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      SizedBox(height: 14.h),

                      // ── Features Chips ──
                      Text(
                        'مميزات وخدمات العقار',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Wrap(
                        spacing: 6.w,
                        runSpacing: 6.h,
                        children: _availableFeatures.map((feat) {
                          final isSelected = _selectedFeatures.contains(feat);
                          return FilterChip(
                            label: Text(feat, style: TextStyle(fontSize: 11.sp)),
                            selected: isSelected,
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _selectedFeatures.add(feat);
                                } else {
                                  _selectedFeatures.remove(feat);
                                }
                              });
                            },
                            selectedColor: app_colors.primaryColor.withValues(alpha: 0.25),
                            checkmarkColor: app_colors.primaryColor,
                            backgroundColor: isDark ? const Color(0xFF113035) : Colors.grey.shade100,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 14.h),

                      // ── Description + AI Generator ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'تفاصيل وملاحظات إضافية',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _isGeneratingAI ? null : _generateAIDescription,
                            icon: _isGeneratingAI
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 16),
                            label: Text(
                              _isGeneratingAI ? 'جاري الصياغة...' : 'صياغة ذكية بالذكاء',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      _buildTextField(
                        controller: _descCtrl,
                        label: 'اكتب مواصفات العقار، الجيران، القرب من الخدمات والمدارس...',
                        icon: Icons.description_rounded,
                        isDark: isDark,
                        maxLines: 4,
                      ),
                      SizedBox(height: 24.h),

                      // ── Publish Button ──
                      SizedBox(
                        width: double.infinity,
                        height: 52.h,
                        child: ElevatedButton.icon(
                          onPressed: _isPublishing ? null : _submitProperty,
                          icon: _isPublishing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle_rounded, color: Colors.white),
                          label: Text(
                            _isPublishing ? 'جاري رفع الصور ونشر الإعلان...' : 'نشر إعلان العقار الآن',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                            elevation: 4,
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      cursorColor: app_colors.primaryColor,
      style: TextStyle(
        fontSize: 12.5.sp,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 11.5.sp,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
        prefixIcon: Icon(icon, color: app_colors.primaryColor, size: 18.r),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F2D32) : Colors.grey.shade50,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: const BorderSide(color: app_colors.primaryColor, width: 1.5),
        ),
      ),
    );
  }
}
