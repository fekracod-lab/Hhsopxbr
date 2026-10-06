import 'package:flutter/foundation.dart';
import '../enums/realtime_enums.dart';

/// سجل نبض الاتصال الدوري للسائق (Driver Heartbeat Record)
@immutable
class HeartbeatRecord {
  final String heartbeatId;
  final String driverId;
  final String sessionId;
  final HeartbeatStatus status;
  final DateTime clientTimestamp;
  final DateTime serverTimestamp;
  final int sequenceNumber;

  const HeartbeatRecord({
    required this.heartbeatId,
    required this.driverId,
    required this.sessionId,
    this.status = HeartbeatStatus.healthy,
    required this.clientTimestamp,
    required this.serverTimestamp,
    this.sequenceNumber = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'heartbeatId': heartbeatId,
      'driverId': driverId,
      'sessionId': sessionId,
      'status': status.key,
      'clientTimestamp': clientTimestamp.toIso8601String(),
      'serverTimestamp': serverTimestamp.toIso8601String(),
      'sequenceNumber': sequenceNumber,
    };
  }

  factory HeartbeatRecord.fromMap(Map<String, dynamic> map, String docId) {
    return HeartbeatRecord(
      heartbeatId: docId,
      driverId: map['driverId']?.toString() ?? '',
      sessionId: map['sessionId']?.toString() ?? '',
      status: HeartbeatStatus.values.firstWhere(
        (s) => s.key == map['status']?.toString(),
        orElse: () => HeartbeatStatus.healthy,
      ),
      clientTimestamp: map['clientTimestamp'] != null
          ? DateTime.tryParse(map['clientTimestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      serverTimestamp: map['serverTimestamp'] != null
          ? DateTime.tryParse(map['serverTimestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sequenceNumber: (map['sequenceNumber'] as num?)?.toInt() ?? 0,
    );
  }
}
