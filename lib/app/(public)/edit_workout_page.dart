import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fivethreeone_log/app/interactor/models/preferences_model.dart';
import 'package:fivethreeone_log/app/interactor/models/set_model.dart';
import 'package:fivethreeone_log/app/interactor/models/workout_model.dart';
import 'package:fivethreeone_log/app/interactor/providers/preferences_provider.dart';
import 'package:fivethreeone_log/app/interactor/providers/workout_provider.dart';
import 'package:fivethreeone_log/app/utils/saved_set_labels.dart';
import 'package:fivethreeone_log/app/utils/session_accessories.dart';
import 'package:fivethreeone_log/app/utils/session_plan.dart';
import 'package:fivethreeone_log/app/utils/training_defaults.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Edits a workout that has already been saved.
///
/// The rows come from the workout's own sets, in the order they were lifted,
/// not from the percentage table of the week it was saved in. That table only
/// ever holds the working sets, so a session with warmups and FSL used to show
/// three rows and leave the rest uneditable. The sets are grouped Warmup,
/// Working and FSL by matching their count and order against the session plan
/// for that lift and week (see [labelSavedSets]); a set count that matches no
/// plan is numbered plainly and stays editable.
///
/// Accessory work is stored as its own workouts (see
/// [accessoryWorkoutsForSession]) and is edited in a section of its own.
class EditWorkoutPage extends ConsumerStatefulWidget {
  final WorkoutModel workout;

  const EditWorkoutPage({super.key, required this.workout});

  @override
  ConsumerState<EditWorkoutPage> createState() => _EditWorkoutPageState();
}

class _EditWorkoutPageState extends ConsumerState<EditWorkoutPage> {
  final _formKey = GlobalKey<FormState>();
  late WorkoutModel _editableWorkout;
  late TextEditingController _notesController;

  // One controller per saved set of the workout being edited, in saved order.
  late List<TextEditingController> _repsControllers;
  late List<TextEditingController> _weightsControllers;

  // One entry per accessory workout of the same session, built the first time
  // it is seen because the workout provider loads after this page is created.
  final Map<String, _AccessoryEdit> _accessoryEdits = {};

  @override
  void initState() {
    super.initState();
    _editableWorkout = widget.workout.copyWith();
    _notesController = TextEditingController(text: _editableWorkout.notes);
    _repsControllers = _editableWorkout.sets
        .map((set) => TextEditingController(text: set.reps.toString()))
        .toList();
    _weightsControllers = _editableWorkout.sets
        .map((set) => TextEditingController(text: set.weight.toString()))
        .toList();
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final controller in _repsControllers) {
      controller.dispose();
    }
    for (final controller in _weightsControllers) {
      controller.dispose();
    }
    for (final edit in _accessoryEdits.values) {
      edit.dispose();
    }
    super.dispose();
  }

  // The session the workout was saved in: the plan for the workout's own week,
  // never the week the lifter happens to be in now.
  SessionPlan _sessionPlan(PreferencesModel preferences) {
    final int week = _editableWorkout.week;
    final double oneRM = preferences.rmData[_editableWorkout.exerciseName] ?? 0.0;
    final double trainingMax = preferences.tmData[_editableWorkout.exerciseName] ??
        deriveTrainingMax(oneRM, preferences.tmPercent);
    return buildSessionPlan(
      trainingMax: trainingMax,
      weekPercentages:
          preferences.percData['Semana $week']?.values.toList() ??
              const <double>[],
      mainReps: mainRepsForWeek(week),
      includeWarmups: preferences.warmupSetsEnabled,
      includeFsl: preferences.fslData[_editableWorkout.exerciseName] ?? false,
      roundingStep: sanitiseRoundingStep(preferences.roundingStep),
    );
  }

  SavedSetLabels _savedSetLabels(PreferencesModel preferences) {
    return labelSavedSets(
      savedCount: _editableWorkout.sets.length,
      plan: _sessionPlan(preferences),
    );
  }

  String? _groupTitle(SavedSetGroup group, AppLocalizations localizations) {
    switch (group) {
      case SavedSetGroup.warmup:
        return localizations.warmup;
      case SavedSetGroup.working:
        return localizations.workingSets;
      case SavedSetGroup.fsl:
        return localizations.fsl;
      case SavedSetGroup.unknown:
        return null;
      default:
        return null;
    }
  }

  // Contiguous runs of one group, so the page reads Warmup, Working, FSL rather
  // than repeating a group name on every row.
  List<_SetSection> _sections(
    SavedSetLabels labels,
    AppLocalizations localizations,
  ) {
    final List<_SetSection> sections = [];
    for (int i = 0; i < labels.length; i++) {
      final SavedSetGroup group = labels.groupAt(i);
      if (sections.isEmpty || sections.last.group != group) {
        sections.add(_SetSection(
          group: group,
          title: _groupTitle(group, localizations),
        ));
      }
      sections.last.indices.add(i);
    }
    return sections;
  }

  _AccessoryEdit _accessoryEditFor(WorkoutModel workout) {
    return _accessoryEdits.putIfAbsent(
      workout.id,
      () => _AccessoryEdit.fromWorkout(workout),
    );
  }

  void _showWeightDialog(
    TextEditingController controller,
    double currentWeight,
    AppLocalizations localizations,
  ) {
    final TextEditingController dialogController =
        TextEditingController(text: currentWeight.toString());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.enterWeight),
          content: TextField(
            controller: dialogController,
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
                  controller.text = double.tryParse(dialogController.text)
                          ?.toString() ??
                      currentWeight.toString();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _stepReps(TextEditingController controller, int delta) {
    final int current = int.tryParse(controller.text.trim()) ?? 0;
    final int next = current + delta;
    setState(() {
      controller.text = (next < 0 ? 0 : next).toString();
    });
  }

  void _stepWeight(TextEditingController controller, double delta) {
    final double current = double.tryParse(controller.text.trim()) ?? 0.0;
    final double next = current + delta;
    setState(() {
      controller.text = (next < 0 ? 0.0 : next).toString();
    });
  }

  Future<void> _saveWorkout() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final SavedSetLabels labels =
        _savedSetLabels(ref.read(preferencesProvider));

    final List<SetModel> updatedSets = List<SetModel>.generate(
      _editableWorkout.sets.length,
      (index) => SetModel(
        // Nothing reorders or deletes a set here, so the saved number stands.
        setNumber: _editableWorkout.sets[index].setNumber,
        reps: int.tryParse(_repsControllers[index].text) ?? 0,
        weight: double.tryParse(_weightsControllers[index].text) ?? 0.0,
      ),
    );

    final WorkoutModel updatedWorkout = _editableWorkout.copyWith(
      sets: updatedSets,
      numberOfSets: updatedSets.length,
      notes: _notesController.text,
      volume: totalVolumeOfSets(updatedSets),
      oneRM: recalculatedOneRM(
        updatedSets,
        labels,
        storedOneRM: _editableWorkout.oneRM,
      ),
    );

    final notifier = ref.read(workoutProvider.notifier);
    await notifier.updateWorkout(updatedWorkout);

    // Accessory rows are separate workouts, written back through the same
    // provider the session screen uses.
    for (final edit in _accessoryEdits.values) {
      await notifier.updateWorkout(edit.toWorkout());
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final preferences = ref.watch(preferencesProvider);
    final workouts = ref.watch(workoutProvider);
    final labels = _savedSetLabels(preferences);
    final accessoryWorkouts =
        accessoryWorkoutsForSession(widget.workout, workouts);
    final List<int> mainSetNumbers =
        _editableWorkout.sets.map((set) => set.setNumber).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.editWorkout),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveWorkout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    ExpansionTile(
                      title: Text(localizations.mainLift),
                      children: [
                        for (final section in _sections(labels, localizations)) ...[
                          if (section.title != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8.0, horizontal: 4.0),
                              child: Text(
                                section.title!,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          _buildSetTable(
                            indices: section.indices,
                            repsControllers: _repsControllers,
                            weightControllers: _weightsControllers,
                            setNumbers: mainSetNumbers,
                            unit: preferences.selectedUnit,
                            localizations: localizations,
                          ),
                        ],
                      ],
                    ),
                    for (final workout in accessoryWorkouts)
                      _buildAccessoryTile(
                        workout: workout,
                        unit: preferences.selectedUnit,
                        localizations: localizations,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(labelText: localizations.notes),
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _saveWorkout,
                  child: Text(localizations.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessoryTile({
    required WorkoutModel workout,
    required String unit,
    required AppLocalizations localizations,
  }) {
    final edit = _accessoryEditFor(workout);
    return ExpansionTile(
      title: Text(workout.exerciseName),
      subtitle: Text(localizations.accessory),
      children: [
        _buildSetTable(
          indices: List<int>.generate(edit.length, (i) => i),
          repsControllers: edit.reps,
          weightControllers: edit.weights,
          setNumbers: [
            for (int i = 0; i < edit.length; i++)
              i < workout.sets.length ? workout.sets[i].setNumber : i + 1,
          ],
          unit: unit,
          localizations: localizations,
        ),
      ],
    );
  }

  Widget _buildSetTable({
    required List<int> indices,
    required List<TextEditingController> repsControllers,
    required List<TextEditingController> weightControllers,
    required List<int> setNumbers,
    required String unit,
    required AppLocalizations localizations,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 10.0,
        columns: [
          DataColumn(
            numeric: false,
            tooltip: localizations.set,
            label: Center(child: Text(localizations.set)),
          ),
          DataColumn(
            numeric: false,
            tooltip: localizations.reps,
            label: Center(child: Text(localizations.reps)),
          ),
          DataColumn(
            numeric: false,
            tooltip: unit,
            label: Center(child: Text(unit)),
          ),
        ],
        rows: [
          for (final int index in indices)
            _buildSetRow(
              repsController: repsControllers[index],
              weightController: weightControllers[index],
              setNumber: index < setNumbers.length ? setNumbers[index] : index + 1,
              localizations: localizations,
            ),
        ],
      ),
    );
  }

  DataRow _buildSetRow({
    required TextEditingController repsController,
    required TextEditingController weightController,
    required int setNumber,
    required AppLocalizations localizations,
  }) {
    final int reps = int.tryParse(repsController.text.trim()) ?? 0;
    final double weight = double.tryParse(weightController.text.trim()) ?? 0.0;

    return DataRow(
      cells: [
        DataCell(Center(child: Text('$setNumber'))),
        DataCell(
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 16.0,
                icon: const Icon(Icons.remove),
                onPressed: () => _stepReps(repsController, -1),
              ),
              Text('$reps'),
              IconButton(
                iconSize: 16.0,
                icon: const Icon(Icons.add),
                onPressed: () => _stepReps(repsController, 1),
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
                  _showWeightDialog(weightController, weight, localizations);
                },
                child: IconButton(
                  iconSize: 16.0,
                  icon: const Icon(Icons.remove),
                  onPressed: () => _stepWeight(weightController, -1),
                ),
              ),
              GestureDetector(
                onLongPress: () {
                  _showWeightDialog(weightController, weight, localizations);
                },
                child: Text('$weight'),
              ),
              GestureDetector(
                onLongPress: () {
                  _showWeightDialog(weightController, weight, localizations);
                },
                child: IconButton(
                  iconSize: 16.0,
                  icon: const Icon(Icons.add),
                  onPressed: () => _stepWeight(weightController, 1),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One group of the session as it is shown on the page: the sets that share a
/// label, in saved order.
class _SetSection {
  final SavedSetGroup group;
  final String? title;
  final List<int> indices = [];

  _SetSection({required this.group, required this.title});
}

/// The editable rows of one accessory workout. Accessory sets live in their own
/// workout (one per exercise), so each gets its own controllers and is written
/// back as that workout.
class _AccessoryEdit {
  final WorkoutModel workout;
  final List<TextEditingController> reps;
  final List<TextEditingController> weights;

  _AccessoryEdit._(this.workout, this.reps, this.weights);

  factory _AccessoryEdit.fromWorkout(WorkoutModel workout) {
    return _AccessoryEdit._(
      workout,
      workout.sets
          .map((set) => TextEditingController(text: set.reps.toString()))
          .toList(),
      workout.sets
          .map((set) => TextEditingController(text: set.weight.toString()))
          .toList(),
    );
  }

  int get length => reps.length;

  int _repsAt(int index) {
    final int? parsed = int.tryParse(reps[index].text.trim());
    if (parsed != null && parsed >= 1) {
      return parsed;
    }
    // An accessory row is only ever written with at least one rep, so a cleared
    // field keeps what was stored instead of logging an empty set.
    return index < workout.sets.length ? workout.sets[index].reps : 1;
  }

  /// The workout with the edited rows in it. oneRM and volume are left alone:
  /// the session screen never computes them for accessory work either.
  WorkoutModel toWorkout() {
    final List<SetModel> sets = [
      for (int i = 0; i < reps.length; i++)
        SetModel(
          setNumber:
              i < workout.sets.length ? workout.sets[i].setNumber : i + 1,
          reps: _repsAt(i),
          weight: double.tryParse(weights[i].text.trim()) ??
              (i < workout.sets.length ? workout.sets[i].weight : 0.0),
        ),
    ];
    return workout.copyWith(sets: sets, numberOfSets: sets.length);
  }

  void dispose() {
    for (final controller in reps) {
      controller.dispose();
    }
    for (final controller in weights) {
      controller.dispose();
    }
  }
}
