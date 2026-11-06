import 'package:flutter_test/flutter_test.dart';
import 'package:fivethreeone_log/app/utils/training_defaults.dart';

void main() {
  group('rounding step', () {
    test('an unusable step becomes whole kilos and a missing one the default', () {
      // Absent is the untouched default, not the fallback.
      expect(sanitiseRoundingStep(null), 0.5);
      expect(sanitiseRoundingStep(0), 1.0);
      expect(sanitiseRoundingStep(-0.5), 1.0);
      expect(sanitiseRoundingStep(double.nan), 1.0);
      expect(sanitiseRoundingStep(double.infinity), 1.0);
      expect(sanitiseRoundingStep(double.negativeInfinity), 1.0);
    });

    test('a usable step is left alone', () {
      expect(sanitiseRoundingStep(0.5), 0.5);
      expect(sanitiseRoundingStep(2.5), 2.5);
      expect(sanitiseRoundingStep(5), 5.0);
    });

    test('the label drops the decimal on a whole step only', () {
      expect(formatRoundingStep(1), '1');
      expect(formatRoundingStep(2.5), '2.5');
      expect(formatRoundingStep(0.5), '0.5');
    });
  });

  group('training max percentage', () {
    test('a missing or out of range percentage becomes 85', () {
      expect(sanitiseTmPercent(null), 85.0);
      expect(sanitiseTmPercent(0), 85.0);
      expect(sanitiseTmPercent(49), 85.0);
      expect(sanitiseTmPercent(101), 85.0);
      expect(sanitiseTmPercent(-85), 85.0);
      expect(sanitiseTmPercent(double.nan), 85.0);
      expect(sanitiseTmPercent(double.infinity), 85.0);
    });

    test('the ends of the range are allowed', () {
      expect(sanitiseTmPercent(50), 50.0);
      expect(sanitiseTmPercent(85), 85.0);
      expect(sanitiseTmPercent(100), 100.0);
    });

    test('the training max is the percentage of the 1RM, unrounded', () {
      expect(deriveTrainingMax(120, 85), 102.0);
      expect(deriveTrainingMax(120, 90), 108.0);
      expect(deriveTrainingMax(125, 86), 107.5);
      expect(deriveTrainingMax(100, 100), 100.0);
    });

    test('a bad percentage in the map is refused, not multiplied in', () {
      expect(deriveTrainingMax(100, 0), 85.0);
      expect(deriveTrainingMax(100, 140), 85.0);
    });

    test('one rep of an entry is the 1RM itself', () {
      // Epley would turn 120 x 1 into 124, so a reopen of the form would
      // inflate the number every time. One rep is taken at face value.
      expect(oneRMFromEntry(120, 1), 120.0);
      // Anything else still goes through the Epley formula in utils.
      expect(oneRMFromEntry(100, 5), 117.0); // 100 x 5 x 0.0333 + 100 = 116.65
      expect(oneRMFromEntry(100, 0), 100.0);
    });

    test('the percentage label drops the decimal on a whole percentage', () {
      expect(formatTmPercent(85), '85');
      expect(formatTmPercent(87.5), '87.5');
    });
  });

  group('training max recalculation', () {
    test('an untouched training max follows a percentage change', () {
      final plan = planTrainingMaxRecalculation(
        rmData: {'Supino': 120},
        tmData: {'Supino': 102.0}, // 120 x 85%
        oldPercent: 85,
        newPercent: 90,
      );

      expect(plan.updated, {'Supino': 108.0});
      expect(plan.kept, isEmpty);
    });

    test('a training max advanced by a cycle is kept, not overwritten', () {
      final plan = planTrainingMaxRecalculation(
        rmData: {'Supino': 120},
        tmData: {'Supino': 112.0}, // 102 plus two 5 kilo cycles
        oldPercent: 85,
        newPercent: 90,
      );

      expect(plan.updated, isEmpty);
      expect(plan.kept, ['Supino']);
    });

    test('a training max below the derivation is kept too', () {
      // Someone who lowered the max by hand also owns that number.
      final plan = planTrainingMaxRecalculation(
        rmData: {'Supino': 120},
        tmData: {'Supino': 95.0},
        oldPercent: 85,
        newPercent: 90,
      );

      expect(plan.updated, isEmpty);
      expect(plan.kept, ['Supino']);
    });

    test('the tolerance absorbs rounding, and stops short of a cycle', () {
      final within = planTrainingMaxRecalculation(
        rmData: {'Supino': 120},
        tmData: {'Supino': 102.04},
        oldPercent: 85,
        newPercent: 90,
      );
      final outside = planTrainingMaxRecalculation(
        rmData: {'Supino': 120},
        tmData: {'Supino': 102.06},
        oldPercent: 85,
        newPercent: 90,
      );

      expect(within.updated, {'Supino': 108.0});
      expect(outside.kept, ['Supino']);
    });

    test('a lift with no stored training max gains one', () {
      final plan = planTrainingMaxRecalculation(
        rmData: {'Supino': 120},
        tmData: {},
        oldPercent: 85,
        newPercent: 90,
      );

      expect(plan.updated, {'Supino': 108.0});
      expect(plan.kept, isEmpty);
    });

    test('a lift with no 1RM is left out entirely', () {
      final plan = planTrainingMaxRecalculation(
        rmData: {'Supino': 0, 'Agachamento': 150},
        tmData: {'Supino': 90.0},
        oldPercent: 90,
        newPercent: 90,
      );

      expect(plan.updated, {'Agachamento': 135.0});
      expect(plan.kept, isEmpty);
    });

    test('force rewrites an advanced training max', () {
      final plan = planTrainingMaxRecalculation(
        rmData: {'Supino': 120},
        tmData: {'Supino': 112.0},
        oldPercent: 85,
        newPercent: 90,
        force: true,
      );

      expect(plan.updated, {'Supino': 108.0});
      expect(plan.kept, isEmpty);
    });

    test('only the named lifts are considered', () {
      final plan = planTrainingMaxRecalculation(
        rmData: {'Supino': 120, 'Agachamento': 150},
        tmData: {},
        oldPercent: 85,
        newPercent: 85,
        exercises: ['Agachamento'],
      );

      expect(plan.updated.keys, ['Agachamento']);
      expect(plan.updated['Agachamento'], 127.5); // 150 x 85%
    });
  });

  group('cycle increment', () {
    test('the four main lifts carry the standard increments', () {
      const Map<String, double> stored = {};

      expect(cycleIncrementFor('Supino', stored), 5.0);
      expect(cycleIncrementFor('Press militar', stored), 5.0);
      expect(cycleIncrementFor('Agachamento', stored), 10.0);
      expect(cycleIncrementFor('Levantamento terra', stored), 10.0);
    });

    test('a stored increment wins over the default', () {
      expect(cycleIncrementFor('Supino', {'Supino': 2.5}), 2.5);
      expect(cycleIncrementFor('Agachamento', {'Agachamento': 12.5}), 12.5);
    });

    test('a lift in neither place gets the smallest standard increment', () {
      expect(cycleIncrementFor('Remada curvada', {}), 5.0);
      expect(cycleIncrementFor('Remada curvada', {'Supino': 2.5}), 5.0);
    });

    test('a zero, negative or non-finite stored increment is refused', () {
      // A cycle that adds nothing, or takes weight off, is not a cycle.
      expect(cycleIncrementFor('Supino', {'Supino': 0}), 5.0);
      expect(cycleIncrementFor('Supino', {'Supino': -2.5}), 5.0);
      expect(cycleIncrementFor('Agachamento', {'Agachamento': double.nan}), 10.0);
      expect(
          cycleIncrementFor('Agachamento', {'Agachamento': double.infinity}),
          10.0);
    });

    test('the defaults cover exactly the four main lifts', () {
      expect(defaultCycleIncrement.keys.toList(),
          ['Supino', 'Press militar', 'Agachamento', 'Levantamento terra']);
    });
  });

  group('re-entering a max', () {
    test('one rep is the 1RM itself and goes straight through the percentage',
        () {
      final recalculated = recalculateMax(weight: 120, reps: 1, tmPercent: 85)!;
      expect(recalculated.oneRM, 120.0);
      // 120 at 85% is 102, not the 108 a 90% training max had reached.
      expect(recalculated.trainingMax, 102.0);
    });

    test('several reps go through Epley, then the percentage', () {
      // 100 x 5 rounds up to 117 on the way out of calculate1RM.
      final recalculated = recalculateMax(weight: 100, reps: 5, tmPercent: 90)!;
      expect(recalculated.oneRM, 117.0);
      // 117 at 90% is 105.3, and the training max itself is never rounded.
      expect(recalculated.trainingMax, closeTo(105.3, 1e-9));
    });

    test('a blank or unusable weight gives nothing back', () {
      // Null is what stops a recalculation writing a zero over a real max.
      expect(recalculateMax(weight: 0, reps: 5, tmPercent: 85), isNull);
      expect(recalculateMax(weight: -20, reps: 5, tmPercent: 85), isNull);
      expect(recalculateMax(weight: double.nan, reps: 5, tmPercent: 85), isNull);
      expect(recalculateMax(weight: double.infinity, reps: 5, tmPercent: 85),
          isNull);
    });

    test('saving the entry screen keeps a cycle and week in progress', () {
      final kept = cycleWeekPreserving(
        {
          'Supino': {'cycle': 3, 'week': 2},
        },
        ['Supino', 'Agachamento'],
      );

      expect(kept['Supino'], {'cycle': 3, 'week': 2});
      // A lift that has never been trained starts at cycle one, week one.
      expect(kept['Agachamento'], {'cycle': 1, 'week': 1});
    });

    test('a lift with no stored place in the block is not given someone else',
        () {
      final kept = cycleWeekPreserving({}, ['Supino']);
      expect(kept, {
        'Supino': {'cycle': 1, 'week': 1},
      });
    });
  });
}
