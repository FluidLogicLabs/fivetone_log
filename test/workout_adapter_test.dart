import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fivethreeone_log/app/data/adapters/set_adapter.dart';
import 'package:fivethreeone_log/app/data/adapters/workout_adapter.dart';
import 'package:fivethreeone_log/app/interactor/models/set_model.dart';
import 'package:fivethreeone_log/app/interactor/models/workout_model.dart';

void main() {
  test('accessory workout keeps isAccessory true through WorkoutAdapter', () {
    final workout = WorkoutModel(
      id: '1',
      date: DateTime(2026, 11, 4, 18, 30),
      exerciseName: 'Rosca direta',
      numberOfSets: 3,
      sets: const [
        SetModel(setNumber: 1, reps: 8, weight: 60.0),
        SetModel(setNumber: 2, reps: 8, weight: 60.0),
        SetModel(setNumber: 3, reps: 7, weight: 55.0),
      ],
      notes: '',
      oneRM: 0,
      volume: 0,
      timeSpent: Duration.zero,
      cycle: 2,
      week: 3,
      isAccessory: true,
    );

    final decoded = WorkoutAdapter.fromMap(WorkoutAdapter.toMap(workout));

    expect(decoded.isAccessory, isTrue);
    expect(decoded, workout);
  });

  test('accessory flag survives the JSON encoding used for storage', () {
    final workout = WorkoutModel(
      id: '7',
      date: DateTime(2026, 11, 4, 7, 15),
      exerciseName: 'Paralelas',
      numberOfSets: 2,
      sets: const [
        SetModel(setNumber: 1, reps: 10, weight: 0.0),
        SetModel(setNumber: 2, reps: 9, weight: 0.0),
      ],
      notes: '',
      oneRM: 0,
      volume: 0,
      timeSpent: Duration.zero,
      cycle: 1,
      week: 2,
      isAccessory: true,
    );

    final stored = jsonEncode(WorkoutAdapter.toMap(workout));
    final decoded =
        WorkoutAdapter.fromMap(jsonDecode(stored) as Map<String, dynamic>);

    expect(decoded.isAccessory, isTrue);
    expect(decoded, workout);
  });

  test('stored map without isAccessory decodes to false (old data)', () {
    final map = <String, dynamic>{
      'id': '2',
      'date': DateTime(2026, 10, 1, 8, 30).toIso8601String(),
      'exerciseName': 'Agachamento',
      'numberOfSets': 1,
      'sets': <Map<String, dynamic>>[
        <String, dynamic>{'setNumber': 1, 'reps': 5, 'weight': 100.0},
      ],
      'notes': 'nota',
      'oneRM': 117.0,
      'volume': 500.0,
      'timeSpent': 600,
      'cycle': 1,
      'week': 1,
    };

    final decoded = WorkoutAdapter.fromMap(map);

    expect(decoded.isAccessory, isFalse);
  });

  test('a bodyweight set keeps weight 0.0 through SetAdapter', () {
    const set = SetModel(setNumber: 1, reps: 10, weight: 0.0);

    final decoded = SetAdapter.fromMap(SetAdapter.toMap(set));

    expect(decoded.weight, 0.0);
    expect(decoded, set);
  });

  test('main lift model defaults to isAccessory false and is unchanged', () {
    final workout = WorkoutModel(
      id: '3',
      date: DateTime(2026, 9, 12, 19, 0),
      exerciseName: 'Supino',
      numberOfSets: 3,
      sets: const [
        SetModel(setNumber: 1, reps: 5, weight: 80.0),
        SetModel(setNumber: 2, reps: 5, weight: 80.0),
        SetModel(setNumber: 3, reps: 5, weight: 80.0),
      ],
      notes: 'bem',
      oneRM: 93.0,
      volume: 1200.0,
      timeSpent: const Duration(seconds: 1700),
      cycle: 3,
      week: 2,
    );

    expect(workout.isAccessory, isFalse);

    final decoded = WorkoutAdapter.fromMap(WorkoutAdapter.toMap(workout));

    expect(decoded.isAccessory, isFalse);
    expect(decoded, workout);
    expect(decoded.exerciseName, 'Supino');
    expect(decoded.numberOfSets, 3);
    expect(decoded.notes, 'bem');
    expect(decoded.oneRM, 93.0);
    expect(decoded.volume, 1200.0);
    expect(decoded.timeSpent, const Duration(seconds: 1700));
    expect(decoded.cycle, 3);
    expect(decoded.week, 2);
  });
}
