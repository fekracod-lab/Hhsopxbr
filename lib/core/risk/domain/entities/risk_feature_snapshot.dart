import 'package:flutter/foundation.dart';

/// لقطة بيانات وميزات التقييم الثابتة (Immutable Risk Feature Snapshot)
@immutable
class RiskFeatureSnapshot {
  final Map<String, dynamic> velocityFeatures;
  final Map<String, dynamic> deviceFeatures;
  final Map<String, dynamic> locationFeatures;
  final Map<String, dynamic> financialFeatures;
  final Map<String, dynamic> orderFeatures;
  final Map<String, dynamic> couponFeatures;
  final Map<String, dynamic> behaviorFeatures;
  final Map<String, dynamic> accountFeatures;

  const RiskFeatureSnapshot({
    this.velocityFeatures = const {},
    this.deviceFeatures = const {},
    this.locationFeatures = const {},
    this.financialFeatures = const {},
    this.orderFeatures = const {},
    this.couponFeatures = const {},
    this.behaviorFeatures = const {},
    this.accountFeatures = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'velocityFeatures': velocityFeatures,
      'deviceFeatures': deviceFeatures,
      'locationFeatures': locationFeatures,
      'financialFeatures': financialFeatures,
      'orderFeatures': orderFeatures,
      'couponFeatures': couponFeatures,
      'behaviorFeatures': behaviorFeatures,
      'accountFeatures': accountFeatures,
    };
  }

  factory RiskFeatureSnapshot.fromMap(Map<String, dynamic> map) {
    return RiskFeatureSnapshot(
      velocityFeatures: map['velocityFeatures'] is Map ? Map<String, dynamic>.from(map['velocityFeatures'] as Map) : {},
      deviceFeatures: map['deviceFeatures'] is Map ? Map<String, dynamic>.from(map['deviceFeatures'] as Map) : {},
      locationFeatures: map['locationFeatures'] is Map ? Map<String, dynamic>.from(map['locationFeatures'] as Map) : {},
      financialFeatures: map['financialFeatures'] is Map ? Map<String, dynamic>.from(map['financialFeatures'] as Map) : {},
      orderFeatures: map['orderFeatures'] is Map ? Map<String, dynamic>.from(map['orderFeatures'] as Map) : {},
      couponFeatures: map['couponFeatures'] is Map ? Map<String, dynamic>.from(map['couponFeatures'] as Map) : {},
      behaviorFeatures: map['behaviorFeatures'] is Map ? Map<String, dynamic>.from(map['behaviorFeatures'] as Map) : {},
      accountFeatures: map['accountFeatures'] is Map ? Map<String, dynamic>.from(map['accountFeatures'] as Map) : {},
    );
  }
}
