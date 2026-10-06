import 'cart_item.dart';

/// سلة مشتريات معلقة لزبون في الطابور (Hold Cart Entity)
class HoldCart {
  final String id;
  final String customerName;
  final List<PosCartItem> items;
  final double discount;
  final DateTime savedAt;

  const HoldCart({
    required this.id,
    required this.customerName,
    required this.items,
    this.discount = 0.0,
    required this.savedAt,
  });

  double get total => items.fold(0.0, (sum, it) => sum + it.totalPrice) - discount;
  int get itemCount => items.fold(0, (sum, it) => sum + it.quantity);
}
