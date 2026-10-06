// مستويات حداثة البيانات المخزنة محلياً (MADAR SHOP Cache Freshness)
// Pure Dart — Zero UI Dependencies

enum CacheFreshness {
  fresh,
  stale,
  expired;

  bool get isUsable => this == fresh || this == stale;
  bool get requiresRefresh => this != fresh;
}
