import 'package:flutter/material.dart';

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

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
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

  @override
  Widget build(BuildContext context) {
    // final seconds = _logManager.lifeTimeInSeconds;
    // final minutes = seconds/60;
    // final hours = seconds/3600;
    // final days = seconds/(24*3600);

    // final timeString = days > 0 ? "$days days" : "";

    _logManager.getLogFileSize().then((value) {
      _logFileSize = value;
    });

    // _logManager.verifyLogFile().then((value) {
    //   _logsAreValid = value!;
    // });

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
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text(''),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
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
              ))
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(8.0),
            child: ListTile(
              tileColor: _isDarkModeEnabled ? Colors.black54 : null,
              title: Text(
                "Logs",
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : null,
                  fontSize: 18,
                ),
              ),
              // subtitle: Text("hello"),
              trailing: IconButton(
                icon: Icon(
                  Icons.arrow_forward,
                  color: _isDarkModeEnabled
                      ? Colors.greenAccent
                      : Colors.blueAccent,
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
          ),
          Divider(
            color: _isDarkModeEnabled ? Colors.greenAccent : null,
          ),
          Padding(
            padding: EdgeInsets.all(4.0),
            child: Card(
              color: _isDarkModeEnabled ? Colors.black87 : null,
              child: Column(
                children: <Widget>[
                  ListTile(
                    title: Text(
                      _logsAreValid ? "Valid Logs" : "Logs Are Invalid",
                      style: TextStyle(
                          color: _isDarkModeEnabled ? Colors.white : null),
                    ),
                  ),
                  Divider(
                      color: _isDarkModeEnabled ? Colors.greenAccent : null),
                  ListTile(
                    title: Text(
                      "Log file: ${(_logFileSizeScaled).toStringAsFixed(2)} $_logFileSizeUnits",
                      style: TextStyle(
                          color: _isDarkModeEnabled ? Colors.white : null),
                    ),
                    subtitle: Text(
                      "lifetime: ${_logManager.lifeTimeInSeconds} seconds\nusage: ${_logManager.appUsageInSeconds} seconds\n${(100 * _logManager.appUsageInSeconds / _logManager.lifeTimeInSeconds).toStringAsFixed(2)}%",
                      style: TextStyle(
                          color: _isDarkModeEnabled ? Colors.white : null),
                    ),
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
        backgroundColor: _isDarkModeEnabled ? Colors.black12 : Colors.white,
        // fixedColor: Colors.white,
        currentIndex: _selectedIndex,
        selectedItemColor:
            _isDarkModeEnabled ? Colors.white : Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        unselectedIconTheme: IconThemeData(color: Colors.grey),
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(
              Icons.star,
              color: Colors.grey,
            ),
            label: 'Favorites',
            backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.white,
            activeIcon: Icon(
              Icons.star,
              color:
                  _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
            ),
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.category,
              color: Colors.grey,
            ),
            label: 'Categories',
            backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.white,
            activeIcon: Icon(
              Icons.category,
              color:
                  _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
            ),
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.discount,
              color: Colors.grey,
            ),
            label: 'Tags',
            backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.white,
            activeIcon: Icon(
              Icons.discount,
              color:
                  _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
            ),
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.settings,
              color: Colors.grey,
            ),
            label: 'Settings',
            backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.white,
            activeIcon: Icon(
              Icons.settings,
              color:
                  _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
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
    _logManager.deleteLogFile();
    setState(() {});
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
