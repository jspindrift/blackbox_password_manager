import 'dart:convert';
import 'dart:developer' as dev;
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
  BasicLogList logList;

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
      logList: BasicLogList.fromJson(json["logList"]),
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

  static const _minCreationTime = '2023-11-07T08:28:44.219169';

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

  BasicLogList _basicLogLineList = BasicLogList(list: []);

  Block _block = Block(
    blockNumber: 0,
    time: 'INIT TIME',
    hash: '',
    mac: '',
    logList: BasicLogList(list: []),
  );

  int _blockHeight = 0;
  int _lifeTimeInSeconds = 0;
  int _appUsageInSeconds = 0;

  int _logLineCount = 0;

  bool _validLogs = false;
  bool _hasInvalidLogs = false;
  bool _logsAreVerifiable = false;

  bool _deletedLogFile = false;
  bool _isSavingLogs = false;

  String _lastHash = "lastHash";
  String _lastMac = "lastMac";

  final fileManager = FileManager();
  final cryptor = Cryptor();
  final hasher = Hasher();
  final digester = Digester();
  final deviceManager = DeviceManager();
  final settingsManager = SettingsManager();


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


  LogManager._internal();


  void initialize2() async {
    logger.d("LogManager: initialize2");
    try {
      await settingsManager.initialize();
      final sessionNumber = settingsManager.sessionNumber;
      settingsManager.incrementSessionNumber();

      if (sessionNumber == 0) {
        logger.d("first time opening app");
      }

      fileManager.readLogDataAppend().then((value) async {
        final blockSplit = value.split("\n");

        _blockHeight = blockSplit.length - 1;
        int index = 0;
        String appendedString = "";
        for (var block in blockSplit) {
          // print("part[$index]: $part");

          try {
            final isBlock = Block.fromRawJson(block.trim());
            if (isBlock != null) {
              logger.d("decoded line: $isBlock");
              appendedString += block + "\n";
            }

            _lastHash = isBlock.hash;
            _lastMac = isBlock.mac;

          } catch (e) {
            // print("error: $e\n...cant decode line: ${part.length}: $part");
            final block2 = block.split(", ");
            if (block2.length > 1) {
              _logsAreVerifiable = true;
              // logger.d("block2 first: ${block2.first}");
              // logger.d("block2 last: ${block2.last}");

              final hashCheck = block2.first.replaceAll("hash: ", "");
              final macCheck = block2.last.replaceAll("digest: ", "");
              logger.d("hashline line[$index]: ${hashCheck}");
              logger.d("macline line[$index]: ${macCheck}");

              final logHash = hasher.sha256Hash(appendedString);
              // logger.d('logHash: ${logHash}');
              // logger.d('hashline==logHash: ${logHash == hashline}');

              // final logKey = base64.encode(cryptor.logSecretKeyBytes);
              final logKeyHex = hex.encode(cryptor.logSecretKeyBytes);
              // final logMac = await digester.hmac(logHash, logKey);
              final logMac = await digester.hmac(logHash, logKeyHex);
              final logMacHex = hex.encode(logMac);
              // final logMacHex2 = hex.encode(logMac2);

              // logger.d('logMac: ${logMacHex}');
              // logger.d('logMac==MAC: ${logMacHex==macCheck}');

              if (logHash != hashCheck || logMacHex != macCheck) {
                _hasInvalidLogs = true;
                logger.w(
                    "invalid hash/digest[$index]: $hashCheck, $logHash, $logMacHex");
              }

              if (index == blockSplit.length - 1) {
                appendedString += block;
              } else {
                appendedString += block + "\n";
              }
            } else {
              if (index == blockSplit.length - 1) {
                appendedString += block;
              } else {
                appendedString += block + "\n";
              }
            }
          }
          index += 1;
        }

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

            final appVersion = settingsManager.versionAndBuildNumber();
            final startTime = DateTime.now().toIso8601String();

            final logHash = hasher.sha256Hash(value);
            final logKeyHex = hex.encode(cryptor.logSecretKeyBytes);
            // print('logKeyHex cryptor: ${logKeyHex}');

            var logHexMacEncoded = "";
            try {
              final logHexMac = await digester.hmac(logHash, logKeyHex);
              logHexMacEncoded = hex.encode(logHexMac);
              // print('logHexMac: ${logHexMacEncoded}');
            } catch (e) {
              logger.e("Exception: $e");
            }

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
    if (!_isSavingLogs) {
      final timestamp = DateTime.now();

      // if (!timestamp.isAfter(DateTime.parse(_minCreationTime))) {
      //   print('invalid time: failed to log');
      //   return;
      // }
      // print("second: ${(timestamp.millisecondsSinceEpoch/(60*1000)).toInt()}");
      // print("minute: ${DateTime.now().toUtc().minute}");

      _logLineCount += 1;

      final logLine2 = BasicLogLine(
        time: timestamp.toIso8601String(),
        index: _logLineCount,
        callingFunction: "$callingClass.$callingFunction",
        message: message,
      );

      _basicLogLineList.list.add(logLine2);
    }
    // else {
    //   logger.wtf("isSavingLogs->TRUE: not appending");
    // }
  }

  void logLongMessage(String message) {
    dev.log(message);
  }

  /// save collected logs to the log file
  Future<void> saveLogs() async {
    logger.d("save Logs");
    if (_deletedLogs) {
      /// set back after the first time
      _basicLogLineList.list = [];
      _deletedLogs = false;
      return;
    }

    _isSavingLogs = true;

    try {
      final timestamp = DateTime.now();

      // if (!timestamp.isAfter(DateTime.parse(_minCreationTime))) {
      //   print('invalid time: failed to save logs');
      //   return;
      // }

      if (_basicLogLineList != null) {
        if (_blockHeight == 0) {
          try {
          final startTime = DateTime.now().toIso8601String();

          final deviceId = await deviceManager.getDeviceId();
          _logLineCount += 1;
          final logLine3 = BasicLogLine(
            time: timestamp.toIso8601String(),
            index: _logLineCount,
            callingFunction: "LogManager.saveLogs",
            message:
                "debug: $kDebugMode | deviceId: $deviceId | session: ${settingsManager.sessionNumber}",
          );

          _basicLogLineList.list.add(logLine3);

          final logLineJsonString = _basicLogLineList.toRawJson();

          final blockHash = hasher.sha256Hash(logLineJsonString);
          final logKey = base64.encode(cryptor.logSecretKeyBytes);
          final blockMac = await digester.hmac(blockHash, logKey);

          logger.d('saving blockHash: ${blockHash}');
          logger.d('saving block mac: ${hex.encode(blockMac)}');

          if (blockHash.isEmpty) {
            logger.wtf("blockHash is EMPTY");
          }

          if (blockMac.isEmpty) {
            logger.wtf("blockMac is EMPTY");
          }


          _block = Block(
            blockNumber: _blockHeight,
            time: startTime,
            logList: _basicLogLineList,
            hash: blockHash,
            mac: hex.encode(blockMac),
          );

          /// write to log file
          // await fileManager
          //     .writeLogDataAppend(_basicLogLineList.toRawJson() + "\n---[${settingsManager.sessionNumber}]--\n");
          await fileManager
              .writeLogDataAppend(_block.toRawJson() + "\n");
          _logLineCount = 0;

          /// shoudn't happen but if it does..custom splitting and saving
          // if (blockchainStringData.length >= _logFileLimitSize) {
          //   /// shoudn't happen
          //   logger.w("LogFile Size Limit Reached");
          // }

          _basicLogLineList.list = [];
          _blockHeight += 1;

          _isSavingLogs = false;
          } catch (e) {
            logger.wtf("Error313: $e");
          }
        }
        else {
          try {
            /// Blocks after genesis block
            final startTime = DateTime.now().toIso8601String();

            final lastHash = _block.hash;
            final lastMac = _block.mac;

            _logLineCount += 1;

            /// TODO: add different logging
            final logLine1 = BasicLogLine(
              time: timestamp.toIso8601String(),
              index: _logLineCount,
              callingFunction:
              "LogManager.saveLogs", //programInfo.callerFunctionName,
              message:
              "debug: $kDebugMode | session: ${settingsManager.sessionNumber}",
            );

            _basicLogLineList.list.add(logLine1);

            final logLine2 = BasicLogLine(
              time: timestamp.toIso8601String(),
              index: _logLineCount,
              callingFunction:
              "LogManager.saveLogs",
              message: "prevHash: $lastHash, prevMac: $lastMac",
            );

            _basicLogLineList.list.add(logLine2);

            final logLineJsonString = _basicLogLineList.toRawJson();

            _currentBlockLogSizeInBytes = logLineJsonString.length;
            _currentBlockLogSizeInKilobytes = logLineJsonString.length / 1024;

            final blockHash = hasher.sha256Hash(logLineJsonString);

            final logKey = base64.encode(cryptor.logSecretKeyBytes);
            final blockMac = await digester.hmac(blockHash, logKey);
            logger.d('saving blockHash: ${blockHash}');
            logger.d('saving block mac: ${hex.encode(blockMac)}');

            if (blockHash.isEmpty) {
              logger.wtf("blockHash is EMPTY");
            }

            if (blockMac.isEmpty) {
              logger.wtf("blockMac is EMPTY");
            }

            _block = Block(
              blockNumber: _blockHeight,
              time: startTime,
              logList: _basicLogLineList,
              hash: blockHash,
              mac: hex.encode(blockMac),
            );

            await fileManager
                .writeLogDataAppend(_block.toRawJson() + "\n");

            _basicLogLineList.list = [];
            _logLineCount = 0;

            /// check for empty list (concurrency error)
            if (_basicLogLineList.list.length == 0) {
              _isSavingLogs = false;
              return;
            }

            _basicLogLineList.list = [];
            _blockHeight += 1;
            _isSavingLogs = false;
          } catch (e) {
            logger.wtf("Error314: $e");
          }
        }
      }
    } catch (e) {
      logger.w("Error in LogManager: $e");
      log("LogManager", "saveLogs", "Error in LogManager: ${e.toString()}");
      _isSavingLogs = false;
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
    final size = await fileManager.readLogDataAppend();
    _initialLogSizeInBytes = size.length;
    // print('getLogFileSize: ${size.length}');
    return size.length;
  }

  /// delete our log file
  void deleteLogFile() async {
    // final f =
    _deletedLogs = true;
    await fileManager.clearLogFileAppend();
    // await fileManager.clearLogFileAppend();

    fileManager.readLogDataAppend().then((value) {
      if (value.isEmpty) {
        logger.d("deleted logfile");
        _basicLogLineList.list = [];
        _lifeTimeInSeconds = 0;
        _appUsageInSeconds = 0;
        _blockHeight = 0;
        _deletedLogFile = true;
      } else {
        logger.w("log file could not be deleted: ${value.length}");
      }
    });
  }

  /// verify the log files entries using the log key and block's
  /// previous hash and mac entries
  Future<bool?> verifyLogFile() async {
    logger.d("verifyLogFile");
    try {
      final logs = await fileManager.readLogDataAppend();
      if (logs != null && logs.isNotEmpty) {
        _latestLogSizeInBytes = logs.length;
        _initialLogSizeInBytes = logs.length;
        _initialLogSizeInKilobytes = logs.length / 1024;
        _initialLogSizeInMegabytes = logs.length / 1048576;
        _initialLogSizeInGigabytes = logs.length / 1073741824;
        logger.d('initialize retrieved data: $_initialLogSizeInBytes bytes\n'
                '$_initialLogSizeInKilobytes kB\n$_initialLogSizeInMegabytes MB\n'
                ' $_initialLogSizeInGigabytes Gb');


        final blockSplit = logs.split("\n");
        final logKey = base64.encode(cryptor.logSecretKeyBytes);

        // blocks that have a bug reported message in them from the app
        var bugBlocks = [];

        if (logKey != null && logKey.isNotEmpty) {
          var totalNumLines = 0;
          var macsVerified = true;
          _appUsageInSeconds = 0;

          try {
            for (var iblock in blockSplit) {
              /// if we reach end of array with no other object, break out
              if (iblock.replaceAll(" ", "").length == 0) {
                break;
              }
              var block = Block.fromRawJson(iblock.replaceAll("\n", ""));
              // logger.d("block: $block");

              logger.d('iterating blockNumber: ${block.blockNumber}\n'
                  'block hash: ${block.hash}\n'
                  'block mac: ${block.mac}');

              var timeA = DateTime.parse(block.logList.list.first.time);
              var timeB = DateTime.parse(block.logList.list.last.time);


              _appUsageInSeconds += timeB
                  .difference(timeA)
                  .inSeconds;

              logger.d("${timeB
                  .difference(timeA)
                  .inSeconds} seconds\n"
                  "app usage: $_appUsageInSeconds seconds");

              var hasReportedBug = false;

              final numLogLines = block.logList.list.length;
              // print('numLogLines: $numLogLines');
              totalNumLines += numLogLines;

              final logLines = block.logList;
              final logLineJsonString = logLines.toRawJson();

              final blockHash = hasher.sha256Hash(logLineJsonString);
              final blockMac = await digester.hmac(blockHash, logKey);
              // logger.d('blockMac to check: ${hex.encode(blockMac)}');

              if (block.mac != hex.encode(blockMac)) {
                logger.wtf("Block Mac does not equal: ${block.blockNumber}");
                macsVerified = false;
              }
              // else {
              //   logger.wtf("Block Mac  equal: ${block.blockNumber}");
              // }

              try {
                var index = 0;
                for (var line in block.logList.list) {
                  var a = DateTime.parse(line.time);
                  if (index + 1 < block.logList.list.length) {
                    var b = DateTime.parse(block.logList.list[index + 1].time);
                    // logger.d("diff[$index]: ${b
                    //     .difference(a)
                    //     .inMilliseconds}");
                  }

                  index++;
                  DateTime.parse(line.time);
                  if (line.message == "BUG REPORTED 🐞" && !hasReportedBug) {
                    hasReportedBug = true;
                    bugBlocks.add(block.blockNumber);
                  }
                }
              } catch (e) {
                logger.wtf("Block1 error: $e");
              }
            }
          } catch (e) {
            logLongMessage("Block2 error: $e\nblockSplit: ${blockSplit}");
          }

          logger.d('verified: $macsVerified, totalNumLines: $totalNumLines');
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
