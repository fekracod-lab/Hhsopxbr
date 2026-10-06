import '../entities/sensitive_data_descriptor.dart';
import '../enums/security_enums.dart';

/// محرك حماية الخصوصية وتصنيف وحجب البيانات الشخصية (Privacy & PII Protection Engine)
class PrivacyEngine {
  final Map<String, SensitiveDataDescriptor> descriptors;

  const PrivacyEngine({
    this.descriptors = SensitiveDataDescriptor.defaultDescriptors,
  });

  /// حجب رقم الهاتف الشخصي (Phone Number Masking)
  /// مثال: `07801234567` -> `078****4567`
  String maskPhoneNumber(String? phone) {
    if (phone == null || phone.trim().isEmpty) return '';
    final clean = phone.trim();
    if (clean.length <= 6) return '****';
    final prefix = clean.substring(0, 3);
    final suffix = clean.substring(clean.length - 4);
    return '$prefix****$suffix';
  }

  /// حجب البريد الإلكتروني (Email Masking)
  /// مثال: `driver@madar.iq` -> `d***r@madar.iq`
  String maskEmail(String? email) {
    if (email == null || email.trim().isEmpty) return '';
    final parts = email.trim().split('@');
    if (parts.length != 2) return '***@***';
    final username = parts[0];
    final domain = parts[1];

    if (username.length <= 2) {
      return '*@$domain';
    }
    final firstChar = username[0];
    final lastChar = username[username.length - 1];
    return '$firstChar***$lastChar@$domain';
  }

  /// حجب الإحداثيات الجغرافية الدقيقة لحماية خصوصية الموقع (Location Fuzzing / Coarsening)
  (double lat, double lng) coarsenLocation(double lat, double lng) {
    // التقريب لمنزلتين عشريتين (~1km دقة لحفظ الخصوصية في السجلات العامة)
    final coarseLat = double.parse(lat.toStringAsFixed(2));
    final coarseLng = double.parse(lng.toStringAsFixed(2));
    return (coarseLat, coarseLng);
  }

  /// تنظيف وحجب خريطة البيانات وفق مصفوفة تصنيف الحساسية
  Map<String, dynamic> sanitizeMap(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is Map<String, dynamic>) {
        sanitized[key] = sanitizeMap(value);
      } else if (value is List) {
        sanitized[key] = value.map((item) {
          if (item is Map<String, dynamic>) return sanitizeMap(item);
          return item;
        }).toList();
      } else {
        final keyLower = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final descriptor = descriptors[keyLower];

        if (keyLower.contains('password') ||
            keyLower.contains('secret') ||
            keyLower.contains('token') ||
            keyLower.contains('jwt') ||
            keyLower.contains('cvv') ||
            keyLower.contains('cardnumber') ||
            descriptor?.classification == DataClassification.highlySensitive) {
          sanitized[key] = '[REDACTED_HIGHLY_SENSITIVE]';
        } else if (keyLower.contains('phone')) {
          sanitized[key] = maskPhoneNumber(value?.toString());
        } else if (keyLower.contains('email')) {
          sanitized[key] = maskEmail(value?.toString());
        } else if (descriptor != null) {
          sanitized[key] = '[MASKED_PII]';
        } else {
          sanitized[key] = value;
        }
      }
    }

    return sanitized;
  }
}
