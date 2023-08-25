import 'dart:async';
import 'dart:convert';
import 'package:argon2/argon2.dart';
import '../models/KeyItem.dart';
import 'package:convert/convert.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:password_strength/password_strength.dart';
import 'package:random_password_generator/random_password_generator.dart';

import '../helpers/AppConstants.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/KeychainManager.dart';
import '../managers/Cryptor.dart';

import '../models/NoteItem.dart';
import '../models/GenericItem.dart';
import '../models/KeyItem.dart';

import 'home_tab_screen.dart';


enum PasswordType { random, mnemonic, pin }

// mnemonic delimeter
const List<String> delimeterList = <String>[
  'space',
  'hyphen',
  'comma',
  'period',
  'underscores',
];

class AddKeyItemScreen extends StatefulWidget {
  const AddKeyItemScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/add_key_item_screen';

  @override
  State<AddKeyItemScreen> createState() => _AddKeyItemScreenState();
}

class _AddKeyItemScreenState extends State<AddKeyItemScreen> {
  final _nameTextController = TextEditingController();
  final _notesTextController = TextEditingController();
  final _tagTextController = TextEditingController();
  final _keyDataTextController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _notesFocusNode = FocusNode();
  final _keyDataFocusNode = FocusNode();

  int _selectedIndex = 1;

  bool _isDarkModeEnabled = false;
  bool _tagTextFieldValid = false;

  bool _isEditing = false;
  bool _isNewKey = true;
  bool _isFavorite = false;
  bool _fieldsAreValid = false;

  bool _isSymmetric = true;
  bool _isPurposeKeyGen = false;
  bool _isPurposeEncryption = false;
  bool _isPurposeSigning = false;
  bool _isPurposeKeyExchange = false;

  bool _isSigningAlgoK1= false;
  bool _isSigningAlgoR1 = false;
  bool _isSigningAlgoWOTS = false;

  bool _isExchangeAlgoR1 = false;
  bool _isExchangeAlgoX25519 = false;
  
  bool _validKeyTypeValues = true;

  bool _isBip39Valid = false;

  List<String> _keyTags = [];
  List<bool> _selectedTags = [];
  List<String> _filteredTags = [];

  List<int> _seedKey = [];

  String _randomPassword = "";
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

  bool _isWithLetters = true;
  bool _isWithLowercase = true;
  bool _isWithNumbers = false;
  bool _isWithSpecial = false;
  bool _isWithUppercase = true;

  PasswordType _selectedSegment = PasswordType.random;

  String _dropdownValue = delimeterList.first;

  String _modifiedDate = DateTime.now().toIso8601String();

  final _randomGenerator = RandomPasswordGenerator();

  final logManager = LogManager();
  final settingsManager = SettingsManager();
  final keyManager = KeychainManager();
  final cryptor = Cryptor();

  @override
  void initState() {
    super.initState();

    logManager.log("AddKeyItemScreen", "initState", "initState");

    // print("tags note: ${settingsManager.itemTags}");
    // if (widget.note == null) {
    // print("starting new key item");
    _isEditing = true;

    _generateKey();

    _filteredTags = settingsManager.itemTags;
    for (var tag in settingsManager.itemTags) {
      _selectedTags.add(false);
      // _filteredTags.add(tag);
    }

    _isDarkModeEnabled = settingsManager.isDarkModeEnabled;

    _selectedIndex = settingsManager.currentTabIndex;

    _validateFields();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text('Key'),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          // if (_isEditing)
            Visibility(
              visible: _isEditing,
              child:
            TextButton(
              child: Text(
                "Save",
                style: TextStyle(
                  color: _isDarkModeEnabled
                      ? (_fieldsAreValid ? Colors.greenAccent : Colors.grey)
                      : (_fieldsAreValid ? Colors.white : Colors.grey[400]),
                  fontSize: 18,
                ),
              ),
              style: ButtonStyle(
                  foregroundColor: _isDarkModeEnabled
                      ? (_fieldsAreValid
                          ? MaterialStateProperty.all<Color>(Colors.greenAccent)
                          : MaterialStateProperty.all<Color>(Colors.grey))
                      : null),
              onPressed: () async {
                // print("pressed done");
                await _pressedSaveKeyItem();

                setState(() {
                  _isEditing = !_isEditing;
                });

                if (!_isNewKey) {
                  Timer(Duration(milliseconds: 100), () {
                    FocusScope.of(context).unfocus();
                  });
                }
              },
            ),),
          // if (!_isEditing)
    Visibility(
      visible: !_isEditing,
      child:
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
              onPressed: _fieldsAreValid
                  ? () async {
                      // print("pressed done");
                      // await _pressedSaveNoteItem();

                      setState(() {
                        _isEditing = !_isEditing;
                      });
                      // if (!_isNewKey) {
                      //   Timer(Duration(milliseconds: 100), () {
                      //     FocusScope.of(context).unfocus();
                      //   });
                      // }
                    }
                  : null,
            ),
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
                  cursorColor: _isDarkModeEnabled ? Colors.greenAccent : null,
                  autofocus: true,
                  autocorrect: false,
                  enabled: _isEditing,
                  decoration: InputDecoration(
                    labelText: 'Key Name',
                    // icon: Icon(
                    //   Icons.edit_outlined,
                    //   color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                    // ),
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
                  // keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.done,
                  focusNode: _nameFocusNode,
                  controller: _nameTextController,
                ),
              ),
              Text(
                  "Type",
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : Colors.black,
                ),
              ),
              Row(children: [
                Spacer(),
                Checkbox(
                  value: _isSymmetric,
                  onChanged: (value){
                  setState((){
                    _isSymmetric = value!;
                    _validKeyTypeValues = _isSymmetric || (_isSigningAlgoK1 || _isSigningAlgoR1 || _isSigningAlgoWOTS || _isExchangeAlgoR1 || _isExchangeAlgoX25519);
                  });

                  _resetKeyField();
                  },
                ),
                Text(
                  "symmetric",
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  ),
                ),
                Spacer(),
                Checkbox(
                  value: !_isSymmetric, onChanged: (value){
                  setState((){
                    _isSymmetric = !value!;
                    _validKeyTypeValues = _isSymmetric || (_isSigningAlgoK1 || _isSigningAlgoR1 || _isSigningAlgoWOTS || _isExchangeAlgoR1 || _isExchangeAlgoX25519);
                  });

                  _resetKeyField();
                },
                ),
                Text(
                  "asymmetric",
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  ),
                ),
                Spacer(),
              ],),
              /// symmetric options
              ///
              Divider(color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey),

              Visibility(
                visible: !_isSymmetric,
                child:
              Text(
                "Purpose",
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : Colors.black,
                ),
              ),),


              Visibility(
                visible: false, //_isSymmetric,
                child:
                    Column(children: [


              Row(children: [
                Spacer(),
                Checkbox(
                  value: _isPurposeKeyGen,
                  onChanged: (value){
                    setState((){
                      _isPurposeKeyGen = value!;
                      _isPurposeEncryption = !value;
                    });
                  },
                ),
                Text(
                  "keygen",
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  ),
                ),
                Spacer(),
                Checkbox(
                  value: _isPurposeEncryption, onChanged: (value){
                  setState((){
                    _isPurposeEncryption = value!;
                    _isPurposeKeyGen = !value;
                  });
                },
                ),
                Text(
                  "encryption",
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  ),
                ),
                Spacer(),
              ],),

                    ],),
              ),

              Visibility(
                visible: !_isSymmetric,
                child:
              Row(children: [
                Spacer(),
                Checkbox(
                  value: _isPurposeSigning,
                  onChanged: (value){
                    setState((){
                      _isPurposeSigning = value!;
                      if (value) {
                        _isPurposeKeyExchange = false;
                        _isExchangeAlgoX25519 = false;
                        _isSigningAlgoK1 = true;
                      }
                      // _validKeyTypeValues = _isSymmetric || (_isSigningAlgoK1 || _isSigningAlgoR1 || _isSigningAlgoWOTS || _isExchangeAlgoR1 || _isExchangeAlgoX25519);
                      _validKeyTypeValues = _isSymmetric || (_isPurposeSigning && (_isSigningAlgoK1 || _isSigningAlgoR1 || _isSigningAlgoWOTS)) || (_isPurposeKeyExchange && (_isExchangeAlgoR1 || _isExchangeAlgoX25519));

                      _resetKeyField();
                    });
                  },
                ),
                Text(
                  "signing",
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  ),
                ),
                Spacer(),
                Checkbox(
                  value: _isPurposeKeyExchange, onChanged: (value){
                  setState((){
                    _isPurposeKeyExchange = value!;
                    if (value) {
                      _isPurposeSigning = false;
                      _isSigningAlgoK1 = false;
                      _isSigningAlgoR1 = false;
                      _isSigningAlgoWOTS = false;
                      _isExchangeAlgoX25519 = true;
                    }
                    // _validKeyTypeValues = _isSymmetric || (_isSigningAlgoK1 || _isSigningAlgoR1 || _isSigningAlgoWOTS || _isExchangeAlgoR1 || _isExchangeAlgoX25519);
                    _validKeyTypeValues = _isSymmetric || (_isPurposeSigning && (_isSigningAlgoK1 || _isSigningAlgoR1 || _isSigningAlgoWOTS)) || (_isPurposeKeyExchange && (_isExchangeAlgoR1 || _isExchangeAlgoX25519));

                    _resetKeyField();
                  });
                },
                ),
                Text(
                  "key-exchange",
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  ),
                ),
                // Spacer(),
                // Checkbox(
                //   value: _isPurposeDecryption, onChanged: (value){
                //   setState((){
                //     _isPurposeDecryption = value!;
                //   });
                // },
                // ),
                // Text(
                //   "key-exchange",
                //   style: TextStyle(
                //     color: _isDarkModeEnabled ? Colors.white : Colors.black,
                //   ),
                // ),
                Spacer(),
              ],),),
              Visibility(
                  visible: !_isSymmetric && (_isPurposeSigning || _isPurposeKeyExchange),
                  child: Divider(
                      color: _isDarkModeEnabled ? Colors.greenAccent : null,
                  ),
              ),
              Visibility(
                  visible: !_isSymmetric && (_isPurposeSigning || _isPurposeKeyExchange),
                  child: Text(
                      "Algorithm",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : Colors.black,
                    ),
                  ),
              ),
              Visibility(
                visible: !_isSymmetric && _isPurposeSigning,
                child:
                Row(children: [
                  Spacer(),
                  Checkbox(
                    value: _isSigningAlgoK1,
                    onChanged: (value){
                      setState((){
                        _isSigningAlgoK1 = value!;
                        // _isSigningAlgoR1 = !value!;
                        // _isSigningAlgoWOTS = !value!;
                        if (value) {
                          _isSigningAlgoR1 = false;//!value!;
                          _isSigningAlgoWOTS = false;//!value!;
                        }
                        // _validKeyTypeValues = _isSymmetric || (_isSigningAlgoK1 || _isSigningAlgoR1 || _isSigningAlgoWOTS || _isExchangeAlgoR1 || _isExchangeAlgoX25519);
                        _validKeyTypeValues = _isSymmetric || (_isPurposeSigning && (_isSigningAlgoK1 || _isSigningAlgoR1 || _isSigningAlgoWOTS)) || (_isPurposeKeyExchange && (_isExchangeAlgoR1 || _isExchangeAlgoX25519));

                        _resetKeyField();
                      });
                    },
                  ),
                  Text(
                    "secp256k1",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : Colors.black,
                    ),
                  ),
                  Spacer(),
                  Checkbox(
                    value: _isSigningAlgoR1, onChanged: (value){
                    setState((){
                      _isSigningAlgoR1 = value!;
                      if (value) {
                        _isSigningAlgoK1 = false;
                        _isSigningAlgoWOTS = false;
                      }
                      // _validKeyTypeValues = _isSymmetric || (_isSigningAlgoK1 || _isSigningAlgoR1 || _isSigningAlgoWOTS || _isExchangeAlgoR1 || _isExchangeAlgoX25519);
                      _validKeyTypeValues = _isSymmetric || (_isPurposeSigning && (_isSigningAlgoK1 || _isSigningAlgoR1 || _isSigningAlgoWOTS)) || (_isPurposeKeyExchange && (_isExchangeAlgoR1 || _isExchangeAlgoX25519));

                      _resetKeyField();
                    });
                  },
                  ),
                  Text(
                    "secp256r1",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : Colors.black,
                    ),
                  ),
                  Spacer(),
                  Checkbox(
                    value: _isSigningAlgoWOTS, onChanged: (value){
                    setState((){
                      _isSigningAlgoWOTS = value!;
                      if (value) {
                        _isSigningAlgoR1 = false;//!value!;
                        _isSigningAlgoK1 = false;//!value!;
                      }
                      // _validKeyTypeValues = _isSymmetric || (_isSigningAlgoK1 || _isSigningAlgoR1 || _isSigningAlgoWOTS || _isExchangeAlgoR1 || _isExchangeAlgoX25519);
                      _validKeyTypeValues = _isSymmetric || (_isPurposeSigning && (_isSigningAlgoK1 || _isSigningAlgoR1 || _isSigningAlgoWOTS)) || (_isPurposeKeyExchange && (_isExchangeAlgoR1 || _isExchangeAlgoX25519));

                      _resetKeyField();
                    });
                  },
                  ),
                  Text(
                    "WOTS+",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : Colors.black,
                    ),
                  ),
                  Spacer(),
                ],),),

              Visibility(
                visible: !_isSymmetric && _isPurposeKeyExchange,
                child:
                Row(children: [
                  // Spacer(),
                  // Checkbox(
                  //   value: _isExchangeAlgoR1, onChanged: (value){
                  //   setState((){
                  //     _isExchangeAlgoR1 = value!;
                  //     _isExchangeAlgoX25519 = !value!;
                  //     // _validKeyTypeValues = _isSymmetric || (_isSigningAlgoK1 || _isSigningAlgoR1 || _isSigningAlgoWOTS || _isExchangeAlgoR1 || _isExchangeAlgoX25519);
                  //     _validKeyTypeValues = _isSymmetric || (_isPurposeSigning && (_isSigningAlgoK1 || _isSigningAlgoR1 || _isSigningAlgoWOTS)) || (_isPurposeKeyExchange && (_isExchangeAlgoR1 || _isExchangeAlgoX25519));
                  //   });
                  //
                  //   _resetKeyField();
                  // },
                  // ),
                  // Text(
                  //   "secp256r1",
                  //   style: TextStyle(
                  //     color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  //   ),
                  // ),
                  Spacer(),
                  Checkbox(
                    value: _isExchangeAlgoX25519,
                    onChanged: (value){
                      setState((){
                        _isExchangeAlgoX25519 = value!;
                        _isExchangeAlgoR1 = !value;
                        _validKeyTypeValues = _isSymmetric || (_isPurposeSigning && (_isSigningAlgoK1 || _isSigningAlgoR1 || _isSigningAlgoWOTS)) || (_isPurposeKeyExchange && (_isExchangeAlgoR1 || _isExchangeAlgoX25519));
                      });

                      _resetKeyField();
                    },
                  ),
                  Text(
                    "X25519",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : Colors.black,
                    ),
                  ),
                  Spacer(),
                ],),),
              Visibility(
                  visible: !_isSymmetric,
                  child:Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : null,
              ),),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Visibility(
              visible: _isSymmetric,
              child: Spacer(),
            ),
              Visibility(
                visible: true,
                child: ElevatedButton(
                  style: ButtonStyle(
                    foregroundColor: _isDarkModeEnabled
                  ? MaterialStateProperty.all<Color>(
                  Colors.black)
                        : null,
                    backgroundColor: _validKeyTypeValues
                        ? (_isDarkModeEnabled
                        ? MaterialStateProperty.all<Color>(
                        Colors.greenAccent)
                        : null)
                        : MaterialStateProperty.all<Color>(
                        Colors.blueGrey)
                  ),
                  onPressed: _validKeyTypeValues ? () {
                    // if (_isSymmetric) {
                    //   showGeneratePasswordModal(context);
                    // } else {
                      _generateKey();
                    // }
                  } : null,
                  child: Text(
                    _isSymmetric ? "Generate Key" : "Generate Keys",
                  ),
                ),
              ),
            Visibility(
              visible: _isSymmetric,
              child: Spacer(),
            ),
            Visibility(
              visible: _isSymmetric,
              child: ElevatedButton(
                style: ButtonStyle(
                    foregroundColor: _isDarkModeEnabled
                        ? MaterialStateProperty.all<Color>(
                        Colors.black)
                        : null,
                    backgroundColor: _validKeyTypeValues
                        ? (_isDarkModeEnabled
                        ? MaterialStateProperty.all<Color>(
                        Colors.greenAccent)
                        : null)
                        : MaterialStateProperty.all<Color>(
                        Colors.blueGrey)
                ),
                onPressed: _validKeyTypeValues ? () {
                  _generatePasswordInit();

                  showGeneratePasswordModal(context);
                } : null,
                child: Text(
                  "Custom Key",
                ),
              ),
            ),
            Visibility(
              visible: _isSymmetric,
              child: Spacer(),
            ),
          ],),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: TextFormField(
                        cursorColor:
                            _isDarkModeEnabled ? Colors.greenAccent : null,
                        autofocus: true,
                        autocorrect: false,
                        enabled: true,
                        readOnly: true,
                        minLines: 2,
                        maxLines: 8,
                        decoration: InputDecoration(
                          labelText: 'Key',
                          // icon: Icon(
                          //   Icons.edit_outlined,
                          //   color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                          // ),
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
                        // keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.done,
                        focusNode: _keyDataFocusNode,
                        controller: _keyDataTextController,
                      ),
                    ),
                  ),
                  //
                ],
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: TextFormField(
                  cursorColor: _isDarkModeEnabled ? Colors.greenAccent : null,
                  autofocus: true,
                  autocorrect: false,
                  enabled: true,
                  minLines: 5,
                  maxLines: 10,
                  readOnly: !_isEditing,
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
                  // keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.newline,
                  focusNode: _notesFocusNode,
                  controller: _notesTextController,
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
                          _isEditing = true;
                        });

                        _validateFields();
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
                          _isEditing = true;
                        });

                        _validateFields();
                      },
                    ),
                    Spacer(),
                  ],
                ),
              ),
              Divider(color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey),
              Center(
                child: Text(
                  "Tags",
                  style: TextStyle(
                    color: _isDarkModeEnabled
                        ? Colors.greenAccent
                        : Colors.blueAccent,
                    fontSize: 18,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Container(
                  height: 44,
                  child: ListView.separated(
                    itemCount: _keyTags.length + 1,
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
                          TextButton(
                            child: Text(
                              "Add Tag",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            onPressed: () {
                              _showModalAddTagView();
                            },
                          ),
                          SizedBox(
                            width: 16,
                          ),
                        ],
                      );

                      var currentTagItem;
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
                              SizedBox(
                                width: 8,
                              ),
                              Padding(
                                padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
                                child: Text(
                                  "${_keyTags[index - 1]}",
                                  style: TextStyle(
                                    color: _isDarkModeEnabled
                                        ? Colors.greenAccent
                                        : Colors.blueAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (_selectedTags.length >= index - 1 &&
                                  _selectedTags[index - 1])
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _keyTags.removeAt(index - 1);
                                      _selectedTags.removeAt(index - 1);
                                      _isEditing = true;
                                    });

                                    _validateFields();
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
                      }

                      return Padding(
                        padding: EdgeInsets.all(4),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTags[index - 1] =
                                  !_selectedTags[index - 1];
                            });
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
              if (!_isNewKey)
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      // SizedBox(height: 8),
                      // Text(
                      //   widget.note == null ? '' : 'id: ${(widget.note?.id)!}',
                      //   style: TextStyle(
                      //     fontSize: 14,
                      //     color: _isDarkModeEnabled ? Colors.white : null,
                      //   ),
                      // ),
                      // SizedBox(height: 8),
                      // Text(
                      //   'created: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse((widget.note?.cdate)!))}',
                      //   style: TextStyle(
                      //     fontSize: 14,
                      //     color: _isDarkModeEnabled ? Colors.white : null,
                      //   ),
                      // ),
                      // SizedBox(height: 5),
                      // Text(
                      //   'modified: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse(_modifiedDate))}',
                      //   style: TextStyle(
                      //     fontSize: 14,
                      //     color: _isDarkModeEnabled ? Colors.white : null,
                      //   ),
                      // ),
                      // SizedBox(height: 8),
                      // Text(
                      //   widget.note == null
                      //       ? ''
                      //       : 'size: ${(((widget.note)!).toRawJson().length / 1024).toStringAsFixed(2)} KB',
                      //   style: TextStyle(
                      //     fontSize: 14,
                      //     color: _isDarkModeEnabled ? Colors.white : null,
                      //   ),
                      // ),
                      if (!_isNewKey)
                        Divider(
                          color: _isDarkModeEnabled ? Colors.greenAccent : null,
                        ),
                      if (!_isNewKey)
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
                              _showConfirmDeleteItemDialog();
                            },
                          ),
                        ),
                    ],
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

  void _validateFields() {
    final name = _nameTextController.text;
    // final notes = _notesTextController.text;

    if (name.isEmpty) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    if (_seedKey.isEmpty) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    setState(() {
      _fieldsAreValid = true;
    });
  }

  void _resetKeyField() {
    setState((){
      _keyDataTextController.text = "";
    });
  }

  _generateKey() async {

    if (_isSymmetric) {
      _seedKey = cryptor.getRandomBytes(32);
      // print("rand seed: $_seedKey");

      setState(() {
        _keyDataTextController.text =
            bip39.entropyToMnemonic(hex.encode(_seedKey));
      });
    } else {

      if (_isPurposeSigning) {
        if (_isSigningAlgoR1) {
          final priv = await cryptor.generateKeysS_secp256r1();
          // print("priv key: $priv");

          // var pub = priv.publicKey;
          // var xpub = ec.publicKeyToCompressedHex(pub);
          _keyDataTextController.text = hex.encode(priv.bytes);

        } else if (_isSigningAlgoK1) {
          final priv = await cryptor.generateKeysS_secp256k1();
          // print("priv key: $priv");
          _keyDataTextController.text = hex.encode(priv.bytes);

        }
      } else {
        // if (_isExchangeAlgoR1) {
        //   final keys = cryptor.generateKeysX_secp256r1();
        //   print("keys: $keys");
        //
        // } else {
          final keys = await cryptor.generateKeysX_secp256k1();
          // print("keys: $keys");
          // final pub = await keys.extractPublicKey();
          final priv = await keys.extractPrivateKeyBytes();

          // print('aliceKeyPair Pub: ${pub.bytes}');
          // _keyDataTextController.text = hex.encode(pub.bytes);

          _keyDataTextController.text = hex.encode(priv);

        // }
      }
      // _seedKey = cryptor.getRandomBytes(32);
      // print("rand seed: $_seedKey");
      //
      // setState(() {
      //   _keyDataTextController.text =
      //       bip39.entropyToMnemonic(hex.encode(_seedKey));
      // });
    }
  }

  _pressedSaveKeyItem() async {
    var createDate = DateTime.now().toIso8601String();
    var uuid = cryptor.getUUID();

    _modifiedDate = createDate;
    // if (!_isNewKey) {
    //   createDate = (widget.note?.cdate)!;
    //   uuid = (widget.note?.id)!;
    //   setState(() {
    //     _modifiedDate = DateTime.now().toIso8601String();
    //   });
    // }

    final name = _nameTextController.text;
    final notes = _notesTextController.text;

    // final itemId = uuid + "-" + createDate + "-" + _modifiedDate;
    final encodedLength = utf8.encode(name).length + utf8.encode(notes).length + utf8.encode(hex.encode(_seedKey)).length;
    settingsManager.doEncryption(encodedLength);
    // cryptor.setTempKeyIndex(keyIndex);

    // logManager.logger.d("keyIndex: $keyIndex");

    /// encrypt note items
    ///
    final encryptedNotes = await cryptor.encrypt(notes);
    final encryptedKey = await cryptor.encrypt(hex.encode(_seedKey));

    var keyItem = KeyItem(
      id: uuid,
      keyId: keyManager.keyId,
      version: AppConstants.keyItemVersion,
      name: name,
      key: encryptedKey,
      keyType: EnumToString.convertToString(EncryptionKeyType.sym),
      purpose: EnumToString.convertToString(KeyPurposeType.encryption),
      algo: EnumToString.convertToString(EncryptionAlgoType.aes_ctr_256),
      notes: encryptedNotes,
      favorite: _isFavorite,
      isBip39: false,
      peerPublicKeys: [],
      tags: _keyTags,
      mac: "",
      cdate: createDate,
      mdate: _modifiedDate,
    );

    final itemMac = await cryptor.hmac256(keyItem.toRawJson());
    keyItem.mac = itemMac;

    final keyItemJson = keyItem.toRawJson();
    // logManager.logger.d("save keyItemJson: $keyItemJson");

    /// TODO: add GenericItem
    ///
    final genericItem = GenericItem(type: "key", data: keyItemJson);
    // print('genericItem toRawJson: ${genericItem.toRawJson()}');

    final genericItemString = genericItem.toRawJson();
    // logManager.logger.d("save key item genericItemString: $genericItemString");

    /// save note in keychain
    ///
    // final status = await keyManager.saveItem(uuid, genericItemString);

    final status = false;

    if (status) {
      EasyLoading.showToast('Saved Item', duration: Duration(seconds: 1));

      if (_isNewKey) {
        Navigator.of(context).pop('savedItem');
      }
    } else {
      _showErrorDialog('Could not save the item.');
    }
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
        _keyDataTextController.text = value;

        double strength = estimatePasswordStrength(value);
        setState(() {
          _passwordStrength = strength;
        });

        _validateFields();
      }
    });
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
              _confirmedDeleteItem();
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmedDeleteItem() async {
    // final status = await keyManager.deleteItem((widget.note?.id)!);
    //
    // if (status) {
    //   Navigator.of(context).pop();
    // } else {
    //   _showErrorDialog('Delete item failed');
    // }
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
                              _filteredTags = settingsManager.itemTags;
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
                                      _filteredTags = settingsManager.itemTags;
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
                                  if (!_keyTags.contains(userTag)) {
                                    state(() {
                                      _keyTags.add(userTag);
                                      _selectedTags.add(false);
                                    });

                                    if (!settingsManager.itemTags
                                        .contains(userTag)) {
                                      var updatedTagList =
                                          settingsManager.itemTags.copy();
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
                                    _filteredTags = settingsManager.itemTags;
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
                                _keyTags.contains(_filteredTags[index]);
                            return ListTile(
                              title: Text(
                                _filteredTags[index],
                                // settingsManager.itemTags[index],
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
          _tagTextController.text.isNotEmpty && !_keyTags.contains(text);
    });

    if (text.isEmpty) {
      state(() {
        _filteredTags = settingsManager.itemTags;
      });
    } else {
      _filteredTags = [];
      for (var t in settingsManager.itemTags) {
        if (t.contains(text)) {
          _filteredTags.add(t);
        }
      }
      state(() {});
    }
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
