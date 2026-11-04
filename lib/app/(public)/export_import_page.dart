import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fivethreeone_log/app/interactor/providers/workout_provider.dart';
import 'package:fivethreeone_log/app/interactor/providers/accessory_exercise_provider.dart'; // Accessory exercise catalogue
import 'package:fivethreeone_log/app/interactor/providers/preferences_provider.dart';
import 'package:fivethreeone_log/app/utils/file_utils.dart'; // Import utility functions for file operations
import 'package:fivethreeone_log/app/data/adapters/workout_adapter.dart'; // Import WorkoutAdapter
import 'package:fivethreeone_log/app/data/adapters/accessory_exercise_adapter.dart'; // Import AccessoryExerciseAdapter
import 'package:fivethreeone_log/app/data/adapters/preferences_adapter.dart'; // Import PreferencesAdapter
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import localization

class ExportImportPage extends ConsumerWidget {
  const ExportImportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = ref.watch(workoutProvider);
    final preferences = ref.watch(preferencesProvider);
    final accessoryExercises = ref.watch(accessoryExercisesProvider); // Accessory exercise catalogue
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.exportImportData),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final data = {
                    'workouts': workouts.map((w) => WorkoutAdapter.toMap(w)).toList(),
                    'preferences': PreferencesAdapter.toMap(preferences),
                    'accessoryExercises': accessoryExercises.map((e) => AccessoryExerciseAdapter.toMap(e)).toList(), // New field
                  };
                  final filePath = await FileUtils.exportData(data);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${localizations.dataExportedSuccessfully} $filePath')),
                  );
                },
                child: Text(localizations.exportData),
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () async {
                  final data = await FileUtils.importData();
                  if (data != null) {
                    final workoutNotifier = ref.read(workoutProvider.notifier);
                    final preferencesNotifier = ref.read(preferencesProvider.notifier);
          
                    final importedWorkouts = (data['workouts'] as List)
                        .map((json) => WorkoutAdapter.fromMap(json))
                        .toList();
                    final importedPreferences = PreferencesAdapter.fromMap(data['preferences']);
          
                    await workoutNotifier.setImportedWorkouts(importedWorkouts);
                    await preferencesNotifier.setImportedPreferences(importedPreferences);

                    // Old export files have no catalogue: keep them importable.
                    if (data['accessoryExercises'] != null) {
                      final importedAccessoryExercises = (data['accessoryExercises'] as List)
                          .map((json) => AccessoryExerciseAdapter.fromMap(json))
                          .toList();
                      await ref
                          .read(accessoryExercisesProvider.notifier)
                          .setImportedExercises(importedAccessoryExercises);
                    }
          
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(localizations.dataImportedSuccessfully)),
                    );
                  }
                },
                child: Text(localizations.importData),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
