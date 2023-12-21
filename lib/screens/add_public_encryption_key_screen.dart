import 'dart:async';
import 'dart:convert';
import 'package:argon2/argon2.dart';
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:bip39/bip39.dart' as bip39;

import '../models/KeyItem.dart';
import '../helpers/AppConstants.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/KeychainManager.dart';
import '../managers/Cryptor.dart';

import '../models/GenericItem.dart';

import 'home_tab_screen.dart';


/// Adding a Primary (Main/Parent) Public Key
///
///

class AddPublicEncryptionKeyScreen extends StatefulWidget {
  const AddPublicEncryptionKeyScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/add_public_encryption_key_screen';

  @override
  State<AddPublicEncryptionKeyScreen> createState() => _AddPublicEncryptionKeyScreenState();
}

class _AddPublicEncryptionKeyScreenState extends State<AddPublicEncryptionKeyScreen> {
  final _nameTextController = TextEditingController();
  final _notesTextController = TextEditingController();
  final _tagTextController = TextEditingController();
  final _keyDataTextController = TextEditingController();
  final _importKeyDataTextController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _notesFocusNode = FocusNode();
  final _keyDataFocusNode = FocusNode();
  final _importKeyDataFocusNode = FocusNode();

  int _selectedIndex = 1;

  bool _isDarkModeEnabled = false;
  bool _tagTextFieldValid = false;
  bool _shouldShowExtendedKeys = false;
  bool _shouldShowRootKey = false;

  bool _isEditing = false;
  bool _isNewKey = true;
  bool _isFavorite = false;
  bool _fieldsAreValid = false;

  bool _isGeneratingKey = true;

  bool _validKeyTypeValues = true;

  List<String> _keyTags = [];
  List<bool> _selectedTags = [];
  List<String> _filteredTags = [];

  List<int> _privKeyExchange = [];
  List<int> _pubKeyExchange = [];

  List<int> _privKeySigning = [];
  List<int> _pubKeySigning = [];

  String _publicKeyMnemonic = "";

  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _keyManager = KeychainManager();
  final _cryptor = Cryptor();


  @override
  void initState() {
    super.initState();

    _logManager.log("AddPublicEncryptionKeyScreen", "initState", "initState");

    // print("tags note: ${_settingsManager.itemTags}");
    // if (widget.note == null) {
    // print("starting new key item");
    _isEditing = true;

    _generateKeyPair();

    _filteredTags = _settingsManager.itemTags;
    for (var tag in _settingsManager.itemTags) {
      _selectedTags.add(false);
      // _filteredTags.add(tag);
    }

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;

    _selectedIndex = _settingsManager.currentTabIndex;

    _validateFields();

    // Timer(Duration(milliseconds: 100), () {
    //   _showModalGenerateOrImportKeyView();
    // });
  }


  Future<void> _generateKeyPair() async {
    // print("add_public_encryption_key: _generateKeyPair");

    final algorithm_exchange = X25519();

    // _seedKey = _cryptor.getRandomBytes(32);
    // print("rand seed: $_seedKey");

    // final encryptedPrivateKey = await _cryptor.createEncryptedPeerKeyExchangeKey();
    // print("encryptedPrivateKey: ${encryptedPrivateKey}");
    //
    // final privateExchangeKeySeed = await _cryptor.decrypt(encryptedPrivateKey);
    // print("privateExchangeKeySeed: ${privateExchangeKeySeed}");
    //
    // // final privKeyHex = hex.decode(privateExchangeKeySeed);
    // // print("privKeyHex: ${privKeyHex.length}: ${privKeyHex}");
    //
    // _privKeyExchange = base64.decode(privateExchangeKeySeed);
    // print("_privKeyExchange64: ${_privKeyExchange.length}: ${_privKeyExchange}");

    /// OR
    ///

    // final privateExchangeKeySeed2 = _cryptor.getRandomBytes(32);

    // print("pubExchangeKeySeed: $pubExchangeKeySeed");


    // final privSeedPair = await algorithm_exchange
    //     .newKeyPairFromSeed(base64.decode(privateExchangeKeySeed));

    /// TODO: test alt method
    ///
    final privSeedPair2 = await algorithm_exchange
        .newKeyPair();
    final privkeyseed2 = await privSeedPair2.extractPrivateKeyBytes();
    // print("privkeyseed2 check: ${privkeyseed2}");

    _privKeyExchange = privkeyseed2;

    // final privSeedPairChecker = await algorithm_exchange
    //     .newKeyPairFromSeed(privkeyseed2);
    // final privkeyseed4 = await privSeedPairChecker.extractPrivateKeyBytes();
    // print("privkeyseed4 check: ${privkeyseed4}");

    // final privkeyseed = await privSeedPair.extractPrivateKeyBytes();
    // print("privkeyseed check: ${privkeyseed}");
    // print("privkeyseed check hex: ${hex.encode(privkeyseed)}");
    //
    // final simplePublicKey = await privSeedPair.extractPublicKey();

    final simplePublicKey = await privSeedPair2.extractPublicKey();

    _pubKeyExchange = simplePublicKey.bytes;
    // print("_pubKeyExchange: ${_pubKeyExchange}");

    // final expanded = await _cryptor.expandKey(_seedKey);

    setState(() {
      _pubKeyExchange = simplePublicKey.bytes;
      // print("_pubKeyExchange: ${_pubKeyExchange}");
      // print("_pubKeyExchange: ${_pubKeyExchange.length}: ${_pubKeyExchange}");
      // print("main publicKey: ${_pubKeyExchange.length}: ${hex.encode(_pubKeyExchange)}");

      _publicKeyMnemonic = bip39.entropyToMnemonic(hex.encode(_pubKeyExchange));
      // print("_publicKeyMnemonic: ${_publicKeyMnemonic}");

      _keyDataTextController.text =
          _publicKeyMnemonic;
    });

    _validateFields();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black54 : Colors.blue[50],//Colors.grey[100],
      appBar: AppBar(
        title: Text('Asymmetric Key Pair'),
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

              /// symmetric options
              ///
              // Divider(color: _isDarkModeEnabled ? Colors.greenAccent : null),


              Visibility(
                visible: true,
                child:
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Visibility(
                      visible: true,
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
                            backgroundColor:(_isDarkModeEnabled
                                ? MaterialStateProperty.all<Color>(
                                Colors.greenAccent)
                                : null)
                        ),
                        onPressed: () async {
                          setState((){
                            _isGeneratingKey = true;
                          });
                          await _generateKeyPair();
                        },
                        child: Text(
                          "Generate Key",
                        ),
                      ),
                    ),
                    Visibility(
                      visible: true,
                      child: Spacer(),
                    ),
                    // Visibility(
                    //   visible: false,
                    //   child: ElevatedButton(
                    //     style: ButtonStyle(
                    //         foregroundColor: _isDarkModeEnabled
                    //             ? MaterialStateProperty.all<Color>(
                    //             Colors.black)
                    //             : null,
                    //         backgroundColor:(_isDarkModeEnabled
                    //             ? MaterialStateProperty.all<Color>(
                    //             Colors.greenAccent)
                    //             : null)
                    //     ),
                    //     onPressed: () async {
                    //       // await _generateKeyPair();
                    //       /// HERE: test
                    //       _showModalImportKeyOptionsView();
                    //     },
                    //     child: Text(
                    //       "Import Key",
                    //     ),
                    //   ),
                    // ),
                    // Visibility(
                    //   visible: false,
                    //   child: Spacer(),
                    // ),
                  ],),),
              // Divider(color: _isDarkModeEnabled ? Colors.greenAccent : null),

              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Public Key:\n${hex.encode(_pubKeyExchange)}",

                  // "Public Key:\n${hex.encode(_pubKeyExchange)}\n\nPublic Mnemonic:\n${_publicKeyMnemonic}",
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : null,
                    fontSize: 16,
                  ),
                ),
              ),
              Visibility(
                visible: false,
                child:
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
                          // obscureText: _shouldShowRootKey,
                          // minLines: _shouldShowRootKey ? 2 : 1,
                          // maxLines: _shouldShowRootKey ? 8 : 1,
                          decoration: InputDecoration(
                            labelText: 'Public Key',
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
                ),),
              Visibility(
                visible: !_isGeneratingKey,
                child:
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
                          readOnly: false,
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
                          focusNode: _importKeyDataFocusNode,
                          controller: _importKeyDataTextController,
                        ),
                      ),
                    ),
                    //
                  ],
                ),),
              Visibility(
                visible: false,
                child:
                ElevatedButton(
                  style: ButtonStyle(
                    foregroundColor: _isDarkModeEnabled
                        ? MaterialStateProperty.all<Color>(
                        Colors.black)
                        : null,
                    backgroundColor:(_isDarkModeEnabled
                        ? MaterialStateProperty.all<Color>(
                        Colors.greenAccent)
                        : null),
                  ),
                  onPressed: () async {
                    // await _generateKeyPair();
                    setState((){
                      _shouldShowRootKey = !_shouldShowRootKey;
                    });
                  },
                  child: Text( !_shouldShowRootKey ?
                  "Show Key" : "Hide Key",
                  ),
                ),),

              // Visibility(
              //   visible: _shouldShowExtendedKeys,
              //   child:
              //   Padding(
              //     padding: EdgeInsets.all(16),
              //     child: Text(
              //       "Encryption: ${hex.encode(Kenc)}",
              //       style: TextStyle(
              //         color: _isDarkModeEnabled ? Colors.white : null,
              //       ),
              //       textAlign: TextAlign.left,
              //     ),
              //   ),),
              // Visibility(
              //   visible: _shouldShowExtendedKeys,
              //   child:
              //   Padding(
              //     padding: EdgeInsets.all(16),
              //     child: Text(
              //       "Authentication: ${hex.encode(Kauth)}",
              //       style: TextStyle(
              //         color: _isDarkModeEnabled ? Colors.white : null,
              //       ),
              //       textAlign: TextAlign.left,
              //     ),
              //   ),),

              Divider(color: _isDarkModeEnabled ? Colors.greenAccent : null),

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
              Divider(color: _isDarkModeEnabled ? Colors.greenAccent : null),
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

  void _validateFields() {
    final name = _nameTextController.text;
    final mnemonic = _keyDataTextController.text;

    if (name.isEmpty) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    if (_pubKeyExchange.isEmpty) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    if (!bip39.validateMnemonic(mnemonic)) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    setState(() {
      _fieldsAreValid = true;
    });
  }


  _pressedSaveKeyItem() async {

    if (_privKeyExchange == null) {
      _showErrorDialog('Could not save the item.');
      return;
    }

    if (_privKeyExchange.isEmpty) {
      _showErrorDialog('Could not save the item.');
      return;
    }
    var createDate = DateTime.now().toIso8601String();
    var uuid = _cryptor.getUUID();

    final name = _nameTextController.text;
    final notes = _notesTextController.text;

    final encodedLength = utf8.encode(name).length + utf8.encode(notes).length + utf8.encode(base64.encode(_privKeyExchange)).length;

    _settingsManager.doEncryption(encodedLength);

    if (AppConstants.debugKeyData) {
      _logManager.logger.d("_privKeyExchange: $_privKeyExchange");
    }


    /// encrypt note items
    ///
    final encryptedName = await _cryptor.encrypt(name);

    final encryptedNotes = await _cryptor.encrypt(notes);

    /// TODO: switch encoding !
    // final encryptedKey = await _cryptor.encrypt(hex.encode(_privKeyExchange));
    final encryptedKey = await _cryptor.encrypt(base64.encode(_privKeyExchange));

    var keyItem = KeyItem(
      id: uuid,
      keyId: _keyManager.keyId,
      version: AppConstants.keyItemVersion,
      name: encryptedName,
      key: encryptedKey,
      keyType: EnumToString.convertToString(EncryptionKeyType.asym),
      purpose: EnumToString.convertToString(KeyPurposeType.keyexchange),
      algo: EnumToString.convertToString(KeyExchangeAlgoType.x25519),
      notes: encryptedNotes,
      favorite: _isFavorite,
      isBip39: false,
      peerPublicKeys: [],
      tags: _keyTags,
      mac: "",
      cdate: createDate,
      mdate: createDate,
    );

    final itemMac = await _cryptor.hmac256(keyItem.toRawJson());
    keyItem.mac = itemMac;

    final keyItemJson = keyItem.toRawJson();
    // print("save keyItemJson: $keyItemJson");

    final genericItem = GenericItem(type: "key", data: keyItemJson);
    // print('genericItem toRawJson: ${genericItem.toRawJson()}');

    final genericItemString = genericItem.toRawJson();
    // _logManager.logger.d("save key item genericItemString: $genericItemString");

    /// save key item in keychain
    ///
    final status = await _keyManager.saveItem(uuid, genericItemString);

    // final status = true;

    if (status) {
      EasyLoading.showToast('Saved Item', duration: Duration(seconds: 1));

      if (_isNewKey) {
        Navigator.of(context).pop('savedItem');
      }
    } else {
      _showErrorDialog('Could not save the item.');
    }
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

                                  if (!_settingsManager.itemTags
                                      .contains(userTag)) {
                                    var updatedTagList =
                                    _settingsManager.itemTags.copy();
                                    updatedTagList.add(userTag);

                                    updatedTagList
                                        .sort((e1, e2) => e1.compareTo(e2));

                                    _settingsManager
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

  /// For adding tags
  _validateModalField(StateSetter state) async {
    final text = _tagTextController.text;

    state(() {
      _tagTextFieldValid =
          _tagTextController.text.isNotEmpty && !_keyTags.contains(text);
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
