import 'package:cloud_firestore/cloud_firestore.dart';

class IraqiDataSeeder {
  static final Map<String, List<String>> iraqData = {
    'بغداد': [
      'الكرخ',
      'الرصافة',
      'مدينة الصدر',
      'الكاظمية',
      'المنصور',
      'الكرادة',
      'الدورة',
      'بغداد الجديدة',
      'حي الجامعة',
      'الشعب',
      'الحسينية',
      'التاجي',
      'المحمودية',
      'أبو غريب',
      'الطارمية',
      'اليوسفية',
      'الراشدية'
    ],
    'البصرة': ['مركز البصرة', 'الزبير', 'القرنة', 'أبي الخصيب', 'الفاو', 'شط العرب', 'المدينة', 'الهوير', 'سفوان'],
    'نينوى': ['الموصل', 'تلعفر', 'تلكيف', 'سنجار', 'الحمدانية', 'الشيخان', 'البعاج', 'الحضر', 'زمار', 'القوش'],
    'أربيل': ['مركز أربيل', 'شقلاوة', 'سوران', 'كوي سنجق', 'راوندوز', 'چومان', 'خبات', 'سيدكان'],
    'السليمانية': ['مركز السليمانية', 'رانية', 'دوكان', 'سيد صادق', 'بشدر', 'قلعة دزة', 'دربندخان', 'جمجمال'],
    'كركوك': ['مركز كركوك', 'الحويجة', 'داقوق', 'الدبس', 'تازة', 'ليلان'],
    'بابل': ['الحلة', 'المحاويل', 'المسيب', 'الهاشمية', 'القاسم', 'بابل'],
    'النجف': ['مركز النجف', 'الكوفة', 'المناذرة', 'المشخاب', 'الحيدرية'],
    'كربلاء': ['مركز كربلاء', 'الهندية', 'عين التمر', 'الحسينية'],
    'ذي قار': ['الناصرية', 'الشطرة', 'الرفاعي', 'سوق الشيوخ', 'الجبايش', 'قلعة سكر'],
    'الأنبار': ['الرمادي', 'الفلوجة', 'هيت', 'عانة', 'راوة', 'الرطبة', 'القائم', 'حديثة', 'الكرمة', 'الخالدية'],
    'ديالى': ['بعقوبة', 'المقدادية', 'خانقين', 'الخالص', 'بلدروز', 'السعدية', 'جلولاء'],
    'المثنى': ['السماوة', 'الرميثة', 'الخضر', 'السلمان'],
    'القادسية': ['الديوانية', 'عفك', 'الشامية', 'الحمزة', 'الدغارة'],
    'ميسان': ['العمارة', 'علي الغربي', 'الميمونة', 'المجر الكبير', 'الكحلاء', 'قلعة صالح'],
    'واسط': ['الكوت', 'العزيزية', 'الصويرة', 'الحي', 'النعمانية', 'بدرة'],
    'صلاح الدين': ['تكريت', 'سامراء', 'بلد', 'الدجيل', 'الشرقاط', 'بيجي', 'الدور', 'طوز خورماتو'],
    'دهوك': ['مركز دهوك', 'زاخو', 'العمادية', 'سميل', 'عقرة', 'شيخان'],
    'حلبجة': ['مركز حلبجة', 'سيروان', 'خورمال'],
  };

  static Future<void> seedIraqData() async {
    final firestore = FirebaseFirestore.instance;
    final govCollection = firestore.collection('governorates');

    int index = 0;
    for (var entry in iraqData.entries) {
      final govName = entry.key;
      final regions = entry.value;

      // Check if governorate already exists
      final existingGov = await govCollection.where('name', isEqualTo: govName).get();

      DocumentReference govRef;
      if (existingGov.docs.isEmpty) {
        govRef = await govCollection.add({
          'name': govName,
          'isActive': true,
          'orderIndex': index,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        govRef = existingGov.docs.first.reference;
        await govRef.update({
          'orderIndex': index,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      index++;

      final regionsCollection = govRef.collection('regions');

      for (var regionName in regions) {
        // Check if region already exists
        final existingRegion = await regionsCollection.where('name', isEqualTo: regionName).get();

        if (existingRegion.docs.isEmpty) {
          await regionsCollection.add({
            'name': regionName,
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }
  }
}
