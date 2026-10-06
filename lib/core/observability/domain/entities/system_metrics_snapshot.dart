import 'package:flutter/foundation.dart';

/// لقطة المؤشرات العامة الشاملة للنظام (System Metrics Snapshot)
@immutable
class SystemMetricsSnapshot {
  final String snapshotId;
  final int activeUsers;
  final int onlineDrivers;
  final int availableDrivers;
  final int busyDrivers;
  final int activeRides;
  final int activeDeliveries;
  final double ordersPerMin;
  final double rideAcceptanceRate; // 0.0 .. 1.0
  final double cancellationRate; // 0.0 .. 1.0
  final double gpsUpdateRatePerSec;
  final double heartbeatSuccessRate; // 0.0 .. 1.0
  final int reconnectionCount;
  final int avgEtaLatencyMs;
  final double riskEvaluationsPerMin;
  final double blockRate; // 0.0 .. 1.0
  final double challengeRate; // 0.0 .. 1.0
  final int failedTransactionsCount;
  final int firestoreErrorsCount;
  final DateTime timestamp;

  const SystemMetricsSnapshot({
    required this.snapshotId,
    this.activeUsers = 0,
    this.onlineDrivers = 0,
    this.availableDrivers = 0,
    this.busyDrivers = 0,
    this.activeRides = 0,
    this.activeDeliveries = 0,
    this.ordersPerMin = 0.0,
    this.rideAcceptanceRate = 1.0,
    this.cancellationRate = 0.0,
    this.gpsUpdateRatePerSec = 0.0,
    this.heartbeatSuccessRate = 1.0,
    this.reconnectionCount = 0,
    this.avgEtaLatencyMs = 0,
    this.riskEvaluationsPerMin = 0.0,
    this.blockRate = 0.0,
    this.challengeRate = 0.0,
    this.failedTransactionsCount = 0,
    this.firestoreErrorsCount = 0,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'snapshotId': snapshotId,
      'activeUsers': activeUsers,
      'onlineDrivers': onlineDrivers,
      'availableDrivers': availableDrivers,
      'busyDrivers': busyDrivers,
      'activeRides': activeRides,
      'activeDeliveries': activeDeliveries,
      'ordersPerMin': ordersPerMin,
      'rideAcceptanceRate': rideAcceptanceRate,
      'cancellationRate': cancellationRate,
      'gpsUpdateRatePerSec': gpsUpdateRatePerSec,
      'heartbeatSuccessRate': heartbeatSuccessRate,
      'reconnectionCount': reconnectionCount,
      'avgEtaLatencyMs': avgEtaLatencyMs,
      'riskEvaluationsPerMin': riskEvaluationsPerMin,
      'blockRate': blockRate,
      'challengeRate': challengeRate,
      'failedTransactionsCount': failedTransactionsCount,
      'firestoreErrorsCount': firestoreErrorsCount,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SystemMetricsSnapshot.fromMap(Map<String, dynamic> map, String docId) {
    return SystemMetricsSnapshot(
      snapshotId: docId,
      activeUsers: (map['activeUsers'] as num?)?.toInt() ?? 0,
      onlineDrivers: (map['onlineDrivers'] as num?)?.toInt() ?? 0,
      availableDrivers: (map['availableDrivers'] as num?)?.toInt() ?? 0,
      busyDrivers: (map['busyDrivers'] as num?)?.toInt() ?? 0,
      activeRides: (map['activeRides'] as num?)?.toInt() ?? 0,
      activeDeliveries: (map['activeDeliveries'] as num?)?.toInt() ?? 0,
      ordersPerMin: (map['ordersPerMin'] as num?)?.toDouble() ?? 0.0,
      rideAcceptanceRate: (map['rideAcceptanceRate'] as num?)?.toDouble() ?? 1.0,
      cancellationRate: (map['cancellationRate'] as num?)?.toDouble() ?? 0.0,
      gpsUpdateRatePerSec: (map['gpsUpdateRatePerSec'] as num?)?.toDouble() ?? 0.0,
      heartbeatSuccessRate: (map['heartbeatSuccessRate'] as num?)?.toDouble() ?? 1.0,
      reconnectionCount: (map['reconnectionCount'] as num?)?.toInt() ?? 0,
      avgEtaLatencyMs: (map['avgEtaLatencyMs'] as num?)?.toInt() ?? 0,
      riskEvaluationsPerMin: (map['riskEvaluationsPerMin'] as num?)?.toDouble() ?? 0.0,
      blockRate: (map['blockRate'] as num?)?.toDouble() ?? 0.0,
      challengeRate: (map['challengeRate'] as num?)?.toDouble() ?? 0.0,
      failedTransactionsCount: (map['failedTransactionsCount'] as num?)?.toInt() ?? 0,
      firestoreErrorsCount: (map['firestoreErrorsCount'] as num?)?.toInt() ?? 0,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
