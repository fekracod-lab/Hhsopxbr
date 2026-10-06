// كيان الطابعة الفيزيائية/الشبكية (MADAR SHOP Printer Entity)
// Pure Dart — Zero UI Dependencies

import '../enums/printer_connection_type.dart';
import '../enums/printer_status.dart';
import '../value_objects/paper_profile.dart';
import '../value_objects/printer_capabilities.dart';

class Printer {
  final String id;
  final String businessId;
  final String branchId;
  final String name;
  final String manufacturer;
  final String model;
  final PrinterConnectionType connectionType;
  final PrinterCapabilities capabilities;
  final PaperProfile paperProfile;
  final PrinterStatus status;
  final String? ipAddress;
  final int? port;
  final String? bluetoothAddress;
  final String? windowsDeviceName;
  final bool isDefault;
  final DateTime lastSeenAt;
  final Map<String, dynamic> metadata;

  Printer({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.name,
    this.manufacturer = 'Generic',
    this.model = 'Standard POS',
    required this.connectionType,
    required this.capabilities,
    PaperProfile? paperProfile,
    this.status = PrinterStatus.online,
    this.ipAddress,
    this.port,
    this.bluetoothAddress,
    this.windowsDeviceName,
    this.isDefault = false,
    DateTime? lastSeenAt,
    this.metadata = const {},
  })  : paperProfile = paperProfile ?? PaperProfile.thermal80mm(),
        lastSeenAt = lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  bool get isReadyToPrint => status.isReady;

  bool supportsPaperCut() => capabilities.cut && paperProfile.supportsCut;
  bool supportsCashDrawer() => capabilities.drawer && paperProfile.supportsDrawer;
  bool supportsQr() => capabilities.qr;
  bool supportsBarcode() => capabilities.barcode;

  Printer copyWith({
    String? name,
    String? manufacturer,
    String? model,
    PrinterConnectionType? connectionType,
    PrinterCapabilities? capabilities,
    PaperProfile? paperProfile,
    PrinterStatus? status,
    String? ipAddress,
    int? port,
    String? bluetoothAddress,
    String? windowsDeviceName,
    bool? isDefault,
    DateTime? lastSeenAt,
    Map<String, dynamic>? metadata,
  }) {
    return Printer(
      id: id,
      businessId: businessId,
      branchId: branchId,
      name: name ?? this.name,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      connectionType: connectionType ?? this.connectionType,
      capabilities: capabilities ?? this.capabilities,
      paperProfile: paperProfile ?? this.paperProfile,
      status: status ?? this.status,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      bluetoothAddress: bluetoothAddress ?? this.bluetoothAddress,
      windowsDeviceName: windowsDeviceName ?? this.windowsDeviceName,
      isDefault: isDefault ?? this.isDefault,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Printer &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          businessId == other.businessId &&
          branchId == other.branchId;

  @override
  int get hashCode => id.hashCode ^ businessId.hashCode ^ branchId.hashCode;

  @override
  String toString() =>
      'Printer(id: $id, name: $name, type: $connectionType, status: $status)';
}
