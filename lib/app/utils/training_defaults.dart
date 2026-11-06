import 'package:flutter/foundation.dart';

import 'utils.dart';

/// The numbers behind every calculated weight live here, in one place, so a
/// stored preference and a missing preference can never tell different
/// stories.

/// The smallest weight jump the app rounds to when nothing else is stored.
/// One kilo keeps the old whole-unit behaviour, so a preferences map written
/// before the step existed behaves exactly as it did.
const double defaultRoundingStep = 1.0;

/// Rounds a stored rounding step to something usable. A step of zero would
/// divide by zero and a negative step would round the wrong way, so anything
/// that is not a positive, finite number falls back to [defaultRoundingStep].
double sanitiseRoundingStep(double? step) {
  if (step == null || step.isNaN || !step.isFinite || step <= 0) {
    return defaultRoundingStep;
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
/// would inflate the figure every time the entry form is reopened.
double oneRMFromEntry(double weight, int reps) {
  if (reps == 1) {
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
