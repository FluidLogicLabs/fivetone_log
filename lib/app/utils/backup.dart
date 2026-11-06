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
///
/// It never throws. An adapter reading a field of the wrong type used to throw
/// out of here, which meant the function asked "is this a backup?" answered
/// with an exception, and the screen had nothing to say but the one message it
/// had. A field that cannot be read is now the same answer as a missing one.
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

  try {
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
                  AccessoryExerciseAdapter.fromMap(
                      Map<String, dynamic>.from(json)),
            ]
          : null,
    );
  } catch (_) {
    return null;
  }
}

/// Writes a backup through [FileUtils], which reports rather than throws.
Future<ExportResult> exportBackup(BackupData data, {String? dialogTitle}) {
  return FileUtils.exportData(backupToMap(data), dialogTitle: dialogTitle);
}

/// What reading a backup file produced: the data, or the reason there is none.
///
/// The reasons stay apart all the way to the screen. One catch-all message is
/// what used to report an export that wrote nothing as "not a valid backup".
class BackupImport {
  final ImportStatus status;
  final BackupData? data;

  const BackupImport(this.status, {this.data});
}

/// Reads a backup out of what the file reader produced.
///
/// This is the whole of the import decision, so a test can put a real file's
/// bytes through the exact chain the screen uses and see the same answer.
BackupImport readBackup(ImportResult read) {
  if (read.status != ImportStatus.decoded) {
    return BackupImport(read.status);
  }
  // A json object with preferences in it is a backup; anything else is not.
  final BackupData? data = backupFromMap(read.data);
  if (data == null) {
    return const BackupImport(ImportStatus.notBackup);
  }
  return BackupImport(ImportStatus.decoded, data: data);
}

/// Reads a backup from a file the user picks.
///
/// Never throws: a cancelled picker, an empty file, a file that is not json and
/// a json file that is not a backup each come back as their own [ImportStatus].
Future<BackupImport> pickBackup({String? dialogTitle}) async {
  return readBackup(await FileUtils.importData(dialogTitle: dialogTitle));
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
///
/// [FileUtils.exportData] reports every outcome instead of throwing, so there
/// is no catch here that could turn a failure into silence.
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

  final ExportResult result = await exportBackup(data);

  switch (result.status) {
    case ExportStatus.cancelled:
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.exportCancelled)),
      );
      return false;
    case ExportStatus.failed:
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.exportFailed)),
      );
      return false;
    case ExportStatus.written:
      // Downloads and a desktop dialog both report a path the file is really
      // at. Android and iOS report only a name, so the wording says the name
      // rather than pointing at a folder the file may not be in.
      final String message;
      if (result.location == ExportLocation.appFolder) {
        message =
            '${localizations.dataExportedToAppFolder} ${result.path ?? result.name}';
      } else if (result.path != null) {
        message = '${localizations.dataExportedSuccessfully} ${result.path}';
      } else {
        message = '${localizations.dataExportedAs} ${result.name}';
      }
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return true;
  }
}

/// Imports a backup into all three stores. True when something was imported,
/// which is what tells the entry screen to re-read its fields.
///
/// Each rejection says what is actually wrong with the file, so a file the app
/// wrote badly can never be reported as a file that is not a backup.
Future<bool> runImport(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations localizations,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

  final BackupImport read = await pickBackup();

  switch (read.status) {
    case ImportStatus.cancelled:
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.importCancelled)),
      );
      return false;
    case ImportStatus.empty:
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.importEmptyFile)),
      );
      return false;
    case ImportStatus.notJson:
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.importNotJson)),
      );
      return false;
    case ImportStatus.notBackup:
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.importFailed)),
      );
      return false;
    case ImportStatus.readFailed:
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.importUnreadable)),
      );
      return false;
    case ImportStatus.decoded:
      try {
        await applyBackup(ref, read.data!);
      } catch (_) {
        // The file was good; storing it was not. Saying "not a backup" here
        // would send the user looking for another file for nothing.
        messenger.showSnackBar(
          SnackBar(content: Text(localizations.importStoreFailed)),
        );
        return false;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.dataImportedSuccessfully)),
      );
      return true;
  }
}
