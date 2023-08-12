import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helpers/HearbeatTimer.dart';
import '../helpers/InactivityTimer.dart';

import '../managers/GeolocationManager.dart';
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

  final logManager = LogManager();
  final settingsManager = SettingsManager();
  final cryptor = Cryptor();
  final geolocationManager = GeoLocationManager();

  final heartbeatTimer = HeartbeatTimer();
  final inactivityTimer = InactivityTimer();

  @override
  void initState() {
    super.initState();

    logManager.log("HomeTabScreen", "initState", "initState");
    // logManager.logger.d("HomeTabScreen - initState");

    // DeviceManager().initialize();

    // logManager.logger.d("deviceData: ${DeviceManager().deviceData}");
    // logManager.logger.d("deviceData: ${settingsManager.deviceManager.deviceData}");

    settingsManager.setIsOnLockScreen(false);

    heartbeatTimer.initialize();

    inactivityTimer.startInactivityTimer();

    /// TODO: un/comment this for geo location feature
    // if (geolocationManager.geoLocationUpdate == null) {
    //   geolocationManager.initialize();
    // }

    if (settingsManager.isRecoveredSession) {

      Future.delayed(Duration.zero, () {
        _showRecoveryInfoDialog();
      });
    }

    /// add observer for app lifecycle state transitions
    WidgetsBinding.instance.addObserver(this);

    /// set the last selected tab
    setState(() {
      _isDarkModeEnabled = settingsManager.isDarkModeEnabled;
      _selectedIndex = settingsManager.currentTabIndex;
    });

    _widgetOptions = <Widget>[
      FavoritesListScreen(),
      WelcomeCategoriesScreen(),
      WelcomeTagsScreen(),
      SettingsScreen(),
    ];

    darkModeChangedSubscription =
        settingsManager.onDarkModeEnabledChanged.listen((darkModeEnabled) {
      // print("darkModeChangedSubscription: $darkModeEnabled");
      /// refresh UI
      if (mounted) {
        setState(() {
          _isDarkModeEnabled = darkModeEnabled;
        });
      }
    });

    selectRouteSubscription =
        settingsManager.onSelectedRouteChanged.listen((routeIndex) {
      // print("onSelectedRouteChanged: $routeIndex");
      /// refresh UI
      if (mounted) {
        setState(() {
          _selectedIndex = routeIndex;
          settingsManager.setCurrentTabIndex(routeIndex);
        });
      }
    });

    inactivityLogoutSubscription =
        settingsManager.onInactivityLogoutRecieved.listen((value) async {
      // print("HomeTabScreen: onInactivityLogoutRecieved: $value");

      // final isScanning = settingsManager.isScanningQRCode;
      if (!_isOnLockScreen) {
        // pop the qr code scan view...doesnt work
        // print("is scanning: ${settingsManager.isScanningQRCode}");
        //
        // if (settingsManager.isScanningQRCode) {
        //   print("pop screen");
        //   Navigator.of(context).pop();
        //   settingsManager.setIsScanningQRCode(false);
        // }

        // Navigator.of(context).pop();
        /// stop heartbeats
        HeartbeatTimer().stopHeartbeatTimer();

        inactivityTimer.stopInactivityTimer();

        settingsManager.setIsOnLockScreen(true);

        /// save logs
        logManager.setIsSavingLogs(true);
        await logManager.saveLogs();
        _isOnLockScreen = true;

        cryptor.clearAllKeys();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LockScreen(),
            fullscreenDialog: true,
          ),
        ).then((value) {
          settingsManager.setIsOnLockScreen(false);

          inactivityTimer.startInactivityTimer();

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
        // logManager.log("HomeTabScreen", "didChangeAppLifecycleState",
        //     "AppLifecycleState: inactive");
        logManager.logger.d("AppLifecycleState: inactive - HomeTabScreen");
        // Navigator.of(context).pop();

        /// Save logs here...
        /// Tried saving on AppLifecycleState.paused but it fails and
        /// clears the log file data when app is force closed while in foreground.
        /// This seems to only happen when app is in prod/release mode and not
        /// in build/debug mode, which is very odd...
        logManager.setIsSavingLogs(true);

        await logManager.saveLogs();

        break;
      case AppLifecycleState.resumed:
        // logManager.log("HomeTabScreen", "didChangeAppLifecycleState",
        //     "AppLifecycleState: resumed");
        logManager.logger.d("AppLifecycleState: resumed - HomeTabScreen");

        /// we want to only clear the clipboard after they have copied from the app and
        /// are coming back into the app, not every time they come back in.
        ///
        /// read clipboard and if theres data clear it
        if (settingsManager.didCopyToClipboard) {
          // print("resumed: didCopyToClipboard");
          Clipboard.getData("text/plain").then((value) {
            final data = value?.text;
            if (data != null) {
              // print("resumed: clear data");
              Clipboard.setData(ClipboardData(text: ""));
            }
            settingsManager.setDidCopyToClipboard(false);
          });
        }

        break;
      case AppLifecycleState.paused:
        // logManager.log("HomeTabScreen", "didChangeAppLifecycleState",
        //     "AppLifecycleState: paused");
        logManager.logger.d("AppLifecycleState: paused - HomeTabScreen");

        if (settingsManager.isLockOnExitEnabled &&
            !_isOnLockScreen &&
            !settingsManager.isScanningQRCode) {
          settingsManager.setIsOnLockScreen(true);

          /// stop heartbeats
          HeartbeatTimer().stopHeartbeatTimer();

          inactivityTimer.stopInactivityTimer();

          setState(() {
            _isOnLockScreen = true;
          });

          cryptor.clearAllKeys();

          logManager.logger.wtf("AppLifecycleState: paused - HomeTabScreen - lock");

          /// Push LockScreen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LockScreen(),
              fullscreenDialog: true,
            ),
          ).then((value) {
            settingsManager.setIsOnLockScreen(false);

            inactivityTimer.startInactivityTimer();

            setState(() {
              _isOnLockScreen = false;
            });
          });
        }
        break;
      case AppLifecycleState.detached:
        cryptor.clearAllKeys();
        logManager.logger.d("AppLifecycleState: detached");
        // logManager.log("HomeTabScreen", "didChangeAppLifecycleState",
        //     "AppLifecycleState: detached");
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
      //   //         _isDarkModeEnabled = settingsManager.isDarkModeEnabled;
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

    settingsManager.setCurrentTabIndex(index);
  }

}
