import 'package:flutter_test/flutter_test.dart';
import 'package:fivethreeone_log/app/utils/session_plan.dart';

void main() {
  group('weightForPercentage', () {
    test('rounds up to the next whole unit, like the working sets', () {
      // 90 x 85% is 76.5, the working set table has always shown 77.
      expect(weightForPercentage(90, 85), 77.0);
      expect(weightForPercentage(100, 65), 65.0);
      expect(weightForPercentage(95, 65), 62.0); // 61.75
    });

    test('never rounds down, even when that lands well short of the fraction',
        () {
      expect(weightForPercentage(52.5, 65), 35.0); // 34.125
    });

    test('matches the working set table for a whole week', () {
      expect(
        [65.0, 75.0, 85.0].map((p) => weightForPercentage(90, p)).toList(),
        [59.0, 68.0, 77.0],
      );
    });
  });

  group('warmup ladder', () {
    test('is 40% x 5, 50% x 5, 60% x 3 of the training max', () {
      final sets = buildWarmupSets(100);

      expect(sets.map((set) => set.percentage).toList(), [40.0, 50.0, 60.0]);
      expect(sets.map((set) => set.reps).toList(), [5, 5, 3]);
      expect(sets.map((set) => set.weight).toList(), [40.0, 50.0, 60.0]);
    });

    test('weights round exactly like working weights', () {
      final sets = buildWarmupSets(95);

      expect(sets[0].weight, 38.0); // 38.0
      expect(sets[1].weight, 48.0); // 47.5 rounds up
      expect(sets[2].weight, 57.0); // 57.0
    });

    test('numbers the sets from one, or from the given start', () {
      expect(buildWarmupSets(100).map((set) => set.setNumber).toList(),
          [1, 2, 3]);
      expect(
          buildWarmupSets(100, startSetNumber: 7)
              .map((set) => set.setNumber)
              .toList(),
          [7, 8, 9]);
    });
  });

  group('FSL', () {
    test('is five sets of five at the first working set weight', () {
      final sets = buildFslSets(100, 65);

      expect(sets.length, 5);
      expect(sets.every((set) => set.reps == 5), isTrue);
      expect(sets.every((set) => set.weight == 65.0), isTrue);
      expect(sets.every((set) => set.percentage == 65.0), isTrue);
    });

    test('derives the weight from the first set percentage, with rounding', () {
      // 95 x 65% is 61.75: the FSL weight is the same 62 the first working set
      // shows, because both go through the same ceiling.
      expect(buildFslSets(95, 65).first.weight, 62.0);
      expect(buildFslSets(90, 85).first.weight, 77.0); // 76.5
    });

    test('carries the first set percentage for the label', () {
      final sets = buildFslSets(100, 85);

      expect(formatPercentageLabel(sets.first.percentage), '85%');
    });

    test('numbers the sets on from the given start', () {
      expect(buildFslSets(100, 65).map((set) => set.setNumber).toList(),
          [1, 2, 3, 4, 5]);
      expect(
          buildFslSets(100, 65, startSetNumber: 4)
              .map((set) => set.setNumber)
              .toList(),
          [4, 5, 6, 7, 8]);
    });
  });

  group('session plan', () {
    test('warmups, working sets, then FSL, numbered straight through', () {
      final plan = buildSessionPlan(
        trainingMax: 100,
        weekPercentages: [65, 75, 85],
        mainReps: [5, 5, 5],
        includeWarmups: true,
        includeFsl: true,
      );

      expect(plan.warmupSets.map((set) => set.percentage).toList(),
          [40.0, 50.0, 60.0]);
      expect(plan.mainSets.map((set) => set.percentage).toList(),
          [65.0, 75.0, 85.0]);
      expect(plan.fslSets.map((set) => set.weight).toList(),
          [65.0, 65.0, 65.0, 65.0, 65.0]);
      expect(plan.all.map((set) => set.setNumber).toList(),
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
      expect(plan.length, 11);
      expect(plan.all.map((set) => set.weight).toList(), [
        40.0, 50.0, 60.0, // warmups
        65.0, 75.0, 85.0, // working sets
        65.0, 65.0, 65.0, 65.0, 65.0, // FSL
      ]);
    });

    test('with both groups off it is exactly the working sets', () {
      final plan = buildSessionPlan(
        trainingMax: 100,
        weekPercentages: [65, 75, 85],
        mainReps: [5, 5, 5],
        includeWarmups: false,
        includeFsl: false,
      );

      expect(plan.warmupSets, isEmpty);
      expect(plan.fslSets, isEmpty);
      expect(plan.all.length, 3);
      expect(plan.all.map((set) => set.setNumber).toList(), [1, 2, 3]);
    });

    test('FSL on its own carries on from the working sets', () {
      final plan = buildSessionPlan(
        trainingMax: 100,
        weekPercentages: [65, 75, 85],
        mainReps: [5, 5, 5],
        includeWarmups: false,
        includeFsl: true,
      );

      expect(plan.warmupSets, isEmpty);
      expect(plan.fslSets.map((set) => set.setNumber).toList(), [4, 5, 6, 7, 8]);
    });

    test('FSL tracks the first set of whichever week is being run', () {
      final week2 = buildSessionPlan(
        trainingMax: 100,
        weekPercentages: [70, 80, 90],
        mainReps: [3, 3, 3],
        includeWarmups: false,
        includeFsl: true,
      );
      final week3 = buildSessionPlan(
        trainingMax: 100,
        weekPercentages: [75, 85, 95],
        mainReps: [5, 3, 1],
        includeWarmups: false,
        includeFsl: true,
      );

      expect(week2.fslSets.first.weight, 70.0);
      expect(week3.fslSets.first.weight, 75.0);
      expect(week3.fslSets.first.percentage, 75.0);
    });

    test('working set reps follow the week scheme', () {
      final plan = buildSessionPlan(
        trainingMax: 100,
        weekPercentages: [75, 85, 95],
        mainReps: [5, 3, 1],
        includeWarmups: false,
        includeFsl: false,
      );

      expect(plan.mainSets.map((set) => set.reps).toList(), [5, 3, 1]);
    });

    test('a zero training max leaves the generated groups out', () {
      final plan = buildSessionPlan(
        trainingMax: 0,
        weekPercentages: [65, 75, 85],
        mainReps: [5, 5, 5],
        includeWarmups: true,
        includeFsl: true,
      );

      expect(plan.warmupSets, isEmpty);
      expect(plan.fslSets, isEmpty);
      expect(plan.all.length, 3);
    });

    test('the deload week does not stack the ladder on the 40/50/60 sets', () {
      final plan = buildSessionPlan(
        trainingMax: 100,
        weekPercentages: [40, 50, 60],
        mainReps: [5, 5, 5],
        includeWarmups: true,
        includeFsl: false,
      );

      // Decided 6 Nov: the ladder is suppressed on the deload week, so the
      // session is the three working sets only.
      expect(plan.warmupSets, isEmpty);
      expect(plan.all.map((set) => set.percentage).toList(),
          [40.0, 50.0, 60.0]);
    });
  });

  group('percentage label', () {
    test('a whole percentage loses the decimal', () {
      expect(formatPercentageLabel(85), '85%');
      expect(formatPercentageLabel(40), '40%');
    });

    test('a fractional percentage keeps one decimal', () {
      expect(formatPercentageLabel(72.5), '72.5%');
      expect(formatPercentageLabel(67.5), '67.5%');
    });

    test('reads next to the weight it belongs to', () {
      final plan = buildSessionPlan(
        trainingMax: 90,
        weekPercentages: [65, 75, 85],
        mainReps: [5, 5, 5],
        includeWarmups: true,
        includeFsl: true,
      );

      final last = plan.mainSets.last;
      expect(last.weight, 77.0); // 90 x 85% rounded up
      expect(formatPercentageLabel(last.percentage), '85%');

      final lastWarmup = plan.warmupSets.last;
      expect(lastWarmup.weight, 54.0); // 90 x 60%
      expect(formatPercentageLabel(lastWarmup.percentage), '60%');
    });
  });

  group('deload week', () {
    test('the ladder is suppressed so 40/50/60 is not shown twice', () {
      final plan = buildSessionPlan(
        trainingMax: 90,
        weekPercentages: [40, 50, 60],
        mainReps: [5, 5, 5],
        includeWarmups: true,
        includeFsl: false,
      );

      expect(plan.warmupSets, isEmpty);
      expect(plan.all.length, 3);
      expect(plan.all.map((set) => set.setNumber).toList(), [1, 2, 3]);
      expect(plan.all.map((set) => set.percentage).toList(), [40.0, 50.0, 60.0]);
    });

    test('detection keys off the lightest working week only', () {
      expect(isDeloadWeek([40, 50, 60]), isTrue);
      expect(isDeloadWeek([65, 75, 85]), isFalse);
      expect(isDeloadWeek([]), isFalse);
    });

    test('FSL still applies on the deload week when switched on', () {
      final plan = buildSessionPlan(
        trainingMax: 90,
        weekPercentages: [40, 50, 60],
        mainReps: [5, 5, 5],
        includeWarmups: true,
        includeFsl: true,
      );

      expect(plan.warmupSets, isEmpty);
      expect(plan.fslSets.length, 5);
      expect(plan.fslSets.first.setNumber, 4);
      expect(plan.fslSets.first.weight, 36.0); // 90 x 40%
    });
  });

  group('rounding step', () {
    test('the default step is still the whole unit', () {
      expect(weightForPercentage(90, 85), 77.0);
      expect(weightForPercentage(90, 85, step: 1), 77.0);
    });

    test('a half-kilo step rounds up to the next half', () {
      // 90 x 85% is 76.5 exactly, which is already on a half.
      expect(weightForPercentage(90, 85, step: 0.5), 76.5);
      // 95 x 65% is 61.75, the next half above it is 62.0.
      expect(weightForPercentage(95, 65, step: 0.5), 62.0);
      // 105.5 x 62.5% is 65.9375, the next half above it is 66.0.
      expect(weightForPercentage(105.5, 62.5, step: 0.5), 66.0);
    });

    test('a step above one rounds up to its own multiple', () {
      // 105.5 x 62.5% is 65.9375, the next 2.5 is 67.5.
      expect(weightForPercentage(105.5, 62.5, step: 2.5), 67.5);
      expect(weightForPercentage(100, 65, step: 2.5), 65.0);
    });

    test('never rounds down, whatever the step', () {
      // 52.5 x 65% is 34.125, the next half above it is 34.5.
      expect(weightForPercentage(52.5, 65, step: 0.5), 34.5);
      expect(weightForPercentage(52.5, 65, step: 5), 35.0);
    });

    test('a zero, negative or non-finite step falls back to one', () {
      // A zero step would divide by zero, so it behaves exactly like the
      // default rather than throwing or hanging.
      expect(weightForPercentage(90, 85, step: 0), 77.0);
      expect(weightForPercentage(90, 85, step: -0.5), 77.0);
      expect(weightForPercentage(90, 85, step: double.nan), 77.0);
      expect(weightForPercentage(90, 85, step: double.infinity), 77.0);
      expect(weightForPercentage(90, 85, step: double.negativeInfinity), 77.0);
    });

    test('the ladder rounds to the same step as the working sets', () {
      expect(buildWarmupSets(95, step: 0.5).map((set) => set.weight).toList(),
          [38.0, 47.5, 57.0]); // 47.5 used to round up to 48
      expect(buildWarmupSets(95).map((set) => set.weight).toList(),
          [38.0, 48.0, 57.0]);
    });

    test('FSL copies the first working set at the same step', () {
      expect(buildFslSets(95, 65, step: 0.5).first.weight, 62.0);
      expect(buildFslSets(105.5, 62.5, step: 2.5).first.weight, 67.5);
    });

    test('the whole plan shares one step', () {
      final plan = buildSessionPlan(
        trainingMax: 102.5,
        weekPercentages: [65, 75, 85],
        mainReps: [5, 5, 5],
        includeWarmups: true,
        includeFsl: true,
        roundingStep: 2.5,
      );

      expect(plan.all.map((set) => set.weight).toList(), [
        42.5, 52.5, 62.5, // warmups: 41, 51.25, 61.5 rounded up to 2.5s
        67.5, 77.5, 87.5, // working sets: 66.625, 76.875, 87.125
        67.5, 67.5, 67.5, 67.5, 67.5, // FSL copies the first working set
      ]);
    });

    test('the half step plan keeps the same percentages on the labels', () {
      final plan = buildSessionPlan(
        trainingMax: 90,
        weekPercentages: [65, 75, 85],
        mainReps: [5, 5, 5],
        includeWarmups: false,
        includeFsl: false,
        roundingStep: 0.5,
      );

      expect(plan.all.map((set) => set.weight).toList(), [58.5, 67.5, 76.5]);
      expect(plan.all.map((set) => set.percentage).toList(), [65.0, 75.0, 85.0]);
      expect(formatPercentageLabel(plan.all.last.percentage), '85%');
    });
  });
}
