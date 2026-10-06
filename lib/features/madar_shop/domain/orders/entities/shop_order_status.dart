// تصنيف أبعاد الطلب (المصدر، القناة، طريقة الاستلام، وحالات دورة الحياة)
// MADAR SHOP Order Dimensions & Lifecycle Status
// Pure Dart — Zero UI Dependencies

/// 1. مصدر الطلب التجاري (Order Source)
enum ShopOrderSource {
  marketplace, // تطبيق مدار المركزي للزبائن
  pos,         // نقطة البيع في المتجر
  phone,       // طلب هاتفي مباشر
  external;    // تكامل خارجي / منصات طرف ثالث

  static ShopOrderSource fromString(String? val) {
    if (val == null) return ShopOrderSource.pos;
    switch (val.trim().toLowerCase()) {
      case 'marketplace':
      case 'madar':
      case 'app':
        return ShopOrderSource.marketplace;
      case 'pos':
      case 'in_store':
        return ShopOrderSource.pos;
      case 'phone':
      case 'whatsapp':
        return ShopOrderSource.phone;
      default:
        return ShopOrderSource.external;
    }
  }

  String toDbString() => name;
}

/// 2. القناة التقنية المنفذة للطلب (Order Channel)
enum ShopOrderChannel {
  mobileApp,   // تطبيق الزبون على الهاتف
  desktopPos,  // برنامج نقطة البيع على الويندوز
  whatsapp,    // محادثة واتساب
  callCenter,  // اتصال هاتفي
  web;         // بوابة الويب

  static ShopOrderChannel fromString(String? val) {
    if (val == null) return ShopOrderChannel.desktopPos;
    switch (val.trim().toLowerCase()) {
      case 'mobile_app':
      case 'mobileapp':
      case 'mobile':
        return ShopOrderChannel.mobileApp;
      case 'desktop_pos':
      case 'desktoppos':
      case 'desktop':
      case 'windows':
        return ShopOrderChannel.desktopPos;
      case 'whatsapp':
        return ShopOrderChannel.whatsapp;
      case 'call_center':
      case 'callcenter':
        return ShopOrderChannel.callCenter;
      case 'web':
        return ShopOrderChannel.web;
      default:
        return ShopOrderChannel.desktopPos;
    }
  }

  String toDbString() => name;
}

/// 3. طريقة تلبية واستلام الطلب (Fulfillment Method)
enum ShopOrderFulfillment {
  delivery,      // توصيل عبر كابتن مدار أو سائق المتجر
  inStorePickup, // استلام مباشر من الفرع بواسطة الزبون (Takeaway / Pickup)
  dineIn,        // استهلاك محلي داخل المحل / المطعم
  curbside;      // تسليم عند باب السيارة

  static ShopOrderFulfillment fromString(String? val) {
    if (val == null) return ShopOrderFulfillment.inStorePickup;
    switch (val.trim().toLowerCase()) {
      case 'delivery':
        return ShopOrderFulfillment.delivery;
      case 'in_store_pickup':
      case 'instorepickup':
      case 'pickup':
      case 'takeaway':
        return ShopOrderFulfillment.inStorePickup;
      case 'dine_in':
      case 'dinein':
        return ShopOrderFulfillment.dineIn;
      case 'curbside':
        return ShopOrderFulfillment.curbside;
      default:
        return ShopOrderFulfillment.inStorePickup;
    }
  }

  String toDbString() => name;

  String get displayNameAr {
    switch (this) {
      case ShopOrderFulfillment.delivery:
        return 'توصيل';
      case ShopOrderFulfillment.inStorePickup:
        return 'استلام من المحل';
      case ShopOrderFulfillment.dineIn:
        return 'محلي';
      case ShopOrderFulfillment.curbside:
        return 'تسليم للمركبة';
    }
  }
}

/// 4. حالات دورة حياة الطلب المتطابقة مع نظام مدار الموحد
enum ShopOrderStatus {
  pending,         // قيد الانتظار (طلب جديد)
  accepted,        // تم قبول الطلب وتأكيده
  preparing,       // قيد التجهيز والتعبئة
  ready,           // جاهز للتسليم
  readyForPickup,  // جاهز بانتظار استلام الزبون من المحل (Pickup)
  pickedUp,        // استلمه الزبون من المحل أو استلمه الكابتن
  delivering,      // في الطريق مع الكابتن
  completed,       // مكتمل ومسدد بنجاح
  rejected,        // مرفوض من قبل المتجر
  cancelled;       // ملغي

  static ShopOrderStatus fromString(String? val) {
    if (val == null) return ShopOrderStatus.pending;
    switch (val.trim().toLowerCase()) {
      case 'pending':
        return ShopOrderStatus.pending;
      case 'accepted':
        return ShopOrderStatus.accepted;
      case 'preparing':
      case 'in_progress':
        return ShopOrderStatus.preparing;
      case 'ready':
        return ShopOrderStatus.ready;
      case 'ready_for_pickup':
      case 'readyforpickup':
        return ShopOrderStatus.readyForPickup;
      case 'picked_up':
      case 'pickedup':
        return ShopOrderStatus.pickedUp;
      case 'delivering':
      case 'on_the_way':
        return ShopOrderStatus.delivering;
      case 'completed':
      case 'delivered':
        return ShopOrderStatus.completed;
      case 'rejected':
        return ShopOrderStatus.rejected;
      case 'cancelled':
      case 'canceled':
        return ShopOrderStatus.cancelled;
      default:
        return ShopOrderStatus.pending;
    }
  }

  String toDbString() {
    switch (this) {
      case ShopOrderStatus.pending:
        return 'pending';
      case ShopOrderStatus.accepted:
        return 'accepted';
      case ShopOrderStatus.preparing:
        return 'preparing';
      case ShopOrderStatus.ready:
        return 'ready';
      case ShopOrderStatus.readyForPickup:
        return 'ready_for_pickup';
      case ShopOrderStatus.pickedUp:
        return 'picked_up';
      case ShopOrderStatus.delivering:
        return 'delivering';
      case ShopOrderStatus.completed:
        return 'completed';
      case ShopOrderStatus.rejected:
        return 'rejected';
      case ShopOrderStatus.cancelled:
        return 'cancelled';
    }
  }

  bool get isTerminal =>
      this == ShopOrderStatus.completed ||
      this == ShopOrderStatus.rejected ||
      this == ShopOrderStatus.cancelled;

  bool get isActive => !isTerminal;

  String get displayNameAr {
    switch (this) {
      case ShopOrderStatus.pending:
        return 'قيد الانتظار';
      case ShopOrderStatus.accepted:
        return 'مقبول';
      case ShopOrderStatus.preparing:
        return 'قيد التجهيز';
      case ShopOrderStatus.ready:
        return 'جاهز';
      case ShopOrderStatus.readyForPickup:
        return 'جاهز للاستلام بالمحل';
      case ShopOrderStatus.pickedUp:
        return 'تم الاستلام';
      case ShopOrderStatus.delivering:
        return 'جاري التوصيل';
      case ShopOrderStatus.completed:
        return 'مكتمل';
      case ShopOrderStatus.rejected:
        return 'مرفوض';
      case ShopOrderStatus.cancelled:
        return 'ملغي';
    }
  }
}
