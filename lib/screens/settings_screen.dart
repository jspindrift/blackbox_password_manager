import 'package:flutter/material.dart';

import '../helpers/InactivityTimer.dart';
import '../managers/KeychainManager.dart';
import '../managers/BiometricManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/LogManager.dart';
import '../managers/Cryptor.dart';
import '../screens/rekey_auth_screen.dart';
import '../screens/advanced_settings_screen.dart';
import '../screens/change_password_screen.dart';
import '../screens/backups_screen.dart';
import '../screens/pin_code_screen.dart';
import 'inactivity_time_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/settings_screen';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}


class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {

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

  bool _isBiometricSupported = false;
  bool _isBiometricKeyAvailable = false;
  bool _isLockOnExitEnabled = false;
  bool _isPinCodeEnabled = false;
  bool _isDarkModeEnabled = false;

  /// default is 5 minutes
  int _selectedTimeIndex = 3;
  String _selectedTimeString = "5 minutes";

  final _keyManager = KeychainManager();
  final _biometricManager = BiometricManager();
  final _settingsManager = SettingsManager();
  final _logManager = LogManager();
  final _cryptor = Cryptor();
  final _inactivityTimer = InactivityTimer();

  @override
  void initState() {
    super.initState();

    /// add observer for app lifecycle state transitions
    WidgetsBinding.instance.addObserver(this);

    _logManager.log("SettingsScreen", "initState", "initState");
    // _logManager.logger.d("SettingsScreen - initState");

    _isLockOnExitEnabled = _settingsManager.isLockOnExitEnabled;
    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;

    setState(() {
      _selectedTimeIndex =
          _timeIndexSeconds.indexOf(_settingsManager.inactivityTime);
      _selectedTimeString = _timeList[_selectedTimeIndex];
    });

    _keyManager.readEncryptedKey();

    _keyManager.readPinCodeKey().then((value) {
      setState(() {
        _isPinCodeEnabled = value;
      });
    });

    // /// local authentication check
    // _biometricManager.isDeviceSecured().then((bool isSupported) {
    //   _biometricManager.checkBiometrics().then((value) {
    //     setState(() {
    //       _isBiometricSupported = isSupported && value;
    //     });
    //   });
    // });

    _biometricManager.doBiometricCheck().then((value) {
      setState(() {
        _isBiometricSupported = value;
      });
    });

    _keyManager.renderBiometricKey().then((value) {
      setState(() {
        _isBiometricKeyAvailable = value;
      });
    });
  }


  /// track the lifecycle of the app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.inactive:
        // _logManager.log("SettingsScreen", "didChangeAppLifecycleState",
        //     "AppLifecycleState: inactive");
        // _logManager.logger.d("AppLifecycleState: inactive - SettingsScreen");

        break;
      case AppLifecycleState.resumed:
        // _logManager.log("SettingsScreen", "didChangeAppLifecycleState",
        //     "AppLifecycleState: resumed");
        // _logManager.logger.d("AppLifecycleState: resumed - SettingsScreen");

        /// check biometrics
        final checkBioAvailability = await _biometricManager.doBiometricCheck();
        if (mounted) {
          setState(() {
            _isBiometricSupported = checkBioAvailability;
          });
        }

        if (!checkBioAvailability) {
          final deleteBioStatus = await _keyManager.deleteBiometricKey();
          if (deleteBioStatus) {
            if (mounted) {
              setState(() {
                _isBiometricKeyAvailable = false;
              });
            }
          }
        }

        break;
      case AppLifecycleState.paused:
        // _logManager.log("SettingsScreen", "didChangeAppLifecycleState",
        //     "AppLifecycleState: paused");
        // _logManager.logger.d("AppLifecycleState: paused - SettingsScreen");
        break;
      case AppLifecycleState.detached:
        // _logManager.logger.d("AppLifecycleState: detached - SettingsScreen");
        // _logManager.log("SettingsScreen", "didChangeAppLifecycleState",
        //     "AppLifecycleState: detached");
        break;
      case AppLifecycleState.hidden:
        // _logManager.logger.d("AppLifecycleState: hidden - SettingsScreen");
        break;
    }
  }

  @override
  void dispose() {
    super.dispose();

    WidgetsBinding.instance.removeObserver(this);
  }

  /// update and read values after popping back from backup screen
  /// this is in case the user restored from a backup
  void updateKeysAndStates() async {
    await _keyManager.readEncryptedKey();

    if (mounted) {
      setState(() {
        _isLockOnExitEnabled = _settingsManager.isLockOnExitEnabled;
        _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;
      });
    }

    final bioRenderStatus = await _keyManager.renderBiometricKey();
    final isBiometricSupported = await _biometricManager.doBiometricCheck();

    if (mounted) {
      setState(() {
        _isBiometricSupported = isBiometricSupported;
        _isBiometricKeyAvailable = bioRenderStatus  && isBiometricSupported;
      });
    }

    if (!isBiometricSupported) {
      await _keyManager.deleteBiometricKey();
    }

    final pinStatus = await _keyManager.readPinCodeKey();
    if (mounted) {
      setState(() {
        _isPinCodeEnabled = pinStatus;

        _selectedTimeIndex =
            _timeIndexSeconds.indexOf(_settingsManager.inactivityTime);
        _selectedTimeString = _timeList[_selectedTimeIndex];
      });
    }

  }

  /// TODO: add inactivity time screen
  ///
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        title: Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Container(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: _isDarkModeEnabled
                          ? BorderSide(color: Colors.greenAccent)
                          : null,
                    ),
                    child: Text(
                      'Log Out',
                      style: _isDarkModeEnabled
                          ? TextStyle(color: Colors.greenAccent, fontSize: 16)
                          : null,
                    ),
                    onPressed: () {
                      // print("press");
                      _showLogoutDialog(context);
                    },
                  ),
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              ),
              Padding(
                padding: EdgeInsets.all(4.0),
                child: Center(
                  child: ElevatedButton(
                    child: Text(
                      'Change Password',
                      style: _isDarkModeEnabled
                          ? TextStyle(color: Colors.black, fontSize: 16)
                          : null,
                    ),
                    style: ButtonStyle(
                      backgroundColor: _isDarkModeEnabled
                          ? MaterialStateProperty.all<Color>(Colors.greenAccent)
                          : null,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChangePasswordScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),

              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : null,
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Security",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _isDarkModeEnabled
                        ? Colors.greenAccent
                        : Colors.blueAccent,
                  ),
                ),
              ),
              Visibility(
                visible: _settingsManager.shouldRekey,
                child: Divider(
                  color: _isDarkModeEnabled ? Colors.grey[900] : Colors.white,
                ),
              ),
              Visibility(
                visible: _settingsManager.shouldRekey,
                child: Padding(
                  padding: EdgeInsets.all(0.0),
                  child: Card(
                    elevation: 0,
                    color: _isDarkModeEnabled ? Colors.black54 : Colors.white,
                    child: Container(
                      height: 70,
                      child: ListTile(
                        enabled: true,
                        title:  Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                          'Re-Key Vault',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _isDarkModeEnabled ? Colors.white : null),
                        ),),
                        subtitle: Padding(
                          padding: EdgeInsets.fromLTRB(8, 4, 8, 16),
                          child:  Text(
                          'This will re-encrypt your vault with a new key.',
                          style: TextStyle(
                              color: _isDarkModeEnabled
                                  ? Colors.white
                                  : null),
                        ),),
                        leading: IconButton(
                          icon: Icon(
                            Icons.key,
                            size: 40,
                            color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                          ),
                          onPressed: (){
                            /// Navigate to re-key screen
                            _logManager.logger.d("show re-key screen");
                            /// TODO: inactivity screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReKeyAuthScreen(),
                              ),
                            ).then((value) {
                              // _updateUI();
                              updateKeysAndStates();
                            });
                          },
                        ),
                        trailing: Icon(
                          Icons.arrow_forward,
                          // size: 30,
                          color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                        ),
                        onTap: (){
                          /// Navigate to re-key screen
                          _logManager.logger.d("show re-key screen");

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReKeyAuthScreen(),
                            ),
                          ).then((value) {
                            // _updateUI();
                            updateKeysAndStates();
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Visibility(
                visible: _settingsManager.shouldRekey,
                child: Divider(
                  color: _isDarkModeEnabled ? Colors.grey[900] : Colors.white,
                ),
              ),
              Visibility(
                visible: _isBiometricSupported,
                child: Padding(
                  padding: EdgeInsets.all(0.0),
                  child: Card(
                    elevation: 0,
                    color: _isDarkModeEnabled ? Colors.black : Colors.white,
                    child: Container(
                      height: 70,
                      child: ListTile(
                        enabled: true,
                        title: Text(
                          'Use ${_biometricManager.biometricType}',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _isDarkModeEnabled ? Colors.white : null),
                        ),
                        subtitle: !_isBiometricKeyAvailable && _isPinCodeEnabled
                            ? Text(
                                'This will replace your pin code',
                                style: TextStyle(
                                    color: _isDarkModeEnabled
                                        ? Colors.white
                                        : null),
                              )
                            : null,
                        trailing: Switch(
                          thumbColor:
                              MaterialStateProperty.all<Color>(Colors.white),
                          trackColor: _isBiometricKeyAvailable
                              ? (_isDarkModeEnabled
                                  ? MaterialStateProperty.all<Color>(
                                      Colors.greenAccent)
                                  : MaterialStateProperty.all<Color>(
                                      Colors.blue))
                              : MaterialStateProperty.all<Color>(Colors.grey),
                          value: _isBiometricKeyAvailable,
                          onChanged: (value) {
                            _pressedBiometricSwitch(value);
                          },
                        ),
                      ),
                    ),
                  ),
                ),),
              Divider(
                color: _isDarkModeEnabled ? Colors.grey[900] : Colors.white,
              ),
              Padding(
                padding: EdgeInsets.all(0.0),
                child: Card(
                    elevation: 0,
                    color: _isDarkModeEnabled ? Colors.black54 : Colors.white,
                    child: Container(
                      height: 70,
                      child: ListTile(
                        enabled: true,
                        title: Text(
                          'Use Pin Code',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _isDarkModeEnabled ? Colors.white : null),
                        ),
                        subtitle: _isBiometricSupported && !_isPinCodeEnabled
                            ? Text(
                                'This will replace ${_biometricManager.biometricType}',
                                style: TextStyle(
                                    color: _isDarkModeEnabled
                                        ? Colors.white
                                        : null),
                              )
                            : null,
                        trailing: Switch(
                          thumbColor:
                              MaterialStateProperty.all<Color>(Colors.white),
                          trackColor: _isPinCodeEnabled
                              ? (_isDarkModeEnabled
                                  ? MaterialStateProperty.all<Color>(
                                      Colors.greenAccent)
                                  : MaterialStateProperty.all<Color>(
                                      Colors.blue))
                              : MaterialStateProperty.all<Color>(Colors.grey),
                          value: _isPinCodeEnabled,
                          onChanged: (value) {
                            _pressedPinCodeSwitch(value);
                          },
                        ),
                      ),
                    )),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.grey[900] : Colors.grey,
              ),
              Padding(
                padding: EdgeInsets.all(0.0),
                child: Card(
                  elevation: 0,
                  color: _isDarkModeEnabled ? Colors.black : Colors.white,
                  child: Container(
                    height: 70,
                    child: ListTile(
                      enabled: true,
                      title: Text(
                        'Inactivity Time',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _isDarkModeEnabled ? Colors.white : null),
                      ),
                      subtitle: Text(
                        _selectedTimeString,
                        style: TextStyle(
                            color: _isDarkModeEnabled ? Colors.white : null),
                      ),
                      onTap: () {
                        // print("inactivity screen");

                        /// TODO: inactivity screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InactivityTimeScreen(),
                          ),
                        ).then((value) {
                          // _updateUI();
                          updateKeysAndStates();
                        });
                      },
                      trailing: IconButton(
                        icon: Icon(
                          Icons.arrow_forward,
                          color: _isDarkModeEnabled
                              ? Colors.greenAccent
                              : Colors.blueAccent,
                        ),
                        onPressed: () {
                          // print("inactivity screen");

                          /// TODO: inactivity screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InactivityTimeScreen(),
                            ),
                          ).then((value) {
                            // _updateUI();
                            updateKeysAndStates();
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.grey[900] : Colors.grey,
              ),
              Card(
                elevation: 0,
                color: _isDarkModeEnabled ? Colors.black54 : Colors.white,
                child: Container(
                  height: 70,
                  child: ListTile(
                    enabled: true,
                    title: Text(
                      'Lock On Exit',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _isDarkModeEnabled ? Colors.white : null),
                    ),
                    subtitle: Text(
                      'App locks when backgrounded',
                      style: TextStyle(
                          color: _isDarkModeEnabled ? Colors.white : null),
                    ),
                    trailing: Switch(
                      thumbColor:
                          MaterialStateProperty.all<Color>(Colors.white),
                      trackColor: _isLockOnExitEnabled
                          ? (_isDarkModeEnabled
                              ? MaterialStateProperty.all<Color>(
                                  Colors.greenAccent)
                              : MaterialStateProperty.all<Color>(Colors.blue))
                          : MaterialStateProperty.all<Color>(Colors.grey),
                      value: _isLockOnExitEnabled,
                      onChanged: (value) {
                        _pressedLockOnExitSwitch(value);
                      },
                    ),
                  ),
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Advanced",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _isDarkModeEnabled
                        ? Colors.greenAccent
                        : Colors.blueAccent,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(0.0),
                child: Card(
                  elevation: 1,
                  color: _isDarkModeEnabled ? Colors.black54 : Colors.white,
                  child: ListTile(
                    enabled: true,
                    title: Text(
                      'Manage Backups',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _isDarkModeEnabled ? Colors.white : null),
                    ),
                    subtitle: Text(
                      'Create and restore backups',
                      style: TextStyle(
                          // fontSize: 20,
                          // fontWeight: FontWeight.bold,
                          color: _isDarkModeEnabled ? Colors.white : null),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BackupsScreen(),
                        ),
                      ).then((value) {
                        updateKeysAndStates();
                      });
                    },
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
                            builder: (context) => BackupsScreen(),
                          ),
                        ).then((value) {
                          updateKeysAndStates();
                        });
                      },
                    ),
                  ),
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.grey[900] : null,
              ),
              Padding(
                padding: EdgeInsets.all(0.0),
                child: Card(
                  color: _isDarkModeEnabled ? Colors.black54 : Colors.white,
                  elevation: 1,
                  child: ListTile(
                    enabled: true,
                    trailing: IconButton(
                      icon: Icon(
                        Icons.settings,
                        color: _isDarkModeEnabled
                            ? Colors.greenAccent
                            : Colors.blueAccent,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdvancedSettingsScreen(),
                          ),
                        ).then((value) {
                          updateKeysAndStates();
                        });
                      },
                    ),
                    title: Text(
                      'Advanced Settings',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _isDarkModeEnabled ? Colors.white : null),
                    ),
                    subtitle: Text(
                      'Tap to see advanced settings',
                      style: TextStyle(
                          // fontSize: 20,
                          // fontWeight: FontWeight.bold,
                          color: _isDarkModeEnabled ? Colors.white : null),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdvancedSettingsScreen(),
                        ),
                      ).then((value) {
                        setState(() {
                          _isDarkModeEnabled =
                              _settingsManager.isDarkModeEnabled;
                        });

                        _keyManager.readPinCodeKey().then((value) {
                          if (mounted) {
                            setState(() {
                              _isPinCodeEnabled = value;
                            });
                          }
                        });
                      });
                    },
                  ),
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : null,
              ),
              Visibility(
                visible: false,
                child: Padding(
                padding: EdgeInsets.all(0.0),
                child: Card(
                  color: _isDarkModeEnabled ? Colors.black54 : Colors.white,
                  elevation: 1,
                  child: ListTile(
                    enabled: true,
                    trailing: IconButton(
                      icon: Icon(
                        Icons.qr_code_scanner,
                        color: _isDarkModeEnabled
                            ? Colors.greenAccent
                            : Colors.blueAccent,
                      ),
                      onPressed: () {
                        /// scan in message
                        // print("scan message");
                      },
                    ),
                    title: Text(
                      'Scan Encrypted Message',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _isDarkModeEnabled ? Colors.white : null),
                    ),
                    subtitle: Text(
                      'Used for transferring an encrypted message from another device',
                      style: TextStyle(
                          color: _isDarkModeEnabled ? Colors.white : null),
                    ),
                    onTap: () {
                      /// scan in message
                      // print("scan message");

                    },
                  ),
                ),
              ),),
            ],
          ),
        ),
      ),
    );
  }

  /// authenticate the user with biometrics and create the biometric
  /// keychain item to unwrap our encryption keys when authenticated
  void _pressedBiometricSwitch(bool shouldCreate) async {
    _logManager.log(
        "SettingsScreen", "_pressedBiometricSwitch", "creating biometric key");
    try {
      if (shouldCreate) {
        final status = await _biometricManager.authenticateWithBiometrics();
        if (status) {
          final saveStatus = await _keyManager.saveBiometricKey();
          setState(() {
            _isBiometricKeyAvailable = saveStatus;
          });

          if (saveStatus) {
            // delete pin code
            final status2 = await _keyManager.deletePinCode();

            if (status2) {
              setState(() {
                _isPinCodeEnabled = false;
              });
            } else {
              /// Android bug for deletion (try again)
              final status3 = await _keyManager.deletePinCode();

              if (status3) {
                setState(() {
                  _isPinCodeEnabled = false;
                });
              }
            }
          }
        }
      } else {
        final deleteStatus = await _keyManager.deleteBiometricKey();
        if (deleteStatus) {
          setState(() {
            _isBiometricKeyAvailable = false;
          });
        }
      }
    } catch (e) {
      _logManager.logger.d(e);
      setState(() {
        _isBiometricKeyAvailable = !shouldCreate;
      });
    }
  }

  /// allow the user to create a pin code key and wrap our encryption keys
  /// with the pin code key.
  void _pressedPinCodeSwitch(bool enabled) async {
    if (enabled) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PinCodeScreen(
            flow: PinCodeFlow.create,
          ),
          fullscreenDialog: true,
        ),
      ).then((value) {
        if (value != null) {
          if (value == 'setPin') {
            _logManager.logger.wtf("setPinCode");
            setState(() {
              _isPinCodeEnabled = true;
              _isBiometricKeyAvailable = false;
            });
          }
        } else {
          setState(() {
            _isPinCodeEnabled = false;
          });
        }
      });
    } else {
      final status = await _keyManager.deletePinCode();
      if (status) {
        setState(() {
          _isPinCodeEnabled = false;
        });
      }
    }
  }

  /// enable/disable lock on exit mode
  void _pressedLockOnExitSwitch(bool value) {
    _logManager.log(
        "SettingsScreen", "_pressedLockOnExitSwitch", "Lock On Exit: $value");
    _settingsManager.saveLockOnExit(value);
    setState(() {
      _isLockOnExitEnabled = value;
    });
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Log Out"),
        content: Text("Are you sure you want to Log Out?"),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text("Cancel"),
          ),
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor:
                  MaterialStateProperty.all<Color>(Colors.redAccent),
            ),
            onPressed: () {
              _inactivityTimer.stopInactivityTimer();
              _settingsManager.setIsOnLockScreen(true);
              _cryptor.clearAllKeys();
              _logManager.logger.d("log out homey");
              // Navigator.of(ctx).pop();
              Navigator.of(ctx).popUntil((route) => route.isFirst);
              // Navigator.of(ctx).popUntil((route) {
              //   print("route.isFirst: $route : ${route.isFirst}");
              //   return route.isFirst;
              // } );
            },
            child: Text("Log Out"),
          ),
        ],
      ),
    );
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
