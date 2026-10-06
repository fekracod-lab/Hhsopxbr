// نقطة التفتيش لتتبع آخر موقع متزامن مع الخادم (MADAR SHOP Sync Checkpoint)
// Pure Dart — Zero UI Dependencies

class SyncCheckpoint {
  final String businessId;
  final String branchId;
  final String? lastServerCursor;
  final DateTime? lastServerTimestamp;
  final DateTime lastSyncAt;
  final int sequenceNumber;

  const SyncCheckpoint({
    required this.businessId,
    required this.branchId,
    this.lastServerCursor,
    this.lastServerTimestamp,
    required this.lastSyncAt,
    this.sequenceNumber = 0,
  });

  SyncCheckpoint advance({
    required String? newCursor,
    required DateTime? newServerTimestamp,
    required DateTime syncTime,
    int? newSequence,
  }) {
    return SyncCheckpoint(
      businessId: businessId,
      branchId: branchId,
      lastServerCursor: newCursor ?? lastServerCursor,
      lastServerTimestamp: newServerTimestamp ?? lastServerTimestamp,
      lastSyncAt: syncTime,
      sequenceNumber: newSequence ?? (sequenceNumber + 1),
    );
  }

  Map<String, dynamic> toJson() => {
        'businessId': businessId,
        'branchId': branchId,
        'lastServerCursor': lastServerCursor,
        'lastServerTimestamp': lastServerTimestamp?.toIso8601String(),
        'lastSyncAt': lastSyncAt.toIso8601String(),
        'sequenceNumber': sequenceNumber,
      };

  factory SyncCheckpoint.fromJson(Map<String, dynamic> json) {
    return SyncCheckpoint(
      businessId: json['businessId'] as String,
      branchId: json['branchId'] as String,
      lastServerCursor: json['lastServerCursor'] as String?,
      lastServerTimestamp: json['lastServerTimestamp'] != null
          ? DateTime.parse(json['lastServerTimestamp'] as String)
          : null,
      lastSyncAt: DateTime.parse(json['lastSyncAt'] as String),
      sequenceNumber: (json['sequenceNumber'] as num?)?.toInt() ?? 0,
    );
  }
}
