import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import '../managers/KeychainManager.dart';
import '../managers/Cryptor.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';


class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/change_password_screen';

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordTextController = TextEditingController();
  final _enterPasswordTextController = TextEditingController();
  final _confirmPasswordTextController = TextEditingController();
  final _passwordHintTextController = TextEditingController();

  final _currentPasswordFocusNode = FocusNode();
  final _enterPasswordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  final _passwordHintFocusNode = FocusNode();

  bool _hideCurrentPasswordField = true;
  bool _hideEnterPasswordField = true;
  bool _hideConfirmPasswordField = true;

  bool _isConfirmingCurrentPassword = true;
  bool _currentFieldIsValid = false;
  bool _fieldsAreValid = false;

  bool _isAuthenticating = false;

  bool _isDarkModeEnabled = false;

  int _wrongPasswordCount = 0;

  var _cryptor = Cryptor();
  var _keyManager = KeychainManager();
  var _logManager = LogManager();
  var _settingsManager = SettingsManager();


  @override
  void initState() {
    super.initState();

    _logManager.log("ChangePasswordScreen", "initState", "initState");

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;

    final isRecovered = _settingsManager.isRecoveredSession;

    _isConfirmingCurrentPassword = !isRecovered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black54 : Colors.white70,//Colors.blue[50],//Colors.grey[100],
      appBar: AppBar(
        title: Text('Change Password'),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
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
              if (_isConfirmingCurrentPassword)
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: TextFormField(
                    obscureText: _hideCurrentPasswordField,
                    autocorrect: false,
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 16,
                      color: _isDarkModeEnabled ? Colors.white : null,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Current Master Password',
                      contentPadding:
                          EdgeInsets.fromLTRB(10.0, 10.0, 0.0, 10.0),
                      hintStyle: TextStyle(
                        fontSize: 18.0,
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                      labelStyle: TextStyle(
                        fontSize: 18.0,
                        color: _isDarkModeEnabled ? Colors.white : null,
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      prefixIcon: Icon(
                        Icons.security,
                        color: _isDarkModeEnabled ? Colors.grey : null,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          Icons.remove_red_eye,
                          color: _hideCurrentPasswordField
                              ? Colors.grey
                              : _isDarkModeEnabled
                                  ? Colors.greenAccent
                                  : Colors.blueAccent,
                        ),
                        onPressed: () {
                          setState(() => _hideCurrentPasswordField =
                              !_hideCurrentPasswordField);
                        },
                      ),
                    ),
                    textInputAction: TextInputAction.go,
                    onChanged: (_) {
                      _validateCurrentField();
                    },
                    onTap: () {
                      _validateCurrentField();
                    },
                    onFieldSubmitted: (_) {
                      _validateCurrentField();

                      if (_currentFieldIsValid) {
                        setState(() {
                          _isAuthenticating = true;
                        });
                        Timer(Duration(milliseconds: 300), () async {
                          await _confirmCurrentMasterPassword();
                        });
                      }
                    },
                    focusNode: _currentPasswordFocusNode,
                    controller: _currentPasswordTextController,
                  ),
                ),
              Visibility(
                visible: !_isConfirmingCurrentPassword,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: TextFormField(
                    obscureText: _hideEnterPasswordField,
                    autocorrect: false,
                    style: TextStyle(
                      fontSize: 16,
                      color: _isDarkModeEnabled ? Colors.white : null,
                    ),
                    decoration: InputDecoration(
                      labelText: 'New Master Password',
                      contentPadding:
                          EdgeInsets.fromLTRB(10.0, 10.0, 0.0, 10.0),
                      hintStyle: TextStyle(
                        fontSize: 18.0,
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                      labelStyle: TextStyle(
                        fontSize: 18.0,
                        color: _isDarkModeEnabled ? Colors.white : null,
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
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
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      _validateNewFields();
                    },
                    onTap: () {
                      _validateNewFields();
                    },
                    onFieldSubmitted: (_) {
                      _validateNewFields();
                      FocusScope.of(context)
                          .requestFocus(_confirmPasswordFocusNode);
                    },
                    focusNode: _enterPasswordFocusNode,
                    controller: _enterPasswordTextController,
                  ),
                ),),
                Visibility(
                  visible: !_isConfirmingCurrentPassword,
                  child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: TextFormField(
                    autocorrect: false,
                    obscureText: _hideConfirmPasswordField,
                    style: TextStyle(
                      fontSize: 16,
                      color: _isDarkModeEnabled ? Colors.white : null,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Confirm New Master Password',
                      contentPadding:
                          EdgeInsets.fromLTRB(10.0, 10.0, 0.0, 10.0),
                      hintStyle: TextStyle(
                        fontSize: 18.0,
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                      labelStyle: TextStyle(
                        fontSize: 18.0,
                        color: _isDarkModeEnabled ? Colors.white : null,
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
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
                      _validateNewFields();
                    },
                    onTap: () {
                      _validateNewFields();
                    },
                    onFieldSubmitted: (_) {
                      _validateNewFields();
                      FocusScope.of(context)
                          .requestFocus(_passwordHintFocusNode);
                    },
                    focusNode: _confirmPasswordFocusNode,
                    controller: _confirmPasswordTextController,
                  ),
                ),),
              Visibility(
                visible: !_isConfirmingCurrentPassword,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: TextFormField(
                    cursorColor: _isDarkModeEnabled ? Colors.greenAccent : null,
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
                      fillColor:
                          _isDarkModeEnabled ? Colors.black12 : Colors.white10,
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
                    textInputAction: TextInputAction.go,
                    onChanged: (_) {
                      _validateNewFields();
                    },
                    onTap: () {
                      _validateNewFields();
                    },
                    onFieldSubmitted: (_) {
                      _validateNewFields();

                      if (_fieldsAreValid) {
                        FocusScope.of(context).unfocus();

                        setState(() {
                          _isAuthenticating = true;
                        });
                        Timer(Duration(milliseconds: 300), () async {
                          await _changeMasterPassword();
                        });
                      }
                    },
                    focusNode: _passwordHintFocusNode,
                    controller: _passwordHintTextController,
                  ),
                ),
              ),
              // if (_isConfirmingCurrentPassword)
              Visibility(
                visible: _isConfirmingCurrentPassword,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: _isDarkModeEnabled
                          ? MaterialStateProperty.all<Color>(Colors.greenAccent)
                          : null,
                    ),
                    onPressed: _currentFieldIsValid
                        ? () async {
                            FocusScope.of(context).unfocus();

                            setState(() {
                              _isAuthenticating = true;
                            });
                            Timer(Duration(milliseconds: 300), () async {
                              await _confirmCurrentMasterPassword();
                            });
                          }
                        : null,
                    child: Text(
                      'Confirm',
                      style: TextStyle(
                        fontSize: 16,
                        color: _isDarkModeEnabled ? Colors.black : null,
                      ),
                    ),
                  ),
                ),
              ),
              // if (!_isConfirmingCurrentPassword)
              Visibility(
                visible: !_isConfirmingCurrentPassword,
                child: Padding(
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
                    onPressed: _fieldsAreValid
                        ? () {
                            FocusScope.of(context).unfocus();

                            setState(() {
                              _isAuthenticating = true;
                            });
                            Timer(Duration(milliseconds: 300), () async {
                              await _changeMasterPassword();
                            });
                          }
                        : null,
                    child: Text(
                      'Update',
                      style: TextStyle(
                        fontSize: 16,
                        color: _isDarkModeEnabled ? Colors.black : null,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
              // if (_isAuthenticating && _isConfirmingCurrentPassword)
              Visibility(
                visible: (_isAuthenticating && _isConfirmingCurrentPassword),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Confirming...',
                    style: TextStyle(
                      fontSize: 16,
                      color: _isDarkModeEnabled ? Colors.white : null,
                    ),
                  ),
                ),
              ),
              // if (_isAuthenticating && !_isConfirmingCurrentPassword)
              Visibility(
                visible: (_isAuthenticating && !_isConfirmingCurrentPassword),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Changing Password...',
                    style: TextStyle(
                      fontSize: 16,
                      color: _isDarkModeEnabled ? Colors.white : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// determine if the necessary field(s) are filled out to enable the user
  /// to confirm the current password
  void _validateCurrentField() {
    final currentPassword = _currentPasswordTextController.text;
    if (currentPassword == null || currentPassword.isEmpty) {
      setState(() {
        _currentFieldIsValid = false;
      });
      return;
    }
    setState(() {
      _currentFieldIsValid = true;
    });
  }

  /// determine if the necessary fields are filled out to enable the user
  /// to confirm the new password
  void _validateNewFields() {
    final firstPassword = _enterPasswordTextController.text;
    if (firstPassword == null || firstPassword.isEmpty) {
      setState(() {
        _fieldsAreValid = false;
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

  /// confirm the current vault master password
  Future<void> _confirmCurrentMasterPassword() async {
    FocusScope.of(context).unfocus();

    final password = _currentPasswordTextController.text;

    _logManager.log(
        "ChangePasswordScreen", "_confirmCurrentMasterPassword", "confirming");

    try {
      _cryptor.deriveKeyCheck(password, _keyManager.salt).then((value) {
        _logManager.log("ChangePasswordScreen", "_confirmCurrentMasterPassword",
            "deriveKeyCheck: $value");

        // reset fields
        if (value) {
          _wrongPasswordCount = 0;
          _currentPasswordTextController.text = '';

          setState(() {
            _isAuthenticating = false;
            _isConfirmingCurrentPassword = false;
          });

          Timer(Duration(milliseconds: 200), () async {
            FocusScope.of(context)
                .requestFocus(_enterPasswordFocusNode);
          });

        } else {
          _wrongPasswordCount += 1;
          setState(() {
            _isAuthenticating = false;
          });
          if (_wrongPasswordCount % 3 == 0 && _keyManager.hint.isNotEmpty) {
            _showErrorDialog('Invalid password.\n\nhint: ${_keyManager.hint}');
          } else {
            _showErrorDialog('Invalid password.');
          }
        }
      });
    } catch (e) {
      _logManager.logger.w(e);
      _logManager.log(
          "ChangePasswordScreen", "_confirmCurrentMasterPassword", "Error: $e");
      _showErrorDialog('An error occurred');
    }
  }

  /// change the master password after confirming the current master password
  Future<void> _changeMasterPassword() async {
    final password = _enterPasswordTextController.text;
    final hint = _passwordHintTextController.text;

    _logManager.log("ChangePasswordScreen", "_changeMasterPassword", "changing");

    try {
      var updatedKeyParams = await _cryptor.deriveNewKey(password, hint);
        if (updatedKeyParams != null) {
          _enterPasswordTextController.text = "";
          _confirmPasswordTextController.text = "";
          _passwordHintTextController.text = "";

          /// save new encrypted key data
          final saveStatus = await _keyManager.saveMasterPassword(
              updatedKeyParams,
          );

          setState(() {
            _isAuthenticating = false;
          });

          await _keyManager.readEncryptedKey();

          _logManager.log("ChangePasswordScreen", "_changeMasterPassword",
              "deriveNewKey: $saveStatus");

          if (saveStatus) {
            _settingsManager.setIsRecoveredSession(false);
            EasyLoading.showToast(
              'Password Changed Successfully',
              duration: Duration(seconds: 3),
            );

            /// check if user pushed the app to the background while changing
            /// to new master password.  This way we dont pop off our lock screen
            if (_cryptor.aesRootSecretKeyBytes.isNotEmpty) {
              Navigator.of(context).pop();
            }

          } else {
            EasyLoading.showToast(
              'Password Change Failed',
              duration: Duration(seconds: 3),
            );
          }
        } else {
          setState(() {
            _isAuthenticating = false;
          });

          /// check if app was backgrounded while deriving key
          if (!_settingsManager.isOnLockScreen) {
            Navigator.of(context).pop();
            _showErrorDialog('An error occurred');
          }
        }
    } catch (e) {
      _logManager.logger.w(e);
      _logManager.log(
          "ChangePasswordScreen", "_changeMasterPassword", "Error: $e");
      _showErrorDialog('An error occurred');
    }
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

                Timer(Duration(milliseconds: 200), () async {
                  FocusScope.of(context).requestFocus(_currentPasswordFocusNode);
                });
              },
              child: Text('Okay'))
        ],
      ),
    );
  }

}
