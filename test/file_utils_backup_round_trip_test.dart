import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fivethreeone_log/app/interactor/models/accessory_exercise_model.dart';
import 'package:fivethreeone_log/app/interactor/models/preferences_model.dart';
import 'package:fivethreeone_log/app/interactor/models/set_model.dart';
import 'package:fivethreeone_log/app/interactor/models/workout_model.dart';
import 'package:fivethreeone_log/app/utils/backup.dart';
import 'package:fivethreeone_log/app/utils/file_utils.dart';

/// Everything a real backup carries, including the settings added since the
/// export was first written.
PreferencesModel _preferences() {
  return const PreferencesModel(
    selectedUnit: 'lb',
    rmData: {'Supino': 120.0, 'Agachamento': 150.5},
    percData: {
      'Semana 1': {'Série 1': 65.0, 'Série 2': 75.0, 'Série 3': 85.0},
      'Semana 3': {'Série 1': 70.0},
    },
    cycleWeekData: {
      'Supino': {'cycle': 2, 'week': 3},
      'Agachamento': {'cycle': 1, 'week': 1},
    },
    tmData: {'Supino': 108.0, 'Agachamento': 135.25},
    warmupSetsEnabled: false,
    fslData: {'Supino': true, 'Agachamento': false},
    roundingStep: 2.5,
    tmPercent: 92.5,
    cycleIncrement: {'Supino': 5.0, 'Agachamento': 10.0},
  );
}

WorkoutModel _workout({String id = '1', String exercise = 'Supino'}) {
  return WorkoutModel(
    id: id,
    date: DateTime(2026, 11, 5, 18, 30),
    exerciseName: exercise,
    numberOfSets: 2,
    sets: const [
      SetModel(setNumber: 1, reps: 5, weight: 90.0),
      SetModel(setNumber: 2, reps: 3, weight: 102.5),
    ],
    oneRM: 110,
    volume: 900,
    timeSpent: const Duration(minutes: 20),
    cycle: 2,
    week: 3,
  );
}

BackupData _backup() {
  return BackupData(
    workouts: [_workout(), _workout(id: '2', exercise: 'Agachamento')],
    preferences: _preferences(),
    accessoryExercises: const [
      AccessoryExerciseModel(name: 'Rosca direta', lastUsedLift: 'Supino'),
      AccessoryExerciseModel(name: 'Remada curvada'),
    ],
  );
}

/// The bytes an export writes: the same map, the same encoding.
Uint8List _exportedBytes(BackupData data) {
  return Uint8List.fromList(utf8.encode(jsonEncode(backupToMap(data))));
}

/// The bytes of a file the export actually wrote to disk.
Future<Uint8List> _bytesOnDisk(Directory folder, BackupData data) async {
  final ExportResult result = await FileUtils.writeToFolder(
    folder,
    FileUtils.defaultFileName,
    _exportedBytes(data),
  );
  expect(result.status, ExportStatus.written);
  expect(File(result.path!).existsSync(), isTrue);
  expect(File(result.path!).lengthSync(), greaterThan(0));
  return File(result.path!).readAsBytes();
}

void main() {
  late Directory folder;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('fivetlog_export_test');
  });

  tearDown(() async {
    if (folder.existsSync()) {
      await folder.delete(recursive: true);
    }
  });

  test('a file the export wrote holds the json and imports back whole', () async {
    final BackupData written = _backup();
    final Uint8List onDisk = await _bytesOnDisk(folder, written);

    final BackupImport read = readBackup(FileUtils.decodeImport(onDisk));

    expect(read.status, ImportStatus.decoded);
    final BackupData restored = read.data!;

    expect(restored.preferences, written.preferences);
    expect(restored.workouts, written.workouts);
    expect(restored.accessoryExercises, written.accessoryExercises);

    // Named individually as well, so a change that keeps both sides equally
    // wrong cannot pass unnoticed.
    expect(restored.preferences.selectedUnit, 'lb');
    expect(restored.preferences.rmData['Agachamento'], 150.5);
    expect(restored.preferences.tmData['Agachamento'], 135.25);
    expect(restored.preferences.percData['Semana 1']!['Série 3'], 85.0);
    expect(restored.preferences.cycleWeekData['Supino']!['week'], 3);
    expect(restored.preferences.warmupSetsEnabled, isFalse);
    expect(restored.preferences.fslData['Supino'], isTrue);
    expect(restored.preferences.roundingStep, 2.5);
    expect(restored.preferences.tmPercent, 92.5);
    expect(restored.preferences.cycleIncrement['Agachamento'], 10.0);

    expect(restored.workouts!.length, 2);
    expect(restored.workouts!.last.exerciseName, 'Agachamento');
    expect(restored.workouts!.first.sets.length, 2);
    expect(restored.workouts!.first.sets.last.weight, 102.5);
    expect(restored.accessoryExercises!.first.name, 'Rosca direta');
    expect(restored.accessoryExercises!.last.lastUsedLift, isNull);
  });

  test('an empty file is an empty file, not a bad backup', () {
    expect(FileUtils.decodeImport(Uint8List(0)).status, ImportStatus.empty);
    expect(readBackup(FileUtils.decodeImport(Uint8List(0))).status,
        ImportStatus.empty);
  });

  test('a file of whitespace is empty too', () {
    final Uint8List bytes = Uint8List.fromList(utf8.encode('  \n\t '));
    expect(FileUtils.decodeImport(bytes).status, ImportStatus.empty);
  });

  test('a file that is not json says so', () {
    final Uint8List bytes = Uint8List.fromList(utf8.encode('not json at all'));
    expect(FileUtils.decodeImport(bytes).status, ImportStatus.notJson);
    expect(readBackup(FileUtils.decodeImport(bytes)).status,
        ImportStatus.notJson);
  });

  test('bytes that are not utf8 say the file is not json', () {
    final Uint8List bytes = Uint8List.fromList([0xC3, 0x28, 0x00, 0xFF]);
    expect(FileUtils.decodeImport(bytes).status, ImportStatus.notJson);
  });

  test('json that is not a backup is rejected as not a backup', () {
    final Uint8List bytes =
        Uint8List.fromList(utf8.encode('{"hello":"world"}'));
    expect(FileUtils.decodeImport(bytes).status, ImportStatus.decoded);
    expect(readBackup(FileUtils.decodeImport(bytes)).status,
        ImportStatus.notBackup);
  });

  test('a json list is json, but not a backup', () {
    final Uint8List bytes = Uint8List.fromList(utf8.encode('[1, 2, 3]'));
    expect(FileUtils.decodeImport(bytes).status, ImportStatus.notBackup);
    expect(readBackup(FileUtils.decodeImport(bytes)).status,
        ImportStatus.notBackup);
  });

  test('a backup written with a byte order mark still reads', () {
    final Uint8List plain = _exportedBytes(_backup());
    final Uint8List withBom = Uint8List.fromList(
      [0xEF, 0xBB, 0xBF, ...plain],
    );

    final BackupImport read = readBackup(FileUtils.decodeImport(withBom));

    expect(read.status, ImportStatus.decoded);
    expect(read.data!.preferences, _preferences());
  });

  test('a backup shaped file with an unreadable field is not a backup', () {
    // The right keys, one value of the wrong type. backupFromMap used to throw
    // out of the adapter here instead of answering the question it is named
    // for.
    final Uint8List bytes = Uint8List.fromList(utf8.encode(
      '{"preferences":{"selectedUnit":42,"fslData":{"Supino":"yes"}},'
      '"workouts":[]}',
    ));

    final ImportResult decoded = FileUtils.decodeImport(bytes);
    expect(decoded.status, ImportStatus.decoded);
    expect(readBackup(decoded).status, ImportStatus.notBackup);
  });

  test('a write that cannot happen is reported, never thrown', () async {
    // A file where the directory should be, so the write cannot land.
    final File blocker = File('${folder.path}${Platform.pathSeparator}blocker');
    await blocker.writeAsString('x');

    final ExportResult result = await FileUtils.writeToFolder(
      Directory(blocker.path),
      FileUtils.defaultFileName,
      _exportedBytes(_backup()),
    );

    expect(result.status, ExportStatus.failed);
    expect(result.path, isNull);
  });
}
