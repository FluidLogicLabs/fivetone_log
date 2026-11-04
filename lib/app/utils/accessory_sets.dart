import '../interactor/models/set_model.dart';

/// Reads the editable accessory set rows and returns one [SetModel] per row
/// that actually has reps entered.
///
/// A row counts as filled when its reps input parses as an integer greater than
/// or equal to 1. Its set number is the position of the row (index + 1), so a
/// gap in the middle of the rows keeps the set numbering honest.
///
/// A weight of 0 (empty, unparseable or literally zero) means bodyweight.
///
/// Returns null when no row is filled: blank means no row is written at all.
List<SetModel>? parseAccessorySets(
  List<String> repsInputs,
  List<String> weightInputs,
) {
  final List<SetModel> sets = [];

  for (int i = 0; i < repsInputs.length; i++) {
    final int? reps = _parseAccessoryReps(repsInputs[i]);
    if (reps == null) {
      continue;
    }
    final String weightInput = i < weightInputs.length ? weightInputs[i] : '';
    sets.add(SetModel(
      setNumber: i + 1,
      reps: reps,
      weight: _parseAccessoryWeight(weightInput),
    ));
  }

  if (sets.isEmpty) {
    return null;
  }
  return sets;
}

int? _parseAccessoryReps(String input) {
  final int? reps = int.tryParse(input.trim());
  if (reps == null || reps < 1) {
    return null;
  }
  return reps;
}

double _parseAccessoryWeight(String input) {
  // 0.0 is a valid weight: it means bodyweight.
  return double.tryParse(input.trim()) ?? 0.0;
}

/// True when at least one exercise has a filled set row, so an accessory-only
/// session can enable the save button.
///
/// Reuses [parseAccessorySets] so "filled" means exactly the same thing here as
/// it does when the rows are written.
bool anyAccessorySetsFilled(
  Map<String, List<String>> repsInputsByExercise,
  Map<String, List<String>> weightInputsByExercise,
) {
  for (final name in repsInputsByExercise.keys) {
    final sets = parseAccessorySets(
      repsInputsByExercise[name] ?? const <String>[],
      weightInputsByExercise[name] ?? const <String>[],
    );
    if (sets != null) {
      return true;
    }
  }
  return false;
}

/// Formats an accessory weight for display.
///
/// 0 means bodyweight: it is shown as "BW" where there is room for it and as
/// "0 kg" in dense summaries, where "BW" alone would be ambiguous.
String formatAccessoryWeight(double weight, {bool compact = false}) {
  if (weight == 0) {
    return compact ? '0 kg' : 'BW';
  }
  return '$weight';
}
