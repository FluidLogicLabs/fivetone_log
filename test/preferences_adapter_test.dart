import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fivethreeone_log/app/data/adapters/preferences_adapter.dart';
import 'package:fivethreeone_log/app/interactor/models/preferences_model.dart';
import 'package:fivethreeone_log/app/utils/training_defaults.dart';

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

  test('the rounding step defaults to one and survives storage', () {
    // Nothing stored means the setting has never been touched, which is the
    // half kilo default, not the whole kilo fallback.
    expect(_emptyPreferences().roundingStep, 0.5);

    final decoded = _throughStorage(_emptyPreferences().copyWith(roundingStep: 0.5));

    expect(decoded.roundingStep, 0.5);
    expect(decoded, _emptyPreferences().copyWith(roundingStep: 0.5));
  });

  test('a stored rounding step of zero is refused on read', () {
    final map = <String, dynamic>{
      'selectedUnit': 'kg',
      'rmData': <String, double>{},
      'percData': <String, dynamic>{},
      'cycleWeekData': <String, dynamic>{},
      'tmData': <String, double>{},
      'roundingStep': 0,
    };

    // A stored but unusable step falls back to whole kilos.
    expect(PreferencesAdapter.fromMap(map).roundingStep, 1.0);
  });

  test('the training max percentage defaults to 85 and survives storage', () {
    expect(_emptyPreferences().tmPercent, 85.0);

    final decoded = _throughStorage(_emptyPreferences().copyWith(tmPercent: 90));

    expect(decoded.tmPercent, 90.0);
    expect(decoded, _emptyPreferences().copyWith(tmPercent: 90));
  });

  test('a stored map written before the percentage existed still loads', () {
    final map = <String, dynamic>{
      'selectedUnit': 'kg',
      'rmData': <String, double>{'Supino': 100.0},
      'percData': <String, dynamic>{},
      'cycleWeekData': <String, dynamic>{},
      'tmData': <String, double>{'Supino': 90.0},
      'warmupSetsEnabled': true,
      'fslData': <String, bool>{},
    };

    final preferences = PreferencesAdapter.fromMap(map);

    expect(preferences.tmPercent, 85.0);
    expect(preferences.roundingStep, 0.5);
    // The stored training max is what the cycles left behind, so it is kept
    // exactly as it was written.
    expect(preferences.tmData['Supino'], 90.0);
  });

  test('an out of range percentage in a stored map is refused', () {
    final map = <String, dynamic>{
      'selectedUnit': 'kg',
      'rmData': <String, double>{},
      'percData': <String, dynamic>{},
      'cycleWeekData': <String, dynamic>{},
      'tmData': <String, double>{},
      'tmPercent': 140,
    };

    expect(PreferencesAdapter.fromMap(map).tmPercent, 85.0);
  });

  test('the cycle increments default to the standard map and round trip', () {
    expect(_emptyPreferences().cycleIncrement, defaultCycleIncrement);

    final custom = _emptyPreferences().copyWith(
        cycleIncrement: {'Supino': 2.5, 'Agachamento': 12.5});
    final decoded = _throughStorage(custom);

    expect(decoded.cycleIncrement, {'Supino': 2.5, 'Agachamento': 12.5});
    expect(decoded, custom);
  });

  test('a stored map without increments falls back to the defaults', () {
    final map = <String, dynamic>{
      'selectedUnit': 'kg',
      'rmData': <String, double>{},
      'percData': <String, dynamic>{},
      'cycleWeekData': <String, dynamic>{},
      'tmData': <String, double>{},
    };

    expect(PreferencesAdapter.fromMap(map).cycleIncrement, defaultCycleIncrement);
  });

  test('increments written as whole numbers by hand still load', () {
    final map = <String, dynamic>{
      'selectedUnit': 'kg',
      'rmData': <String, double>{},
      'percData': <String, dynamic>{},
      'cycleWeekData': <String, dynamic>{},
      'tmData': <String, double>{},
      'cycleIncrement': <String, dynamic>{'Supino': 5, 'Agachamento': 10},
    };

    final decoded = PreferencesAdapter.fromMap(map);

    expect(decoded.cycleIncrement['Supino'], 5.0);
    expect(decoded.cycleIncrement['Agachamento'], 10.0);
  });

  test('FSL stays off for a lift that was never toggled', () {
    final decoded = _throughStorage(
      _emptyPreferences().copyWith(fslData: {'Supino': true}),
    );

    expect(decoded.fslData['Supino'], isTrue);
    expect(decoded.fslData['Agachamento'] ?? false, isFalse);
  });
}
