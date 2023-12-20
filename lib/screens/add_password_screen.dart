import 'dart:async';

import 'package:argon2/argon2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:password_strength/password_strength.dart';
import 'package:random_password_generator/random_password_generator.dart';
import 'package:bip39/bip39.dart' as bip39;

import '../helpers/AppConstants.dart';
import '../managers/GeolocationManager.dart';
import '../models/PasswordItem.dart';
import '../models/GenericItem.dart';
import '../managers/Cryptor.dart';
import '../managers/KeychainManager.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import 'home_tab_screen.dart';

// generated password type
enum PasswordType { random, mnemonic, pin }

// mnemonic delimeter
const List<String> delimeterList = <String>[
  'space',
  'hyphen',
  'comma',
  'period',
  'underscores',
];

class AddPasswordScreen extends StatefulWidget {
  const AddPasswordScreen({
    Key? key,
    required this.passwordList,
  }) : super(key: key);
  static const routeName = '/add_password_screen';

  final List<String> passwordList;

  @override
  State<AddPasswordScreen> createState() => _AddPasswordScreenState();
}

class _AddPasswordScreenState extends State<AddPasswordScreen> {
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

  List<String> _passwordTags = [];
  List<bool> _selectedTags = [];
  List<String> _filteredTags = [];

  bool _tagTextFieldValid = false;

  int _selectedIndex = 0;

  bool _isDarkModeEnabled = false;

  bool _duplicatePassword = false;
  bool _isPasswordBip39Valid = false;
  bool _isGeoLockedEnabled = false;
  bool _isLocationSettingsEnabled = false;

  bool _hidePasswordField = true;
  bool _fieldsAreValid = false;
  bool _isFavorite = false;

  bool _isWithLetters = true;
  bool _isWithNumbers = false;
  bool _isWithSpecial = false;
  bool _isWithUppercase = true;

  bool _isBip39Valid = false;

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

  double _passwordStrength = 0.0;
  double _randomPasswordStrength = 0.0;

  final _randomGenerator = RandomPasswordGenerator();
  String _randomPassword = '';

  PasswordType _selectedSegment = PasswordType.random;

  String _dropdownValue = delimeterList.first;

  final _cryptor = Cryptor();
  final _keyManager = KeychainManager();
  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _geolocationManager = GeoLocationManager();


  @override
  void initState() {
    super.initState();

    _logManager.log("AddPasswordScreen", "initState", "initState");

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;
    _selectedIndex = _settingsManager.currentTabIndex;
    _filteredTags = _settingsManager.itemTags;

    if (_testGeoLock) {
      if (_geolocationManager.geoLocationUpdate == null) {
        _geolocationManager.initialize();
      }
    }

    _isLocationSettingsEnabled = _geolocationManager.isLocationSettingsEnabled;
    _logManager.logger.d("_isLocationSettingsEnabled: $_isLocationSettingsEnabled");

    /// We do this so tags show up in the UI when added.
    /// Not sure why this works but it does
    Timer(Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(_notesFocusNode);
      FocusScope.of(context).requestFocus(_nameFocusNode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text('Password'),
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        automaticallyImplyLeading: false,
        leading: BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            child: Text(
              "Save",
              style: TextStyle(
                color: _isDarkModeEnabled
                    ? (_fieldsAreValid ? Colors.greenAccent : Colors.grey)
                    : (_fieldsAreValid ? Colors.white : null),
                fontSize: 18,
              ),
            ),
            onPressed: _fieldsAreValid
                ? () async {
                    // print("pressed done");
                    await _pressedSaveItem();

                    Timer(Duration(milliseconds: 100), () {
                      FocusScope.of(context).unfocus();
                    });
                  }
                : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          child: Column(
            // mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(16.0),
                child: TextFormField(
                  cursorColor: _isDarkModeEnabled ? Colors.greenAccent : null,
                  autofocus: true,
                  autocorrect: false,
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
                  ),
                  style: TextStyle(
                    fontSize: 18.0,
                    color: _isDarkModeEnabled ? Colors.white : null,
                  ),
                  onChanged: (_) {
                    _validateFields();
                  },
                  onTap: () {
                    _validateFields();
                  },
                  onFieldSubmitted: (_) {
                    _validateFields();
                  },
                  textInputAction: TextInputAction.next,
                  focusNode: _nameFocusNode,
                  controller: _nameTextController,
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: TextFormField(
                  cursorColor: _isDarkModeEnabled ? Colors.greenAccent : null,
                  autocorrect: false,
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
                  ),
                  style: TextStyle(
                    fontSize: 18.0,
                    color: _isDarkModeEnabled ? Colors.white : null,
                  ),
                  onChanged: (_) {
                    _validateFields();
                  },
                  onTap: () {
                    _validateFields();
                  },
                  onFieldSubmitted: (_) {
                    _validateFields();
                  },
                  textInputAction: TextInputAction.next,
                  focusNode: _usernameFocusNode,
                  controller: _usernameTextController,
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        cursorColor:
                            _isDarkModeEnabled ? Colors.greenAccent : null,
                        autocorrect: false,
                        obscureText: _hidePasswordField,
                        minLines: 1,
                        maxLines: _hidePasswordField ? 1 : 8,
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
                          prefixIcon: Icon(
                            Icons.security,
                            color: _isDarkModeEnabled ? Colors.grey : null,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 18.0,
                          color: _isDarkModeEnabled ? Colors.white : null,
                        ),
                        onChanged: (pwd) {
                          _validateFields();

                          double strength = estimatePasswordStrength(pwd);
                          setState(() {
                            _passwordStrength = strength;
                            _isPasswordBip39Valid = bip39.validateMnemonic(pwd);
                          });
                        },
                        onTap: () {
                          _validateFields();
                        },
                        onFieldSubmitted: (_) {
                          _validateFields();
                        },
                        keyboardType: TextInputType.visiblePassword,
                        textInputAction: TextInputAction.done,
                        focusNode: _passwordFocusNode,
                        controller: _passwordTextController,
                      ),
                    ),
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
              // if (_duplicatePassword)
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
                  ),
                ),
              ),
              Row(
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

                        backgroundColor:
                            _isDarkModeEnabled ? Colors.blueGrey : Colors.grey,
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
                        color: _isDarkModeEnabled ? Colors.white : Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
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
                    backgroundColor: _isDarkModeEnabled
                        ? MaterialStateProperty.all<Color>(Colors.greenAccent)
                        : null,
                  ),
                  onPressed: () {
                    _generatePasswordInit();

                    // show modal
                    showGeneratePasswordModal(context);
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isFavorite = !_isFavorite;
                        });
                      },
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
                          color:
                              _isDarkModeEnabled ? Colors.white : Colors.black,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _isFavorite = !_isFavorite;
                        });
                      },
                    ),
                    Spacer(),
                  ],
                ),
              ),
              Divider(color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey),
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
                        ? Text(
                      "Encrypt password with GPS coordinates.  You will only be able to decrypt this item while within ~300 ft. of current location.",
                      style: TextStyle(
                        fontSize: 14.0,
                        color: _isDarkModeEnabled
                            ? Colors.white
                            : Colors.black,
                      ),
                    ) : Text(
                      "Enable location settings to Geo-Encrypt password.",
                      style: TextStyle(
                        fontSize: 14.0,
                        color: _isDarkModeEnabled
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                    trailing: Switch(
                      thumbColor: MaterialStateProperty.all<Color>(Colors.white),
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
                      onChanged: (value) {
                        setState(() {
                          _isGeoLockedEnabled = value;
                        });

                        _validateFields();
                      },
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
                            onPressed: () {
                              _showModalAddTagView();
                            },
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
                      if (index > 0)
                        currentTagItem = GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTags[index - 1] =
                                  !_selectedTags[index - 1];
                            });
                          },
                          child: Row(
                            children: [
                              // if (!_selectedTags[index-1])
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
                                    });
                                  },
                                  icon: Icon(
                                    Icons.cancel_sharp,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              if (!_selectedTags[index - 1])
                                SizedBox(
                                  width: 8,
                                ),
                            ],
                          ),
                        );

                      return Padding(
                        padding: EdgeInsets.all(4),
                        child: GestureDetector(
                          onTap: () {
                            if (index == 0) {
                              _showModalAddTagView();
                            } else {
                              setState(() {
                                _selectedTags[index - 1] =
                                    !_selectedTags[index - 1];
                              });
                            }
                          },
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
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : null,
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: TextFormField(
                  cursorColor: _isDarkModeEnabled ? Colors.greenAccent : null,
                  autocorrect: false,
                  minLines: 2,
                  maxLines: 8,
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
                  ),
                  style: TextStyle(
                    fontSize: 18.0,
                    color: _isDarkModeEnabled ? Colors.white : null,
                  ),
                  textInputAction: TextInputAction.newline,
                  focusNode: _notesFocusNode,
                  controller: _notesTextController,
                ),
              ),
              Divider(color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey),
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
                  child: Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 16,
                      color: _isDarkModeEnabled
                          ? (_fieldsAreValid ? Colors.black : Colors.black54)
                          : null,
                    ),
                  ),
                  onPressed: _fieldsAreValid
                      ? () async {
                          await _pressedSaveItem();
                        }
                      : null,
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

    _settingsManager.changeRoute(index);
  }

  /// validate that we have values in all the necessary fields
  /// before we enable the user to save
  void _validateFields() {
    final name = _nameTextController.text;
    final password = _passwordTextController.text;

    setState(() {
      _duplicatePassword = widget.passwordList.contains(password);
      _isPasswordBip39Valid = bip39.validateMnemonic(password);
    });

    if (name.isEmpty) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    setState(() {
      _fieldsAreValid = true;
    });
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
                                        : null,
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
                      //   child: Icon(
                      //     Icons.check_circle,
                      // ),
                      // ),
                    ],
                  ),
                  // Padding(
                  //   padding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 0.0),
                  //   child: LinearProgressIndicator(
                  //     color:
                  //         _isDarkModeEnabled ? Colors.greenAccent : Colors.blue,
                  //     backgroundColor: _isDarkModeEnabled ? Colors.blueGrey : Colors.grey,
                  //     value: _randomPasswordStrength,
                  //     semanticsLabel: 'Password strength indicator',
                  //   ),
                  // ),
                  SizedBox(
                    height: 20,
                  ),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            // backgroundColor: Colors.greenAccent,
                            // foregroundColor: Colors.black,
                            // shadowColor: Colors.black,
                            // onSurface: Colors.greenAccent,
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
                              // fontWeight: FontWeight.normal,
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
      /// if user has chosen a generated password, set it in the
      /// password field
      if (value != null) {
        _passwordTextController.text = value;

        double strength = estimatePasswordStrength(value);
        setState(() {
          _passwordStrength = strength;
        });

        _validateFields();
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
          // final isExistingTag = _filteredTags.contains(_tagTextController.text);// && _tagTextController.text.isNotEmpty;
          // final isExistingTag = _passwordTags.contains(_tagTextController.text) && _tagTextController.text.isNotEmpty;
          // var isExactMatch = false;
          // for (var thisTag in _passwordTags) {
          //   if (thisTag == _tagTextController.text) {
          //     isExactMatch = true;
          //   }
          // }
          // print("existing: $isExistingTag");
          // print("match: $isExactMatch");

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
                                setState(() {});
                              },
                              onTap: () {
                                _validateModalField(state);
                                setState(() {});
                              },
                              onFieldSubmitted: (_) {
                                _validateModalField(state);
                                setState(() {});
                              },
                              keyboardType: TextInputType.visiblePassword,
                              textInputAction: TextInputAction.done,
                              // focusNode: _passwordFocusNode,
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
                                    _tagTextController.text = "";
                                    _tagTextFieldValid = false;
                                  });

                                  _validateFields();
                                  _validateModalField(state);
                                  Navigator.of(context).pop();
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Container(
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
                            // // final isExistingTag = _filteredTags.contains(_tagTextController.text) && _tagTextController.text.isNotEmpty;
                            // isExactMatch = false;
                            // for (var thisTag in _filteredTags) {
                            //   if (thisTag == _tagTextController.text) {
                            //     isExactMatch = true;
                            //   }
                            // }
                            // print("currrent2: $isCurrentTag");
                            // print("existing2: $isExistingTag");
                            // print("match2: $isExactMatch");

                            var tagTile = ListTile(
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
                            // final createTile = ListTile(
                            //   title: Text(
                            //     "Create Tag \"${_tagTextController.text}\"",
                            //     style: TextStyle(
                            //       color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                            //     ),
                            //   ),
                            // );

                            // return index == 0 ? (isExistingTag ? usedTile : createTile) : tagTile;
                            // return isExistingTag ? (isExactMatch ?  usedTile : usedTile) : tagTile;
                            return tagTile;
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
    // if (_tagTextController.text.isNotEmpty) {
    //   state(() {
    //     _tagTextFieldValid = _tagTextController.text.isNotEmpty;
    //   });

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
          // state(() {
          _filteredTags.add(t);
          // });
        }
      }
      state(() {});
    }
  }

  /// save the new password item
  Future<void> _pressedSaveItem() async {
    final createDate = DateTime.now().toIso8601String();
    final uuid = _cryptor.getUUID();

    final name = _nameTextController.text;
    final username = _usernameTextController.text;
    final password = _passwordTextController.text;
    final notes = _notesTextController.text;

    final passwordItem = PasswordItem(
      id: uuid,
      keyId: _keyManager.keyId,
      version: AppConstants.passwordItemVersion,
      name: name, //encryptedName,
      username: username, //encryptedUsername,
      password: password, //encryptedPassword,
      previousPasswords: [],
      favorite: _isFavorite,
      isBip39: _isBip39Valid,
      tags: _passwordTags,
      geoLock: null,
      notes: notes, //encryptedNotes,
      mac: "",
      cdate: createDate,
      mdate: createDate,
    );

    /// encrypt our parameters
    await passwordItem.encryptParams(_isGeoLockedEnabled ? _geolocationManager.geoLocationUpdate : null);

    final passwordItemString = passwordItem.toRawJson();
    // _logManager.logger.d('passwordItem toRawJson: ${passwordItemString}');


    final genericItem = GenericItem(type: "password", data: passwordItemString);
    // _logManager.logger.d('genericItem toRawJson: ${genericItem.toRawJson()}');

    final genericItemString = genericItem.toRawJson();
    // final generalItemHash = _cryptor.sha256(genericItemString);
    // print('generalItemHash:$uuid: ${generalItemHash}');

    final status = await _keyManager.saveItem(uuid, genericItemString);

    if (status) {
      Navigator.of(context).pop('savedItem');
    } else {
      _showErrorDialog('Could not save the item.');
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
      } else {
        final mnemonic = bip39.generateMnemonic(strength: 256);
        newPassword = _delimeterConversion(mnemonic);
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
          uppercase: false,
      );
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
    } else {
      newPassword = _randomGenerator.randomPassword(
          letters: false,
          numbers: true,
          passwordLength: _numberPinDigits,
          specialChar: false,
          uppercase: false);
    }

    double strength = estimatePasswordStrength(newPassword);
    setState(() {
      _randomPassword = newPassword;
      _randomPasswordStrength = strength;
    });
  }

  /// change the delimeter for the mnemonic
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

    return words;
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
