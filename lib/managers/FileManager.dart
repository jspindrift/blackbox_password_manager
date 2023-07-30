import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// this creates a stackoverflow
// import '../managers/LogManager.dart';

class FileManager {
  static final FileManager _shared = FileManager._internal();

  var logger = Logger(
    printer: PrettyPrinter(),
  );

  factory FileManager() {
    return _shared;
  }

  // Future<Directory?>? _tempDirectory;
  // Future<Directory?>? _appSupportDirectory;
  // Future<Directory?>? _appLibraryDirectory;
  Future<Directory?>? _appDocumentsDirectory;
  // Future<Directory?>? _externalDocumentsDirectory;
  // Future<List<Directory>?>? _externalStorageDirectories;
  // Future<List<Directory>?>? _externalCacheDirectories;
  // Future<Directory?>? _downloadsDirectory;

  int _logFileNumber = 0;

  int get logFileNumber {
    return _logFileNumber;
  }

  FileManager._internal();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    // print("directory: $directory");
    return directory.path;
  }

  get localPath {
    return _localPath;
  }

  Future<String> get _externalLocalPath async {
    final directories = await getExternalStorageDirectories();
    logger.d("directories: $directories");

    /// find the correct directory


    return directories?.last.path ?? "none";
  }

  get externalLocalPath {
    return _externalLocalPath;
  }

  /// Local Log File  ----------------------------------------
  ///
  Future<File> get _localLogFile async {
    final path = await _localPath;

    // print("path: $path");

    /// TODO: fix this directory file error, returning on exception for now
    try {
      final logDirExists = Directory("$path/logs/").existsSync();

      // print("logDirExists: $logDirExists");
      if (logDirExists) {
        final files = Directory("$path/logs/").listSync();
        // print("files: ${files.length}: $files");

        // var numFiles = files.length;
        // final logFileNumber = numFiles;

        // print('1 file path: ${files.last.path}');
        // print("return vault file: ${'${files.last.path}'}");
        return File('${files.last.path}');
      } else {
        Directory("$path/logs/").createSync();
        return File('$path/logs/logs.txt');
      }
    } catch (e) {
      return File('$path/logs/logs.txt');
    }
  }

  /// Local Log File Appended ----------------------------------------
  ///
  Future<File> get _localLogFileAppend async {
    final path = await _localPath;

    // print("path: $path");

    /// TODO: fix this directory file error, returning on exception for now
    try {
      final logDirExists = Directory("$path/bbxlogs/").existsSync();

      // print("logDirExists: $logDirExists");
      if (logDirExists) {
        final files = Directory("$path/bbxlogs/").listSync();
        // print("files: ${files.length}: $files");

        // var numFiles = files.length;
        // final logFileNumber = numFiles;

        // print('1 file path: ${files.last.path}');
        // print("return vault file: ${'${files.last.path}'}");
        return File('${files.last.path}');
      } else {
        Directory("$path/bbxlogs/").createSync();
        return File('$path/bbxlogs/logs.txt');
      }
    } catch (e) {
      return File('$path/bbxlogs/logs.txt');
    }
  }

  /// Local Backup Vault File  ----------------------------------------
  ///
  Future<File> get _localVaultFile async {
    final path = await _localPath;

    /// TODO: fix this directory file error, returning on exception for now
    try {
      final backupDirExists = Directory("$path/backups/").existsSync();

      // print("backupDirExists: $backupDirExists");
      if (backupDirExists) {
        final files = Directory("$path/backups/").listSync();
        // print("files: ${files.length}: $files");

        var numFiles = files.length;
        final logFileNumber = numFiles;

        // print('1 file path: ${files.last.path}');
        // print("return vault file: ${'${files.last.path}'}");
        return File('${files.first.path}');
        // return File('$path/logs/log-0.txt');

      } else {
        // final vaultDirCreateStatus =
        Directory("$path/backups/").createSync();
        // if (vaultDirCreateStatus) {
        //   print('create directory path /backups/vault.txt');
        // }
        return File('$path/backups/vault.txt');
      }
    } catch (e) {
      // logManager.logger.w("FILE ERROR: $e");
      // print("FILE ERROR: $e");
      return File('$path/backups/vault.txt');
    }
  }

  Future<File> get _localVaultFileSDCard async {
    final path = await _externalLocalPath;

    /// TODO: fix this directory file error, returning on exception for now
    try {
      final backupDirExists = Directory("$path/backups/").existsSync();

      // print("backupDirExists: $backupDirExists");
      if (backupDirExists) {
        final files = Directory("$path/backups/").listSync();
        // print("files: ${files.length}: $files");

        var numFiles = files.length;
        final logFileNumber = numFiles;

        // print('1 file path: ${files.last.path}');
        // print("return vault file: ${'${files.last.path}'}");
        return File('${files.first.path}');
        // return File('$path/logs/log-0.txt');

      } else {
        // final vaultDirCreateStatus =
        Directory("$path/backups/").createSync();
        // if (vaultDirCreateStatus) {
        //   print('create directory path /backups/vault.txt');
        // }
        return File('$path/backups/vault.txt');
      }
    } catch (e) {
      // logManager.logger.w("FILE ERROR: $e");
      // print("FILE ERROR: $e");
      return File('$path/backups/vault.txt');
    }
  }

  /// Temp Vault File  ----------------------------------------
  ///
  Future<File> get _localTempVaultFile async {
    final path = await _localPath;

    /// TODO: fix this directory file error, returning on exception for now
    try {
      final backupDirExists = Directory("$path/temp/").existsSync();

      // print("backupDirExists: $backupDirExists");
      if (backupDirExists) {
        final files = Directory("$path/temp/").listSync();
        // print("files: ${files.length}: $files");

        // var numFiles = files.length;
        // print('1 file path: ${files.last.path}');
        // print("return vault file: ${'${files.last.path}'}");
        return File('${files.first.path}');
      } else {
        // final vaultDirCreateStatus =
        Directory("$path/temp/").createSync();

        return File('$path/temp/vault.txt');
      }
    } catch (e) {
      // print("FILE ERROR: $e");
      return File('$path/temp/vault.txt');
    }
  }



  /// Log Data ----------------------------------------
  ///
  Future<File?> writeLogData(String data) async {
    // print("write log file: ${data.length}");

    try {
      final file = await _localLogFile;

      // Write the file
      return file.writeAsString(data, mode: FileMode.writeOnly, flush: true);
      // return file.writeAsString(data, mode: FileMode.append);
    } catch (e) {
      // print("Exception: File: $e");
      return null;
    }
  }

  Future<File> clearLogFile() async {
    // print("clear log file");
    final file = await _localLogFile;

    // Write the file
    return file.writeAsString("", mode: FileMode.writeOnly);
    // return file.writeAsString(data, mode: FileMode.append);
  }

  Future<String> readLogData() async {
    // print("readLogData");
    try {
      final file = await _localLogFile;
      final contents = await file.readAsString();
      // print("read log file: ${contents.length}");
      return contents;
    } catch (e) {
      return '';
    }
  }

  /// Append Only Log Data ----------------------------------------
  ///
  Future<File?> writeLogDataAppend(String data) async {
    // print("write log file: ${data.length}");

    try {
      final file = await _localLogFileAppend;

      // Write the file
      return file.writeAsString(data,
          mode: FileMode.writeOnlyAppend, flush: false);
      // return file.writeAsString(data, mode: FileMode.append);
    } catch (e) {
      // print("Exception: writeLogDataAppend: $e");
      return null;
    }
  }

  Future<File> clearLogFileAppend() async {
    // print("clear log file");
    final file = await _localLogFileAppend;

    // Write the file
    return file.writeAsString("", mode: FileMode.writeOnly);
    // return file.writeAsString(data, mode: FileMode.append);
  }

  Future<String> readLogDataAppend() async {
    // print("read log file");

    try {
      final file = await _localLogFileAppend;

      // Read the file
      final contents = await file.readAsString();
      // print("read log file: ${contents.length}");

      return contents;
    } catch (e) {
      return '';
    }
  }

  /// Backup Vault Data ----------------------------------------
  ///
  Future<File?> writeVaultData(String data) async {
    try {
      final file = await _localVaultFile;

      // Write the file
      return file.writeAsString(data, mode: FileMode.writeOnly);
      // return file.writeAsString(data, mode: FileMode.append);
    } catch (e) {
      // print("write vault error: $e");
      return null;
    }
  }

  Future<File> clearVaultFile() async {
    final file = await _localVaultFile;

    // Write the file
    return file.writeAsString("", mode: FileMode.writeOnly);
    // return file.writeAsString(data, mode: FileMode.append);
  }

  Future<String> readVaultData() async {
    try {
      final file = await _localVaultFile;

      // Read the file
      final contents = await file.readAsString();

      return contents;
    } catch (e) {
      return "";
    }
  }

  /// Backup Vault Data - Android External Storage (SD card) ------------------
  ///
  Future<File?> writeVaultDataSDCard(String data) async {
    try {
      final file = await _localVaultFileSDCard;
      // Write the file
      return file.writeAsString(data, mode: FileMode.writeOnly);
    } catch (e) {
      logger.e("write vault error: $e");
      return null;
    }
  }

  Future<File> clearVaultFileSDCard() async {
    final file = await _localVaultFileSDCard;

    // Write the file
    return file.writeAsString("", mode: FileMode.writeOnly);
    // return file.writeAsString(data, mode: FileMode.append);
  }

  Future<String> readVaultDataSDCard() async {
    try {
      final file = await _localVaultFileSDCard;

      // Read the file
      final contents = await file.readAsString();

      return contents;
    } catch (e) {
      return "";
    }
  }

  /// Temp Vault File functions ----------------------------------------
  ///
  Future<File?> writeTempVaultData(String data) async {
    try {
      final file = await _localTempVaultFile;
      print("writeTempVaultData[${data.length}]: $file");

      // Write the file
      return file.writeAsString(data, mode: FileMode.writeOnly);
      // return file.writeAsString(data, mode: FileMode.append);
    } catch (e) {
      // print("write vault error: $e");
      return null;
    }
  }

  Future<String> readTempVaultData() async {
    try {
      final file = await _localTempVaultFile;

      // Read the file
      final contents = await file.readAsString();

      return contents;
    } catch (e) {
      return "";
    }
  }

  Future<File> clearTempVaultFile() async {
    final file = await _localTempVaultFile;

    print("clearTempVaultFile: $file");
    // Write the file
    return file.writeAsString("", mode: FileMode.writeOnly);
    // return file.writeAsString(data, mode: FileMode.append);
  }


}
