import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CloudinaryService {
  static const String cloudName = 'dzcxhdnji'; 
  static const String uploadPreset = 'flutter_unsigned'; 

  /// Upload image from memory bytes using dual-engine:
  /// 1. Firebase Storage with proper image content-type and security rules matching
  /// 2. Cloudinary fallback
  static Future<String?> uploadBytes(Uint8List bytes, String filename) async {
    final safeFilename = 'meal_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // المحرك الأول: Firebase Storage السريع والمباشر
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.uid.isNotEmpty) {
        final storageRef = FirebaseStorage.instance
            .ref('restaurants/${user.uid}/meals/$safeFilename');
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'uploadedBy': user.uid, 'source': 'pos_desktop'},
        );
        await storageRef.putData(bytes, metadata);
        final downloadUrl = await storageRef.getDownloadURL();
        if (downloadUrl.isNotEmpty) {
          debugPrint('[ImageUpload] Successfully uploaded to Firebase Storage: $downloadUrl');
          return downloadUrl;
        }
      }
    } catch (e) {
      debugPrint('[ImageUpload] Firebase Storage direct upload failed: $e. Trying Cloudinary fallback...');
    }

    // المحرك الثاني: خادم Cloudinary الاحتياطي
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      var request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: safeFilename));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final resBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(resBody);
        final secureUrl = data['secure_url'] as String?;
        if (secureUrl != null && secureUrl.isNotEmpty) {
          debugPrint('[ImageUpload] Successfully uploaded to Cloudinary: $secureUrl');
          return secureUrl;
        }
      } else {
        debugPrint('[ImageUpload] Cloudinary error: ${streamedResponse.statusCode} - $resBody');
      }
    } catch (e) {
      debugPrint('[ImageUpload] Exception in Cloudinary uploadBytes: $e');
    }

    return null;
  }

  /// Upload image alias
  static Future<String?> uploadImage(Uint8List bytes, String filename) => uploadBytes(bytes, filename);

  // Helper to generate optimized Cloudinary URL
  static String getOptimizedUrl(String url, {int? width, int? height}) {
    if (!url.contains('cloudinary.com')) return url;

    // Check if it already has transformations
    if (url.contains('/upload/w_') || url.contains('/upload/h_')) return url;

    // Splitting by 'upload/' to inject parameters
    final parts = url.split('/upload/');
    if (parts.length != 2) return url;

    final List<String> transformations = ['q_auto', 'f_auto']; // Quality & Format auto
    if (width != null) transformations.add('w_$width');
    if (height != null) transformations.add('h_$height');
    transformations.add('c_fill'); // Crop mode

    final params = transformations.join(',');
    return '${parts[0]}/upload/$params/${parts[1]}';
  }
}
