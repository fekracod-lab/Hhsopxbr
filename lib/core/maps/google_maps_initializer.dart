import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// مسرّع ومُهيئ خرائط Google عند الطلب الفعلي فقط (Lazy On-Demand Maps Initializer)
/// يمنع تحميل dynamite module واستخراج شهادات Play Services أثناء تشغيل التطبيق (Boot)
class GoogleMapsInitializer {
  static bool _isInitialized = false;

  /// تهيئة محرك الخرائط فقط عند حاجة الشاشة الحالية إليه
  static Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      final mapsImplementation = GoogleMapsFlutterPlatform.instance;
      if (mapsImplementation is GoogleMapsFlutterAndroid) {
        await mapsImplementation.initializeWithRenderer(AndroidMapRenderer.latest);
        mapsImplementation.useAndroidViewSurface = false;
        debugPrint(' [MAP] AndroidMapRenderer.latest initialized on-demand.');
      }
    } catch (e) {
      debugPrint(' [MAP] Renderer on-demand init info: $e');
    }
  }
}
