import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fivethreeone_log/app/(public)/edit_workout_page.dart';
import 'package:fivethreeone_log/app/interactor/models/preferences_model.dart';
import 'package:fivethreeone_log/app/interactor/models/set_model.dart';
import 'package:fivethreeone_log/app/interactor/models/workout_model.dart';
import 'package:fivethreeone_log/app/interactor/providers/preferences_provider.dart';
import 'package:fivethreeone_log/app/interactor/providers/workout_provider.dart';
import 'package:fivethreeone_log/app/interactor/repository/preferences_repository.dart';
import 'package:fivethreeone_log/app/interactor/repository/workout_repository.dart';
import 'package:fivethreeone_log/app/utils/utils.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Stands in for SharedPreferences, so the page is opened against the same
/// notifier the app uses and the assertions read what was actually stored.
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
  Future<void> updateCycleAndWeek(String exercise, int cycle, int week) async {}
}

class _FakeWorkoutRepository implements WorkoutRepository {
  final List<WorkoutModel> stored;

  _FakeWorkoutRepository(this.stored);

  @override
  Future<List<WorkoutModel?>> getAll() async => stored;

  @override
  Future<WorkoutModel?> get(int id) async {
    for (final workout in stored) {
      if (workout.id == id.toString()) {
        return workout;
      }
    }
    return null;
  }

  @override
  Future<WorkoutModel> insert(WorkoutModel workout) async {
    stored.add(workout);
    return workout;
  }

  @override
  Future<WorkoutModel> update(WorkoutModel workout) async {
    final int index = stored.indexWhere((saved) => saved.id == workout.id);
    if (index != -1) {
      stored[index] = workout;
    }
    return workout;
  }

  @override
  Future<bool> delete(int id) async {
    stored.removeWhere((workout) => workout.id == id.toString());
    return true;
  }
}

/// Week one of cycle three, a 100 kg bench training max, the ladder on and FSL
/// on: the session this page has to show in full.
PreferencesModel _preferences() {
  return const PreferencesModel(
    selectedUnit: 'kg',
    rmData: {'Supino': 100.0},
    percData: {
      'Semana 1': {'Série 1': 65.0, 'Série 2': 75.0, 'Série 3': 85.0},
    },
    cycleWeekData: {
      'Supino': {'cycle': 3, 'week': 1},
    },
    tmData: {'Supino': 100.0},
    warmupSetsEnabled: true,
    fslData: {'Supino': true},
    roundingStep: 1.0,
  );
}

final DateTime _sessionStart = DateTime(2026, 11, 6, 18, 0);

/// Eleven saved sets: three warmups, three working sets and five FSL sets.
WorkoutModel _fullSession({double fslWeight = 65, String id = '1'}) {
  final List<SetModel> sets = [
    const SetModel(setNumber: 1, reps: 5, weight: 40),
    const SetModel(setNumber: 2, reps: 5, weight: 50),
    const SetModel(setNumber: 3, reps: 3, weight: 60),
    const SetModel(setNumber: 4, reps: 5, weight: 65),
    const SetModel(setNumber: 5, reps: 5, weight: 75),
    const SetModel(setNumber: 6, reps: 5, weight: 85),
    for (int i = 0; i < 5; i++)
      SetModel(setNumber: 7 + i, reps: 5, weight: fslWeight),
  ];
  return WorkoutModel(
    id: id,
    date: _sessionStart,
    exerciseName: 'Supino',
    numberOfSets: sets.length,
    sets: sets,
    notes: 'felt strong',
    oneRM: 100,
    volume: 1755,
    timeSpent: const Duration(minutes: 40),
    cycle: 3,
    week: 1,
  );
}

/// A workout whose four sets match no shape the plan can produce, the way a
/// workout saved by an older build looks.
WorkoutModel _legacyWorkout() {
  return WorkoutModel(
    id: '1',
    date: _sessionStart,
    exerciseName: 'Supino',
    numberOfSets: 4,
    sets: const [
      SetModel(setNumber: 1, reps: 5, weight: 60),
      SetModel(setNumber: 2, reps: 5, weight: 70),
      SetModel(setNumber: 3, reps: 5, weight: 80),
      SetModel(setNumber: 4, reps: 8, weight: 50),
    ],
    notes: '',
    oneRM: 111,
    volume: 1450,
    timeSpent: Duration.zero,
    cycle: 3,
    week: 1,
  );
}

/// Accessory work of the same session: its own workout, written a moment after
/// the main lift, as the session screen writes it.
WorkoutModel _accessoryWorkout() {
  return WorkoutModel(
    id: '2',
    date: _sessionStart.add(const Duration(milliseconds: 900)),
    exerciseName: 'Triceps',
    numberOfSets: 2,
    sets: const [
      SetModel(setNumber: 1, reps: 8, weight: 30),
      SetModel(setNumber: 2, reps: 8, weight: 30),
    ],
    oneRM: 0,
    volume: 0,
    timeSpent: Duration.zero,
    cycle: 3,
    week: 1,
    isAccessory: true,
  );
}

class _Launcher extends StatelessWidget {
  final Widget page;

  const _Launcher({required this.page});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => page),
          ),
          child: const Text('open'),
        ),
      ),
    );
  }
}

class _OpenedPage {
  final _FakeWorkoutRepository repository;
  final AppLocalizations localizations;

  _OpenedPage(this.repository, this.localizations);

  WorkoutModel get workout =>
      repository.stored.firstWhere((saved) => !saved.isAccessory);

  WorkoutModel get accessory =>
      repository.stored.firstWhere((saved) => saved.isAccessory);
}

/// Opens the edit page on the first main lift workout through a pushed route,
/// so saving can pop back the way it does in the app.
Future<_OpenedPage> _openEditPage(
  WidgetTester tester,
  List<WorkoutModel> workouts, {
  PreferencesModel? preferences,
}) async {
  final prefsRepository = _FakePreferencesRepository(preferences ?? _preferences());
  final workoutRepository = _FakeWorkoutRepository([...workouts]);
  final preferencesNotifier = PreferencesNotifier(prefsRepository);
  await preferencesNotifier.loadPreferences();
  final workoutNotifier = WorkoutNotifier(workoutRepository);
  final localizations = await AppLocalizations.delegate.load(const Locale('en'));
  final WorkoutModel edited =
      workouts.firstWhere((workout) => !workout.isAccessory);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWith((ref) => preferencesNotifier),
        workoutProvider.overrideWith((ref) => workoutNotifier),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _Launcher(page: EditWorkoutPage(workout: edited)),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  // The rows live in a collapsed tile, as they always have.
  await tester.tap(find.text(localizations.mainLift));
  await tester.pumpAndSettle();

  return _OpenedPage(workoutRepository, localizations);
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.save));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every saved set gets a row, grouped Warmup, Working and FSL',
      (tester) async {
    final page = await _openEditPage(tester, [_fullSession()]);

    expect(find.text(page.localizations.warmup), findsOneWidget);
    expect(find.text(page.localizations.workingSets), findsOneWidget);
    expect(find.text(page.localizations.fsl), findsOneWidget);

    // Eleven rows, each with a reps stepper and a weight stepper.
    expect(find.byIcon(Icons.remove), findsNWidgets(22));
    expect(find.text('40.0'), findsOneWidget);
    expect(find.text('50.0'), findsOneWidget);
    expect(find.text('85.0'), findsOneWidget);
    // Five FSL sets at the same weight, all editable.
    expect(find.text('65.0'), findsNWidgets(6));
  });

  testWidgets('an edited warmup row and FSL row are both saved', (tester) async {
    final page = await _openEditPage(tester, [_fullSession()]);

    // First row, reps: the warmup at 40 kg goes from 5 to 6.
    final firstRepsAdd = find.byIcon(Icons.add).first;
    await tester.ensureVisible(firstRepsAdd);
    await tester.pumpAndSettle();
    await tester.tap(firstRepsAdd);
    await tester.pumpAndSettle();

    // Last row, weight: the fifth FSL set goes from 65 to 66.
    final lastWeightAdd = find.byIcon(Icons.add).last;
    await tester.ensureVisible(lastWeightAdd);
    await tester.pumpAndSettle();
    await tester.tap(lastWeightAdd);
    await tester.pumpAndSettle();

    await _tapSave(tester);

    final WorkoutModel saved = page.workout;
    expect(saved.sets.length, 11);
    expect(saved.sets.first.reps, 6);
    expect(saved.sets.first.weight, 40.0);
    expect(saved.sets.last.weight, 66.0);
    expect(saved.sets.last.reps, 5);
    // The rows nobody touched kept what they were stored with.
    expect(saved.sets[1].weight, 50.0);
    expect(saved.notes, 'felt strong');
  });

  testWidgets('the saved 1RM comes from the last working set', (tester) async {
    // The FSL sets are logged heavier than the working sets, so an estimate
    // taken from the last set of the workout would be visibly wrong.
    final page = await _openEditPage(tester, [_fullSession(fslWeight: 95)]);

    await _tapSave(tester);

    final WorkoutModel saved = page.workout;
    expect(saved.oneRM, calculate1RM(85, 5));
    expect(saved.oneRM, isNot(calculate1RM(95, 5)));
    // Volume still adds up everything that was kept.
    expect(saved.volume, 4130.0);
  });

  testWidgets('a workout that matches no plan stays fully editable',
      (tester) async {
    final page = await _openEditPage(tester, [_legacyWorkout()]);

    expect(find.text(page.localizations.warmup), findsNothing);
    expect(find.text(page.localizations.workingSets), findsNothing);
    expect(find.text(page.localizations.fsl), findsNothing);

    // Four saved sets, four rows.
    expect(find.byIcon(Icons.remove), findsNWidgets(8));

    final firstRepsAdd = find.byIcon(Icons.add).first;
    await tester.ensureVisible(firstRepsAdd);
    await tester.pumpAndSettle();
    await tester.tap(firstRepsAdd);
    await tester.pumpAndSettle();

    await _tapSave(tester);

    final WorkoutModel saved = page.workout;
    expect(saved.sets.length, 4);
    expect(saved.sets.first.reps, 6);
    // No set could be shown to be a working set, so the stored estimate stands
    // rather than being replaced by one read off an arbitrary set.
    expect(saved.oneRM, 111.0);
  });

  testWidgets('accessory rows of the same session are editable and saved',
      (tester) async {
    final page = await _openEditPage(tester, [_fullSession(), _accessoryWorkout()]);

    final accessoryTile =
        find.ancestor(of: find.text('Triceps'), matching: find.byType(ExpansionTile));
    expect(accessoryTile, findsOneWidget);

    await tester.ensureVisible(find.text('Triceps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Triceps'));
    await tester.pumpAndSettle();

    final accessoryRepsAdd =
        find.descendant(of: accessoryTile, matching: find.byIcon(Icons.add)).first;
    await tester.ensureVisible(accessoryRepsAdd);
    await tester.pumpAndSettle();
    await tester.tap(accessoryRepsAdd);
    await tester.pumpAndSettle();

    await _tapSave(tester);

    final WorkoutModel saved = page.accessory;
    expect(saved.isAccessory, isTrue);
    expect(saved.sets.length, 2);
    expect(saved.sets.first.reps, 9);
    expect(saved.sets.first.weight, 30.0);
    // oneRM and volume stay untouched for accessory work, as the session screen
    // leaves them.
    expect(saved.oneRM, 0.0);
    expect(saved.volume, 0.0);
  });
}
