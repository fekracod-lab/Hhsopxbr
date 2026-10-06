// حالات الاتصال بالشبكة والتحقق الفعلي من الوصول (MADAR SHOP Connectivity State)
// Pure Dart — Zero UI Dependencies

enum ConnectivityState {
  online,
  offline,
  unstable,
  unknown;

  bool get isConnected => this == online;
  bool get isDisconnected => this == offline;
}
