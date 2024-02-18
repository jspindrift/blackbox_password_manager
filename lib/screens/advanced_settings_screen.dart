import 'dart:io';
import 'dart:async';

import 'package:dynamic_themes/dynamic_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pin_code_view/pin_code_view.dart';

import '../helpers/AppConstants.dart';
import '../managers/PostQuantumManager.dart';
import '../managers/WOTSManager.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/KeychainManager.dart';
import '../models/WOTSSignatureItem.dart';
import '../screens/show_logs_screen.dart';
import '../screens/settings_about_screen.dart';
import '../screens/diagnostics_screen.dart';
import '../screens/recovery_mode_screen.dart';
import '../screens/home_tab_screen.dart';


class AdvancedSettingsScreen extends StatefulWidget {
  const AdvancedSettingsScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/advanced_settings_screen';

  @override
  State<AdvancedSettingsScreen> createState() => _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState extends State<AdvancedSettingsScreen> {
  final _bugNotesTextController = TextEditingController();

  bool _isDarkModeEnabled = false;

  int _selectedIndex = 3;
  int _signCounter = 1;

  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _keyManager = KeychainManager();

  /// post quantum signing
  final _wotsManager = WOTSManager();
  final _postQuantumManager = PostQuantumManager();


  @override
  void initState() {
    super.initState();

    _logManager.log("AdvancedSettingsScreen", "initState", "initState");

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;

    _postQuantumManager.initialize();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    Navigator.of(context)
        .popUntil((route) => route.settings.name == HomeTabScreen.routeName);

    _settingsManager.changeRoute(index);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? (Platform.isAndroid ? (AppConstants.useMaterial3 ? Colors.black12 : Colors.black54) : (AppConstants.useMaterial3 ? Colors.black26 : Colors.black54)) : Colors.white70, //Colors.blue[50],//Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Advanced Settings",
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
      ),
      body: SingleChildScrollView(
        child: Container(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(0.0),
                child: ListTile(
                  enabled: true,
                  title: Text(
                    'About',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _isDarkModeEnabled ? Colors.white : null,
                    ),
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.fromLTRB(0, 4, 4, 4),
                    child: Text(
                      "Device and App Information",
                      style: TextStyle(
                        fontSize: 14,
                        // fontWeight: FontWeight.bold,
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.info,
                      color: _isDarkModeEnabled
                          ? Colors.greenAccent
                          : Colors.blueAccent,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsAboutScreen(),
                        ),
                      );
                    },
                  ),
                  // subtitle: Text('Tap to see advanced settings'),
                  onTap: () {
                    /// open the about screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsAboutScreen(),
                      ),
                    );
                  },
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              ),
              Visibility(
                visible: true,
                child: Padding(
                  padding: EdgeInsets.all(0.0),
                  child: ListTile(
                    enabled: true,
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
                        );
                      },
                    ),
                    title: Text(
                      'Diagnostics',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                    ),
                    subtitle: Text(
                      'Logging and other information',
                      style: TextStyle(
                        fontSize: 14,
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DiagnosticsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              ),
              Padding(
                padding: EdgeInsets.all(0.0),
                child: ListTile(
                  title: Text(
                    'Dark Mode',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _isDarkModeEnabled ? Colors.white : Colors.black,
                    ),
                  ),
                  enabled: true,
                  trailing: Switch(
                    value: _isDarkModeEnabled,
                    thumbColor: MaterialStateProperty.all<Color>(Colors.white),
                    trackColor: _isDarkModeEnabled
                        ? MaterialStateProperty.all<Color>(Colors.greenAccent)
                        : MaterialStateProperty.all<Color>(Colors.grey),
                    onChanged: (value) async {
                      setState(() {
                        _isDarkModeEnabled = !_isDarkModeEnabled;
                      });

                      await _settingsManager.saveDarkMode(_isDarkModeEnabled);

                      DynamicTheme.of(context)?.setTheme(_isDarkModeEnabled ? 1 : 0);

                      /// broadcast dark mode change to HomeTabScreen
                      _settingsManager.processDarkModeChange(_isDarkModeEnabled);
                    },
                  ),
                  onTap: () {
                    // print('dark mode');
                  },
                ),
              ),
              // Divider(
              //   color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              // ),
              // Padding(
              //   padding: EdgeInsets.all(0.0),
              //   child: ListTile(
              //     enabled: true,
              //     title: Text(
              //       'About',
              //       style: TextStyle(
              //         fontSize: 20,
              //         fontWeight: FontWeight.bold,
              //         color: _isDarkModeEnabled ? Colors.white : null,
              //       ),
              //     ),
              //     subtitle: Padding(
              //       padding: EdgeInsets.fromLTRB(0, 4, 4, 4),
              //       child: Text(
              //         "Device and App Information",
              //         style: TextStyle(
              //           fontSize: 14,
              //           // fontWeight: FontWeight.bold,
              //           color: _isDarkModeEnabled ? Colors.white : null,
              //         ),
              //       ),
              //     ),
              //     trailing: IconButton(
              //       icon: Icon(
              //         Icons.info,
              //         color: _isDarkModeEnabled
              //             ? Colors.greenAccent
              //             : Colors.blueAccent,
              //       ),
              //       onPressed: () {
              //         Navigator.push(
              //           context,
              //           MaterialPageRoute(
              //             builder: (context) => SettingsAboutScreen(),
              //           ),
              //         );
              //       },
              //     ),
              //     // subtitle: Text('Tap to see advanced settings'),
              //     onTap: () {
              //       /// open the about screen
              //       Navigator.push(
              //         context,
              //         MaterialPageRoute(
              //           builder: (context) => SettingsAboutScreen(),
              //         ),
              //       );
              //     },
              //   ),
              // ),
              // Divider(
              //   color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              // ),
              Visibility(
                visible: false,
                child: Padding(
                  padding: EdgeInsets.all(0.0),
                  child: ListTile(
                    enabled: true,
                    title: Text(
                      'BlackBox Subscriptions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                    ),
                    subtitle: Padding(
                      padding: EdgeInsets.fromLTRB(0, 4, 4, 4),
                      child: Text(
                        "Buy a subscription to access more features.",
                        style: TextStyle(
                          fontSize: 14,
                          // fontWeight: FontWeight.bold,
                          color: _isDarkModeEnabled ? Colors.white : null,
                        ),
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.money_outlined,
                        color: _isDarkModeEnabled
                            ? Colors.greenAccent
                            : Colors.blueAccent,
                      ),
                      onPressed: () {
                        // Navigator.push(
                        //   context,
                        //   MaterialPageRoute(
                        //     builder: (context) => PurchaseSubscriptionScreen(),
                        //   ),
                        // );
                      },
                    ),
                    // subtitle: Text('Tap to see advanced settings'),
                    onTap: () {
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => PurchaseSubscriptionScreen(),
                      //   ),
                      // );
                    },
                  ),
                ),
              ),
              // Padding(
              //   padding: EdgeInsets.all(0.0),
              //   child: ListTile(
              //     enabled: true,
              //     title: Text(
              //       'Emergency Kit',
              //       style: TextStyle(
              //         fontSize: 20,
              //         fontWeight: FontWeight.bold,
              //         color: _isDarkModeEnabled ? Colors.white : null,
              //       ),
              //     ),
              //     subtitle: Padding(
              //       padding: EdgeInsets.fromLTRB(0, 4, 4, 4),
              //       child: Text(
              //         "Backup your secret key for your vault.",
              //         style: TextStyle(
              //           fontSize: 14,
              //           // fontWeight: FontWeight.bold,
              //           color: _isDarkModeEnabled ? Colors.white : null,
              //         ),
              //       ),
              //     ),
              //     trailing: IconButton(
              //       icon: Icon(
              //         Icons.emergency,
              //         color: _isDarkModeEnabled
              //             ? Colors.greenAccent
              //             : Colors.blueAccent,
              //       ),
              //       onPressed: () {
              //         Navigator.push(
              //           context,
              //           MaterialPageRoute(
              //             builder: (context) => EmergencyKitScreen(),
              //           ),
              //         );
              //       },
              //     ),
              //     // subtitle: Text('Tap to see advanced settings'),
              //     onTap: () {
              //       /// open the about screen
              //       Navigator.push(
              //         context,
              //         MaterialPageRoute(
              //           builder: (context) => EmergencyKitScreen(),
              //         ),
              //       );
              //     },
              //   ),
              // ),
              // Divider(
              //   color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              // ),

              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              ),
              Visibility(
                visible: true,
                child: Padding(
                  padding: EdgeInsets.all(0.0),
                  child: ListTile(
                    enabled: true,
                    title: Text(
                      'Vault Recovery',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                    ),
                    subtitle: Padding(
                      padding: EdgeInsets.fromLTRB(0, 4, 4, 4),
                      child: Text(
                        "Exchange keys with friends in order to generate a recovery key for your vault.",
                        style: TextStyle(
                          fontSize: 14,
                          // fontWeight: FontWeight.bold,
                          color: _isDarkModeEnabled ? Colors.white : null,
                        ),
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.vpn_key,
                        color: _isDarkModeEnabled
                            ? Colors.greenAccent
                            : Colors.blueAccent,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecoveryModeScreen(),
                          ),
                        );
                      },
                    ),
                    // subtitle: Text('Tap to see advanced settings'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecoveryModeScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Visibility(
              visible: kDebugMode,
              child: Divider(
                  color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
                ),
              ),
              Visibility(
              visible: kDebugMode,
              child: Padding(
                  padding: EdgeInsets.all(0.0),
                  child: ListTile(
                    enabled: true,
                    title: Text(
                      'Report a bug',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                    ),
                    subtitle: Text(
                      'Tap to trigger an alert in the logs.',
                      style: TextStyle(
                        fontSize: 14,
                        // fontWeight: FontWeight.bold,
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.bug_report_rounded,
                        color: _isDarkModeEnabled
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),
                      onPressed: () {
                        _showConfirmFoundABugDialog();
                      },
                    ),
                    onTap: () {
                      _showConfirmFoundABugDialog();
                    },
                  ),
                ),
              ),
              Visibility(
                visible: kDebugMode,
                child: Divider(
                  color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
                ),
              ),
              Visibility(
                visible: kDebugMode,
                child: Padding(
                  padding: EdgeInsets.all(0.0),
                  child: ListTile(
                    enabled: true,
                    title: Text(
                      'Run tests',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                    ),
                    subtitle: Text(
                      'Tap to trigger tests',
                      style: TextStyle(
                        fontSize: 14,
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.transfer_within_a_station,
                        color: _isDarkModeEnabled
                            ? Colors.greenAccent
                            : Colors.green,
                      ),
                      onPressed: () async {
                        // await _runPostQuantumIntegrityTestWithReset();
                        await _runGigaWotsSignTestWithReset();
                      },
                    ),
                    onTap: () async {
                      // await _runPostQuantumIntegrityTest();
                      await _runGigaWotsSignTest();
                    },
                  ),
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              ),
              Padding(
                padding: EdgeInsets.all(12.0),
                child: ElevatedButton(
                  style: OutlinedButton.styleFrom(
                    side: _isDarkModeEnabled
                        ? BorderSide(color: Colors.greenAccent)
                        : BorderSide(color: Colors.black),
                  ),
                  child: Text(
                    'Delete Blackbox Data',
                    style: TextStyle(
                      color: _isDarkModeEnabled
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    ),
                  ),
                  onPressed: () {
                    _showConfirmDeleteAccountDialog();
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.0, 0, 16, 8),
                child: Text(
                  'Remove all Blackbox vault data from this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Visibility(
                visible: true,
                child: Divider(
                  color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
                ),
              ),
              Visibility(
                visible: kDebugMode,
                child: Padding(
                padding: EdgeInsets.fromLTRB(16.0, 16, 16, 32),
                child: ElevatedButton(
                  style: OutlinedButton.styleFrom(
                    side: _isDarkModeEnabled
                        ? BorderSide(color: Colors.greenAccent)
                        : BorderSide(color: Colors.black),
                    // backgroundColor: _isDarkModeEnabled ? Colors.transparent : Colors.blueAccent,
                  ),
                  child: Text(
                    'Delete Everything',
                    style: TextStyle(
                      color: _isDarkModeEnabled
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    ),
                  ),
                  onPressed: () {
                    _showConfirmDeleteEverythingDialog();
                  },
                ),
              ),),
            ],
          ),
        ),
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


  void _resetTestVariables() {
    _logManager.logger.d("_resetTestVariables");

    _signCounter = 1;
    _wotsManager.reset();
    _postQuantumManager.reset();
  }

  void _runTests() async {
    _logManager.logger.d("_runTests");

    /// set variables here
    final message = "hello world:${_wotsManager.lastBlockHash}";
    final kek = List.filled(32, 0);
    // final kak = List.filled(32, 1);
    // final ivg = List.filled(16, 0);

    /// Do some testing here...
    ///

    // final ctx = await _cryptor.superEncryption(kek, kak, ivg, message);
    // final ptx = await _cryptor.superDecryption(kek, kak, ivg, ctx);

    /// create WOTS top public key
    // _wotsManager.createTopPubKey(kek, 0);

    /// create WOTS signature
    final sigItem = await _wotsManager.signMessage(kek, _signCounter, message);
    // _logManager.logLongMessage("sigItem: ${sigItem?.toRawJson()}");

    /// verify WOTS signature
    final isValid = await _wotsManager.verifySignature(sigItem);
    _logManager.logger.d("isValid: ${isValid}");

    _signCounter++;
  }

  /// hybrid asymmetric and WOTS signing
  Future<void> _runPostQuantumIntegrityTest() async {
    _logManager.logger.d("_runPostQuantumTest");

    // await _postQuantumManager.postQuantumProjectIntegrityTest(256);

    /// TODO: uncomment this after to verify
    // await _postQuantumManager.postQuantumProjectIntegrityTestVerify();
  }

  Future<void> _runPostQuantumIntegrityTestWithReset() async {
    _resetTestVariables();

    await _runPostQuantumIntegrityTest();
  }

  /// hybrid asymmetric and WOTS signing
  Future<void> _runGigaWotsSignTest() async {
    _logManager.logger.d("_runPostQuantumTest");

    /// set variables here
    final message = "[$_signCounter]:hello world";
    final kek = List.filled(32, 0);

    /// Do some testing here...
    ///

    var wotsMessageData = WOTSMessageData(
        messageIndex: _signCounter,
        previousHash: _wotsManager.lastBlockHash,
        publicKey: _wotsManager.topPublicKey,
        nextPublicKey: _wotsManager.nextTopPublicKey,
        data: message,
    );

    // final ctx = await _cryptor.superEncryption(kek, kak, ivg, message);
    // final ptx = await _cryptor.superDecryption(kek, kak, ivg, ctx);

    /// create WOTS top public key
    // _wotsManager.createTopPubKey(kek, 0);

    /// create WOTS signature
    final sigItem = await _wotsManager.signGigaWotMessage(
        kek,
        "main",
        _wotsManager.lastBlockHash,
        wotsMessageData,
        256,
        false,
    );
    // _logManager.logLongMessage("sigItem: ${sigItem?.toRawJson()}");

    /// verify WOTS signature
    final isValid = await _wotsManager.verifyGigaWotSignature(sigItem);
    _logManager.logger.d("isValid[${_signCounter}]: ${isValid}");

    _signCounter++;
  }

  Future<void> _runGigaWotsSignTestWithReset() async {
    _resetTestVariables();

    await _runGigaWotsSignTest();
  }


  void _showConfirmDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // backgroundColor: _isDarkModeEnabled ? Colors.black : null,
        title: Text(
          'Delete Blackbox Data',
          // style: TextStyle(
          //   color: _isDarkModeEnabled ? Colors.white : Colors.black,
          // ),
        ),
        content: Text(
          'Are you sure you want to delete all Blackbox device data?',
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
            onPressed: () async {
              Navigator.of(context).pop();
              _showSecondConfirmDeleteAccountDialog();
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSecondConfirmDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        title: Text('Delete Blackbox Password Manager Data'),
        content: Text('Last Chance.  This will delete all device data.'),
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
            onPressed: () async {
              await _confirmedDeleteAccount();
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }


  /// delete the account items and encryption key and force user back
  /// to login screen to setup a new account
  Future<void> _confirmedDeleteAccount() async {
    final status = await _keyManager.deleteForBackup();
    if (status) {
      _settingsManager.removeAllPreferences();
      _settingsManager.postResetAppNotification();
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      _showErrorDialog('Delete account failed');
    }
  }


  /// TODO: get rid of this.  This is used for testing purposes
  Future<void> _confirmedDeleteEverything() async {
    final status = await _keyManager.deleteAll();
    if (status) {
      _settingsManager.removeAllPreferences();
      _settingsManager.postResetAppNotification();
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      _showErrorDialog('Delete everything failed');
    }
  }

  /// TODO: get rid of this.  This is used for testing purposes
  void _showConfirmDeleteEverythingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            "Delete Everything",
        ),
        content: Text(
            "Are you sure you want to delete everything?  This will delete everything except backups!",
        ),
        actions: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
                "Cancel",
              style: TextStyle(
                color: _isDarkModeEnabled ? Colors.white : Colors.black,
              ),
            ),
            ),
          ),
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor:
              MaterialStateProperty.all<Color>(Colors.redAccent),
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              _showDoubleConfirmDeleteEverythingDialog();
            },
            child: Text(
              "Delete Everything",
              style: TextStyle(
                color: _isDarkModeEnabled ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDoubleConfirmDeleteEverythingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Delete Everything?'),
        content: Text(
            'Are you sure you want to delete all data?  Backups will not be deleted.'),
        actions: <Widget>[
          Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              "Cancel",
              style: TextStyle(
                color: _isDarkModeEnabled ? Colors.white : Colors.black,
              ),
            ),
            ),
          ),
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor:
              MaterialStateProperty.all<Color>(Colors.redAccent),
            ),
            onPressed: () async {
              await _confirmedDeleteEverything();
            },
            child: Text(
              "Delete Everything",
              style: TextStyle(
                color: _isDarkModeEnabled ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmFoundABugDialog() {
    // showDialog<String>(
    //   context: context,
    //   builder: (BuildContext context) => AlertDialog(
    //     title: const Text('Remove Account?'),
    //     content: const Text(
    //       'Do you want to permanently remove your account and sign out?',
    //     ),
    //     actions: <Widget>[
    //       TextButton(
    //         onPressed: () => Navigator.pop(context, 'Cancel'),
    //         child: const Text('Cancel'),
    //       ),
    //       TextButton(
    //         onPressed: _pressedRemoveAccount2,
    //         child: const Text('Yes'),
    //       ),
    //     ],
    //   ),
    // );

    showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        // backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.white,
        title: Text('Report a bug'),
      content: TextField(
          controller: _bugNotesTextController,
          autofocus: true,
          maxLines: 4,
          keyboardType: TextInputType.text,
          maxLength: 120,
          minLines: 3,
          decoration: InputDecoration(
              hintText: "Notes",
          ),
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
            onPressed: () {
              _confirmedFoundABug(_bugNotesTextController.text);
              Navigator.of(context).pop();

              _bugNotesTextController.text = "";
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _confirmedFoundABug(String notes) {
    _logManager.log(
        "AdvancedSettingsScreen", "_confirmedFoundABug", "BUG REPORTED 🐞${(notes.length > 0 ? "\n\nNotes: $notes" : "")}");
  }


  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
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

}
