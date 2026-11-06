import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// How an export ended.
///
/// The three outcomes are separate on purpose: a failure that looks like a
/// cancel is how a user ends up with no file and no complaint, and a cancel
/// that looks like a success is worse.
enum ExportStatus { written, cancelled, failed }

/// Where a written file ended up.
enum ExportLocation {
  /// The location the user chose in the system dialog.
  chosenByUser,

  /// The platform's Downloads folder, written by the app itself.
  downloads,

  /// A folder the app owns, because nothing better was available.
  appFolder,
}

/// Where an export actually landed, so a screen can say something true about
/// it rather than assuming the folder it asked for.
class ExportResult {
  final ExportStatus status;

  /// The file's full path where the platform can report one.
  ///
  /// Null on Android and iOS: the storage framework reports a content URI, and
  /// the plugin answers with a path it guessed from the file name and the
  /// Downloads folder, which is not where the document was actually created.
  /// Nothing may be written to that guess.
  final String? path;

  /// The name the file was offered as, always known.
  final String name;

  final ExportLocation location;

  const ExportResult({
    required this.status,
    required this.name,
    this.path,
    this.location = ExportLocation.appFolder,
  });

  const ExportResult.written({
    required this.name,
    this.path,
    this.location = ExportLocation.appFolder,
  }) : status = ExportStatus.written;

  ExportResult.cancelled(this.name)
      : status = ExportStatus.cancelled,
        path = null,
        location = ExportLocation.appFolder;

  ExportResult.failed(this.name)
      : status = ExportStatus.failed,
        path = null,
        location = ExportLocation.appFolder;
}

/// How far an import got.
///
/// [empty], [notJson] and [notBackup] are kept apart so the screen can say
/// which one happened. They used to arrive as one message, which is why an
/// export that silently wrote nothing came back as "not a valid backup".
enum ImportStatus {
  /// Bytes were read and decoded into a json object.
  decoded,

  /// The user backed out of the picker.
  cancelled,

  /// The file exists and holds nothing.
  empty,

  /// The file is not json, or not utf8 text at all.
  notJson,

  /// Valid json, but not a backup.
  notBackup,

  /// The file could not be read off the device.
  readFailed,
}

/// What a read produced: the json object, or the reason there is not one.
class ImportResult {
  final ImportStatus status;
  final Map<String, dynamic>? data;

  const ImportResult(this.status, {this.data});

  const ImportResult.decoded(Map<String, dynamic> this.data)
      : status = ImportStatus.decoded;

  const ImportResult.cancelled()
      : status = ImportStatus.cancelled,
        data = null;

  const ImportResult.empty()
      : status = ImportStatus.empty,
        data = null;

  const ImportResult.notJson()
      : status = ImportStatus.notJson,
        data = null;

  const ImportResult.notBackup()
      : status = ImportStatus.notBackup,
        data = null;

  const ImportResult.readFailed()
      : status = ImportStatus.readFailed,
        data = null;
}

class FileUtils {
  /// The name the app gives its own backups, so re-exporting never leaves a
  /// trail of differently named files.
  static const String defaultFileName = 'fivetlog-backup.json';

  /// True on the platforms whose save dialog writes the bytes itself.
  ///
  /// file_picker 8.0.0 saveFile takes `bytes` and, on Android and iOS, the
  /// native side writes them and hands back a path. On desktop the dialog only
  /// chooses a name and the caller has to write the file.
  static bool get pickerWritesBytes => Platform.isAndroid || Platform.isIOS;

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

  /// Writes [data] as json and reports where it went.
  ///
  /// The picker opens in Downloads where the platform has one. Where the picker
  /// is missing, refuses to open, or hands back a location that cannot be
  /// written to, the file goes into Downloads when that exists and into a
  /// folder the app owns when it does not. Nothing in here throws: every
  /// outcome is an [ExportStatus].
  ///
  /// [pickerWritesBytes] exists so the two picker contracts can be tested on
  /// one machine. Leave it null in app code.
  static Future<ExportResult> exportData(
    Map<String, dynamic> data, {
    String? dialogTitle,
    String fileName = defaultFileName,
    bool? pickerWritesBytes,
  }) async {
    final bool nativeWriter = pickerWritesBytes ?? FileUtils.pickerWritesBytes;

    Uint8List bytes;
    try {
      bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
    } catch (_) {
      return ExportResult.failed(fileName);
    }

    final Directory? downloads = await downloadsDirectory();

    String? pickedPath;
    bool pickerOpened = true;
    try {
      pickedPath = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: fileName,
        // A raw filesystem path only means something to the desktop dialogs.
        // On Android the plugin puts this into EXTRA_INITIAL_URI, which the
        // storage framework reads as a document URI, so a path from
        // path_provider points nowhere and is better left out.
        initialDirectory: nativeWriter ? null : downloads?.path,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        // Required on Android and iOS. The native side writes these bytes
        // through the storage framework and the document it creates is empty
        // without them: on Android writing null throws a NullPointerException
        // on the main thread, which no try/catch on this side can catch.
        bytes: bytes,
      );
    } catch (_) {
      pickerOpened = false;
    }

    if (pickerOpened) {
      if (pickedPath == null) {
        // A usable picker that returned nothing means the user cancelled, and
        // writing anyway would be doing something they just said no to.
        return ExportResult.cancelled(fileName);
      }
      if (nativeWriter) {
        // The plugin has already written the bytes through the storage
        // framework. Its answer is a guess at a Downloads path, not the
        // document the user chose, so writing there with dart:io would leave
        // the real document empty and drop a second file somewhere else.
        return ExportResult.written(
          name: fileName,
          location: ExportLocation.chosenByUser,
        );
      }
      try {
        await File(pickedPath).writeAsBytes(bytes, flush: true);
        return ExportResult.written(
          name: fileName,
          path: pickedPath,
          location: downloads != null && _isInside(pickedPath, downloads.path)
              ? ExportLocation.downloads
              : ExportLocation.chosenByUser,
        );
      } catch (_) {
        // Some desktop dialogs hand back a location that cannot be written
        // straight to. Fall through and write where the app certainly can.
      }
    }

    // Downloads first where the platform has one, then a folder the app owns.
    if (downloads != null) {
      final ExportResult attempt = await writeToFolder(
        downloads,
        fileName,
        bytes,
        location: ExportLocation.downloads,
      );
      if (attempt.status == ExportStatus.written) {
        return attempt;
      }
    }

    final Directory? documents = await _documentsFolder();
    if (documents == null) {
      return ExportResult.failed(fileName);
    }
    return writeToFolder(documents, fileName, bytes);
  }

  /// Writes [bytes] into [folder] under [name], reporting rather than throwing.
  ///
  /// Separate from [exportData] so the write a user relies on can be tested
  /// against a real directory.
  static Future<ExportResult> writeToFolder(
    Directory folder,
    String name,
    Uint8List bytes, {
    ExportLocation location = ExportLocation.appFolder,
  }) async {
    try {
      await folder.create(recursive: true);
      final File file = File('${folder.path}${Platform.pathSeparator}$name');
      await file.writeAsBytes(bytes, flush: true);
      return ExportResult.written(
        name: name,
        path: file.path,
        location: location,
      );
    } catch (_) {
      return ExportResult.failed(name);
    }
  }

  /// The app's own documents folder, the last place a backup can always go.
  static Future<Directory?> _documentsFolder() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return null;
    }
  }

  /// Lets the user pick a json file and reports what was in it.
  ///
  /// The bytes are asked for directly with `withData`, because on Android the
  /// path the plugin hands back is a cache copy it made itself, and on some
  /// devices that copy is not there. Nothing in here throws.
  static Future<ImportResult> importData({String? dialogTitle}) async {
    FilePickerResult? picked;
    bool filterRefused = false;
    try {
      picked = await FilePicker.platform.pickFiles(
        dialogTitle: dialogTitle,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
    } catch (_) {
      // A device whose storage provider has no mapping for the json mime type
      // can refuse the filtered request outright. Being able to pick the file
      // at all and then say what is wrong with it beats an import that never
      // opens.
      filterRefused = true;
    }

    if (filterRefused) {
      try {
        picked = await FilePicker.platform.pickFiles(
          dialogTitle: dialogTitle,
          type: FileType.any,
          withData: true,
        );
      } catch (_) {
        return const ImportResult.readFailed();
      }
    }

    if (picked == null || picked.files.isEmpty) {
      return const ImportResult.cancelled();
    }

    final PlatformFile file = picked.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null) {
      // withData did not deliver, so read the cached copy the picker made.
      try {
        final String? path = file.path;
        if (path == null) {
          return const ImportResult.readFailed();
        }
        bytes = await File(path).readAsBytes();
      } catch (_) {
        return const ImportResult.readFailed();
      }
    }

    return decodeImport(bytes);
  }

  /// Turns the bytes of a picked file into a json object, or into the reason
  /// there is not one. Pure, so every rejection path is testable without a
  /// device.
  static ImportResult decodeImport(Uint8List bytes) {
    if (bytes.isEmpty) {
      return const ImportResult.empty();
    }

    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      return const ImportResult.notJson();
    }

    // A byte order mark left by an editor on another platform is not json.
    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    }
    if (text.trim().isEmpty) {
      return const ImportResult.empty();
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return const ImportResult.notJson();
    }
    if (decoded is! Map) {
      // Valid json, but a backup is an object. A list or a bare number is
      // something else that happens to sit in a .json file.
      return const ImportResult.notBackup();
    }

    return ImportResult.decoded(Map<String, dynamic>.from(decoded));
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
