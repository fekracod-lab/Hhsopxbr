import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dalal_alqaim/core/app_globals.dart'; // For isDarkModeNotifier
import 'package:dalal_alqaim/shared/app_colors.dart'; // primaryColor

class LocationPermissionHelper {
  /// يطلب إذن الموقع عن طريق:
  /// 1. إظهار الإفصاح البارز (Prominent Disclosure)
  /// 2. طلب إذن الموقع أثناء الاستخدام (Foreground)
  static Future<bool> requestLocationPermissionWithDisclosure(BuildContext context) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'خدمة الـ GPS طافية عندك، شغّلها حتى نندل مكانك ونوصلك أسرع',
                style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily),
              ),
              backgroundColor: const Color(0xFFE65100),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }

      final hasForeground = await Permission.locationWhenInUse.isGranted;

      // إذا كان الإذن ممنوحاً، نعتبر الإذن متوفر في هذه المرحلة
      if (hasForeground) {
        return true;
      }

      // 1⃣ عرض نافذة الإفصاح
      if (!context.mounted) return false;
      bool userAgreed = await showDisclosureDialog(context);
      if (!userAgreed) return false;

      // 2⃣ طلب إذن Foreground أولاً
      final fgStatus = await requestForegroundLocation();
      if (!fgStatus.isGranted) {
        if (fgStatus.isPermanentlyDenied && context.mounted) {
          _showSettingsDialog(context);
        }
        return false;
      }

      return true;
    } catch (e) {
      debugPrint(' Location permission request error: $e');
      return false;
    }
  }

  static Future<bool> showDisclosureDialog(BuildContext context) async {
    bool accepted = false;
    if (!context.mounted) return false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return ValueListenableBuilder<bool>(
          valueListenable: isDarkModeNotifier,
          builder: (context, isDark, _) {
            final bg = isDark ? const Color(0xFF101D25) : Colors.white;
            final txtColor = isDark ? Colors.white : Colors.black87;
            final subTxtColor = isDark ? Colors.white70 : Colors.black54;

            return AlertDialog(
              backgroundColor: bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.location_on_rounded, color: primaryColor, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'نحتاج نعرف موقعك',
                      style: TextStyle(
                        fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                        fontWeight: FontWeight.bold,
                        color: txtColor,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'تطبيق مدار يحتاج يندل موقعك حتى نحدد أقرب كابتن تكسي يمك ويجيك مباشرة لباب البيت وبدون تأخير \nموقعك محفوظ ومأمن وما نشاركه ويا أي طرف ثاني.',
                    style: TextStyle(
                      fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                      color: subTxtColor,
                      fontSize: 13,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    accepted = false;
                    Navigator.of(ctx).pop();
                  },
                  child: Text(
                    'بعدين',
                    style: TextStyle(
                      fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    accepted = true;
                    Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'تدلل، موافق',
                    style: TextStyle(
                      fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    return accepted;
  }

  static Future<PermissionStatus> requestForegroundLocation() async {
    return await Permission.locationWhenInUse.request();
  }

  static void _showSettingsDialog(BuildContext context) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text(
              'لازم تفعل الموقع',
              style: TextStyle(
                fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'حتى نگدر نحدد مكانك وندزلك الكابتن، يرجى تفعيل إذن الموقع من إعدادات جهازك.',
              style: TextStyle(
                fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                fontSize: 13,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'إلغاء',
                  style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  openAppSettings();
                },
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                child: Text(
                  'فتح الإعدادات',
                  style: TextStyle(
                    fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
