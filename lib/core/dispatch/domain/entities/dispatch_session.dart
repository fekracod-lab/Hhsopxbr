import 'package:flutter/foundation.dart';
import '../enums/dispatch_enums.dart';

/// جلسة التوزيع المستمرة (Dispatch Session Tracking)
@immutable
class DispatchSession {
  final String sessionId;
  final String orderId;
  final DispatchType dispatchType;
  final int currentRingIndex;
  final DispatchStatus status;
  final String? assignedDriverId;
  final String? assignedDriverName;
  final String? assignedDriverPhone;
  final List<String> offersSent;
  final List<String> rejectedDriverIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DispatchSession({
    required this.sessionId,
    required this.orderId,
    required this.dispatchType,
    this.currentRingIndex = 0,
    this.status = DispatchStatus.searching,
    this.assignedDriverId,
    this.assignedDriverName,
    this.assignedDriverPhone,
    this.offersSent = const [],
    this.rejectedDriverIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  DispatchSession copyWith({
    String? sessionId,
    String? orderId,
    DispatchType? dispatchType,
    int? currentRingIndex,
    DispatchStatus? status,
    String? assignedDriverId,
    String? assignedDriverName,
    String? assignedDriverPhone,
    List<String>? offersSent,
    List<String>? rejectedDriverIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DispatchSession(
      sessionId: sessionId ?? this.sessionId,
      orderId: orderId ?? this.orderId,
      dispatchType: dispatchType ?? this.dispatchType,
      currentRingIndex: currentRingIndex ?? this.currentRingIndex,
      status: status ?? this.status,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      assignedDriverName: assignedDriverName ?? this.assignedDriverName,
      assignedDriverPhone: assignedDriverPhone ?? this.assignedDriverPhone,
      offersSent: offersSent ?? this.offersSent,
      rejectedDriverIds: rejectedDriverIds ?? this.rejectedDriverIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'orderId': orderId,
      'dispatchType': dispatchType.key,
      'currentRingIndex': currentRingIndex,
      'status': status.key,
      'assignedDriverId': assignedDriverId,
      'assignedDriverName': assignedDriverName,
      'assignedDriverPhone': assignedDriverPhone,
      'offersSent': offersSent,
      'rejectedDriverIds': rejectedDriverIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DispatchSession.fromMap(Map<String, dynamic> map, String docId) {
    return DispatchSession(
      sessionId: docId,
      orderId: map['orderId']?.toString() ?? '',
      dispatchType: DispatchType.fromString(map['dispatchType']?.toString()),
      currentRingIndex: (map['currentRingIndex'] as num?)?.toInt() ?? 0,
      status: DispatchStatus.fromString(map['status']?.toString()),
      assignedDriverId: map['assignedDriverId']?.toString(),
      assignedDriverName: map['assignedDriverName']?.toString(),
      assignedDriverPhone: map['assignedDriverPhone']?.toString(),
      offersSent: (map['offersSent'] as List?)?.map((e) => e.toString()).toList() ?? [],
      rejectedDriverIds: (map['rejectedDriverIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
