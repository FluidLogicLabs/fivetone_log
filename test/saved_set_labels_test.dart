import 'package:flutter_test/flutter_test.dart';
import 'package:fivethreeone_log/app/interactor/models/set_model.dart';
import 'package:fivethreeone_log/app/utils/saved_set_labels.dart';
import 'package:fivethreeone_log/app/utils/session_plan.dart';
import 'package:fivethreeone_log/app/utils/utils.dart';

/// Week one of a cycle for a lift whose training max is 100: the ladder, three
/// working sets at 65/75/85, then five FSL sets at 65.
SessionPlan _weekOnePlan({bool warmups = true, bool fsl = true}) {
  return buildSessionPlan(
    trainingMax: 100,
    weekPercentages: const [65.0, 75.0, 85.0],
    mainReps: mainRepsForWeek(1),
    includeWarmups: warmups,
    includeFsl: fsl,
  );
}

List<SetModel> _sets(List<double> weights, {int reps = 5}) {
  return [
    for (int i = 0; i < weights.length; i++)
      SetModel(setNumber: i + 1, reps: reps, weight: weights[i]),
  ];
}

void main() {
  group('labelSavedSets', () {
    test('eleven saved sets read as three warmups, three working, five FSL',
        () {
      final labels =
          labelSavedSets(savedCount: 11, plan: _weekOnePlan());

      expect(labels.matched, isTrue);
      expect(labels.length, 11);
      expect(labels.groups.take(3), everyElement(SavedSetGroup.warmup));
      expect(labels.groups.skip(3).take(3), everyElement(SavedSetGroup.working));
      expect(labels.groups.skip(6), everyElement(SavedSetGroup.fsl));
      expect(labels.lastWorkingIndex, 5);
    });

    test('a workout saved with warmups off and FSL on is working then FSL', () {
      final labels = labelSavedSets(
        savedCount: 8,
        plan: _weekOnePlan(warmups: false, fsl: true),
      );

      expect(labels.matched, isTrue);
      expect(labels.groups.take(3), everyElement(SavedSetGroup.working));
      expect(labels.groups.skip(3), everyElement(SavedSetGroup.fsl));
      expect(labels.lastWorkingIndex, 2);
    });

    test('a legacy three set workout is read as the three working sets', () {
      final labels = labelSavedSets(
        savedCount: 3,
        plan: _weekOnePlan(),
      );

      expect(labels.matched, isTrue);
      expect(labels.groups, everyElement(SavedSetGroup.working));
      expect(labels.lastWorkingIndex, 2);
    });

    test('six sets still label as ladder plus working when FSL is off now', () {
      final labels = labelSavedSets(
        savedCount: 6,
        plan: _weekOnePlan(fsl: false),
      );

      expect(labels.matched, isTrue);
      expect(labels.groups.take(3), everyElement(SavedSetGroup.warmup));
      expect(labels.groups.skip(3), everyElement(SavedSetGroup.working));
    });

    test('a set count that matches no shape is numbered, not hidden', () {
      final labels = labelSavedSets(
        savedCount: 4,
        plan: _weekOnePlan(),
      );

      expect(labels.matched, isFalse);
      expect(labels.length, 4);
      expect(labels.groups, everyElement(SavedSetGroup.unknown));
      expect(labels.lastWorkingIndex, isNull);
    });

    test('a lift with no percentage table in any week is numbered', () {
      final plan = buildSessionPlan(
        trainingMax: 0,
        weekPercentages: const [],
        mainReps: mainRepsForWeek(1),
      );

      final labels = labelSavedSets(savedCount: 2, plan: plan);

      expect(labels.matched, isFalse);
      expect(labels.length, 2);
    });

    test('an empty workout has no labels', () {
      final labels = labelSavedSets(savedCount: 0, plan: _weekOnePlan());

      expect(labels.isEmpty, isTrue);
      expect(labels.matched, isFalse);
    });
  });

  group('totalVolumeOfSets', () {
    test('adds every set that is kept, warmups and FSL included', () {
      final sets = _sets([40.0, 50.0, 60.0]);

      expect(totalVolumeOfSets(sets), 750.0);
    });
  });

  group('lastWorkingSet', () {
    test('is the last working set, not the last set of the workout', () {
      final sets = _sets([40.0, 50.0, 60.0, 65.0, 75.0, 85.0, 65.0, 65.0, 65.0, 65.0, 65.0]);
      final labels = labelSavedSets(savedCount: 11, plan: _weekOnePlan());

      expect(labels.lastWorkingIndex, 5);
      expect(lastWorkingSet(sets, labels), sets[5]);
      expect(lastWorkingSet(sets, labels), isNot(sets.last));
    });

    test('is found again when the shape is working sets plus FSL', () {
      final sets = _sets([60.0, 70.0, 80.0, 95.0, 95.0, 95.0, 95.0, 95.0]);
      final labels = labelSavedSets(
        savedCount: 8,
        plan: _weekOnePlan(warmups: false, fsl: true),
      );

      expect(labels.groups.take(3), everyElement(SavedSetGroup.working));
      expect(lastWorkingSet(sets, labels), sets[2]);
    });
  });

  group('recalculatedOneRM', () {
    test('comes from the last working set even when an FSL set is heavier',
        () {
      // A mis-logged FSL set at 95 kilos sits at the end of the workout. The
      // estimate has to stay on the 80 kilo working set.
      final sets = _sets([40.0, 50.0, 60.0, 60.0, 70.0, 80.0, 95.0, 95.0, 95.0, 95.0, 95.0]);
      final labels = labelSavedSets(savedCount: 11, plan: _weekOnePlan());

      expect(
        recalculatedOneRM(sets, labels, storedOneRM: 1),
        calculate1RM(80, 5),
      );
      expect(
        recalculatedOneRM(sets, labels, storedOneRM: 1),
        isNot(calculate1RM(95, 5)),
      );
    });

    test('a workout without the ladder still estimates from its last working set',
        () {
      final sets = _sets([60.0, 70.0, 80.0, 95.0, 95.0, 95.0, 95.0, 95.0]);
      final labels = labelSavedSets(
        savedCount: 8,
        plan: _weekOnePlan(warmups: false, fsl: true),
      );

      expect(
        recalculatedOneRM(sets, labels, storedOneRM: 1),
        calculate1RM(80, 5),
      );
    });

    test('a labelled workout with no working set stores zero, not nonsense',
        () {
      const labels = SavedSetLabels(
        groups: [SavedSetGroup.warmup, SavedSetGroup.warmup],
        matched: true,
      );

      expect(
        recalculatedOneRM(_sets([40.0, 50.0]), labels, storedOneRM: 120),
        0.0,
      );
    });

    test('an unlabelled workout keeps the estimate it was saved with', () {
      final labels = labelSavedSets(savedCount: 4, plan: _weekOnePlan());
      final sets = _sets([60.0, 70.0, 80.0, 90.0]);

      expect(labels.matched, isFalse);
      expect(
        recalculatedOneRM(sets, labels, storedOneRM: 120),
        120.0,
      );
    });
  });
}
