import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helpers/HearbeatTimer.dart';
import '../helpers/InactivityTimer.dart';

import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/Cryptor.dart';
import '../screens/welcome_tags_screen.dart';
import '../screens/welcome_categories_screen.dart';
import '../screens/lock_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/favorites_list_screen.dart';

class HomeTabScreen extends StatefulWidget {
  const HomeTabScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/home_tab_screen';

  @override
  State<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isDarkModeEnabled = false;
  bool _isOnLockScreen = false;

  List<Widget> _widgetOptions = [];

  late StreamSubscription darkModeChangedSubscription;
  late StreamSubscription selectRouteSubscription;
  late StreamSubscription inactivityLogoutSubscription;

  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _cryptor = Cryptor();
  // final _geolocationManager = GeoLocationManager();

  final _heartbeatTimer = HeartbeatTimer();
  final _inactivityTimer = InactivityTimer();

  @override
  void initState() {
    super.initState();

    _logManager.log("HomeTabScreen", "initState", "initState");
    // _logManager.logger.d("HomeTabScreen - initState");

    // DeviceManager().initialize();

    // _logManager.logger.d("deviceData: ${DeviceManager().deviceData}");
    // _logManager.logger.d("deviceData: ${_settingsManager.deviceManager.deviceData}");

    _settingsManager.setIsOnLockScreen(false);

    _heartbeatTimer.initialize();

    _inactivityTimer.startInactivityTimer();

    /// TODO: un/comment this for geo location feature
    // if (_geolocationManager.geoLocationUpdate == null) {
    //   _geolocationManager.initialize();
    // }

    if (_settingsManager.isRecoveredSession) {

      Future.delayed(Duration.zero, () {
        _showRecoveryInfoDialog();
      });
    }

    /// add observer for app lifecycle state transitions
    WidgetsBinding.instance.addObserver(this);

    /// set the last selected tab
    setState(() {
      _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;
      _selectedIndex = _settingsManager.currentTabIndex;
    });

    _widgetOptions = <Widget>[
      FavoritesListScreen(),
      WelcomeCategoriesScreen(),
      WelcomeTagsScreen(),
      SettingsScreen(),
    ];

    darkModeChangedSubscription =
        _settingsManager.onDarkModeEnabledChanged.listen((darkModeEnabled) {
      // print("darkModeChangedSubscription: $darkModeEnabled");
      /// refresh UI
      if (mounted) {
        setState(() {
          _isDarkModeEnabled = darkModeEnabled;
        });
      }
    });

    selectRouteSubscription =
        _settingsManager.onSelectedRouteChanged.listen((routeIndex) {
      // print("onSelectedRouteChanged: $routeIndex");
      /// refresh UI
      if (mounted) {
        setState(() {
          _selectedIndex = routeIndex;
          _settingsManager.setCurrentTabIndex(routeIndex);
        });
      }
    });

    inactivityLogoutSubscription =
        _settingsManager.onInactivityLogoutRecieved.listen((value) async {
      // print("HomeTabScreen: onInactivityLogoutRecieved: $value");

      // final isScanning = _settingsManager.isScanningQRCode;
      if (!_isOnLockScreen) {
        // pop the qr code scan view...doesnt work
        // print("is scanning: ${_settingsManager.isScanningQRCode}");
        //
        // if (_settingsManager.isScanningQRCode) {
        //   print("pop screen");
        //   Navigator.of(context).pop();
        //   _settingsManager.setIsScanningQRCode(false);
        // }

        // Navigator.of(context).pop();
        /// stop heartbeats
        HeartbeatTimer().stopHeartbeatTimer();

        _inactivityTimer.stopInactivityTimer();

        _settingsManager.setIsOnLockScreen(true);

        /// save logs
        _logManager.setIsSavingLogs(true);
        await _logManager.saveLogs();
        _isOnLockScreen = true;

        _cryptor.clearAllKeys();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LockScreen(),
            fullscreenDialog: true,
          ),
        ).then((value) {
          _settingsManager.setIsOnLockScreen(false);

          _inactivityTimer.startInactivityTimer();

          setState(() {
            _isOnLockScreen = false;
          });
        });
      }
    });
  }

  void _showRecoveryInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Recovery Mode'),
        content: Text(
            "You are allowed to change the master password during this session.  If you forgot it change it now."),
        actions: <Widget>[
          ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: Text('Okay'))
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();

    WidgetsBinding.instance.removeObserver(this);

    darkModeChangedSubscription.cancel();
    selectRouteSubscription.cancel();
    inactivityLogoutSubscription.cancel();
  }

  /// track the lifecycle of the app
  /// TODO: Use StreamSubscription to trigger on clear Clipboard after sensitive field is copied
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.inactive:
        // print("INACTIVE-------------------------------");
        // _logManager.log("HomeTabScreen", "didChangeAppLifecycleState",
        //     "AppLifecycleState: inactive");
        // _logManager.logger.d("AppLifecycleState: inactive - HomeTabScreen");
        // Navigator.of(context).pop();

        /// Save logs here...
        /// Tried saving on AppLifecycleState.paused but it fails and
        /// clears the log file data when app is force closed while in foreground.
        /// This seems to only happen when app is in prod/release mode and not
        /// in build/debug mode, which is very odd...
        _logManager.setIsSavingLogs(true);

        await _logManager.saveLogs();

        break;
      case AppLifecycleState.resumed:
        // _logManager.log("HomeTabScreen", "didChangeAppLifecycleState",
        //     "AppLifecycleState: resumed");
        // _logManager.logger.d("AppLifecycleState: resumed - HomeTabScreen");

        /// we want to only clear the clipboard after they have copied from the app and
        /// are coming back into the app, not every time they come back in.
        ///
        /// read clipboard and if theres data clear it
        if (_settingsManager.didCopyToClipboard) {
          // print("resumed: didCopyToClipboard");
          Clipboard.getData("text/plain").then((value) {
            final data = value?.text;
            if (data != null) {
              // print("resumed: clear data");
              Clipboard.setData(ClipboardData(text: ""));
            }
            _settingsManager.setDidCopyToClipboard(false);
          });
        }

        break;
      case AppLifecycleState.paused:
        // _logManager.log("HomeTabScreen", "didChangeAppLifecycleState",
        //     "AppLifecycleState: paused");
        // _logManager.logger.d("AppLifecycleState: paused - HomeTabScreen");

        if (_settingsManager.isLockOnExitEnabled &&
            !_isOnLockScreen &&
            !_settingsManager.isScanningQRCode) {
          _settingsManager.setIsOnLockScreen(true);

          /// stop heartbeats
          HeartbeatTimer().stopHeartbeatTimer();

          _inactivityTimer.stopInactivityTimer();

          setState(() {
            _isOnLockScreen = true;
          });

          _cryptor.clearAllKeys();

          _logManager.logger.wtf("AppLifecycleState: paused - HomeTabScreen - lock");

          /// Push LockScreen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LockScreen(),
              fullscreenDialog: true,
            ),
          ).then((value) {
            _settingsManager.setIsOnLockScreen(false);

            _inactivityTimer.startInactivityTimer();

            setState(() {
              _isOnLockScreen = false;
            });
          });
        }
        break;
      case AppLifecycleState.detached:
        _cryptor.clearAllKeys();
        // _logManager.logger.d("AppLifecycleState: detached");
        // _logManager.log("HomeTabScreen", "didChangeAppLifecycleState",
        //     "AppLifecycleState: detached");
        break;
      case AppLifecycleState.hidden:
        // _logManager.logger.d("AppLifecycleState: hidden - HomeTabScreen");
        // _logManager.log("HomeTabScreen", "didChangeAppLifecycleState",
        //     "AppLifecycleState: hidden");
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.grey : null,
      // appBar: AppBar(
      //   title: Text('BlackBox'),
      //   automaticallyImplyLeading: false,
      //   backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
      //   // leading: IconButton(
      //   //   icon: Icon(Icons.settings),
      //   //   color: _isDarkModeEnabled ? Colors.greenAccent : null,
      //   //   onPressed: () {
      //   //     Navigator.push(
      //   //       context,
      //   //       MaterialPageRoute(
      //   //         builder: (context) => SettingsScreen(),
      //   //         fullscreenDialog: true,
      //   //       ),
      //   //     ).then((value) {
      //   //       setState(() {
      //   //         _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;
      //   //       });
      //   //       // _updatePasswordItemList();
      //   //     });
      //   //   },
      //   // ),
      // ),
      body: _widgetOptions.elementAt(_selectedIndex),
      // Center(
      //   child: _widgetOptions.elementAt(_selectedIndex),
      // ),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 2.0,
        backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.white,
        // fixedColor: _isDarkModeEnabled ? Colors.black87 : Colors.white,
        // fixedColor: Colors.blue,
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

    _settingsManager.setCurrentTabIndex(index);
  }

}
