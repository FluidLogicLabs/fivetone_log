import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fivethreeone_log/app/data/adapters/preferences_adapter.dart';
import 'package:fivethreeone_log/app/interactor/models/preferences_model.dart';

/// Round trips through JSON, which is exactly how the repository stores
/// preferences and how an export file carries them.
PreferencesModel _throughStorage(PreferencesModel model) {
  final String stored = jsonEncode(PreferencesAdapter.toMap(model));
  return PreferencesAdapter.fromMap(
      jsonDecode(stored) as Map<String, dynamic>);
}

PreferencesModel _emptyPreferences() {
  return const PreferencesModel(
    selectedUnit: 'kg',
    rmData: {},
    percData: {},
    cycleWeekData: {},
    tmData: {},
  );
}

void main() {
  test('warmups default on and FSL starts empty', () {
    final preferences = _emptyPreferences();

    expect(preferences.warmupSetsEnabled, isTrue);
    expect(preferences.fslData, isEmpty);
  });

  test('a stored map written before the toggles existed still loads', () {
    final map = <String, dynamic>{
      'selectedUnit': 'kg',
      'rmData': <String, double>{'Supino': 100.0},
      'percData': <String, dynamic>{},
      'cycleWeekData': <String, dynamic>{},
      'tmData': <String, double>{'Supino': 90.0},
    };

    final preferences = PreferencesAdapter.fromMap(map);

    expect(preferences.warmupSetsEnabled, isTrue);
    expect(preferences.fslData, isEmpty);
    expect(preferences.tmData['Supino'], 90.0);
  });

  test('hiding warmups and enabling FSL for one lift both survive storage', () {
    final preferences = _emptyPreferences()
        .copyWith(warmupSetsEnabled: false, fslData: {'Supino': true});

    final decoded = _throughStorage(preferences);

    expect(decoded.warmupSetsEnabled, isFalse);
    expect(decoded.fslData['Supino'], isTrue);
    expect(decoded.fslData.containsKey('Agachamento'), isFalse);
    expect(decoded, preferences);
  });

  test('FSL stays off for a lift that was never toggled', () {
    final decoded = _throughStorage(
      _emptyPreferences().copyWith(fslData: {'Supino': true}),
    );

    expect(decoded.fslData['Supino'], isTrue);
    expect(decoded.fslData['Agachamento'] ?? false, isFalse);
  });
}
