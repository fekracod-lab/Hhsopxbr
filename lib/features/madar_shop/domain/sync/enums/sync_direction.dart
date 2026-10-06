// اتجاه حركة البيانات في طبقة المزامنة (MADAR SHOP Sync Direction)
// Pure Dart — Zero UI Dependencies

enum SyncDirection {
  outbound, // من الجهاز المحلي إلى الخادم (Push / Outbox)
  inbound;  // من الخادم إلى الجهاز المحلي (Pull / Inbox)
}
