// حدث صندوق الوارد لتطبيق التحديثات القادمة من الخادم (MADAR SHOP Inbox Event)
// Pure Dart — Zero UI Dependencies

class InboxEvent {
  final String eventId;
  final String businessId;
  final String branchId;
  final String entityType; // e.g. "PRODUCT", "INVENTORY", "PRICE", "SETTING"
  final String entityId;

  final String serverCursor;
  final DateTime serverTimestamp;
  final Map<String, dynamic> payload;

  final bool isApplied;
  final DateTime? appliedAt;

  const InboxEvent({
    required this.eventId,
    required this.businessId,
    required this.branchId,
    required this.entityType,
    required this.entityId,
    required this.serverCursor,
    required this.serverTimestamp,
    required this.payload,
    this.isApplied = false,
    this.appliedAt,
  });

  InboxEvent markApplied([DateTime? timestamp]) {
    return InboxEvent(
      eventId: eventId,
      businessId: businessId,
      branchId: branchId,
      entityType: entityType,
      entityId: entityId,
      serverCursor: serverCursor,
      serverTimestamp: serverTimestamp,
      payload: payload,
      isApplied: true,
      appliedAt: timestamp ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'businessId': businessId,
        'branchId': branchId,
        'entityType': entityType,
        'entityId': entityId,
        'serverCursor': serverCursor,
        'serverTimestamp': serverTimestamp.toIso8601String(),
        'payload': payload,
        'isApplied': isApplied,
        'appliedAt': appliedAt?.toIso8601String(),
      };

  factory InboxEvent.fromJson(Map<String, dynamic> json) {
    return InboxEvent(
      eventId: json['eventId'] as String,
      businessId: json['businessId'] as String,
      branchId: json['branchId'] as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      serverCursor: json['serverCursor'] as String,
      serverTimestamp: DateTime.parse(json['serverTimestamp'] as String),
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      isApplied: json['isApplied'] as bool? ?? false,
      appliedAt: json['appliedAt'] != null
          ? DateTime.parse(json['appliedAt'] as String)
          : null,
    );
  }
}
