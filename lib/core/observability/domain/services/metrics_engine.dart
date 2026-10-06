import '../entities/metric_sample.dart';
import '../entities/system_metrics_snapshot.dart';

/// محرك تجميع وحساب المؤشرات التشغيلية الحية (Realtime Metrics Engine)
class MetricsEngine {
  final List<MetricSample> _samples = [];
  final List<DateTime> _orderTimestamps = [];
  final List<DateTime> _gpsTimestamps = [];
  final List<DateTime> _cancellationTimestamps = [];
  final List<DateTime> _totalRideTimestamps = [];

  int _onlineDrivers = 0;
  int _availableDrivers = 0;
  int _busyDrivers = 0;
  int _activeRides = 0;
  int _activeDeliveries = 0;
  int _failedTransactions = 0;
  int _firestoreErrors = 0;
  int _reconnections = 0;
  int _successfulHeartbeats = 0;
  int _totalHeartbeats = 0;

  MetricsEngine();

  void recordSample(MetricSample sample) {
    _samples.add(sample);
  }

  void updateDriverCounts({
    required int online,
    required int available,
    required int busy,
  }) {
    _onlineDrivers = online;
    _availableDrivers = available;
    _busyDrivers = busy;
  }

  void updateActiveOperations({
    required int activeRides,
    required int activeDeliveries,
  }) {
    _activeRides = activeRides;
    _activeDeliveries = activeDeliveries;
  }

  void recordOrderCreated({DateTime? now}) {
    _orderTimestamps.add(now ?? DateTime.now());
  }

  void recordGpsUpdate({DateTime? now}) {
    _gpsTimestamps.add(now ?? DateTime.now());
  }

  void recordCancellation({DateTime? now}) {
    _cancellationTimestamps.add(now ?? DateTime.now());
  }

  void recordRideRequested({DateTime? now}) {
    _totalRideTimestamps.add(now ?? DateTime.now());
  }

  void recordHeartbeat({required bool isSuccess}) {
    _totalHeartbeats++;
    if (isSuccess) _successfulHeartbeats++;
  }

  void incrementFailedTransactions() => _failedTransactions++;
  void incrementFirestoreErrors() => _firestoreErrors++;
  void incrementReconnections() => _reconnections++;

  /// توليد لقطة شاملة للمؤشرات التشغيلية الحالية
  SystemMetricsSnapshot generateSnapshot({DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    // 1. حساب معدل الطلبات في الدقيقة (Orders per Minute - 1m window)
    final oneMinAgo = currentTime.subtract(const Duration(minutes: 1));
    _orderTimestamps.removeWhere((t) => t.isBefore(oneMinAgo));
    final ordersPerMin = _orderTimestamps.length.toDouble();

    // 2. حساب معدل تحديثات الـ GPS في الثانية (10s window)
    final tenSecAgo = currentTime.subtract(const Duration(seconds: 10));
    _gpsTimestamps.removeWhere((t) => t.isBefore(tenSecAgo));
    final gpsRatePerSec = (_gpsTimestamps.length / 10.0);

    // 3. حساب نسبة الإلغاء في آخر 15 دقيقة
    final fifteenMinAgo = currentTime.subtract(const Duration(minutes: 15));
    _cancellationTimestamps.removeWhere((t) => t.isBefore(fifteenMinAgo));
    _totalRideTimestamps.removeWhere((t) => t.isBefore(fifteenMinAgo));
    final totalRides = _totalRideTimestamps.length;
    final cancellationRate = totalRides > 0
        ? (_cancellationTimestamps.length / totalRides).clamp(0.0, 1.0)
        : 0.0;

    // 4. حساب نسبة نجاح النبضات
    final heartbeatSuccessRate = _totalHeartbeats > 0
        ? (_successfulHeartbeats / _totalHeartbeats).clamp(0.0, 1.0)
        : 1.0;

    final snapshotId = 'snap-${currentTime.millisecondsSinceEpoch}';

    return SystemMetricsSnapshot(
      snapshotId: snapshotId,
      activeUsers: _onlineDrivers + _activeRides + 50, // Approximation
      onlineDrivers: _onlineDrivers,
      availableDrivers: _availableDrivers,
      busyDrivers: _busyDrivers,
      activeRides: _activeRides,
      activeDeliveries: _activeDeliveries,
      ordersPerMin: ordersPerMin,
      cancellationRate: cancellationRate,
      gpsUpdateRatePerSec: gpsRatePerSec,
      heartbeatSuccessRate: heartbeatSuccessRate,
      reconnectionCount: _reconnections,
      failedTransactionsCount: _failedTransactions,
      firestoreErrorsCount: _firestoreErrors,
      timestamp: currentTime,
    );
  }

  void clear() {
    _samples.clear();
    _orderTimestamps.clear();
    _gpsTimestamps.clear();
    _cancellationTimestamps.clear();
    _totalRideTimestamps.clear();
    _onlineDrivers = 0;
    _availableDrivers = 0;
    _busyDrivers = 0;
    _activeRides = 0;
    _activeDeliveries = 0;
    _failedTransactions = 0;
    _firestoreErrors = 0;
    _reconnections = 0;
    _successfulHeartbeats = 0;
    _totalHeartbeats = 0;
  }
}
