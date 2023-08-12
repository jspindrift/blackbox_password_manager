import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import "package:flutter/services.dart";
import 'package:flutter/foundation.dart';
import "package:flutter_barcode_scanner/flutter_barcode_scanner.dart";
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:neon_widgets/neon_widgets.dart';

import '../helpers/HearbeatTimer.dart';
import '../managers/JailbreakChecker.dart';
import '../managers/KeychainManager.dart';
import '../managers/BiometricManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/Cryptor.dart';
import '../managers/FileManager.dart';
import '../managers/LogManager.dart';
import '../managers/DeviceManager.dart';

import '../models/RecoveryKeyCode.dart';
import '../screens/backups_screen.dart';
import '../screens/pin_code_screen.dart';
import '../screens/home_tab_screen.dart';
import "../widgets/QRScanView.dart";
import '../testing/test_crypto.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/login_screen';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final _enterPasswordTextController = TextEditingController();
  final _confirmPasswordTextController = TextEditingController();
  final _passwordHintTextController = TextEditingController();

  final _enterPasswordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  final _passwordHintFocusNode = FocusNode();

  bool _fieldsAreValid = false;
  bool _isSigningUp = false;
  bool _hideConfirmPasswordField = true;
  bool _hideEnterPasswordField = true;

  bool _isAuthenticating = false;
  bool _isBiometricLoginEnabled = false;

  bool _hasBackups = false;
  bool _isRecoveryModeEnabled = false;

  bool _isOnLoginScreen = true;

  bool _isDarkModeEnabled = false;
  bool _isFirstLaunch = true;

  bool _isInit = true;

  int _wrongPasswordCount = 0;

  bool _isJailbroken = false;

  /// subscription for receiving notification of app data reset to reset states
  late StreamSubscription resetAppSubscription;


  final cryptor = Cryptor();
  final keyManager = KeychainManager();
  final biometricManager = BiometricManager();
  final settingsManager = SettingsManager();
  final fileManager = FileManager();
  final logManager = LogManager();
  final deviceManager = DeviceManager();
  final heartbeatTimer = HeartbeatTimer();

  final jailbreakChecker = JailbreakChecker();

  @override
  void initState() {
    super.initState();

    /// add observer for app lifecycle state transitions
    WidgetsBinding.instance.addObserver(this);

    logManager.initialize();

    settingsManager.initializeLaunchSettings();
    // keyManager.deleteAll();
    // logManager.logger.d("now: ${DateTime.now().toIso8601String()}");

    logManager.log("LoginScreen", "initState", "initState");

    _isDarkModeEnabled = settingsManager.isDarkModeEnabled;

    _calculateDevices();

    _startup();

    _readRecoveryMode();

    /// setup subscription streams
    resetAppSubscription = settingsManager.onResetAppRecieved.listen((event) {
      logManager.logger.d("LoginPage: resetAppSubscription: ${event}");
      if (mounted) {
        setState(() {
          _isSigningUp = event;
        });
      }
    });

    _testStartupConfig();

    _isInit = false;
  }

  void _testStartupConfig() async {
    // final sessionNumber = settingsManager.sessionNumber;
    // print("sessionNumber: $sessionNumber");

    // if (sessionNumber == 0) {
    //   print("first time opening app");
    //   settingsManager.incrementSessionNumber();
    // } else {
    //   settingsManager.incrementSessionNumber();
    // }

    // settingsManager.saveEncryptionCount(0);
    // settingsManager.saveNumBytesEncrypted(0);
    // settingsManager.saveEncryptionRolloverCount(0);

    // keyManager.deleteAll();
    // settingsManager.removeAllPreferences();
  }

  void _readRecoveryMode() async {
    setState(() {
      _isRecoveryModeEnabled = settingsManager.isRecoveryModeEnabled;
    });
  }

  /// Determine app/device state
  void _calculateDevices() async {
    await _getAppSettings();

    final check = await biometricManager.doBiometricCheck();
    setState(() {
      _isBiometricLoginEnabled = check;
    });

    if (Platform.isIOS) {
      final idList = await keyManager.readLocalDeviceKeys();
      final thisId = await deviceManager.getDeviceId();
      // print("thisId: $thisId");

      var foundID = false;

      for (var k in idList) {
        // print("key: ${k.key}\ntime: ${k.value}");
        if (k.key == thisId) {
          // print("found thisId!");
          foundID = true;
          break;
        }
        // else {
        //   print("mismatch: ${k.key}");
        // }
      }

      /// TODO: this is different for android
      if (foundID) {
        setState(() {
          _isFirstLaunch = false;
        });
      } else {
          logManager.logger.d("delete for startup!!");
          await keyManager.deleteForStartup();
          setState(() {
            _isSigningUp = true;
          });
          if (thisId != null) {
            await keyManager.saveLocalDeviceKey(
              thisId,
              DateTime.now().toIso8601String(),
            );
          }
      }
    } else {
      if (!settingsManager.launchSettingInitialized) {
        logManager.logger.d("settingsManager.launchSettingInitialized: ${settingsManager.launchSettingInitialized}");
          Future.delayed(Duration(seconds: 2), () {
            if (settingsManager.launchSettingInitialized) {
              _checkHasLaunchedState();
            }
          });
      } else {
        _checkHasLaunchedState();
      }
    }
  }

  _checkHasLaunchedState() async {
    final status = settingsManager.hasLaunched;
    logManager.logger.d("hasLaunched: $status");

    if (!status) {
      logManager.logger.d("delete for startup");
      keyManager.deleteForStartup();
      settingsManager.saveHasLaunched();

      _showErrorDialog("Deleted for Startup");
    } else {
      setState(() {
        _isFirstLaunch = false;
      });
    }
  }

  void _startup() async {
    // print("startup 2: $_isFirstLaunch");

    /// testing SD card backup saving location
    // final xPath = await fileManager.externalLocalPath;
    // logManager.logger.d("fileManager.externalLocalPath: ${xPath}");

    _isJailbroken = await jailbreakChecker.isDeviceJailbroken();

    if (_isJailbroken) {
      Future.delayed(Duration(seconds: 0), () {
        _showJailbreakDialog();
      });
      return;
    }

    // final check = await biometricManager.doBiometricCheck();
    // setState(() {
    //   _isBiometricLoginEnabled = check;
    // });

    /// get log key ready for authenticating logs
    keyManager.readLogKey();

    _getAppState();

    /// check for pin code
    final pinStatus = await keyManager.readPinCodeKey();
    // print("pinStatus1: $pinStatus, $_isFirstLaunch");

    if (pinStatus && !_isFirstLaunch) {
      _isOnLoginScreen = false;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PinCodeScreen(
            flow: PinCodeFlow.lock,
          ),
          fullscreenDialog: true,
        ),
      ).then((value) {
        /// if valid login from pin code screen
        if (value == 'login') {
          Navigator.of(context)
              .pushNamed(HomeTabScreen.routeName)
              .then((value) async {
            logManager.saveLogs();

            settingsManager.setCurrentTabIndex(1);

            HeartbeatTimer().stopHeartbeatTimer();

            setState(() {
              _isOnLoginScreen = true;
            });

            _getAppState();
          });
        }
      });
    }
  }

  _getAppState() async {
    /// read encrypted key material data
    final keyStatus = await keyManager.readEncryptedKey();
    setState(() {
      _isSigningUp = !keyManager.hasPasswordItems;
    });

    /// check biometric key
    final bioStatus = await keyManager.renderBiometricKey();
    setState(() {
      _isBiometricLoginEnabled = bioStatus;
    });

    final checkBioAvailability = await biometricManager.doBiometricCheck();
    setState(() {
      _isBiometricLoginEnabled = checkBioAvailability;
    });

    if (!checkBioAvailability) {
      keyManager.deleteBiometricKey();
    }

    _readRecoveryMode();

    // lets go dark... :)
    if (_isSigningUp || !keyStatus) {
      setState(() {
        _isDarkModeEnabled = true;
      });
      settingsManager.saveDarkMode(true);
      // set to secure settings by default
      settingsManager.saveLockOnExit(true);
    } else {
      setState(() {
        _isDarkModeEnabled = settingsManager.isDarkModeEnabled;
      });
    }

    // /// check biometric key
    // final bioStatus = await keyManager.renderBiometricKey();
    // setState(() {
    //   _isBiometricLoginEnabled = bioStatus;
    // });

    /// invoke on first instantiation
    if (bioStatus && !_isFirstLaunch && !_isSigningUp) {
      _pressedBiometricButton();
    }

    if (_isFirstLaunch) {
      _isBiometricLoginEnabled = false;
    }

    /// check local document backup file
    final vaultFileString = await fileManager.readNamedVaultData();

    if (vaultFileString.isNotEmpty) {
      setState(() {
        _hasBackups = true;
      });
    } else {
      setState(() {
        _hasBackups = false;
      });
    }

    /// check android SD backup file if local does not exist
    if (Platform.isAndroid && !_hasBackups) {
      var vaultFileString = await fileManager.readVaultDataSDCard();
      setState(() {
        _hasBackups = vaultFileString.isNotEmpty;
      });
    }

  }

  Future<void> _getAppSettings() async {
    await settingsManager.initialize();
    // await DeviceManager().initialize();

    logManager.logger.d("deviceData: ${settingsManager.deviceManager.deviceData}");

    setState(() {
      _isRecoveryModeEnabled = settingsManager.isRecoveryModeEnabled;
    });

  }


  /// track the lifecycle of the app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.inactive:
        // print("INACTIVE-------------------------------");
        logManager.log("LoginScreen", "didChangeAppLifecycleState",
            "AppLifecycleState: inactive");
        logManager.logger.d("AppLifecycleState: inactive - LoginScreen");
        // Navigator.of(context).pop();

        /// Save logs here...
        /// Tried saving on AppLifecycleState.paused but it fails and
        /// clears the log file data when app is force closed while in foreground.
        /// This seems to only happen when app is in prod/release mode and not
        /// in build/debug mode, which is very odd...

        if (_isOnLoginScreen) {
          logManager.setIsSavingLogs(true);
          await logManager.saveLogs();
        }

        break;
      case AppLifecycleState.resumed:
        logManager.log("LoginScreen", "didChangeAppLifecycleState",
            "AppLifecycleState: resumed");
        logManager.logger.d("AppLifecycleState: resumed - LoginScreen");

        if (!_isInit) {
          _readRecoveryMode();

          /// check biometrics
          final checkBioAvailability = await biometricManager.doBiometricCheck();
          setState(() {
            _isBiometricLoginEnabled = checkBioAvailability;
          });

          if (!checkBioAvailability) {
            keyManager.deleteBiometricKey();
          }
        }
        break;
      case AppLifecycleState.paused:
        logManager.log("LoginScreen", "didChangeAppLifecycleState",
            "AppLifecycleState: paused");
        logManager.logger.d("AppLifecycleState: paused - LoginScreen");

        break;
      case AppLifecycleState.detached:
        logManager.logger.d("AppLifecycleState: detached");
        logManager.log("LoginScreen", "didChangeAppLifecycleState",
            "AppLifecycleState: detached");
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
    _isDarkModeEnabled = settingsManager.isDarkModeEnabled;

    // print("$_isOnLoginScreen, $_isFirstLaunch, $_isInit");
    if (_isOnLoginScreen && !_isFirstLaunch && !_isInit) {
      keyManager.readPinCodeKey().then((value) {
        // print("readPinCodeKey-login: $value");
        if (value) {
          _isOnLoginScreen = false;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PinCodeScreen(
                flow: PinCodeFlow.lock,
              ),
              fullscreenDialog: true,
            ),
          ).then((value) async {
            if (value == 'login') {
              // settingsManager.setCurrentTabIndex(0);

              Navigator.of(context)
                  .pushNamed(HomeTabScreen.routeName)
                  .then((value) async {
                logManager.saveLogs();

                settingsManager.setCurrentTabIndex(1);

                HeartbeatTimer().stopHeartbeatTimer();

                setState(() {
                  _isOnLoginScreen = true;
                });

                /// read encrypted key material data
                keyManager.readEncryptedKey().then((value) {
                  setState(() {
                    _isSigningUp = !keyManager.hasPasswordItems;
                  });

                  // lets go dark... :)
                  if (_isSigningUp) {
                    setState(() {
                      _isDarkModeEnabled = true;
                    });
                    settingsManager.saveDarkMode(true);
                    // set to secure settings by default
                    settingsManager.saveLockOnExit(true);
                  }
                });

                keyManager.renderBiometricKey().then((value) {
                  setState(() {
                    _isBiometricLoginEnabled = value;
                  });
                });

                final vaultFileString = await fileManager.readNamedVaultData();

                if (vaultFileString.isNotEmpty) {
                  setState(() {
                    _hasBackups = true;
                  });
                }

                /// check android backup file
                if (Platform.isAndroid && !_hasBackups) {
                  var vaultFileString = await fileManager.readVaultDataSDCard();
                  setState(() {
                    _hasBackups = vaultFileString.isNotEmpty;
                  });
                }

              });
            }
          });
        }
      });
    }

    return WillPopScope(
        onWillPop: (){
      return Future.value(false);
    },
    child: Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text('Blackbox'),
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: Icon(
            Icons.home,
          color: _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
          size: 30,
        ),
        actions: [
            Visibility(
              visible: _isRecoveryModeEnabled,
              child: IconButton(
              icon: Icon(Icons.camera),
              color: _isDarkModeEnabled ? Colors.greenAccent : null,
              onPressed: () async {
                await _scanQR();
              },
            ),
            ),
          Visibility(
              visible: Platform.isMacOS,
              child: IconButton(
                icon: Icon(
                  Icons.transfer_within_a_station,
                  color: Colors.greenAccent,
                ),
                onPressed: () {
                  TestCrypto().runTests();
                },
              ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Card(
            color: _isDarkModeEnabled ? Colors.black54 : null,
            child: Form(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: NeonContainer(
                borderColor: _isDarkModeEnabled ? Colors.black87 : Colors.white,
                containerColor: _isDarkModeEnabled ? Colors.black87 : Colors.white,
                spreadColor: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                lightBlurRadius: 80,
                lightSpreadRadius: 5,
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: TextFormField(
                      cursorColor:
                          _isDarkModeEnabled ? Colors.greenAccent : null,
                      obscureText: _hideEnterPasswordField,
                      keyboardType: TextInputType.visiblePassword,
                      style: TextStyle(
                        fontSize: 16.0,
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Master Password',
                        contentPadding:
                            EdgeInsets.fromLTRB(20.0, 10.0, 10.0, 10.0),
                        filled: _isDarkModeEnabled ? true : false,
                        fillColor: _isDarkModeEnabled
                            ? Colors.black12
                            : Colors.white10,
                        hintStyle: TextStyle(
                          color: _isDarkModeEnabled ? Colors.white : null,
                        ),
                        labelStyle: TextStyle(
                          color: _isDarkModeEnabled ? Colors.white : null,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _isDarkModeEnabled
                                ? Colors.greenAccent
                                : Colors.grey,
                            width: 0.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _isDarkModeEnabled
                                ? Colors.greenAccent
                                : Colors.grey,
                            width: 0.0,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.security,
                          color: _isDarkModeEnabled ? Colors.grey : null,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.remove_red_eye,
                            color: _hideEnterPasswordField
                                ? Colors.grey
                                : _isDarkModeEnabled
                                    ? Colors.greenAccent
                                    : Colors.blueAccent,
                          ),
                          onPressed: () {
                            setState(() => _hideEnterPasswordField =
                                !_hideEnterPasswordField);
                          },
                        ),
                      ),
                      textInputAction: _isSigningUp
                          ? TextInputAction.next
                          : TextInputAction.done,
                      autocorrect: false,
                      onChanged: (_) {
                        _validateFields();
                      },
                      onTap: () {
                        _validateFields();
                      },
                      onFieldSubmitted: (_) {
                        if (_isSigningUp) {
                          FocusScope.of(context)
                              .requestFocus(_confirmPasswordFocusNode);
                        }
                        _validateFields();
                      },
                      focusNode: _enterPasswordFocusNode,
                      controller: _enterPasswordTextController,
                    ),
                  ),
                  Visibility(
                    visible: _isSigningUp,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: TextFormField(
                        cursorColor:
                            _isDarkModeEnabled ? Colors.greenAccent : null,
                        autocorrect: false,
                        obscureText: _hideConfirmPasswordField,
                        style: TextStyle(
                          fontSize: 16.0,
                          color: _isDarkModeEnabled ? Colors.white : null,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Confirm Master Password',
                          labelStyle: TextStyle(
                            color: _isDarkModeEnabled ? Colors.white : null,
                          ),
                          contentPadding:
                              EdgeInsets.fromLTRB(20.0, 10.0, 10.0, 10.0),
                          filled: _isDarkModeEnabled ? true : false,
                          fillColor: _isDarkModeEnabled
                              ? Colors.black12
                              : Colors.white10,
                          hintStyle: TextStyle(
                            color: _isDarkModeEnabled ? Colors.white : null,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _isDarkModeEnabled
                                  ? Colors.greenAccent
                                  : Colors.grey,
                              width: 0.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _isDarkModeEnabled
                                  ? Colors.greenAccent
                                  : Colors.grey,
                              width: 0.0,
                            ),
                          ),
                          prefixIcon: Icon(
                            Icons.security,
                            color: _isDarkModeEnabled ? Colors.grey : null,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.remove_red_eye,
                              color: _hideConfirmPasswordField
                                  ? Colors.grey
                                  : _isDarkModeEnabled
                                      ? Colors.greenAccent
                                      : Colors.blueAccent,
                            ),
                            onPressed: () {
                              setState(() => _hideConfirmPasswordField =
                                  !_hideConfirmPasswordField);
                            },
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                        onChanged: (_) {
                          _validateFields();
                        },
                        onTap: () {
                          _validateFields();
                        },
                        onFieldSubmitted: (_) {
                            FocusScope.of(context)
                                .requestFocus(_passwordHintFocusNode);
                          _validateFields();
                        },
                        focusNode: _confirmPasswordFocusNode,
                        controller: _confirmPasswordTextController,
                      ),
                    ),
                  ),
                  Visibility(
                    visible: _isSigningUp,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: TextFormField(
                        cursorColor:
                            _isDarkModeEnabled ? Colors.greenAccent : null,
                        autocorrect: false,
                        obscureText: false,
                        style: TextStyle(
                          fontSize: 16.0,
                          color: _isDarkModeEnabled ? Colors.white : null,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Password Hint (Optional)',
                          labelStyle: TextStyle(
                            color: _isDarkModeEnabled ? Colors.white : null,
                          ),
                          contentPadding:
                              EdgeInsets.fromLTRB(20.0, 10.0, 10.0, 10.0),
                          filled: _isDarkModeEnabled ? true : false,
                          fillColor: _isDarkModeEnabled
                              ? Colors.black12
                              : Colors.white10,
                          hintStyle: TextStyle(
                            color: _isDarkModeEnabled ? Colors.white : null,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _isDarkModeEnabled
                                  ? Colors.greenAccent
                                  : Colors.grey,
                              width: 0.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _isDarkModeEnabled
                                  ? Colors.greenAccent
                                  : Colors.grey,
                              width: 0.0,
                            ),
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onChanged: (_) {
                          _validateFields();
                        },
                        onTap: () {
                          _validateFields();
                        },
                        onFieldSubmitted: (_) {
                          _validateFields();
                        },
                        focusNode: _passwordHintFocusNode,
                        controller: _passwordHintTextController,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: _isDarkModeEnabled
                            ? (_fieldsAreValid
                                ? MaterialStateProperty.all<Color>(
                                    Colors.greenAccent)
                                : MaterialStateProperty.all<Color>(Colors.grey))
                            : null,
                      ),
                      onPressed: !_fieldsAreValid
                          ? null
                          : () async {
                              if (_isSigningUp) {
                                FocusScope.of(context).unfocus();

                                setState(() {
                                  _isAuthenticating = true;
                                });
                                const duration =
                                    const Duration(milliseconds: 300);
                                Timer(duration, () async {
                                  await _createAccount();
                                });
                              } else {
                                FocusScope.of(context).unfocus();

                                setState(() {
                                  _isAuthenticating = true;
                                });
                                const duration =
                                    const Duration(milliseconds: 300);
                                Timer(duration, () async {
                                  await _logIn();
                                });
                              }
                            },
                      child: Text(
                        _isSigningUp ? 'Create Account' : 'Login',
                        style: TextStyle(
                          fontSize: 16,
                          color: _isDarkModeEnabled ? Colors.black : null,
                        ),
                      ),
                    ),
                  ),
                  Visibility(
                    visible: _isBiometricLoginEnabled,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: IconButton(
                        icon: Image.asset(
                          biometricManager.biometricIcon,
                          width: 100,
                          height: 100,
                        ),
                        onPressed: () async {
                          _pressedBiometricButton();
                        },
                      ),
                    ),
                  ),
                  Visibility(
                    visible: (_isSigningUp && _hasBackups),
                    child: ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: _isDarkModeEnabled
                            ? MaterialStateProperty.all<Color>(
                                Colors.greenAccent)
                            : null,
                      ),
                      child: Text(
                        'Restore From Backup',
                        style: TextStyle(
                          fontSize: 16,
                          color: _isDarkModeEnabled ? Colors.black : null,
                        ),
                      ),
                      onPressed: () {
                        _pressedRestoreFromBackup();
                      },
                    ),
                  ),
                  Visibility(
                    visible: (_isAuthenticating && _isSigningUp),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Creating Account...',
                        style: TextStyle(
                          fontSize: 16,
                          color: _isDarkModeEnabled ? Colors.white : null,
                        ),
                      ),
                    ),
                  ),
                  Visibility(
                    visible: (_isAuthenticating && !_isSigningUp),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Logging in...',
                        style: TextStyle(
                          fontSize: 16,
                          color: _isDarkModeEnabled ? Colors.white : null,
                        ),
                      ),
                    ),
                  ),
                  Visibility(
                    visible: (_wrongPasswordCount > 2 && kDebugMode),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: TextButton(
                        child: Text(
                          'Restart',
                          style: TextStyle(
                            fontSize: 16,
                            color: _isDarkModeEnabled ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () async {
                          final status = await keyManager.deleteForBackup();
                          if (status) {
                            settingsManager.removeAllPreferences();
                            // Navigator.popUntil(context, (route) => route.isFirst);
                          } else {
                            _showErrorDialog('Delete account failed');
                          }

                          _computeLogoutValues();
                        },
                      ),
                    ),
                  ),
                ],
              ),),
            ),
          ),
        ),
      ),),
    );
  }

  /// validate the text fields to verify the inputs match before we
  /// allow the user to create the account/vault
  void _validateFields() {
    final firstPassword = _enterPasswordTextController.text;
    if (firstPassword == null || firstPassword.isEmpty) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    if (!_isSigningUp) {
      setState(() {
        _fieldsAreValid = true;
      });
      return;
    }

    final secondPassword = _confirmPasswordTextController.text;
    if (secondPassword == null || secondPassword.isEmpty) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }
    if (firstPassword == secondPassword) {
      setState(() {
        _fieldsAreValid = true;
      });
    } else {
      setState(() {
        _fieldsAreValid = false;
      });
    }
  }

  /// called after we pop back to this screen on a logout
  _computeLogoutValues() async {
    setState(() {
      _isOnLoginScreen = true;
    });

    _readRecoveryMode();

    logManager.saveLogs();

    cryptor.clearAllKeys();

    /// read encrypted key material data
    keyManager.readEncryptedKey().then((value) {
      setState(() {
        _isSigningUp = !keyManager.hasPasswordItems;
      });

      // logManager.logger.d("_isSigningUp: ${_isSigningUp}");

      // lets go dark... :)
      if (_isSigningUp) {
        setState(() {
          _isDarkModeEnabled = true;
        });
        settingsManager.saveDarkMode(true);
        // set to secure settings by default
        settingsManager.saveLockOnExit(true);
      }
    });

    keyManager.renderBiometricKey().then((value) {
      setState(() {
        _isBiometricLoginEnabled = value;
      });
    });

    final vaultFileString = await fileManager.readNamedVaultData();

    if (vaultFileString.isNotEmpty) {
      setState(() {
        _hasBackups = true;
      });
    } else {
      setState(() {
        _hasBackups = false;
      });
    }

    /// check android backup file
    if (Platform.isAndroid) {
      var vaultFileString = await fileManager.readVaultDataSDCard();
      setState(() {
        _hasBackups = vaultFileString.isNotEmpty;
      });
    }

    logManager.logger.d("_hasBackups: $_hasBackups");

    /// check for pin code
    final pinStatus = await keyManager.readPinCodeKey(); //.then((value) {
    // print("pinStatus: $pinStatus");
    if (pinStatus && !_isFirstLaunch) {
      _isOnLoginScreen = false;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PinCodeScreen(
            flow: PinCodeFlow.lock,
          ),
          fullscreenDialog: true,
        ),
      ).then((value) {
        /// if valid login from pin code screen
        if (value == 'login') {
          Navigator.of(context)
              .pushNamed(HomeTabScreen.routeName)
              .then((value) async {
            logManager.saveLogs();

            settingsManager.setCurrentTabIndex(1);

            HeartbeatTimer().stopHeartbeatTimer();

            setState(() {
              _isOnLoginScreen = true;
            });

            _getAppState();
          });
        }
      });
    }
  }

  /// create an account and save encrypted key details
  Future<void> _createAccount() async {
    // FocusScope.of(context).unfocus();

    // logManager.logger.d("isAuthenticating: ${_isAuthenticating}");

    final password = _enterPasswordTextController.text;
    final hint = _passwordHintTextController.text;

    if (password.isEmpty) {
      setState(() {
        _isAuthenticating = false;
      });
      _showErrorDialog('Password cannot be empty');
      return;
    }

    final uuid = cryptor.getUUID();


    try {
      var newKeyParams = await cryptor.deriveKey(uuid, password, hint);
      if (newKeyParams == null) {
        return null;
      }
      // reset fields
      _enterPasswordTextController.text = '';
      _confirmPasswordTextController.text = '';
      _passwordHintTextController.text = '';

      _hideEnterPasswordField = true;
      _hideConfirmPasswordField = true;

      String encodedSalt = newKeyParams.salt;
      String encodedEncryptedKey = newKeyParams.key;//base64.encode(newKeyParams.key);

      /// TODO: save secret salt
      ///

      // final deviceId = await deviceManager.getDeviceId();
      // print("deviceId: $deviceId");

      final deviceId = "macOSX";

      /// create secret salt
      if (deviceId != null) {
        // save password details
        final status = await keyManager.saveMasterPassword(
            newKeyParams,
        );
        // print("status: $status");

        if (status) {
          /// Save identity key data
          ///
          final myId = await cryptor.createMyDigitalID();
          // print("myId: $myId");

          if (myId != null) {
            // final statusId =
            await keyManager.saveMyIdentity(
                keyManager.vaultId,
                myId.toRawJson(),
            );

            // print("statusId: $statusId");
          }

          /// re-save log key in-case we needed to create a new one
          await keyManager.saveLogKey(cryptor.logKeyMaterial);

          /// re-read and refresh our variables
          await keyManager.readEncryptedKey();
        }

        setState(() {
          _isSigningUp = false;
          _isAuthenticating = false;
          _isOnLoginScreen = false;
          _isFirstLaunch = false;
        });

        settingsManager.setCurrentTabIndex(1);

        settingsManager.setIsCreatingNewAccount(true);

        Navigator.of(context).pushNamed(HomeTabScreen.routeName).then((value) {
          settingsManager.setCurrentTabIndex(1);
          // settingsManager.setIsCreatingNewAccount(true);

          HeartbeatTimer().stopHeartbeatTimer();

          _computeLogoutValues();
        });
      }
    } catch (e) {
      logManager.logger.d(e);
      _showErrorDialog('An error occurred');
    }
  }

  /// log in with master password
  Future<void> _logIn() async {
    FocusScope.of(context).unfocus();

    final password = _enterPasswordTextController.text;

    if (password.isEmpty) {
      setState(() {
        _isAuthenticating = false;
      });
      _showErrorDialog('Password cannot be empty');
      return;
    }

    try {
      // check password
      final status = await cryptor.deriveKeyCheck(password, keyManager.salt);
      logManager.log("LoginScreen", "_logIn", "deriveKeyCheck: $status");
      logManager.logger.d("deriveKeyCheck: $status");

      if (status) {
        setState((){
          _wrongPasswordCount = 0;
          _enterPasswordTextController.text = '';
          _isOnLoginScreen = false;
          _hideEnterPasswordField = true;
        });


        Navigator.of(context).pushNamed(HomeTabScreen.routeName).then((value) {
          settingsManager.setCurrentTabIndex(1);

          HeartbeatTimer().stopHeartbeatTimer();

          _computeLogoutValues();
        });
      } else {
        _wrongPasswordCount += 1;

        /// save the logs on invalid tries
        logManager.log("LoginScreen", "_logIn", "invalid password");
        logManager.saveLogs();

        if (_wrongPasswordCount % 3 == 0 && keyManager.hint.isNotEmpty) {
          _showErrorDialog('Invalid password.\n\nhint: ${keyManager.hint}');
        } else {
          _showErrorDialog('Invalid password.');
        }
      }

      setState(() {
        _isAuthenticating = false;
      });
    } catch (e) {
      setState(() {
        _isAuthenticating = false;
      });

      logManager.logger.w("Exception: $e");

      /// save the logs on invalid tries
      logManager.log("LoginScreen", "_logIn", "Error");
      logManager.saveLogs();
    }
  }

  /// authenticate the user with biometrics
  Future<void> _pressedBiometricButton() async {
    FocusScope.of(context).unfocus();

    _enterPasswordTextController.text = '';

    await biometricManager.getAvailableBiometrics();
    // print("no available biometrics: ${biometricManager.availableBiometrics}");

    if (biometricManager.availableBiometrics == null ||
        biometricManager.availableBiometrics!.isEmpty) {
      // print("no available biometrics");
      _showErrorDialog('Biometrics unavailable');
      setState(() {
        _isBiometricLoginEnabled = false;
      });

      await keyManager.deleteBiometricKey();
      return;
    }

    final status = await biometricManager.authenticateWithBiometrics();
    EasyLoading.show(status: "Authenticating...");

    if (status) {
      // if valid auth, create biometric key
      final setStatus = await keyManager.setBiometricKey();
      if (setStatus) {
        setState(() {
          _isOnLoginScreen = false;
          _hideEnterPasswordField = true;
        });

        final logKeyMaterial = await keyManager.readLogKey();
        await cryptor.decodeAndSetLogKey(logKeyMaterial);

        Navigator.of(context).pushNamed(HomeTabScreen.routeName).then((value) {
          settingsManager.setCurrentTabIndex(1);

          HeartbeatTimer().stopHeartbeatTimer();

          _computeLogoutValues();
        });
      } else {
        logManager.log(
            "LoginScreen", "_pressedBiometricButton", "setStatus1 - fail");

        /// Android simulator bug only works sometimes if done twice???
        /// Note: Android sucks
        final setStatus2 = await keyManager.setBiometricKey();

        if (setStatus2) {
          setState(() {
            _isOnLoginScreen = false;
          });
          Navigator.of(context)
              .pushNamed(HomeTabScreen.routeName)
              .then((value) {
            settingsManager.setCurrentTabIndex(1);

            HeartbeatTimer().stopHeartbeatTimer();

            _computeLogoutValues();
          });
        } else {
          // print('setStatus 2 - fail');
          logManager.logger.w("setStatus2 - fail");
          logManager.log(
              "LoginScreen", "_pressedBiometricButton", "setStatus2 - fail");
          _showErrorDialog('Biometric key cannot be read 2');
        }
      }
    } else {
      /// save the logs on invalid states
      logManager.log("LoginScreen", "_pressedBiometricButton", "Error");
      logManager.saveLogs();
      _showErrorDialog('Biometric error');
    }

    EasyLoading.dismiss();
  }

  /// show backups screen for user to restore from
  void _pressedRestoreFromBackup() {
    _isOnLoginScreen = false;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BackupsScreen(),
        fullscreenDialog: true,
      ),
    ).then((value) {
      _isOnLoginScreen = true;

      /// read encrypted key material data
      keyManager.readEncryptedKey().then((value) {
        setState(() {
          _isSigningUp = !keyManager.hasPasswordItems;
        });

        if (keyManager.hasPasswordItems) {
          _isOnLoginScreen = false;
          _hideEnterPasswordField = true;

          // reset fields
          _enterPasswordTextController.text = '';
          _confirmPasswordTextController.text = '';

          Navigator.of(context)
              .pushNamed(HomeTabScreen.routeName)
              .then((value) {
            settingsManager.setCurrentTabIndex(1);

            HeartbeatTimer().stopHeartbeatTimer();

            _computeLogoutValues();
          });
        }
      });
    });
  }

  Future<void> _scanQR() async {
    String barcodeScanRes;
    if (!mounted) {
      logManager.logger.e("something went wrong: not mounted");
      return;
    }

    if (Platform.isIOS) {
      // Platform messages may fail, so we use a try/catch PlatformException.
      try {
        barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
            "#ff6666", "Cancel", true, ScanMode.QR);
        // logManager.logger.d(barcodeScanRes);

        try {
          RecoveryKeyCode keyCode = RecoveryKeyCode.fromRawJson(barcodeScanRes);

          if (keyCode != null) {
            /// try to decrypt item
            await _decryptWithRecoveryKey(keyCode);
          } else {
            _showErrorDialog("Exception: Invalid code format");
          }
        } catch (e) {
          logManager.logger.d("something went wrong: $e");
          _showErrorDialog("Exception: Could not scan code.");
        }
      } on PlatformException {
        barcodeScanRes = "Failed to get platform version.";
        _showErrorDialog("Exception: Failed to get platform version.");
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context)
            .push(MaterialPageRoute(
          builder: (context) => QRScanView(),
        ))
            .then((value) async {
          if (value != null) {
            RecoveryKeyCode keyCode =
            RecoveryKeyCode.fromRawJson(value);

            if (keyCode != null) {
              /// try to decrypt item
              await _decryptWithRecoveryKey(keyCode);
            } else {
              _showErrorDialog("Invalid code format");
            }
          }
        });
      });
    }

  }

  _decryptWithRecoveryKey(RecoveryKeyCode key) async {
    // print("_decryptWithRecoveryKey");

    EasyLoading.show(status: "Decrypting...");

    final keyId = key.id;
    final keyData = key.key;
    // logManager.logger.d("keyId: ${keyId}");
    // logManager.logger.d("keyData: ${keyData}");

    final recoveryItem = await keyManager.getRecoveryKeyItem(keyId);

    if (recoveryItem != null) {
      SecretKey skey = SecretKey(base64.decode(keyData));
      final encryptedKeys = recoveryItem.data;
      logManager.logger.d("encryptedKeys: ${encryptedKeys}");

      final decryptedKeys = await cryptor.decryptRecoveryKey(skey, encryptedKeys);
      // print("decrypted4Keys: ${decryptedKeys}");

      if (decryptedKeys.length == 32) {
        cryptor.setAesRootKeyBytes(decryptedKeys);
        await cryptor.expandSecretRootKey(decryptedKeys);

        /// Log in
        /// TODO: set variable to tell user to change password on this session
        /// don't check current password on password change
        _enterPasswordTextController.text = '';
        _isOnLoginScreen = false;
        _hideEnterPasswordField = true;

        settingsManager.setIsRecoveredSession(true);

        Navigator.of(context).pushNamed(HomeTabScreen.routeName).then((value) {
          settingsManager.setCurrentTabIndex(1);

          settingsManager.setIsRecoveredSession(false);

          HeartbeatTimer().stopHeartbeatTimer();

          _computeLogoutValues();
        });
      }
    } else {
      logManager.logger.d("cant find recovery key item");
      _showErrorDialog("Could not get Recovery Key");
    }

    EasyLoading.dismiss();
  }


  void _showJailbreakDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Jailbreak Detected'),
        content: Text("Warning.  This device appears to be jailbroken.\n\nThis app will not work on this device safely"),
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
