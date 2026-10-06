import 'package:flutter/foundation.dart';
import '../enums/dispatch_enums.dart';
import 'dispatch_session.dart';

/// نتيجة التوزيع النهائي للطلب (Dispatch Result)
@immutable
class DispatchResult {
  final bool isSuccess;
  final String? assignedDriverId;
  final String? assignedDriverName;
  final String? assignedDriverPhone;
  final DispatchSession? dispatchSession;
  final DispatchFailureReason failureReason;
  final String? errorMessage;

  const DispatchResult._({
    required this.isSuccess,
    this.assignedDriverId,
    this.assignedDriverName,
    this.assignedDriverPhone,
    this.dispatchSession,
    this.failureReason = DispatchFailureReason.none,
    this.errorMessage,
  });

  factory DispatchResult.assigned({
    required String driverId,
    required String driverName,
    required String driverPhone,
    required DispatchSession session,
  }) {
    return DispatchResult._(
      isSuccess: true,
      assignedDriverId: driverId,
      assignedDriverName: driverName,
      assignedDriverPhone: driverPhone,
      dispatchSession: session,
    );
  }

  factory DispatchResult.failed({
    required DispatchFailureReason reason,
    required String errorMessage,
    DispatchSession? session,
  }) {
    return DispatchResult._(
      isSuccess: false,
      failureReason: reason,
      errorMessage: errorMessage,
      dispatchSession: session,
    );
  }
}
