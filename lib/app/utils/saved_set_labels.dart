import 'package:flutter/foundation.dart';

import '../interactor/models/set_model.dart';
import 'session_plan.dart';
import 'utils.dart';

/// Which part of the session one saved set belongs to.
enum SavedSetGroup { warmup, working, fsl, unknown }

/// One label per saved set of a workout, in lifting order, plus whether those
/// labels were read from a session plan at all.
///
/// A workout saved by an older build, or one saved while the warmup ladder or
/// FSL was switched the other way, can have a set count that no shape the
/// current plan produces. That is not an error: [matched] is false, every set
/// is [SavedSetGroup.unknown] and the page numbers the sets instead. Every set
/// is still editable; nothing is hidden for not fitting a pattern.
@immutable
class SavedSetLabels {
  final List<SavedSetGroup> groups;

  /// True when [groups] came from a plan shape, so a group name is a real
  /// claim about the set. False means the sets are only numbered.
  final bool matched;

  const SavedSetLabels({required this.groups, required this.matched});

  /// Plain numbering: one [SavedSetGroup.unknown] per set.
  SavedSetLabels.plain(int count)
      : groups = List<SavedSetGroup>.filled(count, SavedSetGroup.unknown),
        matched = false;

  int get length => groups.length;

  bool get isEmpty => groups.isEmpty;

  SavedSetGroup groupAt(int index) => groups[index];

  /// Index of the last set that sits in the working group, or null when no set
  /// is known to be a working set.
  int? get lastWorkingIndex {
    for (int i = groups.length - 1; i >= 0; i--) {
      if (groups[i] == SavedSetGroup.working) {
        return i;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedSetLabels &&
          runtimeType == other.runtimeType &&
          matched == other.matched &&
          listEquals(groups, other.groups);

  @override
  int get hashCode => matched.hashCode ^ Object.hashAll(groups);
}

/// Reads the groups a saved set list is in.
///
/// The saved workout carries no per set group, only the sets in the order they
/// were lifted, so the groups are recovered positionally: warmups first, then
/// the working sets, then FSL, which is the order [SessionPlan.all] uses.
/// [plan] is the session for the workout's own week, not the week the lifter is
/// in now.
///
/// The shapes tried, in order, are the plan as configured, then the same plan
/// without FSL, then without the ladder, then the working sets alone. The first
/// one whose length equals [savedCount] wins. Count and order only: weights are
/// not compared, because a lifter who loaded something else would otherwise
/// lose their labels.
///
/// Returns [SavedSetLabels.plain] when no shape fits, which is what makes a
/// legacy workout fully editable rather than hidden.
SavedSetLabels labelSavedSets({
  required int savedCount,
  required SessionPlan plan,
}) {
  if (savedCount <= 0) {
    return SavedSetLabels.plain(0);
  }

  for (final List<SavedSetGroup> shape in _candidateShapes(plan)) {
    if (shape.length == savedCount) {
      return SavedSetLabels(groups: shape, matched: true);
    }
  }
  return SavedSetLabels.plain(savedCount);
}

/// Volume of the sets that are kept, in the selected unit.
double totalVolumeOfSets(List<SetModel> sets) {
  return sets.fold(0.0, (sum, set) => sum + set.weight * set.reps);
}

/// The last set of the working group, or null when the labels hold no working
/// set. Never the last set of the workout: a warmup or an FSL set at the end of
/// a session is lighter and would deflate the estimate.
SetModel? lastWorkingSet(List<SetModel> sets, SavedSetLabels labels) {
  final int? index = labels.lastWorkingIndex;
  if (index == null || index < 0 || index >= sets.length) {
    return null;
  }
  return sets[index];
}

/// The 1RM estimate a save should store.
///
/// It comes from the last working set, never from the last set overall. Three
/// outcomes:
///  * a working set exists, so its weight and reps give the estimate;
///  * the shape matched a plan but holds no working set, so the estimate is 0
///    rather than a number read off a warmup;
///  * the shape matched nothing, so nothing here can be shown to be a working
///    set and [storedOneRM] is left as it was instead of being replaced by an
///    invented figure.
double recalculatedOneRM(
  List<SetModel> sets,
  SavedSetLabels labels, {
  required double storedOneRM,
}) {
  final SetModel? lastWorking = lastWorkingSet(sets, labels);
  if (lastWorking != null) {
    return calculate1RM(lastWorking.weight, lastWorking.reps);
  }
  if (labels.matched) {
    return 0.0;
  }
  return storedOneRM;
}

/// The plan shapes a saved workout could have, longest first, without
/// duplicates and never without a working group: a session with no working
/// sets is not a session this app writes.
List<List<SavedSetGroup>> _candidateShapes(SessionPlan plan) {
  final List<SavedSetGroup> warmups =
      List<SavedSetGroup>.filled(plan.warmupSets.length, SavedSetGroup.warmup);
  final List<SavedSetGroup> working =
      List<SavedSetGroup>.filled(plan.mainSets.length, SavedSetGroup.working);
  final List<SavedSetGroup> fsl =
      List<SavedSetGroup>.filled(plan.fslSets.length, SavedSetGroup.fsl);

  final List<List<SavedSetGroup>> shapes = [
    [...warmups, ...working, ...fsl],
    [...warmups, ...working],
    [...working, ...fsl],
    [...working],
  ];

  final List<List<SavedSetGroup>> unique = [];
  for (final shape in shapes) {
    if (!shape.contains(SavedSetGroup.working)) {
      continue;
    }
    if (unique.any((kept) => listEquals(kept, shape))) {
      continue;
    }
    unique.add(shape);
  }
  return unique;
}
