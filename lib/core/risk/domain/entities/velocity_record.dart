import 'package:flutter/foundation.dart';
import '../enums/risk_enums.dart';

/// سجل تتبع تكرار وسرعة العمليات الحركية (Velocity Record)
@immutable
class VelocityRecord {
  final String recordId;
  final String subjectId;
  final String actionType;
  final VelocityWindow window;
  final int count;
  final int limit;
  final DateTime firstEventAt;
  final DateTime lastEventAt;
  final bool exceeded;

  const VelocityRecord({
    required this.recordId,
    required this.subjectId,
    required this.actionType,
    required this.window,
    required this.count,
    required this.limit,
    required this.firstEventAt,
    required this.lastEventAt,
    required this.exceeded,
  });

  Map<String, dynamic> toMap() {
    return {
      'recordId': recordId,
      'subjectId': subjectId,
      'actionType': actionType,
      'window': window.key,
      'count': count,
      'limit': limit,
      'firstEventAt': firstEventAt.toIso8601String(),
      'lastEventAt': lastEventAt.toIso8601String(),
      'exceeded': exceeded,
    };
  }

  factory VelocityRecord.fromMap(Map<String, dynamic> map, String docId) {
    return VelocityRecord(
      recordId: docId,
      subjectId: map['subjectId']?.toString() ?? '',
      actionType: map['actionType']?.toString() ?? '',
      window: VelocityWindow.values.firstWhere(
        (w) => w.key == map['window']?.toString(),
        orElse: () => VelocityWindow.oneHour,
      ),
      count: (map['count'] as num?)?.toInt() ?? 0,
      limit: (map['limit'] as num?)?.toInt() ?? 10,
      firstEventAt: map['firstEventAt'] != null
          ? DateTime.tryParse(map['firstEventAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastEventAt: map['lastEventAt'] != null
          ? DateTime.tryParse(map['lastEventAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      exceeded: map['exceeded'] == true,
    );
  }
}
