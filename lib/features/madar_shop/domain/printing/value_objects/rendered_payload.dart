// ناتج تصيير وثيقة الطباعة (MADAR SHOP Rendered Payload Value Object)
// Pure Dart — Zero UI Dependencies

import 'paper_profile.dart';

class RenderedPayload {
  final List<int> rawBytes;
  final String plainText;
  final int linesCount;
  final int maxColumns;
  final PaperProfile? paperProfile;
  final bool hasCutCommand;
  final bool hasDrawerKickCommand;
  final Map<String, dynamic> metadata;

  const RenderedPayload({
    required this.rawBytes,
    required this.plainText,
    int? linesCount,
    int? lineCount,
    int? maxColumns,
    int? characterWidth,
    this.paperProfile,
    this.hasCutCommand = false,
    bool? hasDrawerKickCommand,
    bool? hasDrawerKick,
    this.metadata = const {},
  })  : linesCount = linesCount ?? lineCount ?? 0,
        maxColumns = maxColumns ?? characterWidth ?? 0,
        hasDrawerKickCommand = hasDrawerKickCommand ?? hasDrawerKick ?? false;

  int get lineCount => linesCount;
  int get characterWidth => maxColumns;
  bool get hasDrawerKick => hasDrawerKickCommand;
  int get sizeInBytes => rawBytes.length;

  @override
  String toString() =>
      'RenderedPayload(bytes: $sizeInBytes, lines: $linesCount, cols: $maxColumns, cut: $hasCutCommand, drawer: $hasDrawerKickCommand)';
}
