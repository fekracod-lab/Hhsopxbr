// سياسات الإذن بالعمليات بدون اتصال (MADAR SHOP Offline Operation Permission)
// Pure Dart — Zero UI Dependencies

enum OfflineOperationPermission {
  allow,
  allowWithWarning,
  block;

  bool get isAllowed => this == allow || this == allowWithWarning;
  bool get isBlocked => this == block;
  bool get hasWarning => this == allowWithWarning;
}
