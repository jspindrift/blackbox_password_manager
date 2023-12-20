import 'dart:convert';
import 'dart:async';

import 'package:argon2/argon2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:password_strength/password_strength.dart';
import 'package:random_password_generator/random_password_generator.dart';
import 'package:bip39/bip39.dart' as bip39;

import '../widgets/qr_code_view.dart';
import '../models/GeoLockItem.dart';
import '../helpers/AppConstants.dart';
import '../helpers/WidgetUtils.dart';
import '../managers/GeolocationManager.dart';
import '../managers/Cryptor.dart';
import '../managers/KeychainManager.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../models/PasswordItem.dart';
import '../models/GenericItem.dart';
import '../models/QRCodeItem.dart';
import '../screens/previous_passwords_screen.dart';
import '../screens/show_bip39_screen.dart';
import 'home_tab_screen.dart';

enum PasswordType { random, mnemonic, pin }

const List<String> delimeterList = <String>[
  'space',
  'hyphen',
  'comma',
  'period',
  'underscores',
];

class EditPasswordScreen extends StatefulWidget {
  const EditPasswordScreen({
    Key? key,
    required this.id,
    required this.passwordList,
  }) : super(key: key);
  static const routeName = '/edit_password_screen';

  final String id;
  final List<String> passwordList;

  @override
  State<EditPasswordScreen> createState() => _EditPasswordScreenState();
}

class _EditPasswordScreenState extends State<EditPasswordScreen> {
  /// test geo-lock
  static const bool _testGeoLock = true;
  static const bool _debugRand = false;

  final _nameTextController = TextEditingController();
  final _usernameTextController = TextEditingController();
  final _passwordTextController = TextEditingController();
  final _notesTextController = TextEditingController();
  final _tagTextController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _notesFocusNode = FocusNode();

  int _selectedIndex = 0;

  bool _isLocationSettingsEnabled = false;

  bool _isPasswordBip39Valid = false;
  bool _duplicatePassword = false;
  bool _isDarkModeEnabled = false;
  bool _tagTextFieldValid = false;

  bool _didWarnOfChange = false;
  bool _isEditing = true;
  bool _hidePasswordField = true;
  bool _fieldsAreValid = false;
  bool _fieldsAreChanged = false;
  bool _isFavorite = false;

  PasswordItem? _passwordItem;
  GeoLockItem? _geoLockItem;

  DateTime _createdDate = DateTime.now();
  DateTime _modifiedDate = DateTime.now();

  String _initialPassword = '';
  String _itemPropertiesString = '';
  QRCodeItem qrItem = QRCodeItem(name: '', username: '', password: '');

  List<PreviousPassword> _previousPasswords = [];
  List<PreviousPassword> _initialEncryptedPreviousPasswords = [];
  List<PreviousPassword> _decryptedPreviousPasswordList = [];

  List<String> _passwordTags = [];
  List<bool> _selectedTags = [];
  List<String> _filteredTags = [];

  bool _isWithLetters = true;
  bool _isWithNumbers = false;
  bool _isWithSpecial = false;
  bool _isWithUppercase = true;

  bool _isBip39Valid = false;

  /// Geo Lock
  bool _isGeoLockedEnabled = false;
  bool _isInitiallyGeoLocked = false;
  bool _isDecryptingGeoLock = false;
  bool _hasDecryptedGeoLock = false;
  bool _isOutOfRange = false;

  double _passwordStrength = 0.0;
  double _randomPasswordStrength = 0.0;

  double _numberCharPassword = 12.0;
  double _numberPinDigits = 12.0;
  int _numberCharPasswordLabel = 12;
  int _numberWordsLabel = 12;
  int _numberPinDigitsLabel = 12;

  static const _maxNumberChars = 100;
  static const _maxNumberWords = 24;
  static const _maxNumberPinDigits = 100;

  double _charactersSliderValue = 0.12;
  double _wordsSliderValue = 0.5;
  double _pinSliderValue = 12 / _maxNumberPinDigits;

  final _randomGenerator = RandomPasswordGenerator();
  String _randomPassword = '';

  PasswordType _selectedSegment = PasswordType.random;

  String _dropdownValue = delimeterList.first;

  /// subscriptions
  late StreamSubscription onLocationSettingsChangeSubscription;
  late StreamSubscription onGeoLocationUpdateSubscription;

  final _cryptor = Cryptor();
  final _keyManager = KeychainManager();
  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _geolocationManager = GeoLocationManager();

  @override
  void initState() {
    super.initState();

    _logManager.log("EditPasswordScreen", "initState", "initState");

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;

    _selectedIndex = _settingsManager.currentTabIndex;

    _filteredTags = _settingsManager.itemTags;

    if (_testGeoLock) {
      if (_geolocationManager.geoLocationUpdate == null) {
        _geolocationManager.initialize();
      }
    }

    _isLocationSettingsEnabled = _geolocationManager.isLocationSettingsEnabled;

    _getPasswordItem();

    onLocationSettingsChangeSubscription =
        _geolocationManager.onLocationSettingsChange.listen((event) {
      _logManager.logger.d("onLocationSettingsChangeSubscription: $event");
      setState(() {
        _isLocationSettingsEnabled = event;
      });
    });

    onGeoLocationUpdateSubscription = GeoLocationManager()
        .onGeoLocationUpdate
        .listen((geoLocationUpdate) async {
      final userLocationString =
          "position: ${geoLocationUpdate.userLocation.latitude}, ${geoLocationUpdate.userLocation.longitude}";
      // _logManager.logger.d(
      //     "EditPassword: onGeoLocationUpdate: userLocationString: $userLocationString");
      if (!_isInitiallyGeoLocked) {
        _logManager.logger.d("not initially geo locked, returning");
        return;
      } else {
        // _isGeoLockedEnabled = true;
        _validateFields();

        if (_hasDecryptedGeoLock && !_isEditing) {
          _logManager.logger.d("geo locked, already decrypted");

          /// TODO: still do decryption to see if we fall out of range
          /// cant save edited passwords when we fall out of range unless we turn
          /// geoLock off and save, then turn back on and save
          final decryptedPassword = await decryptGeoLock(geoLocationUpdate);

          if (decryptedPassword.isNotEmpty) {
            // _logManager.logger.d("debug: geoLock: We are still within range: $decryptedPassword");

            _isBip39Valid = (_passwordItem?.isBip39)!;
            // _logManager.logger.d("debug: geoLock: We are still within range: $_isBip39Valid");

            if (_isBip39Valid) {
              final mnemonic = bip39.entropyToMnemonic(decryptedPassword);
              setState(() {
                _passwordTextController.text = mnemonic;
              });
            } else {
              setState(() {
                _passwordTextController.text = decryptedPassword;
              });
            }
            setState(() {
              _isOutOfRange = false;
            });
          } else {
            _logManager.logger.d("debug: geoLock: We are out of range");
            setState(() {
              _passwordTextController.text = "";
              _isOutOfRange = true;
            });
          }

          return;
        } else if (!_isEditing) {
          _logManager.logger.d("geo locked, not decrypted, trying decryption");

          final decryptedPassword = await decryptGeoLock(geoLocationUpdate);

          if (decryptedPassword.isNotEmpty) {
            _logManager.logger.d("geo locked decrypted successfully");

            setState(() {
              _isOutOfRange = false;
              _hasDecryptedGeoLock = true;
              _isDecryptingGeoLock = false;
            });

            if (_isBip39Valid) {
              final mnemonic = bip39.entropyToMnemonic(decryptedPassword);

              setState(() {
                _passwordTextController.text = mnemonic;
                _initialPassword = mnemonic;
              });
            } else {
              setState(() {
                _passwordTextController.text = decryptedPassword;
                _initialPassword = decryptedPassword;
              });
            }
          } else {
            _logManager.logger.d("geo locked decrypted unsuccessfully");
            setState(() {
              _passwordTextController.text = "";
              _isOutOfRange = true;
              _hasDecryptedGeoLock = false;
              _isDecryptingGeoLock = true;
            });
          }
        }
      }
    });

    /// We do this so tags show up in the UI when added.
    /// Not sure why this works but it does
    Timer(Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(_notesFocusNode);
      FocusScope.of(context).requestFocus(_nameFocusNode);
      FocusScope.of(context).unfocus();

      setState(() {
        _isEditing = false;
      });
    });
  }

  void _throwError() {
    if (mounted) {
      setState(() {
        _passwordTextController.text = "Invalid Item";
        _hidePasswordField = false;
        _showErrorDialog("Error Reading Item");
      });
    }
  }

  Future<void> _getPasswordItem() async {

    final genItemString = await _keyManager.getItem(widget.id);
    final genericItem = GenericItem.fromRawJson(genItemString);

    if (genericItem.type != "password") {
      _throwError();
      return;
    }

    try {
      /// must be a PasswordItem type
      _passwordItem = PasswordItem.fromRawJson(genericItem.data);

      if (_passwordItem == null) {
        _throwError();
        return;
      }

      final macCheck = await _passwordItem?.checkMAC() ?? false;
      if (!macCheck) {
        _showErrorDialog("Password Item Invalid.  MAC check failed.");
        return;
      }

      var name = (_passwordItem?.name)!;
      var username = (_passwordItem?.username)!;
      var tags = (_passwordItem?.tags)!;
      var dpassword = "";

      /// TODO: add geo-lock
      if (_passwordItem?.geoLock != null) {
        /// only activate location settings here on init
        /// otherwise init it on geolocation switch
        /// TODO: un/comment this back in
        // if (_geolocationManager.geoLocationUpdate == null) {
        //   _geolocationManager.initialize();
        // }

        _geoLockItem = (_passwordItem?.geoLock)!;

        if (_geoLockItem != null) {
          setState(() {
            _isInitiallyGeoLocked = true;
            _isGeoLockedEnabled = true;
            _isDecryptingGeoLock = true;
          });
        } else {
          setState(() {
            _isOutOfRange = false;
            _isDecryptingGeoLock = false;
          });
        }
      }

      for (var tag in tags) {
        _selectedTags.add(false);
      }

      _passwordTags = tags;

      var isFavorite = (_passwordItem?.favorite)!;

      _isFavorite = isFavorite;
      _isBip39Valid = (_passwordItem?.isBip39)!;

      final notes = (_passwordItem?.notes)!;

      final cdate = (_passwordItem?.cdate)!;
      _createdDate = DateTime.parse(cdate);

      final mdate = (_passwordItem?.mdate)!;
      _modifiedDate = DateTime.parse(mdate);

      final encryptedPreviousPasswords =
      (_passwordItem?.previousPasswords)!;
      _initialEncryptedPreviousPasswords = encryptedPreviousPasswords;

      if (!_isInitiallyGeoLocked) {
        final blob = (_passwordItem?.password)!;

        /// decrypt password
        final pwd = await _cryptor.decrypt(blob);
        dpassword = pwd;
        if (_isBip39Valid) {
          dpassword = bip39.entropyToMnemonic(pwd);

          _passwordTextController.text = dpassword;
        } else {
          _passwordTextController.text = dpassword;
        }

        final hasPasswordInList =
        widget.passwordList.contains(dpassword);

        if (hasPasswordInList) {
          var dupeCount = 0;
          for (var pwd in widget.passwordList) {
            if (pwd == dpassword) {
              dupeCount += 1;
            }
          }
          if (dupeCount > 1) {
            _duplicatePassword = true;
          }
        }

        setState(() {
          _passwordStrength = estimatePasswordStrength(dpassword);
        });

        _validateFields();
      } else {
        if (_geolocationManager.geoLocationUpdate != null) {
          final pwd = await decryptGeoLock(
              _geolocationManager.geoLocationUpdate!,
          );

          dpassword = pwd;
          if (pwd.isNotEmpty) {
            _logManager.logger.d("geo locked decrypted successfully");

            setState(() {
              _isOutOfRange = false;
              _hasDecryptedGeoLock = true;
              _isDecryptingGeoLock = false;
            });

            if (_isBip39Valid) {
              dpassword = bip39.entropyToMnemonic(dpassword);

              setState(() {
                _passwordTextController.text = dpassword;
                _hasDecryptedGeoLock = true;
              });
            } else {
              setState(() {
                _passwordTextController.text = dpassword;
                _hasDecryptedGeoLock = true;
              });
            }
          } else {
            setState(() {
              _isOutOfRange = true;
              _logManager.logger.d("is out of range");
            });
          }

          _validateFields();
        } else {
          print("geo update is null");
        }
      }

      final dname = await _cryptor.decrypt(name);
      /// decrypt username
      final dusername = await _cryptor.decrypt(username);
      /// decrypt notes
      final dnotes = await _cryptor.decrypt(notes);

      setState(() {
        _nameTextController.text = dname;
        _usernameTextController.text = dusername;
        _notesTextController.text = dnotes;
        _initialPassword = dpassword;
      });

      _itemPropertiesString =
      '$dname.$dusername.${tags
          .toString()}.$isFavorite.$_initialPassword.$dnotes';

      qrItem = QRCodeItem(
          name: dname, username: dusername, password: dpassword);

      /// decrypt previous passwords
      if (encryptedPreviousPasswords.isNotEmpty) {
        var index = 0;
        for (var pp in encryptedPreviousPasswords) {
          index += 1;
          var decryptedPreviousPassword = await _cryptor.decrypt(pp.password);

          if (pp.isBip39) {
            decryptedPreviousPassword =
                _cryptor.entropyToMnemonic(decryptedPreviousPassword);
          }

          final decrypedPreviousItem = PreviousPassword(
            password: decryptedPreviousPassword,
            isBip39: pp.isBip39,
            cdate: pp.cdate,
          );
          _previousPasswords.add(decrypedPreviousItem);
        }

        cyclePreviousPasswords();
      }

      _validateFields();
    } catch (e) {
      _logManager.logger.wtf("Exception: $e");
    }

  }

  Future<String> decryptGeoLock(GeoLocationUpdate geoLocationUpdate) async {
    try {
      if (_passwordItem != null
          && geoLocationUpdate != null
          && _geoLockItem != null) {
        final owner_lat_tokens = _geoLockItem?.lat_tokens;
        final owner_long_tokens = _geoLockItem?.long_tokens;

        // _logManager.logger.d("owner_lat_tokens: ${owner_lat_tokens}\n"
        //     "owner_long_tokens:\n ${owner_long_tokens}");
        List<int> decoded_lat_tokens = [];
        List<int> decoded_long_tokens = [];

        // for (var lat_tok_enc in owner_lat_tokens!) {
        final decoded = List<int>.from(base64.decode(owner_lat_tokens!));
        decoded_lat_tokens = decoded;
        // }

        // for (var long_tok_enc in owner_long_tokens!) {
        final decoded2 = List<int>.from(base64.decode(owner_long_tokens!));
        decoded_long_tokens = decoded2;
        // }

        // _logManager.logger.d("decoded: ${decoded.length}: ${decoded}\n"
        //     "decoded2:\n ${decoded2.length}: ${decoded2}");

        final encryptedPassword = (_passwordItem?.password)!;

        final decryptedGeoItem = await _cryptor.geoDecrypt(
          geoLocationUpdate.userLocation.latitude,
          geoLocationUpdate.userLocation.longitude,
          decoded_lat_tokens,
          decoded_long_tokens,
          encryptedPassword,
        );

        // _logManager.logger.d("decryptedGeoItem: ${decryptedGeoItem}\n");

        if (decryptedGeoItem == null) {
          return "";
        }

        final decryptedPassword = decryptedGeoItem.decryptedPassword;

        final ilat = decryptedGeoItem.index_lat;
        final ilong = decryptedGeoItem.index_long;

        var ilat2 = (ilat >= 16 ? ilat % 16 : 16 - ilat);
        var ilong2 = (ilong >= 16 ? ilong % 16 : 16 - ilong);

        final inc_lat = 0.0001 * ilat2;
        final inc_long = 0.0001 * ilong2;

        var lat = _geolocationManager.geoLocationUpdate?.userLocation.latitude;
        var long = _geolocationManager.geoLocationUpdate?.userLocation.longitude;

        var latneg = false;
        var lat_abs = 0.0;
        if (lat! < 0) {
          latneg = true;
          if (ilat <= 16) {
            lat_abs = lat.abs() + inc_lat;
          } else {
            lat_abs = lat.abs() - inc_lat;
          }
        }

        var longneg = false;
        var long_abs = 0.0;
        if (long! < 0) {
          longneg = true;
          if (ilong <= 16) {
            long_abs = long.abs() + inc_long;
          } else {
            long_abs = long.abs() - inc_long;
          }
        }

        if (latneg) {
          lat = -lat_abs;
        }

        if (longneg) {
          long = -long_abs;
        }

        return decryptedPassword;
      }

      return "";
    } catch (e) {
      _logManager.logger.w("decryptGeoLock failed: $e");
      return "";
    }
  }

  /// go through our previous passwords and add to our list of
  /// decrypted previous passwords to show on the previous password screen
  void cyclePreviousPasswords() {

    _decryptedPreviousPasswordList = [];

    setState(() {
      _previousPasswords.forEach((element) {
        var decodedPassword = element.password;
        // _logManager.logger.d("pwd: ${element.password}");

        final previousDecoded = PreviousPassword(
          password: decodedPassword,
          isBip39: element.isBip39,
          cdate: element.cdate,
        );
        _decryptedPreviousPasswordList.add(previousDecoded);
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    // cancel subscriptions here
    onLocationSettingsChangeSubscription.cancel();
    onGeoLocationUpdateSubscription.cancel();

    /// TODO: un/comment this back in
    // _geolocationManager.shutdown();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text('Password'),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: !_isEditing ? BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () async {
            await onLocationSettingsChangeSubscription.cancel();
            await onGeoLocationUpdateSubscription.cancel();

            Navigator.of(context).pop();
          },
        ) : CloseButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () async {
            setState((){
              _didWarnOfChange = false;
              _isEditing = false;
            });

            await _getPasswordItem();
          },
        ),
        actions: [
          if (_isEditing)
            TextButton(
              child: Text(
                "Save",
                style: TextStyle(
                  color: _isDarkModeEnabled
                      ? (_fieldsAreValid ? Colors.greenAccent : Colors.grey)
                      : (_fieldsAreValid ? Colors.white : Colors.grey),
                  fontSize: 18,
                ),
              ),
              onPressed: _fieldsAreValid
                  ? () async {
                      setState(() {
                        _didWarnOfChange = false;
                        _isEditing = !_isEditing;
                      });

                      await _pressedSaveItem();

                      Timer(Duration(milliseconds: 100), () {
                        FocusScope.of(context).unfocus();
                      });
                    }
                  : null,
            ),
          if (!_isEditing)
            TextButton(
              child: Text(
                "Edit",
                style: TextStyle(
                  color: _isDarkModeEnabled
                      ? (_fieldsAreValid ? Colors.greenAccent : Colors.grey)
                      : (_fieldsAreValid ? Colors.white : Colors.grey),
                  fontSize: 18,
                ),
              ),
              onPressed: !_isOutOfRange
                  ? () {
                      setState(() {
                        _isEditing = !_isEditing;
                      });
                    }
                  : null,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(16.0),
                child: TextFormField(
                  maxLines: 1,
                  autofocus: true,
                  autocorrect: false,
                  enabled: _isEditing,
                  style: TextStyle(
                    fontSize: 18.0,
                    color: _isDarkModeEnabled ? Colors.white : null,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Name',
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
                    disabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color:
                            _isDarkModeEnabled ? Colors.blueGrey : Colors.grey,
                        width: 0.0,
                      ),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) {
                    _validateFieldsAreChanged();
                  },
                  onTap: () {
                    setState(() {
                      _isEditing = true;
                    });
                    _validateFieldsAreChanged();
                  },
                  onFieldSubmitted: (_) {
                    _validateFieldsAreChanged();
                  },
                  keyboardType: TextInputType.name,
                  focusNode: _nameFocusNode,
                  controller: _nameTextController,
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: TextFormField(
                  autocorrect: false,
                  enabled: _isEditing,
                  readOnly: false,
                  style: TextStyle(
                    fontSize: 18.0,
                    color: _isDarkModeEnabled ? Colors.white : null,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Username/Email',
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
                    disabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color:
                            _isDarkModeEnabled ? Colors.blueGrey : Colors.grey,
                        width: 0.0,
                      ),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) {
                    _validateFieldsAreChanged();
                  },
                  onTap: () {
                    setState(() {
                      _isEditing = true;
                    });
                    _validateFieldsAreChanged();
                  },
                  onFieldSubmitted: (_) {
                    // _validateFields();
                    _validateFieldsAreChanged();
                  },
                  focusNode: _usernameFocusNode,
                  controller: _usernameTextController,
                ),
              ),
              Visibility(
                visible: true, // !_isOutOfRange
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          // expands: false,
                          autocorrect: false,
                          enabled: true,
                          readOnly: !_isEditing,
                          obscureText: _hidePasswordField,
                          minLines: 1,
                          maxLines: _hidePasswordField ? 1 : 8,
                          style: TextStyle(
                            fontSize: 18.0,
                            color: _isDarkModeEnabled ? Colors.white : null,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Password',
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
                            disabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _isDarkModeEnabled
                                    ? Colors.blueGrey
                                    : Colors.grey,
                                width: 0.0,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.security,
                              color: _isDarkModeEnabled ? Colors.grey : null,
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onChanged: (pwd) {
                            double strength = estimatePasswordStrength(pwd);
                            setState(() {
                              _passwordStrength = strength;
                            });
                            _validateFieldsAreChanged();
                            _checkForDuplicates(pwd);
                          },
                          onFieldSubmitted: (_) {
                            _validateFieldsAreChanged();
                          },
                          keyboardType: TextInputType.visiblePassword,
                          focusNode: _passwordFocusNode,
                          controller: _passwordTextController,
                        ),
                      ),
                      // ),
                      IconButton(
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
                    ],
                  ),
                ),
              ),
              Visibility(
                visible: false, //_isOutOfRange,
                child: Container(
                  color: Colors.red,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "Password cannot be decrypted. Go to the original location where you Geo-Locked this item to decrypt.",
                      style: TextStyle(
                        color: _isDarkModeEnabled ? Colors.white : null,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              Visibility(
                visible: _duplicatePassword,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: ListTile(
                    tileColor: Colors.red,
                    title: Text(
                      "Duplicate Password",
                      style: TextStyle(
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                    ),
                    subtitle: Text(
                      "This password is used somewhere else.  Please use a different password.",
                      style: TextStyle(
                        color: _isDarkModeEnabled ? Colors.white : null,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
              Visibility(
                visible: _testGeoLock ? !_isOutOfRange : true,
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 0.0),
                        child: LinearProgressIndicator(
                          color: _isDarkModeEnabled
                              ? (_isPasswordBip39Valid
                                  ? Colors.purpleAccent
                                  : Colors.greenAccent)
                              : (_isPasswordBip39Valid
                                  ? Colors.purpleAccent
                                  : Colors.greenAccent),
                          backgroundColor: _isDarkModeEnabled
                              ? Colors.blueGrey
                              : Colors.grey,
                          value: _passwordStrength,
                          semanticsLabel: 'Password strength indicator',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 5,
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(0.0, 0.0, 16.0, 0.0),
                      child: Text(
                        "${_passwordStrength.toStringAsFixed(2)}",
                        style: TextStyle(
                          color:
                              _isDarkModeEnabled ? Colors.white : Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    // Visibility(
                    //   visible: _isPasswordBip39Valid,
                    //   child: Padding(
                    //     padding: EdgeInsets.fromLTRB(0.0, 0.0, 8.0, 0.0),
                    //     child: Icon(
                    //       Icons.check_circle,
                    //       color: _isDarkModeEnabled ? Colors.greenAccent : null,
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
              Visibility(
                visible: true, //!_isOutOfRange,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    child: Text(
                      'Generate Password',
                      style: TextStyle(
                        fontSize: 16,
                        color: _isDarkModeEnabled ? Colors.black : null,
                      ),
                    ),
                    style: ButtonStyle(
                      backgroundColor: _isEditing
                          ? (_isDarkModeEnabled
                              ? MaterialStateProperty.all<Color>(
                                  Colors.greenAccent)
                              : null)
                          : MaterialStateProperty.all<Color>(Colors.grey),
                    ),
                    onPressed: _isEditing
                        ? () {
                            _generatePasswordInit();

                            showGeneratePasswordModal(context);
                          }
                        : null,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: !_isOutOfRange
                          ? () {
                              setState(() {
                                _isFavorite = !_isFavorite;
                                _isEditing = true;
                              });

                              _validateFieldsAreChanged();
                            }
                          : null,
                      icon: Icon(
                        Icons.favorite,
                        color: _isFavorite
                            ? (_isDarkModeEnabled
                                ? Colors.greenAccent
                                : Colors.blue)
                            : Colors.grey,
                        size: 30.0,
                      ),
                    ),
                    TextButton(
                      child: Text(
                        'Favorite',
                        style: TextStyle(
                            fontSize: 16.0,
                            color: _isDarkModeEnabled
                                ? (!_isOutOfRange ? Colors.white : Colors.grey)
                                : (!_isOutOfRange
                                    ? Colors.black
                                    : Colors.grey)),
                      ),
                      onPressed: () {
                        setState(() {
                          _isFavorite = !_isFavorite;
                          _isEditing = true;
                        });

                        _validateFieldsAreChanged();
                      },
                    ),
                    Spacer(),
                    IconButton(
                      onPressed: !_isOutOfRange
                          ? () {
                              setState(() {
                                _pressedShareItem();
                              });
                            }
                          : null,
                      icon: Icon(
                        Icons.share,
                        color: _isDarkModeEnabled
                            ? (!_isOutOfRange
                                ? Colors.greenAccent
                                : Colors.grey)
                            : (!_isOutOfRange
                                ? Colors.blueAccent
                                : Colors.grey),
                        size: 30.0,
                      ),
                    ),
                    TextButton(
                      child: Text(
                        'Share',
                        style: TextStyle(
                            fontSize: 16.0,
                            color: _isDarkModeEnabled
                                ? (!_isOutOfRange ? Colors.white : Colors.grey)
                                : (!_isOutOfRange
                                    ? Colors.black
                                    : Colors.grey)),
                      ),
                      onPressed: !_isOutOfRange
                          ? () {
                              _pressedShareItem();
                            }
                          : null,
                    ),
                    Spacer(),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: !_isOutOfRange
                          ? () async {
                              await Clipboard.setData(ClipboardData(
                                  text: _passwordTextController.text));

                              _settingsManager.setDidCopyToClipboard(true);

                              EasyLoading.showToast('Copied',
                                  duration: Duration(milliseconds: 500));
                            }
                          : null,
                      icon: Icon(
                        Icons.copy_rounded,
                        color: _isDarkModeEnabled
                            ? (!_isOutOfRange
                                ? Colors.greenAccent
                                : Colors.grey)
                            : (!_isOutOfRange
                                ? Colors.blueAccent
                                : Colors.grey),
                        size: 30.0,
                      ),
                    ),
                    TextButton(
                      child: Text(
                        'Copy Password',
                        style: TextStyle(
                          fontSize: 16.0,
                          color: _isDarkModeEnabled
                              ? (!_isOutOfRange ? Colors.white : Colors.grey)
                              : (!_isOutOfRange ? Colors.black : Colors.grey),
                        ),
                      ),
                      onPressed: !_isOutOfRange
                          ? () async {
                              await Clipboard.setData(ClipboardData(
                                  text: _passwordTextController.text));

                              _settingsManager.setDidCopyToClipboard(true);

                              EasyLoading.showToast('Copied',
                                  duration: Duration(milliseconds: 500));
                            }
                          : null,
                    ),
                    Spacer(),
                  ],
                ),
              ),
              Visibility(
                visible: bip39.validateMnemonic(_initialPassword),
                child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () async {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ShowBIP39Screen(
                              mnemonic: _initialPassword,
                            ),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.view_agenda_outlined,
                        color: _isDarkModeEnabled
                            ? (!_isOutOfRange
                                ? Colors.greenAccent
                                : Colors.grey)
                            : (!_isOutOfRange
                                ? Colors.blueAccent
                                : Colors.grey),
                        size: 30.0,
                      ),
                    ),
                    TextButton(
                      child: Text(
                        'BIP39 View',
                        style: TextStyle(
                          fontSize: 16.0,
                          color: _isDarkModeEnabled
                              ? (!_isOutOfRange ? Colors.white : Colors.grey)
                              : (!_isOutOfRange ? Colors.black : Colors.grey),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ShowBIP39Screen(
                              mnemonic: _initialPassword,
                            ),
                          ),
                        );
                      },
                    ),
                    Spacer(),
                  ],
                ),
              ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              ),
              Visibility(
                visible: _testGeoLock,
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text(
                      "Geo-Lock",
                      style: TextStyle(
                        fontSize: 18.0,
                        color: _isLocationSettingsEnabled
                            ? (_isDarkModeEnabled ? Colors.white : Colors.black)
                            : Colors.grey,
                      ),
                    ),
                    subtitle: _isLocationSettingsEnabled
                        ? (!_isInitiallyGeoLocked && !_isOutOfRange
                            ? Text(
                                "Encrypt password with GPS coordinates.  You will only be able to decrypt this item while within ~300 ft. of current location.",
                                style: TextStyle(
                                  fontSize: 14.0,
                                  color: _isDarkModeEnabled
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              )
                            : Text(
                                (_isOutOfRange
                                    ? "Trying to Decrypt.\nOut Of Range"
                                    : "Password decrypted.  You are in range."),
                                style: TextStyle(
                                  fontSize: 14.0,
                                  color: _isLocationSettingsEnabled
                                      ? (_isDarkModeEnabled
                                          ? Colors.white
                                          : Colors.black)
                                      : Colors.grey,
                                )))
                        : Text(
                            "Enable Location in phone settings.",
                            style: TextStyle(
                              fontSize: 14.0,
                              color: _isLocationSettingsEnabled
                                  ? (_isDarkModeEnabled
                                      ? Colors.white
                                      : Colors.black)
                                  : Colors.grey,
                            ),
                          ),
                    leading: _isDecryptingGeoLock
                        ? CircularProgressIndicator(
                            color: _isDarkModeEnabled
                                ? Colors.greenAccent
                                : Colors.blueAccent,
                            backgroundColor: Colors.transparent,
                            value: null,
                          )
                        : null,
                    trailing: Switch(
                      thumbColor: (!_isOutOfRange)
                          ? MaterialStateProperty.all<Color>(Colors.white)
                          : MaterialStateProperty.all<Color>(Colors.grey),
                      trackColor: _isLocationSettingsEnabled
                          ? (_isGeoLockedEnabled
                              ? (_isDarkModeEnabled
                                  ? MaterialStateProperty.all<Color>(
                                      Colors.greenAccent)
                                  : MaterialStateProperty.all<Color>(
                                      Colors.blue))
                              : (_isDarkModeEnabled
                                  ? MaterialStateProperty.all<Color>(
                                      Colors.grey)
                                  : MaterialStateProperty.all<Color>(
                                      Colors.grey)))
                          : MaterialStateProperty.all<Color>(Colors.grey),
                      value: _isGeoLockedEnabled,
                      onChanged: (!_isOutOfRange)
                          ? (value) {
                              //(!_isInitiallyGeoLocked && !_isOutOfRange) ? (value) {
                              /// change item's encryption based on geolock value
                              // print("geoLock: $value");

                              setState(() {
                                _isEditing = true;
                                _isGeoLockedEnabled = value;
                              });

                              _validateFields();
                            }
                          : null,
                    ),
                  ),
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              ),
              Text(
                "Tags",
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: _isDarkModeEnabled
                      ? Colors.greenAccent
                      : Colors.blueAccent,
                  fontSize: 18,
                ),
              ),
              // if (_passwordTags.isNotEmpty)
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Container(
                  height: 44,
                  child: ListView.separated(
                    itemCount: _passwordTags.length + 1,
                    separatorBuilder: (context, index) => Divider(
                      color: _isDarkModeEnabled ? Colors.greenAccent : null,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      // var addTagItem;
                      // if (index == 0)
                      final addTagItem = Row(
                        children: [
                          IconButton(
                            onPressed: !_isOutOfRange
                                ? () {
                                    _showModalAddTagView();
                                  }
                                : null,
                            icon: Icon(
                              Icons.add_circle,
                              color: Colors.blueAccent,
                            ),
                          ),
                          Text(
                            "Add Tag",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(
                            width: 16,
                          ),
                        ],
                      );

                      var currentTagItem;
                      final len = _selectedTags.length;
                      if (index > 0) {
                        currentTagItem = GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTags[index - 1] =
                                  !_selectedTags[index - 1];
                            });
                          },
                          child: Row(
                            children: [
                              // if (_selectedTags[index-1])
                              SizedBox(
                                width: 8,
                              ),
                              Padding(
                                padding: EdgeInsets.fromLTRB(8, 0, 4, 0),
                                child: Text(
                                  "${_passwordTags[index - 1]}",
                                  style: TextStyle(
                                    color: _isDarkModeEnabled
                                        ? Colors.greenAccent
                                        : Colors.blueAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (len >= index - 1 && _selectedTags[index - 1])
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _passwordTags.removeAt(index - 1);
                                      _selectedTags.removeAt(index - 1);
                                      _isEditing = true;
                                    });

                                    _validateFieldsAreChanged();
                                  },
                                  icon: const Icon(
                                    Icons.cancel_sharp,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                ),
                              if (!_selectedTags[index - 1])
                                SizedBox(
                                  width: 8,
                                ),
                            ],
                          ),
                        );
                      }
                      return Padding(
                        padding: EdgeInsets.all(4),
                        child: GestureDetector(
                          onTap: !_isOutOfRange
                              ? () {
                                  if (index == 0) {
                                    _showModalAddTagView();
                                  } else {
                                    setState(() {
                                      _selectedTags[index - 1] =
                                          !_selectedTags[index - 1];
                                    });
                                  }
                                }
                              : null,
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: _isDarkModeEnabled
                                  ? Colors.greenAccent.withOpacity(0.25)
                                  : Colors.blueAccent.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: (index == 0 ? addTagItem : currentTagItem),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // if (_hasNotes)
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : null,
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: TextFormField(
                  cursorColor: _isDarkModeEnabled ? Colors.greenAccent : null,
                  autofocus: false,
                  autocorrect: false,
                  enabled: true,
                  readOnly: !_isEditing,
                  minLines: 3,
                  maxLines: 8,
                  style: TextStyle(
                    fontSize: 18.0,
                    color: _isDarkModeEnabled ? Colors.white : null,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Notes',
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
                    disabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color:
                            _isDarkModeEnabled ? Colors.blueGrey : Colors.grey,
                        width: 0.0,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    _validateFieldsAreChanged();
                  },
                  textInputAction: TextInputAction.newline,
                  focusNode: _notesFocusNode,
                  controller: _notesTextController,
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Text(
                      _passwordItem == null ? '' : 'id: ${_passwordItem!.id}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      // 'created: ${DateFormat('yyyy-MM-dd  hh:mm:ss a').format(_modifiedDate)}',
                    'created: ${DateFormat('MMM d y  hh:mm a').format(_createdDate)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      // 'modified: ${DateFormat('yyyy-MM-dd  hh:mm:ss a').format(_modifiedDate)}',
                      'modified: ${DateFormat('MMM d y  hh:mm a').format(_modifiedDate)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _passwordItem == null
                          ? ''
                          : 'size: ${(_passwordItem!.toRawJson().length / 1024).toStringAsFixed(2)} KB',
                      style: TextStyle(
                        fontSize: 14,
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                    ),
                  ],
                ),
              ),
              Visibility(
                visible: _decryptedPreviousPasswordList.isNotEmpty,
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: _isDarkModeEnabled
                          ? BorderSide(color: Colors.greenAccent)
                          : null,
                    ),
                    onPressed: () {
                      _pressedPreviousPasswordsButton();
                    },
                    child: Text(
                      'Previous Passwords',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isDarkModeEnabled ? Colors.greenAccent : null,
                      ),
                    ),
                  ),
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : null,
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: _isDarkModeEnabled
                        ? BorderSide(color: Colors.greenAccent)
                        : null,
                  ),
                  child: Text(
                    'Delete Item',
                    style: TextStyle(
                      color: _isDarkModeEnabled
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    ),
                  ),
                  onPressed: () {
                    if (_isOutOfRange) {
                      _showErrorDialog("Out of range.  Cant delete item.");
                    } else {
                      _showConfirmDeleteItemDialog();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 2.0,
        backgroundColor: _isDarkModeEnabled ? Colors.black12 : Colors.white,
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

    _settingsManager.changeRoute(index);
  }

  /// validate that we have values in all the necessary fields
  /// before we enable the user to save
  bool _validateFields() {
    final name = _nameTextController.text;
    // final username = _usernameTextController.text;
    final password = _passwordTextController.text;

    // _checkForDuplicates(password);
    // setState(() {
    //   _duplicatePassword = widget.passwordList.contains(password);
    // });
    setState(() {
      _isPasswordBip39Valid = bip39.validateMnemonic(password);
    });

    if (name.isEmpty) {
      setState(() {
        _fieldsAreValid = false;
      });
      return false;
    }

    if (password.isEmpty) {
      setState(() {
        _fieldsAreValid = false;
      });
      return false;
    }

    setState(() {
      _fieldsAreValid = true;
    });

    return true;
  }

  void _checkForDuplicates(String password) async {
    // print("check for dupes: ${widget.passwordList}");

    final hasPasswordInList = widget.passwordList.contains(password);
    final initPasswordInList = widget.passwordList.contains(_initialPassword);

    // widget.passwordList.(_initialPassword);
    if (hasPasswordInList) {
      // print("check for dupes: in list");

      var dupeCount = 0;
      for (var pwd in widget.passwordList) {
        if (pwd == password) {
          dupeCount += 1;
        }
      }
      if (initPasswordInList && _initialPassword == password) {
        setState(() {
          _duplicatePassword = (dupeCount > 1);
        });
      } else {
        setState(() {
          _duplicatePassword = (dupeCount > 0);
        });
      }
      //  print("dupes: $dupeCount");
      //
      // print("check for dupes: ${_duplicatePassword}");

    } else {
      setState(() {
        _duplicatePassword = false;
      });
    }
  }

  bool _validateFieldsAreChanged() {
    final val = _validateFields();

    final name = _nameTextController.text;
    final username = _usernameTextController.text;
    final password = _passwordTextController.text;
    final notes = _notesTextController.text;

    /// TODO: add tags to this
    ///
    final updatedPropertiesString =
        '$name.$username.${_passwordTags.toString()}.$_isFavorite.$password.$notes';

    // print('_itemPropertiesString: $_itemPropertiesString');
    // print('updatedPropertiesString: $updatedPropertiesString');

    // check if items in the password item have changed
    if (updatedPropertiesString != _itemPropertiesString) {
      setState(() {
        _fieldsAreChanged = val;
      });

      if (val) {
        if (!_didWarnOfChange) {
          WidgetUtils.showSnackBarDuration(
              context, "Item changed. Press save to finalize changes.",
              Duration(seconds: 3));
        }
        setState(() {
          _didWarnOfChange = true;
        });
      }
    } else {
      setState(() {
        _fieldsAreChanged = false;
      });
    }
    return _fieldsAreChanged;
  }

  /// show the generate password screen
  void showGeneratePasswordModal(BuildContext context) {
    /// show modal bottom sheet
    showModalBottomSheet(
        backgroundColor: _isDarkModeEnabled ? Colors.black : null,
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        builder: (context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter state) {
            return Center(
              child: Column(
                children: <Widget>[
                  SizedBox(
                    height: 44.0,
                  ),
                  CupertinoSegmentedControl(
                    borderColor: _isDarkModeEnabled ? Colors.greenAccent : null,
                    pressedColor:
                        _isDarkModeEnabled ? Colors.greenAccent : null,
                    selectedColor:
                        _isDarkModeEnabled ? Colors.greenAccent : null,
                    unselectedColor: _isDarkModeEnabled ? Colors.black : null,
                    padding: EdgeInsets.all(16.0),
                    groupValue: _selectedSegment,
                    children: <PasswordType, Widget>{
                      PasswordType.random: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'random',
                        ),
                      ),
                      PasswordType.mnemonic: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'mnemonic',
                        ),
                      ),
                      PasswordType.pin: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'pin',
                        ),
                      ),
                    },
                    onValueChanged: (PasswordType value) {
                      state(() {
                        _selectedSegment = value;
                      });

                      _generatePassword(state);
                    },
                  ),
                  if (_selectedSegment == PasswordType.random)
                    Card(
                      color: _isDarkModeEnabled ? Colors.black87 : null,
                      child: Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Checkbox(
                                value: _isWithUppercase,
                                activeColor: _isDarkModeEnabled
                                    ? Colors.greenAccent
                                    : null,
                                checkColor:
                                    _isDarkModeEnabled ? Colors.black : null,
                                fillColor: _isDarkModeEnabled
                                    ? MaterialStateProperty.all<Color>(
                                        Colors.greenAccent)
                                    : null,
                                onChanged: (value) {
                                  state(() {
                                    _isWithUppercase = !_isWithUppercase;
                                  });

                                  _generatePassword(state);
                                },
                              ),
                              Text(
                                'Use Upper Case',
                                style: TextStyle(
                                    color: _isDarkModeEnabled
                                        ? Colors.white
                                        : null),
                              ),
                            ],
                          ),
                          Row(
                            children: <Widget>[
                              Checkbox(
                                value: _isWithNumbers,
                                activeColor: _isDarkModeEnabled
                                    ? Colors.greenAccent
                                    : null,
                                checkColor:
                                    _isDarkModeEnabled ? Colors.black : null,
                                fillColor: _isDarkModeEnabled
                                    ? MaterialStateProperty.all<Color>(
                                        Colors.greenAccent)
                                    : null,
                                onChanged: (value) {
                                  state(() {
                                    _isWithNumbers = !_isWithNumbers;
                                  });

                                  _generatePassword(state);
                                },
                              ),
                              Text(
                                'Use Numbers',
                                style: TextStyle(
                                  color:
                                      _isDarkModeEnabled ? Colors.white : null,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: <Widget>[
                              Checkbox(
                                value: _isWithSpecial,
                                activeColor: _isDarkModeEnabled
                                    ? Colors.greenAccent
                                    : null,
                                checkColor:
                                    _isDarkModeEnabled ? Colors.black : null,
                                fillColor: _isDarkModeEnabled
                                    ? MaterialStateProperty.all<Color>(
                                        Colors.greenAccent)
                                    : null,
                                onChanged: (value) {
                                  state(() {
                                    _isWithSpecial = !_isWithSpecial;
                                  });

                                  _generatePassword(state);
                                },
                              ),
                              Text(
                                'Special Characters',
                                style: TextStyle(
                                  color:
                                      _isDarkModeEnabled ? Colors.white : null,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: <Widget>[
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  '$_numberCharPasswordLabel characters',
                                  style: TextStyle(
                                      color: _isDarkModeEnabled
                                          ? Colors.white
                                          : null),
                                ),
                              ),
                              Expanded(
                                child: Slider(
                                  min: 1 / _maxNumberChars,
                                  value: _charactersSliderValue,
                                  activeColor: _isDarkModeEnabled
                                      ? Colors.greenAccent
                                      : null,
                                  thumbColor: _isDarkModeEnabled
                                      ? Colors.greenAccent
                                      : null,
                                  inactiveColor:
                                      _isDarkModeEnabled ? Colors.grey : null,
                                  onChanged: (value) {
                                    state(() {
                                      _charactersSliderValue = value;
                                      _numberCharPassword =
                                          (value * _maxNumberChars);
                                      _numberCharPasswordLabel =
                                          _numberCharPassword.round();
                                    });

                                    _generatePassword(state);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (_selectedSegment == PasswordType.mnemonic)
                    Card(
                      color: _isDarkModeEnabled ? Colors.black : null,
                      child: Column(
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'Seperator',
                                  style: TextStyle(
                                    color: _isDarkModeEnabled
                                        ? Colors.white
                                        : null,
                                  ),
                                ),
                              ),
                              Card(
                                color: _isDarkModeEnabled
                                    ? Colors.greenAccent
                                    : null,
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(8, 0, 0, 0),
                                  child: DropdownButton(
                                    value: _dropdownValue,
                                    dropdownColor: _isDarkModeEnabled
                                        ? Colors.greenAccent
                                        : null,
                                    iconEnabledColor: _isDarkModeEnabled
                                        ? Colors.black
                                        : Colors.black,

                                    // onTap: () {
                                    //   setState(() {
                                    //     // _isDropDownMenuActive = true;
                                    //   });
                                    // },
                                    style: TextStyle(
                                      color: _isDarkModeEnabled
                                          ? Colors.black
                                          : null,
                                    ),
                                    items: delimeterList
                                        .map<DropdownMenuItem<String>>(
                                            (String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(
                                          value,
                                          style: TextStyle(
                                            color: Colors.black,
                                          ), //_isDarkModeEnabled ? Colors.black : Colors.black),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (String? value) {
                                      state(() {
                                        _dropdownValue = value!;
                                      });

                                      _generatePassword(state);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: <Widget>[
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  '$_numberWordsLabel words',
                                  style: TextStyle(
                                    color: _isDarkModeEnabled
                                        ? Colors.white
                                        : null,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Slider(
                                  min: 1 / _maxNumberWords,
                                  value: _wordsSliderValue,
                                  activeColor: _isDarkModeEnabled
                                      ? Colors.greenAccent
                                      : null,
                                  thumbColor: _isDarkModeEnabled
                                      ? Colors.greenAccent
                                      : null,
                                  inactiveColor:
                                      _isDarkModeEnabled ? Colors.grey : null,
                                  onChanged: (value) {
                                    state(() {
                                      _wordsSliderValue = value;
                                      final numberWordsPassword =
                                          (value * _maxNumberWords);
                                      _numberWordsLabel =
                                          numberWordsPassword.round();
                                    });

                                    _generatePassword(state);
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (_isBip39Valid)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: <Widget>[
                                Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  'BIP-39',
                                  style: TextStyle(
                                      color: _isDarkModeEnabled
                                          ? Colors.white
                                          : null),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  if (_selectedSegment == PasswordType.pin)
                    Card(
                      color: _isDarkModeEnabled ? Colors.black : null,
                      child: Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  '$_numberPinDigitsLabel digits',
                                  style: TextStyle(
                                      color: _isDarkModeEnabled
                                          ? Colors.white
                                          : null),
                                ),
                              ),
                              Expanded(
                                child: Slider(
                                  min: 1 / _maxNumberPinDigits,
                                  value: _pinSliderValue,
                                  activeColor: _isDarkModeEnabled
                                      ? Colors.greenAccent
                                      : null,
                                  thumbColor: _isDarkModeEnabled
                                      ? Colors.greenAccent
                                      : null,
                                  inactiveColor:
                                      _isDarkModeEnabled ? Colors.grey : null,
                                  onChanged: (value) {
                                    state(() {
                                      _pinSliderValue = value;
                                      _numberPinDigits =
                                          (value * _maxNumberPinDigits);
                                      _numberPinDigitsLabel =
                                          _numberPinDigits.round();
                                    });

                                    _generatePassword(state);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: _isDarkModeEnabled
                          ? MaterialStateProperty.all<Color>(Colors.greenAccent)
                          : null,
                    ),
                    onPressed: () {
                      _generatePassword(state);
                    },
                    child: Text(
                      'Generate',
                      style: TextStyle(
                          color: _isDarkModeEnabled ? Colors.black : null),
                    ),
                  ),
                  Divider(
                    color: _isDarkModeEnabled ? Colors.greenAccent : null,
                  ),
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      _randomPassword,
                      style: TextStyle(
                        color: _isDarkModeEnabled
                            ? Colors.greenAccent
                            : Colors.grey[800],
                        fontWeight: FontWeight.normal,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Divider(
                    color: _isDarkModeEnabled ? Colors.greenAccent : null,
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 0.0),
                          child: LinearProgressIndicator(
                            color:
                                _isDarkModeEnabled ? Colors.greenAccent : null,
                            backgroundColor: _isDarkModeEnabled
                                ? Colors.blueGrey
                                : Colors.grey,
                            value: _randomPasswordStrength,
                            semanticsLabel: 'Password strength indicator',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 5,
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(0.0, 0.0, 16.0, 0.0),
                        child: Text(
                          "${_randomPasswordStrength.toStringAsFixed(2)}",
                          style: TextStyle(
                            color: _isDarkModeEnabled
                                ? Colors.white
                                : Colors.black,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      // Visibility(
                      //   visible: _isPasswordBip39Valid,
                      //   child: Padding(
                      //     padding: EdgeInsets.fromLTRB(0.0, 0.0, 8.0, 0.0),
                      //     child: Icon(
                      //       Icons.check_circle,
                      //       color: _isDarkModeEnabled ? Colors.greenAccent : null,
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: _isDarkModeEnabled
                                ? BorderSide(color: Colors.greenAccent)
                                : null,
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: _isDarkModeEnabled
                                  ? Colors.greenAccent
                                  : null,
                              // fontSize: 16,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        ElevatedButton(
                          style: ButtonStyle(
                            backgroundColor: _isDarkModeEnabled
                                ? MaterialStateProperty.all<Color>(
                                    Colors.greenAccent)
                                : null,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop(_randomPassword);
                          },
                          child: Text(
                            'OK',
                            style: TextStyle(
                              fontSize: 16,
                              color: _isDarkModeEnabled ? Colors.black : null,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            );
          });
        }).then((value) {
      if (value != null) {
        _passwordTextController.text = value;

        double strength = estimatePasswordStrength(value);
        setState(() {
          _passwordStrength = strength;
        });

        // _validateFields();

        _validateFieldsAreChanged();
        _checkForDuplicates(value);
      }
    });
  }

  _showModalAddTagView() async {
    showModalBottomSheet(
        backgroundColor: _isDarkModeEnabled ? Colors.black : null,
        elevation: 8,
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        builder: (context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter state) {
            return Center(
              child: Column(
                children: <Widget>[
                  SizedBox(
                    height: 16,
                  ),
                  Row(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(4, 16, 0, 0),
                        child: IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 30,
                            color:
                                _isDarkModeEnabled ? Colors.greenAccent : null,
                          ),
                          onPressed: () {
                            FocusScope.of(context).unfocus();

                            state(() {
                              _tagTextController.text = "";
                              _tagTextFieldValid = false;
                              _filteredTags = _settingsManager.itemTags;
                            });

                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      Spacer(),
                    ],
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 90,
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: TextFormField(
                              cursorColor: _isDarkModeEnabled
                                  ? Colors.greenAccent
                                  : null,
                              autocorrect: false,
                              obscureText: false,
                              minLines: 1,
                              maxLines: 1,
                              decoration: InputDecoration(
                                labelText: 'Tag',
                                hintStyle: TextStyle(
                                  fontSize: 18.0,
                                  color:
                                      _isDarkModeEnabled ? Colors.white : null,
                                ),
                                labelStyle: TextStyle(
                                  fontSize: 18.0,
                                  color:
                                      _isDarkModeEnabled ? Colors.white : null,
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
                                  Icons.tag,
                                  color:
                                      _isDarkModeEnabled ? Colors.grey : null,
                                ),
                                suffix: IconButton(
                                  icon: Icon(
                                    Icons.cancel_outlined,
                                    size: 20,
                                    color: _isDarkModeEnabled
                                        ? Colors.greenAccent
                                        : null,
                                  ),
                                  onPressed: () {
                                    state(() {
                                      _tagTextController.text = "";
                                      _tagTextFieldValid = false;
                                      _filteredTags = _settingsManager.itemTags;
                                    });
                                  },
                                ),
                              ),
                              style: TextStyle(
                                fontSize: 18.0,
                                color: _isDarkModeEnabled ? Colors.white : null,
                              ),
                              onChanged: (pwd) {
                                _validateModalField(state);
                              },
                              onTap: () {
                                _validateModalField(state);
                              },
                              onFieldSubmitted: (_) {
                                _validateModalField(state);
                              },
                              keyboardType: TextInputType.visiblePassword,
                              textInputAction: TextInputAction.done,
                              controller: _tagTextController,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: ElevatedButton(
                          style: ButtonStyle(
                            backgroundColor: _tagTextFieldValid
                                ? (_isDarkModeEnabled
                                    ? MaterialStateProperty.all<Color>(
                                        Colors.greenAccent)
                                    : null)
                                : MaterialStateProperty.all<Color>(
                                    Colors.blueGrey),
                          ),
                          child: Text(
                            "Add",
                            style: TextStyle(
                              color: _tagTextFieldValid
                                  ? (_isDarkModeEnabled
                                      ? Colors.black
                                      : Colors.white)
                                  : Colors.black54,
                            ),
                          ),
                          onPressed: _tagTextFieldValid
                              ? () {
                                  FocusScope.of(context).unfocus();

                                  final userTag = _tagTextController.text;
                                  if (!_passwordTags.contains(userTag)) {
                                    state(() {
                                      _passwordTags.add(userTag);
                                      _selectedTags.add(false);
                                    });

                                    if (!_settingsManager.itemTags
                                        .contains(userTag)) {
                                      var updatedTagList =
                                          _settingsManager.itemTags.copy();
                                      updatedTagList.add(userTag);

                                      updatedTagList
                                          .sort((e1, e2) => e1.compareTo(e2));

                                      settingsManager
                                          .saveItemTags(updatedTagList);

                                      state(() {
                                        _filteredTags = updatedTagList;
                                      });
                                    }
                                  }

                                  state(() {
                                    _isEditing = true;
                                    _tagTextController.text = "";
                                    _tagTextFieldValid = false;
                                    _filteredTags = _settingsManager.itemTags;
                                  });

                                  _validateFields();
                                  Navigator.of(context).pop();
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                  // if (false)
                  Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Container(
                        // height: 180,
                        child: ListView.separated(
                          itemCount: _filteredTags.length,
                          separatorBuilder: (context, index) => Divider(
                            color:
                                _isDarkModeEnabled ? Colors.greenAccent : null,
                          ),
                          scrollDirection: Axis.vertical,
                          itemBuilder: (context, index) {
                            final isCurrentTag =
                                _passwordTags.contains(_filteredTags[index]);
                            return ListTile(
                              title: Text(
                                _filteredTags[index],
                                // _settingsManager.itemTags[index],
                                // "test",
                                style: TextStyle(
                                  color: isCurrentTag
                                      ? Colors.grey
                                      : (_isDarkModeEnabled
                                          ? Colors.white
                                          : Colors.blueAccent),
                                ),
                              ),
                              leading: Icon(
                                Icons.discount,
                                color: isCurrentTag
                                    ? Colors.grey
                                    : (_isDarkModeEnabled
                                        ? Colors.greenAccent
                                        : Colors.blueAccent),
                              ),
                              onTap: !isCurrentTag
                                  ? () {
                                      setState(() {
                                        _tagTextController.text =
                                            _filteredTags[index];
                                        _validateModalField(state);
                                      });
                                    }
                                  : null,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          });
        });
  }

  _validateModalField(StateSetter state) async {
    final text = _tagTextController.text;

    state(() {
      _tagTextFieldValid =
          _tagTextController.text.isNotEmpty && !_passwordTags.contains(text);
    });

    if (text.isEmpty) {
      state(() {
        _filteredTags = _settingsManager.itemTags;
      });
    } else {
      _filteredTags = [];
      for (var t in _settingsManager.itemTags) {
        if (t.contains(text)) {
          _filteredTags.add(t);
        }
      }
      state(() {});
    }
    // }
  }

  _pressedShareItem() {
    final qrItemString = qrItem.toRawJson();

    if (qrItemString.length >= 1286) {
      // print("too much data");
      _showErrorDialog("Too much data for QR code.\n\nLimit is 1286 bytes.");
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QRCodeView(
            data: qrItemString,
            isDarkModeEnabled: _isDarkModeEnabled,
            isEncrypted: false,
          ),
        ),
      );
    }
  }

  /// show the previous passwords screen
  _pressedPreviousPasswordsButton() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreviousPasswordsScreen(
          items: _decryptedPreviousPasswordList,
        ),
      ),
    );
  }

  /// save the edited password item
  Future<void> _pressedSaveItem() async {
    // print('item uuid: ${widget.id}');
    FocusScope.of(context).unfocus();

    final name = _nameTextController.text;
    final username = _usernameTextController.text;
    final password = _passwordTextController.text;
    final notes = _notesTextController.text;

    /// TODO: new method - keep this
    qrItem = QRCodeItem(name: name, username: username, password: password);

    /// TODO: new method - keep this
    final passwordChanged = (_initialPassword != password);
    if (_isOutOfRange && passwordChanged) {
      _logManager.logger.d("Item is out of range, from current geo location to save");
      _showErrorDialog(
          "Cant save.  Location is not within GeoLock coordinates");
      setState(() {
        _isEditing = !_isEditing;
      });
      return;
    }

    /// TODO: add tags to this
    ///
    final updatedPropertiesString =
        '$name.$username.${_passwordTags.toString()}.$_isFavorite.$password.$notes';
    // _logManager.logger.d('updatedPropertiesString: $updatedPropertiesString');

    // check if items in the password item have changed
    /// set no matter what
    _itemPropertiesString = updatedPropertiesString;
    _modifiedDate = DateTime.now();

    /// TODO: new method - add
    final passwordItem = PasswordItem(
      id: widget.id,
      keyId: _keyManager.keyId,
      version: AppConstants.passwordItemVersion,
      name: name,
      username: username,
      password: password,
      previousPasswords: _initialEncryptedPreviousPasswords,
      favorite: _isFavorite,
      isBip39: _isBip39Valid,
      tags: _passwordTags,
      geoLock: null,
      notes: notes,
      mac: "",
      cdate: _createdDate.toIso8601String(),
      mdate: _modifiedDate.toIso8601String(),
    );

    /// TODO: new method - add
    await passwordItem.encryptParams2(_isGeoLockedEnabled ? _geolocationManager.geoLocationUpdate : null, passwordChanged ? _initialPassword : "");

    if (passwordChanged) {
      final isPreviousBip39Valid = bip39.validateMnemonic(_initialPassword);

      final previous = PreviousPassword(
        password: _initialPassword,
        isBip39: isPreviousBip39Valid,
        cdate: _modifiedDate.toIso8601String(),
      );

      /// TODO: new method - keep this here
      _previousPasswords.add(previous);
    }

    setState(() {
      _initialEncryptedPreviousPasswords = passwordItem.previousPasswords;
      _geoLockItem = passwordItem.geoLock;
      _isBip39Valid = passwordItem.isBip39;
      _initialPassword = password;

      _passwordItem = passwordItem;
    });

    /// TODO: new method
    if (passwordChanged) {
      cyclePreviousPasswords();
    }

    final passwordItemString = passwordItem.toRawJson();
    // _logManager.logger.d('passwordItem toRawJson: $passwordItemString');

    final genericItem = GenericItem(type: "password", data: passwordItemString);
    // print('genericItem toRawJson: ${genericItem.toRawJson()}');

    final genericItemString = genericItem.toRawJson();

    /// save item in keychain
    final status = await _keyManager.saveItem(widget.id, genericItemString);

    _validateFieldsAreChanged();

    if (status) {
      EasyLoading.showToast('Saved Item', duration: Duration(seconds: 1));
      setState(() {
        if (_isGeoLockedEnabled && _hasDecryptedGeoLock) {
          _hasDecryptedGeoLock = false;
        }
        _isInitiallyGeoLocked = _isGeoLockedEnabled;
      });
      // Navigator.of(context).pop('savedItem');
    } else {
      _showErrorDialog('Could not save the item.');
      _logManager.log(
          "EditPasswordScreen", "_pressedSaveItem", 'Error saving edited item');
    }
  }

  /// generate a random password for the user
  void _generatePassword(StateSetter state) {
    String newPassword = '';
    if (_selectedSegment == PasswordType.random) {
      newPassword = _randomGenerator.randomPassword(
          letters: _isWithLetters,
          numbers: _isWithNumbers,
          passwordLength: _numberCharPassword,
          specialChar: _isWithSpecial,
          uppercase: _isWithUppercase);
    } else if (_selectedSegment == PasswordType.mnemonic) {
      if (_numberWordsLabel == 12) {
        var mnemonic = bip39.generateMnemonic(strength: 128);
        if (_debugRand) {
          var a = mnemonic;
          final randNumber = 369;
          for (var index = 0; index < randNumber; index++) {
            a = _cryptor.sha256(a);
          }
          final words = bip39.entropyToMnemonic(a.substring(0, 32));
          newPassword = _delimeterConversion(words);
        } else {
          newPassword = _delimeterConversion(mnemonic);
        }
      } else if (_numberWordsLabel == 15) {
        final mnemonic = bip39.generateMnemonic(strength: 160);

        newPassword = _delimeterConversion(mnemonic);
      } else if (_numberWordsLabel == 18) {
        final mnemonic = bip39.generateMnemonic(strength: 192);

        newPassword = _delimeterConversion(mnemonic);
      } else if (_numberWordsLabel == 21) {
        final mnemonic = bip39.generateMnemonic(strength: 224);

        newPassword = _delimeterConversion(mnemonic);
      } else if (_numberWordsLabel == 24) {
        final mnemonic = bip39.generateMnemonic(strength: 256);

        newPassword = _delimeterConversion(mnemonic);
      } else {
        var mnemonic = bip39.generateMnemonic(strength: 256);
        if (_debugRand) {
          mnemonic = bip39.generateMnemonic(strength: 256);
          var a = mnemonic;
          final randNumber = 369;
          for (var index = 0; index < randNumber; index++) {
            a = _cryptor.sha256(a);
          }
          final words = bip39.entropyToMnemonic(a);
          newPassword = _delimeterConversion(words);
        } else {
          newPassword = _delimeterConversion(mnemonic);
        }
      }
      bool isValid = bip39.validateMnemonic(newPassword);
      state(() {
        _isBip39Valid = isValid;
      });
    } else {
      newPassword = _randomGenerator.randomPassword(
          letters: false,
          numbers: true,
          passwordLength: _numberPinDigits,
          specialChar: false,
          uppercase: false);
    }

    // _logManager.logger.d('random password: ${newPassword.length}: $newPassword');
    double strength = estimatePasswordStrength(newPassword);

    state(() {
      _randomPassword = newPassword;
      _randomPasswordStrength = strength;
    });
  }

  /// initialize a generated password when the screen loads
  void _generatePasswordInit() {
    String newPassword = '';
    if (_selectedSegment == PasswordType.random) {
      newPassword = _randomGenerator.randomPassword(
          letters: _isWithLetters,
          numbers: _isWithNumbers,
          passwordLength: _numberCharPassword,
          specialChar: _isWithSpecial,
          uppercase: _isWithUppercase);
    } else if (_selectedSegment == PasswordType.mnemonic) {
      if (_numberWordsLabel == 12) {
        final mnemonic = bip39.generateMnemonic(strength: 128);
        newPassword = _delimeterConversion(mnemonic);
      } else if (_numberWordsLabel == 15) {
        final mnemonic = bip39.generateMnemonic(strength: 160);
        newPassword = _delimeterConversion(mnemonic);
      } else if (_numberWordsLabel == 18) {
        final mnemonic = bip39.generateMnemonic(strength: 192);
        newPassword = _delimeterConversion(mnemonic);
      } else if (_numberWordsLabel == 21) {
        final mnemonic = bip39.generateMnemonic(strength: 224);
        newPassword = _delimeterConversion(mnemonic);
      } else if (_numberWordsLabel == 24) {
        final mnemonic = bip39.generateMnemonic(strength: 256);
        newPassword = _delimeterConversion(mnemonic);
      } else {
        final mnemonic = bip39.generateMnemonic(strength: 256);
        newPassword = _delimeterConversion(mnemonic);
      }
      bool isValid = bip39.validateMnemonic(newPassword);
      setState(() {
        _isBip39Valid = isValid;
      });
      // print('isValid: $isValid');
    } else {
      newPassword = _randomGenerator.randomPassword(
          letters: false,
          numbers: true,
          passwordLength: _numberPinDigits,
          specialChar: false,
          uppercase: false);
    }
    // print('random password: ${newPassword.length}: $newPassword');

    double strength = estimatePasswordStrength(newPassword);
    setState(() {
      _randomPassword = newPassword;
      _randomPasswordStrength = strength;
    });
  }

  String _delimeterConversion(String mnemonic) {
    List parts = mnemonic.split(' ');

    String delimeter = ' ';
    if (_dropdownValue == 'hyphen') {
      delimeter = '-';
    } else if (_dropdownValue == 'comma') {
      delimeter = ',';
    } else if (_dropdownValue == 'period') {
      delimeter = '.';
    } else if (_dropdownValue == 'underscores') {
      delimeter = '_';
    }

    String words = '';
    for (var i = 0; i < _numberWordsLabel; i++) {
      if (i == 0) {
        words = parts[i];
      } else {
        words = words + delimeter + parts[i];
      }
    }
    // print('words: $words');

    return words;
  }

  void _confirmedDeleteItem() async {
    final status = await _keyManager.deleteItem(widget.id);

    if (status) {
      Navigator.of(context).pop();
    } else {
      _showErrorDialog('Delete item failed');
    }
  }

  void _showConfirmDeleteItemDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Item'),
        content: Text('Are you sure you want to delete this item?'),
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
              Navigator.of(context).pop();

              if (_isOutOfRange) {
                _showErrorDialog("Out of range.  Cant delete item.");
              } else {
                _confirmedDeleteItem();
              }
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('An error occured'),
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
