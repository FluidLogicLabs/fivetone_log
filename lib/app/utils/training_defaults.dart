import 'package:flutter/foundation.dart';

import 'utils.dart';

/// The numbers behind every calculated weight live here, in one place, so a
/// stored preference and a missing preference can never tell different
/// stories.

/// The smallest weight jump the app rounds to when nothing is stored, which is
/// every install that has never touched the setting: half a kilo, so a 2.5 kg
/// plate pair can actually be loaded.
const double defaultRoundingStep = 0.5;

/// The step used when a stored value exists but cannot be read as a step. Zero
/// would divide by zero and a negative step would round the wrong way, so the
/// unusable value is replaced by whole kilos rather than by the default, since
/// a whole kilo is the coarser, safer reading and never asks for a plate that
/// is not on the bar.
const double fallbackRoundingStep = 1.0;

/// Rounds a stored rounding step to something usable. Absent means the setting
/// has never been touched, so it gets [defaultRoundingStep]. Present and
/// unusable gets [fallbackRoundingStep]. The two are deliberately different so
/// a corrupt value cannot masquerade as a default.
double sanitiseRoundingStep(double? step) {
  if (step == null) {
    return defaultRoundingStep;
  }
  if (step.isNaN || !step.isFinite || step <= 0) {
    return fallbackRoundingStep;
  }
  return step;
}

/// The step written into a label: whole steps lose their decimal, halves keep
/// it, so "0.5" reads as 0.5 and not 0.5000000001.
String formatRoundingStep(double step) {
  final double safeStep = sanitiseRoundingStep(step);
  final double trimmed = double.parse(safeStep.toStringAsFixed(3));
  return trimmed == trimmed.roundToDouble()
      ? trimmed.toStringAsFixed(0)
      : trimmed.toString();
}

/// The training max is a percentage of the 1RM. Stored as a whole percentage
/// (85 means 85%), never as a fraction, so what is in preferences is what the
/// user typed.
const double defaultTmPercent = 85.0;

/// The range the training max percentage is allowed to sit in. Below 50 the
/// training max stops being a training max, above 100 it stops being a
/// percentage of the 1RM at all.
const double minTmPercent = 50.0;
const double maxTmPercent = 100.0;

/// Guards a stored training max percentage. Anything that is not a finite
/// number inside [minTmPercent] to [maxTmPercent] falls back to
/// [defaultTmPercent].
double sanitiseTmPercent(double? percent) {
  if (percent == null || percent.isNaN || !percent.isFinite) {
    return defaultTmPercent;
  }
  if (percent < minTmPercent || percent > maxTmPercent) {
    return defaultTmPercent;
  }
  return percent;
}

/// The training max for [oneRM] at [tmPercent]. Deliberately not rounded: the
/// rounding step belongs to the weights derived from the training max, and
/// rounding the max itself would shift every set of every session.
double deriveTrainingMax(double oneRM, double tmPercent) {
  return oneRM * sanitiseTmPercent(tmPercent) / 100;
}

/// The training max percentage written into a field or a label: 85 stays "85",
/// a half percentage keeps one decimal.
String formatTmPercent(double percent) {
  final double safePercent = sanitiseTmPercent(percent);
  return safePercent == safePercent.roundToDouble()
      ? safePercent.toStringAsFixed(0)
      : safePercent.toStringAsFixed(1);
}

/// The 1RM behind one entry of weight and reps. One rep is the weight itself:
/// running a single rep through Epley adds 3.33% that nobody lifted, and it
/// would inflate the figure every time the entry form is reopened. No reps at
/// all is read the same way, because a weight with no reps is a typed number
/// the user meant as a max, not a claim about a set.
double oneRMFromEntry(double weight, int reps) {
  if (reps <= 1) {
    return weight;
  }
  return calculate1RM(weight, reps);
}

/// How close a stored training max has to be to the percentage it was derived
/// from before it counts as untouched. A twentieth of a unit is well inside
/// any rounding and well outside the smallest cycle increment.
const double tmMatchTolerance = 0.05;

/// What a training max percentage change did to the stored training maxes.
@immutable
class TrainingMaxRecalculation {
  /// Lift to the new training max, for the lifts that were derived again.
  final Map<String, double> updated;

  /// Lifts left alone because their stored training max no longer matches the
  /// old percentage, which means a cycle has already moved it.
  final List<String> kept;

  const TrainingMaxRecalculation({
    this.updated = const {},
    this.kept = const [],
  });

  bool get isEmpty => updated.isEmpty && kept.isEmpty;
}

/// Works out the training maxes a percentage change would rewrite, without
/// touching anything.
///
/// A lift is only rewritten when its stored training max still equals what the
/// old percentage derives from the stored 1RM, within [tmMatchTolerance]. That
/// is the whole safety rule: a training max that has been advanced through
/// cycles does not match, so it is reported in [kept] and left where it is.
/// [force] is for the explicit, on-screen recalculation, where the user has
/// asked for the derived number regardless.
TrainingMaxRecalculation planTrainingMaxRecalculation({
  required Map<String, double> rmData,
  required Map<String, double> tmData,
  required double oldPercent,
  required double newPercent,
  Iterable<String>? exercises,
  bool force = false,
}) {
  final double safeOld = sanitiseTmPercent(oldPercent);
  final double safeNew = sanitiseTmPercent(newPercent);
  final Map<String, double> updated = <String, double>{};
  final List<String> kept = <String>[];

  for (final String exercise in exercises ?? rmData.keys) {
    final double? oneRM = rmData[exercise];
    if (oneRM == null || oneRM.isNaN || !oneRM.isFinite || oneRM <= 0) {
      // Nothing to derive from, so nothing to write.
      continue;
    }

    final double derived = deriveTrainingMax(oneRM, safeNew);
    final double? stored = tmData[exercise];
    final double previousDerived = deriveTrainingMax(oneRM, safeOld);
    final bool untouched = stored == null ||
        (stored - previousDerived).abs() <= tmMatchTolerance;

    if (force || untouched) {
      updated[exercise] = derived;
    } else {
      kept.add(exercise);
    }
  }

  return TrainingMaxRecalculation(updated: updated, kept: kept);
}

/// How much the training max goes up when a cycle completes, per lift. The
/// lower body lifts move twice as fast as the upper body ones, which is the
/// 5/3/1 convention and what the app hardcoded before this was a preference.
const Map<String, double> defaultCycleIncrement = <String, double>{
  'Supino': 2.5,
  'Press militar': 2.5,
  'Agachamento': 5.0,
  'Levantamento terra': 5.0,
};

/// What a lift that is in neither the stored map nor the defaults gets. The
/// upper body increment is the smallest of the standard ones, so an unknown
/// lift is never handed a jump it did not earn.
const double fallbackCycleIncrement = 2.5;

/// The increment for [exercise]: the stored value first, then the default for
/// that lift, then [fallbackCycleIncrement]. A stored zero or negative is
/// refused, because a cycle that adds nothing or takes weight away is not a
/// cycle.
double cycleIncrementFor(String exercise, Map<String, double> increments) {
  final double? stored = increments[exercise];
  if (stored != null && !stored.isNaN && stored.isFinite && stored > 0) {
    return stored;
  }
  return defaultCycleIncrement[exercise] ?? fallbackCycleIncrement;
}

/// What one typed entry of weight and reps means for the two stored numbers.
class RecalculatedMax {
  final double oneRM;
  final double trainingMax;

  const RecalculatedMax({required this.oneRM, required this.trainingMax});
}

/// Rebuilds the 1RM and the training max from one typed entry, or null when
/// there is no usable weight. Null is what lets a recalculation skip a lift the
/// user left blank instead of writing a zero over a real number.
RecalculatedMax? recalculateMax({
  required double weight,
  required int reps,
  required double tmPercent,
}) {
  if (weight.isNaN || !weight.isFinite || weight <= 0) {
    return null;
  }
  final double oneRM = oneRMFromEntry(weight, reps);
  return RecalculatedMax(
    oneRM: oneRM,
    trainingMax: deriveTrainingMax(oneRM, tmPercent),
  );
}

/// The cycle and week map to store when the entry screen is saved: a lift that
/// already has a place in the block keeps it, and only a lift that has never
/// had one starts at cycle one of week one.
Map<String, Map<String, int>> cycleWeekPreserving(
  Map<String, Map<String, int>> stored,
  Iterable<String> exercises,
) {
  return {
    for (final exercise in exercises)
      exercise: stored[exercise] ?? const {'cycle': 1, 'week': 1},
  };
}
