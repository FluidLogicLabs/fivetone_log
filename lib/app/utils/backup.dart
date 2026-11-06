import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:fivethreeone_log/app/data/adapters/accessory_exercise_adapter.dart';
import 'package:fivethreeone_log/app/data/adapters/preferences_adapter.dart';
import 'package:fivethreeone_log/app/data/adapters/workout_adapter.dart';
import 'package:fivethreeone_log/app/interactor/models/accessory_exercise_model.dart';
import 'package:fivethreeone_log/app/interactor/models/preferences_model.dart';
import 'package:fivethreeone_log/app/interactor/models/workout_model.dart';
import 'package:fivethreeone_log/app/interactor/providers/accessory_exercise_provider.dart';
import 'package:fivethreeone_log/app/interactor/providers/preferences_provider.dart';
import 'package:fivethreeone_log/app/interactor/providers/workout_provider.dart';
import 'package:fivethreeone_log/app/utils/file_utils.dart';

/// Everything a backup file carries.
///
/// [workouts] and [accessoryExercises] are nullable on purpose: a file written
/// before the accessory catalogue existed has no catalogue in it, and a null
/// here means "this file says nothing about it", which is not the same as
/// "this file says there are none". Importing leaves the store alone in that
/// case instead of emptying it.
class BackupData {
  final List<WorkoutModel>? workouts;
  final PreferencesModel preferences;
  final List<AccessoryExerciseModel>? accessoryExercises;

  const BackupData({
    required this.workouts,
    required this.preferences,
    required this.accessoryExercises,
  });
}

/// The one serialisation of a backup: the same three adapters, the same three
/// keys, in the same order the export page has always written them. Both
/// screens go through here so the file format cannot fork.
Map<String, dynamic> backupToMap(BackupData data) {
  return {
    'workouts': [
      for (final workout in data.workouts ?? const <WorkoutModel>[])
        WorkoutAdapter.toMap(workout),
    ],
    'preferences': PreferencesAdapter.toMap(data.preferences),
    'accessoryExercises': [
      for (final exercise in data.accessoryExercises ??
          const <AccessoryExerciseModel>[])
        AccessoryExerciseAdapter.toMap(exercise),
    ],
  };
}

/// Reads a decoded backup file back into models. Null means the file is not a
/// backup at all: there are no preferences in it, so there is nothing to
/// import.
BackupData? backupFromMap(Map<String, dynamic>? map) {
  if (map == null) {
    return null;
  }
  final dynamic preferences = map['preferences'];
  if (preferences is! Map) {
    return null;
  }

  final dynamic workouts = map['workouts'];
  final dynamic accessories = map['accessoryExercises'];

  return BackupData(
    workouts: workouts is List
        ? [
            for (final json in workouts)
              if (json is Map)
                WorkoutAdapter.fromMap(Map<String, dynamic>.from(json)),
          ]
        : null,
    preferences:
        PreferencesAdapter.fromMap(Map<String, dynamic>.from(preferences)),
    accessoryExercises: accessories is List
        ? [
            for (final json in accessories)
              if (json is Map)
                AccessoryExerciseAdapter.fromMap(Map<String, dynamic>.from(json)),
          ]
        : null,
  );
}

/// Writes a backup through [FileUtils]. Null means cancelled.
Future<ExportResult?> exportBackup(BackupData data, {String? dialogTitle}) {
  return FileUtils.exportData(backupToMap(data), dialogTitle: dialogTitle);
}

/// Reads a backup from a file the user picks. Null means cancelled, and a
/// malformed file throws, exactly as [FileUtils.importData] reports it.
Future<BackupData?> pickBackup({String? dialogTitle}) async {
  return backupFromMap(await FileUtils.importData(dialogTitle: dialogTitle));
}

/// Writes an imported backup into the three stores. A store the file said
/// nothing about is left exactly as it is.
Future<void> applyBackup(WidgetRef ref, BackupData data) async {
  final List<WorkoutModel>? workouts = data.workouts;
  if (workouts != null) {
    await ref.read(workoutProvider.notifier).setImportedWorkouts(workouts);
  }
  await ref
      .read(preferencesProvider.notifier)
      .setImportedPreferences(data.preferences);
  final List<AccessoryExerciseModel>? accessories = data.accessoryExercises;
  if (accessories != null) {
    await ref
        .read(accessoryExercisesProvider.notifier)
        .setImportedExercises(accessories);
  }
}

/// Exports the three stores and reports the outcome, so the entry screen and
/// the export page cannot word the same result differently. True when a file
/// was written.
Future<bool> runExport(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations localizations,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final BackupData data = BackupData(
    workouts: ref.read(workoutProvider),
    preferences: ref.read(preferencesProvider),
    accessoryExercises: ref.read(accessoryExercisesProvider),
  );

  try {
    final ExportResult? result = await exportBackup(data);
    if (result == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.exportCancelled)),
      );
      return false;
    }
    // The picker puts the file wherever the user pointed it, so only a file
    // the app wrote itself needs the "not in Downloads" wording.
    final String message = result.usedPicker || result.inDownloads
        ? '${localizations.dataExportedSuccessfully} ${result.path}'
        : '${localizations.dataExportedToAppFolder} ${result.path}';
    messenger.showSnackBar(SnackBar(content: Text(message)));
    return true;
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(localizations.exportFailed)),
    );
    return false;
  }
}

/// Imports a backup into all three stores. True when something was imported,
/// which is what tells the entry screen to re-read its fields.
Future<bool> runImport(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations localizations,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

  try {
    final BackupData? data = await pickBackup();
    if (data == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.importCancelled)),
      );
      return false;
    }
    await applyBackup(ref, data);
    messenger.showSnackBar(
      SnackBar(content: Text(localizations.dataImportedSuccessfully)),
    );
    return true;
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(localizations.importFailed)),
    );
    return false;
  }
}
