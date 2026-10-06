// نموذج بيانات نية حركة المخزون (MADAR SHOP Inventory Movement Intent Model)
// Pure Dart — Zero Flutter / Firebase SDK Dependencies

import '../../../domain/pos/entities/inventory_movement_intent.dart';
import '../../../domain/pos/enums/inventory_movement_type.dart';

class InventoryMovementIntentModel {
  const InventoryMovementIntentModel._();

  static Map<String, dynamic> toMap(InventoryMovementIntent intent) {
    return {
      'intentId': intent.intentId,
      'businessId': intent.businessId,
      'branchId': intent.branchId,
      'productId': intent.productId,
      'variantId': intent.variantId,
      'quantity': intent.quantity,
      'movementType': intent.movementType.toDbString(),
      'referenceType': intent.referenceType,
      'referenceId': intent.referenceId,
      'requestedAt': intent.requestedAt.toIso8601String(),
      'metadata': intent.metadata,
    };
  }

  static InventoryMovementIntent fromMap(Map<String, dynamic> map) {
    return InventoryMovementIntent(
      intentId: map['intentId'] as String? ?? '',
      businessId: map['businessId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      variantId: map['variantId'] as String?,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      movementType: InventoryMovementType.sale,
      referenceType: map['referenceType'] as String? ?? 'SALE',
      referenceId: map['referenceId'] as String? ?? '',
      requestedAt: DateTime.tryParse(map['requestedAt'] as String? ?? '') ?? DateTime.now(),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }
}
