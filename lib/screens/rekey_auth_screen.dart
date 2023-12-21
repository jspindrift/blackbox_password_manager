import 'dart:async';
import 'package:flutter/material.dart';

import '../managers/KeychainManager.dart';
import '../managers/Cryptor.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/KeyScheduler.dart';


class ReKeyAuthScreen extends StatefulWidget {
  const ReKeyAuthScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/rekey_auth_screen';

  @override
  State<ReKeyAuthScreen> createState() => _ReKeyAuthScreenState();
}

class _ReKeyAuthScreenState extends State<ReKeyAuthScreen> {
  final _currentPasswordTextController = TextEditingController();
  final _currentPasswordFocusNode = FocusNode();

  bool _hideCurrentPasswordField = true;
  bool _isConfirmingCurrentPassword = true;
  bool _currentFieldIsValid = false;
  bool _reKeyInProgress = false;
  bool _isAuthenticating = false;
  bool _isDarkModeEnabled = false;

  int _wrongPasswordCount = 0;

  var _cryptor = Cryptor();
  var _keyManager = KeychainManager();
  var _logManager = LogManager();
  var _settingsManager = SettingsManager();
  var _keyScheduler = KeyScheduler();


  @override
  void initState() {
    super.initState();

    _logManager.log("ReKeyAuthScreen", "initState", "initState");

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;

    final isRecovered = _settingsManager.isRecoveredSession;

    _isConfirmingCurrentPassword = !isRecovered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black54 : Colors.blue[50],//Colors.grey[100],
      appBar: AppBar(
        title: Text('Re-Key Vault'),
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
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      _validateCurrentField();
                    },
                    onTap: () {
                      _validateCurrentField();
                    },
                    onFieldSubmitted: (_) {
                      _validateCurrentField();
                    },
                    focusNode: _currentPasswordFocusNode,
                    controller: _currentPasswordTextController,
                  ),
                ),
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
              Visibility(
                visible: (_isAuthenticating && _isConfirmingCurrentPassword),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Confirming Password...',
                    style: TextStyle(
                      fontSize: 16,
                      color: _isDarkModeEnabled ? Colors.white : null,
                    ),
                  ),
                ),
              ),
              // if (_isAuthenticating && !_isConfirmingCurrentPassword)
              Visibility(
                visible: _reKeyInProgress,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Column(
                      children: [
                      Text(
                    'Re-Keying Vault...\nPlease wait and do not leave app',
                    style: TextStyle(
                      fontSize: 16,
                      color: _isDarkModeEnabled ? Colors.white : null,
                    ),
                  ),
                        // ProgressIndicator(value: ,)
                        CircularProgressIndicator(
                          color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                          backgroundColor: _isDarkModeEnabled ? Colors.grey : Colors.grey,
                          value: null,
                          // value: _otpIntervalIncrement == 0 ? 0.0 : (_otpIntervalIncrement/30),
                          // valueColor: _isDarkModeEnabled ? AlwaysStoppedAnimation<Color>(Colors.pinkAccent) : AlwaysStoppedAnimation<Color>(Colors.redAccent),
                          semanticsLabel: "time interval",
                          // semanticsValue: (_otpIntervalIncrement/30).toString(),
                        ),
                    ],),
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

  /// confirm the current vault master password
  Future<void> _confirmCurrentMasterPassword() async {
    FocusScope.of(context).unfocus();

    final password = _currentPasswordTextController.text;

    _logManager.log(
        "ReKeyAuthScreen", "_confirmCurrentMasterPassword", "confirming");

    try {
      final status = await _cryptor.deriveKeyCheck(password, _keyManager.salt);
        _logManager.log("ReKeyAuthScreen", "_confirmCurrentMasterPassword",
            "deriveKeyCheck: $status");

        if (status) {
          _wrongPasswordCount = 0;
          _currentPasswordTextController.text = '';

          setState(() {
            _isAuthenticating = false;
            _isConfirmingCurrentPassword = false;
          });

          _showReKeyConfirmatinoDialog(password);

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
      // });
    } catch (e) {
      _logManager.logger.w(e);
      _logManager.log(
          "ReKeyAuthScreen", "_confirmCurrentMasterPassword", "Error: $e");
      _showErrorDialog('An error occurred');
    }
  }

  Future<bool> reKey(String password) async {
    final status = await _keyScheduler.startReKeyService(password);

    setState(() {
      _reKeyInProgress = false;
    });

    if (status) {

      _logManager.logger.d("reKey COMPLETE!!!! success, check it out.");

      // Navigator.of(context).popUntil((route) => route.isFirst);
      _showCompletionDialog("Complete");

    } else {
      _showErrorDialog("Error re-keying vault.  Be Aware!!");
    }
    return status;
  }

  void _showReKeyConfirmatinoDialog(String password) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Re-Key Vault'),
        content: Text("Warning, this is a sensitive operation.  Please wait for the process the finish and dont background the app.\n\nDo you wish to proceed?"),
        actions: <Widget>[
          ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();

                FocusScope.of(context).requestFocus(_currentPasswordFocusNode);
              },
              child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();

              setState(() {
                _reKeyInProgress = true;
              });

              Timer(Duration(milliseconds: 300), () async {
                await reKey(password);
              });
            },
            child: Text('Okay'),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Re-Key Complete'),
        content: Text(message),
        actions: <Widget>[
          ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();

                // FocusScope.of(context).requestFocus(_currentPasswordFocusNode);
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

                FocusScope.of(context).requestFocus(_currentPasswordFocusNode);
              },
              child: Text('Okay'))
        ],
      ),
    );
  }


}
