// ignore_for_file: unnecessary_import
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class CloudinaryService {
  static const String cloudName = 'dzcxhdnji'; // من حسابك
  static const String uploadPreset = 'flutter_unsigned'; // اسم الـ preset

  /// Upload image from a local file path.
  ///
  /// NOTE: prefer [uploadBytes] to avoid relying on file paths / external storage.
  @Deprecated('Use uploadBytes instead')
  static Future<String?> uploadImage(String filePath) async {
    // Path-based uploads rely on dart:io and are not supported on web.
    // Prefer reading bytes (XFile.readAsBytes) and calling [uploadBytes].
    throw UnsupportedError(
      'uploadImage(filePath) is deprecated. Use uploadBytes(Uint8List, filename) instead.',
    );
  }

  /// Upload image from memory bytes with client-side size and payload protection.
  static Future<String?> uploadBytes(Uint8List bytes, String filename) async {
    if (bytes.isEmpty) {
      debugPrint('Cloudinary uploadBytes: Error - empty bytes payload.');
      return null;
    }
    // Limit image size to 10MB to prevent memory/quota abuse
    if (bytes.lengthInBytes > 10 * 1024 * 1024) {
      debugPrint('Cloudinary uploadBytes: Error - image file exceeds 10MB limit (${bytes.lengthInBytes} bytes).');
      return null;
    }

    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      var request =
          http.MultipartRequest('POST', url)
            ..fields['upload_preset'] = uploadPreset
            ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(resBody);
        return data['secure_url'];
      } else {
        debugPrint('Cloudinary error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception in uploadBytes: $e');
      return null;
    }
  }

  /// Upload video from memory bytes with client-side size protection.
  static Future<String?> uploadVideo(Uint8List bytes, String filename) async {
    if (bytes.isEmpty) {
      debugPrint('Cloudinary uploadVideo: Error - empty bytes payload.');
      return null;
    }
    // Limit video size to 50MB
    if (bytes.lengthInBytes > 50 * 1024 * 1024) {
      debugPrint('Cloudinary uploadVideo: Error - video file exceeds 50MB limit (${bytes.lengthInBytes} bytes).');
      return null;
    }

    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload');

      var request =
          http.MultipartRequest('POST', url)
            ..fields['upload_preset'] = uploadPreset
            ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(resBody);
        return data['secure_url'];
      } else {
        debugPrint('Cloudinary video error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception in uploadVideo: $e');
      return null;
    }
  }

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
