import 'package:flutter_test/flutter_test.dart';
import 'package:fivethreeone_log/app/interactor/models/set_model.dart';
import 'package:fivethreeone_log/app/interactor/models/workout_model.dart';
import 'package:fivethreeone_log/app/utils/session_accessories.dart';

WorkoutModel _workout({
  required String id,
  required String name,
  required DateTime date,
  bool isAccessory = false,
  int cycle = 3,
  int week = 1,
}) {
  return WorkoutModel(
    id: id,
    date: date,
    exerciseName: name,
    numberOfSets: 1,
    sets: const [SetModel(setNumber: 1, reps: 8, weight: 60)],
    oneRM: isAccessory ? 0 : 100,
    volume: isAccessory ? 0 : 480,
    timeSpent: Duration.zero,
    cycle: cycle,
    week: week,
    isAccessory: isAccessory,
  );
}

void main() {
  final DateTime sessionStart = DateTime(2026, 11, 6, 18, 12, 4);

  test('accessory rows saved with the session come back, sorted by name', () {
    final main = _workout(id: '1', name: 'Supino', date: sessionStart);
    final all = [
      main,
      _workout(
        id: '2',
        name: 'Triceps',
        date: sessionStart.add(const Duration(milliseconds: 900)),
        isAccessory: true,
      ),
      _workout(
        id: '3',
        name: 'Remada',
        date: sessionStart.add(const Duration(milliseconds: 1100)),
        isAccessory: true,
      ),
    ];

    final accessory = accessoryWorkoutsForSession(main, all);

    expect(accessory.map((workout) => workout.id), ['3', '2']);
  });

  test('an accessory row from another day or cycle is left out', () {
    final main = _workout(id: '1', name: 'Supino', date: sessionStart);
    final all = [
      main,
      _workout(
        id: '2',
        name: 'Triceps',
        date: sessionStart.add(const Duration(days: 1)),
        isAccessory: true,
      ),
      _workout(
        id: '3',
        name: 'Remada',
        date: sessionStart,
        isAccessory: true,
        cycle: 4,
      ),
      _workout(
        id: '4',
        name: 'Rosca',
        date: sessionStart,
        isAccessory: true,
        week: 2,
      ),
      _workout(id: '5', name: 'Agachamento', date: sessionStart),
    ];

    expect(accessoryWorkoutsForSession(main, all), isEmpty);
  });

  test('editing an accessory row itself shows no accessory section', () {
    final accessory = _workout(
      id: '2',
      name: 'Triceps',
      date: sessionStart,
      isAccessory: true,
    );
    final all = [
      _workout(id: '1', name: 'Supino', date: sessionStart),
      accessory,
      _workout(
        id: '3',
        name: 'Remada',
        date: sessionStart,
        isAccessory: true,
      ),
    ];

    expect(accessoryWorkoutsForSession(accessory, all), isEmpty);
  });
}
