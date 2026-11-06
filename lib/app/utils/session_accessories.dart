import '../interactor/models/workout_model.dart';

/// The accessory rows that belong to the same session as [workout], in a stable
/// order.
///
/// Accessory work is not part of a main lift's `sets`: the session screen
/// writes one `WorkoutModel` per accessory exercise, with `isAccessory` true,
/// oneRM and volume zero, and the same cycle and week as the lift it followed
/// (see `_saveAccessoryData` in workout_page.dart). The model carries no
/// session id, so the links available are the calendar day plus that cycle and
/// week, and that is the rule used here.
///
/// Editing an accessory row itself returns nothing, so the page does not show
/// the same row twice.
List<WorkoutModel> accessoryWorkoutsForSession(
  WorkoutModel workout,
  List<WorkoutModel> allWorkouts,
) {
  if (workout.isAccessory) {
    return const <WorkoutModel>[];
  }
  final matching = allWorkouts
      .where((candidate) =>
          candidate.isAccessory &&
          candidate.id != workout.id &&
          _sameDay(candidate.date, workout.date) &&
          candidate.cycle == workout.cycle &&
          candidate.week == workout.week)
      .toList();
  matching.sort((a, b) {
    final int byName = a.exerciseName.compareTo(b.exerciseName);
    if (byName != 0) {
      return byName;
    }
    return a.date.compareTo(b.date);
  });
  return matching;
}

/// Calendar day comparison. DateUtils lives in material.dart, and this file
/// stays free of the widget layer.
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
