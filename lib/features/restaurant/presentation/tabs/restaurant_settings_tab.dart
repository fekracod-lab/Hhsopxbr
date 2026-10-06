import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dalal_alqaim/services/cloudinary_service.dart';
import 'package:dalal_alqaim/services/ringtone_manager.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class RestaurantSettingsTab extends StatelessWidget {
  final String restaurantId;

  const RestaurantSettingsTab({
    super.key,
    required this.restaurantId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? app_colors.darkCard : Colors.white;
    final textPrimary = isDark ? app_colors.darkText : app_colors.textColor;
    final textSecondary = isDark ? app_colors.darkSubText : app_colors.subTextColor;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(restaurantId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: app_colors.primaryColor),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final openTime = data['openingTime'] ?? '08:00 ص';
        final closeTime = data['closingTime'] ?? '11:00 م';
        final restaurantName = data['restaurantName'] ?? data['fullName'] ?? 'اسم المطعم';
        final cuisineType = data['cuisineType'] ?? 'مطبخ شرقي • مأكولات سريعة';

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const BouncingScrollPhysics(),
          children: [
            const SizedBox(height: 12),

            // 1. Working Hours Section
            Text(
              'أوقات وساعات العمل اليومية',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => _selectTime(context, 'openingTime', openTime),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'بدء العمل واستقبال الطلبات',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: app_colors.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            openTime,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: app_colors.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  InkWell(
                    onTap: () => _selectTime(context, 'closingTime', closeTime),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'نهاية العمل والإغلاق اليومي',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: app_colors.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            closeTime,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: app_colors.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 2. Profile & Branding
            Text(
              'الملف التعريفي والواجهة',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                _showEditProfileDialog(context, data);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: app_colors.primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront_rounded, color: app_colors.primaryColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            restaurantName,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            cuisineType,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: app_colors.subTextColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            // 3. Kitchen Alarm & Notifications Testing
            Text(
              'أجراس وتنبيهات المطبخ',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.volume_up_rounded, color: Colors.amber, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'جرس إنذار الطلبات الجديدة',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              'صوت عالي ومستمر للتأكد من انتباه الطهاة',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          RingtoneManager.startAlarm('test_kitchen', autoStopSeconds: 5);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تجربة جرس المطبخ تعمل لمدة 5 ثوانٍ...'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: app_colors.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        child: Text(
                          'تجربة الصوت',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  void _selectTime(BuildContext context, String field, String currentVal) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null && context.mounted) {
      final formatted = picked.format(context);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(restaurantId)
          .update({field: formatted});
    }
  }

  void _showEditProfileDialog(BuildContext context, Map<String, dynamic> currentData) {
    final nameCtrl = TextEditingController(text: currentData['restaurantName'] ?? currentData['fullName'] ?? '');
    final cuisineCtrl = TextEditingController(text: currentData['cuisineType'] ?? currentData['cuisine'] ?? '');
    final addressCtrl = TextEditingController(text: currentData['address'] ?? '');
    final descCtrl = TextEditingController(text: currentData['description'] ?? '');

    String? logoUrl = currentData['photoUrl'] ?? currentData['imageUrl'];
    String? coverUrl = currentData['coverImageUrl'] ?? currentData['coverImage'];
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardBg = isDark ? app_colors.darkCard : Colors.white;

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Text(
              'تعديل ملف وبيانات المطعم',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isUploading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: LinearProgressIndicator(color: app_colors.primaryColor),
                    ),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'اسم المطعم التجاري'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cuisineCtrl,
                    decoration: const InputDecoration(labelText: 'نوع المطبخ والتصنيف'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(labelText: 'عنوان وموقع المطعم'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'وصف المطعم للزبائن'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final file = await picker.pickImage(source: ImageSource.gallery);
                            if (file != null) {
                              setDlgState(() => isUploading = true);
                              final bytes = await file.readAsBytes();
                              final url = await CloudinaryService.uploadBytes(bytes, 'logo_${DateTime.now().millisecondsSinceEpoch}.jpg');
                              if (url != null) {
                                logoUrl = url;
                              }
                              setDlgState(() => isUploading = false);
                            }
                          },
                          icon: const Icon(Icons.add_a_photo_rounded, size: 16),
                          label: Text('تغيير اللوجو', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final file = await picker.pickImage(source: ImageSource.gallery);
                            if (file != null) {
                              setDlgState(() => isUploading = true);
                              final bytes = await file.readAsBytes();
                              final url = await CloudinaryService.uploadBytes(bytes, 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg');
                              if (url != null) {
                                coverUrl = url;
                              }
                              setDlgState(() => isUploading = false);
                            }
                          },
                          icon: const Icon(Icons.panorama_rounded, size: 16),
                          label: Text('صورة الغلاف', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic()),
              ),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('users').doc(restaurantId).update({
                    'restaurantName': nameCtrl.text.trim(),
                    'cuisineType': cuisineCtrl.text.trim(),
                    'address': addressCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    if (logoUrl != null) 'photoUrl': logoUrl,
                    if (coverUrl != null) 'coverImageUrl': coverUrl,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: app_colors.primaryColor),
                child: Text(
                  'حفظ التعديلات',
                  style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
