import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../managers/LogManager.dart';
import '../managers/FileManager.dart';
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

  final fileManager = FileManager();
  final logManager = LogManager();
  final settingsManager = SettingsManager();

  @override
  void initState() {
    super.initState();

    logManager.log("ShowLogDetailScreen", "initState", "initState");

    _isDarkModeEnabled = settingsManager.isDarkModeEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text('Session #${widget.block.blockNumber + 1}'),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Scrollbar(
        child: ListView.separated(
          separatorBuilder: (context, index) => Divider(
            color: _isDarkModeEnabled ? Colors.greenAccent : null,
          ),
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
      ),
    );
  }
}
