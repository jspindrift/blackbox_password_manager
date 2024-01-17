import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../helpers/AppConstants.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';


class ShowLogDetailScreen extends StatefulWidget {
  const ShowLogDetailScreen({
    Key? key,
    required this.block,
  }) : super(key: key);
  static const routeName = '/show_log_detail_screen';

  final Block block;

  @override
  State<ShowLogDetailScreen> createState() => _ShowLogDetailScreenState();
}

class _ShowLogDetailScreenState extends State<ShowLogDetailScreen> {
  bool _isDarkModeEnabled = false;

  late ScrollController _controller = ScrollController();

  final _logManager = LogManager();
  final _settingsManager = SettingsManager();


  @override
  void initState() {
    super.initState();
    _logManager.log("ShowLogDetailScreen", "initState", "initState");

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? (Platform.isAndroid ? (AppConstants.useMaterial3 ? Colors.black12 : Colors.black54) : (AppConstants.useMaterial3 ? Colors.black26 : Colors.black54)) : Colors.white70, //Colors.blue[50],//Colors.grey[100],
      appBar: AppBar(
        title: Text(
            "Block #${widget.block.blockNumber + 1}",
          style: TextStyle(
            color: _isDarkModeEnabled ? Colors.white : Colors.black,
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: CloseButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          Visibility(
            visible: true,
            child: IconButton(
              icon: Icon(Icons.upload),
              color: _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
              onPressed: () async {
                _controller.animateTo(
                  _controller.position.minScrollExtent,
                  duration: Duration(seconds: 1),
                  curve: Curves.ease,
                );
              },
            ),
          ),
          Visibility(
            visible: true,
            child: IconButton(
              icon: Icon(Icons.download_outlined),
              color: _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
              onPressed: () async {
                _controller.animateTo(
                  _controller.position.maxScrollExtent,
                  duration: Duration(seconds: 1),
                  curve: Curves.ease,
                );
              },
            ),
          ),
        ],
      ),
      body: ListView.separated(
          separatorBuilder: (context, index) => Divider(
            color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
          ),
          controller: _controller,
          itemCount: widget.block.logList.list.length,
          itemBuilder: (context, index) {
            // print('index: $index');
            // if (index == 0) {
            //   return ListTile(
            //     // shape: ShapeBorder,
            //     isThreeLine: true,
            //     title: Text('blockHeight: ${widget.block.logList[index]
            //         .callingFunction}:\n${widget.block.logList[index].message}'),
            //     subtitle: Text('time: ${widget.block.logList[index].time}'),
            //   );
            // }
            // if (index > 0) {
            final msg = widget.block.logList.list[index].message;
            final line =
                '${widget.block.logList.list[index].callingFunction}:\n$msg';

            final hasFailure = msg.contains("failure");
            final validPinCode = msg.contains("Valid Pin Code");
            final invalidPinCode = msg.contains("Invalid Pin Code");
            final setBiometricKey = msg.contains("creating biometric key");
            final validBiometrics =
                msg.contains("Authenticated Biometrics: true");
            final validPassword = msg.contains("deriveKeyCheck: true");
            final invalidPassword = msg.contains("deriveKeyCheck: false");
            final screenChange = msg.contains("initState");
            final appLifecycleState = msg.contains("AppLifecycleState");
            final savedItem = line.contains("KeychainManager.saveItem:");
            final bugReported = msg.contains("BUG REPORTED 🐞");
            final heartbeat = msg.contains("heartbeat");

            return ListTile(
              trailing: hasFailure
                  ? const Icon(
                      Icons.error,
                      color: Colors.redAccent,
                    )
                  : validPinCode
                      ? const Icon(
                          Icons.lock_open,
                          color: Colors.green,
                        )
                      : validBiometrics
                          ? const Icon(
                              Icons.lock_open,
                              color: Colors.green,
                            )
                          : validPassword
                              ? const Icon(
                                  Icons.lock_open,
                                  color: Colors.green,
                                )
                              : invalidPassword
                                  ? const Icon(
                                      Icons.lock_outline_sharp,
                                      color: Colors.redAccent,
                                    )
                                  : screenChange
                                      ? const Icon(
                                          Icons.screen_lock_portrait,
                                          color: Colors.blueAccent,
                                        )
                                      : appLifecycleState
                                          ? const Icon(
                                              Icons.screen_rotation_outlined,
                                              color: Colors.orange,
                                            )
                                          : savedItem
                                              ? const Icon(
                                                  Icons.save,
                                                  color: Colors.green,
                                                )
                                              : invalidPinCode
                                                  ? const Icon(
                                                      Icons.lock_outline_sharp,
                                                      color: Colors.redAccent,
                                                    )
                                                  : setBiometricKey
                                                      ? const Icon(
                                                          Icons.lock_clock,
                                                          color:
                                                              Colors.pinkAccent,
                                                        )
                                                      : bugReported
                                                          ? const Icon(
                                                              Icons
                                                                  .bug_report_rounded,
                                                              color: Colors
                                                                  .greenAccent,
                                                            )
                                                          : heartbeat
                                                              ? const Icon(
                                                                  Icons
                                                                      .monitor_heart,
                                                                  color: Colors
                                                                      .pinkAccent,
                                                                )
                                                              : null,
              isThreeLine: true,
              title: Text(
                line,
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 14,
                  color: _isDarkModeEnabled
                      ? (bugReported ? Colors.redAccent : Colors.white)
                      : null,
                ),
              ),
              subtitle: Padding(
                padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 0.0),
                child: Text(
                  "${DateFormat('yyyy-MM-dd  hh:mm:ss a').format(DateTime.parse(widget.block.logList.list[index].time))}\n${widget.block.logList.list[index].time}",
                  style: TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                    color: _isDarkModeEnabled
                        ? (bugReported ? Colors.redAccent : Colors.white54)
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
    );
  }

}
