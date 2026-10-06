// ملف التصدير المركزي لمنظومة متجر مدار (MADAR SHOP Barrel Export)
// Pure Dart & Clean Architecture Module

// Identity & Multi-Branch
export 'domain/identity/entities/shop_business.dart';
export 'domain/identity/entities/shop_branch.dart';
export 'domain/identity/entities/shop_user.dart';
export 'domain/identity/entities/shop_session.dart';

// RBAC & Permissions Matrix
export 'domain/identity/rbac/shop_role.dart';
export 'domain/identity/rbac/shop_permission.dart';
export 'domain/identity/rbac/shop_permission_matrix.dart';

// Operating State
export 'domain/state/entities/shop_availability_state.dart';

// Catalog, Products & Variants
export 'domain/products/entities/shop_category.dart';
export 'domain/products/entities/shop_product_variant.dart';
export 'domain/products/entities/shop_product.dart';

// Marketplace Bridge
export 'domain/products/marketplace_bridge/marketplace_sync_entity.dart';
export 'domain/products/marketplace_bridge/marketplace_bridge_contracts.dart';

// Orders & Lifecycle State Machine
export 'domain/orders/entities/shop_order_status.dart';
export 'domain/orders/entities/shop_order_item.dart';
export 'domain/orders/entities/shop_order.dart';
export 'domain/orders/lifecycle/shop_order_state_machine.dart';

// Notifications & Audio Bridge
export 'domain/notifications/entities/shop_notification_event.dart';
export 'domain/notifications/contracts/shop_alert_audio_bridge.dart';

// Immutable Audit
export 'domain/audit/entities/shop_audit_entry.dart';
export 'domain/audit/contracts/shop_audit_repository.dart';

// Repository Contracts
export 'domain/contracts/shop_core_repository_contract.dart';

// Application Coordinators
export 'application/shop_identity_coordinator.dart';
export 'application/shop_catalog_coordinator.dart';
export 'application/shop_order_lifecycle_coordinator.dart';

// Data Models & Repositories
export 'data/models/shop_business_model.dart';
export 'data/models/shop_product_model.dart';
export 'data/models/shop_order_model.dart';
export 'data/models/shop_audit_model.dart';
export 'data/repositories/shop_core_repository.dart';

// ─── PHASE S2: POS Transaction Engine ───
// POS Value Objects
export 'domain/pos/value_objects/currency.dart';
export 'domain/pos/value_objects/money.dart';
export 'domain/pos/value_objects/idempotency_key.dart';
export 'domain/pos/value_objects/pricing_snapshot.dart';
export 'domain/pos/value_objects/discount.dart';

// POS Enums
export 'domain/pos/enums/sale_status.dart';
export 'domain/pos/enums/payment_method.dart';
export 'domain/pos/enums/payment_status.dart';
export 'domain/pos/enums/discount_type.dart';

// POS Entities
export 'domain/pos/entities/cart_item.dart';
export 'domain/pos/entities/cart.dart';
export 'domain/pos/entities/resolved_product.dart';
export 'domain/pos/entities/payment.dart';
export 'domain/pos/entities/payment_allocation.dart';
export 'domain/pos/entities/inventory_movement_intent.dart';
export 'domain/pos/entities/customer_ledger_entry.dart';
export 'domain/pos/entities/sale_item.dart';
export 'domain/pos/entities/sale.dart';
export 'domain/pos/entities/receipt_snapshot.dart';

// POS Calculators, Validators & Rules
export 'domain/pos/calculators/tax_policy.dart';
export 'domain/pos/calculators/discount_calculator.dart';
export 'domain/pos/calculators/pricing_calculator.dart';
export 'domain/pos/validators/payment_validator.dart';
export 'domain/pos/rules/sale_state_machine.dart';

// POS Contracts & Services
export 'domain/pos/services/i_product_resolver.dart';
export 'domain/pos/services/product_resolver.dart';
export 'domain/pos/services/i_sale_idempotency_store.dart';
export 'domain/pos/services/i_transaction_boundary.dart';
export 'domain/pos/services/i_shop_pos_repository.dart';

// POS Application Layer
export 'application/pos/failures/pos_failures.dart' hide InsufficientStockFailure;
export 'application/pos/events/pos_domain_events.dart';
export 'application/pos/commands/checkout_command.dart';
export 'application/pos/commands/checkout_result.dart';
export 'application/pos/services/cart_coordinator.dart';
export 'application/pos/services/pos_checkout_coordinator.dart';

// POS Data Models & Implementation
export 'data/pos/models/payment_model.dart';
export 'data/pos/models/sale_model.dart';
export 'data/pos/models/customer_ledger_entry_model.dart';
export 'data/pos/models/inventory_movement_intent_model.dart';
export 'data/pos/repositories/in_memory_sale_idempotency_store.dart';
export 'data/pos/repositories/shop_pos_repository_impl.dart';

// ─── PHASE S3: Inventory Engine ───
// Inventory Value Objects
export 'domain/inventory/value_objects/stock_unit.dart';
export 'domain/inventory/value_objects/stock_quantity.dart';
export 'domain/inventory/value_objects/inventory_item_key.dart';

// Inventory Enums
export 'domain/inventory/enums/inventory_movement_type.dart';
export 'domain/inventory/enums/stock_status.dart';
export 'domain/inventory/enums/negative_stock_policy.dart';
export 'domain/inventory/enums/return_restock_condition.dart';

// Inventory Entities & Rules
export 'domain/inventory/entities/inventory_item.dart';
export 'domain/inventory/entities/inventory_snapshot.dart';
export 'domain/inventory/entities/inventory_ledger_entry.dart';
export 'domain/inventory/rules/stock_rules.dart';

// Inventory Contracts (S4 / S5 / Transfer)
export 'domain/inventory/contracts/purchase_received_intent.dart';
export 'domain/inventory/contracts/return_inventory_intent.dart';
export 'domain/inventory/contracts/inventory_transfer_intent.dart';

// Inventory Repository Interfaces
export 'domain/inventory/repositories/i_inventory_repository.dart';
export 'domain/inventory/repositories/i_inventory_ledger_repository.dart';
export 'domain/inventory/repositories/i_inventory_idempotency_store.dart';

// Inventory Application Layer
export 'application/inventory/failures/inventory_failures.dart';
export 'application/inventory/events/inventory_domain_events.dart';
export 'application/inventory/commands/inventory_commands.dart';
export 'application/inventory/results/inventory_operation_result.dart';
export 'application/inventory/results/reconciliation_report.dart';
export 'application/inventory/services/inventory_transaction_service.dart';
export 'application/inventory/services/inventory_reconciliation_service.dart';

// Inventory Data Models & Repositories
export 'data/inventory/models/inventory_item_model.dart';
export 'data/inventory/models/inventory_ledger_entry_model.dart';
export 'data/inventory/repositories/in_memory_inventory_repository.dart';
export 'data/inventory/repositories/in_memory_inventory_ledger_repository.dart';
export 'data/inventory/repositories/in_memory_inventory_idempotency_store.dart';

// ─── PHASE S4: Purchasing + Suppliers + Payables ───
// Purchasing Enums
export 'domain/purchasing/enums/supplier_status.dart';
export 'domain/purchasing/enums/purchase_order_status.dart';
export 'domain/purchasing/enums/supplier_ledger_entry_type.dart';
export 'domain/purchasing/enums/supplier_payment_method.dart';
export 'domain/purchasing/enums/supplier_payment_status.dart';
export 'domain/purchasing/enums/over_receiving_policy.dart';
export 'domain/purchasing/enums/supplier_overpayment_policy.dart';

// Purchasing Value Objects
export 'domain/purchasing/value_objects/cost_snapshot.dart';

// Purchasing Entities
export 'domain/purchasing/entities/supplier.dart';
export 'domain/purchasing/entities/supplier_account.dart';
export 'domain/purchasing/entities/supplier_ledger_entry.dart';
export 'domain/purchasing/entities/purchase_item.dart';
export 'domain/purchasing/entities/purchase_order.dart';
export 'domain/purchasing/entities/purchase_receipt.dart';
export 'domain/purchasing/entities/purchase_receipt_item.dart';
export 'domain/purchasing/entities/supplier_payment.dart';

// Purchasing Rules
export 'domain/purchasing/rules/purchase_order_state_machine.dart';
export 'domain/purchasing/rules/purchasing_rules.dart';

// Purchasing Repository Interfaces
export 'domain/purchasing/repositories/i_supplier_repository.dart';
export 'domain/purchasing/repositories/i_supplier_ledger_repository.dart';
export 'domain/purchasing/repositories/i_purchase_order_repository.dart';
export 'domain/purchasing/repositories/i_purchase_receipt_repository.dart';
export 'domain/purchasing/repositories/i_supplier_payment_repository.dart';
export 'domain/purchasing/repositories/i_purchasing_idempotency_store.dart';

// Purchasing Application Layer
export 'application/purchasing/failures/purchasing_failures.dart';
export 'application/purchasing/events/purchasing_domain_events.dart';
export 'application/purchasing/commands/purchasing_commands.dart';
export 'application/purchasing/results/purchasing_operation_result.dart';
export 'application/purchasing/results/purchasing_reconciliation_report.dart';
export 'application/purchasing/services/purchasing_coordinator.dart';
export 'application/purchasing/services/purchasing_reconciliation_service.dart';

// Purchasing Data Models & Repositories
export 'data/purchasing/models/supplier_model.dart';
export 'data/purchasing/models/purchase_order_model.dart';
export 'data/purchasing/models/purchase_receipt_model.dart';
export 'data/purchasing/models/supplier_payment_model.dart';
export 'data/purchasing/models/supplier_ledger_entry_model.dart';
export 'data/purchasing/repositories/memory_supplier_repository.dart';
export 'data/purchasing/repositories/memory_supplier_ledger_repository.dart';
export 'data/purchasing/repositories/memory_purchase_order_repository.dart';
export 'data/purchasing/repositories/memory_purchase_receipt_repository.dart';
export 'data/purchasing/repositories/memory_supplier_payment_repository.dart';
export 'data/purchasing/repositories/memory_purchasing_idempotency_store.dart';

// ─── PHASE S5: Returns + Finance + COGS + Gross Profit + Inventory Valuation ───
// Returns Domain
export 'domain/returns/enums/return_order_status.dart';
export 'domain/returns/enums/return_type.dart';
export 'domain/returns/enums/return_reason.dart';
export 'domain/returns/enums/refund_method.dart';
export 'domain/returns/enums/refund_status.dart';
export 'domain/returns/enums/supplier_return_status.dart';
export 'domain/returns/entities/return_item.dart';
export 'domain/returns/entities/return_order.dart';
export 'domain/returns/entities/refund.dart';
export 'domain/returns/entities/supplier_return_item.dart';
export 'domain/returns/entities/supplier_return.dart';
export 'domain/returns/entities/supplier_credit_note.dart';
export 'domain/returns/rules/return_state_machine.dart';
export 'domain/returns/rules/return_rules.dart';
export 'domain/returns/repositories/i_return_order_repository.dart';
export 'domain/returns/repositories/i_refund_repository.dart';
export 'domain/returns/repositories/i_supplier_return_repository.dart';
export 'domain/returns/repositories/i_supplier_credit_note_repository.dart';
export 'domain/returns/repositories/i_returns_idempotency_store.dart';

// Returns Application
export 'application/returns/failures/returns_failures.dart';
export 'application/returns/events/returns_domain_events.dart';
export 'application/returns/commands/returns_commands.dart';
export 'application/returns/results/returns_operation_results.dart';
export 'application/returns/services/returns_coordinator.dart';

// Returns Data
export 'data/returns/models/return_item_model.dart';
export 'data/returns/models/return_order_model.dart';
export 'data/returns/models/refund_model.dart';
export 'data/returns/models/supplier_return_model.dart';
export 'data/returns/models/supplier_credit_note_model.dart';
export 'data/returns/repositories/memory_return_order_repository.dart';
export 'data/returns/repositories/memory_refund_repository.dart';
export 'data/returns/repositories/memory_supplier_return_repository.dart';
export 'data/returns/repositories/memory_supplier_credit_note_repository.dart';
export 'data/returns/repositories/memory_returns_idempotency_store.dart';

// Finance Domain
export 'domain/finance/enums/costing_method.dart';
export 'domain/finance/enums/financial_entry_type.dart';
export 'domain/finance/enums/financial_direction.dart';
export 'domain/finance/value_objects/inventory_cost_layer.dart';
export 'domain/finance/value_objects/gross_profit_result.dart';
export 'domain/finance/value_objects/inventory_valuation_item.dart';
export 'domain/finance/value_objects/inventory_valuation_report.dart';
export 'domain/finance/calculators/revenue_calculator.dart';
export 'domain/finance/calculators/cogs_calculator.dart';
export 'domain/finance/calculators/gross_profit_calculator.dart';
export 'domain/finance/entities/financial_entry.dart';
export 'domain/finance/repositories/i_financial_entry_repository.dart';
export 'domain/finance/repositories/i_inventory_cost_layer_repository.dart';
export 'domain/finance/repositories/i_finance_idempotency_store.dart';

// Finance Application
export 'application/finance/failures/finance_failures.dart';
export 'application/finance/events/finance_domain_events.dart';
export 'application/finance/commands/finance_commands.dart';
export 'application/finance/results/finance_operation_results.dart';
export 'application/finance/services/finance_coordinator.dart';
export 'application/finance/services/finance_reconciliation_service.dart';

// Finance Data
export 'data/finance/models/financial_entry_model.dart';
export 'data/finance/models/inventory_cost_layer_model.dart';
export 'data/finance/repositories/memory_financial_entry_repository.dart';
export 'data/finance/repositories/memory_inventory_cost_layer_repository.dart';
export 'data/finance/repositories/memory_finance_idempotency_store.dart';

// ─── PHASE S6: Printing & Hardware Engine ───
export 'domain/printing/entities/printer.dart';
export 'domain/printing/entities/printer_profile.dart';
export 'domain/printing/entities/print_job.dart';
export 'domain/printing/entities/print_document.dart';
export 'domain/printing/entities/print_section.dart';
export 'domain/printing/value_objects/paper_profile.dart';
export 'domain/printing/value_objects/printer_capabilities.dart';
export 'domain/printing/value_objects/rendered_payload.dart';
export 'domain/printing/enums/printer_status.dart';
export 'domain/printing/enums/printer_connection_type.dart';
export 'domain/printing/enums/print_document_type.dart';
export 'domain/printing/enums/paper_profile_type.dart';
export 'domain/printing/enums/print_job_status.dart';
export 'domain/printing/enums/print_trigger_type.dart';
export 'domain/printing/enums/auto_print_policy.dart';
export 'domain/printing/enums/barcode_format.dart';
export 'domain/printing/contracts/i_printer_driver.dart';
export 'domain/printing/contracts/i_printer_repository.dart';
export 'domain/printing/contracts/i_print_job_repository.dart';
export 'domain/printing/contracts/i_printer_profile_repository.dart';
export 'domain/printing/failures/printing_failures.dart';
export 'domain/printing/rules/auto_print_evaluator.dart';
export 'application/printing/services/print_coordinator.dart';
export 'application/printing/services/print_queue_service.dart';
export 'application/printing/services/document_builder_service.dart';

// ─── PHASE S7: Offline-First Engine & Data Sync ───
export 'domain/sync/entities/sync_command_envelope.dart';
export 'domain/sync/entities/sync_conflict.dart';
export 'domain/sync/entities/inbox_event.dart';
export 'domain/sync/entities/cached_entities.dart';
export 'domain/sync/enums/sync_command_status.dart';
export 'domain/sync/enums/outbox_state.dart';
export 'domain/sync/enums/connectivity_state.dart';
export 'domain/sync/enums/sync_conflict_type.dart';
export 'domain/sync/enums/conflict_resolution_status.dart';
export 'domain/sync/enums/cache_freshness.dart';
export 'domain/sync/enums/offline_operation_permission.dart';
export 'domain/sync/value_objects/offline_policy.dart';
export 'domain/sync/value_objects/sync_checkpoint.dart';
export 'domain/sync/value_objects/sync_lease.dart';
export 'domain/sync/value_objects/sync_ack.dart';
export 'domain/sync/value_objects/sync_status_snapshot.dart';
export 'domain/sync/contracts/i_local_database.dart';
export 'domain/sync/contracts/i_outbox_repository.dart';
export 'domain/sync/contracts/i_inbox_repository.dart';
export 'domain/sync/contracts/i_conflict_repository.dart';
export 'domain/sync/contracts/i_cache_repository.dart';
export 'domain/sync/contracts/i_connectivity_service.dart';
export 'domain/sync/contracts/i_remote_sync_gateway.dart';
export 'domain/sync/failures/sync_failures.dart';
export 'domain/sync/rules/sync_state_machine.dart';
export 'domain/sync/rules/command_dependency_graph.dart';
export 'application/sync/coordinators/sync_coordinator.dart';
export 'application/sync/workers/sync_worker.dart';
export 'application/sync/services/local_transaction_runner.dart';
export 'application/sync/services/offline_stock_allocator.dart';
export 'application/sync/services/sync_reconciliation_service.dart';
export 'application/sync/commands/sync_commands.dart';
export 'application/sync/events/sync_events.dart';

// ─── PHASE S8: Windows POS UI & Authentication Gate ───
export 'domain/identity/contracts/i_shop_identity_repository.dart';
export 'data/identity/repositories/memory_shop_identity_repository.dart';
export 'application/auth/madar_shop_auth_service.dart';
export 'presentation/auth/access_denied_page.dart';
export 'presentation/auth/madar_shop_login_page.dart';
export 'presentation/auth/madar_shop_auth_gate.dart';
export 'presentation/pos/utils/pos_error_mapper.dart';
export 'presentation/pos/controllers/windows_pos_controller.dart';
export 'presentation/pos/widgets/pos_top_status_bar.dart';
export 'presentation/pos/widgets/pos_search_bar.dart';
export 'presentation/pos/widgets/pos_category_filter.dart';
export 'presentation/pos/widgets/pos_product_card.dart';
export 'presentation/pos/widgets/pos_product_grid.dart';
export 'presentation/pos/widgets/pos_cart_pane.dart';
export 'presentation/pos/widgets/pos_total_summary_bar.dart';
export 'presentation/pos/widgets/pos_payment_dialog.dart';
export 'presentation/pos/widgets/pos_receipt_success_dialog.dart';
export 'presentation/pos/widgets/pos_sync_details_dialog.dart';
export 'presentation/pos/widgets/pos_returns_dialog.dart';
export 'presentation/pos/widgets/pos_discount_dialog.dart';
export 'presentation/pos/widgets/pos_customer_dialog.dart';
export 'presentation/pos/widgets/pos_manual_price_dialog.dart';
export 'presentation/pos/pages/windows_pos_page.dart';
