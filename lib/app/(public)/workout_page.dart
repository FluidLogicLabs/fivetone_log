import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fivethreeone_log/app/interactor/models/set_model.dart';
import 'package:fivethreeone_log/app/interactor/models/workout_model.dart';
import 'package:fivethreeone_log/app/interactor/providers/preferences_provider.dart';
import 'package:fivethreeone_log/app/interactor/providers/workout_provider.dart';
import 'package:fivethreeone_log/app/interactor/providers/accessory_exercise_provider.dart'; // Accessory exercise catalogue
import 'package:fivethreeone_log/app/utils/accessory_sets.dart'; // Accessory set parsing
import 'package:fivethreeone_log/app/utils/session_plan.dart'; // Warmups, working sets and FSL for the day
import 'package:fivethreeone_log/app/utils/training_defaults.dart'; // Rounding step, training max percentage, cycle increment
import 'package:fivethreeone_log/app/utils/utils.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:fivethreeone_log/app/utils/exercise_names.dart'; // Import the exercise names mapping

// TODO: Resolver bug: os pesos não estão sendo atualizados corretamente quando o usuário finaliza um ciclo.

class WorkoutPage extends ConsumerStatefulWidget {
  final String exercise;

  const WorkoutPage({super.key, required this.exercise});

  @override
  _WorkoutPageState createState() => _WorkoutPageState();
}

class _WorkoutPageState extends ConsumerState<WorkoutPage> {
  final Map<int, bool> _isCompleted = {};
  final Map<int, int> _reps = {};
  final Map<int, double> _weights = {};
  late Stopwatch _stopwatch;
  late Timer _timer;
  final TextEditingController _notesController = TextEditingController();
  late Timer _setTimer;
  Duration _setTimerDuration = Duration.zero;
  Duration _selectedSetTimerDuration = const Duration(minutes: 2); // Default value
  final Map<String, List<TextEditingController>> _accessoryRepsControllers = {}; // Accessory reps input per exercise
  final Map<String, List<TextEditingController>> _accessoryWeightControllers = {}; // Accessory weight input per exercise
  // Expansion flags are session memory only: the saved workouts decide the
  // initial state once and the user toggles them from there.
  bool _mainLiftExpanded = false;
  bool _accessorySectionExpanded = false;
  final Map<String, bool> _accessoryExpanded = {}; // Accessory card expansion per exercise
  // Sections only get their initial state after the first frame, so this flips
  // once and never goes back.
  bool _expansionSeeded = false;
  // Each group of sets ticks into its own stretch of the maps above. The gaps
  // leave room for 3 warmups, 3 working sets and 5 FSL sets, so turning a group
  // on mid-session cannot shift another group's ticks.
  static const int _warmupIndexBase = 0;
  static const int _mainIndexBase = 10;
  static const int _fslIndexBase = 20;

  void _showNotesDialog(AppLocalizations localizations) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.notes),
          content: TextField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: localizations.enterNotes,
            ),
            maxLines: 5,
          ),
          actions: <Widget>[
            TextButton(
              child: Text(localizations.cancel.toUpperCase()),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(localizations.ok.toUpperCase()),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showSetTimerDialog(AppLocalizations localizations) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.selectTimerDuration),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<Duration>(
                title: Text('30 ${localizations.seconds}'),
                value: const Duration(seconds: 30),
                groupValue: _selectedSetTimerDuration,
                onChanged: (Duration? value) {
                  setState(() {
                    _selectedSetTimerDuration = value!;
                  });
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<Duration>(
                title: Text('60 ${localizations.seconds}'),
                value: const Duration(seconds: 60),
                groupValue: _selectedSetTimerDuration,
                onChanged: (Duration? value) {
                  setState(() {
                    _selectedSetTimerDuration = value!;
                  });
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<Duration>(
                title: Text('90 ${localizations.seconds}'),
                value: const Duration(seconds: 90),
                groupValue: _selectedSetTimerDuration,
                onChanged: (Duration? value) {
                  setState(() {
                    _selectedSetTimerDuration = value!;
                  });
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<Duration>(
                title: Text('2 ${localizations.minutes}'),
                value: const Duration(minutes: 2),
                groupValue: _selectedSetTimerDuration,
                onChanged: (Duration? value) {
                  setState(() {
                    _selectedSetTimerDuration = value!;
                  });
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<Duration>(
                title: Text('3 ${localizations.minutes}'),
                value: const Duration(minutes: 3),
                groupValue: _selectedSetTimerDuration,
                onChanged: (Duration? value) {
                  setState(() {
                    _selectedSetTimerDuration = value!;
                  });
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<Duration>(
                title: Text('5 ${localizations.minutes}'),
                value: const Duration(minutes: 5),
                groupValue: _selectedSetTimerDuration,
                onChanged: (Duration? value) {
                  setState(() {
                    _selectedSetTimerDuration = value!;
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _startSetTimer() {
    _setTimer.cancel();
    _setTimerDuration = _selectedSetTimerDuration;
    _setTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_setTimerDuration.inSeconds > 0) {
        setState(() {
          _setTimerDuration -= const Duration(seconds: 1);
        });
      } else {
        _setTimer.cancel();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _stopwatch.start();
    _setTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });

    // Initialize _isCompleted with false for every set
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final preferences = ref.read(preferencesProvider);
      final week = preferences.cycleWeekData[widget.exercise]?['week'] ?? 1;
      final sets = preferences.percData['Semana $week']?.entries.toList() ?? [];
      final workouts = ref.read(workoutProvider);
      setState(() {
        for (int i = 0; i < sets.length; i++) {
          _isCompleted[_mainIndexBase + i] = false;
        }
        // A section opens only when today already has a saved workout for it.
        // That saved data is the only signal available this early, live input
        // does not exist yet.
        _mainLiftExpanded = _hasMainLiftWorkoutToday(workouts);
        _accessorySectionExpanded = _hasAccessoryWorkoutToday(workouts);
        _expansionSeeded = true;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _stopwatch.stop();
    _setTimer?.cancel();
    for (final controllers in _accessoryRepsControllers.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
    for (final controllers in _accessoryWeightControllers.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  void _showWeightDialog(int index, double currentWeight, AppLocalizations localizations) {
    final TextEditingController controller =
        TextEditingController(text: currentWeight.toString());
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.enterWeight),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: localizations.enterWeight),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(localizations.cancel.toUpperCase()),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(localizations.ok.toUpperCase()),
              onPressed: () {
                setState(() {
                  _weights[index] =
                      double.tryParse(controller.text) ?? currentWeight;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  List<int> _getRepsForWeek(int week) {
    switch (week) {
      case 1:
      case 4:
        return [5, 5, 5];
      case 2:
        return [3, 3, 3];
      case 3:
        return [5, 3, 1];
      default:
        return [5, 5, 5];
    }
  }

  // Maps every planned set to the completion index its row uses, in the order
  // the sets are lifted.
  Map<int, PlannedSet> _planByIndex(SessionPlan plan) {
    return {
      for (int i = 0; i < plan.warmupSets.length; i++)
        _warmupIndexBase + i: plan.warmupSets[i],
      for (int i = 0; i < plan.mainSets.length; i++)
        _mainIndexBase + i: plan.mainSets[i],
      for (int i = 0; i < plan.fslSets.length; i++)
        _fslIndexBase + i: plan.fslSets[i],
    };
  }

  // Only the sets the session currently shows count, so a group that is
  // switched off can never hold the save button hostage.
  bool _allSetsCompleted(SessionPlan plan) {
    final indices = _planByIndex(plan).keys;
    return indices.isNotEmpty &&
        indices.every((index) => _isCompleted[index] ?? false);
  }

  Future<void> _saveData(
      int week,
      int cycle,
      double actualTM,
      String exercise,
      SessionPlan plan,
      Function(WorkoutModel) onSave,
      Function(String, int, int) updateCycleAndWeek,
      Function(String, double) updateTM) async {
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyy-MM-dd – kk:mm').format(now);
    final List<SetModel> setsData = [];
    final String notes = _notesController.text; // Get notes from the controller
    final Duration totalTime = _stopwatch.elapsed; // Get total time

    double totalVolume = 0.0;
    SetModel? lastMainSet;

    // Warmups, working sets and FSL are all written, in the order lifted.
    _planByIndex(plan).forEach((index, planned) {
      if (_isCompleted[index] != true) {
        return;
      }
      final reps = _reps[index] ?? planned.reps;
      final weight = _weights[index] ?? planned.weight;
      final SetModel set = SetModel(
        setNumber: planned.setNumber,
        reps: reps,
        weight: weight,
      );
      setsData.add(set);
      totalVolume += weight * reps;
      if (plan.mainSets.contains(planned)) {
        lastMainSet = set;
      }
    });

    if (setsData.isEmpty) {
      return;
    }

    // The stored 1RM comes from the last working set: a lighter FSL or warmup
    // set at the end of the session would otherwise deflate the estimate.
    final lastSet = lastMainSet ?? setsData.last;
    final calculated1RM = calculate1RM(lastSet.weight, lastSet.reps);

    final workout = WorkoutModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: now,
      exerciseName: exercise,
      numberOfSets: setsData.length,
      sets: setsData,
      notes: notes, // Store notes
      oneRM: calculated1RM, // Store calculated 1RM
      volume: totalVolume, // Store total volume
      timeSpent: totalTime, // Store total time
      cycle: cycle, // Store cycle
      week: week, // Store week
    );

    onSave(workout);

    int newWeek = week + 1;
    int newCycle = cycle;
    
    if (newWeek > 4) {
      newWeek = 1;
      newCycle += 1;

      // Update 1RM
      double increment =
          (exercise == 'Levantamento terra' || exercise == 'Agachamento')
              ? 5.0
              : 2.5;
      print('$exercise: $increment');
      final newTM = actualTM + increment;
      await updateTM(exercise, newTM);
    }

    await updateCycleAndWeek(exercise, newCycle, newWeek);
  }

  // DateUtils.isSameDay compares calendar days, which is what "today" means
  // here; the codebase has no other "is today" helper.
  bool _isToday(DateTime date) => DateUtils.isSameDay(date, DateTime.now());

  // ExpansionTile reads initiallyExpanded only when it creates its state, so a
  // section carries the seed flag in its key: it is rebuilt exactly once, on
  // the frame the first-frame seed lands, and never again. The names keep the
  // two sibling keys distinct.
  Key _seedKey(String section) => ValueKey<String>('$section:$_expansionSeeded');

  // This lift already logged today, so its section can start open.
  bool _hasMainLiftWorkoutToday(List<WorkoutModel> workouts) {
    return workouts.any((workout) =>
        !workout.isAccessory &&
        workout.exerciseName == widget.exercise &&
        _isToday(workout.date));
  }

  // Any accessory row already logged today, so the accessory section can start
  // open.
  bool _hasAccessoryWorkoutToday(List<WorkoutModel> workouts) {
    return workouts.any(
        (workout) => workout.isAccessory && _isToday(workout.date));
  }

  // Most recent accessory row saved under [name], used for the last-time
  // prefill shown inside the accessory section.
  WorkoutModel? _lastAccessoryWorkout(String name, List<WorkoutModel> workouts) {
    WorkoutModel? last;
    for (final workout in workouts) {
      if (!workout.isAccessory || workout.exerciseName != name) {
        continue;
      }
      if (last == null) {
        last = workout;
      } else if (workout.date.isAfter(last.date)) {
        last = workout;
      }
    }
    return last;
  }

  // Creates the input controllers for a catalogue entry the first time it is
  // shown. The rows are seeded with last time's sets when there are any,
  // otherwise three empty rows. Later edits are never overwritten.
  void _ensureAccessoryControllers(String name, WorkoutModel? lastWorkout) {
    if (_accessoryRepsControllers.containsKey(name)) {
      return;
    }
    // Same once-only pass decides the card's initial state: it opens only when
    // this exercise was already logged today. lastWorkout is the most recent
    // saved row, so it being today's means today has one.
    _accessoryExpanded[name] =
        lastWorkout != null && _isToday(lastWorkout.date);
    final List<TextEditingController> repsControllers = [];
    final List<TextEditingController> weightControllers = [];
    final List<SetModel> lastSets = lastWorkout?.sets ?? [];
    final int rowCount = lastSets.isNotEmpty ? lastSets.length : 3;
    for (int i = 0; i < rowCount; i++) {
      final SetModel? lastSet = i < lastSets.length ? lastSets[i] : null;
      repsControllers.add(TextEditingController(
          text: lastSet != null ? '${lastSet.reps}' : ''));
      weightControllers.add(TextEditingController(
          text: lastSet != null ? '${lastSet.weight}' : ''));
    }
    _accessoryRepsControllers[name] = repsControllers;
    _accessoryWeightControllers[name] = weightControllers;
  }

  // One-line summary for the collapsed card: how many rows already hold reps.
  // Deliberately the simple non-empty test, it only has to be readable, not to
  // match what parseAccessorySets writes.
  int _accessoryFilledRowCount(String name) {
    final repsControllers = _accessoryRepsControllers[name] ?? [];
    return repsControllers
        .where((controller) => controller.text.trim().isNotEmpty)
        .length;
  }

  void _addAccessorySet(String name) {
    final repsControllers = _accessoryRepsControllers[name];
    final weightControllers = _accessoryWeightControllers[name];
    if (repsControllers == null || weightControllers == null) {
      return;
    }
    setState(() {
      repsControllers.add(TextEditingController());
      weightControllers.add(TextEditingController());
    });
  }

  void _removeAccessorySet(String name, int index) {
    final repsControllers = _accessoryRepsControllers[name];
    final weightControllers = _accessoryWeightControllers[name];
    if (repsControllers == null || weightControllers == null) {
      return;
    }
    if (index < 0 ||
        index >= repsControllers.length ||
        repsControllers.length <= 1) {
      return;
    }
    final TextEditingController removedRepsController =
        repsControllers.removeAt(index);
    final TextEditingController removedWeightsController =
        weightControllers.removeAt(index);
    setState(() {});
    // Dispose after the frame, once the removed rows are gone from the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      removedRepsController.dispose();
      removedWeightsController.dispose();
    });
  }

  // "BW" where there is room for it, i.e. next to the weight input.
  String? _accessoryWeightSuffix(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) {
      return formatAccessoryWeight(0.0);
    }
    final double? weight = double.tryParse(trimmed);
    if (weight == null || weight != 0) {
      return null;
    }
    return formatAccessoryWeight(weight);
  }

  // Dense summary of a saved accessory session, e.g. "8 x 60.0, 7 x 0 kg".
  String _formatAccessorySets(List<SetModel> sets) {
    return sets
        .map((set) =>
            '${set.reps} x ${formatAccessoryWeight(set.weight, compact: true)}')
        .join(', ');
  }

  void _showAddAccessoryDialog(AppLocalizations localizations) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.accessoryAdd),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: localizations.accessoryNameHint,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(localizations.cancel.toUpperCase()),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(localizations.ok.toUpperCase()),
              onPressed: () {
                final String name = controller.text.trim();
                Navigator.of(context).pop();
                if (name.isNotEmpty) {
                  ref
                      .read(accessoryExercisesProvider.notifier)
                      .addExercise(name);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showRenameAccessoryDialog(String name, AppLocalizations localizations) {
    final TextEditingController controller = TextEditingController(text: name);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.accessoryRename),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: localizations.accessoryNameHint,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(localizations.cancel.toUpperCase()),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(localizations.ok.toUpperCase()),
              onPressed: () {
                final String newName = controller.text.trim();
                Navigator.of(context).pop();
                if (newName.isNotEmpty && newName != name) {
                  _renameAccessory(name, newName);
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Renaming only changes the catalogue entry: rows already logged keep the old
  // name, they are history.
  Future<void> _renameAccessory(String oldName, String newName) async {
    await ref
        .read(accessoryExercisesProvider.notifier)
        .renameExercise(oldName, newName);
    // Keep whatever was already typed in this exercise's rows.
    final repsControllers = _accessoryRepsControllers.remove(oldName);
    final weightControllers = _accessoryWeightControllers.remove(oldName);
    if (repsControllers != null && weightControllers != null) {
      _accessoryRepsControllers[newName] = repsControllers;
      _accessoryWeightControllers[newName] = weightControllers;
    }
    // The card also keeps its open/closed state across a rename; without this
    // it would come back closed, since the new name has no flag yet.
    final bool? wasExpanded = _accessoryExpanded.remove(oldName);
    if (wasExpanded != null) {
      _accessoryExpanded[newName] = wasExpanded;
    }
  }

  // Deleting only removes the catalogue entry: logged history rows stay.
  Future<void> _deleteAccessory(String name) async {
    await ref.read(accessoryExercisesProvider.notifier).deleteExercise(name);
    final List<TextEditingController> removedRepsControllers =
        _accessoryRepsControllers.remove(name) ?? <TextEditingController>[];
    final List<TextEditingController> removedWeightsControllers =
        _accessoryWeightControllers.remove(name) ?? <TextEditingController>[];
    _accessoryExpanded.remove(name);
    // Dispose after the frame, once the entry is gone from the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in removedRepsControllers) {
        controller.dispose();
      }
      for (final controller in removedWeightsControllers) {
        controller.dispose();
      }
    });
  }

  // Writes one row per accessory exercise that has at least one filled set.
  // Nothing entered means nothing written. oneRM and volume are never computed
  // for accessory rows.
  Future<void> _saveAccessoryData(int cycle, int week) async {
    final accessoryExercises = ref.read(accessoryExercisesProvider);
    if (accessoryExercises.isEmpty) {
      return;
    }
    final DateTime now = DateTime.now();

    for (final entry in accessoryExercises) {
      final repsControllers = _accessoryRepsControllers[entry.name];
      final weightControllers = _accessoryWeightControllers[entry.name];
      if (repsControllers == null || weightControllers == null) {
        continue;
      }
      final setsData = parseAccessorySets(
        repsControllers.map((controller) => controller.text).toList(),
        weightControllers.map((controller) => controller.text).toList(),
      );
      if (setsData == null) {
        continue;
      }

      final workout = WorkoutModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: now,
        exerciseName: entry.name,
        numberOfSets: setsData.length,
        sets: setsData,
        notes: '',
        oneRM: 0,
        volume: 0,
        timeSpent: Duration.zero,
        cycle: cycle,
        week: week,
        isAccessory: true, // New field
      );

      await ref.read(workoutProvider.notifier).addWorkout(workout);
      await ref
          .read(accessoryExercisesProvider.notifier)
          .touch(entry.name, widget.exercise);
    }
  }

  // True when at least one accessory entry has a filled set row, so an
  // accessory-only session can be saved.
  bool _anyAccessorySetFilled() {
    final Map<String, List<String>> repsInputs = {};
    final Map<String, List<String>> weightInputs = {};
    final names = <String>{
      ..._accessoryRepsControllers.keys,
      ..._accessoryWeightControllers.keys,
    };
    for (final name in names) {
      repsInputs[name] = (_accessoryRepsControllers[name] ?? [])
          .map((controller) => controller.text)
          .toList();
      weightInputs[name] = (_accessoryWeightControllers[name] ?? [])
          .map((controller) => controller.text)
          .toList();
    }
    return anyAccessorySetsFilled(repsInputs, weightInputs);
  }

  Widget _buildAccessorySection(
    AppLocalizations localizations,
    List<WorkoutModel> workouts,
  ) {
    final accessoryExercises = ref.watch(accessoryExercisesProvider);
    final entries = [...accessoryExercises];
    // Exercises already used on this lift day surface first, then alphabetical.
    entries.sort((a, b) {
      final bool aUsedHere = a.lastUsedLift == widget.exercise;
      final bool bUsedHere = b.lastUsedLift == widget.exercise;
      if (aUsedHere != bUsedHere) {
        return aUsedHere ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return ExpansionTile(
      // Rebuilt once, when the first-frame seed lands; see [_seedKey].
      key: _seedKey('accessorySection'),
      initiallyExpanded: _accessorySectionExpanded,
      onExpansionChanged: (bool expanded) {
        setState(() {
          _accessorySectionExpanded = expanded;
        });
      },
      title: Text(localizations.accessory),
      children: [
        for (final entry in entries)
          _buildAccessoryEntryCard(entry.name, localizations, workouts),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(localizations.accessoryAdd),
            onPressed: () => _showAddAccessoryDialog(localizations),
          ),
        ),
      ],
    );
  }

  Widget _buildAccessoryEntryCard(
    String name,
    AppLocalizations localizations,
    List<WorkoutModel> workouts,
  ) {
    final WorkoutModel? lastWorkout = _lastAccessoryWorkout(name, workouts);
    _ensureAccessoryControllers(name, lastWorkout);
    final repsControllers = _accessoryRepsControllers[name] ?? [];
    final weightControllers = _accessoryWeightControllers[name] ?? [];

    return Card(
      // Cards reorder when an exercise is last used on another lift day, so the
      // identity is the name rather than the position in the list.
      key: ValueKey<String>('accessory:$name'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      elevation: 4.0,
      margin: const EdgeInsets.all(8.0),
      // The header row stays visible and the body folds away, so a long
      // catalogue stays scannable. Tapping the header toggles it.
      child: ExpansionTile(
        initiallyExpanded: _accessoryExpanded[name] ?? false,
        onExpansionChanged: (bool expanded) {
          setState(() {
            _accessoryExpanded[name] = expanded;
          });
        },
        shape: const Border(),
        collapsedShape: const Border(),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        tilePadding: const EdgeInsets.symmetric(horizontal: 8.0),
        childrenPadding: const EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 8.0),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (String value) {
                if (value == 'rename') {
                  _showRenameAccessoryDialog(name, localizations);
                } else if (value == 'delete') {
                  _deleteAccessory(name);
                }
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'rename',
                  child: Text(localizations.accessoryRename),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text(localizations.accessoryDelete),
                ),
              ],
            ),
          ],
        ),
        // On screen collapsed or not: what this session already holds.
        subtitle: Text(
          '${localizations.set}: ${_accessoryFilledRowCount(name)}',
          style: const TextStyle(fontSize: 12.0),
        ),
        children: [
          if (lastWorkout != null)
            Row(
              children: [
                const Icon(Icons.history, size: 16.0),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    '${localizations.accessoryLastUsed}: ${DateFormat('yyyy-MM-dd').format(lastWorkout.date)} - ${_formatAccessorySets(lastWorkout.sets)}',
                    style: const TextStyle(fontSize: 12.0),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8.0),
          for (int i = 0; i < repsControllers.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: repsControllers[i],
                      keyboardType: TextInputType.number,
                      onChanged: (String value) {
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: '${localizations.set} ${i + 1}',
                        hintText: localizations.reps,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: TextFormField(
                      controller: weightControllers[i],
                      keyboardType: TextInputType.number,
                      onChanged: (String value) {
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: localizations.weight,
                        suffixText:
                            _accessoryWeightSuffix(weightControllers[i].text),
                      ),
                    ),
                  ),
                  IconButton(
                    iconSize: 16.0,
                    icon: const Icon(Icons.remove),
                    onPressed: repsControllers.length > 1
                        ? () => _removeAccessorySet(name, i)
                        : null,
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(localizations.accessoryAddSet),
              onPressed: () => _addAccessorySet(name),
            ),
          ),
        ],
      ),
    );
  }
  
  String getTranslatedExerciseName(String exercise, AppLocalizations localizations) {
    switch (exercise) {
      case 'Agachamento':
        return localizations.squat;
      case 'Supino':
        return localizations.bench;
      case 'Levantamento terra':
        return localizations.deadLift;
      case 'Desenvolvimento militar':
        return localizations.militaryPress;
      default:
        return exercise; // Fallback to the original name if not found
    }
  }
  
  // Group header inside the main lift section: "Warmup" above the ladder, "FSL"
  // below the working sets.
  Widget _buildGroupLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(label, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
  }

  // The percentage is context, not the headline: small and muted, directly
  // under the weight it describes.
  Widget _buildPercentageLabel(double percentage) {
    final ThemeData theme = Theme.of(context);
    return Text(
      formatPercentageLabel(percentage),
      style: theme.textTheme.bodySmall?.copyWith(
        fontSize: 10.0,
        color: theme.disabledColor,
      ),
    );
  }

  // Compact label and switch, so both session toggles fit on one row.
  Widget _buildSessionToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  // One table per group: warmups, working sets, FSL. [indexBase] keeps each
  // group on its own stretch of the tick and edit maps, so switching a group on
  // or off never shifts another group's ticks.
  Widget _buildSetsTable(
    List<PlannedSet> plannedSets,
    int indexBase,
    AppLocalizations localizations,
    String unit,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 10.0,
        columns: [
          DataColumn(
            numeric: false,
            tooltip: localizations.set,
            onSort: (columnIndex, ascending) {},
            label: Center(child: Text(localizations.set)),
          ),
          DataColumn(
            numeric: false,
            tooltip: localizations.reps,
            onSort: (columnIndex, ascending) {},
            label: Center(child: Text(localizations.reps)),
          ),
          DataColumn(
            numeric: false,
            tooltip: unit,
            label: Center(child: Text(unit)),
          ),
        ],
        rows: List<DataRow>.generate(
          plannedSets.length,
          (i) {
            final int index = indexBase + i;
            final PlannedSet planned = plannedSets[i];
            final bool isCompleted = _isCompleted[index] ?? false;
            final int reps = _reps[index] ?? planned.reps;
            final double weight = _weights[index] ?? planned.weight;
            return DataRow(
              cells: [
                DataCell(
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: isCompleted,
                        onChanged: (bool? value) {
                          setState(() {
                            _isCompleted[index] = value ?? false;
                            if (value == true) {
                              _startSetTimer();
                            }
                          });
                        },
                      ),
                      Text('${planned.setNumber}'),
                    ],
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 16.0,
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          setState(() {
                            _reps[index] = (reps > 0) ? reps - 1 : 0;
                          });
                        },
                      ),
                      Text('$reps'),
                      IconButton(
                        iconSize: 16.0,
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          setState(() {
                            _reps[index] = reps + 1;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onLongPress: () {
                          _showWeightDialog(index, weight, localizations);
                        },
                        child: IconButton(
                          iconSize: 16.0,
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            setState(() {
                              _weights[index] = (weight > 0) ? weight - 1 : 0;
                            });
                          },
                        ),
                      ),
                      GestureDetector(
                        onLongPress: () {
                          _showWeightDialog(index, weight, localizations);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$weight'),
                            _buildPercentageLabel(planned.percentage),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onLongPress: () {
                          _showWeightDialog(index, weight, localizations);
                        },
                        child: IconButton(
                          iconSize: 16.0,
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            setState(() {
                              _weights[index] = weight + 1;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(preferencesProvider);
    final workouts = ref.watch(workoutProvider);
    final localizations = AppLocalizations.of(context)!;
    final oneRM = preferences.rmData[widget.exercise] ?? 0.0;
    final tm = preferences.tmData?[widget.exercise] ?? (oneRM * 0.9); // Use TM if available, else fallback
    final percData = preferences.percData;
    final cycleWeekData = preferences.cycleWeekData[widget.exercise] ??
        {'cycle': 1, 'week': 1}; 
    
    if (oneRM == 0.0) {
      return Scaffold(
        appBar: AppBar(
          title: Text(getTranslatedExerciseName(widget.exercise, localizations)),
        ),
        body: Center(
          child: Text('${localizations.noDataAvailable} ${getTranslatedExerciseName(widget.exercise, localizations)}'),
        ),
      );
    }

    final week = cycleWeekData['week']!;
    final sets = percData['Semana $week']?.entries.toList() ?? [];
    final repsForWeek = _getRepsForWeek(week);
    final bool warmupSetsEnabled = preferences.warmupSetsEnabled;
    final bool fslEnabled = preferences.fslData[widget.exercise] ?? false;
    final SessionPlan plan = buildSessionPlan(
      trainingMax: tm,
      weekPercentages: sets.map((set) => set.value).toList(),
      mainReps: repsForWeek,
      includeWarmups: warmupSetsEnabled,
      includeFsl: fslEnabled,
      // One preference decides the step for the ladder, the working sets and
      // FSL together, so the three can never round differently.
      roundingStep: sanitiseRoundingStep(preferences.roundingStep),
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                getTranslatedExerciseName(widget.exercise, localizations),
                style: const TextStyle(
                    fontSize: 16), // Keep the font a little bigger
                overflow: TextOverflow
                    .ellipsis, // Limit the size of the exercise title
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _setTimerDuration.inSeconds > 0 ? _formatDuration(_setTimerDuration) : _formatDuration(_stopwatch.elapsed),
              style: const TextStyle(
                  fontSize: 16), // Keep the font a little bigger
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.timer),
            onPressed: () =>  _showSetTimerDialog(localizations),
          ),
          IconButton(
            icon: const Icon(Icons.comment),
            onPressed: () => _showNotesDialog(localizations),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${localizations.cycle}: ${cycleWeekData['cycle']}'),
            Text('${localizations.week}: $week'),
            Text('TM2: $tm ${preferences.selectedUnit}'), // Show TM value
            // Session extras. Both switches persist with the rest of the
            // preferences: warmups globally, FSL per lift.
            Row(
              children: [
                Expanded(
                  child: _buildSessionToggle(
                    label: localizations.warmup,
                    value: warmupSetsEnabled,
                    onChanged: (bool value) => ref
                        .read(preferencesProvider.notifier)
                        .updateWarmupSetsEnabled(value),
                  ),
                ),
                Expanded(
                  child: _buildSessionToggle(
                    label: localizations.fsl,
                    value: fslEnabled,
                    onChanged: (bool value) => ref
                        .read(preferencesProvider.notifier)
                        .updateFslData(widget.exercise, value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  ExpansionTile(
                    // Rebuilt once, when the first-frame seed lands; see
                    // [_seedKey].
                    key: _seedKey('mainLift'),
                    initiallyExpanded: _mainLiftExpanded,
                    onExpansionChanged: (bool expanded) {
                      setState(() {
                        _mainLiftExpanded = expanded;
                      });
                    },
                    title: Text(localizations.mainLift),
                    children: [
                      // Warmups above the working sets, FSL below them, each
                      // with its own label so the three groups read apart.
                      if (plan.warmupSets.isNotEmpty) ...[
                        _buildGroupLabel(localizations.warmup),
                        _buildSetsTable(plan.warmupSets, _warmupIndexBase,
                            localizations, preferences.selectedUnit),
                      ],
                      _buildSetsTable(plan.mainSets, _mainIndexBase,
                          localizations, preferences.selectedUnit),
                      if (plan.fslSets.isNotEmpty) ...[
                        _buildGroupLabel(localizations.fsl),
                        _buildSetsTable(plan.fslSets, _fslIndexBase,
                            localizations, preferences.selectedUnit),
                      ],
                    ],
                  ),
                  _buildAccessorySection(localizations, workouts),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: _allSetsCompleted(plan) || _anyAccessorySetFilled()
                    ? () async {
                        // Capture the session cycle/week before _saveData
                        // advances them.
                        final int sessionCycle = cycleWeekData['cycle'] ?? 1;
                        final int sessionWeek = cycleWeekData['week'] ?? 1;
                        // A partial main lift was never savable before, so
                        // skipping it keeps every reachable path intact and
                        // avoids saving an empty main-lift row.
                        if (_allSetsCompleted(plan)) {
                          await _saveData(
                              week,
                              cycleWeekData['cycle'] ?? 1,
                              tm,
                              widget.exercise,
                              plan,
                              (workout) => ref
                                  .read(workoutProvider.notifier)
                                  .addWorkout(workout),
                              (exercise, cycle, week) => ref
                                  .read(preferencesProvider.notifier)
                                  .updateCycleAndWeek(exercise, cycle, week),
                              (exercise, tm) => ref
                                  .read(preferencesProvider.notifier)
                                  .updateTmData(exercise, tm));
                        }
                        await _saveAccessoryData(sessionCycle, sessionWeek);
                      }
                    : null,
                child: Text(localizations.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
