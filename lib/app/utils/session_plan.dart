import 'package:flutter/foundation.dart';

import 'training_defaults.dart';

/// One set the session window shows and logs: a weight derived from the
/// training max, plus the percentage of the training max it came from.
///
/// The percentage travels with the weight so a row can say where the number
/// came from without re-deriving it. That also keeps the label honest for a
/// weight the lifter edits by hand: it still reads as the percentage the set
/// was programmed at, not as a re-approximation from a rounded weight.
@immutable
class PlannedSet {
  final int setNumber;
  final int reps;
  final double weight;
  final double percentage;

  const PlannedSet({
    required this.setNumber,
    required this.reps,
    required this.weight,
    required this.percentage,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedSet &&
          runtimeType == other.runtimeType &&
          setNumber == other.setNumber &&
          reps == other.reps &&
          weight == other.weight &&
          percentage == other.percentage;

  @override
  int get hashCode =>
      setNumber.hashCode ^ reps.hashCode ^ weight.hashCode ^ percentage.hashCode;
}

/// The warmup ladder, as percentages of the training max, in the order they
/// are lifted.
const List<double> warmupPercentages = [40.0, 50.0, 60.0];

/// Reps for each rung of the ladder, same order as [warmupPercentages].
const List<int> warmupReps = [5, 5, 3];

/// FSL (first set last) is five sets of five at the first working set's weight.
const int fslSetCount = 5;
const int fslReps = 5;

/// Rounds a percentage of [trainingMax] up to the next multiple of [step],
/// never down. Every calculated weight in the app goes through this shape, so
/// the tables, the warmups and the FSL sets can never disagree by a kilo.
///
/// [step] is the user's rounding step, in the selected unit. The default of
/// one keeps the original whole-unit behaviour, and a step that is not a
/// positive finite number is refused here as well so a bad preference can
/// never divide by zero.
double weightForPercentage(double trainingMax, double percentage,
    {double step = 1}) {
  final double safeStep = sanitiseRoundingStep(step);
  return (trainingMax * percentage / 100 / safeStep).ceil() * safeStep;
}

/// The warmup ladder: 40% x 5, 50% x 5, 60% x 3 of [trainingMax].
List<PlannedSet> buildWarmupSets(
  double trainingMax, {
  int startSetNumber = 1,
  double step = 1,
}) {
  final List<PlannedSet> sets = [];
  for (int i = 0; i < warmupPercentages.length; i++) {
    final double percentage = warmupPercentages[i];
    sets.add(PlannedSet(
      setNumber: startSetNumber + i,
      reps: warmupReps[i],
      weight: weightForPercentage(trainingMax, percentage, step: step),
      percentage: percentage,
    ));
  }
  return sets;
}

/// The working sets of the day, one per entry of [weekPercentages] (the stored
/// percentage table for the week), with reps taken from [mainReps].
List<PlannedSet> buildMainSets(
  double trainingMax,
  List<double> weekPercentages,
  List<int> mainReps, {
  int startSetNumber = 1,
  double step = 1,
}) {
  final List<PlannedSet> sets = [];
  for (int i = 0; i < weekPercentages.length; i++) {
    final double percentage = weekPercentages[i];
    sets.add(PlannedSet(
      setNumber: startSetNumber + i,
      // Weeks without a scheme of their own run 5s; the stored tables
      // always carry three reps, this only guards a short list.
      reps: i < mainReps.length ? mainReps[i] : 5,
      weight: weightForPercentage(trainingMax, percentage, step: step),
      percentage: percentage,
    ));
  }
  return sets;
}

/// FSL: [fslSetCount] sets of [fslReps] reps at the weight of the first working
/// set of the day. The weight is calculated from [firstSetPercentage], never
/// taken from a field the lifter filled in.
List<PlannedSet> buildFslSets(
  double trainingMax,
  double firstSetPercentage, {
  int startSetNumber = 1,
  double step = 1,
}) {
  final double weight =
      weightForPercentage(trainingMax, firstSetPercentage, step: step);
  return [
    for (int i = 0; i < fslSetCount; i++)
      PlannedSet(
        setNumber: startSetNumber + i,
        reps: fslReps,
        weight: weight,
        percentage: firstSetPercentage,
      ),
  ];
}

/// The whole main-lift session: warmups, working sets, then FSL. Set numbers
/// run straight through the session, so what is shown, ticked and logged
/// matches the order it is performed in.
@immutable
class SessionPlan {
  final List<PlannedSet> warmupSets;
  final List<PlannedSet> mainSets;
  final List<PlannedSet> fslSets;

  const SessionPlan({
    this.warmupSets = const [],
    this.mainSets = const [],
    this.fslSets = const [],
  });

  /// Every set of the session, in lifting order.
  List<PlannedSet> get all => [...warmupSets, ...mainSets, ...fslSets];

  int get length => warmupSets.length + mainSets.length + fslSets.length;

  bool get isEmpty => length == 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionPlan &&
          runtimeType == other.runtimeType &&
          listEquals(warmupSets, other.warmupSets) &&
          listEquals(mainSets, other.mainSets) &&
          listEquals(fslSets, other.fslSets);

  @override
  int get hashCode => Object.hash(Object.hashAll(warmupSets),
      Object.hashAll(mainSets), Object.hashAll(fslSets));
}

/// Builds the session for the day.
///
/// [weekPercentages] is the stored percentage table for the week, in order, so
/// the first entry is the first working set and the one FSL copies.
/// [mainReps] is the rep scheme for the week.
///
/// With a training max of zero every derived weight would be zero, so the
/// generated groups are left out rather than shown as a row of zeroes.
/// True when the week's first working set is at or below the top of the
/// warmup ladder (week 4, the deload), in which case the ladder is skipped.
bool isDeloadWeek(List<double> weekPercentages) =>
    weekPercentages.isNotEmpty && weekPercentages.first <= warmupPercentages.last;

SessionPlan buildSessionPlan({
  required double trainingMax,
  required List<double> weekPercentages,
  required List<int> mainReps,
  bool includeWarmups = true,
  bool includeFsl = false,
  double roundingStep = 1,
}) {
  final bool hasTrainingMax = trainingMax > 0;

  // Deload week already works at the same light percentages as the ladder, so
  // showing both would put 40, 50 and 60 on screen twice in one session.
  final bool deload = isDeloadWeek(weekPercentages);

  final List<PlannedSet> warmupSets = includeWarmups && hasTrainingMax && !deload
      ? buildWarmupSets(trainingMax, step: roundingStep)
      : const <PlannedSet>[];

  final List<PlannedSet> mainSets = buildMainSets(
    trainingMax,
    weekPercentages,
    mainReps,
    startSetNumber: warmupSets.length + 1,
    step: roundingStep,
  );

  final List<PlannedSet> fslSets =
      includeFsl && hasTrainingMax && weekPercentages.isNotEmpty
          ? buildFslSets(
              trainingMax,
              weekPercentages.first,
              startSetNumber: warmupSets.length + mainSets.length + 1,
              step: roundingStep,
            )
          : const <PlannedSet>[];

  return SessionPlan(
    warmupSets: warmupSets,
    mainSets: mainSets,
    fslSets: fslSets,
  );
}

/// The small muted label that sits under a calculated weight: "85%" for a whole
/// percentage, "72.5%" when the percentage table holds a fraction.
String formatPercentageLabel(double percentage) {
  final String text = percentage == percentage.roundToDouble()
      ? percentage.toStringAsFixed(0)
      : percentage.toStringAsFixed(1);
  return '$text%';
}
