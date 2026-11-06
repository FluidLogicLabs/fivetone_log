import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Where an export actually landed, so a screen can say something true about
/// it rather than assuming the folder it asked for.
class ExportResult {
  /// Full path of the file that was written.
  final String path;

  /// True when the file sits in the platform's Downloads directory.
  final bool inDownloads;

  /// True when the user chose the location in the system picker, false when
  /// the file was written into a folder the app owns.
  final bool usedPicker;

  const ExportResult({
    required this.path,
    required this.inDownloads,
    required this.usedPicker,
  });
}

class FileUtils {
  /// The name the app gives its own backups, so re-exporting never leaves a
  /// trail of differently named files.
  static const String defaultFileName = 'fivetlog-backup.json';

  /// The platform's Downloads directory, or null where there is not one.
  ///
  /// Android and iOS do not expose it, and path_provider signals that either
  /// by returning null or by throwing, so both are handled here. Neither is an
  /// error: the caller falls back to a folder the app can always write to.
  static Future<Directory?> downloadsDirectory() async {
    try {
      return await getDownloadsDirectory();
    } catch (_) {
      return null;
    }
  }

  /// Writes [data] as json and returns where it went, or null when the user
  /// backed out of the picker.
  ///
  /// The picker opens in Downloads where the platform has one. A picker that
  /// is missing, refuses to open, or hands back a location that cannot be
  /// written to falls through to a plain write in Downloads when it exists and
  /// in the app's documents folder when it does not, so the file is never lost
  /// and nothing throws its way up to the screen.
  static Future<ExportResult?> exportData(
    Map<String, dynamic> data, {
    String? dialogTitle,
    String fileName = defaultFileName,
  }) async {
    final String jsonData = jsonEncode(data);
    final Directory? downloads = await downloadsDirectory();

    String? pickedPath;
    bool pickerUsable = true;
    try {
      pickedPath = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: fileName,
        initialDirectory: downloads?.path,
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
    } catch (_) {
      pickerUsable = false;
    }

    if (pickerUsable) {
      if (pickedPath == null) {
        // A usable picker that returned nothing means the user cancelled, and
        // writing anyway would be doing something they just said no to.
        return null;
      }
      try {
        await File(pickedPath).writeAsString(jsonData);
        return ExportResult(
          path: pickedPath,
          inDownloads: downloads != null && _isInside(pickedPath, downloads.path),
          usedPicker: true,
        );
      } catch (_) {
        // Some platforms hand back a location that cannot be written straight
        // to. Fall through and write where the app certainly can.
      }
    }

    final Directory target =
        downloads ?? await getApplicationDocumentsDirectory();
    final File file = File('${target.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(jsonData);
    return ExportResult(
      path: file.path,
      inDownloads: downloads != null,
      usedPicker: false,
    );
  }

  /// Lets the user pick a json file and returns what was in it, or null when
  /// they backed out. A file that is not json is reported as a
  /// [FormatException], so an unreadable file and a cancelled picker do not
  /// look the same to the screen that called this.
  static Future<Map<String, dynamic>?> importData({String? dialogTitle}) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );

    final String? path = result?.files.single.path;
    if (path == null) {
      return null;
    }

    final String jsonData = await File(path).readAsString();
    final dynamic decoded = jsonDecode(jsonData);
    if (decoded is! Map) {
      throw const FormatException('The file does not hold a json object.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  /// True when [path] sits in [directory], used to tell the user whether their
  /// file is in Downloads or somewhere else.
  static bool _isInside(String path, String directory) {
    final String trimmed = directory.endsWith(Platform.pathSeparator)
        ? directory.substring(0, directory.length - 1)
        : directory;
    return path == trimmed ||
        path.startsWith('$trimmed${Platform.pathSeparator}');
  }
}
