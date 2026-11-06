import 'package:flutter/foundation.dart';

@immutable
class PreferencesModel {
  final String selectedUnit;
  final Map<String, double> rmData; // Changed to store 1RM values
  final Map<String, Map<String, double>> percData;
  final Map<String, Map<String, int>> cycleWeekData; // New field
  final Map<String, double> tmData; // Add this field
  // Session extras. Warmups are on by default; FSL is opt in per lift, so the
  // map is keyed by exercise name like tmData and cycleWeekData are.
  final bool warmupSetsEnabled;
  final Map<String, bool> fslData;

  const PreferencesModel({
    required this.selectedUnit,
    required this.rmData,
    required this.percData,
    required this.cycleWeekData, // New field
    required this.tmData,
    this.warmupSetsEnabled = true,
    this.fslData = const {},
  });

  PreferencesModel copyWith({
    String? selectedUnit,
    Map<String, double>? rmData, // Changed to store 1RM values
    Map<String, Map<String, double>>? percData,
    Map<String, Map<String, int>>? cycleWeekData, // New field
    Map<String, double>? tmData,
    bool? warmupSetsEnabled,
    Map<String, bool>? fslData,
  }) {
    return PreferencesModel(
      selectedUnit: selectedUnit ?? this.selectedUnit,
      rmData: rmData ?? this.rmData, // Changed to store 1RM values
      percData: percData ?? this.percData,
      cycleWeekData: cycleWeekData ?? this.cycleWeekData, // New field
      tmData: tmData ?? this.tmData,
      warmupSetsEnabled: warmupSetsEnabled ?? this.warmupSetsEnabled,
      fslData: fslData ?? this.fslData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PreferencesModel &&
          runtimeType == other.runtimeType &&
          selectedUnit == other.selectedUnit &&
          mapEquals(rmData, other.rmData) && // Changed to store 1RM values
          mapEquals(percData, other.percData) &&
          mapEquals(cycleWeekData, other.cycleWeekData) && // New field
          mapEquals(tmData, other.tmData) && // Add this line
          warmupSetsEnabled == other.warmupSetsEnabled &&
          mapEquals(fslData, other.fslData);

  @override
  int get hashCode =>
      selectedUnit.hashCode ^ rmData.hashCode ^ percData.hashCode ^ cycleWeekData.hashCode ^ tmData.hashCode ^ warmupSetsEnabled.hashCode ^ fslData.hashCode; // Add tmData to hashCode
}