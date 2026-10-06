/// نموذج عنصر سلة الكاشير
class PosCartItem {
  final String id;
  final String mealId;
  final String name;
  final double unitPrice;
  int quantity;
  final String? selectedSize;
  final List<Map<String, dynamic>> selectedAddons;
  String? notes;
  final String? imageUrl;

  PosCartItem({
    required this.id,
    required this.mealId,
    required this.name,
    required this.unitPrice,
    this.quantity = 1,
    this.selectedSize,
    this.selectedAddons = const [],
    this.notes,
    this.imageUrl,
  });

  /// احتساب سعر الإضافات للقطعة الواحدة
  double get addonsPricePerUnit {
    double sum = 0;
    for (var addon in selectedAddons) {
      final p = addon['price'];
      if (p is num) {
        sum += p.toDouble();
      } else if (p != null) {
        sum += double.tryParse(p.toString()) ?? 0;
      }
    }
    return sum;
  }

  /// السعر الإفرادي شامل الإضافات
  double get singleItemTotal => unitPrice + addonsPricePerUnit;

  /// السعر الإجمالي للعنصر مضروباً بالكمية
  double get totalPrice => singleItemTotal * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mealId': mealId,
      'name': name,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'selectedSize': selectedSize,
      'selectedAddons': selectedAddons,
      'notes': notes,
      'imageUrl': imageUrl,
      'totalPrice': totalPrice,
    };
  }

  factory PosCartItem.fromMap(Map<String, dynamic> map) {
    double parseNum(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 1;
      return 1;
    }

    final addons = <Map<String, dynamic>>[];
    final rawAddons = map['selectedAddons'];
    if (rawAddons is List) {
      for (final a in rawAddons) {
        if (a is Map) {
          addons.add(Map<String, dynamic>.from(a));
        }
      }
    }

    return PosCartItem(
      id: (map['id'] ?? '').toString(),
      mealId: (map['mealId'] ?? map['id'] ?? '').toString(),
      name: (map['name'] ?? map['title'] ?? 'وجبة').toString(),
      unitPrice: parseNum(map['unitPrice'] ?? map['price']),
      quantity: parseInt(map['quantity']),
      selectedSize: map['selectedSize']?.toString(),
      selectedAddons: addons,
      notes: map['notes']?.toString(),
      imageUrl: (map['imageUrl'] ?? map['photoUrl'])?.toString(),
    );
  }
}
