import 'dart:io';

import 'package:flutter/material.dart';

import '../helpers/AppConstants.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/KeychainManager.dart';
import '../screens/show_logs_screen.dart';
import 'home_tab_screen.dart';


class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/diagnostics_screen';

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> with WidgetsBindingObserver {
  bool _isDarkModeEnabled = false;
  bool _logsAreValid = false;

  int _selectedIndex = 3;

  int _logFileSize = 0;
  double _logFileSizeScaled = 0.0;
  String _logFileSizeUnits = 'KB';

  int _numberOfPasswordItems = 0;
  int _passwordFileSize = 0;

  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _keyManager = KeychainManager();


  @override
  void initState() {
    super.initState();

    /// add observer for app lifecycle state transitions
    WidgetsBinding.instance.addObserver(this);

    _logManager.log("DiagnosticsScreen", "initState", "initState");

    _logManager.getLogFileSize().then((value) {
      setState(() {
        _logFileSize = value;
      });
    });

    _logManager.verifyLogFile().then((value) {
      setState(() {
        _logsAreValid = value!;
      });
    });

    _numberOfPasswordItems = _keyManager.numberOfPasswordItems;
    _passwordFileSize = _keyManager.passwordItemsSize;
    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;
    _selectedIndex = _settingsManager.currentTabIndex;
  }

  /// track the lifecycle of the app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.inactive:
      // _logManager.log("DiagnosticsScreen", "didChangeAppLifecycleState",
      //     "AppLifecycleState: inactive");
        break;
      case AppLifecycleState.resumed:
      // _logManager.log("DiagnosticsScreen", "didChangeAppLifecycleState",
      //     "AppLifecycleState: resumed");
        final fsize = await _logManager.getLogFileSize();
        final isValid = await _logManager.verifyLogFile();
        setState(() {
          _logFileSize = fsize;
          _logsAreValid = isValid!;
        });

        break;
      case AppLifecycleState.paused:
      // _logManager.log("DiagnosticsScreen", "didChangeAppLifecycleState",
      //     "AppLifecycleState: paused");
        break;
      case AppLifecycleState.detached:
      // _logManager.log("DiagnosticsScreen", "didChangeAppLifecycleState",
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
    double years = 0;
    double days = 0;
    double hours = 0;
    double minutes = 0;
    int seconds = _logManager.appUsageInSeconds;
    var elapsedTimeString = "$seconds seconds";

    if (seconds > 60) {
      minutes = (seconds/60);
    }
    if (minutes > 60) {
      hours = (minutes/60);
    }
    if (hours > 24) {
      days = (hours/24);
    }
    if (days >= 365) {
      years = (days/365);
    }

    if (days > 365) {
      elapsedTimeString = "${years.toStringAsFixed(2)} years";
    } else if (days > 1) {
      elapsedTimeString = "${days.toStringAsFixed(2)} days";
    } else if (hours > 1) {
      elapsedTimeString = "${hours.toStringAsFixed(2)} hours";
    } else if (minutes > 1) {
      elapsedTimeString = "${minutes.toStringAsFixed(2)} minutes";
    }

    _logManager.getLogFileSize().then((value) {
      _logFileSize = value;
    });

    _numberOfPasswordItems = _keyManager.numberOfPasswordItems;

    if (_logFileSize > 1024) {
      _logFileSizeScaled = _logFileSize / 1024;
      _logFileSizeUnits = "KB";
    }

    if (_logFileSize > 1048576) {
      _logFileSizeScaled = _logFileSize / 1048576;
      _logFileSizeUnits = "MB";
    }

    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? (Platform.isAndroid ? (AppConstants.useMaterial3 ? Colors.black12 : Colors.black54) : (AppConstants.useMaterial3 ? Colors.black26 : Colors.black54)) : Colors.white70, //Colors.blue[50],//Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Diagnostics",
          style: TextStyle(
            color: _isDarkModeEnabled ? Colors.white : Colors.white,
          ),
        ),
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
            visible: false,
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ShowLogsScreen(),
                  ),
                );
              },
              icon: Icon(
                Icons.list_alt,
                color: _isDarkModeEnabled ? Colors.greenAccent : null,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Card(
              color: _isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
              child: ListTile(
              tileColor: _isDarkModeEnabled ? Colors.black54 : null,
              title: Text(
                "Logs",
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : Colors.white,
                  fontSize: 18,
                ),
              ),
              // subtitle: Text("hello"),
              trailing: IconButton(
                icon: Icon(
                  Icons.arrow_forward,
                  color: _isDarkModeEnabled
                      ? Colors.greenAccent
                      : Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ShowLogsScreen(),
                    ),
                  ).then((value) {
                    _logManager.getLogFileSize().then((value) {
                      setState(() {
                        _logFileSize = value;
                      });
                    });

                    _logManager.verifyLogFile().then((value) {
                      setState(() {
                        _logsAreValid = value!;
                      });
                    });

                    _numberOfPasswordItems = _keyManager.numberOfPasswordItems;
                  });
                },
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ShowLogsScreen(),
                  ),
                );
              },
            ),
          ),),
          Divider(
            color: _isDarkModeEnabled ? Colors.greenAccent : null,
          ),
          Padding(
            padding: EdgeInsets.all(4.0),
            child: Card(
              color: _isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
              child: Column(
                children: <Widget>[
                  ListTile(
                    title: Text(
                      _logsAreValid ? "Valid Logs" : "Logs Are Invalid",
                      style: TextStyle(
                          color: _isDarkModeEnabled ? Colors.white : Colors.white),
                    ),
                  ),
                  Divider(
                      color: _isDarkModeEnabled ? Colors.greenAccent : null),
                  ListTile(
                    title: Text(
                      "Log file: ${(_logFileSizeScaled).toStringAsFixed(2)} $_logFileSizeUnits",
                      style: TextStyle(
                          color: _isDarkModeEnabled ? Colors.white : Colors.white,
                      ),
                    ),
                    subtitle: Padding(
                      padding: EdgeInsets.fromLTRB(0, 8, 8, 4),
                      child: Text(
                      // "App Time: ${_logManager.appUsageInSeconds} seconds\n$elapsedTimeString",
                      //   "App Time: $elapsedTimeString",
                        "App Time: $elapsedTimeString\n\nrate: ${((_logFileSize)/_logManager.appUsageInSeconds).toStringAsFixed(2)} bytes/sec",
                        style: TextStyle(
                          color: _isDarkModeEnabled ? Colors.white : Colors.white,
                          fontSize: 16,
                        ),
                     ),),
                  ),
                ],
              ),
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: _isDarkModeEnabled
                  ? BorderSide(color: Colors.greenAccent)
                  : null,
            ),
            child: Text(
              "Delete Logs",
              style: TextStyle(
                color:
                    _isDarkModeEnabled ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
            onPressed: () {
              _showConfirmDeleteLogsDialog();
            },
          ),
        ],
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

  void deleteLogs() {
    setState(() {
      _logManager.deleteLogFile();
    });
  }

  void _showConfirmDeleteLogsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // backgroundColor: _isDarkModeEnabled ? Colors.black : null,
        title: Text(
          'Delete Logs',
          // style: TextStyle(
          //   color: _isDarkModeEnabled ? Colors.white : Colors.black,
          // ),
        ),
        content: Text(
          'Are you sure you want to delete logs?  You will lose all verifiable tokens.',
          // style: TextStyle(
          //   color: _isDarkModeEnabled ? Colors.white : Colors.black,
          // ),
        ),
        actions: <Widget>[
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel'),
          ),
          OutlinedButton(
            style: TextButton.styleFrom(
              primary: Colors.redAccent,
            ),
            child: Text('Delete'),
            onPressed: () async {
              Navigator.of(context).pop();
              deleteLogs();
            },
          ),
        ],
      ),
    );
  }
}
