import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:routefly/routefly.dart';
import 'package:fivethreeone_log/app/interactor/models/preferences_model.dart';
import 'package:fivethreeone_log/app/interactor/providers/preferences_provider.dart';
import 'package:fivethreeone_log/app/widgets/default_option_button.dart';
import 'package:fivethreeone_log/app/utils/backup.dart'; // Shared export and import
import 'package:fivethreeone_log/app/utils/training_defaults.dart'; // Rounding step and training max percentage
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import localization

class InitialForm extends ConsumerStatefulWidget {
  const InitialForm({super.key});

  @override
  InitialFormState createState() => InitialFormState();
}

class InitialFormState extends ConsumerState<InitialForm> {
  final _formKey = GlobalKey<FormState>();
  String selectedUnit = 'Kg'; // Valor selecionado inicialmente
  final List<String> weightUnits = ['lbs', 'Kg'];
  final Map<String, Map<String, double>> _rmData = {
    'Agachamento': {'peso': 0, 'repeticoes': 0},
    'Levantamento terra': {'peso': 0, 'repeticoes': 0},
    'Supino': {'peso': 0, 'repeticoes': 0},
    'Press militar': {'peso': 0, 'repeticoes': 0},
  };
  final Map<String, Map<String, double>> _percData = {
    'Semana 1': {
      'Série 1': 65,
      'Série 2': 75,
      'Série 3': 85,
    },
    'Semana 2': {
      'Série 1': 70,
      'Série 2': 80,
      'Série 3': 90,
    },
    'Semana 3': {
      'Série 1': 75,
      'Série 2': 85,
      'Série 3': 95,
    },
    'Semana 4': {
      'Série 1': 40,
      'Série 2': 50,
      'Série 3': 60,
    },
  };

  // The two settings that decide how every derived weight reads. They are
  // seeded from what is stored so reopening the screen never invents a value.
  late final TextEditingController _tmPercentController;
  late final TextEditingController _roundingStepController;

  // One field per lift for how much its training max climbs after a cycle.
  late final Map<String, TextEditingController> _incrementControllers;

  // Bumped every time the fields are re-seeded. The text fields carry it in
  // their keys, because a TextFormField keeps the text it was born with and
  // would otherwise ignore a new initial value after an import.
  int _seedGeneration = 0;

  @override
  void initState() {
    super.initState();
    final preferences = ref.read(preferencesProvider);
    _tmPercentController =
        TextEditingController(text: formatTmPercent(preferences.tmPercent));
    _roundingStepController = TextEditingController(
        text: formatRoundingStep(preferences.roundingStep));
    _incrementControllers = {
      for (final exercise in _rmData.keys)
        exercise: TextEditingController(
          text: _formatFieldNumber(
              cycleIncrementFor(exercise, preferences.cycleIncrement)),
        ),
    };
    // Nothing is typed yet, so every field starts on what is stored. On a
    // first run nothing is stored and the zeros stay.
    _applyStoredPreferences();
  }

  // Copies the stored training data into the fields. Runs once on open and
  // again after an import, so the screen always shows what the app is about to
  // use rather than a factory table. Cycle and week are stored in preferences
  // and are never read or written here.
  void _applyStoredPreferences() {
    final preferences = ref.read(preferencesProvider);

    final String storedUnit = preferences.selectedUnit.toLowerCase();
    if (storedUnit.isNotEmpty) {
      selectedUnit = weightUnits.firstWhere(
        (unit) => unit.toLowerCase() == storedUnit,
        orElse: () => selectedUnit,
      );
    }

    // A stored 1RM is shown as a single rep, which is the only reading of the
    // two fields that reproduces it exactly.
    for (final exercise in _rmData.keys) {
      final double? storedOneRM = preferences.rmData[exercise];
      _rmData[exercise]!['peso'] = storedOneRM ?? 0;
      _rmData[exercise]!['repeticoes'] = storedOneRM == null ? 0 : 1;
    }

    // Stored percentages win over the defaults, so reopening the screen cannot
    // quietly put the table back to the factory values.
    for (final week in _percData.keys) {
      final Map<String, double>? storedWeek = preferences.percData[week];
      if (storedWeek == null) {
        continue;
      }
      for (final exerciseSet in _percData[week]!.keys) {
        final double? stored = storedWeek[exerciseSet];
        if (stored != null) {
          _percData[week]![exerciseSet] = stored;
        }
      }
    }

    _tmPercentController.text = formatTmPercent(preferences.tmPercent);
    _roundingStepController.text = formatRoundingStep(preferences.roundingStep);
    for (final exercise in _incrementControllers.keys) {
      _incrementControllers[exercise]!.text = _formatFieldNumber(
          cycleIncrementFor(exercise, preferences.cycleIncrement));
    }
    _seedGeneration++;
  }

  // A number as it belongs in a text field: no trailing decimal on a whole
  // number, and nothing else changed.
  String _formatFieldNumber(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  // What a 1RM field starts on: empty when nothing is stored, the stored
  // number otherwise.
  String _fieldValue(String exercise, String field) {
    final double value = _rmData[exercise]![field]!;
    return value == 0 ? '' : _formatFieldNumber(value);
  }

  // The two backup actions live on this screen as well as the export page.
  // An import replaces everything, so the fields are re-read from the store
  // afterwards and show the file's data instead of the stale form state.
  Future<void> _importBackup(AppLocalizations localizations) async {
    final bool imported = await runImport(context, ref, localizations);
    if (!imported || !mounted) {
      return;
    }
    setState(_applyStoredPreferences);
  }

  // What is stored for one lift right now, shown above its fields so an old
  // number is never mistaken for a fresh one. It states cycle and week because
  // those are the two things a re-entry does not touch.
  String _storedSummary(
    String exercise,
    PreferencesModel preferences,
    AppLocalizations localizations,
  ) {
    final double? storedOneRM = preferences.rmData[exercise];
    final double? storedTrainingMax = preferences.tmData[exercise] ??
        (storedOneRM == null
            ? null
            : deriveTrainingMax(storedOneRM, preferences.tmPercent));
    final Map<String, int>? cycleWeek = preferences.cycleWeekData[exercise];

    final List<String> parts = [
      localizations.current,
      if (storedOneRM != null)
        '${localizations.oneRM} ${_formatFieldNumber(storedOneRM)}',
      if (storedTrainingMax != null)
        '${localizations.trainingMax} ${_formatFieldNumber(storedTrainingMax)}',
      if (cycleWeek != null) '${localizations.cycle} ${cycleWeek['cycle'] ?? 1}',
      if (cycleWeek != null) '${localizations.week} ${cycleWeek['week'] ?? 1}',
    ];
    return parts.join(' · ');
  }

  // Rebuilds the 1RM and the training max from what is typed in the fields.
  // Cycle and week are left alone: the training max goes back to the configured
  // percentage, but the block does not move. Lifts with no weight typed are
  // skipped rather than zeroed.
  Future<void> _recalculate(
    Iterable<String> exercises,
    AppLocalizations localizations,
  ) async {
    final preferences = ref.read(preferencesProvider);
    final Map<String, double> rmData = <String, double>{};
    final Map<String, double> tmData = <String, double>{};

    for (final exercise in exercises) {
      final RecalculatedMax? recalculated = recalculateMax(
        weight: _rmData[exercise]!['peso']!,
        reps: _rmData[exercise]!['repeticoes']!.toInt(),
        tmPercent: preferences.tmPercent,
      );
      if (recalculated == null) {
        continue;
      }
      rmData[exercise] = recalculated.oneRM;
      tmData[exercise] = recalculated.trainingMax;
    }

    if (rmData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.checkInputData)),
      );
      return;
    }

    await ref.read(preferencesProvider.notifier).updateRmAndTm(rmData, tmData);

    if (!mounted) {
      return;
    }
    setState(_applyStoredPreferences);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.recalculated)),
    );
  }

  // Recalculating every lift throws away every cycle increment at once, so it
  // asks first and says what happens to the block before doing it.
  Future<void> _recalculateAll(AppLocalizations localizations) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.recalculateAll),
        content: Text(localizations.recalculateExplained),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.recalculateAll),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _recalculate(_rmData.keys, localizations);
  }

  @override
  void dispose() {
    _tmPercentController.dispose();
    _roundingStepController.dispose();
    for (final controller in _incrementControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // A typed number, with a comma accepted because a numeric keyboard on a
  // Brazilian device offers one.
  double? _typedNumber(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  Future<void> _saveSettings(AppLocalizations localizations) async {
    final notifier = ref.read(preferencesProvider.notifier);
    final current = notifier.getPreferences();
    final double typedStep =
        _typedNumber(_roundingStepController.text) ?? current.roundingStep;
    final double typedPercent =
        _typedNumber(_tmPercentController.text) ?? current.tmPercent;

    await notifier.updateRoundingStep(typedStep);

    // Each increment is written as typed. A field holding nonsense leaves the
    // stored increment alone rather than being replaced by a guess.
    for (final exercise in _incrementControllers.keys) {
      final double? typedIncrement =
          _typedNumber(_incrementControllers[exercise]!.text);
      if (typedIncrement == null || typedIncrement <= 0) {
        continue;
      }
      await notifier.updateCycleIncrement(exercise, typedIncrement);
    }

    final TrainingMaxRecalculation plan =
        await notifier.updateTmPercent(typedPercent);

    if (!mounted) {
      return;
    }
    // Show what was actually stored, which is not what was typed when the
    // value was out of range and had to fall back.
    final saved = ref.read(preferencesProvider);
    setState(() {
      _roundingStepController.text = formatRoundingStep(saved.roundingStep);
      _tmPercentController.text = formatTmPercent(saved.tmPercent);
      // Written back from the store, so a refused increment does not sit in
      // the field pretending it was saved.
      for (final exercise in _incrementControllers.keys) {
        _incrementControllers[exercise]!.text = _formatFieldNumber(
            cycleIncrementFor(exercise, saved.cycleIncrement));
      }
    });
    final String keptNote = plan.kept.isEmpty
        ? ''
        : ' · ${localizations.tmLeftAlone}: '
            '${plan.kept.map((exercise) => getExerciseName(exercise, localizations)).join(', ')}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${localizations.settingsSaved}$keptNote')),
    );
  }

  String getWeekName(String week, AppLocalizations localizations) {
    switch (week) {
      case 'Semana 1':
        return localizations.week1;
      case 'Semana 2':
        return localizations.week2;
      case 'Semana 3':
        return localizations.week3;
      case 'Semana 4':
        return localizations.week4;
      default:
        return week;
    }
  }

  String getRepsName(String reps, AppLocalizations localizations) {
    switch (reps) {
      case 'Série 1':
        return localizations.set1;
      case 'Série 2':
        return localizations.set2;
      case 'Série 3':
        return localizations.set3;
      default:
        return reps;
    }
  }

  String getExerciseName(String exercise, AppLocalizations localizations) {
    switch (exercise) {
      case 'Agachamento':
        return localizations.squat;
      case 'Levantamento terra':
        return localizations.deadLift;
      case 'Supino':
        return localizations.bench;
      case 'Press militar':
        return localizations.militaryPress;
      default:
        return exercise; 
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    // Watched, not read: the stored summary has to follow a recalculation or an
    // import the moment it lands.
    final preferences = ref.watch(preferencesProvider);

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
        child: Column(
          children: [
            DefaultOptionButton(
              labelText: localizations.unitOfMeasure, // Localized text
              selectedValue: selectedUnit,
              options: weightUnits,
              onChanged: (value) {
                setState(() {
                  selectedUnit = value;
                });
                // Você pode adicionar aqui lógica para salvar a seleção
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => runExport(context, ref, localizations),
                    icon: const Icon(Icons.upload_file),
                    label: Text(localizations.exportData),
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _importBackup(localizations),
                    icon: const Icon(Icons.download),
                    label: Text(localizations.importData),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              maintainState: true,
              title: Text(localizations.enter1RM), // Localized text
              children: [
                for (var exercise in _rmData.keys)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            getExerciseName(exercise, localizations),
                          ),
                        ),
                        if (preferences.rmData[exercise] != null) ...[
                          const SizedBox(height: 2.0),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _storedSummary(exercise, preferences, localizations),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10.0),
                        Center(
                          child: Row(
                            children: [
                              Expanded(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: TextFormField(
                                      key: ValueKey<String>(
                                          'rm-weight-$exercise-$_seedGeneration'),
                                      initialValue:
                                          _fieldValue(exercise, 'peso'),
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText:
                                            '${localizations.weight} ($selectedUnit)', // Dynamic unit
                                        border: const OutlineInputBorder(),
                                      ),
                                      inputFormatters: [
                                        LengthLimitingTextInputFormatter(5),
                                      ],
                                      validator: (value) => value!.isEmpty
                                          ? localizations.insertValue
                                          : null,
                                      onChanged: (value) {
                                        setState(() {
                                          _rmData[exercise]!['peso'] =
                                              double.tryParse(value) ?? 0;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: TextFormField(
                                      key: ValueKey<String>(
                                          'rm-reps-$exercise-$_seedGeneration'),
                                      initialValue:
                                          _fieldValue(exercise, 'repeticoes'),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        LengthLimitingTextInputFormatter(2),
                                      ],
                                      validator: (value) => value!.isEmpty
                                          ? localizations.insertValue
                                          : null,
                                      decoration: InputDecoration(
                                        labelText: localizations.reps,
                                        border: const OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          _rmData[exercise]!['repeticoes'] =
                                              double.tryParse(value) ?? 0;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                  child: Center(
                                child: Text(
                                  _rmData[exercise]!['repeticoes']! == 0
                                      ? '1RM: 0.00'
                                      : '1RM: ${oneRMFromEntry(_rmData[exercise]!['peso']!, _rmData[exercise]!['repeticoes']!.toInt()).toStringAsFixed(2)}',
                                ),
                              )),
                              // One lift at a time: no confirmation, because
                              // the text above the fields already says what a
                              // recalculation does.
                              IconButton(
                                tooltip: localizations.recalculate,
                                icon: const Icon(Icons.refresh),
                                onPressed: () =>
                                    _recalculate([exercise], localizations),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    localizations.recalculateExplained,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _recalculateAll(localizations),
                      icon: const Icon(Icons.refresh),
                      label: Text(localizations.recalculateAll),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              maintainState: true,
              title: Text(localizations.adjustPercentages), // Localized text
              children: [
                for (var week in _percData.keys)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Center(
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              getWeekName(week, localizations),
                            ),
                          ),
                          const SizedBox(height: 10.0),
                          Center(
                            child: Row(
                              children: [
                                for (var exerciceSet in _percData[week]!.keys)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0),
                                      child: TextFormField(
                                        key: ValueKey<String>(
                                            'perc-$week-$exerciceSet-$_seedGeneration'),
                                        keyboardType: TextInputType.number,
                                        initialValue:
                                            _percData[week]![exerciceSet]
                                                .toString(),
                                        decoration: InputDecoration(
                                          labelText:
                                              getRepsName(exerciceSet, localizations), // Dynamic unit
                                          border: const OutlineInputBorder(),
                                          suffix: const Text(
                                            '%',
                                          ),
                                        ),
                                        inputFormatters: [
                                          LengthLimitingTextInputFormatter(3),
                                        ],
                                        onChanged: (value) {
                                          setState(() {
                                            _percData[week]![exerciceSet] =
                                                double.tryParse(value) ?? 0;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8.0),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              maintainState: true,
              title: Text(localizations.trainingSettings),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: TextFormField(
                            controller: _tmPercentController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(5),
                            ],
                            decoration: InputDecoration(
                              labelText: localizations.trainingMaxPercentage,
                              border: const OutlineInputBorder(),
                              suffix: const Text('%'),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: TextFormField(
                            controller: _roundingStepController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(5),
                            ],
                            decoration: InputDecoration(
                              labelText: localizations.roundingStep,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    localizations.trainingMaxExplained,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                for (final exercise in _rmData.keys)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 4.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(getExerciseName(exercise, localizations)),
                        ),
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            key: ValueKey<String>(
                                'increment-$exercise-$_seedGeneration'),
                            controller: _incrementControllers[exercise],
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(5),
                            ],
                            decoration: InputDecoration(
                              labelText: localizations.cycleIncrement,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    localizations.cycleIncrementExplained,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _saveSettings(localizations),
                      child: Text(localizations.saveSettings),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onPressed: () async {
                    // Validate returns true if the form is valid, or false otherwise.
                    if (_formKey.currentState!.validate()) {
                      // If the form is valid, display a snackbar. In the real world,
                      final Map<String, double> rmData = {
                        for (var exercise in _rmData.keys)
                          exercise: oneRMFromEntry(
                              _rmData[exercise]!['peso']!,
                              _rmData[exercise]!['repeticoes']!.toInt())
                      };
                      // The training max comes from the stored percentage,
                      // never from a number written into this screen.
                      final double tmPercent =
                          ref.read(preferencesProvider).tmPercent;
                      final Map<String, double> tmData = {
                        for (var exercise in _rmData.keys)
                          exercise: deriveTrainingMax(
                              oneRMFromEntry(
                                  _rmData[exercise]!['peso']!,
                                  _rmData[exercise]!['repeticoes']!.toInt()),
                              tmPercent)
                      };
                      // A cycle and a week already in progress stay where they
                      // are. Only a lift that has never had them starts at one.
                      final Map<String, Map<String, int>> cycleWeekData =
                          cycleWeekPreserving(
                              preferences.cycleWeekData, _rmData.keys);
                      // Built from the stored preferences rather than a fresh
                      // model, so the rounding step, the training max
                      // percentage, the increments and the warmup choices are
                      // not quietly reset by saving this screen.
                      await ref
                          .read(preferencesProvider.notifier)
                          .setPreferences(
                            preferences.copyWith(
                              selectedUnit: selectedUnit,
                              rmData: rmData,
                              tmData: tmData,
                              percData: _percData,
                              cycleWeekData: cycleWeekData,
                            ),
                          );
                      // Redirect to home page using Routefly
                      Routefly.navigate('/home');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(localizations.checkInputData)), // Localized text
                      );
                    }
                  },
                  child: Text(localizations.generateWorkout), // Localized text
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
