import 'package:flutter/foundation.dart';
import '../entities/dispatch_candidate.dart';

/// ⭕ حلقة البحث الجغرافي الدائرية
@immutable
class SearchRing {
  final int index;
  final double minRadiusMeters;
  final double maxRadiusMeters;

  const SearchRing({
    required this.index,
    required this.minRadiusMeters,
    required this.maxRadiusMeters,
  });

  bool containsDistance(double distanceMeters) {
    return distanceMeters >= minRadiusMeters && distanceMeters <= maxRadiusMeters;
  }
}

/// محرك دوائر البحث المتوسعة الذكي (Expanding Ring Engine)
class ExpandingRingEngine {
  final List<SearchRing> rings;

  const ExpandingRingEngine({
    this.rings = defaultRings,
  });

  /// الحلقات الافتراضية للتوزيع:
  /// Ring 0: 0 – 1.5 كم
  /// Ring 1: 1.5 – 3.5 كم
  /// Ring 2: 3.5 – 6.0 كم
  /// Ring 3: 6.0 – 10.0 كم
  static const List<SearchRing> defaultRings = [
    SearchRing(index: 0, minRadiusMeters: 0, maxRadiusMeters: 1500),
    SearchRing(index: 1, minRadiusMeters: 1500, maxRadiusMeters: 3500),
    SearchRing(index: 2, minRadiusMeters: 3500, maxRadiusMeters: 6000),
    SearchRing(index: 3, minRadiusMeters: 6000, maxRadiusMeters: 10000),
  ];

  /// جلب حلقة بحث بحسب الفهرس
  SearchRing? getRing(int index) {
    if (index >= 0 && index < rings.length) {
      return rings[index];
    }
    return null;
  }

  /// هل تم استنفاد كافة حلقات البحث المتاحة؟
  bool isExhausted(int ringIndex) => ringIndex >= rings.length;

  /// تصفية المرشحين المتواجدين داخل حلقة بحث محددة
  List<DispatchCandidate> filterCandidatesInRing({
    required List<DispatchCandidate> candidates,
    required int ringIndex,
  }) {
    final ring = getRing(ringIndex);
    if (ring == null) return [];

    return candidates.where((c) => ring.containsDistance(c.distanceMeters)).toList();
  }
}
