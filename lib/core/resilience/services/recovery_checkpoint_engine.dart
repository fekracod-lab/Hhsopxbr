import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../entities/recovery_checkpoint.dart';

/// محرك إنشاء وتدقيق نقاط التفتيش التشغيلية (Recovery Checkpoint Engine)
class RecoveryCheckpointEngine {
  final Map<String, RecoveryCheckpoint> _checkpoints = {};

  RecoveryCheckpointEngine();

  Map<String, RecoveryCheckpoint> get checkpoints => Map.unmodifiable(_checkpoints);

  /// حفظ نقطة تفتيش مع توثيق الـ SHA-256 Integrity Hash
  Future<RecoveryCheckpoint> saveCheckpoint({
    required String operationId,
    required String domainType,
    required String state,
    int version = 1,
    int lastKnownServerVersion = 1,
    required String correlationId,
    Map<String, dynamic> payload = const {},
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();

    // حساب الـ Hash لضمان سلامة نقطة التفتيش من التلاعب
    final rawData = '$operationId|$domainType|$state|$version|$lastKnownServerVersion|${timestamp.toIso8601String()}|$correlationId|${jsonEncode(payload)}';
    final integrityHash = sha256.convert(utf8.encode(rawData)).toString();

    final checkpoint = RecoveryCheckpoint(
      checkpointId: 'chk_$operationId',
      operationId: operationId,
      domainType: domainType,
      state: state,
      version: version,
      lastKnownServerVersion: lastKnownServerVersion,
      checkpointTimestamp: timestamp,
      correlationId: correlationId,
      integrityHash: integrityHash,
      payload: payload,
    );

    _checkpoints[operationId] = checkpoint;
    return checkpoint;
  }

  void saveRawCheckpoint(RecoveryCheckpoint checkpoint) {
    _checkpoints[checkpoint.operationId] = checkpoint;
  }

  RecoveryCheckpoint? getLatestCheckpoint(String operationId) {
    return _checkpoints[operationId];
  }

  bool verifyCheckpointIntegrity(RecoveryCheckpoint checkpoint) {
    final rawData = '${checkpoint.operationId}|${checkpoint.domainType}|${checkpoint.state}|${checkpoint.version}|${checkpoint.lastKnownServerVersion}|${checkpoint.checkpointTimestamp.toIso8601String()}|${checkpoint.correlationId}|${jsonEncode(checkpoint.payload)}';
    final computedHash = sha256.convert(utf8.encode(rawData)).toString();
    return computedHash == checkpoint.integrityHash;
  }

  Future<void> removeCheckpoint(String operationId) async {
    _checkpoints.remove(operationId);
  }

  void clear() {
    _checkpoints.clear();
  }
}
