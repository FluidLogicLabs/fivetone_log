import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fivethreeone_log/app/(public)/form_page.dart';
import 'package:fivethreeone_log/app/interactor/models/preferences_model.dart';
import 'package:fivethreeone_log/app/interactor/providers/preferences_provider.dart';
import 'package:fivethreeone_log/app/interactor/repository/preferences_repository.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Stands in for SharedPreferences, so the screen is tested against the same
/// notifier the app uses and the assertions can read what was actually stored.
class _FakePreferencesRepository implements PreferencesRepository {
  PreferencesModel? stored;

  _FakePreferencesRepository(this.stored);

  @override
  Future<PreferencesModel?> get() async => stored;

  @override
  Future<PreferencesModel> insert(PreferencesModel preferences) async {
    stored = preferences;
    return preferences;
  }

  @override
  Future<PreferencesModel> update(PreferencesModel preferences) async {
    stored = preferences;
    return preferences;
  }

  @override
  Future<bool> delete() async {
    stored = null;
    return true;
  }

  @override
  Future<void> updateCycleAndWeek(String exercise, int cycle, int week) async {
    final PreferencesModel? current = stored;
    if (current == null) {
      return;
    }
    stored = current.copyWith(
      cycleWeekData: {
        ...current.cycleWeekData,
        exercise: {'cycle': cycle, 'week': week},
      },
    );
  }
}

/// A lifter two weeks into cycle three, with a bench training max that a cycle
/// has already advanced past the 85% default: 120 at 90% is 108, at 85% it is
/// 102.
PreferencesModel _storedPreferences() {
  return const PreferencesModel(
    selectedUnit: 'Kg',
    rmData: {'Supino': 120.0},
    percData: {},
    cycleWeekData: {
      'Supino': {'cycle': 3, 'week': 2},
    },
    tmData: {'Supino': 108.0},
  );
}

Future<_FakePreferencesRepository> _openEntryScreen(WidgetTester tester) async {
  final repository = _FakePreferencesRepository(_storedPreferences());
  final localizations = await AppLocalizations.delegate.load(const Locale('en'));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWith(
          (ref) => PreferencesNotifier(repository),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const FormPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // The lift fields live in a collapsed tile.
  await tester.tap(find.text(localizations.enter1RM));
  await tester.pumpAndSettle();

  return repository;
}

void main() {
  testWidgets('the fields open on the stored numbers, not on zeros',
      (tester) async {
    await _openEntryScreen(tester);

    expect(find.text('120'), findsOneWidget);
    // The weight and the single rep together reproduce the stored 1RM.
    expect(find.text('1RM: 120.00'), findsOneWidget);
    // And the stored block is stated above the fields.
    expect(find.textContaining('TM 108'), findsOneWidget);
    expect(find.textContaining('Cycle 3'), findsOneWidget);
    expect(find.textContaining('Week 2'), findsOneWidget);
  });

  testWidgets(
      'recalculating one lift rewrites its maxes and leaves cycle and week',
      (tester) async {
    final repository = await _openEntryScreen(tester);

    // Agachamento, Levantamento terra, Supino, Press militar: bench is third.
    final recalculate = find.byTooltip('Recalculate');
    expect(recalculate, findsNWidgets(4));
    await tester.ensureVisible(recalculate.at(2));
    await tester.pumpAndSettle();
    await tester.tap(recalculate.at(2));
    await tester.pumpAndSettle();

    final PreferencesModel stored = repository.stored!;
    // 120 at 85% is 102, so the advanced training max is deliberately gone.
    expect(stored.tmData['Supino'], 102.0);
    expect(stored.rmData['Supino'], 120.0);
    // The training block has not moved.
    expect(stored.cycleWeekData['Supino'], {'cycle': 3, 'week': 2});
    expect(find.text('Recalculated'), findsOneWidget);
    // The stored summary on screen has followed the new numbers.
    expect(find.textContaining('TM 102'), findsOneWidget);
  });

  testWidgets('a lift left blank is skipped instead of being zeroed',
      (tester) async {
    final repository = await _openEntryScreen(tester);
    final PreferencesModel before = repository.stored!;

    final weightFields = find.byType(TextFormField);
    // Supino's weight field: four weight and four reps fields come first.
    await tester.ensureVisible(weightFields.at(4));
    await tester.pumpAndSettle();
    await tester.enterText(weightFields.at(4), '');
    await tester.pumpAndSettle();

    final recalculate = find.byTooltip('Recalculate');
    await tester.ensureVisible(recalculate.at(2));
    await tester.pumpAndSettle();
    await tester.tap(recalculate.at(2));
    await tester.pumpAndSettle();

    expect(repository.stored, before);
    expect(find.text('Check input data'), findsOneWidget);
  });
}
