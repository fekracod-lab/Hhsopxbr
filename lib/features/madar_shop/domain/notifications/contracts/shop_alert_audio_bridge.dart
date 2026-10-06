// عقود جسر التنبيهات الصوتية الصاخبة لطلبات المتجر (Audio Alert Bridge Contract)
// Pure Dart — Zero UI Dependencies

abstract class IShopAlertAudioBridge {
  /// تشغيل نغمة رنين الطلب الجديد بشكل متكرر حتى يتفاعل الكاشير/المتجر
  Future<void> startOrderIncomingLoop({
    required String orderId,
    String? soundAssetPath,
  });

  /// إيقاف الرنين المتكرر فور تفاعل المتجر وقبول أو فتح الطلب
  Future<void> stopOrderIncomingLoop({required String orderId});

  /// تشغيل رنة إشعار قصيرة لمرة واحدة (مثل إتمام البيع أو نفاد المخزون)
  Future<void> playOneShotChime({
    String? soundAssetPath,
  });

  /// هل هناك رنين متكرر يعمل حالياً
  bool get isAudioAlertPlaying;
}
