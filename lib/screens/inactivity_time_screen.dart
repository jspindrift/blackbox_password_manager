import 'dart:io';

import 'package:flutter/material.dart';

import '../helpers/AppConstants.dart';
import '../helpers/InactivityTimer.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import 'home_tab_screen.dart';


class InactivityTimeScreen extends StatefulWidget {
  const InactivityTimeScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/inactivity_time_screen';

  @override
  State<InactivityTimeScreen> createState() => _InactivityTimeScreenState();
}


class _InactivityTimeScreenState extends State<InactivityTimeScreen> {
  bool _isDarkModeEnabled = false;

  int _selectedIndex = 0;

  int _selectedTimeIndex = 0;

  static const _timeList = [
    "1 minute",
    "2 minutes",
    "3 minutes",
    "5 minutes",
    "10 minutes",
    "15 minutes",
    "30 minutes",
    "1 hour"
  ];

  static const _timeIndexSeconds = [
    60,
    2 * 60,
    3 * 60,
    5 * 60,
    10 * 60,
    15 * 60,
    30 * 60,
    60 * 60
  ];

  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _inactivityTimer = InactivityTimer();


  @override
  void initState() {
    super.initState();

    _logManager.log("InactivityTimeScreen", "initState", "initState");

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;

    _selectedIndex = _settingsManager.currentTabIndex;

    _selectedTimeIndex =
        _timeIndexSeconds.indexOf(_settingsManager.inactivityTime);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? (Platform.isAndroid ? (AppConstants.useMaterial3 ? Colors.black12 : Colors.black54) : (AppConstants.useMaterial3 ? Colors.black26 : Colors.black54)) : Colors.blue[50],//Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Inactivity Time",
          style: TextStyle(
            color: _isDarkModeEnabled ? Colors.white : Colors.black,
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: ListView.separated(
        itemCount: _timeIndexSeconds.length,
        separatorBuilder: (context, index) => Divider(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
        ),
        itemBuilder: (context, index) {
          return Container(
            height: 50,
            child: ListTile(
              visualDensity: VisualDensity(vertical: 4),
              title: Text(
                _timeList[index],
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : null,
                ),
              ),
              trailing: Checkbox(
                value: (_selectedTimeIndex == index),
                fillColor: _isDarkModeEnabled
                    ? MaterialStateProperty.all<Color>(Colors.greenAccent)
                    : null,
                checkColor: _isDarkModeEnabled ? Colors.black : null,
                onChanged: (value) {
                  onTimeSelected(index);
                },
              ),
              onTap: () {
                onTimeSelected(index);
              },
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 2.0,
        backgroundColor: _isDarkModeEnabled ? Colors.black12 : Colors.white,
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

  void onTimeSelected(int index) async {
    /// settings save inactivity time
    ///
    await _settingsManager.saveInactivityTime(_timeIndexSeconds[index]);

    _logManager.log("InactivityTimeScreen", "onTimeSelected", "change inactivity time: ${_timeIndexSeconds[index]} seconds");

    _inactivityTimer.startInactivityTimer();

    setState(() {
      _selectedTimeIndex = index;
    });
  }
}
