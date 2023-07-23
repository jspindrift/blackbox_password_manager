import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '../managers/KeychainManager.dart';
import '../managers/Cryptor.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/BiometricManager.dart';
import 'home_tab_screen.dart';

/// Secret App Codes Screen
///

class SecretCodesScreen extends StatefulWidget {
  const SecretCodesScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/secret_codes_screen';

  @override
  State<SecretCodesScreen> createState() => _SecretCodesScreenState();
}

class _SecretCodesScreenState extends State<SecretCodesScreen> {
  final _enterCodePasscodeTextController = TextEditingController();
  final _enterCodeIndexTextController = TextEditingController();

  final _enterCodePasscodeFocusNode = FocusNode();
  final _enterCodeIndexFocusNode = FocusNode();

  bool _hideEnterPasscodeField = true;

  bool _fieldsAreValid = false;
  bool _isDarkModeEnabled = false;
  bool _isShowingPasscode = false;

  int _selectedIndex = 3;

  var cryptor = Cryptor();
  var keyManager = KeychainManager();
  var logManager = LogManager();
  var settingsManager = SettingsManager();
  final biometricManager = BiometricManager();

  @override
  void initState() {
    super.initState();

    logManager.log("SecretCodesScreen", "initState", "initState");

    _isDarkModeEnabled = settingsManager.isDarkModeEnabled;

    _enterCodeIndexTextController.text = "0";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text('Secret App Codes'),
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
              // Padding(
              //   padding: EdgeInsets.all(16.0),
              //   child: Card(
              //     color: _isDarkModeEnabled ? Colors.black54 : Colors.white,
              //     elevation: 4,
              //     child: ListTile(
              //       title: Padding(
              //         padding: EdgeInsets.fromLTRB(0, 4, 4, 4),
              //         child: Text(
              //           "Shared Secrets",
              //           style: TextStyle(
              //             color: _isDarkModeEnabled
              //                 ? Colors.greenAccent
              //                 : Colors.black,
              //           ),
              //         ),
              //       ),
              //       subtitle: Padding(
              //         padding: EdgeInsets.fromLTRB(0, 4, 4, 4),
              //         child: Text(
              //           "$_numberOfSecretShares items",
              //           style: TextStyle(
              //             color: _isDarkModeEnabled
              //                 ? Colors.greenAccent
              //                 : Colors.black,
              //           ),
              //         ),
              //       ),
              //       trailing: Icon(
              //         Icons.arrow_forward_ios,
              //         color: _isDarkModeEnabled
              //             ? Colors.greenAccent
              //             : Colors.blueAccent,
              //       ),
              //       onTap: () {
              //         Navigator.push(
              //           context,
              //           MaterialPageRoute(
              //             builder: (context) => SharedSecretsListScreen(),
              //           ),
              //         ).then((value) {
              //           keyManager
              //               .getAllEncryptedSecretShareItems()
              //               .then((value) {
              //             setState(() {
              //               _numberOfSecretShares = (value?.length)!;
              //             });
              //           });
              //         });
              //       },
              //     ),
              //   ),
              // ),
              // Divider(
              //   color: _isDarkModeEnabled ? Colors.greenAccent : null,
              // ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: TextFormField(
                  autocorrect: false,
                  obscureText: false,
                  style: TextStyle(
                    fontSize: 16,
                    color: _isDarkModeEnabled ? Colors.white : null,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Code Id',
                    contentPadding: EdgeInsets.fromLTRB(10.0, 10.0, 0.0, 10.0),
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
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    _validateNewFields();
                  },
                  onTap: () {
                    _validateNewFields();
                  },
                  onFieldSubmitted: (_) {
                    _validateNewFields();
                  },
                  keyboardType: TextInputType.text,
                  focusNode: _enterCodeIndexFocusNode,
                  controller: _enterCodeIndexTextController,
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: TextFormField(
                  obscureText: _hideEnterPasscodeField,
                  autocorrect: false,
                  style: TextStyle(
                    fontSize: 16,
                    color: _isDarkModeEnabled ? Colors.white : null,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Secret Code',
                    contentPadding: EdgeInsets.fromLTRB(10.0, 10.0, 0.0, 10.0),
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
                        color: _hideEnterPasscodeField
                            ? Colors.grey
                            : _isDarkModeEnabled
                                ? Colors.greenAccent
                                : Colors.blueAccent,
                      ),
                      onPressed: () {
                        setState(() =>
                            _hideEnterPasscodeField = !_hideEnterPasscodeField);
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
                  },
                  focusNode: _enterCodePasscodeFocusNode,
                  controller: _enterCodePasscodeTextController,
                ),
              ),

              // if (!_isConfirmingCurrentPassword)
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
                  onPressed: _fieldsAreValid
                      ? () {
                          // setState(() {
                          //   _isAuthenticating = true;
                          // });
                          // Timer(Duration(milliseconds: 200), () async {
                          //   await _changeRecoveryPasscode();
                          // });
                        }
                      : null,
                  child: Text(
                    'Go',
                    style: TextStyle(
                      fontSize: 16,
                      color: _isDarkModeEnabled ? Colors.black : null,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 2.0,
        backgroundColor: _isDarkModeEnabled ? Colors.black12 : Colors.white,
        // fixedColor: Colors.white,
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

    settingsManager.changeRoute(index);
  }

  /// determine if the necessary fields are filled out to enable the user
  /// to confirm the new passcode
  void _validateNewFields() {
    final firstPassword = _enterCodeIndexTextController.text;
    if (firstPassword == null || firstPassword.isEmpty) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    final secondPassword = _enterCodePasscodeTextController.text;
    if (secondPassword == null || secondPassword.isEmpty) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    // if (firstPassword == secondPassword) {
    setState(() {
      _fieldsAreValid = true;
    });
    // } else {
    //   setState(() {
    //     _fieldsAreValid = false;
    //   });
    // }
  }

  // /// change the master password after confirming the current master password
  // Future<void> _changeRecoveryPasscode() async {
  //   final passcode = _enterPasscodeTextController.text;
  //   logManager.log(
  //       "RecoveryPasscodeScreen", "_changeRecoveryPasscode", "changing");
  //
  //   try {
  //     // await cryptor.deriveNewKey(password).then((value) async {
  //     //
  //     //   String encodedSalt = base64.encode(cryptor.salt!);
  //     //   String encodedEncryptedKey = base64.encode(value);
  //
  //     // save new password details
  //     await keyManager.saveRecoveryPasscode(passcode).then((value) async {
  //       // await keyManager.saveLogKey(cryptor.logKeyMaterial);
  //       // await keyManager.readEncryptedKey();
  //
  //       logManager.log("RecoveryPasscodeScreen", "_changeRecoveryPasscode",
  //           "deriveNewKey: $value");
  //
  //       if (value) {
  //         _enterPasscodeTextController.text = '';
  //         _confirmPasscodeTextController.text = '';
  //
  //         EasyLoading.showToast(
  //           'Passcode Changed Successfully',
  //           duration: Duration(seconds: 3),
  //         );
  //       } else {
  //         EasyLoading.showToast(
  //           'Passcode Change Failed',
  //           duration: Duration(seconds: 3),
  //         );
  //       }
  //       setState(() {});
  //       // Navigator.of(context).pop();
  //     });
  //
  //     // Navigator.of(context).pop();
  //     // });
  //   } catch (e) {
  //     logManager.logger.w(e);
  //     logManager.log(
  //         "RecoveryPasscodeScreen", "_changeRecoveryPasscode", "Error: $e");
  //     _showErrorDialog('An error occurred');
  //   }
  // }

  // void _confirmedDeletePasscode() async {
  //   await keyManager.deleteRecoveryPasscodeKey();
  //
  //   setState(() {});
  // }

  // void _showConfirmDeletePasscodeDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       title: Text('Delete Passcode'),
  //       content: Text(
  //           'Any previously shared secrets encrypted with this passcode.  If you forget or lose this passcode you will not be able to recover them.'),
  //       actions: <Widget>[
  //         OutlinedButton(
  //           onPressed: () {
  //             Navigator.of(context).pop();
  //           },
  //           child: Text('Cancel'),
  //         ),
  //         OutlinedButton(
  //           style: TextButton.styleFrom(
  //             primary: Colors.redAccent,
  //           ),
  //           onPressed: () {
  //             Navigator.of(context).pop();
  //             _confirmedDeletePasscode();
  //           },
  //           child: Text('Delete'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

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
