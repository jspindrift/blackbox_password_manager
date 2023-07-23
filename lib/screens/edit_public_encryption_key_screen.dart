import 'dart:async';
import 'dart:convert';
import 'package:argon2/argon2.dart';
import '../models/KeyItem.dart';
import '../screens/active_encryption_screen.dart';
import '../screens/peer_public_key_list_screen.dart';
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:intl/intl.dart';

import '../helpers/AppConstants.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/KeychainManager.dart';
import '../managers/Cryptor.dart';

import '../models/GenericItem.dart';

import '../models/QRCodeItem.dart';
import '../widgets/qr_code_view.dart';
import 'home_tab_screen.dart';

/// Editing a Primary (Main/Parent) Public Key
/// 
///

class EditPublicEncryptionKeyScreen extends StatefulWidget {
  const EditPublicEncryptionKeyScreen({
    Key? key,
    required this.id,
  }) : super(key: key);
  static const routeName = '/edit_public_encryption_key_screen';

  final String id;

  @override
  State<EditPublicEncryptionKeyScreen> createState() => _EditPublicEncryptionKeyScreenState();
}

class _EditPublicEncryptionKeyScreenState extends State<EditPublicEncryptionKeyScreen> {
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
  bool _shouldShowExtendedKeys = false;

  bool _isEditing = false;
  bool _isNewKey = true;
  bool _isFavorite = false;
  bool _fieldsAreValid = false;
  bool _isSymmetricKey = false;

  bool _hasPeerPublicKeys = false;

  bool _validKeyTypeValues = true;

  List<String> _keyTags = [];
  List<bool> _selectedTags = [];
  List<String> _filteredTags = [];

  /// used for asymmetric keys
  List<int> _privKey = [];
  List<int> _pubKey = [];
  String _publicKeyMnemonic = "";

  /// Used for symmetric keys
  List<int> _seedKey = [];
  List<int> Kenc = [];
  List<int> Kauth = [];

  QRCodeKeyItem qrItem = QRCodeKeyItem(key: '', symmetric: false);

  KeyItem? _keyItem;

  List<PeerPublicKey> _peerPublicKeys = [];

  String _modifiedDate = DateTime.now().toIso8601String();
  String _createdDate = DateTime.now().toIso8601String();

  final logManager = LogManager();
  final settingsManager = SettingsManager();
  final keyManager = KeychainManager();
  final cryptor = Cryptor();

  @override
  void initState() {
    super.initState();

    logManager.log("EditPublicEncryptionKeyScreen", "initState", "initState");

    // print("tags note: ${settingsManager.itemTags}");
    // if (widget.note == null) {
    // print("starting new key item");
    // _isEditing = true;

    /// read key info from keychain
    _getItem();

    _filteredTags = settingsManager.itemTags;
    for (var tag in settingsManager.itemTags) {
      _selectedTags.add(false);
      // _filteredTags.add(tag);
    }

    _isDarkModeEnabled = settingsManager.isDarkModeEnabled;

    _selectedIndex = settingsManager.currentTabIndex;

    _validateFields();
  }

  void _getItem() async {
    /// get the password item and decrypt the data
    keyManager.getItem(widget.id).then((value) async {
      final genericItem = GenericItem.fromRawJson(value);

      if (genericItem.type == "key") {
        // print("edit public encryption key: value: $value");

        /// must be a PasswordItem type
        _keyItem = KeyItem.fromRawJson(genericItem.data);

        if (_keyItem != null) {
          var keydata = (_keyItem?.key)!;

          if (keydata == null) {
            return;
          }
          // print("keydata: ${keydata.length}: ${keydata}");

          final keyType = (_keyItem?.keyType)!;
          // final keyIndex = (_keyItem?.keyIndex)!;
          // var keyIndex = 0;
          //
          // if (_keyItem?.keyIndex != null) {
          //   keyIndex = (_keyItem?.keyIndex)!;
          // }

          /// decrypt root seed and expand
          final decryptedSeedData = await cryptor.decrypt(keydata);
          // print("decryptedSeedData: ${decryptedSeedData}");

          /// TODO: switch encoding !
          // final decodedRootKey = hex.decode(decryptedSeedData);
          final decodedRootKey = base64.decode(decryptedSeedData);

          // print("decodedRootKey: ${decodedRootKey.length}: ${decodedRootKey}");

          if (keyType == EnumToString.convertToString(EncryptionKeyType.asym)) {
            setState(() {
              _isSymmetricKey = false;
            });
            final peerPublicKeys = (_keyItem?.peerPublicKeys)!;

            if (peerPublicKeys == null) {
              setState(() {
                _hasPeerPublicKeys = false;
              });
            } else {
              if (peerPublicKeys.isEmpty) {
                setState(() {
                  _hasPeerPublicKeys = false;
                });
              } else {
                setState(() {
                  _hasPeerPublicKeys = true;
                  _peerPublicKeys = peerPublicKeys;
                });
              }
            }

            _generateKeyPair(decryptedSeedData);

          } else {
            setState(() {
              _isSymmetricKey = true;
            });

            final expanded = await cryptor.expandKey(decodedRootKey);

            setState(() {
              _seedKey = decodedRootKey;
              // print("_seedKey: ${_seedKey.length}: ${_seedKey}");

              Kenc = expanded.sublist(0,32);
              Kauth = expanded.sublist(32,64);

              _keyDataTextController.text = bip39.entropyToMnemonic(decryptedSeedData);
            });
          }


          var name = (_keyItem?.name)!;
          var tags = (_keyItem?.tags)!;

          for (var tag in tags) {
            _selectedTags.add(false);
          }

          _keyTags = tags;

          var isFavorite = (_keyItem?.favorite)!;

          _isFavorite = isFavorite;

          final notes = (_keyItem?.notes)!;

          final cdate = (_keyItem?.cdate)!;
          _createdDate = cdate;// DateTime.parse(cdate);

          final mdate = (_keyItem?.mdate)!;
          _modifiedDate = mdate;//DateTime.parse(mdate);

          // final encryptedPreviousPasswords =
          // (_keyItem?.previousKeys)!;
          // _initialEncryptedPreviousPasswords = encryptedPreviousPasswords;

          // final blob = (_passwordItem?.password)!;

          cryptor.decrypt(name).then((value) {
            name = value;

            _validateFields();
          });

          /// decrypt notes
          cryptor.decrypt(notes).then((value) {
            if (value.isNotEmpty) {
              setState(() {
                // _hasNotes = true;
                _notesTextController.text = value;
              });
            }

            if (_isSymmetricKey) {
              qrItem = QRCodeKeyItem(key: base64.encode(_seedKey), symmetric: true);
            } else {
              qrItem = QRCodeKeyItem(key: base64.encode(_pubKey), symmetric: false);
            }

            setState(() {
              _nameTextController.text = name;
            });

            _validateFields();
          });

          setState(() {

          });
        }
      }
    });
  }

  Future<void> _generateKeyPair(String privateKeyString) async {
    // print("edit_public_encr_key: _generateKeyPair");

    final algorithm_exchange = X25519();

    // _seedKey = cryptor.getRandomBytes(32);
    // print("rand seed: $_seedKey");

    // final encryptedPrivateKey = await cryptor.createDigitalIdentityExchange();
    // print("encryptedPrivateKey: ${encryptedPrivateKey}");
    //
    // final privateExchangeKeySeed = await cryptor.decrypt(encryptedPrivateKey);
    // print("privateExchangeKeySeed: ${privateExchangeKeySeed}");

    /// TODO: switch encoding !
    // _privKey = hex.decode(privateKeyString);
    _privKey = base64.decode(privateKeyString);

    // print("_privKey: ${_privKey.length}: ${_privKey}");

    /// OR
    ///

    // final privateExchangeKeySeed2 = cryptor.getRandomBytes(32);

    // print("pubExchangeKeySeed: $pubExchangeKeySeed");

    /// TODO: switch encoding !
    // final privSeedPair = await algorithm_exchange
    //     .newKeyPairFromSeed(hex.decode(privateKeyString));
    final privSeedPair = await algorithm_exchange
        .newKeyPairFromSeed(base64.decode(privateKeyString));

    // final tempPrivKey = await privSeedPair.extractPrivateKeyBytes();
    // print("tempPrivKey: ${tempPrivKey}");

    final simplePublicKey = await privSeedPair.extractPublicKey();

    // _pubKey = simplePublicKey.bytes;
    // print("_publicKey: ${simplePublicKey.bytes}");

    // final expanded = await cryptor.expandKey(_seedKey);


    setState(() {
      _pubKey = simplePublicKey.bytes;
      qrItem = QRCodeKeyItem(key: base64.encode(_pubKey), symmetric: false);

      // print("_publicKey: ${_publicKey}");
      // print("_publicKey: ${_pubKey.length}: ${_pubKey}");
      // print("_publicKey: ${_pubKey.length}: ${hex.encode(_pubKey)}");

      _publicKeyMnemonic = bip39.entropyToMnemonic(hex.encode(_pubKey));
      // print("_publicKeyMnemonic: ${_publicKeyMnemonic}");

      _keyDataTextController.text =
          _publicKeyMnemonic;

      // Kenc = expanded.sublist(0,32);
      // Kauth = expanded.sublist(32,64);
    });

    _validateFields();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text(
            'Key Pair',
          textAlign: TextAlign.center,
        ),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: !_isEditing ? BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ) : CloseButton(
              color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () {
              setState((){
                _isEditing = false;
              });

              _getItem();
          },
        ),
        actions: [
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
          Visibility(
            visible: !_isEditing,
            child:
            TextButton(
              child: Text(
                "Edit",
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
                // await _pressedSaveKeyItem();

                setState(() {
                  _isEditing = !_isEditing;
                });

                // Timer(Duration(milliseconds: 100), () {
                //   FocusScope.of(context).unfocus();
                //   /// TODO: re-enable fields for editing
                //   ///
                // });
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
                  textInputAction: TextInputAction.done,
                  focusNode: _nameFocusNode,
                  controller: _nameTextController,
                ),
              ),

              /// symmetric options
              ///
              // Divider(color: _isDarkModeEnabled ? Colors.greenAccent : null),


              // Row(
              //   mainAxisAlignment: MainAxisAlignment.center,
              //   children: [
              //     Visibility(
              //       visible: true,
              //       child: Spacer(),
              //     ),
              //     Visibility(
              //       visible: false,
              //       child: ElevatedButton(
              //         style: ButtonStyle(
              //             foregroundColor: _isDarkModeEnabled
              //                 ? MaterialStateProperty.all<Color>(
              //                 Colors.black)
              //                 : null,
              //             backgroundColor: _validKeyTypeValues
              //                 ? (_isDarkModeEnabled
              //                 ? MaterialStateProperty.all<Color>(
              //                 Colors.greenAccent)
              //                 : null)
              //                 : MaterialStateProperty.all<Color>(
              //                 Colors.blueGrey)
              //         ),
              //         onPressed: _validKeyTypeValues ? () {
              //           // _generateKey();
              //         } : null,
              //         child: Text(
              //           "Generate Key",
              //         ),
              //       ),
              //     ),
              //     Visibility(
              //       visible: true,
              //       child: Spacer(),
              //     ),
              //   ],),
              // Divider(color: _isDarkModeEnabled ? Colors.greenAccent : null),
              Visibility(
                visible: false,
                child:
                ElevatedButton(
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
                    // _generateKey();
                    setState((){
                      _shouldShowExtendedKeys = !_shouldShowExtendedKeys;
                    });
                  } : null,
                  child: Text( !_shouldShowExtendedKeys ?
                  "Show Key" : "Hide Key",
                  ),
                ),),
              Visibility(
                visible: true, //_shouldShowExtendedKeys,
                child:  Padding(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Text(
                    "Public Key:\n${hex.encode(_pubKey)}",
                    // "Public Key:\n${hex.encode(_peerPublicKeyData)}\n\nPublic Mnemonic:\n${_publicKeyMnemonic}",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                      fontSize: 16,
                    ),
                  ),
                ),),

              Divider(color: _isDarkModeEnabled ? Colors.greenAccent : null),

              Visibility(
                visible: false, //_shouldShowExtendedKeys,
                child:
                Row(
                  children: [
                    Visibility(
                      visible: true,
                      child:  Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        "Public Key:\n${hex.encode(_pubKey)}",
                        // "Public Key:\n${hex.encode(_peerPublicKeyData)}\n\nPublic Mnemonic:\n${_publicKeyMnemonic}",
                        style: TextStyle(
                          color: _isDarkModeEnabled ? Colors.white : null,
                          fontSize: 16,
                        ),
                      ),
                    ),),
                    Visibility(
                      visible: false,
                      child:
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
                    ),),
                    //
                  ],
                ),),
              Visibility(
                visible: true,
                child:
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: _fieldsAreValid
                            ? () async {

                          final entropy = bip39.mnemonicToEntropy(_keyDataTextController.text);

                          // final entropyBytes = hex.decode(entropy);
                          //
                          // final base64Key = base64.encode(entropyBytes);

                          await Clipboard.setData(ClipboardData(
                            text: entropy,
                          ));

                          settingsManager.setDidCopyToClipboard(true);

                          EasyLoading.showToast('Copied Public Key',
                              duration: Duration(milliseconds: 500));
                        }
                            : null,
                        icon: Icon(
                          Icons.copy_rounded,
                          color: _isDarkModeEnabled
                              ? (_fieldsAreValid
                              ? Colors.greenAccent
                              : Colors.grey)
                              : (_fieldsAreValid
                              ? Colors.blueAccent
                              : Colors.grey),
                          size: 30.0,
                        ),
                      ),
                      TextButton(
                        child: Text(
                          'Copy PubKey',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: _isDarkModeEnabled
                                ? (_fieldsAreValid ? Colors.white : Colors.grey)
                                : (_fieldsAreValid ? Colors.black : Colors.grey),
                          ),
                        ),
                        onPressed: _fieldsAreValid
                            ? () async {

                          final entropy = bip39.mnemonicToEntropy(_keyDataTextController.text);

                          // final entropyBytes = hex.decode(entropy);
                          //
                          // final base64Key = base64.encode(entropyBytes);

                          await Clipboard.setData(ClipboardData(
                            text: entropy,
                          ));

                          settingsManager.setDidCopyToClipboard(true);

                          EasyLoading.showToast('Copied Public Key',
                              duration: Duration(milliseconds: 500),
                          );
                        } : null,
                      ),
                      Spacer(),

                    ],
                  ),
                ),),
              Visibility(
                visible: true,
                child:
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: _fieldsAreValid
                            ? () async {

                          _pressedShareItem();

                          // print("show QR code");
                          // await Clipboard.setData(ClipboardData(
                          //     text: _keyDataTextController.text));
                          //
                          // settingsManager.setDidCopyToClipboard(true);
                          //
                          // EasyLoading.showToast('Copied',
                          //     duration: Duration(milliseconds: 500));
                        }
                            : null,
                        icon: Icon(
                          Icons.qr_code,
                          color: _isDarkModeEnabled
                              ? (_fieldsAreValid
                              ? Colors.greenAccent
                              : Colors.grey)
                              : (_fieldsAreValid
                              ? Colors.blueAccent
                              : Colors.grey),
                          size: 30.0,
                        ),
                      ),
                      TextButton(
                        child: Text(
                          'PubKey QR Code',
                          // 'Public Key QR Code',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: _isDarkModeEnabled
                                ? (_fieldsAreValid ? Colors.white : Colors.grey)
                                : (_fieldsAreValid ? Colors.black : Colors.grey),
                          ),
                        ),
                        onPressed: _fieldsAreValid
                            ? () async {
                          _pressedShareItem();
                        } : null,
                      ),
                      Spacer(),
                    ],
                  ),
                ),),


              // Divider(color: _isDarkModeEnabled ? Colors.greenAccent : null),

              // Padding(
              //     padding: EdgeInsets.all(16),
              //     child: ListTile(
              //       title: Text(
              //         "Encrypt/Decrypt",
              //         style: TextStyle(
              //           color: _isDarkModeEnabled ? Colors.white : null,
              //         ),
              //       ),
              //       trailing: Icon(
              //         Icons.arrow_forward_ios,
              //         color: _isDarkModeEnabled ? Colors.greenAccent : null,
              //       ),
              //       onTap: (){
              //         print("open encryption and decryption screen");
              //
              //         Navigator.push(
              //           context,
              //           MaterialPageRoute(
              //             builder: (context) => ActiveEncryptionScreen(
              //               id: widget.id,
              //             ),
              //           ),
              //         ).then((value) {
              //           // _getItem();
              //         });
              //       },
              //     )
              // ),
              Visibility(
                visible: true, //_hasPeerPublicKeys,
                child:
                    Divider(color: _isDarkModeEnabled ? Colors.greenAccent : null),
              ),
              Visibility(
                visible: true, //_hasPeerPublicKeys,
                child:
              Padding(
                  padding: EdgeInsets.all(16),
                  child: ListTile(
                    title: Text(
                      "Peer Public Keys (${_peerPublicKeys.length})",
                      style: TextStyle(
                        color: _isDarkModeEnabled ? Colors.white : Colors.blueAccent,
                      ),
                    ),
                    subtitle: Padding(
                      padding: EdgeInsets.fromLTRB(0, 8, 4, 4),
                      child: Text(
                      "Add a friend's public key to established a shared secret.",
                      style: TextStyle(
                        color: _isDarkModeEnabled ? Colors.grey[300] : null,
                        fontSize: 14
                      ),
                    ),),
                    leading: Icon(
                      Icons.key,
                      color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                    ),
                    onTap: (){

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PeerPublicKeyListScreen(
                            id: widget.id,
                          ),
                        ),
                      ).then((value) {
                        // _getItem();
                        _getItem();
                      });
                    },
                  )
              ),),

              Visibility(
                visible: false, //!_hasPeerPublicKeys,
                child:
                Divider(color: _isDarkModeEnabled ? Colors.greenAccent : null),
              ),
              Visibility(
                visible: false,//!_hasPeerPublicKeys,
                child:
                Padding(
                    padding: EdgeInsets.all(16),
                    child: ListTile(
                      title: Text(
                        "Peer Public Keys",
                        style: TextStyle(
                          color: _isDarkModeEnabled ? Colors.white : null,
                        ),
                      ),
                      leading: Icon(
                        Icons.add_circle,
                        color: _isDarkModeEnabled ? Colors.greenAccent : null,
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: _isDarkModeEnabled ? Colors.greenAccent : null,
                      ),
                      onTap: (){
                        // print("import peer public keys...");

                        /// Show Modal asking to scan or import
                        ///


                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PeerPublicKeyListScreen(
                              id: widget.id,
                            ),
                          ),
                        ).then((value) {
                          _getItem();
                        });
                      },
                    )
                ),),

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
              Divider(
                  color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              ),
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
                                color: _isDarkModeEnabled ? Colors.white : Colors.blueAccent,
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
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "id: ${(_keyItem?.id)!}",
                  // "Public Key:\n${hex.encode(_peerPublicKeyData)}\n\nPublic Mnemonic:\n${_publicKeyMnemonic}",
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : null,
                    fontSize: 14,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "created: ${DateFormat('MMM d y  hh:mm:ss a').format(DateTime.parse((_createdDate)!))}",
                  // "Public Key:\n${hex.encode(_peerPublicKeyData)}\n\nPublic Mnemonic:\n${_publicKeyMnemonic}",
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : null,
                    fontSize: 14,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "modified: ${DateFormat('MMM d y  hh:mm:ss a').format(DateTime.parse((_modifiedDate)!))}",
                  // "Public Key:\n${hex.encode(_peerPublicKeyData)}\n\nPublic Mnemonic:\n${_publicKeyMnemonic}",
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : null,
                    fontSize: 14,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    // if (!_isNewKey)
                    Divider(
                      color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
                    ),
                    // if (!_isNewKey)
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

    if (_seedKey.isEmpty && _isSymmetricKey) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    if (_privKey.isEmpty && !_isSymmetricKey) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    setState(() {
      _fieldsAreValid = true;
    });
  }


  _pressedShareItem() {
    // var qrItemString = "";

    // if (_isSymmetricKey) {
     final qrItemString = qrItem.toRawJson();
     // print("qrItemString: ${qrItemString}");
    // } else {
    //   qrItemString = qrPublicItem.toRawJson();
    // }

    // final qrItemString = qrItem.toRawJson();

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

  _pressedSaveKeyItem() async {
    _modifiedDate = DateTime.now().toIso8601String();
    var uuid = widget.id;

    if (uuid == null) {
      return;
    }

    if (uuid.isEmpty) {
      return;
    }

    if (_privKey == null) {
      _showErrorDialog('Could not save the item.');
      return;
    }

    if (_privKey.isEmpty) {
      _showErrorDialog('Could not save the item.');
      return;
    }

    final name = _nameTextController.text;
    final notes = _notesTextController.text;

    final encodedLength = utf8.encode(name).length + utf8.encode(notes).length + utf8.encode(base64.encode(_privKey)).length;

    settingsManager.doEncryption(encodedLength);

    /// encrypt
    final encryptedName = await cryptor.encrypt(name);
    final encryptedNotes = await cryptor.encrypt(notes);

    final encryptedKey = await cryptor.encrypt(base64.encode(_privKey));

    final keyItem = KeyItem(
      id: uuid,
      version: AppConstants.keyItemVersion,
      name: encryptedName,
      key: encryptedKey,
      keyType: EnumToString.convertToString(EncryptionKeyType.asym),
      purpose: EnumToString.convertToString(KeyPurposeType.keyexchange),
      algo: EnumToString.convertToString(KeyExchangeAlgoType.x25519),
      notes: encryptedNotes,
      favorite: _isFavorite,
      isBip39: false,
      peerPublicKeys: _peerPublicKeys,
      tags: _keyTags,
      cdate: _createdDate,
      mdate: _modifiedDate,
    );

    final keyItemJson = keyItem.toRawJson();
    // print("save edited keyItemJson: $keyItemJson");

    /// TODO: add GenericItem
    ///
    final genericItem = GenericItem(type: "key", data: keyItemJson);
    // print('genericItem toRawJson: ${genericItem.toRawJson()}');

    final genericItemString = genericItem.toRawJson();
    // print("save key item genericItemString: $genericItemString");

    /// save key item in keychain
    ///
    final status = await keyManager.saveItem(uuid, genericItemString);

    if (status) {
      EasyLoading.showToast('Saved Item', duration: Duration(seconds: 1));
    } else {
      _showErrorDialog('Could not save the item.');
    }
  }

  void _showConfirmDeleteItemDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Item'),
        content: Text('Are you sure you want to delete this item?  This will also delete all Peer Public Keys associated with this key.'),
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
    final status = await keyManager.deleteItem((widget.id)!);

    if (status) {
      Navigator.of(context).pop();
    } else {
      _showErrorDialog('Delete item failed');
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
