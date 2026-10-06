import 'package:flutter/foundation.dart';
import '../enums/dispatch_enums.dart';

/// نتيجة فحص أهلية السائق (Driver Eligibility Result)
@immutable
class DriverEligibilityResult {
  final bool isEligible;
  final DriverEligibilityStatus status;
  final String? rejectionReason;

  const DriverEligibilityResult._({
    required this.isEligible,
    required this.status,
    this.rejectionReason,
  });

  factory DriverEligibilityResult.eligible() {
    return const DriverEligibilityResult._(
      isEligible: true,
      status: DriverEligibilityStatus.eligible,
    );
  }

  factory DriverEligibilityResult.ineligible(DriverEligibilityStatus status, String reason) {
    return DriverEligibilityResult._(
      isEligible: false,
      status: status,
      rejectionReason: reason,
    );
  }
}
