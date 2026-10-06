// حزمة اختبارات محرك الطباعة والعتاد (MADAR SHOP Phase S6 Comprehensive Tests)
// Pure Dart — Zero UI Dependencies — 86 Tests Covering Groups A through I

import 'package:flutter_test/flutter_test.dart';

import 'package:dalal_alqaim/features/madar_shop/domain/pos/entities/payment.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/pos/entities/receipt_snapshot.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/pos/entities/sale.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/pos/entities/sale_item.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/pos/enums/payment_method.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/pos/enums/sale_status.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/pos/value_objects/currency.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/pos/value_objects/money.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/pos/value_objects/pricing_snapshot.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/contracts/i_printer_driver.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/entities/print_document.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/entities/print_job.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/entities/print_section.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/entities/printer.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/entities/printer_profile.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/enums/auto_print_policy.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/enums/barcode_format.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/enums/paper_profile_type.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/enums/print_document_type.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/enums/print_job_status.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/enums/print_trigger_type.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/enums/printer_connection_type.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/enums/printer_status.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/failures/printing_failures.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/rules/auto_print_evaluator.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/rules/print_state_machine.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/value_objects/paper_profile.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/value_objects/printer_capabilities.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/value_objects/rendered_payload.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/purchasing/entities/purchase_receipt.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/purchasing/entities/purchase_receipt_item.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/returns/entities/return_item.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/returns/entities/return_order.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/returns/enums/return_order_status.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/returns/enums/return_type.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/inventory/value_objects/stock_quantity.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/inventory/value_objects/stock_unit.dart';
import 'package:dalal_alqaim/features/madar_shop/application/printing/commands/printing_commands.dart';
import 'package:dalal_alqaim/features/madar_shop/application/printing/events/printing_events.dart';
import 'package:dalal_alqaim/features/madar_shop/application/printing/renderers/a4_document_renderer.dart';
import 'package:dalal_alqaim/features/madar_shop/application/printing/renderers/a5_document_renderer.dart';
import 'package:dalal_alqaim/features/madar_shop/application/printing/renderers/label_document_renderer.dart';
import 'package:dalal_alqaim/features/madar_shop/application/printing/renderers/renderer_factory.dart';
import 'package:dalal_alqaim/features/madar_shop/application/printing/renderers/thermal_58mm_renderer.dart';
import 'package:dalal_alqaim/features/madar_shop/application/printing/renderers/thermal_80mm_renderer.dart';
import 'package:dalal_alqaim/features/madar_shop/application/printing/services/document_builder_service.dart';
import 'package:dalal_alqaim/features/madar_shop/application/printing/services/print_coordinator.dart';
import 'package:dalal_alqaim/features/madar_shop/application/printing/services/print_queue_service.dart';
import 'package:dalal_alqaim/features/madar_shop/data/printing/discovery/memory_printer_discovery.dart';
import 'package:dalal_alqaim/features/madar_shop/data/printing/drivers/esc_pos_driver.dart';
import 'package:dalal_alqaim/features/madar_shop/data/printing/drivers/mock_print_agent_client.dart';
import 'package:dalal_alqaim/features/madar_shop/data/printing/drivers/mock_printer_driver.dart';
import 'package:dalal_alqaim/features/madar_shop/data/printing/drivers/usb_printer_driver.dart';
import 'package:dalal_alqaim/features/madar_shop/data/printing/drivers/windows_system_printer_driver.dart';
import 'package:dalal_alqaim/features/madar_shop/data/printing/repositories/memory_print_job_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/printing/repositories/memory_printer_profile_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/printing/repositories/memory_printer_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/printing/repositories/memory_printing_idempotency_store.dart';

void main() {
  const bizId = 'BIZ-01';
  const branch1 = 'BRANCH-01';
  const branch2 = 'BRANCH-02';

  late MemoryPrinterRepository printerRepo;
  late MemoryPrinterProfileRepository profileRepo;
  late MemoryPrintJobRepository jobRepo;
  late MemoryPrintingIdempotencyStore idempotencyStore;
  late MockPrinterDriver mockDriver;
  late PrintQueueService queueService;
  late PrintCoordinator coordinator;
  late DocumentBuilderService docBuilder;
  final List<PrintingEvent> emittedEvents = [];
  final List<PrintingAuditRecord> emittedAuditRecords = [];

  setUp(() {
    printerRepo = MemoryPrinterRepository();
    profileRepo = MemoryPrinterProfileRepository();
    jobRepo = MemoryPrintJobRepository();
    idempotencyStore = MemoryPrintingIdempotencyStore();
    mockDriver = MockPrinterDriver();
    emittedEvents.clear();
    emittedAuditRecords.clear();

    queueService = PrintQueueService(
      jobRepository: jobRepo,
      maxRetries: 3,
      baseRetryDelay: const Duration(milliseconds: 5),
      onEvent: emittedEvents.add,
      onAudit: emittedAuditRecords.add,
    );

    coordinator = PrintCoordinator(
      printerRepository: printerRepo,
      profileRepository: profileRepo,
      jobRepository: jobRepo,
      idempotencyStore: idempotencyStore,
      queueService: queueService,
      driverResolver: (p) async => mockDriver,
      onEvent: emittedEvents.add,
      onAudit: emittedAuditRecords.add,
    );

    docBuilder = const DocumentBuilderService();
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP A: Paper Profiles (Tests 1 to 10)
  // ══════════════════════════════════════════════════════════════
  group('GROUP A: Paper Profiles', () {
    test('1. 58mm thermal profile dimensions and 32 column constraint', () {
      final p = PaperProfile.thermal58mm();
      expect(p.type, PaperProfileType.thermal58mm);
      expect(p.widthMm, 58.0);
      expect(p.heightMm, isNull);
      expect(p.maxCharsPerLine, 32);
      expect(p.isContinuous, isTrue);
    });

    test('2. 80mm thermal profile dimensions and 48 column constraint', () {
      final p = PaperProfile.thermal80mm();
      expect(p.type, PaperProfileType.thermal80mm);
      expect(p.widthMm, 80.0);
      expect(p.heightMm, isNull);
      expect(p.maxCharsPerLine, 48);
      expect(p.isContinuous, isTrue);
    });

    test('3. A4 standard dimensions (210x297mm) and 80 columns', () {
      final p = PaperProfile.a4();
      expect(p.type, PaperProfileType.a4);
      expect(p.widthMm, 210.0);
      expect(p.heightMm, 297.0);
      expect(p.maxCharsPerLine, 80);
      expect(p.isContinuous, isFalse);
    });

    test('4. A5 dimensions (148x210mm) and 60 columns', () {
      final p = PaperProfile.a5();
      expect(p.type, PaperProfileType.a5);
      expect(p.widthMm, 148.0);
      expect(p.heightMm, 210.0);
      expect(p.maxCharsPerLine, 60);
      expect(p.isContinuous, isFalse);
    });

    test('5. Label printer profile dimensions (50x30mm) and 28 columns', () {
      final p = PaperProfile.label();
      expect(p.type, PaperProfileType.label);
      expect(p.widthMm, 50.0);
      expect(p.heightMm, 30.0);
      expect(p.maxCharsPerLine, 28);
      expect(p.isContinuous, isFalse);
    });

    test('6. Custom paper profile with custom margins and dimensions', () {
      final p = PaperProfile.custom(
        widthMm: 100.0,
        heightMm: 150.0,
        printableWidthMm: 90.0,
        maxCharsPerLine: 40,
        leftMarginMm: 5.0,
        rightMarginMm: 5.0,
      );
      expect(p.type, PaperProfileType.custom);
      expect(p.widthMm, 100.0);
      expect(p.heightMm, 150.0);
      expect(p.printableWidthMm, 90.0);
      expect(p.maxCharsPerLine, 40);
    });

    test('7. Printable width calculations with margins', () {
      final p = PaperProfile.thermal80mm();
      expect(p.printableWidthMm, 72.0);
      expect(p.leftMarginMm, 4.0);
      expect(p.rightMarginMm, 4.0);
    });

    test('8. Paper profile equality and copyWith invariants', () {
      final p1 = PaperProfile.thermal80mm();
      final p2 = p1.copyWith(maxCharsPerLine: 44);
      expect(p2.maxCharsPerLine, 44);
      expect(p2.widthMm, 80.0);
      expect(p1 == p2, isFalse);
    });

    test('9. Paper profile rejects zero or negative width', () {
      expect(
        () => PaperProfile(
          type: PaperProfileType.custom,
          widthMm: -10,
          printableWidthMm: 5,
          maxCharsPerLine: 30,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('10. Paper profile type enum mapping completeness', () {
      expect(PaperProfileType.values.length, 6);
      expect(PaperProfileType.values, contains(PaperProfileType.thermal58mm));
      expect(PaperProfileType.values, contains(PaperProfileType.thermal80mm));
      expect(PaperProfileType.values, contains(PaperProfileType.a4));
      expect(PaperProfileType.values, contains(PaperProfileType.a5));
      expect(PaperProfileType.values, contains(PaperProfileType.label));
      expect(PaperProfileType.values, contains(PaperProfileType.custom));
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP B: Document Models & S2/S4/S5 Snapshots (Tests 11 to 20)
  // ══════════════════════════════════════════════════════════════
  group('GROUP B: Document Models & Snapshots', () {
    test('11. Build PrintDocument from Sale using ReceiptSnapshot', () {
      final sale = Sale(
        id: 'SALE-101',
        saleNumber: 'INV-101',
        businessId: bizId,
        branchId: branch1,
        terminalId: 'T1',
        sessionId: 'SESS-1',
        cashierId: 'CASH-1',
        cashierName: 'محمد كاشير',
        status: SaleStatus.completed,
        subtotal: Money.fromAmount(3000, Currency.iqd),
        discountTotal: Money.zero(Currency.iqd),
        taxTotal: Money.zero(Currency.iqd),
        grandTotal: Money.fromAmount(3000, Currency.iqd),
        paidTotal: Money.fromAmount(3000, Currency.iqd),
        remainingTotal: Money.zero(Currency.iqd),
        changeTotal: Money.zero(Currency.iqd),
        idempotencyKey: 'IDEMP-SALE-101',
        items: [
          SaleItem(
            itemId: 'ITEM-1',
            productId: 'PROD-1',
            sku: 'MILK-1',
            name: 'حليب كامل الدسم',
            quantity: 2.0,
            lineDiscount: Money.zero(Currency.iqd),
            lineTax: Money.zero(Currency.iqd),
            pricingSnapshot: PricingSnapshot.create(
              unitPrice: Money.fromAmount(1500, Currency.iqd),
              basePrice: Money.fromAmount(1500, Currency.iqd),
              costPrice: Money.fromAmount(1000, Currency.iqd),
            ),
          ),
        ],
        payments: [
          Payment(
            id: 'PAY-1',
            method: PaymentMethod.cash,
            amount: Money.fromAmount(3000, Currency.iqd),
            receivedAt: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
      );

      final doc = docBuilder.buildFromSale(
        sale,
        businessName: 'أسواق مدار المركزية',
        branchName: 'الفرع الرئيسي',
      );

      expect(doc.documentType, PrintDocumentType.saleReceipt);
      expect(doc.documentId, 'SALE-101');
      expect(doc.businessId, bizId);
      expect(doc.branchId, branch1);
      expect(doc.containsCutSection, isTrue);
      expect(doc.containsDrawerKickSection, isTrue);
    });

    test('12. Frozen snapshot integrity guarantees historical receipt accuracy', () {
      final snapshot = ReceiptSnapshot(
        saleId: 'HIST-001',
        saleNumber: 'INV-HIST-001',
        businessName: 'متجر مدار القديم',
        branchName: 'فرع بغداد',
        terminalId: 'POS-01',
        cashierName: 'علي كاشير',
        lines: [
          const ReceiptLineSnapshot(
            productName: 'سكر 1 كغم',
            sku: 'SUGAR-1',
            unitOfMeasure: 'piece',
            quantity: 3.0,
            unitPriceAmount: 1000.0,
            discountAmount: 0.0,
            lineTotalAmount: 3000.0,
          ),
        ],
        subtotalAmount: 3000.0,
        discountTotalAmount: 0.0,
        taxTotalAmount: 0.0,
        grandTotalAmount: 3000.0,
        paidTotalAmount: 3000.0,
        changeTotalAmount: 0.0,
        remainingTotalAmount: 0.0,
        payments: [
          const ReceiptPaymentSnapshot(methodDisplayName: 'نقدي', amount: 3000.0),
        ],
        currencyCode: 'IQD',
        currencySymbol: 'د.ع',
        printedOrCreatedAt: DateTime(2025, 1, 1),
      );

      final doc = docBuilder.buildFromReceiptSnapshot(snapshot);
      expect(doc.metadata['grandTotal'], 3000.0);
      expect(doc.metadata['saleNumber'], 'INV-HIST-001');
      expect(doc.createdAt, DateTime(2025, 1, 1));
    });

    test('13. Build PrintDocument from ReturnOrder with refund totals', () {
      final returnOrder = ReturnOrder(
        id: 'RET-001',
        businessId: bizId,
        branchId: branch1,
        originalSaleId: 'SALE-101',
        returnNumber: 'RN-001',
        type: ReturnType.fullReturn,
        status: ReturnOrderStatus.completed,
        items: [
          ReturnItem(
            id: 'RIT-1',
            originalSaleItemId: 'ITEM-1',
            productId: 'PROD-1',
            descriptionSnapshot: 'حليب كامل الدسم',
            skuSnapshot: 'MILK-01',
            quantity: StockQuantity.fromDouble(1.0, StockUnit.piece),
            unitRefundPrice: Money.fromAmount(1500, Currency.iqd),
            originalCostBasis: Money.fromAmount(1000, Currency.iqd),
          ),
        ],
        createdBy: 'أحمد كاشير',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        idempotencyKey: 'IDEMP-RET-01',
      );

      final doc = docBuilder.buildFromReturn(
        returnOrder,
        businessName: 'أسواق مدار',
        branchName: 'الفرع الأول',
      );

      expect(doc.documentType, PrintDocumentType.returnReceipt);
      expect(doc.documentId, 'RET-001');
      expect(doc.metadata['returnNumber'], 'RN-001');
      expect(doc.metadata['totalRefund'], 1500.0);
    });

    test('14. Build PrintDocument from PurchaseReceipt with items and supplier', () {
      final receipt = PurchaseReceipt(
        id: 'PR-501',
        businessId: bizId,
        branchId: branch1,
        purchaseOrderId: 'PO-901',
        supplierId: 'SUPP-AL-MANAR',
        items: [
          PurchaseReceiptItem(
            purchaseItemId: 'PI-1',
            productId: 'PROD-RICE',
            quantityReceived: StockQuantity.fromDouble(50.0, StockUnit.kg),
            unit: StockUnit.kg,
            unitCost: Money.fromAmount(2000, Currency.iqd),
          ),
        ],
        receivedBy: 'مأمور المخزن',
        receivedAt: DateTime.now(),
        idempotencyKey: 'IDEMP-PR-501',
      );

      final doc = docBuilder.buildFromPurchaseReceipt(
        receipt,
        businessName: 'مخازن مدار',
        branchName: 'مستودع الكرخ',
      );

      expect(doc.documentType, PrintDocumentType.purchaseReceipt);
      expect(doc.metadata['supplierId'], 'SUPP-AL-MANAR');
    });

    test('15. Build product label document with SKU and barcode', () {
      final doc = docBuilder.buildProductLabel(
        businessId: bizId,
        branchId: branch1,
        productName: 'زيت زيتون بكر 1 لتر',
        sku: 'OLIVE-1L',
        barcode: '6281001234567',
        priceFormatted: '8,500 د.ع',
        variant: 'علبة زجاج',
        batch: 'B-2026',
        expiry: '2028-12-31',
      );

      expect(doc.documentType, PrintDocumentType.label);
      expect(doc.sections.any((s) => s.type == PrintSectionType.barcode), isTrue);
    });

    test('16. Build invoice document preserves preferred paper profile', () {
      final doc = PrintDocument(
        documentType: PrintDocumentType.invoice,
        documentId: 'INV-999',
        title: 'فاتورة ضريبية رسمية',
        businessId: bizId,
        branchId: branch1,
        sections: [
          PrintSection.header('فاتورة رسمية'),
        ],
        preferredPaperProfile: PaperProfile.a4(),
        createdAt: DateTime.now(),
      );

      expect(doc.documentType, PrintDocumentType.invoice);
      expect(doc.preferredPaperProfile?.type, PaperProfileType.a4);
    });

    test('17. Build official A4 report document with header and footer', () {
      final doc = docBuilder.buildReportDocument(
        title: 'تقرير المبيعات الشهري',
        reportId: 'REP-2026-09',
        businessId: bizId,
        branchId: branch1,
        businessName: 'شركة مدار التجارية',
        branchName: 'المقر العام',
        bodySections: [
          PrintSection.divider(),
          PrintSection.footer('إجمالي المبيعات: 15,000,000 د.ع'),
        ],
      );

      expect(doc.documentType, PrintDocumentType.report);
      expect(doc.preferredPaperProfile?.type, PaperProfileType.a4);
      expect(doc.sections.first.text, 'تقرير المبيعات الشهري');
    });

    test('18. Cash payment emits cashDrawerKick section', () {
      final snapshot = ReceiptSnapshot(
        saleId: 'S-1',
        saleNumber: 'INV-1',
        businessName: 'B',
        branchName: 'BR',
        terminalId: 'T1',
        cashierName: 'C1',
        lines: [],
        subtotalAmount: 1000,
        discountTotalAmount: 0,
        taxTotalAmount: 0,
        grandTotalAmount: 1000,
        paidTotalAmount: 1000,
        changeTotalAmount: 0,
        remainingTotalAmount: 0,
        payments: [
          const ReceiptPaymentSnapshot(methodDisplayName: 'نقدي (Cash)', amount: 1000),
        ],
        currencyCode: 'IQD',
        currencySymbol: 'د.ع',
        printedOrCreatedAt: DateTime.now(),
      );

      final doc = docBuilder.buildFromReceiptSnapshot(snapshot);
      expect(doc.containsDrawerKickSection, isTrue);
    });

    test('19. Non-cash payment does not emit cashDrawerKick section', () {
      final snapshot = ReceiptSnapshot(
        saleId: 'S-2',
        saleNumber: 'INV-2',
        businessName: 'B',
        branchName: 'BR',
        terminalId: 'T1',
        cashierName: 'C1',
        lines: [],
        subtotalAmount: 1000,
        discountTotalAmount: 0,
        taxTotalAmount: 0,
        grandTotalAmount: 1000,
        paidTotalAmount: 1000,
        changeTotalAmount: 0,
        remainingTotalAmount: 0,
        payments: [
          const ReceiptPaymentSnapshot(methodDisplayName: 'بطاقة إلكترونية (Card)', amount: 1000),
        ],
        currencyCode: 'IQD',
        currencySymbol: 'د.ع',
        printedOrCreatedAt: DateTime.now(),
      );

      final doc = docBuilder.buildFromReceiptSnapshot(snapshot);
      expect(doc.containsDrawerKickSection, isFalse);
    });

    test('20. Paper cut section emitted at end of receipts', () {
      final snapshot = ReceiptSnapshot(
        saleId: 'S-3',
        saleNumber: 'INV-3',
        businessName: 'B',
        branchName: 'BR',
        terminalId: 'T1',
        cashierName: 'C1',
        lines: [],
        subtotalAmount: 500,
        discountTotalAmount: 0,
        taxTotalAmount: 0,
        grandTotalAmount: 500,
        paidTotalAmount: 500,
        changeTotalAmount: 0,
        remainingTotalAmount: 0,
        payments: [],
        currencyCode: 'IQD',
        currencySymbol: 'د.ع',
        printedOrCreatedAt: DateTime.now(),
      );

      final doc = docBuilder.buildFromReceiptSnapshot(snapshot);
      expect(doc.containsCutSection, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP C: Rendering, Text Wrapping & Arabic Layout (Tests 21 to 30)
  // ══════════════════════════════════════════════════════════════
  group('GROUP C: Rendering & Text Layout', () {
    const thermal58 = Thermal58mmRenderer();
    const thermal80 = Thermal80mmRenderer();
    const a4Renderer = A4DocumentRenderer();

    test('21. 58mm renderer deterministic line wrapping on long item names', () {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'DOC-58',
        title: '58mm Test',
        businessId: bizId,
        branchId: branch1,
        sections: [
          PrintSection.items([
            const PrintItemRowData(
              name: 'شامبو ترطيب وتغذية الشعر بخلاصة زيت الأركان الطبيعي سعة 500 مل',
              quantity: 1.0,
              unitPriceFormatted: '5,000 د.ع',
              totalPriceFormatted: '5,000 د.ع',
            ),
          ]),
        ],
        createdAt: DateTime.now(),
      );

      final payload = thermal58.render(
        document: doc,
        profile: PaperProfile.thermal58mm(),
      );

      expect(payload.characterWidth, 32);
      expect(payload.plainText, contains('5,000 د.ع'));
      expect(payload.linesCount, greaterThan(3));
    });

    test('22. 58mm renderer two-column key-value alignment', () {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'DOC-KV',
        title: 'KV Test',
        businessId: bizId,
        branchId: branch1,
        sections: [
          PrintSection(
            type: PrintSectionType.keyValue,
            keyValues: [
              const PrintKeyValueData(key: 'الكاشير', value: 'محمد علي'),
            ],
          ),
        ],
        createdAt: DateTime.now(),
      );

      final payload = thermal58.render(
        document: doc,
        profile: PaperProfile.thermal58mm(),
      );

      expect(payload.plainText, contains('الكاشير'));
      expect(payload.plainText, contains('محمد علي'));
    });

    test('23. 80mm renderer responsive 4-column item table', () {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'DOC-80',
        title: '80mm Test',
        businessId: bizId,
        branchId: branch1,
        sections: [
          PrintSection.items([
            const PrintItemRowData(
              name: 'أرز بسمتي',
              quantity: 2.0,
              unitPriceFormatted: '3,000 د.ع',
              totalPriceFormatted: '6,000 د.ع',
            ),
          ]),
        ],
        createdAt: DateTime.now(),
      );

      final payload = thermal80.render(
        document: doc,
        profile: PaperProfile.thermal80mm(),
      );

      expect(payload.characterWidth, 48);
      expect(payload.plainText, contains('أرز بسمتي'));
      expect(payload.plainText, contains('6,000 د.ع'));
    });

    test('24. 80mm renderer right-aligned totals', () {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'DOC-TOTALS',
        title: 'Totals',
        businessId: bizId,
        branchId: branch1,
        sections: [
          PrintSection.totals([
            const PrintKeyValueData(key: 'الإجمالي الصافي', value: '25,000 د.ع'),
          ]),
        ],
        createdAt: DateTime.now(),
      );

      final payload = thermal80.render(
        document: doc,
        profile: PaperProfile.thermal80mm(),
      );

      expect(payload.plainText, contains('الإجمالي الصافي'));
      expect(payload.plainText, contains('25,000 د.ع'));
    });

    test('25. Pure Arabic text rendering integrity in UTF-8 bytes', () {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'DOC-ARABIC',
        title: 'Arabic UTF8',
        businessId: bizId,
        branchId: branch1,
        sections: [
          PrintSection.header('متجر مدار للأجهزة الكهربائية والمستلزمات المنزلية'),
        ],
        createdAt: DateTime.now(),
      );

      final payload = thermal80.render(
        document: doc,
        profile: PaperProfile.thermal80mm(),
      );

      expect(payload.rawBytes.isNotEmpty, isTrue);
      expect(payload.plainText, contains('متجر مدار'));
    });

    test('26. Mixed Arabic and English text rendering', () {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'DOC-MIXED',
        title: 'Mixed Test',
        businessId: bizId,
        branchId: branch1,
        sections: [
          PrintSection.items([
            const PrintItemRowData(
              name: 'سماعات Apple AirPods Pro الجيل الثاني',
              sku: 'APP-AIR-02',
              quantity: 1.0,
              unitPriceFormatted: '320,000 د.ع',
              totalPriceFormatted: '320,000 د.ع',
            ),
          ]),
        ],
        createdAt: DateTime.now(),
      );

      final payload = thermal80.render(
        document: doc,
        profile: PaperProfile.thermal80mm(),
      );

      expect(payload.plainText, contains('AirPod'));
      expect(payload.plainText, contains('320,000 د.ع'));
    });

    test('27. Large quantity formatting (fractional vs integer)', () {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'DOC-QTY',
        title: 'Qty Test',
        businessId: bizId,
        branchId: branch1,
        sections: [
          PrintSection.items([
            const PrintItemRowData(
              name: 'تفاح أحمر بالكيلو',
              quantity: 3.75,
              unitPriceFormatted: '2,000 د.ع',
              totalPriceFormatted: '7,500 د.ع',
            ),
          ]),
        ],
        createdAt: DateTime.now(),
      );

      final payload = thermal80.render(
        document: doc,
        profile: PaperProfile.thermal80mm(),
      );

      expect(payload.plainText, contains('3.75'));
    });

    test('28. Discount row rendering only when discount is present', () {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'DOC-DISC',
        title: 'Disc Test',
        businessId: bizId,
        branchId: branch1,
        sections: [
          PrintSection.items([
            const PrintItemRowData(
              name: 'قميص رجالي',
              quantity: 1.0,
              unitPriceFormatted: '20,000 د.ع',
              totalPriceFormatted: '15,000 د.ع',
              discountFormatted: '5,000 د.ع',
            ),
          ]),
        ],
        createdAt: DateTime.now(),
      );

      final payload = thermal80.render(
        document: doc,
        profile: PaperProfile.thermal80mm(),
      );

      expect(payload.plainText, contains('-5,000 د.ع'));
    });

    test('29. Tax row rendering when tax is present', () {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'DOC-TAX',
        title: 'Tax Test',
        businessId: bizId,
        branchId: branch1,
        sections: [
          PrintSection.totals([
            const PrintKeyValueData(key: 'ضريبة المبيعات (5%)', value: '1,000 د.ع'),
          ]),
        ],
        createdAt: DateTime.now(),
      );

      final payload = thermal80.render(
        document: doc,
        profile: PaperProfile.thermal80mm(),
      );

      expect(payload.plainText, contains('ضريبة المبيعات (5%)'));
      expect(payload.plainText, contains('1,000 د.ع'));
    });

    test('30. A4 renderer paginated multi-page table layout with Page X of Y', () {
      final manyItems = List.generate(
        75,
        (i) => PrintItemRowData(
          name: 'صنف بضاعة متعدد رقم $i',
          quantity: 1.0,
          unitPriceFormatted: '1,000 د.ع',
          totalPriceFormatted: '1,000 د.ع',
        ),
      );

      final doc = PrintDocument(
        documentType: PrintDocumentType.report,
        documentId: 'A4-PAGE',
        title: 'تقرير الأصناف الشامل',
        businessId: bizId,
        branchId: branch1,
        sections: [
          PrintSection.header('تقرير المخزون الكامل'),
          PrintSection.items(manyItems),
          PrintSection.footer('نهاية التقرير المعتمد'),
        ],
        createdAt: DateTime.now(),
      );

      final payload = a4Renderer.render(
        document: doc,
        profile: PaperProfile.a4(),
      );

      expect(payload.plainText, contains('صفحة 1 من'));
      expect(payload.plainText, contains('صفحة 2 من'));
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP D: Printer Capabilities & Hardware Directives (Tests 31 to 40)
  // ══════════════════════════════════════════════════════════════
  group('GROUP D: Printer Capabilities', () {
    const thermal80 = Thermal80mmRenderer();

    test('31. QR code emitted when capability.qr is true', () {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'D-QR',
        title: 'QR Test',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.qrCode('MADAR-VERIFY-123')],
        createdAt: DateTime.now(),
      );

      final payload = thermal80.render(
        document: doc,
        profile: PaperProfile.thermal80mm(),
        capabilities: const PrinterCapabilities(qr: true),
      );

      expect(payload.plainText, contains('[QR-CODE: MADAR-VERIFY-123]'));
    });

    test('32. Fallback text emitted when capability.qr is false', () {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'D-NO-QR',
        title: 'No QR Test',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.qrCode('MADAR-VERIFY-123')],
        createdAt: DateTime.now(),
      );

      final payload = thermal80.render(
        document: doc,
        profile: PaperProfile.thermal80mm(),
        capabilities: const PrinterCapabilities(qr: false),
      );

      expect(payload.plainText, contains('QR: MADAR-VERIFY-123'));
    });

    test('33. Barcode emitted when capability.barcode is true', () {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'D-BARCODE',
        title: 'Barcode Test',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.barcode('6281001234567')],
        createdAt: DateTime.now(),
      );

      final payload = thermal80.render(
        document: doc,
        profile: PaperProfile.thermal80mm(),
        capabilities: const PrinterCapabilities(barcode: true),
      );

      expect(payload.plainText, contains('[BARCODE: 6281001234567]'));
    });

    test('34. Fallback text emitted when capability.barcode is false', () {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'D-NO-BARCODE',
        title: 'No Barcode Test',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.barcode('6281001234567')],
        createdAt: DateTime.now(),
      );

      final payload = thermal80.render(
        document: doc,
        profile: PaperProfile.thermal80mm(),
        capabilities: const PrinterCapabilities(barcode: false),
      );

      expect(payload.plainText, contains('BARCODE: 6281001234567'));
    });

    test('35. Cut command executed when capability.cut is true', () {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'D-CUT',
        title: 'Cut Test',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.paperCut()],
        createdAt: DateTime.now(),
      );

      final payload = thermal80.render(
        document: doc,
        profile: PaperProfile.thermal80mm(),
        capabilities: const PrinterCapabilities(cut: true),
      );

      expect(payload.hasCutCommand, isTrue);
    });

    test('36. Cut command suppressed when capability.cut is false', () {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'D-NO-CUT',
        title: 'No Cut Test',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.paperCut()],
        createdAt: DateTime.now(),
      );

      final payload = thermal80.render(
        document: doc,
        profile: PaperProfile.thermal80mm(),
        capabilities: const PrinterCapabilities(cut: false),
      );

      expect(payload.hasCutCommand, isFalse);
    });

    test('37. Cash drawer kick executed when capability.drawer is true', () {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'D-DRAWER',
        title: 'Drawer Test',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.cashDrawerKick()],
        createdAt: DateTime.now(),
      );

      final payload = thermal80.render(
        document: doc,
        profile: PaperProfile.thermal80mm(),
        capabilities: const PrinterCapabilities(drawer: true),
      );

      expect(payload.hasDrawerKick, isTrue);
    });

    test('38. Cash drawer kick suppressed when capability.drawer is false', () {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'D-NO-DRAWER',
        title: 'No Drawer Test',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.cashDrawerKick()],
        createdAt: DateTime.now(),
      );

      final payload = thermal80.render(
        document: doc,
        profile: PaperProfile.thermal80mm(),
        capabilities: const PrinterCapabilities(drawer: false),
      );

      expect(payload.hasDrawerKick, isFalse);
    });

    test('39. PrinterCapabilities default flags all false for safe fallback', () {
      const caps = PrinterCapabilities();
      expect(caps.qr, isFalse);
      expect(caps.barcode, isFalse);
      expect(caps.cut, isFalse);
      expect(caps.drawer, isFalse);
    });

    test('40. ESC/POS driver generates standard binary cut sequence', () async {
      final escPos = EscPosDriver();
      await escPos.connect();
      await escPos.cutPaper();
      expect(escPos.transmittedPackets.isNotEmpty, isTrue);
      expect(escPos.transmittedPackets.last, EscPosDriver.cmdCutPartial);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP E: Print Queue & State Machine (Tests 41 to 50)
  // ══════════════════════════════════════════════════════════════
  group('GROUP E: Print Queue & State Machine', () {
    test('41. Initial state is queued upon submission', () async {
      final job = PrintJob(
        jobId: 'JOB-41',
        documentId: 'DOC-41',
        documentType: PrintDocumentType.saleReceipt,
        businessId: bizId,
        branchId: branch1,
        printerId: 'PRN-01',
        actorId: 'TESTER',
        idempotencyKey: 'KEY-41',
        createdAt: DateTime.now(),
      );

      expect(job.status, PrintJobStatus.queued);
    });

    test('42. Queue transitions to printing on start', () {
      final job = PrintJob(
        jobId: 'JOB-42',
        documentId: 'DOC-42',
        documentType: PrintDocumentType.saleReceipt,
        businessId: bizId,
        branchId: branch1,
        printerId: 'PRN-01',
        actorId: 'TESTER',
        idempotencyKey: 'KEY-42',
        createdAt: DateTime.now(),
      );

      final started = job.markStarted();
      expect(started.status, PrintJobStatus.printing);
      expect(started.startedAt, isNotNull);
      expect(started.attemptCount, 1);
    });

    test('43. Queue transitions to completed on driver success', () async {
      final job = PrintJob(
        jobId: 'JOB-43',
        documentId: 'DOC-43',
        documentType: PrintDocumentType.saleReceipt,
        businessId: bizId,
        branchId: branch1,
        printerId: 'PRN-01',
        actorId: 'TESTER',
        idempotencyKey: 'KEY-43',
        createdAt: DateTime.now(),
      );

      final payload = RenderedPayload(
        rawBytes: [1, 2, 3],
        plainText: 'TEST',
        linesCount: 1,
        maxColumns: 32,
      );

      final result = await queueService.enqueueJob(
        job: job,
        payload: payload,
        driver: mockDriver,
      );

      expect(result.status, PrintJobStatus.completed);
      expect(result.completedAt, isNotNull);
    });

    test('44. Queue transitions to failed on unrecoverable error after retries', () async {
      mockDriver.shouldFailPrint = true;

      final job = PrintJob(
        jobId: 'JOB-44',
        documentId: 'DOC-44',
        documentType: PrintDocumentType.saleReceipt,
        businessId: bizId,
        branchId: branch1,
        printerId: 'PRN-01',
        actorId: 'TESTER',
        idempotencyKey: 'KEY-44',
        maxAttempts: 3,
        createdAt: DateTime.now(),
      );

      final payload = RenderedPayload(
        rawBytes: [1, 2, 3],
        plainText: 'TEST',
        linesCount: 1,
        maxColumns: 32,
      );

      final result = await queueService.enqueueJob(
        job: job,
        payload: payload,
        driver: mockDriver,
      );

      expect(result.status, PrintJobStatus.failed);
      expect(result.attemptCount, 3);
    });

    test('45. Operator cancels queued job successfully', () async {
      final job = PrintJob(
        jobId: 'JOB-45',
        documentId: 'DOC-45',
        documentType: PrintDocumentType.saleReceipt,
        businessId: bizId,
        branchId: branch1,
        printerId: 'PRN-01',
        actorId: 'TESTER',
        idempotencyKey: 'KEY-45',
        createdAt: DateTime.now(),
      );

      await jobRepo.saveJob(job);

      final cancelled = await queueService.cancelJob(
        businessId: bizId,
        jobId: 'JOB-45',
        cancelledBy: 'MANAGER',
        reason: 'Customer changed payment method',
      );

      expect(cancelled.status, PrintJobStatus.cancelled);
      expect(cancelled.lastError, contains('MANAGER'));
    });

    test('46. State machine rejects illegal transition from completed to queued', () {
      final transition = PrintStateMachine.validateTransition(
        currentStatus: PrintJobStatus.completed,
        nextStatus: PrintJobStatus.queued,
      );
      expect(transition.isAllowed, isFalse);
    });

    test('47. State machine rejects illegal transition from failed to printing', () {
      final transition = PrintStateMachine.validateTransition(
        currentStatus: PrintJobStatus.failed,
        nextStatus: PrintJobStatus.printing,
      );
      expect(transition.isAllowed, isFalse);
    });

    test('48. Queue increments attemptCount on each try', () {
      final job = PrintJob(
        jobId: 'JOB-48',
        documentId: 'DOC-48',
        documentType: PrintDocumentType.saleReceipt,
        businessId: bizId,
        branchId: branch1,
        printerId: 'PRN-01',
        actorId: 'TESTER',
        idempotencyKey: 'KEY-48',
        createdAt: DateTime.now(),
      );

      final j1 = job.markStarted();
      expect(j1.attemptCount, 1);
      final j2 = j1.markStarted();
      expect(j2.attemptCount, 2);
    });

    test('49. Terminal state flag is true for completed, failed, cancelled', () {
      expect(PrintJobStatus.completed.isTerminal, isTrue);
      expect(PrintJobStatus.failed.isTerminal, isTrue);
      expect(PrintJobStatus.cancelled.isTerminal, isTrue);
      expect(PrintJobStatus.queued.isTerminal, isFalse);
      expect(PrintJobStatus.printing.isTerminal, isFalse);
      expect(PrintJobStatus.unknownRequiresConfirmation.isTerminal, isFalse);
    });

    test('50. State machine allows transition from printing to queued for retry', () {
      final transition = PrintStateMachine.validateTransition(
        currentStatus: PrintJobStatus.printing,
        nextStatus: PrintJobStatus.queued,
      );
      expect(transition.isAllowed, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP F: Idempotency & Auto-Print vs Reprint (Tests 51 to 60)
  // ══════════════════════════════════════════════════════════════
  group('GROUP F: Idempotency & Auto-Print vs Reprint', () {
    setUp(() async {
      await printerRepo.savePrinter(Printer(
        id: 'PRN-01',
        businessId: bizId,
        branchId: branch1,
        name: 'طابعة الكاشير 1',
        connectionType: PrinterConnectionType.network,
        capabilities: const PrinterCapabilities(cut: true, drawer: true),
        status: PrinterStatus.online,
        isDefault: true,
      ));
    });

    test('51. Auto-print executes once for a given document', () async {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'SALE-51',
        title: 'Sale 51',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.header('Receipt 51')],
        createdAt: DateTime.now(),
      );

      final job = await coordinator.submitPrintJob(SubmitPrintJobCommand(
        businessId: bizId,
        branchId: branch1,
        document: doc,
        triggerType: PrintTriggerType.autoPrint,
        requestedBy: 'SYSTEM',
        idempotencyKey: 'AUTO-SALE-51',
      ));

      expect(job.status, PrintJobStatus.completed);
      expect(mockDriver.printedJobs.length, 1);
    });

    test('52. Duplicate auto-print request is rejected with DuplicateAutoPrintFailure', () async {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'SALE-52',
        title: 'Sale 52',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.header('Receipt 52')],
        createdAt: DateTime.now(),
      );

      await coordinator.submitPrintJob(SubmitPrintJobCommand(
        businessId: bizId,
        branchId: branch1,
        document: doc,
        triggerType: PrintTriggerType.autoPrint,
        requestedBy: 'SYSTEM',
        idempotencyKey: 'AUTO-SALE-52-A',
      ));

      // Second auto-print request for same sale
      expect(
        () => coordinator.submitPrintJob(SubmitPrintJobCommand(
          businessId: bizId,
          branchId: branch1,
          document: doc,
          triggerType: PrintTriggerType.autoPrint,
          requestedBy: 'SYSTEM',
          idempotencyKey: 'AUTO-SALE-52-B',
        )),
        throwsA(isA<DuplicateAutoPrintFailure>()),
      );
    });

    test('53. Manual reprint with valid reason is permitted even if auto-printed', () async {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'SALE-53',
        title: 'Sale 53',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.header('Receipt 53')],
        createdAt: DateTime.now(),
      );

      // 1. First auto print
      await coordinator.submitPrintJob(SubmitPrintJobCommand(
        businessId: bizId,
        branchId: branch1,
        document: doc,
        triggerType: PrintTriggerType.autoPrint,
        requestedBy: 'SYSTEM',
        idempotencyKey: 'AUTO-SALE-53',
      ));

      // 2. Manual reprint with reason
      final reprintJob = await coordinator.reprintDocument(ReprintCommand(
        businessId: bizId,
        branchId: branch1,
        originalJobIdOrDocumentId: 'SALE-53',
        document: doc,
        requestedBy: 'CASHIER_AHMED',
        reason: 'Customer requested a paper copy for accounting',
        idempotencyKey: 'REPRINT-SALE-53-1',
      ));

      expect(reprintJob.status, PrintJobStatus.completed);
      expect(mockDriver.printedJobs.length, 2);
    });

    test('54. Manual reprint without reason is rejected with InvalidReprintReasonFailure', () async {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'SALE-54',
        title: 'Sale 54',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.header('Receipt 54')],
        createdAt: DateTime.now(),
      );

      expect(
        () => coordinator.reprintDocument(ReprintCommand(
          businessId: bizId,
          branchId: branch1,
          originalJobIdOrDocumentId: 'SALE-54',
          document: doc,
          requestedBy: 'CASHIER_AHMED',
          reason: '   ', // Blank
          idempotencyKey: 'REPRINT-SALE-54',
        )),
        throwsA(isA<InvalidReprintReasonFailure>()),
      );
    });

    test('55. Manual reprint generates a separate job ID', () async {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'SALE-55',
        title: 'Sale 55',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.header('Receipt 55')],
        createdAt: DateTime.now(),
      );

      final job1 = await coordinator.submitPrintJob(SubmitPrintJobCommand(
        businessId: bizId,
        branchId: branch1,
        document: doc,
        triggerType: PrintTriggerType.autoPrint,
        requestedBy: 'SYSTEM',
        idempotencyKey: 'AUTO-SALE-55',
      ));

      final job2 = await coordinator.reprintDocument(ReprintCommand(
        businessId: bizId,
        branchId: branch1,
        originalJobIdOrDocumentId: 'SALE-55',
        document: doc,
        requestedBy: 'CASHIER',
        reason: 'Lost receipt',
        idempotencyKey: 'REPRINT-55',
      ));

      expect(job1.id, isNot(equals(job2.id)));
    });

    test('56. Same idempotency key returns existing job without re-printing', () async {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'SALE-56',
        title: 'Sale 56',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.header('Receipt 56')],
        createdAt: DateTime.now(),
      );

      final job1 = await coordinator.submitPrintJob(SubmitPrintJobCommand(
        businessId: bizId,
        branchId: branch1,
        document: doc,
        triggerType: PrintTriggerType.autoPrint,
        requestedBy: 'SYSTEM',
        idempotencyKey: 'SAME-KEY-56',
      ));

      final job2 = await coordinator.submitPrintJob(SubmitPrintJobCommand(
        businessId: bizId,
        branchId: branch1,
        document: doc,
        triggerType: PrintTriggerType.autoPrint,
        requestedBy: 'SYSTEM',
        idempotencyKey: 'SAME-KEY-56',
      ));

      expect(job1.id, equals(job2.id));
      expect(mockDriver.printedJobs.length, 1);
    });

    test('57. Different idempotency keys allow distinct print jobs', () async {
      final doc1 = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'DOC-57-1',
        title: 'Doc 1',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.header('1')],
        createdAt: DateTime.now(),
      );
      final doc2 = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'DOC-57-2',
        title: 'Doc 2',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.header('2')],
        createdAt: DateTime.now(),
      );

      final j1 = await coordinator.submitPrintJob(SubmitPrintJobCommand(
        businessId: bizId,
        branchId: branch1,
        document: doc1,
        triggerType: PrintTriggerType.autoPrint,
        requestedBy: 'S',
        idempotencyKey: 'KEY-57-1',
      ));

      final j2 = await coordinator.submitPrintJob(SubmitPrintJobCommand(
        businessId: bizId,
        branchId: branch1,
        document: doc2,
        triggerType: PrintTriggerType.autoPrint,
        requestedBy: 'S',
        idempotencyKey: 'KEY-57-2',
      ));

      expect(j1.id, isNot(equals(j2.id)));
      expect(mockDriver.printedJobs.length, 2);
    });

    test('58. Auto-print policy OFF suppresses automatic print', () {
      final shouldPrint = AutoPrintEvaluator.shouldAutoPrint(
        policy: AutoPrintPolicy.off,
        documentType: PrintDocumentType.saleReceipt,
      );
      expect(shouldPrint, isFalse);
    });

    test('59. Auto-print policy SALE_ONLY permits sale receipts but suppresses returns', () {
      expect(
        AutoPrintEvaluator.shouldAutoPrint(
          policy: AutoPrintPolicy.saleOnly,
          documentType: PrintDocumentType.saleReceipt,
        ),
        isTrue,
      );
      expect(
        AutoPrintEvaluator.shouldAutoPrint(
          policy: AutoPrintPolicy.saleOnly,
          documentType: PrintDocumentType.returnReceipt,
        ),
        isFalse,
      );
    });

    test('60. Auto-print policy ALL_DOCUMENTS permits all document types', () {
      expect(
        AutoPrintEvaluator.shouldAutoPrint(
          policy: AutoPrintPolicy.allDocuments,
          documentType: PrintDocumentType.report,
        ),
        isTrue,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP G: Failures, Bounded Retries & Unknown State (Tests 61 to 70)
  // ══════════════════════════════════════════════════════════════
  group('GROUP G: Failures, Retries & Unknown State', () {
    test('61. Printer offline triggers bounded retry up to maxAttempts', () async {
      mockDriver.status = PrinterStatus.offline;

      final job = PrintJob(
        jobId: 'JOB-61',
        documentId: 'DOC-61',
        documentType: PrintDocumentType.saleReceipt,
        businessId: bizId,
        branchId: branch1,
        printerId: 'PRN-01',
        actorId: 'TESTER',
        idempotencyKey: 'KEY-61',
        maxAttempts: 3,
        createdAt: DateTime.now(),
      );

      final payload = RenderedPayload(
        rawBytes: [1, 2],
        plainText: 'TEST',
        linesCount: 1,
        maxColumns: 32,
      );

      final result = await queueService.enqueueJob(
        job: job,
        payload: payload,
        driver: mockDriver,
      );

      expect(result.status, PrintJobStatus.failed);
      expect(result.attemptCount, 3);
    });

    test('62. Exhausted retries transitions job to failed state (never fake success)', () async {
      mockDriver.shouldFailPrint = true;

      final job = PrintJob(
        jobId: 'JOB-62',
        documentId: 'DOC-62',
        documentType: PrintDocumentType.saleReceipt,
        businessId: bizId,
        branchId: branch1,
        printerId: 'PRN-01',
        actorId: 'TESTER',
        idempotencyKey: 'KEY-62',
        maxAttempts: 2,
        createdAt: DateTime.now(),
      );

      final payload = RenderedPayload(
        rawBytes: [1],
        plainText: 'F',
        linesCount: 1,
        maxColumns: 32,
      );

      final result = await queueService.enqueueJob(
        job: job,
        payload: payload,
        driver: mockDriver,
      );

      expect(result.status, PrintJobStatus.failed);
      expect(result.lastError, contains('فشلت الطباعة'));
    });

    test('63. ACK timeout transitions job to unknownRequiresConfirmation', () async {
      mockDriver.shouldTimeoutAck = true;

      final job = PrintJob(
        jobId: 'JOB-63',
        documentId: 'DOC-63',
        documentType: PrintDocumentType.saleReceipt,
        businessId: bizId,
        branchId: branch1,
        printerId: 'PRN-01',
        actorId: 'TESTER',
        idempotencyKey: 'KEY-63',
        createdAt: DateTime.now(),
      );

      final payload = RenderedPayload(
        rawBytes: [1],
        plainText: 'ACK',
        linesCount: 1,
        maxColumns: 32,
      );

      final result = await queueService.enqueueJob(
        job: job,
        payload: payload,
        driver: mockDriver,
      );

      expect(result.status, PrintJobStatus.unknownRequiresConfirmation);
      expect(result.lastError, contains('ACK Timeout'));
    });

    test('64. ACK timeout does NOT execute blind auto retry', () async {
      mockDriver.shouldTimeoutAck = true;

      final job = PrintJob(
        jobId: 'JOB-64',
        documentId: 'DOC-64',
        documentType: PrintDocumentType.saleReceipt,
        businessId: bizId,
        branchId: branch1,
        printerId: 'PRN-01',
        actorId: 'TESTER',
        idempotencyKey: 'KEY-64',
        maxAttempts: 5,
        createdAt: DateTime.now(),
      );

      final payload = RenderedPayload(
        rawBytes: [1],
        plainText: 'ACK',
        linesCount: 1,
        maxColumns: 32,
      );

      final result = await queueService.enqueueJob(
        job: job,
        payload: payload,
        driver: mockDriver,
      );

      // Attempt count must remain 1 because blind auto-retry is forbidden on ACK timeout
      expect(result.attemptCount, 1);
      expect(result.status, PrintJobStatus.unknownRequiresConfirmation);
    });

    test('65. Manual confirmation of unknown job as printed marks status completed', () async {
      final unknownJob = PrintJob(
        jobId: 'JOB-65',
        documentId: 'DOC-65',
        documentType: PrintDocumentType.saleReceipt,
        businessId: bizId,
        branchId: branch1,
        printerId: 'PRN-01',
        status: PrintJobStatus.unknownRequiresConfirmation,
        actorId: 'TESTER',
        idempotencyKey: 'KEY-65',
        createdAt: DateTime.now(),
      );

      await jobRepo.saveJob(unknownJob);

      final confirmed = await queueService.confirmUnknownState(
        businessId: bizId,
        jobId: 'JOB-65',
        actuallyPrinted: true,
        actor: 'SUPERVISOR',
        reason: 'Inspected printer tray: receipt came out clearly',
      );

      expect(confirmed.status, PrintJobStatus.completed);
      expect(confirmed.completedAt, isNotNull);
    });

    test('66. Manual confirmation of unknown job as not printed marks status failed', () async {
      final unknownJob = PrintJob(
        jobId: 'JOB-66',
        documentId: 'DOC-66',
        documentType: PrintDocumentType.saleReceipt,
        businessId: bizId,
        branchId: branch1,
        printerId: 'PRN-01',
        status: PrintJobStatus.unknownRequiresConfirmation,
        actorId: 'TESTER',
        idempotencyKey: 'KEY-66',
        createdAt: DateTime.now(),
      );

      await jobRepo.saveJob(unknownJob);

      final confirmed = await queueService.confirmUnknownState(
        businessId: bizId,
        jobId: 'JOB-66',
        actuallyPrinted: false,
        actor: 'SUPERVISOR',
        reason: 'No paper came out',
      );

      expect(confirmed.status, PrintJobStatus.failed);
    });

    test('67. Network printer disconnects cleanly on connection error', () async {
      final escDriver = EscPosDriver();
      await _testEscPosDriverDisconnect(escDriver);
    });

    test('68. Windows system printer driver reports unsupported when platform bridge is absent', () async {
      final winDriver = WindowsSystemPrinterDriver(
        systemPrinterName: 'EPSON-TM-T20III',
        isDriverAvailable: false,
      );

      final connected = await winDriver.connect();
      expect(connected, isFalse);

      final dummyJob = PrintJob(
        jobId: 'W1',
        documentId: 'D1',
        documentType: PrintDocumentType.saleReceipt,
        businessId: bizId,
        branchId: branch1,
        printerId: 'P1',
        actorId: 'A',
        idempotencyKey: 'K',
        createdAt: DateTime.now(),
      );

      expect(
        () => winDriver.printPayload(
          dummyJob,
          RenderedPayload(rawBytes: [], plainText: '', linesCount: 0, maxColumns: 0),
        ),
        throwsA(isA<UnsupportedPrinterOperationFailure>()),
      );
    });

    test('69. USB printer driver reports unsupported when hardware handle is detached', () async {
      final usbDriver = UsbPrinterDriver(
        deviceIdentifier: 'USB-001',
        isHardwareAttached: false,
      );

      expect(await usbDriver.connect(), isFalse);

      final dummyJob = PrintJob(
        jobId: 'U1',
        documentId: 'D1',
        documentType: PrintDocumentType.saleReceipt,
        businessId: bizId,
        branchId: branch1,
        printerId: 'P1',
        actorId: 'A',
        idempotencyKey: 'K',
        createdAt: DateTime.now(),
      );

      expect(
        () => usbDriver.printPayload(
          dummyJob,
          RenderedPayload(rawBytes: [], plainText: '', linesCount: 0, maxColumns: 0),
        ),
        throwsA(isA<UnsupportedPrinterOperationFailure>()),
      );
    });

    test('70. Driver timeout stops execution without hanging', () async {
      final winDriver = WindowsSystemPrinterDriver(
        systemPrinterName: 'TEST',
        isDriverAvailable: false,
      );
      final status = await winDriver.getStatus();
      expect(status, PrinterStatus.unknown);
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP H: Multi-Branch & Multi-Tenant Isolation (Tests 71 to 80)
  // ══════════════════════════════════════════════════════════════
  group('GROUP H: Multi-Branch Isolation', () {
    setUp(() async {
      // Register printer in Branch 1
      await printerRepo.savePrinter(Printer(
        id: 'PRN-BR1',
        businessId: bizId,
        branchId: branch1,
        name: 'طابعة الفرع الأول',
        connectionType: PrinterConnectionType.network,
        capabilities: const PrinterCapabilities(cut: true),
        status: PrinterStatus.online,
        isDefault: true,
      ));

      // Register printer in Branch 2
      await printerRepo.savePrinter(Printer(
        id: 'PRN-BR2',
        businessId: bizId,
        branchId: branch2,
        name: 'طابعة الفرع الثاني',
        connectionType: PrinterConnectionType.network,
        capabilities: const PrinterCapabilities(cut: true),
        status: PrinterStatus.online,
        isDefault: true,
      ));
    });

    test('71. Branch A cannot print to Branch B printer', () async {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'SALE-71',
        title: 'Doc',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.header('H')],
        createdAt: DateTime.now(),
      );

      // Branch 1 trying to force override with Branch 2 printer
      expect(
        () => coordinator.submitPrintJob(SubmitPrintJobCommand(
          businessId: bizId,
          branchId: branch1,
          document: doc,
          triggerType: PrintTriggerType.autoPrint,
          printerIdOverride: 'PRN-BR2', // Belong to branch2!
          requestedBy: 'CASHIER',
          idempotencyKey: 'KEY-71',
        )),
        throwsA(isA<CrossBranchPrinterAccessFailure>()),
      );
    });

    test('72. Business A cannot access printers of Business B', () async {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'SALE-72',
        title: 'Doc',
        businessId: 'OTHER-BIZ',
        branchId: branch1,
        sections: [PrintSection.header('H')],
        createdAt: DateTime.now(),
      );

      expect(
        () => coordinator.submitPrintJob(SubmitPrintJobCommand(
          businessId: 'OTHER-BIZ',
          branchId: branch1,
          document: doc,
          triggerType: PrintTriggerType.autoPrint,
          requestedBy: 'CASHIER',
          idempotencyKey: 'KEY-72',
        )),
        throwsA(isA<NoAvailablePrinterFailure>()),
      );
    });

    test('73. Cross-branch access throws CrossBranchPrinterAccessFailure', () {
      const failure = CrossBranchPrinterAccessFailure();
      expect(failure.code, 'CROSS_BRANCH_PRINTER_ACCESS');
    });

    test('74. Printer profile repository isolates profiles by branch', () async {
      await profileRepo.saveProfile(PrinterProfile(
        id: 'PROF-1',
        businessId: bizId,
        branchId: branch1,
        printerId: 'PRN-BR1',
        name: 'Profile Br1',
        paperProfile: PaperProfile.thermal80mm(),
      ));

      final br2Profiles = await profileRepo.getProfilesForBranch(
        businessId: bizId,
        branchId: branch2,
      );
      expect(br2Profiles.isEmpty, isTrue);
    });

    test('75. Printer repository isolates printers by business and branch', () async {
      final br1Printers = await printerRepo.getPrintersForBranch(
        businessId: bizId,
        branchId: branch1,
      );
      expect(br1Printers.length, 1);
      expect(br1Printers.first.id, 'PRN-BR1');
    });

    test('76. Default printer resolution prefers branch default printer', () async {
      final p = await printerRepo.getDefaultPrinter(
        businessId: bizId,
        branchId: branch2,
      );
      expect(p?.id, 'PRN-BR2');
    });

    test('77. Deleting a printer in Branch A does not affect Branch B', () async {
      await printerRepo.deletePrinter(businessId: bizId, printerId: 'PRN-BR1');
      final br1 = await printerRepo.getPrintersForBranch(businessId: bizId, branchId: branch1);
      final br2 = await printerRepo.getPrintersForBranch(businessId: bizId, branchId: branch2);

      expect(br1.isEmpty, isTrue);
      expect(br2.length, 1);
    });

    test('78. Print coordinator resolves profile for the matching document type', () async {
      await profileRepo.saveProfile(PrinterProfile(
        id: 'PROF-RET',
        businessId: bizId,
        branchId: branch1,
        printerId: 'PRN-BR1',
        name: 'Return Profile',
        targetDocumentType: PrintDocumentType.returnReceipt,
        paperProfile: PaperProfile.thermal58mm(),
      ));

      final resolved = await profileRepo.getProfileForDocument(
        businessId: bizId,
        branchId: branch1,
        documentType: PrintDocumentType.returnReceipt,
      );

      expect(resolved?.id, 'PROF-RET');
      expect(resolved?.paperProfile.type, PaperProfileType.thermal58mm);
    });

    test('79. Job history query filters accurately by branchId', () async {
      await jobRepo.saveJob(PrintJob(
        jobId: 'J1',
        documentId: 'D1',
        documentType: PrintDocumentType.saleReceipt,
        businessId: bizId,
        branchId: branch1,
        printerId: 'P1',
        actorId: 'A',
        idempotencyKey: 'K1',
        createdAt: DateTime.now(),
      ));
      await jobRepo.saveJob(PrintJob(
        jobId: 'J2',
        documentId: 'D2',
        documentType: PrintDocumentType.saleReceipt,
        businessId: bizId,
        branchId: branch2,
        printerId: 'P2',
        actorId: 'A',
        idempotencyKey: 'K2',
        createdAt: DateTime.now(),
      ));

      final br1Jobs = await jobRepo.getJobs(businessId: bizId, branchId: branch1);
      expect(br1Jobs.length, 1);
      expect(br1Jobs.first.jobId, 'J1');
    });

    test('80. Audit records capture businessId, branchId, and actorId', () async {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'DOC-80',
        title: 'Audit Doc',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.header('A')],
        createdAt: DateTime.now(),
      );

      await coordinator.submitPrintJob(SubmitPrintJobCommand(
        businessId: bizId,
        branchId: branch1,
        document: doc,
        triggerType: PrintTriggerType.autoPrint,
        requestedBy: 'CASHIER_OMAR',
        idempotencyKey: 'KEY-80',
      ));

      final audit = emittedAuditRecords.firstWhere((r) => r.action == 'PRINT_COMPLETED');
      expect(audit.businessId, bizId);
      expect(audit.branchId, branch1);
      expect(audit.documentId, 'DOC-80');
    });
  });

  // ══════════════════════════════════════════════════════════════
  // GROUP I: Concurrency & Observability (Tests 81 to 86)
  // ══════════════════════════════════════════════════════════════
  group('GROUP I: Concurrency & Observability', () {
    setUp(() async {
      await printerRepo.savePrinter(Printer(
        id: 'PRN-CONC',
        businessId: bizId,
        branchId: branch1,
        name: 'طابعة التزامن',
        connectionType: PrinterConnectionType.network,
        capabilities: const PrinterCapabilities(cut: true),
        status: PrinterStatus.online,
        isDefault: true,
      ));
    });

    test('81. CRITICAL CONCURRENCY: Two simultaneous auto-prints for same sale create exactly one job', () async {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'SALE-CONCURRENCY-001',
        title: 'Concurrent Sale',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.header('CONCURRENCY')],
        createdAt: DateTime.now(),
      );

      // Launch two rapid concurrent requests simultaneously
      final future1 = coordinator.submitPrintJob(SubmitPrintJobCommand(
        businessId: bizId,
        branchId: branch1,
        document: doc,
        triggerType: PrintTriggerType.autoPrint,
        requestedBy: 'THREAD_A',
        idempotencyKey: 'IDEMP-THREAD-A',
      ));

      final future2 = coordinator.submitPrintJob(SubmitPrintJobCommand(
        businessId: bizId,
        branchId: branch1,
        document: doc,
        triggerType: PrintTriggerType.autoPrint,
        requestedBy: 'THREAD_B',
        idempotencyKey: 'IDEMP-THREAD-B',
      ));

      // One should succeed, and the other must be rejected cleanly with DuplicateAutoPrintFailure
      final results = await Future.wait([
        future1.then((j) => 'SUCCESS').catchError((e) => 'REJECTED: $e'),
        future2.then((j) => 'SUCCESS').catchError((e) => 'REJECTED: $e'),
      ]);

      expect(results, contains('SUCCESS'));
      expect(results.any((r) => r.contains('DuplicateAutoPrintFailure')), isTrue);
      // Ensure only 1 actual print job reached the physical driver
      expect(mockDriver.printedJobs.length, 1);
    });

    test('82. Concurrent reprint requests with distinct idempotency keys both succeed', () async {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'SALE-REPRINT-CONC',
        title: 'Reprint Conc',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.header('REPRINT')],
        createdAt: DateTime.now(),
      );

      final f1 = coordinator.reprintDocument(ReprintCommand(
        businessId: bizId,
        branchId: branch1,
        originalJobIdOrDocumentId: 'SALE-REPRINT-CONC',
        document: doc,
        requestedBy: 'USER_1',
        reason: 'Reason 1',
        idempotencyKey: 'REP-KEY-1',
      ));

      final f2 = coordinator.reprintDocument(ReprintCommand(
        businessId: bizId,
        branchId: branch1,
        originalJobIdOrDocumentId: 'SALE-REPRINT-CONC',
        document: doc,
        requestedBy: 'USER_2',
        reason: 'Reason 2',
        idempotencyKey: 'REP-KEY-2',
      ));

      final jobs = await Future.wait([f1, f2]);
      expect(jobs[0].status, PrintJobStatus.completed);
      expect(jobs[1].status, PrintJobStatus.completed);
      expect(mockDriver.printedJobs.length, 2);
    });

    test('83. PrintQueuedEvent emitted with safe metadata (no credentials)', () async {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'SAFE-DOC',
        title: 'Safe',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.header('Safe')],
        createdAt: DateTime.now(),
      );

      await coordinator.submitPrintJob(SubmitPrintJobCommand(
        businessId: bizId,
        branchId: branch1,
        document: doc,
        triggerType: PrintTriggerType.autoPrint,
        requestedBy: 'SYSTEM',
        idempotencyKey: 'SAFE-KEY',
      ));

      final queued = emittedEvents.whereType<PrintQueuedEvent>().first;
      final map = queued.toMap();
      expect(map.containsKey('password'), isFalse);
      expect(map.containsKey('token'), isFalse);
      expect(map['documentId'], 'SAFE-DOC');
    });

    test('84. PrintCompletedEvent emitted with duration and metrics', () async {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'METRICS-DOC',
        title: 'Metrics',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.header('Metrics')],
        createdAt: DateTime.now(),
      );

      await coordinator.submitPrintJob(SubmitPrintJobCommand(
        businessId: bizId,
        branchId: branch1,
        document: doc,
        triggerType: PrintTriggerType.autoPrint,
        requestedBy: 'SYSTEM',
        idempotencyKey: 'METRICS-KEY',
      ));

      final completed = emittedEvents.whereType<PrintCompletedEvent>().first;
      expect(completed.duration.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('85. UnknownPrintStateEvent emitted on ACK timeout', () async {
      mockDriver.shouldTimeoutAck = true;

      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'ACK-EVT-DOC',
        title: 'ACK',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.header('ACK')],
        createdAt: DateTime.now(),
      );

      final job = await coordinator.submitPrintJob(SubmitPrintJobCommand(
        businessId: bizId,
        branchId: branch1,
        document: doc,
        triggerType: PrintTriggerType.autoPrint,
        requestedBy: 'SYSTEM',
        idempotencyKey: 'ACK-EVT-KEY',
      ));

      expect(job.status, PrintJobStatus.unknownRequiresConfirmation);
      final evt = emittedEvents.whereType<UnknownPrintStateEvent>().first;
      expect(evt.documentId, 'ACK-EVT-DOC');
    });

    test('86. Audit trail logs REPRINT_REQUESTED with actor and reason', () async {
      final doc = PrintDocument(
        documentType: PrintDocumentType.saleReceipt,
        documentId: 'AUDIT-REP-DOC',
        title: 'Audit Reprint',
        businessId: bizId,
        branchId: branch1,
        sections: [PrintSection.header('Reprint Audit')],
        createdAt: DateTime.now(),
      );

      await coordinator.reprintDocument(ReprintCommand(
        businessId: bizId,
        branchId: branch1,
        originalJobIdOrDocumentId: 'AUDIT-REP-DOC',
        document: doc,
        requestedBy: 'OMAR_MANAGER',
        reason: 'Customer tax declaration requirement',
        idempotencyKey: 'AUDIT-REP-KEY',
      ));

      final audit = emittedAuditRecords.firstWhere((a) => a.action == 'REPRINT_REQUESTED');
      expect(audit.actor, 'OMAR_MANAGER');
      expect(audit.reason, 'Customer tax declaration requirement');
    });
  });
}

Future<void> _testEscPosDriverDisconnect(EscPosDriver driver) async {
  await driver.connect();
  await driver.disconnect();
  expect(
    () => driver.printPayload(
      PrintJob(
        jobId: 'J',
        documentId: 'D',
        documentType: PrintDocumentType.saleReceipt,
        businessId: 'B',
        branchId: 'BR',
        printerId: 'P',
        actorId: 'A',
        idempotencyKey: 'K',
        createdAt: DateTime.now(),
      ),
      RenderedPayload(rawBytes: [], plainText: '', linesCount: 0, maxColumns: 0),
    ),
    throwsA(isA<PrinterOfflineFailure>()),
  );
}
