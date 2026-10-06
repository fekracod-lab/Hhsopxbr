# MADAR SHOP S2 — POS Transaction Engine Architectural & Execution Report

**Date:** 2026-09-05  
**Engine:** MADAR SHOP POS Transaction Engine (Phase S2)  
**Status:** **IMPLEMENTED** (Domain & Application Engine Verified / Live Cloud Functions & Live POS Hardware Integration Pending)  
**Framework:** Flutter & Pure Dart (Clean Architecture + Sound Null Safety)  

---

## 1. Executive Summary
Phase S2 implements the core **POS Transaction Engine** for the MADAR SHOP platform within `lib/features/madar_shop/`. 
In strict accordance with the project directives and the 30GB disk quota constraint, this phase introduces **Zero UI changes** and **Zero unnecessary third-party package dependencies**. 
It defines the complete transactional lifecycle: from product resolution (Barcode ➔ SKU ➔ ID ➔ Search) and in-memory multi-item cart management (supporting weighable fractional units, variants, and line/order discounts) through deterministic monetary calculation, multi-method payment validation (Cash, Card, Digital, Credit), customer ledger entries, inventory movement intents, idempotent checkout coordination, and immutable receipt snapshots.

---

## 2. Files Created

### Domain Layer (`lib/features/madar_shop/domain/pos/`)
1. `value_objects/currency.dart`: Value object for ISO/local currencies with default Iraqi Dinar (`IQD`, scale 0) and US Dollar (`USD`, scale 2).
2. `value_objects/money.dart`: Precision value object operating on integer minor units to eliminate floating-point drift.
3. `value_objects/idempotency_key.dart`: Value object encapsulating transactional idempotency keys and TTL expiry.
4. `value_objects/pricing_snapshot.dart`: Immutable historical snapshot of unit prices, discounts, taxes, and cost at time of sale.
5. `value_objects/discount.dart`: Deterministic calculation of percentage vs. fixed discounts.
6. `enums/sale_status.dart`: Finite state machine statuses (`draft`, `paymentPending`, `completed`, `cancelled`, `failed`).
7. `enums/payment_method.dart`: Supported tender types (`cash`, `card`, `digital`, `credit`).
8. `enums/payment_status.dart`: Payment lifecycle states (`pending`, `authorized`, `completed`, `failed`, `refunded`).
9. `enums/inventory_movement_type.dart`: Inventory movement classifications (`sale`, `refund`, `damageLoss`, `adjustment`).
10. `enums/discount_type.dart`: `percentage` and `fixed`.
11. `entities/cart_item.dart`: Single line item in the POS cart with weighable unit support and profit margin calculations.
12. `entities/cart.dart`: Immutable cart aggregate managing line items, cart-level discounts, customer metadata, and subtotal metrics.
13. `entities/resolved_product.dart`: Normalized product entity output by the resolution pipeline.
14. `entities/payment.dart`: Individual payment tender record with reference and status.
15. `entities/payment_allocation.dart`: Multi-payment allocation model calculating paid totals, remaining balance, and cash change.
16. `entities/inventory_movement_intent.dart`: Intent entity emitted to the future S3 Inventory Engine.
17. `entities/customer_ledger_entry.dart`: Financial ledger entry tracking credit sales and receivables deltas.
18. `entities/sale_item.dart`: Historical item snapshot persisted inside the completed `Sale`.
19. `entities/sale.dart`: Core POS sale aggregate containing financial totals, payment records, cashier metadata, and audit fields.
20. `entities/receipt_snapshot.dart`: Frozen snapshot of all customer-facing receipt information for future S6 printing.
21. `calculators/tax_policy.dart`: Extensible tax policy abstraction (`TaxPolicy.none()` and `TaxPolicy.rate()`).
22. `calculators/discount_calculator.dart`: Deterministic line and cart discount allocation across items preventing rounding drift.
23. `calculators/pricing_calculator.dart`: Pure calculator generating complete order totals and snapshots.
24. `validators/payment_validator.dart`: Financial validator enforcing non-negative tenders, customer requirements for credit, and cash-only change.
25. `rules/sale_state_machine.dart`: Strict transition matrix preventing illegal status jumps.
26. `services/i_product_resolver.dart`: Contract for hierarchical product resolution.
27. `services/product_resolver.dart`: Implementation prioritizing Barcode ➔ SKU ➔ ID ➔ Text Search.
28. `services/i_sale_idempotency_store.dart`: Contract for transaction deduplication.
29. `services/i_transaction_boundary.dart`: Contract for atomic conceptual transactions.
30. `services/i_shop_pos_repository.dart`: Repository interface for POS persistence.

### Application Layer (`lib/features/madar_shop/application/pos/`)
31. `failures/pos_failures.dart`: Strongly-typed exceptions (`InvalidCartFailure`, `ProductUnavailableFailure`, `UnauthorizedCashierFailure`, `SessionExpiredFailure`, etc.).
32. `events/pos_domain_events.dart`: Decoupled domain events (`SaleCompletedEvent`, `CreditCreatedEvent`, `InventoryMovementRequestedEvent`, `ReceiptReadyEvent`).
33. `commands/checkout_command.dart`: Encapsulated input parameters for the checkout pipeline.
34. `commands/checkout_result.dart`: OutputDTO containing the generated `Sale`, `ReceiptSnapshot`, and movement intents.
35. `services/cart_coordinator.dart`: In-memory cart orchestration service enforcing RBAC for price overrides and discounts.
36. `services/pos_checkout_coordinator.dart`: Central transactional coordinator orchestrating validation, totals calculation, payment verification, persistence, and event broadcasting.

### Data Layer (`lib/features/madar_shop/data/pos/`)
37. `models/payment_model.dart`: Serialization/deserialization for payments.
38. `models/sale_model.dart`: Serialization/deserialization for sales and sale items.
39. `models/customer_ledger_entry_model.dart`: Serialization/deserialization for ledger entries.
40. `models/inventory_movement_intent_model.dart`: Serialization/deserialization for inventory intents.
41. `repositories/in_memory_sale_idempotency_store.dart`: In-memory implementation of `ISaleIdempotencyStore`.
42. `repositories/shop_pos_repository_impl.dart`: Concrete repository implementation for POS entities.

### Tests & Documentation
43. `test/madar_shop_pos_engine_test.dart`: 48 comprehensive unit tests covering Groups A through L.
44. `docs/madar_shop_s2_pos_transaction_engine_report.md`: This comprehensive report.

---

## 3. Files Modified
1. `lib/features/madar_shop/domain/identity/entities/shop_session.dart`: Added `isHeartbeatStale()` alias for session staleness detection.
2. `lib/features/madar_shop/madar_shop.dart`: Exported all S2 POS value objects, enums, entities, calculators, services, and models.

---

## 4. Files Deleted
None. (Zero dead or obsolete files; clean additive architecture).

---

## 5. Architecture & Dependency Flow
```text
Presentation Layer (Future S8 Windows POS UI / Mobile POS)
       │
       ▼
Application Layer (CartCoordinator, PosCheckoutCoordinator)
       │
       ▼
Domain Layer (Sale Aggregate, Cart, Money, PricingCalculator, PaymentValidator, State Machine)
       │
       ▼
Repository Contracts (IShopPosRepository, ISaleIdempotencyStore, ITransactionBoundary)
       │
       ▼
Data Layer (ShopPosRepositoryImpl, InMemorySaleIdempotencyStore, Mappers)
       │
       ▼
Cloud / Local Storage (Firestore Transactions / Local Cache)
```

---

## 6. Domain Model Highlights

### Money & Rounding
- `Money` encapsulates `minorUnits` (integer) and `Currency`.
- IQD default: 0 decimal digits. USD default: 2 decimal digits.
- Mathematical operations are deterministic with zero floating point drift (tested across 100 fractional additions).

### PricingSnapshot
Preserves historical integrity:
```dart
class PricingSnapshot {
  final Money basePrice;
  final Money costPrice;
  final Money unitPrice;
  final Money unitDiscount;
  final Money unitTax;
  final Money netUnitPrice;
  final bool isManualOverride;
  final String? overrideReason;
  final DateTime capturedAt;
}
```
If a product's price in the master catalog changes from 10,000 IQD to 12,000 IQD, historical sales and printed receipts retain the exact 10,000 IQD captured at sale time.

---

## 7. Checkout Flow
1. **Idempotency Verification**: Checks `ISaleIdempotencyStore` for duplicate submissions.
2. **Session & Terminal Security**: Validates that the active session is neither expired nor heartbeat-stale, and matches the target terminal, business, and branch.
3. **RBAC Authorization**: Ensures the operator possesses `ShopPermission.accessPos` and `ShopPermission.createSalesOrder`.
4. **Cart Invariants**: Ensures cart is non-empty with all line quantities strictly > 0.
5. **Deterministic Calculation**: Computes line subtotals, item discounts, cart-level discounts, taxable base, taxes via `TaxPolicy`, and net margins.
6. **Payment Allocation**: Verifies that total tenders equal or exceed the grand total.
7. **Credit Validation**: Requires a non-null `customerId` if any tender uses `PaymentMethod.credit`.
8. **Atomic Commit**: Persists the `Sale`, `InventoryMovementIntent`s, `CustomerLedgerEntry` (if credit), `ReceiptSnapshot`, and audit log atomically.
9. **Event Emission**: Publishes `SaleCompletedEvent`, `InventoryMovementRequestedEvent`, and `ReceiptReadyEvent`.

---

## 8. Payment Flow & Multi-Tender
- **Split Payment**: Seamlessly handles partial cash + partial card (e.g., 6,000 IQD Cash + 4,000 IQD Card on a 10,000 IQD total).
- **Cash Overpayment**: Accurately computes change (e.g., 15,000 IQD Cash on a 10,000 IQD total results in 5,000 IQD change).
- **Overpayment Guard**: Prohibits overpayment on electronic or credit payment methods.

---

## 9. Inventory Integration (S3 Readiness)
POS operations do not mutate raw inventory directly. Instead, they emit clean `InventoryMovementIntent` records:
```dart
class InventoryMovementIntent {
  final String productId;
  final String? variantId;
  final double quantity;
  final InventoryMovementType movementType; // SALE
  final String referenceId; // saleId
}
```
This guarantees that the upcoming Phase S3 Inventory Engine can process batching, stock valuation, and reservation without race conditions or double deductions.

---

## 10. Credit / Customer Ledger Integration
When a sale includes `PaymentMethod.credit`:
- `CustomerLedgerEntry` is automatically constructed with `debit = grandTotal`, `credit = immediatePaid`, and `balanceDelta = remainingBalance`.
- Anonymous credit sales are strictly rejected at the domain validation level.

---

## 11. Idempotency & Concurrency
- `IdempotencyKey` prevents duplicate sales on double-taps, network retries, or app restarts.
- Tested: Submitting the same idempotency key twice returns the existing sale with `isIdempotentReplay = true` and generates **one single sale**, not two.

---

## 12. Security & RBAC Enforcement
- Standard cashiers can add products and complete sales.
- Unauthorized roles (such as `InventoryClerk`) are rejected with `UnauthorizedCashierFailure`.
- Manual price overrides require `ShopPermission.overrideItemPrice`.
- Item/Cart discounts require `ShopPermission.applyItemDiscount` / `applyCartDiscount`.
- Mismatched branches are blocked with `BranchMismatchFailure`.

---

## 13. Audit Trail
Every completed sale records an immutable `ShopAuditEntry` capturing:
- `userId`, `userName`, `terminalId`, `businessId`, `branchId`
- `action`, `referenceId`
- `afterState`: `saleNumber`, `grandTotal`, `itemsCount`, `isCredit`
- `timestamp`

---

## 14. Verification Commands & Actual Test Results

### Command 1: Unit Test Matrix
```bash
flutter test test/madar_shop_identity_and_rbac_test.dart test/madar_shop_product_and_marketplace_test.dart test/madar_shop_order_lifecycle_test.dart test/madar_shop_pos_engine_test.dart
```
**Output:**
```text
00:01 +65: All tests passed!
```
- **S1 Tests**: 17 tests passed (Identity, RBAC, Heartbeat Lease, Marketplace Bridge, Order Lifecycle).
- **S2 POS Tests**: 48 tests passed (Groups A through L).
- **Total MADAR SHOP Tests**: 65/65 Passed (100%).

### Command 2: Static Code Analysis
```bash
flutter analyze lib/features/madar_shop test/madar_shop_identity_and_rbac_test.dart test/madar_shop_product_and_marketplace_test.dart test/madar_shop_order_lifecycle_test.dart test/madar_shop_pos_engine_test.dart
```
**Output:**
```text
Analyzing 5 items...
No issues found! (ran in 4.2s)
```

---

## 15. Known Limitations & Unverified Items
1. **Physical Printing Hardware**: ESC/POS USB/Bluetooth printer communication is deferred to Phase S6. `ReceiptSnapshot` is structurally ready.
2. **Barcode Scanner Device Hook**: Handheld barcode scanner input (HID keyboard emulation / serial port) is deferred to the Windows POS UI integration layer. The domain resolver `ProductResolver` is fully implemented and tested.
3. **Live Firestore Transactions**: While models and domain contracts are designed for Firestore atomic batches, live cloud execution has not been run against a live Firebase project in this offline unit testing phase (**UNIT VERIFIED — PRODUCTION UNVERIFIED**).

---

## 16. S3 Readiness Assessment
The POS Transaction Engine is **100% architecturally prepared** for Phase S3 (Inventory Engine):
- Emits clean `InventoryMovementIntent` records with exact product and variant IDs.
- Tracks weighable and unit-based inventory quantities.
- Computes gross profit margins using cost-price snapshots.

---

## 17. Final Status
**STATUS: IMPLEMENTED**  
*(Domain & Application Engine Fully Verified via 65 Automated Unit Tests & Zero Analyzer Issues)*
