// عقد إيجار قفل المزامنة لمنع التزاحم والتعافي بعد الانهيار (MADAR SHOP Sync Lease)
// Pure Dart — Zero UI Dependencies

class SyncLease {
  final String leaseId;
  final String workerId;
  final DateTime acquiredAt;
  final DateTime expiresAt;

  const SyncLease({
    required this.leaseId,
    required this.workerId,
    required this.acquiredAt,
    required this.expiresAt,
  });

  bool isExpired([DateTime? now]) {
    final current = now ?? DateTime.now();
    return current.isAfter(expiresAt);
  }

  SyncLease renew(Duration extension) {
    return SyncLease(
      leaseId: leaseId,
      workerId: workerId,
      acquiredAt: acquiredAt,
      expiresAt: DateTime.now().add(extension),
    );
  }

  Map<String, dynamic> toJson() => {
        'leaseId': leaseId,
        'workerId': workerId,
        'acquiredAt': acquiredAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory SyncLease.fromJson(Map<String, dynamic> json) {
    return SyncLease(
      leaseId: json['leaseId'] as String,
      workerId: json['workerId'] as String,
      acquiredAt: DateTime.parse(json['acquiredAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}
