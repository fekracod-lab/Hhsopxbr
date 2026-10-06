import 'package:flutter/foundation.dart';
import 'failure_injection.dart';

/// سيناريو فحص الفوضى والتعافي التشغيلي (Chaos Scenario Definition)
@immutable
class ChaosScenario {
  final String scenarioId;
  final String name;
  final String description;
  final List<FailureInjection> injections;
  final Duration duration;
  final List<String> assertions;

  const ChaosScenario({
    required this.scenarioId,
    required this.name,
    required this.description,
    this.injections = const [],
    this.duration = const Duration(seconds: 30),
    this.assertions = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'scenarioId': scenarioId,
      'name': name,
      'description': description,
      'injections': injections.map((i) => i.toMap()).toList(),
      'durationMs': duration.inMilliseconds,
      'assertions': assertions,
    };
  }

  factory ChaosScenario.fromMap(Map<String, dynamic> map, String docId) {
    final injList = (map['injections'] as List?)
            ?.map((e) => FailureInjection.fromMap(Map<String, dynamic>.from(e as Map), (e)['injectionId']?.toString() ?? ''))
            .toList() ??
        [];

    return ChaosScenario(
      scenarioId: docId,
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      injections: injList,
      duration: Duration(milliseconds: (map['durationMs'] as num?)?.toInt() ?? 30000),
      assertions: (map['assertions'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
