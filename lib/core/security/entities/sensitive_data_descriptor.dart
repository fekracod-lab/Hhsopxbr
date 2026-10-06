import 'package:flutter/foundation.dart';
import '../enums/security_enums.dart';

/// واصف حساسية الحقول والبيانات (Sensitive Data Descriptor)
@immutable
class SensitiveDataDescriptor {
  final String fieldName;
  final DataClassification classification;
  final String maskPattern;
  final bool isPii;

  const SensitiveDataDescriptor({
    required this.fieldName,
    required this.classification,
    this.maskPattern = '***',
    this.isPii = true,
  });

  static const defaultDescriptors = <String, SensitiveDataDescriptor>{
    'phone': SensitiveDataDescriptor(fieldName: 'phone', classification: DataClassification.sensitive),
    'phoneNumber': SensitiveDataDescriptor(fieldName: 'phoneNumber', classification: DataClassification.sensitive),
    'email': SensitiveDataDescriptor(fieldName: 'email', classification: DataClassification.confidential),
    'password': SensitiveDataDescriptor(fieldName: 'password', classification: DataClassification.highlySensitive),
    'token': SensitiveDataDescriptor(fieldName: 'token', classification: DataClassification.highlySensitive),
    'otp': SensitiveDataDescriptor(fieldName: 'otp', classification: DataClassification.highlySensitive),
    'cardNumber': SensitiveDataDescriptor(fieldName: 'cardNumber', classification: DataClassification.highlySensitive),
    'cvv': SensitiveDataDescriptor(fieldName: 'cvv', classification: DataClassification.highlySensitive),
    'latitude': SensitiveDataDescriptor(fieldName: 'latitude', classification: DataClassification.confidential),
    'longitude': SensitiveDataDescriptor(fieldName: 'longitude', classification: DataClassification.confidential),
    'nationalId': SensitiveDataDescriptor(fieldName: 'nationalId', classification: DataClassification.highlySensitive),
  };
}
