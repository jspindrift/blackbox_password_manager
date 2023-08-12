import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:neon_widgets/neon_widgets.dart';
import '../helpers/HearbeatTimer.dart';
import '../helpers/InactivityTimer.dart';
import '../screens/pin_code_screen.dart';
import '../managers/KeychainManager.dart';
import '../managers/BiometricManager.dart';
import '../managers/Cryptor.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/lock_screen';

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _passwordTextController = TextEditingController();

  bool _hidePasswordField = true;
  bool _isAuthenticating = false;
  bool _isBiometricLoginEnabled = false;
  bool _isFieldValid = false;

  bool _isDarkModeEnabled = false;

  int _wrongPasswordCount = 0;

  final cryptor = Cryptor();
  final keyManager = KeychainManager();
  final biometricManager = BiometricManager();
  final logManager = LogManager();
  final settingsManager = SettingsManager();
  final inactivityTimer = InactivityTimer();

  @override
  void initState() {
    super.initState();

    logManager.log("LockScreen", "initState", "initState");

    _isDarkModeEnabled = settingsManager.isDarkModeEnabled;

    inactivityTimer.stopInactivityTimer();

    settingsManager.setIsOnLockScreen(true);

    settingsManager.setIsRecoveredSession(false);

    /// local authentication check
    biometricManager.isDeviceSecured().then((bool isSupported) {
      if (isSupported) {
        biometricManager.checkBiometrics().then((value) {
          if (value) {
            biometricManager.getAvailableBiometrics();
          }
        });
      }
    });

    /// read encrypted key material data
    keyManager.readEncryptedKey().then((value) {});

    /// check biometric key
    keyManager.renderBiometricKey().then((value) {
      setState(() {
        _isBiometricLoginEnabled = value;
      });
    });

    _checkPinCodeScreenStatus();

    _validateField();
  }

  _checkPinCodeScreenStatus() async {
    /// check pin code, if set show pin code screen
    final status = await keyManager.readPinCodeKey();//.then((value) {
    if (status) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PinCodeScreen(
                flow: PinCodeFlow.lock,
              ),
          fullscreenDialog: true,
        ),
      ).then((value) {
        if (value == 'login') {
          Navigator.of(context).pop();
          HeartbeatTimer().startHeartbeatTimer();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: (){
        return Future.value(false);
      },
        child: Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text('Locked'),
        // backgroundColor: Colors.black54,
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
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
                      obscureText: _hidePasswordField,
                      style: TextStyle(
                        fontSize: 16.0,
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Master Password',
                        contentPadding:
                            EdgeInsets.fromLTRB(10.0, 10.0, 0.0, 10.0),
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
                            color: _hidePasswordField
                                ? Colors.grey
                                : _isDarkModeEnabled
                                    ? Colors.greenAccent
                                    : Colors.blueAccent,
                          ),
                          onPressed: () {
                            setState(
                                () => _hidePasswordField = !_hidePasswordField);
                          },
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      onChanged: (_) {
                        _validateField();
                      },
                      onTap: () {
                        _validateField();
                      },
                      onFieldSubmitted: (_) {
                        _validateField();
                      },
                      controller: _passwordTextController,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: _isDarkModeEnabled
                            ? MaterialStateProperty.all<Color>(
                                Colors.greenAccent)
                            : null,
                      ),
                      child: Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 16,
                          color: _isDarkModeEnabled ? Colors.black : null,
                        ),
                      ),
                      onPressed: _isFieldValid
                          ? () {
                              setState(() {
                                _isAuthenticating = true;
                              });
                              const duration =
                                  const Duration(milliseconds: 200);
                              Timer(duration, () {
                                _logIn();
                              });
                            }
                          : null,
                    ),
                  ),
                  if (_isBiometricLoginEnabled)
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: IconButton(
                        icon: Image.asset(
                          biometricManager.biometricIcon,
                          width: 100,
                          height: 100,
                        ),
                        // icon: Image.asset("icons8-fingerprint-96.png"),
                        onPressed: () async {
                          _pressedBiometricButton();
                        },
                      ),
                      // ElevatedButton(
                      //   style: ButtonStyle(
                      //     backgroundColor: _isDarkModeEnabled
                      //         ? MaterialStateProperty.all<Color>(
                      //             Colors.greenAccent)
                      //         : null,
                      //   ),
                      //   child: Text(
                      //     biometricManager.biometricType,
                      //     style: TextStyle(
                      //       fontSize: 16,
                      //       color: _isDarkModeEnabled ? Colors.black : null,
                      //     ),
                      //   ),
                      //   onPressed: () {
                      //     _pressedBiometricButton();
                      //   },
                      // ),
                    ),
                  if (_isAuthenticating)
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Logging in...',
                        style: TextStyle(
                          fontSize: 16,
                          color: _isDarkModeEnabled ? Colors.white : null,
                        ),
                      ),
                    ),
                ],
              ),),
            ),
          ),
        ),
      ),
      ),
    );
  }

  /// validate fields are valid before enabling button to log in
  _validateField() {
    final password = _passwordTextController.text;
    if (password != null && password.isNotEmpty) {
      setState(() {
        _isFieldValid = true;
      });
    } else {
      setState(() {
        _isFieldValid = false;
      });
    }
  }

  /// log user in using master password
  void _logIn() async {
    setState(() {
      _isAuthenticating = true;
    });

    FocusScope.of(context).unfocus();

    final password = _passwordTextController.text;

    try {
      await cryptor.deriveKeyCheck(password, keyManager.salt).then((value) {
        // reset fields
        _passwordTextController.text = '';

        logManager.log("LockScreen", "_logIn", "deriveKeyCheck: $value");
        if (value) {
          Navigator.of(context).pop();

          HeartbeatTimer().startHeartbeatTimer();
        } else {
          _wrongPasswordCount += 1;

          /// save the logs on invalid states
          logManager.log("LockScreen", "_logIn", "Error: Invalid Password");
          logManager.saveLogs();
          if (_wrongPasswordCount % 3 == 0 && keyManager.hint.isNotEmpty) {
            _showErrorDialog('Invalid password\n\nhint: ${keyManager.hint}');
          } else {
            _showErrorDialog('Invalid password');
          }
        }

        setState(() {
          _isAuthenticating = false;
        });
      });
    } catch (e) {
      logManager.logger.d(e);

      /// save the logs on invalid states
      logManager.log("LockScreen", "_logIn", "Error: $e");
      logManager.saveLogs();
    }
  }

  /// authenticate the user with biometrics to unlock
  void _pressedBiometricButton() async {
    // await biometricManager.getAvailableBiometrics();
    final isBiometricsSupported = await biometricManager.doBiometricCheck();

    // print("no available biometrics: ${biometricManager.availableBiometrics}");

    if (!isBiometricsSupported) {
      // print("no available biometrics");
      _showErrorDialog('Biometrics unavailable');
      setState(() {
        _isBiometricLoginEnabled = false;
      });

      // await keyManager.deleteBiometricKey();
      EasyLoading.dismiss();
      return;
    }

    final status = await biometricManager.authenticateWithBiometrics();
    EasyLoading.show(status: "Authenticating...");

    if (status) {
      final setStatus = await keyManager.setBiometricKey();
      if (setStatus) {
        final logKeyMaterial = await keyManager.readLogKey();
        await cryptor.decodeAndSetLogKey(logKeyMaterial);

        HeartbeatTimer().startHeartbeatTimer();

        Navigator.of(context).pop();
      } else {
        _showErrorDialog('Biometric key cannot be read');
      }
    } else {
      /// save the logs on invalid states
      logManager.log("LockScreen", "_pressedBiometricButton", "Error");
      logManager.saveLogs();
      _showErrorDialog('Biometric error');
    }

    EasyLoading.dismiss();
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
