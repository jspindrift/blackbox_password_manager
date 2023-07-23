import 'dart:async';
import 'dart:math';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:intl/intl.dart';
import '../helpers/WidgetUtils.dart';
import '../managers/Cryptor.dart';
import '../managers/Digester.dart';
import '../managers/LogManager.dart';
import '../managers/FileManager.dart';
import '../managers/SettingsManager.dart';

class ShowLogDetail2Screen extends StatefulWidget {
  const ShowLogDetail2Screen({
    Key? key,
    // required this.block,
  }) : super(key: key);
  static const routeName = '/show_log_detail2_screen';

  // final Block block;

  @override
  State<ShowLogDetail2Screen> createState() => _ShowLogDetail2ScreenState();
}

class _ShowLogDetail2ScreenState extends State<ShowLogDetail2Screen> {
  TextEditingController _logTextController = TextEditingController();
  ScrollController _logScrollController = ScrollController();

  bool _isDarkModeEnabled = false;

  bool _logsAreVerifiable = false;
  bool _hasInvalidLogs = false;

  int _numberOfSessions = 0;
  int _numberOfLines = 0;

  String _numberKB = ""; //0.0;
  String _numberMB = ""; //0.0;
  int unit = 0;
  int invalidByteIndex = 0;

  String logSizeString = "0 bytes";

  double _logFontSize = 8.0;
  bool _logFontDecreaseEnable = true;
  bool _logFontIncreaseEnable = true;

  String _appendedLogs = "";

  final fileManager = FileManager();
  final logManager = LogManager();
  final settingsManager = SettingsManager();
  final cryptor = Cryptor();
  final digester = Digester();

  @override
  void initState() {
    super.initState();

    logManager.log("ShowLogDetail2Screen", "initState", "initState");

    _isDarkModeEnabled = settingsManager.isDarkModeEnabled;

    // EasyLoading.showProgress(0.1,maskType: EasyLoadingMaskType.black);
    EasyLoading.showProgress(0.3,
        maskType: EasyLoadingMaskType.black, status: "Loading...");

    // WidgetUtils.showSnackBarDuration(context, "loading data", Duration(seconds: 5));
    // WidgetUtils.showToastMessage("loading...", 3);

    Timer(Duration(milliseconds: 100), () async {
      await _readLogs();
    });
  }

  Future<void> _readLogs() async {
    fileManager.readLogDataAppend().then((value) async {
      _numberKB = (value.length / 1024).toStringAsFixed(2);
      _numberMB = (value.length / pow(1024, 2)).toStringAsFixed(2);

      if (value.length / pow(1024, 2) > 1) {
        // unit = 2;
        logSizeString = "$_numberMB MB";
      } else if (value.length / 1024 > 1) {
        // unit = 1;
        logSizeString = "$_numberKB KB";
      }
      // EasyLoading.showProgress(0.5,maskType: EasyLoadingMaskType.black);
      EasyLoading.showProgress(0.5,
          maskType: EasyLoadingMaskType.black, status: "Loading.");

      // print("value.length: ${value.length}");
      // print("value.length: ${_numberKB} KB");
      // print("value.length: ${_numberMB} MB");

      final parts = value.split("\n");
      final logHash = cryptor.sha256(value);
      // print('logHash: ${logHash}');
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
      int lineNumber = 0;

      // int numStartups = 0;
      String appendedStringShow = "";
      String appendedStringValidate = "";

      invalidByteIndex = 0;

      for (var part in parts) {
        // print("part[$index]: $part");

        try {
          final isLogLine = BasicLogList.fromRawJson(part.trim());
          if (isLogLine != null) {
            // print("decoded line: $isLogLine");
            // invalidByteIndex += 0;//part.length;
            if (!_hasInvalidLogs) {
              invalidByteIndex += part.length;
            }
            // appendedStringValidate += part + "\n";
            appendedStringValidate += isLogLine.toRawJson() + "\n";

            appendedStringShow += part +
                "\n\n---------------------[$index]--------------------------\n\n";
            // for (var line in isLogLine.list) {
            //   appendedStringShow += line.toRawJson() + "\n";
            //   lineNumber += 1;
            // }
            lineNumber += isLogLine.list.length;
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
          //   final logHash = hasher.sha256Hash(appendedStringShow);
          //   print('logHash: ${logHash}');
          //
          //   // appendedStringShow += part;
          //
          // }
        } catch (e) {
          final parts2 = part.split(", ");
          if (parts2.length > 1) {
            _logsAreVerifiable = true;
            lineNumber += 1;
            // invalidByteIndex += part.length;
            if (!_hasInvalidLogs) {
              invalidByteIndex += part.length;
            }
            _numberOfSessions += 1;
            // numStartups += 1;
            // print("parts2 first: ${parts2.first}");
            // print("parts2 last: ${parts2.last}");

            final hashCheck = parts2.first.replaceAll("hash: ", "");
            final macCheck = parts2.last.replaceAll("digest: ", "");
            // print("hashCheck: ${hashCheck}");
            // print("macCheck: ${macCheck}");

            // print("macline line[$index]: ${macline}");

            // print("appendedStringValidate: $appendedStringValidate");
            final logHash = cryptor.sha256(appendedStringValidate);
            // print('logHash: ${logHash}');
            // print('hashline==logHash: ${logHash == hashline}');

            // final logKey = base64.encode(cryptor.logSecretKeyBytes);
            // var cryptor;
            final logKeyHex = hex.encode(cryptor.logSecretKeyBytes);
            // final logMac = await digester.hmac(logHash, logKey);
            final logMac = await digester.hmac(logHash, logKeyHex);
            final logMacHex = hex.encode(logMac);
            // final logMacHex2 = hex.encode(logMac2);

            // print('logMac: ${logMacHex}');
            // print('logMac==MAC: ${logMacHex==macCheck}');

            if (logHash != hashCheck || logMacHex != macCheck) {
              setState(() {
                _hasInvalidLogs = true;
              });
              // invalidByteIndex = index;
              // print("! invalidByteIndex: $invalidByteIndex");

              logManager.logger.d(
                  "invalid hash/digest[$index]: $hashCheck, $logHash, $logMacHex");
            }
            // else {
            //
            // }
            // else {
            //   print("");
            // }

            if (index == parts.length - 1) {
              appendedStringShow += part;
              appendedStringValidate += part;
            } else {
              appendedStringShow += part + "\n";
              appendedStringValidate += part + "\n";
            }
          } else {
            lineNumber += 1;
            if (!_hasInvalidLogs) {
              invalidByteIndex += part.length;
            }

            if (index == parts.length - 1) {
              appendedStringShow += part;
              appendedStringValidate += part;
            } else {
              appendedStringShow += part + "\n";
              appendedStringValidate += part + "\n";
            }
          }
        }
        index += 1;
      }

      setState(() {
        _appendedLogs = appendedStringShow;
      });
      EasyLoading.showProgress(1.0,
          maskType: EasyLoadingMaskType.black, status: "Loading...");

      if (_logsAreVerifiable) {
        if (_hasInvalidLogs) {
          logManager.logger.d("logs invalid");
        } else {
          logManager.logger.d("logs valid!!!");
        }
      }

      logManager.logger.d("_numberOfSessions(startups): ${_numberOfSessions}");
      logManager.logger.d(
          "lineNumber: ${lineNumber}: ${(lineNumber * 32 / (1024)).toStringAsFixed(2)} KB, ${lineNumber}: ${(lineNumber * 32 / (pow(1024, 2))).toStringAsFixed(2)} MB");

      setState(() {
        _numberOfLines = lineNumber;

        // _logTextController.text = appendedStringShow;

        // _logTextController.
        if (_hasInvalidLogs) {
          // logManager.logger.d("scroll this: ${invalidByteIndex/8}");

          _logScrollController.jumpTo(invalidByteIndex.toDouble() / 8);
          // _logScrollController.jumpTo(invalidByteIndex.toDouble());

        } else {
          _logScrollController.jumpTo(value.length.toDouble());
        }
        // _logScrollController.(100);
      });

      EasyLoading.dismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text("$_numberOfLines lines\n $logSizeString"),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          // IconButton(onPressed: _logFontIncreaseEnable ? (){
          //   setState(() {
          //     if (_logFontSize < 24.0) {
          //       _logFontSize += 1.0;
          //       _logFontDecreaseEnable = true;
          //     } else {
          //       _logFontIncreaseEnable = false;
          //     }
          //   });
          // } : null,
          //   icon: Icon(
          //     Icons.add,
          //   color: Colors.greenAccent,
          // ),),
          // IconButton(onPressed: _logFontDecreaseEnable ? (){
          //   setState(() {
          //     if (_logFontSize > 6.0) {
          //       _logFontSize -= 1.0;
          //       _logFontIncreaseEnable = true;
          //     } else {
          //       _logFontDecreaseEnable = false;
          //     }
          //   });
          // } : null,
          //   icon: Icon(
          //   Icons.remove,
          //   color: Colors.greenAccent,
          // ),),
        ],
      ),
      body: SingleChildScrollView(
        controller: _logScrollController,
        physics: BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 32, 16, 64),
          child:
              // TextSpan(
              //     text: _appendedLogs,
              //     // children: [],
              // //     style: new TextStyle(
              // //   fontSize: _logFontSize, color: _isDarkModeEnabled ? Colors.white : Colors.black,
              // // ),
              // ),
          SelectableText(
            _appendedLogs,
            style: new TextStyle(
              fontSize: _logFontSize,
              color: _isDarkModeEnabled ? Colors.white : Colors.black,
            ),
          ),
          //     Text(
          //
          //   _appendedLogs,
          //   style: new TextStyle(
          //     fontSize: _logFontSize,
          //     color: _isDarkModeEnabled ? Colors.white : Colors.black,
          //   ),
          // ),
        ),
      ),
      //       Column(children: [
      //
      //
      //         SizedBox(height: 32,),
      //   // SingleChildScrollView(
      //   //   // child: Center(
      //   //     child:
      //         Container(
      //           height: 400,
      //           child:
      //       // Expanded(
      //       //   child:
      //         TextFormField(
      //         enabled: true,
      //         style: TextStyle(
      //           fontSize: 10.0,
      //           color: _isDarkModeEnabled ? Colors.white : null,
      //         ),
      //         decoration: InputDecoration(
      //           labelText: 'logs',
      //           // icon: Icon(
      //           //   Icons.edit_outlined,
      //           //   color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
      //           // ),
      //           hintStyle: TextStyle(
      //             fontSize: 18.0,
      //             color: _isDarkModeEnabled ? Colors.white : null,
      //           ),
      //           labelStyle: TextStyle(
      //             fontSize: 18.0,
      //             color: _isDarkModeEnabled ? Colors.white : null,
      //           ),
      //           enabledBorder: OutlineInputBorder(
      //             borderSide: BorderSide(
      //               color: _isDarkModeEnabled
      //                   ? Colors.greenAccent
      //                   : Colors.grey,
      //               width: 0.0,
      //             ),
      //           ),
      //           focusedBorder: OutlineInputBorder(
      //             borderSide: BorderSide(
      //               color: _isDarkModeEnabled
      //                   ? Colors.greenAccent
      //                   : Colors.grey,
      //               width: 0.0,
      //             ),
      //           ),
      //           disabledBorder: OutlineInputBorder(
      //             borderSide: BorderSide(
      //               color:
      //               _isDarkModeEnabled ? Colors.blueGrey : Colors.grey,
      //               width: 0.0,
      //             ),
      //           ),
      //         ),
      //         minLines: 20,
      //         maxLines: 21,
      //         readOnly: true,
      //         scrollController: _logScrollController,
      //         controller: _logTextController,
      //       ),
      //     ),
      // // ),
      //     // ),
      //   // ),
      //
      //         Text(
      //           "$_numberOfLines lines | $logSizeString",
      //           style: TextStyle(
      //             color: Colors.white,
      //           ),
      //         )
      //       ],),
      // Scrollbar(
      //   child: ListView.separated(
      //     separatorBuilder: (context, index) => Divider(
      //       color: _isDarkModeEnabled ? Colors.greenAccent : null,
      //     ),
      //     itemCount: widget.block.logList.list.length,
      //     itemBuilder: (context, index) {
      //       // print('index: $index');
      //       // if (index == 0) {
      //       //   return ListTile(
      //       //     // shape: ShapeBorder,
      //       //     isThreeLine: true,
      //       //     title: Text('blockHeight: ${widget.block.logList[index]
      //       //         .callingFunction}:\n${widget.block.logList[index].message}'),
      //       //     subtitle: Text('time: ${widget.block.logList[index].time}'),
      //       //   );
      //       // }
      //       // if (index > 0) {
      //       final msg = widget.block.logList.list[index].message;
      //       final line =
      //           '${widget.block.logList.list[index].callingFunction}:\n$msg';
      //
      //       final hasFailure = msg.contains("failure");
      //       final validPinCode = msg.contains("Valid Pin Code");
      //       final invalidPinCode = msg.contains("Invalid Pin Code");
      //       final setBiometricKey = msg.contains("creating biometric key");
      //       final validBiometrics =
      //       msg.contains("Authenticated Biometrics: true");
      //       final validPassword = msg.contains("deriveKeyCheck: true");
      //       final invalidPassword = msg.contains("deriveKeyCheck: false");
      //       final screenChange = msg.contains("initState");
      //       final appLifecycleState = msg.contains("AppLifecycleState");
      //       final savedItem = line.contains("KeychainManager.saveItem:");
      //       final bugReported = msg.contains("BUG REPORTED 🐞");
      //       final heartbeat = msg.contains("heartbeat");
      //
      //       return ListTile(
      //         trailing: hasFailure
      //             ? const Icon(
      //           Icons.error,
      //           color: Colors.redAccent,
      //         )
      //             : validPinCode
      //             ? const Icon(
      //           Icons.lock_open,
      //           color: Colors.green,
      //         )
      //             : validBiometrics
      //             ? const Icon(
      //           Icons.lock_open,
      //           color: Colors.green,
      //         )
      //             : validPassword
      //             ? const Icon(
      //           Icons.lock_open,
      //           color: Colors.green,
      //         )
      //             : invalidPassword
      //             ? const Icon(
      //           Icons.lock_outline_sharp,
      //           color: Colors.redAccent,
      //         )
      //             : screenChange
      //             ? const Icon(
      //           Icons.screen_lock_portrait,
      //           color: Colors.blueAccent,
      //         )
      //             : appLifecycleState
      //             ? const Icon(
      //           Icons.screen_rotation_outlined,
      //           color: Colors.orange,
      //         )
      //             : savedItem
      //             ? const Icon(
      //           Icons.save,
      //           color: Colors.green,
      //         )
      //             : invalidPinCode
      //             ? const Icon(
      //           Icons.lock_outline_sharp,
      //           color: Colors.redAccent,
      //         )
      //             : setBiometricKey
      //             ? const Icon(
      //           Icons.lock_clock,
      //           color:
      //           Colors.pinkAccent,
      //         )
      //             : bugReported
      //             ? const Icon(
      //           Icons
      //               .bug_report_rounded,
      //           color: Colors
      //               .greenAccent,
      //         )
      //             : heartbeat ? const Icon(
      //           Icons
      //               .monitor_heart,
      //           color: Colors
      //               .pinkAccent,
      //         )
      //             : null,
      //         isThreeLine: true,
      //         title: Text(
      //           line,
      //           style: TextStyle(
      //             fontWeight: FontWeight.normal,
      //             fontSize: 14,
      //             color: _isDarkModeEnabled
      //                 ? (bugReported ? Colors.redAccent : Colors.white)
      //                 : null,
      //           ),
      //         ),
      //         subtitle: Padding(
      //           padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 0.0),
      //           child: Text(
      //             "${DateFormat('yyyy-MM-dd  hh:mm:ss a').format(DateTime.parse(widget.block.logList.list[index].time))}\n${widget.block.logList.list[index].time}",
      //             style: TextStyle(
      //               fontWeight: FontWeight.normal,
      //               fontSize: 14,
      //               color: _isDarkModeEnabled
      //                   ? (bugReported ? Colors.redAccent : Colors.white54)
      //                   : null,
      //             ),
      //           ),
      //         ),
      //       );
      //     },
      //   ),
      // ),
    );
  }
}
