// حالات حل التعارضات المسجلة (MADAR SHOP Conflict Resolution Status)
// Pure Dart — Zero UI Dependencies

enum ConflictResolutionStatus {
  unresolved,
  resolvedLocalWins,
  resolvedServerWins,
  resolvedManual,
  rejected;

  bool get isResolved => this != unresolved;
}
