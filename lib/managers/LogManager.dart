import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../managers/FileManager.dart';
import '../managers/Cryptor.dart';
import '../managers/Hasher.dart';
import '../managers/Digester.dart';
import '../managers/DeviceManager.dart';
import '../managers/SettingsManager.dart';

/// cant add this as it causes a circular reference
// import '../managers/KeychainManager.dart';

/// get stack trace information
/// can only be used in debug mode for now since StackTrace info is different!
class CustomTrace {
  final StackTrace _trace;

  String fileName = '';
  String functionName = '';
  String callerFunctionName = '';
  int lineNumber = 0;
  int columnNumber = 0;

  CustomTrace(this._trace) {
    _parseTrace();
  }

  String _getFunctionNameFromFrame(String frame) {
    /* Just giving another nickname to the frame */
    var currentTrace = frame;

    /* To get rid off the #number thing, get the index of the first whitespace */
    var indexOfWhiteSpace = currentTrace.indexOf(' ');

    /* Create a substring from the first whitespace index till the end of the string */
    var subStr = currentTrace.substring(indexOfWhiteSpace);

    /* Grab the function name using reg expr */
    var indexOfFunction = subStr.indexOf(RegExp(r'[A-Za-z0-9]'));

    /* Create a new substring from the function name index till the end of string */
    subStr = subStr.substring(indexOfFunction);

    indexOfWhiteSpace = subStr.indexOf(' ');

    /* Create a new substring from start to the first index of a whitespace. This substring gives us the function name */
    subStr = subStr.substring(0, indexOfWhiteSpace);

    return subStr;
  }

  void _parseTrace() {
    /* The trace comes with multiple lines of strings, (each line is also known as a frame), so split the trace's string by lines to get all the frames */
    var frames = this._trace.toString().split("\n");

    /* The first frame is the current function */
    this.functionName = _getFunctionNameFromFrame(frames[0]);

    /* The second frame is the caller function */
    this.callerFunctionName = _getFunctionNameFromFrame(frames[1]);

    /* The first frame has all the information we need */
    var traceString = frames[0];

    /* Search through the string and find the index of the file name by looking for the '.dart' regex */
    var indexOfFileName = traceString.indexOf(RegExp(r'[A-Za-z]+.dart'));

    var fileInfo = traceString.substring(indexOfFileName);

    var listOfInfos = fileInfo.split(":");

    /* Splitting fileInfo by the character ":" separates the file name, the line number and the column counter nicely.
      Example: main.dart:5:12
      To get the file name, we split with ":" and get the first index
      To get the line number, we would have to get the second index
      To get the column number, we would have to get the third index
    */

    this.fileName = listOfInfos[0];
    this.lineNumber = int.parse(listOfInfos[1]);
    var columnStr = listOfInfos[2];
    columnStr = columnStr.replaceFirst(")", "");
    this.columnNumber = int.parse(columnStr);
  }
}

/// format of a log
///
class LogLine {
  String time;
  String callingFunction;
  String message;

  LogLine({
    required this.time,
    required this.callingFunction,
    required this.message,
  });

  factory LogLine.fromRawJson(String str) => LogLine.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory LogLine.fromJson(Map<String, dynamic> json) {
    return LogLine(
      time: json['time'],
      callingFunction: json['callingFunction'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "time": time,
      "callingFunction": callingFunction,
      "message": message,
    };
    return jsonMap;
  }
}

class BasicLogLine {
  String time;
  int index;
  String callingFunction;
  String message;

  BasicLogLine({
    required this.time,
    required this.index,
    required this.callingFunction,
    required this.message,
  });

  factory BasicLogLine.fromRawJson(String str) =>
      BasicLogLine.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory BasicLogLine.fromJson(Map<String, dynamic> json) {
    return BasicLogLine(
      time: json['time'],
      index: json['index'],
      callingFunction: json['callingFunction'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "time": time,
      "index": index,
      "callingFunction": callingFunction,
      "message": message,
    };
    return jsonMap;
  }
}

/// list of logs in a session/block
class LogList {
  List<LogLine> list;

  LogList({
    required this.list,
  });

  factory LogList.fromRawJson(String str) => LogList.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory LogList.fromJson(Map<String, dynamic> json) {
    return LogList(
      list: List<LogLine>.from(json["list"].map((x) => LogLine.fromJson(x))),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "list": list,
    };
    return jsonMap;
  }
}

class BasicLogList {
  List<BasicLogLine> list;

  BasicLogList({
    required this.list,
  });

  factory BasicLogList.fromRawJson(String str) =>
      BasicLogList.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory BasicLogList.fromJson(Map<String, dynamic> json) {
    return BasicLogList(
      list: List<BasicLogLine>.from(
          json["list"].map((x) => BasicLogLine.fromJson(x))),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "list": list,
    };
    return jsonMap;
  }
}

/// A full app session (login->lock/logout) is a block
class Block {
  int blockNumber;
  String time;
  String hash;
  String mac;
  LogList logList;

  Block({
    required this.blockNumber,
    required this.time,
    required this.logList,
    required this.hash,
    required this.mac,
  });

  factory Block.fromRawJson(String str) => Block.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Block.fromJson(Map<String, dynamic> json) {
    return Block(
      blockNumber: json['blockNumber'],
      time: json['time'],
      logList: LogList.fromJson(json["logList"]),
      hash: json['hash'],
      mac: json['mac'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "blockNumber": blockNumber,
      "time": time,
      "logList": logList,
      "hash": hash,
      "mac": mac,
    };
    return jsonMap;
  }
}

/// collection of all logs in blocks
class Blockchain {
  String time;
  List<Block> blocks;

  Blockchain({
    required this.time,
    required this.blocks,
  });

  factory Blockchain.fromRawJson(String str) =>
      Blockchain.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Blockchain.fromJson(Map<String, dynamic> json) {
    return Blockchain(
        time: json['time'],
        blocks: List<Block>.from(json["blocks"].map((x) => Block.fromJson(x))));
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "time": time,
      "blocks": blocks,
    };
    return jsonMap;
  }
}

/// Our Log Manager that handles logging and verifying logs
class LogManager {
  var logger = Logger(
    printer: PrettyPrinter(methodCount: 4),
  );

  static final LogManager _shared = LogManager._internal();

  factory LogManager() {
    return _shared;
  }

  static const _logManagerType = 0; // 0 = blockchain, 1 = append only

  static const _minCreationTime = '2022-12-04T08:28:44.219169';
  // static const _minCreationTime = '2022-12-05T08:28:44.219169';

  static const _logFileLimitSize = 10485760; // 10 MB in bytes
  static const _logFileLimitSize_1MB = 1048576; // 1 MB in bytes

  int _initialLogSizeInBytes = 0;
  double _initialLogSizeInKilobytes = 0;
  double _initialLogSizeInMegabytes = 0;
  double _initialLogSizeInGigabytes = 0;

  int _latestLogSizeInBytes = 0;

  int get latestLogSizeInBytes {
    return _latestLogSizeInBytes;
  }

  bool _deletedLogs = false;

  int _currentBlockLogSizeInBytes = 0;
  double _currentBlockLogSizeInKilobytes = 0;
  double _currentBlockLogSizeInMegabytes = 0;
  double _currentBlockLogSizeInGigabytes = 0;

  LogList _logLineList = LogList(list: []);
  BasicLogList _basicLogLineList = BasicLogList(list: []);

  Block _block = Block(
    blockNumber: 0,
    time: 'INIT TIME',
    hash: '',
    mac: '',
    logList: LogList(list: []),
  );

  Blockchain _blockchain = Blockchain(time: 'INIT TIME', blocks: []);

  int _blockHeight = 0;
  int _lifeTimeInSeconds = 0;
  int _appUsageInSeconds = 0;

  int _logLineCount = 0;

  bool _validLogs = false;
  bool _hasInvalidLogs = false;
  bool _logsAreVerifiable = false;

  bool _deletedLogFile = false;
  bool _savingConcurrent = false;
  bool _isSavingLogs = false;
  // String _noPinCodeMessage = 'failure: Bad state: No element';

  final fileManager = FileManager();
  final cryptor = Cryptor();
  final hasher = Hasher();
  final digester = Digester();
  final deviceManager = DeviceManager();
  final settingsManager = SettingsManager();
  // final tokenModel = TokenModel();

  int get lifeTimeInSeconds {
    return _lifeTimeInSeconds;
  }

  int get appUsageInSeconds {
    return _appUsageInSeconds;
  }

  bool get validLogs {
    return _validLogs;
  }

  bool get isSavingLogs {
    return _isSavingLogs;
  }

  void setIsSavingLogs(bool value) {
    _isSavingLogs = value;
  }

  /// cannot use this or causes stackoverflow
  // final keyManager = KeychainManager();

  LogManager._internal();

  void initialize() async {
    initialize2();

    try {
      /// TODO: remove after testing
      ///
      // deleteLogFile();

      await settingsManager.initialize();

      fileManager.readLogData().then((value) {
        _initialLogSizeInBytes = value.length;
        _initialLogSizeInKilobytes = value.length / 1024;
        _initialLogSizeInMegabytes = value.length / 1048576;
        _initialLogSizeInGigabytes = value.length / 1073741824;
        logger.d(
            'initialize retrieved data: $_initialLogSizeInBytes bytes, $_initialLogSizeInKilobytes kB, $_initialLogSizeInMegabytes MB, $_initialLogSizeInGigabytes Gb');

        final timestamp = DateTime.now();

        if (!timestamp.isAfter(DateTime.parse(_minCreationTime))) {
          logger.w('invalid time: failed to log2');
          return;
        }

        if (value != null) {
          if (value.isNotEmpty) {
            logger.d(
                'is file size less than limit: ${_initialLogSizeInBytes <= _logFileLimitSize}');

            _blockchain = Blockchain.fromRawJson(value);
            _blockHeight = _blockchain.blocks.length;
            logger.d(
                'blockchain: $_blockHeight blocks, time: ${_blockchain.time}');

            // final version = settingsManager.packageInfo.version;
            final appVersion = settingsManager.versionAndBuildNumber();//settingsManager.packageInfo.version;

            final startTime = DateTime.now().toIso8601String();

            final logLine = LogLine(
              time: startTime,
              callingFunction:
                  "LogManager.initialize", //programInfo.callerFunctionName,
              message: 'Initialize LogManager: version: $appVersion',
            );

            _logLineList.list.add(logLine);

            _block = Block(
              blockNumber: _blockHeight,
              time: startTime,
              logList: _logLineList,
              hash: '',
              mac: '',
            );
          } else {
            /// create the first blockchain log
            ///
            _createFirstBlock();
          }
        } else {
          /// create the first blockchain log
          ///
          _createFirstBlock();
        }
      });
    } catch (e) {
      logger.w("log exception: $e");
    }
  }

  void initialize2() async {
    logger.d("LogManager: initialize2");
    try {
      /// TODO: remove after testing
      ///
      // deleteLogFile();

      await settingsManager.initialize();

      var numberOfSessions = 0;

      final sessionNumber = settingsManager.sessionNumber;
      // print("initialize2 sessionNumber: $sessionNumber");
      settingsManager.incrementSessionNumber();

      if (sessionNumber == 0) {
        logger.d("first time opening app");
      }

      fileManager.readLogDataAppend().then((value) async {
        final parts = value.split("\n");
        // print("newlines: ${parts.length}");
        // print("last line: ${parts.last}");

        /// this wont happen here, for testing
        // var lastLine;
        // if (parts.length > 1) {
        //   lastLine = parts[parts.length-1];
        // } else {
        //   lastLine = parts[0];
        // }
        // final lastLine = parts[parts.length-1];
        // print("last line: ${lastLine}");

        // final parts2 = lastLine.split(", ");
        // final hashline = parts2.first.replaceAll("hash: ", "");
        // final macline = parts2.last.replaceAll("digest: ", "");
        // print("hashline line: ${hashline}");
        // print("macline line: ${macline}");

        int index = 0;
        String appendedString = "";
        for (var part in parts) {
          // print("part[$index]: $part");

          try {
            final isLogLine = BasicLogList.fromRawJson(part.trim());
            if (isLogLine != null) {
              // print("decoded line: $isLogLine");
              appendedString += part + "\n";
            }
            // else {
            //   print("cant decode line: $part");
            //
            //   // final parts2 = part.split(", ");
            //   // print("parts2 first: ${parts2.first}");
            //   // print("parts2 last: ${parts2.last}");
            //   //
            //   // final hashline = parts2.first.replaceAll("hash: ", "");
            //   // final macline = parts2.last.replaceAll("digest: ", "");
            //   // print("hashline line[$index]: ${hashline}");
            //   // print("macline line[$index]: ${macline}");
            //   //
            //   // final logHash = hasher.sha256Hash(appendedString);
            //   // print('logHash: ${logHash}');
            //
            //   // appendedString += part;
            //
            // }
          } catch (e) {
            // print("error: $e\n...cant decode line: ${part.length}: $part");
            final parts2 = part.split(", ");
            if (parts2.length > 1) {
              _logsAreVerifiable = true;
              numberOfSessions += 1;
              // print("parts2 first: ${parts2.first}");
              // print("parts2 last: ${parts2.last}");

              final hashCheck = parts2.first.replaceAll("hash: ", "");
              final macCheck = parts2.last.replaceAll("digest: ", "");
              // print("hashline line[$index]: ${hashline}");
              // print("macline line[$index]: ${macline}");

              final logHash = hasher.sha256Hash(appendedString);
              // print('logHash: ${logHash}');
              // print('hashline==logHash: ${logHash == hashline}');

              // final logKey = base64.encode(cryptor.logSecretKeyBytes);
              final logKeyHex = hex.encode(cryptor.logSecretKeyBytes);
              // final logMac = await digester.hmac(logHash, logKey);
              final logMac = await digester.hmac(logHash, logKeyHex);
              final logMacHex = hex.encode(logMac);
              // final logMacHex2 = hex.encode(logMac2);

              // print('logMac: ${logMacHex}');
              // print('logMac==MAC: ${logMacHex==macCheck}');

              if (logHash != hashCheck || logMacHex != macCheck) {
                _hasInvalidLogs = true;
                logger.w(
                    "invalid hash/digest[$index]: $hashCheck, $logHash, $logMacHex");
              }
              // else {
              //   logger.d("valid logs");
              // }

              if (index == parts.length - 1) {
                appendedString += part;
              } else {
                appendedString += part + "\n";
              }
            } else {
              if (index == parts.length - 1) {
                appendedString += part;
              } else {
                appendedString += part + "\n";
              }
            }
          }
          index += 1;
        }

        // print("numberOfSessions: $numberOfSessions");
        //
        // print("IS APPENDED length: ${appendedString.length}, ${value.length}");
        //
        // print("IS APPENDED STRING ==: ${appendedString == value}");

        // print("_logsAreVerifiable: $_logsAreVerifiable");
        // print("_hasInvalidLogs: $_hasInvalidLogs");
        // print("_validLogs: $_validLogs");

        if (_logsAreVerifiable) {
          _validLogs = !_hasInvalidLogs;
        } else {
          _validLogs = false;
        }

        // print("_validLogs: $_validLogs");

        _initialLogSizeInBytes = value.length;
        _initialLogSizeInKilobytes = value.length / 1024;
        _initialLogSizeInMegabytes = value.length / 1048576;
        _initialLogSizeInGigabytes = value.length / 1073741824;
        logger.d(
            'initialize log append retrieved data: $_initialLogSizeInBytes bytes, $_initialLogSizeInKilobytes kB, $_initialLogSizeInMegabytes MB, $_initialLogSizeInGigabytes Gb');

        final timestamp = DateTime.now();

        if (!timestamp.isAfter(DateTime.parse(_minCreationTime))) {
          logger.d('invalid time: failed to log2');
          return;
        }

        if (value != null) {
          if (value.isNotEmpty) {
            logger.d(
                'is file size less than 1MB: ${_initialLogSizeInBytes <= _logFileLimitSize_1MB}');

            // _blockchain = Blockchain.fromRawJson(value);
            // _blockHeight = _blockchain.blocks.length;
            // logger.d(
            //     'blockchain: $_blockHeight blocks, time: ${_blockchain.time}');
            //
            // final version = settingsManager.packageInfo.version;
            final appVersion = settingsManager.versionAndBuildNumber();//settingsManager.packageInfo.version;

            final startTime = DateTime.now().toIso8601String();
            //
            // final logLine = LogLine(
            //   time: startTime,
            //   callingFunction:
            //   "LogManager.initialize", //programInfo.callerFunctionName,
            //   message: 'Initialize LogManager: version: $version',
            // );
            //
            // _logLineList.list.add(logLine);
            //
            // _block = Block(
            //   blockNumber: _blockHeight,
            //   time: startTime,
            //   logList: _logLineList,
            //   hash: '',
            //   mac: '',
            // );

            final logHash = hasher.sha256Hash(value);
            // print('logHash: ${logHash}');

            // final logKey = base64.encode(cryptor.logSecretKeyBytes);
            // print('logKey cryptor: ${logKey}');

            final logKeyHex = hex.encode(cryptor.logSecretKeyBytes);
            // print('logKeyHex cryptor: ${logKeyHex}');

            // print('mac log with key: $logKey');
            // final logMac = await digester.hmac(logHash, logKey);
            // print('logMac: ${hex.encode(logMac)}');

            final logHexMac = await digester.hmac(logHash, logKeyHex);
            final logHexMacEncoded = hex.encode(logHexMac);
            // print('logHexMac: ${logHexMacEncoded}');

            /// TODO: diff logging
            // _logLineCount += 1;
            // final logLineHash = BasicLogLine(
            //   time: startTime,
            //   index: 0,
            //   callingFunction:
            //   "LogManager.initialize",
            //   message: "hash: $logHash, digest: $logMac",
            // );

            /// Write hash and digest to log file
            final logHashLine = "hash: $logHash, digest: $logHexMacEncoded";

            await fileManager.writeLogDataAppend(logHashLine + "\n");

            // _basicLogLineList.list.add(logLineHash);

            /// TODO: diff logging
            _logLineCount += 1;
            final logLine2 = BasicLogLine(
              time: startTime,
              index: _logLineCount,
              callingFunction: "LogManager.initialize",
              message: "version: $appVersion",
            );

            _basicLogLineList.list.add(logLine2);

            _logLineCount += 1;
            final logLine3 = BasicLogLine(
              time: startTime,
              index: _logLineCount,
              callingFunction: "LogManager.initialize",
              message: "session: ${settingsManager.sessionNumber}",
            );

            _basicLogLineList.list.add(logLine3);
          } else {
            /// create the first blockchain log
            ///
            _createFirstBlock2();
          }
        } else {
          /// create the first blockchain log
          ///
          _createFirstBlock2();
        }
      });
    } catch (e) {
      logger.w("log exception: $e");
    }
  }

  /// create the first block in our chain.
  void _createFirstBlock() async {
    logger.d('Create First Block');
    try {
      _blockchain = Blockchain(time: "create first block", blocks: []);

      // CustomTrace programInfo = CustomTrace(StackTrace.current);
      final deviceId = await deviceManager.getDeviceId();

      /// create the first blockchain log
      ///
      final startTime = DateTime.now();
      final startTimeString = startTime.toIso8601String();

      if (!startTime.isAfter(DateTime.parse(_minCreationTime))) {
        logger.d('we not good');
        return;
      }

      var logLine = LogLine(
        time: startTimeString,
        callingFunction: "LogManager._createFirstBlock",
        message: 'Genesis: deviceId: $deviceId',
      );

      _logLineList.list.add(logLine);

      // final version = settingsManager.packageInfo.version;
      final appVersion = settingsManager.versionAndBuildNumber();//settingsManager.packageInfo.version;

      logLine = LogLine(
        time: startTimeString,
        callingFunction: "LogManager._createFirstBlock",
        message: 'version: $appVersion',
      );

      _logLineList.list.add(logLine);

      final logLineJsonString = logLine.toRawJson();

      final hash = hasher.sha256Hash(logLineJsonString);

      _block = Block(
        blockNumber: 0,
        time: startTimeString,
        logList: _logLineList,
        hash: hash,
        mac: '',
      );

      _blockchain = Blockchain(time: startTimeString, blocks: [_block]);

      // /// TODO: diff logging
      // _logLineCount += 1;
      // final logLine2 = BasicLogLine(
      //   time: startTimeString,
      //   index: _logLineCount,
      //   callingFunction:
      //   "LogManager._createFirstBlock",
      //   message: "version: $version",
      // );
      //
      // _basicLogLineList.list.add(logLine2);
      // logger.d('starting with new logs');
    } catch (e) {
      print(e);
    }
  }

  /// create the first block in our chain.
  void _createFirstBlock2() async {
    logger.d('Create First Block2');
    try {
      final deviceId = await deviceManager.getDeviceId();

      /// create the first blockchain log
      ///
      final startTime = DateTime.now();
      final startTimeString = startTime.toIso8601String();

      if (!startTime.isAfter(DateTime.parse(_minCreationTime))) {
        logger.d('we not good');
        return;
      }

      // final version = settingsManager.packageInfo.version;
      final appVersion = settingsManager.versionAndBuildNumber();//settingsManager.packageInfo.version;

      /// TODO: diff logging
      _logLineCount += 1;
      final logLine2 = BasicLogLine(
        time: startTimeString,
        index: _logLineCount,
        callingFunction: "LogManager._createFirstBlock",
        message: "version: $appVersion",
      );

      _basicLogLineList.list.add(logLine2);

      _logLineCount += 1;
      final logLine3 = BasicLogLine(
        time: startTimeString,
        index: _logLineCount,
        callingFunction: "LogManager._createFirstBlock",
        message: 'Genesis: deviceId: $deviceId',
      );

      _basicLogLineList.list.add(logLine3);

      _logLineCount += 1;
      final logLine4 = BasicLogLine(
        time: startTimeString,
        index: _logLineCount,
        callingFunction: "LogManager._createFirstBlock",
        message: "session: ${settingsManager.sessionNumber}",
      );

      _basicLogLineList.list.add(logLine4);
      // logger.d('starting with new logs');
    } catch (e) {
      print(e);
    }
  }

  /// log a message, cannot use StackTrace here in production mode
  /// so wee manually add the calling class and function here
  void log(String callingClass, String callingFunction, String message) {
    // CustomTrace programInfo = CustomTrace(StackTrace.current);
    final timestamp = DateTime.now();

    // if (!timestamp.isAfter(DateTime.parse(_minCreationTime))) {
    //   print('invalid time: failed to log');
    //   return;
    // }
    // print("second: ${(timestamp.millisecondsSinceEpoch/(60*1000)).toInt()}");
    // print("minute: ${DateTime.now().toUtc().minute}");

    final logLine = LogLine(
      time: timestamp.toIso8601String(),
      callingFunction: "$callingClass.$callingFunction",
      message: message,
    );

    // if (_logManagerType == 0) {
    _logLineList.list.add(logLine);
    // } else {

    _logLineCount += 1;

    final logLine2 = BasicLogLine(
      time: timestamp.toIso8601String(),
      index: _logLineCount,
      callingFunction: "$callingClass.$callingFunction",
      message: message,
    );

    _basicLogLineList.list.add(logLine2);
  }

  /// save collected logs to the log file
  Future<void> saveLogs() async {
    // print("save logs: $_isSavingLogs");
    if (_deletedLogs) {
      // print("deleted logs, ignoring saving.");
      return;
    }

    try {
      final timestamp = DateTime.now();

      // if (!timestamp.isAfter(DateTime.parse(_minCreationTime))) {
      //   print('invalid time: failed to save logs');
      //   return;
      // }

      if (_logLineList != null) {
        // print("session #: ${settingsManager.sessionNumber}");

        if (_blockHeight == 0) {
          // if (_blockchain.blocks.length == 0) {
          // print("0: ${_blockchain.blocks.toString()}");
          final startTime = DateTime.now().toIso8601String();

          if (_deletedLogFile) {
            final deviceId = await deviceManager.getDeviceId();

            final logLineSpecial = LogLine(
              time: startTime,
              callingFunction:
                  "LogManager.saveLogs", //programInfo.callerFunctionName,
              message: "deleted logs - deviceId: $deviceId",
            );
            _logLineList.list.add(logLineSpecial);

            _deletedLogFile = false;
          }

          final logLine = LogLine(
            time: startTime,
            callingFunction: "LogManager.saveLogs",
            message: "debug: $kDebugMode",
          );

          _logLineList.list.add(logLine);

          _logLineCount += 1;

          final logLine3 = BasicLogLine(
            time: timestamp.toIso8601String(),
            index: _logLineCount,
            callingFunction: "LogManager.saveLogs",
            message:
                "debug: $kDebugMode | session: ${settingsManager.sessionNumber}",
          );

          _basicLogLineList.list.add(logLine3);

          await fileManager
              .writeLogDataAppend(_basicLogLineList.toRawJson() + "\n");

          _basicLogLineList.list = [];
          _logLineCount = 0;

          final logLineJsonString = _logLineList.toRawJson();

          final blockHash = hasher.sha256Hash(logLineJsonString);

          // print('logKey: $logKey');
          // final blockMac = await digester.hmac(logLineJsonString, logKey);
          // final logKey = cryptor.logSecretKeyBytes;
          final logKey = base64.encode(cryptor.logSecretKeyBytes);
          // print('logKey cryptor: ${cryptor.logSecretKeyBytes}');
          // print('mac log with key: $logKey');
          final blockMac = await digester.hmac(blockHash, logKey);

          _block = Block(
            blockNumber: _blockHeight,
            time: startTime,
            logList: _logLineList,
            hash: blockHash,
            mac: base64.encode(blockMac),
          );

          _blockchain = Blockchain(time: startTime, blocks: [_block]);

          final blockchainStringData = _blockchain.toRawJson();
          // print(
          //     'is file size less than limit: ${blockchainStringData.length <= _logFileLimitSize}');

          /// shoudn't happen but if it does..custom splitting and saving
          if (blockchainStringData.length >= _logFileLimitSize) {
            /// shoudn't happen
            logger.w("LogFile Size Limit Reached");
          }
          // print('blockchainStringData: $blockchainStringData');
          // print('blockchainStringData length: ${blockchainStringData.length}');
          // print('blockchainStringData length: ${blockchainStringData.length}');

          final f = await fileManager.writeLogData(blockchainStringData);
          // if (f != null) {
          //   print('write data: ${f.path}');
          // }
          // print('write data: ${f.path}');

          _logLineList.list = [];

          _blockHeight += 1;

          final data = await fileManager.readLogData();
          // print('retrieved new logs: ${value.length}');
          _latestLogSizeInBytes = data.length;
          // print(
          //     'is file size less than limit: ${value.length <= _logFileLimitSize}');

          _blockchain = Blockchain.fromRawJson(data);
          _isSavingLogs = false;
        } else {
          // print("save: ${_blockchain.blocks.toString()}");
          // print("save logs blockheight: $_blockHeight");
          // CustomTrace programInfo = CustomTrace(StackTrace.current);
          // CustomTrace programInfo = CustomTrace(StackTrace.current);
          final startTime = DateTime.now().toIso8601String();
          final logLine = LogLine(
            time: startTime,
            callingFunction:
                "LogManager.saveLogs", //programInfo.callerFunctionName,
            message: "debug: $kDebugMode",
          );

          _logLineList.list.add(logLine);

          final lastHash = _blockchain.blocks.last.hash;
          final lastMac = _blockchain.blocks.last.mac;

          final logLineLast = LogLine(
            time: startTime,
            callingFunction: "LogManager.saveLogs",
            message: "prevHash: $lastHash, prevMac: $lastMac",
          );

          _logLineList.list.add(logLineLast);

          _logLineCount += 1;

          /// TODO: add different logging
          final logLine3 = BasicLogLine(
            time: timestamp.toIso8601String(),
            index: _logLineCount,
            callingFunction:
                "LogManager.saveLogs", //programInfo.callerFunctionName,
            message:
                "debug: $kDebugMode | session: ${settingsManager.sessionNumber}",
          );

          _basicLogLineList.list.add(logLine3);

          // await fileManager.writeLogDataAppend(_basicLogLineList.toRawJson());
          await fileManager
              .writeLogDataAppend(_basicLogLineList.toRawJson() + "\n");

          _basicLogLineList.list = [];
          _logLineCount = 0;

          // print(_logLineList.list);

          final logLineJsonString = _logLineList.toRawJson();

          _currentBlockLogSizeInBytes = logLineJsonString.length;
          _currentBlockLogSizeInKilobytes = logLineJsonString.length / 1024;
          // _currentBlockLogSizeInMegabytes = logLineJsonString.length/1048576;
          // _currentBlockLogSizeInGigabytes = logLineJsonString.length/1073741824;

          // print('current block size: $_currentBlockLogSizeInBytes bytes, $_currentBlockLogSizeInKilobytes kB');
          // print('current block size: $_currentBlockLogSizeInKilobytes kB, $_currentBlockLogSizeInMegabytes MB, $_currentBlockLogSizeInGigabytes Gb');

          final blockHash = hasher.sha256Hash(logLineJsonString);

          // if (lastHash == blockHash) {
          //   print("something is very wrong");
          // }
          final logKey = base64.encode(cryptor.logSecretKeyBytes);
          // print('mac log with key: $logKey');
          final blockMac = await digester.hmac(blockHash, logKey);

          _block = Block(
            blockNumber: _blockchain.blocks.length,
            time: startTime,
            logList: _logLineList,
            hash: blockHash,
            mac: base64.encode(blockMac),
          );

          _blockchain.blocks.add(_block);

          final blockchainStringData = _blockchain.toRawJson();
          // final blockStringData = sessionBlockData.toRawJson();
          // print(
          //     'is file size less than limit: ${blockchainStringData.length <= _logFileLimitSize}');

          /// shoudn't happen but if it does..custom splitting and saving
          if (blockchainStringData.length >= _logFileLimitSize) {
            /// could happen
          }
          // print('blockchainStringData length: ${blockchainStringData.length}');

          final f = await fileManager.writeLogData(blockchainStringData);
          // if (f != null) {
          //   print('write data: ${f.path}');
          // }

          _logLineList.list = [];

          _blockHeight += 1;

          final data = await fileManager.readLogData(); //.then((value) {
          // print('retrieved new logs: ${data.length}');
          _latestLogSizeInBytes = data.length;

          // print(
          //     'is file size less than limit: ${value.length <= _logFileLimitSize}');

          _blockchain = Blockchain.fromRawJson(data);

          _isSavingLogs = false;

          // _iterateThroughLogs(_blockchain);
          // });
        }
      }
    } catch (e) {
      logger.w("Error in LogManager: $e");
      log("LogManager", "saveLogs", "Error in LogManager: ${e.toString()}");
    }
  }

  /// print out log information...for testing purposes
  void _iterateThroughLogs(Blockchain blockchain) async {
    for (var block in blockchain.blocks) {
      print('iterating block #: ${block.blockNumber}');
      // print('iterating block index #: $index');
      print('block hash: ${block.hash}');
      print('block mac: ${block.mac}');
      // index += 1;
      for (var line in block.logList.list) {
        print('line: ${line.time} : ${line.callingFunction}: ${line.message}');
      }
    }
  }

  /// get the size of the log file/blockchain
  Future<int> getLogFileSize() async {
    final size = await fileManager.readLogData();
    _initialLogSizeInBytes = size.length;
    // print('getLogFileSize: ${size.length}');
    return size.length;
  }

  /// delete our log file
  void deleteLogFile() async {
    // final f =
    _deletedLogs = true;
    await fileManager.clearLogFile();
    await fileManager.clearLogFileAppend();

    fileManager.readLogData().then((value) {
      if (value.isEmpty) {
        logger.d("deleted logfile");
        // _blocks = [];
        _blockchain = Blockchain(time: 'init time', blocks: []);
        _logLineList.list = [];

        _lifeTimeInSeconds = 0;
        _appUsageInSeconds = 0;

        _blockHeight = 0;

        _deletedLogFile = true;
        // saveLogs();
        // _createFirstBlock();
      } else {
        logger.w("log file could not be deleted: ${value.length}");
      }
    });
  }

  /// verify the log files entries using the log key and block's
  /// previous hash and mac entries
  Future<bool?> verifyLogFile() async {
    logger.d("verifyLogFile");
    // tokenModel.bugTokens = 0;
    try {
      final logs = await fileManager.readLogData(); //.then((value) async {
      if (logs != null && logs.isNotEmpty) {
        _latestLogSizeInBytes = logs.length;
        _initialLogSizeInBytes = logs.length;
        _initialLogSizeInKilobytes = logs.length / 1024;
        _initialLogSizeInMegabytes = logs.length / 1048576;
        _initialLogSizeInGigabytes = logs.length / 1073741824;
        logger.d(
            'initialize retrieved data: $_initialLogSizeInBytes bytes, $_initialLogSizeInKilobytes kB, $_initialLogSizeInMegabytes MB, $_initialLogSizeInGigabytes Gb');

        // print(
        //     'is file size less than limit: ${_initialLogSizeInBytes <=
        //         _logFileLimitSize}');

        _blockchain = Blockchain.fromRawJson(logs);
        _blockHeight = _blockchain.blocks.length;
        var genesisTime =
            DateTime.parse(_blockchain.blocks.first.logList.list.first.time);
        var activeTime =
            DateTime.parse(_blockchain.blocks.last.logList.list.last.time);

        /// extra time check just in case
        if (!genesisTime.isAfter(DateTime.parse(_minCreationTime))) {
          logger.w('invalid time: failed to verify log');
          return false;
        }

        _lifeTimeInSeconds = activeTime.difference(genesisTime).inSeconds;
        // print('lifetime: $_lifeTimeInSeconds');

        logger.d('blockchain: $_blockHeight blocks, time: ${_blockchain.time}');

        final logKey = base64.encode(cryptor.logSecretKeyBytes);

        // blocks that have a bug reported message in them from the app
        var bugBlocks = [];

        if (logKey != null && logKey.isNotEmpty) {
          // final blockHash = hasher.sha256Hash(logLineJsonString);

          // print('logKey: ${cryptor.logSecretKeyBytes}');
          // print('mac log with key: $logKey');
          // final blockMac = await digester.hmac(blockHash,logKey);

          var totalNumLines = 0;
          var macsVerified = true;
          _appUsageInSeconds = 0;
          for (var block in _blockchain.blocks) {
            // print(
            //     'iterating block #: ${block.blockNumber}, time: ${block
            //         .time}');
            // print('iterating block index #: $index');
            // print('block hash: ${block.hash}');
            // print('block mac: ${block.mac}');

            var timeA = DateTime.parse(block.logList.list.first.time);
            var timeB = DateTime.parse(block.logList.list.last.time);
            //
            // print("${timeB.difference(timeA).inSeconds} seconds");

            _appUsageInSeconds += timeB.difference(timeA).inSeconds;

            var hasReportedBug = false;

            final numLogLines = block.logList.list.length;
            // print('numLogLines: $numLogLines');
            totalNumLines += numLogLines;

            final logLines = block.logList;
            final logLineJsonString = logLines.toRawJson();

            final blockHash = hasher.sha256Hash(logLineJsonString);
            final blockMac = await digester.hmac(blockHash, logKey);
            // print('blockMac: ${base64.encode(blockMac)}');

            if (block.mac != base64.encode(blockMac)) {
              logger.e("Block Mac does not equal: ${block.blockNumber}");
              macsVerified = false;
            }
            // else {
            //   logger.d("Block Macs equal!!!");
            // }

            for (var line in block.logList.list) {
              // print('line: ${line.time} : ${line.callingFunction}: ${line
              //     .message}');
              if (line.message == "BUG REPORTED 🐞" && !hasReportedBug) {
                hasReportedBug = true;
                bugBlocks.add(block.blockNumber);
              }
            }
          }

          // print("appUsage: $_appUsageInSeconds seconds");
          logger.d('verified: $macsVerified, totalNumLines: $totalNumLines');
          // logger.d('bug Blocks: $bugBlocks');

          return macsVerified;
        } else {
          logger.e("Error: logKey missing for verifying logs");
        }
      } else {
        logger.e("Error: Cannot verify log file");
      }

      return false;
    } catch (e) {
      logger.d("Error: Cannot verify log file: $e");
      log("LogManager", "verifyLogs", "Error: Cannot verify log file: $e");
      return false;
    }
  }
}
