import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fivethreeone_log/app/interactor/models/accessory_exercise_model.dart';
import 'package:fivethreeone_log/app/interactor/models/preferences_model.dart';
import 'package:fivethreeone_log/app/interactor/models/set_model.dart';
import 'package:fivethreeone_log/app/interactor/models/workout_model.dart';
import 'package:fivethreeone_log/app/utils/backup.dart';

/// The file as it survives a real export and import: encoded to json, decoded
/// back, then read into models.
BackupData? _throughTheFile(BackupData data) {
  final String written = jsonEncode(backupToMap(data));
  return backupFromMap(jsonDecode(written) as Map<String, dynamic>);
}

PreferencesModel _preferences() {
  return const PreferencesModel(
    selectedUnit: 'kg',
    rmData: {'Supino': 120.0, 'Agachamento': 150.0},
    percData: {
      'Semana 1': {'Série 1': 65.0, 'Série 2': 75.0, 'Série 3': 85.0},
    },
    cycleWeekData: {
      'Supino': {'cycle': 2, 'week': 3},
    },
    tmData: {'Supino': 108.0},
    warmupSetsEnabled: false,
    fslData: {'Supino': true},
    roundingStep: 0.5,
    tmPercent: 90.0,
    cycleIncrement: {'Supino': 2.5, 'Agachamento': 10.0},
  );
}

WorkoutModel _workout() {
  return WorkoutModel(
    id: '1',
    date: DateTime(2026, 11, 5, 18, 30),
    exerciseName: 'Supino',
    numberOfSets: 1,
    sets: const [SetModel(setNumber: 1, reps: 5, weight: 90.0)],
    oneRM: 110,
    volume: 450,
    timeSpent: const Duration(minutes: 20),
    cycle: 2,
    week: 3,
  );
}

void main() {
  test('a backup keeps the three sections in the order they were written', () {
    final map = backupToMap(BackupData(
      workouts: [_workout()],
      preferences: _preferences(),
      accessoryExercises: const [
        AccessoryExerciseModel(name: 'Rosca direta', lastUsedLift: 'Supino'),
      ],
    ));

    expect(map.keys.toList(),
        ['workouts', 'preferences', 'accessoryExercises']);
    expect((map['workouts'] as List).length, 1);
    expect((map['accessoryExercises'] as List).length, 1);
  });

  test('every preference, including the new ones, survives a backup', () {
    final decoded = _throughTheFile(BackupData(
      workouts: [_workout()],
      preferences: _preferences(),
      accessoryExercises: const [],
    ));

    expect(decoded, isNotNull);
    expect(decoded!.preferences, _preferences());
    expect(decoded.preferences.roundingStep, 0.5);
    expect(decoded.preferences.tmPercent, 90.0);
    expect(decoded.preferences.cycleIncrement['Supino'], 2.5);
    expect(decoded.workouts!.single.exerciseName, 'Supino');
    expect(decoded.workouts!.single.sets.single.weight, 90.0);
  });

  test('a file with no catalogue leaves the catalogue alone, not empty', () {
    final map = <String, dynamic>{
      'workouts': <dynamic>[],
      'preferences': <String, dynamic>{
        'selectedUnit': 'kg',
        'rmData': <String, double>{},
        'percData': <String, dynamic>{},
        'cycleWeekData': <String, dynamic>{},
        'tmData': <String, double>{},
      },
    };

    final decoded = backupFromMap(map);

    expect(decoded, isNotNull);
    expect(decoded!.accessoryExercises, isNull);
    expect(decoded.workouts, isEmpty);
  });

  test('a file without a workouts list is still importable', () {
    final decoded = backupFromMap(<String, dynamic>{
      'preferences': <String, dynamic>{
        'selectedUnit': 'kg',
        'rmData': <String, double>{},
        'percData': <String, dynamic>{},
        'cycleWeekData': <String, dynamic>{},
        'tmData': <String, double>{},
      },
    });

    expect(decoded!.workouts, isNull);
    expect(decoded.preferences.tmPercent, 85.0);
  });

  test('a file with no preferences is not a backup', () {
    expect(backupFromMap(<String, dynamic>{'workouts': <dynamic>[]}), isNull);
    expect(backupFromMap(null), isNull);
  });
}
