import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pin_code_view/pin_code_view.dart';

import '../models/PinCodeItem.dart';
import '../managers/Cryptor.dart';
import '../managers/KeychainManager.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../helpers/AppConstants.dart';


/// flow determines if user is creating the pin code
/// or entering the code from the lock screen
enum PinCodeFlow {
  create,
  lock,
}

class PinCodeScreen extends StatefulWidget {
  const PinCodeScreen({
    Key? key,
    required this.flow,
  }) : super(key: key);
  static const routeName = '/pin_code_screen';

  final PinCodeFlow flow;

  @override
  State<PinCodeScreen> createState() => _PinCodeScreenState();
}

class _PinCodeScreenState extends State<PinCodeScreen> {
  String _initialPinCode = '';

  bool _isDarkModeEnabled = false;

  bool _shouldObscurePin = true;

  bool _isConfirmingPinCode = false;
  bool _isCreatingPinCode = false;
  bool _isCheckingPinCode = false;

  int _pinCodeAttemptsLeft = 3;
  int _pinCodeLength = 4;

  final _cryptor = Cryptor();
  final _keyManager = KeychainManager();
  final _logManager = LogManager();
  final _settingsManager = SettingsManager();


  @override
  void initState() {
    super.initState();

    _logManager.log("PinCodeScreen", "initState", "initState");

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;

    if (widget.flow == PinCodeFlow.lock) {
      /// save category tab index so we always land on this page to get vault item info
      _settingsManager.setCurrentTabIndex(1);

      _keyManager.getPinCodeItem().then((value) {
        setState(() {
          _pinCodeAttemptsLeft = 3 - value!.attempts;
        });
      });
    }
    else {
      Timer(Duration(milliseconds: 300), () {
        _showChoosePinCodeLength();
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
      backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
      appBar: AppBar(
        backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
        automaticallyImplyLeading:
            widget.flow == PinCodeFlow.create ? true : false,
        leading: widget.flow == PinCodeFlow.create
            ? CloseButton(
                color: _isDarkModeEnabled ? Colors.greenAccent : null,
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            : null,
        actions: [
          IconButton(
              onPressed: () {
                setState(() {
                  _shouldObscurePin = !_shouldObscurePin;
                });
              },
              icon: Icon(
                Icons.remove_red_eye,
                color: _isDarkModeEnabled
                    ? (_shouldObscurePin
                        ? Colors.greenAccent
                        : Colors.grey[200])
                    : (_shouldObscurePin ? Colors.white : Colors.grey[200]),
              ),
          ),
        ],
      ),
      body: PinCode(
        backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
        obscurePin: _shouldObscurePin,
        codeLength: _settingsManager.pinCodeLength,
        title: _isConfirmingPinCode ? "Confirm Pin Code" : "Enter PIN Code",
        subtitle: _isCreatingPinCode
            ? "Saving Pin Code..."
            : _isCheckingPinCode
                ? "Confirming Pin Code..."
                : widget.flow == PinCodeFlow.lock
                    ? (_pinCodeAttemptsLeft <= 2
                        ? "$_pinCodeAttemptsLeft attempts left"
                        : "")
                    : "",
        onChange: (String code) async {
          if (widget.flow == PinCodeFlow.create) {
            if (_isConfirmingPinCode) {
              if (_initialPinCode == code) {
                setState(() {
                  _isCreatingPinCode = true;
                  _initialPinCode = '';
                });

                /// Create pin code
                /// ...
                const duration = const Duration(milliseconds: 200);
                Timer(duration, () {
                  _createPinCode(code);
                });
              } else {
                _showErrorDialog('Pin Code Doesn\'t Match');
                setState(() {
                  _isConfirmingPinCode = false;
                  _initialPinCode = '';
                });
              }
            } else {
              setState(() {
                _initialPinCode = code;
                _isConfirmingPinCode = true;
              });
            }
          } else {
            setState(() {
              _isCheckingPinCode = true;
            });

            const duration = const Duration(milliseconds: 200);
            Timer(duration, () {
              _checkPinCode(code);
            });
          }
        }, //: (String code) async {},
      ),
      ),
    );
  }

  /// create the pin code item and save in keychain
  void _createPinCode(String code) async {
    try {
      final pinJsonString = await _cryptor.derivePinKey(code);
      // _logManager.logger.wtf("_createPinCode: derivePinKey: $pinJsonString");

      if (pinJsonString.isNotEmpty) {
        final status = await _keyManager.savePinCode(pinJsonString);
        // _logManager.logger.wtf("_createPinCode: save status: $status");

        if (status) {
          /// delete biometric key
          await _keyManager.deleteBiometricKey();

          /// deleteStatus can be false but we still want to confirm the
          /// saved pincode
          setState(() {
            _isConfirmingPinCode = false;
          });

          if (!_settingsManager.isOnLockScreen) {
            Navigator.of(context).pop('setPin');
          } else {
            setState(() {
              _isCreatingPinCode = false;
              _initialPinCode = '';
            });
          }
        } else {
          _showErrorDialog('Could Not Save Pin');
          _logManager.logger.w('Exception: _createPinCode: failure');
        }
      } else {
        /// this occurs while backgrounding the app while creating/deriving the key
        setState(() {
          _isConfirmingPinCode = false;
          _isCreatingPinCode = false;
          _initialPinCode = '';
        });
      }
    } catch (e) {
      _logManager.logger.w('Exception: _createPinCode: $e');
    }
  }

  /// check/validate the pin code from the lock screen
  void _checkPinCode(String code) async {
    // _logManager.logger.d("_checkPinCode: $code");
    try {
      final item = await _keyManager.getPinCodeItem();

      if (item != null) {
        var attempts = item.attempts;

        final status = await _cryptor.derivePinKeyCheck(item, code);
        if (status) {
          _logManager.log("PinCodeScreen", "_checkPinCode", "Valid Pin Code");

          /// if we have more than 1 previous failed attempt, we need to save
          /// a new pin code item with attempts reset to 0
          if (attempts > 0) {
            /// reset attempts and re-save item
            final newItem = PinCodeItem(
              id: item.id,
              version: AppConstants.pinCodeItemVersion,
              attempts: 0,
              rounds: item.rounds,
              salt: item.salt,
              keyMaterial: item.keyMaterial,
              cdate: item.cdate,
            );

            final newItemString = newItem.toRawJson();

            final statusSave = await _keyManager.savePinCode(newItemString);

            if (statusSave) {
              Navigator.of(context).pop('login');
              // Navigator.pop(context, 'login');

            } else {
              _showErrorDialog("Couldn't Save Pin Code");

              _logManager.logger.w("Couldn't save pincode");
              _logManager.log(
                  "PinCodeScreen", "_checkPinCode", "Couldn't save pincode");
            }
          } else {
            Navigator.of(context).pop('login');
          }
        } else {
          /// increment attempts and re-save pin code item
          ///
          _logManager.log("PinCodeScreen", "_checkPinCode",
              "Invalid Pin Code: ${attempts + 1}");
          attempts += 1;

          /// check pin code attempts
          if (attempts >= 3) {
            final statusDelete = await _keyManager.deletePinCode();
            if (statusDelete) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            } else {
              _logManager.logger.w("Couldn't delete pincode");
              _logManager.log(
                  "PinCodeScreen", "_checkPinCode", "Couldn't delete pincode");

              final statusDelete2 = await _keyManager.deletePinCode();
              if (statusDelete2) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              } else {
                _logManager.logger.w("Couldn't delete pincode x2");
                _logManager.log("PinCodeScreen", "_checkPinCode",
                    "Couldn't delete pincode x2");
              }
            }
          } else {
            _showErrorDialog('Invalid Pin Code');
            _logManager.saveLogs();

            setState(() {
              _pinCodeAttemptsLeft -= 1;
            });

            final newItem = PinCodeItem(
              id: item.id,
              version: AppConstants.pinCodeItemVersion,
              attempts: attempts,
              rounds: item.rounds,
              salt: item.salt,
              keyMaterial: item.keyMaterial,
              cdate: item.cdate,
            );

            final newItemString = newItem.toRawJson();

            final statusSave = await _keyManager.savePinCode(newItemString);

            if (!statusSave) {
              _logManager.logger.w("Couldn't save pincode");
              _logManager.log(
                  "PinCodeScreen", "_checkPinCode", "Couldn't save pincode");
            }
          }
        }
      } else {
        _logManager.log("PinCodeScreen", "_checkPinCode", "pincode not found");
        _logManager.logger.w("pincode not found");
        Navigator.of(context).popUntil((route) => route.isFirst);
        _showErrorDialog('Pin Code Not Found');
      }

      setState(() {
        _isCheckingPinCode = false;
      });
    } catch (e) {
      _logManager.logger.w('Exception: _checkPinCode: $e');
    }
  }

  void _showChoosePinCodeLength() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Set Number of Digits'),
        // content: Text(message),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () async {
              await _settingsManager.savePinCodeLength(4);
              setState(() {});
              Navigator.of(ctx).pop();
              Navigator.of(ctx).pop();
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _settingsManager.savePinCodeLength(4);
              setState(() {});
              Navigator.of(ctx).pop();
            },
            child: Text('4'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _settingsManager.savePinCodeLength(6);
              setState(() {});
              Navigator.of(ctx).pop();
            },
            child: Text('6'),
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
            child: Text('Okay'),
          ),
        ],
      ),
    );
  }
}
