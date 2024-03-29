import 'dart:io';

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../helpers/AppConstants.dart';
import '../screens/show_log_detail_screen.dart';
import '../managers/LogManager.dart';
import '../managers/FileManager.dart';
import '../managers/SettingsManager.dart';
import 'home_tab_screen.dart';


class ShowLogsScreen extends StatefulWidget {
  const ShowLogsScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/show_logs_screen';

  @override
  State<ShowLogsScreen> createState() => _ShowLogsScreenState();
}

class _ShowLogsScreenState extends State<ShowLogsScreen> with WidgetsBindingObserver {
  List<Block> _blocks = [];
  List<String> _timeLapses = [];
  List<int> sessionTimes = [];

  int _selectedIndex = 3;

  bool _isDarkModeEnabled = false;

  late ScrollController _controller = ScrollController();

  final _fileManager = FileManager();
  final _logManager = LogManager();
  final _settingsManager = SettingsManager();


  @override
  void initState() {
    super.initState();

    /// add observer for app lifecycle state transitions
    WidgetsBinding.instance.addObserver(this);

    _logManager.log("ShowLogsScreen", "initState", "initState");

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;

    _readLogs();
  }

  Future<void> _readLogs() async {
    final logData = await _fileManager.readLogDataAppend();
    // _logManager.logger.wtf("_readLogs: $logData");

    final blockSplit = logData.split("\n");
    _blocks = [];

    try {
        if (logData != null) {
          if (logData.isNotEmpty) {
            for (var iblock in blockSplit) {
              /// if we reach end of array with no other object, break out
              if (iblock
                  .replaceAll(" ", "")
                  .length == 0) {
                break;
              }

              var block = Block.fromRawJson(iblock);

              _blocks.add(block);
            }

            sessionTimes = [];
            _blocks.sort((a, b) {
              return a.time.compareTo(b.time);
            });

            setState(() {
              _blocks.forEach((element) {
                // _logManager.logger.wtf("${element.toRawJson()}");
                final a = DateTime.parse(element.logList.list.first.time);
                final b = DateTime.parse(element.logList.list.last.time);

                final dt = b
                    .difference(a)
                    .inSeconds;
                  sessionTimes.add(dt);
                });
              });

              await _logManager.verifyLogFile().then((value) {
            });
          }
        }

        buildTimeLapse();
      } catch (e) {
        _logManager.logger.wtf("blockSplit Error: $e");
      }
  }

  void buildTimeLapse() {
    int timeLapseIndex = 0;
    int blockIndex = 0;
    String currentTimeLapseString = '';
    _timeLapses = [];
    List<int> timeIntervals = [];
    List<int> windowTimeIntervals = [];

    DateTime firstTime = DateTime.now();
    DateTime secondTime = DateTime.now();

    for (var iblock in _blocks) {
      // print('new block......................');
      windowTimeIntervals.add(999999999);
      blockIndex += 1;
      timeIntervals = [];
      for (var ilist in iblock.logList.list) {
        if (timeLapseIndex == 0) {
          firstTime = DateTime.parse(ilist.time);
          secondTime = DateTime.parse(ilist.time);
          timeIntervals.add(0);
        } else {
          secondTime = DateTime.parse(ilist.time);
          timeIntervals.add(secondTime.difference(firstTime).inMilliseconds);
        }

        if (timeLapseIndex > 0) {
          windowTimeIntervals.add(timeIntervals[timeLapseIndex] -
              timeIntervals[(timeLapseIndex - 1)]);
        }
        // else {
        // windowTimeIntervals.add(999999999);
        // }

        // print('t:${secondTime.difference(firstTime).inMilliseconds}');

        final msg = ilist.message;
        // final line = '${ilist.callingFunction}:\n$msg';

        // final hasFailure = msg.contains("failure");
        final validPinCode = msg.contains("Valid Pin Code");
        final invalidPinCode = msg.contains("Invalid Pin Code");

        final validBiometrics = msg.contains("Authenticated Biometrics: true");
        // final validBiometrics = msg.contains("Authenticated Biometrics: true");

        final validPassword = msg.contains("deriveKeyCheck: true");
        final invalidPassword = msg.contains("deriveKeyCheck: false");
        // final screenChange = msg.contains("initState");
        // final appLifecycleState = msg.contains("AppLifecycleState");
        // final savedItem = line.contains("KeychainManager.saveItem:🧬");

        if (validBiometrics) {
          currentTimeLapseString += "🧬";
        } else if (validPassword) {
          currentTimeLapseString += "🔑";
        } else if (validPinCode) {
          currentTimeLapseString += "🅿️";
        } else if (invalidPinCode) {
          currentTimeLapseString += "❌";
        } else if (invalidPassword) {
          currentTimeLapseString += "❌";
        }

        timeLapseIndex += 1;
      }
      _timeLapses.add(currentTimeLapseString);
      currentTimeLapseString = '';
      timeLapseIndex = 0;
    }

    setState(() {});
  }

  /// track the lifecycle of the app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.inactive:
      // _logManager.log("ShowLogsScreen", "didChangeAppLifecycleState",
      //     "AppLifecycleState: inactive");
        break;
      case AppLifecycleState.resumed:
      // _logManager.log("ShowLogsScreen", "didChangeAppLifecycleState",
      //     "AppLifecycleState: resumed");
        await _readLogs();
        break;
      case AppLifecycleState.paused:
      // _logManager.log("ShowLogsScreen", "didChangeAppLifecycleState",
      //     "AppLifecycleState: paused");
        break;
      case AppLifecycleState.detached:
      // _logManager.log("ShowLogsScreen", "didChangeAppLifecycleState",
      //     "AppLifecycleState: detached");
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void dispose() {
    super.dispose();

    WidgetsBinding.instance.removeObserver(this);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? (Platform.isAndroid ? (AppConstants.useMaterial3 ? Colors.black12 : Colors.black54) : (AppConstants.useMaterial3 ? Colors.black26 : Colors.black54)) : Colors.white70, //Colors.blue[50],//Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : Colors.blueAccent,
        leading: BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
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
        itemCount: _timeLapses.length,
        controller: _controller,
        itemBuilder: (context, index) {
          return ListTile(
            isThreeLine: _timeLapses[index].isNotEmpty ? true : false,
            title: Text(
              '#${index + 1}: ${DateFormat('yyyy-MM-dd  hh:mm a').format(DateTime.parse(_blocks[index].time))}\n'
                  '${sessionTimes[index]} seconds\n'
                  'size: ${(_blocks[index].toRawJson().length/1024).toStringAsFixed(2)} KB',
              style: TextStyle(
                color: _isDarkModeEnabled ? Colors.white : null,
              ),
            ),
            subtitle: _timeLapses[index].isNotEmpty ? Text(
              _timeLapses.length > 0 ? _timeLapses[index] : "",
              style: TextStyle(
                color: _isDarkModeEnabled ? Colors.white : null,
              ),
            ) : null,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShowLogDetailScreen(
                    block: _blocks[index],
                  ),
                  fullscreenDialog: true,
                ),
              ).then((value) {
                _readLogs();
              });
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 2.0,
        currentIndex: _selectedIndex,
        selectedItemColor:
        _isDarkModeEnabled ? Colors.white : Colors.white,
        unselectedItemColor: Colors.green,
        unselectedIconTheme: IconThemeData(color: Colors.greenAccent),
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(
              Icons.star,
              color: Colors.grey,
            ),
            label: 'Favorites',
            backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
            activeIcon: Icon(
              Icons.star,
              color:
              _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
            ),
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.category,
              color: Colors.grey,
            ),
            label: 'Categories',
            backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
            activeIcon: Icon(
              Icons.category,
              color:
              _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
            ),
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.discount,
              color: Colors.grey,
            ),
            label: 'Tags',
            backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
            activeIcon: Icon(
              Icons.discount,
              color:
              _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
            ),
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.settings,
              color: Colors.grey,
            ),
            label: 'Settings',
            backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
            activeIcon: Icon(
              Icons.settings,
              color:
              _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
            ),
          ),
        ],
        onTap: _onItemTapped,
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    Navigator.of(context)
        .popUntil((route) => route.settings.name == HomeTabScreen.routeName);

    _settingsManager.changeRoute(index);
  }
}
