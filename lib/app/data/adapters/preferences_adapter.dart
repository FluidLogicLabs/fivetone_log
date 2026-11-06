import '../../interactor/models/preferences_model.dart';
import '../../utils/training_defaults.dart';

class PreferencesAdapter {
  // A stored map is only ever a jsonDecode result, so every value arrives as
  // num or String rather than a typed double. These helpers keep the reads
  // null safe and coerce ints, which a hand-edited export can easily carry.
  static double? _asDouble(dynamic value) =>
      value is num ? value.toDouble() : null;

  static Map<String, double> _doubleMap(dynamic value) {
    if (value is! Map) {
      return {};
    }
    return <String, double>{
      for (final entry in value.entries)
        if (entry.value is num)
          '${entry.key}': (entry.value as num).toDouble(),
    };
  }

  static Map<String, Map<String, double>> _nestedDoubleMap(dynamic value) {
    if (value is! Map) {
      return {};
    }
    return <String, Map<String, double>>{
      for (final entry in value.entries)
        '${entry.key}': _doubleMap(entry.value),
    };
  }

  static Map<String, Map<String, int>> _nestedIntMap(dynamic value) {
    if (value is! Map) {
      return {};
    }
    return <String, Map<String, int>>{
      for (final entry in value.entries)
        if (entry.value is Map)
          '${entry.key}': <String, int>{
            for (final inner in (entry.value as Map).entries)
              if (inner.value is num)
                '${inner.key}': (inner.value as num).round(),
          },
    };
  }

  // Convert a Map to PreferencesModel
  static PreferencesModel fromMap(Map<String, dynamic> map) {
    return PreferencesModel(
      selectedUnit: map['selectedUnit'] as String? ?? 'kg',
      rmData: _doubleMap(map['rmData']), // Changed to store 1RM values
      percData: _nestedDoubleMap(map['percData']),
      cycleWeekData: _nestedIntMap(map['cycleWeekData']), // New field
      tmData: _doubleMap(map['tmData']), // New field
      // Older stored maps and exports carry neither key: warmups were always
      // on before they became optional, and FSL was never offered at all.
      warmupSetsEnabled: map['warmupSetsEnabled'] as bool? ?? true,
      fslData: Map<String, bool>.from(map['fslData'] ?? {}),
      roundingStep: sanitiseRoundingStep(_asDouble(map['roundingStep'])),
      tmPercent: sanitiseTmPercent(_asDouble(map['tmPercent'])),
      // No stored map means the map was written before increments were a
      // preference, so the standard defaults apply.
      cycleIncrement: map['cycleIncrement'] == null
          ? defaultCycleIncrement
          : _doubleMap(map['cycleIncrement']),
    );
  }

  // Convert PreferencesModel to a Map
  static Map<String, dynamic> toMap(PreferencesModel model) {
    return {
      'selectedUnit': model.selectedUnit,
      'rmData': model.rmData, // Changed to store 1RM values
      'percData': model.percData,
      'cycleWeekData': model.cycleWeekData, // New field
      'tmData': model.tmData, // New field
      'warmupSetsEnabled': model.warmupSetsEnabled,
      'fslData': model.fslData,
      'roundingStep': model.roundingStep,
      'tmPercent': model.tmPercent,
      'cycleIncrement': model.cycleIncrement,
    };
  }
}
