import 'dart:async';
import 'dart:math';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import '../managers/Cryptor.dart';
import '../managers/Digester.dart';
import '../managers/LogManager.dart';
import '../managers/FileManager.dart';
import '../managers/SettingsManager.dart';


class ShowLogDetail2Screen extends StatefulWidget {
  const ShowLogDetail2Screen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/show_log_detail2_screen';

  @override
  State<ShowLogDetail2Screen> createState() => _ShowLogDetail2ScreenState();
}

class _ShowLogDetail2ScreenState extends State<ShowLogDetail2Screen> {
  ScrollController _logScrollController = ScrollController();

  bool _isDarkModeEnabled = false;
  bool _logsAreVerifiable = false;
  bool _hasInvalidLogs = false;

  int _numberOfSessions = 0;
  int _numberOfLines = 0;

  String _numberKB = "";
  String _numberMB = "";
  int unit = 0;
  int invalidByteIndex = 0;

  String logSizeString = "0 bytes";
  String _appendedLogs = "";

  double _logFontSize = 8.0;

  final _fileManager = FileManager();
  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _cryptor = Cryptor();
  final _digester = Digester();


  @override
  void initState() {
    super.initState();

    _logManager.log("ShowLogDetail2Screen", "initState", "initState");

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;

    EasyLoading.showProgress(
        0.3,
        maskType: EasyLoadingMaskType.black,
        status: "Loading...",
    );

    Timer(Duration(milliseconds: 100), () async {
      await _readLogs();
    });
  }

  Future<void> _readLogs() async {
    _fileManager.readLogDataAppend().then((value) async {
      _numberKB = (value.length / 1024).toStringAsFixed(2);
      _numberMB = (value.length / pow(1024, 2)).toStringAsFixed(2);

      if (value.length / pow(1024, 2) > 1) {
        logSizeString = "$_numberMB MB";
      } else if (value.length / 1024 > 1) {
        logSizeString = "$_numberKB KB";
      }

      EasyLoading.showProgress(
          0.5,
          maskType: EasyLoadingMaskType.black,
          status: "Loading...",
      );

      // print("value.length: ${value.length}");
      // print("value.length: ${_numberKB} KB");
      // print("value.length: ${_numberMB} MB");

      final parts = value.split("\n");

      int index = 0;
      int lineNumber = 0;
      String appendedStringShow = "";
      String appendedStringValidate = "";

      invalidByteIndex = 0;

      for (var part in parts) {
        try {
          final isBlock = Block.fromRawJson(part.trim());
          if (isBlock != null) {
            if (!_hasInvalidLogs) {
              invalidByteIndex += part.length;
            }
            appendedStringValidate += isBlock.toRawJson() + "\n";

            appendedStringShow += part +
                "\n\n---------------------[$index]--------------------------\n\n";

            lineNumber += isBlock.logList.list.length;
          }

        } catch (e) {
          final parts2 = part.split(", ");
          if (parts2.length > 1) {
            _logsAreVerifiable = true;
            lineNumber += 1;
            if (!_hasInvalidLogs) {
              invalidByteIndex += part.length;
            }
            _numberOfSessions += 1;
            final hashCheck = parts2.first.replaceAll("hash: ", "");
            final macCheck = parts2.last.replaceAll("digest: ", "");
            // _logManager.logger.d("hashCheck: ${hashCheck}");
            // _logManager.logger.d("macCheck: ${macCheck}");
            // _logManager.logger.d("appendedStringValidate: $appendedStringValidate");
            final logHash = _cryptor.sha256(appendedStringValidate);
            // _logManager.logger.d('logHash: ${logHash}');

            final logKeyHex = hex.encode(_cryptor.logSecretKeyBytes);
            final logMac = await _digester.hmac(logHash, logKeyHex);
            final logMacHex = hex.encode(logMac);

            // _logManager.logger.d('logMac: ${logMacHex}');
            // _logManager.logger.d('logMac==MAC: ${logMacHex==macCheck}');

            if (logHash != hashCheck || logMacHex != macCheck) {
              setState(() {
                _hasInvalidLogs = true;
              });

              _logManager.logger.d(
                  "invalid hash/digest[$index]: $hashCheck, $logHash, $logMacHex");
            }

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
          _logManager.logger.d("logs invalid");
        } else {
          _logManager.logger.d("logs valid!!!");
        }
      }

      _logManager.logger.d("_numberOfSessions(startups): ${_numberOfSessions}");
      _logManager.logger.d(
          "lineNumber: ${lineNumber}: ${(lineNumber * 32 / (1024)).toStringAsFixed(2)} KB, ${lineNumber}: ${(lineNumber * 32 / (pow(1024, 2))).toStringAsFixed(2)} MB");

      setState(() {
        _numberOfLines = lineNumber;
        if (_hasInvalidLogs) {
          _logScrollController.jumpTo(invalidByteIndex.toDouble() / 8);
        } else {
          _logScrollController.jumpTo(value.length.toDouble());
        }
      });

      EasyLoading.dismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black54 : Colors.blue[50],//Colors.grey[100],
      appBar: AppBar(
        title: Text("$_numberOfLines lines\n $logSizeString"),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: CloseButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [],
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
