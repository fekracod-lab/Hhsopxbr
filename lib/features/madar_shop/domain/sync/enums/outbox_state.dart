// حالات سجلات صندوق الصادر المحلي (MADAR SHOP Outbox State)
// Pure Dart — Zero UI Dependencies

enum OutboxState {
  pending,
  inFlight,
  acknowledged,
  failed,
  conflict;

  bool get canDispatch => this == pending || this == failed;
  bool get isInFlight => this == inFlight;
  bool get isCompleted => this == acknowledged;
}
