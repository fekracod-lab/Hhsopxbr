// مخطط التبعيات والترتيب السببي لأوامر المزامنة (MADAR SHOP Command Dependency Graph)
// Pure Dart — Zero UI Dependencies

import '../entities/sync_command_envelope.dart';

class CommandDependencyGraph {
  /// ترتيب قائمة الأوامر حسب التسلسل السببي والتبعية لكل كيان
  /// يحافظ على الترتيب التصاعدي للـ sequence ويفصل بين الكيانات
  static List<SyncCommandEnvelope> orderCommands(List<SyncCommandEnvelope> commands) {
    if (commands.isEmpty) return const [];

    // 1. فرز حسب وقت الإنشاء والتسلسل للجهاز Monotonic Sequence أولاً
    final sorted = List<SyncCommandEnvelope>.from(commands)
      ..sort((a, b) {
        final seqCmp = a.sequence.compareTo(b.sequence);
        if (seqCmp != 0) return seqCmp;
        return a.createdAt.compareTo(b.createdAt);
      });

    // 2. التحقق من التبعيات الصريحة إذا وجدت في payload
    // مثلاً: "dependsOnCommandId"
    final idMap = {for (var c in sorted) c.commandId: c};
    final visited = <String>{};
    final result = <SyncCommandEnvelope>[];

    void visit(SyncCommandEnvelope command) {
      if (visited.contains(command.commandId)) return;

      final dependsOn = command.payload['dependsOnCommandId'] as String?;
      if (dependsOn != null && idMap.containsKey(dependsOn)) {
        visit(idMap[dependsOn]!);
      }

      visited.add(command.commandId);
      result.add(command);
    }

    for (final cmd in sorted) {
      visit(cmd);
    }

    return result;
  }

  /// تجميع الأوامر حسب الكيان (Entity Stream) لضمان المعالجة المتسلسلة لنفس المنتج أو الفاتورة
  static Map<String, List<SyncCommandEnvelope>> groupByEntityStream(List<SyncCommandEnvelope> commands) {
    final groups = <String, List<SyncCommandEnvelope>>{};
    for (final cmd in commands) {
      final key = '${cmd.entityType}:${cmd.entityId}';
      groups.putIfAbsent(key, () => []).add(cmd);
    }

    // ترتيب كل Stream حسب الـ sequence
    for (final list in groups.values) {
      list.sort((a, b) => a.sequence.compareTo(b.sequence));
    }

    return groups;
  }
}
