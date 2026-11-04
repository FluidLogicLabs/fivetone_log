import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fivethreeone_log/app/data/adapters/accessory_exercise_adapter.dart';
import 'package:fivethreeone_log/app/interactor/models/accessory_exercise_model.dart';

// These two helpers mirror exactly what
// SharedPreferencesAccessoryExerciseRepository writes to and reads from the
// 'accessoryExercises' key. SharedPreferences itself is never instantiated here,
// so the tests stay pure and need no test binding.

String encodeCatalogue(List<AccessoryExerciseModel> exercises) {
  return jsonEncode(
    exercises.map((exercise) => AccessoryExerciseAdapter.toMap(exercise)).toList(),
  );
}

List<AccessoryExerciseModel> decodeCatalogue(String catalogueString) {
  final catalogueList = List<Map<String, dynamic>>.from(
    jsonDecode(catalogueString) as List<dynamic>,
  );
  return catalogueList
      .map((exerciseMap) => AccessoryExerciseAdapter.fromMap(exerciseMap))
      .toList();
}

void main() {
  test('adapter round-trips a catalogue entry', () {
    const exercise = AccessoryExerciseModel(
      name: 'Face pull',
      lastUsedLift: 'Supino',
    );

    final map = AccessoryExerciseAdapter.toMap(exercise);
    final decoded = AccessoryExerciseAdapter.fromMap(map);

    expect(decoded, exercise);
  });

  test('missing lastUsedLift key decodes to null', () {
    final decoded = AccessoryExerciseAdapter.fromMap(<String, dynamic>{
      'name': 'Face pull',
    });

    expect(decoded.name, 'Face pull');
    expect(decoded.lastUsedLift, isNull);
  });

  test('a model with no lastUsedLift round-trips as null', () {
    const exercise = AccessoryExerciseModel(name: 'Face pull');

    final map = AccessoryExerciseAdapter.toMap(exercise);
    final decoded = AccessoryExerciseAdapter.fromMap(map);

    expect(decoded, exercise);
    expect(decoded.lastUsedLift, isNull);
    expect(map.containsKey('lastUsedLift'), isTrue);
  });

  test('lastUsedLift survives a full JSON string round trip', () {
    final catalogue = <AccessoryExerciseModel>[
      const AccessoryExerciseModel(name: 'Face pull', lastUsedLift: 'Supino'),
    ];

    final decoded = decodeCatalogue(encodeCatalogue(catalogue));

    expect(decoded, equals(catalogue));
    expect(decoded.first.lastUsedLift, 'Supino');
  });

  test('an empty catalogue string decodes to an empty list', () {
    final decoded = decodeCatalogue('[]');

    expect(decoded, isEmpty);
  });

  test('an empty catalogue encodes to an empty list', () {
    expect(encodeCatalogue(<AccessoryExerciseModel>[]), '[]');
  });

  test('a full catalogue round-trips without losing or reordering entries', () {
    final catalogue = <AccessoryExerciseModel>[
      const AccessoryExerciseModel(name: 'Face pull', lastUsedLift: 'Supino'),
      const AccessoryExerciseModel(name: 'Biceps curl'),
      const AccessoryExerciseModel(name: 'Ab roller', lastUsedLift: 'Agachamento'),
    ];

    final decoded = decodeCatalogue(encodeCatalogue(catalogue));

    expect(decoded, equals(catalogue));
    expect(decoded.length, 3);
    expect(decoded[1].lastUsedLift, isNull);
  });

  test('copyWith renames an entry and keeps its lastUsedLift', () {
    const exercise = AccessoryExerciseModel(
      name: 'Face pull',
      lastUsedLift: 'Supino',
    );

    final renamed = exercise.copyWith(name: 'Face pulls');

    expect(renamed.name, 'Face pulls');
    expect(renamed.lastUsedLift, 'Supino');
  });

  test('copyWith sets lastUsedLift without touching the name', () {
    const exercise = AccessoryExerciseModel(name: 'Face pull');

    final touched = exercise.copyWith(lastUsedLift: 'Desenvolvimento militar');

    expect(touched.name, 'Face pull');
    expect(touched.lastUsedLift, 'Desenvolvimento militar');
    expect(touched, isNot(exercise));
  });

  test('equal models share an equality and a hashCode', () {
    const first = AccessoryExerciseModel(name: 'Face pull', lastUsedLift: 'Supino');
    const second = AccessoryExerciseModel(name: 'Face pull', lastUsedLift: 'Supino');

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });
}
