import 'dart:async';
import 'dart:convert';

import 'package:blackbox_password_manager/managers/WOTSManager.dart';
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import '../helpers/AppConstants.dart';
import '../models/EncryptedPeerMessage.dart';
import '../models/KeyItem.dart';
import '../models/GenericItem.dart';
import '../models/QRCodeEncryptedMessageItem.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/KeychainManager.dart';
import '../managers/Cryptor.dart';
import '../models/WOTSSignatureItem.dart';
import '../widgets/qr_code_view.dart';
import 'home_tab_screen.dart';


/// This is where encryption and decryption of messages with a set key takes place
///
/// Copied from EditEncryptionKeyScreen


class ActiveEncryptionScreen extends StatefulWidget {
  const ActiveEncryptionScreen({
    Key? key,
    required this.id,
    KeyItem? this.keyItem,
    // required this.state,

  }) : super(key: key);
  static const routeName = '/active_encryption_key_screen';

  final String id;
  final KeyItem? keyItem;
  // final StateBuilder state;

  @override
  State<ActiveEncryptionScreen> createState() => _ActiveEncryptionScreenState();
}

class _ActiveEncryptionScreenState extends State<ActiveEncryptionScreen> {
  final _messageTextController = TextEditingController();

  final _messageFocusNode = FocusNode();

  final _debugTestWots = false;

  int _selectedIndex = 1;

  bool _isDarkModeEnabled = false;
  bool _fieldsAreValid = false;

  bool _isRootSymmetric = false;
  bool _didEncrypt = false;
  bool _isDecrypting = false;
  bool _didDecryptSuccessfully = false;
  bool _showShareMessageAsQRCode = false;
  bool _hasEmbeddedMessageObject = false;

  bool _isUsingWOTS = false;

  List<int> _mainPrivateKey = [];
  List<int> _mainPublicKey = [];
  String _mainKeyName = "";
  String _peerKeyName = "";

  String _fromAddr = "";
  String _toAddr = "";

  List<int> _peerPublicKey = [];

  List<int> _seedKey = [];
  List<int> _Kenc = [];
  List<int> _Kauth = [];

  /// sender (this user)
  List<int> _Kenc_send = [];
  List<int> _Kauth_send = [];

  /// reciever (peer)
  List<int> _Kenc_rec = [];
  List<int> _Kauth_rec = [];

  List<int> _Kwots = [];
  List<int> _Kwots_send = [];
  int _wotsSigningCounter = 0;

  KeyItem? _keyItem;

  QRCodeEncryptedMessageItem? _qrMessageItem;

  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _keyManager = KeychainManager();
  final _cryptor = Cryptor();

  final _wotsManager = WOTSManager();

  @override
  void initState() {
    super.initState();

    _logManager.log("ActiveEncryptionScreen", "initState", "initState");

    // _logManager.logger.d("widget.id: ${widget.id}");

    /// read key info from keychain
    _getItem();

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;

    _selectedIndex = _settingsManager.currentTabIndex;

    _wotsManager.reset();

    _validateFields();
  }

  void _getItem() async {

    if (widget.keyItem == null) {
      _isRootSymmetric = true;
      /// get the password item and decrypt the data
      final item = await _keyManager.getItem(widget.id);//.then((value) async {
        final genericItem = GenericItem.fromRawJson(item);
        if (genericItem.type == "key") {
          /// must be a PasswordItem type
          _keyItem = KeyItem.fromRawJson(genericItem.data);

          if (_keyItem != null) {
            var keydata = (_keyItem?.key)!;

            if (keydata == null) {
              return;
            }
            // print("keydata: ${keydata.length}: $keydata");

            /// TODO: set seedKey and encryption/auth keys
            // final decrypedSeedData = await _cryptor.decrypt(keydata);
            final decrypedSeedData = await _cryptor.decryptReturnData(keydata);
            var decodedSeedData = decrypedSeedData;
            if (_keyItem?.keyType == "sym") {
              decodedSeedData = base64.decode(utf8.decode(decrypedSeedData));
            }


            _seedKey = decodedSeedData;
            _logManager.logger.d("_seedKey: ${hex.encode(_seedKey)}");

            final expanded = await _cryptor.expandKey(_seedKey);
            if (AppConstants.debugKeyData) {
              _logManager.logger.d("decrypedSeedData: ${decrypedSeedData
                  .length}: $decrypedSeedData");
              _logManager.logger.d("decodedSeedData: ${decodedSeedData
                  .length}: $decodedSeedData");
              _logManager.logger.d("expanded: ${expanded.length}: $expanded");
            }


            setState(() {
              _Kenc = expanded.sublist(0, 32);
              _Kauth = expanded.sublist(32, 64);
            });

            var name = (_keyItem?.name)!;

            _logManager.logger.d("_Kenc: ${hex.encode(_Kenc)}\n"
                "_Kauth: ${hex.encode(_Kauth)}");

            _cryptor.decrypt(name).then((value) {
              name = value;

              _validateFields();
            });

            _Kwots = _cryptor.aesGenKeyBytes;
            if (_Kwots != null && _Kwots.isNotEmpty) {
              _logManager.logger.d("got a wots key: ${hex.encode(_Kwots)}");
            }
          }
        }
      // });
    } else {
      _isRootSymmetric = false;

      var keydata = (widget.keyItem?.key)!;

      // final keyIndex = (widget.keyItem?.keyIndex)!;
      var version = 0;

      if (widget.keyItem?.version != null) {
        version = (widget.keyItem?.version)!;
      }

      if (keydata == null) {
        return;
      }

      var keyName = (widget.keyItem?.name)!;


      final decryptedName = await _cryptor.decrypt(keyName);
      setState(() {
        _mainKeyName = decryptedName;
      });

      // _validateFields();

      var peerPublicKeys = (widget.keyItem?.peerPublicKeys)!;

      for (var peerKey in peerPublicKeys) {
        if (peerKey.id == widget.id) {
          var keyIndex = 0;
          // if (peerKey.version != null) {
          //   version = (peerKey?.version)!;
          // }
          final decryptedPeerPublicKey = await _cryptor.decrypt(peerKey.key);
          // _peerPublicKey = base64.decode(decryptedPeerPublicKey);

          final decryptedPeerName = await _cryptor.decrypt(peerKey.name);
          // _peerKeyName = decryptedPeerName;
          setState(() {
            _peerPublicKey = base64.decode(decryptedPeerPublicKey);
            _peerKeyName = decryptedPeerName;
          });
        }
      }

      /// TODO: set seedKey and encryption/auth keys
      // final decrypedSeedData = await _cryptor.decrypt(keydata);
      final decrypedMainPrivateKeyData = await _cryptor.decrypt(keydata);

      // print("decrypedMainPrivateKeyData: $decrypedMainPrivateKeyData");
      // _mainPrivateKey = base64.decode(decrypedMainPrivateKeyData);
      setState(() {
        _mainPrivateKey = base64.decode(decrypedMainPrivateKeyData);
      });

      await _generatePeerKeyPair();


      _validateFields();
    }

  }

  Future<void> _generatePeerKeyPair() async {
    if (_mainPrivateKey == null) {
      return;
    }

    if (_mainPrivateKey.isEmpty) {
      return;
    }

    if (_peerPublicKey == null) {
      return;
    }

    if (_peerPublicKey.isEmpty) {
      return;
    }

    final algorithm_exchange = X25519();

    // print("bobPubString: ${bobPubString.length}: ${bobPubString}");

    /// TODO: switch encoding !
    // final privKey = hex.decode(privateKeyString);
    // final privKey = base64.decode(privateKeyString);
    // print("privKey: ${privKey.length}: ${privKey}");
    // print("_mainPrivateKey: ${_mainPrivateKey.length}: ${_mainPrivateKey}");

    // final ownerKeyPair = await algorithm_exchange.newKeyPairFromSeed(privKey);
    final ownerKeyPair = await algorithm_exchange.newKeyPairFromSeed(_mainPrivateKey);

    // final privKey = await ownerKeyPair.extractPrivateKeyBytes();
    // print("privKeyBytes: ${privKey.length}: ${privKey}");

    final mainPublicKey = await ownerKeyPair.extractPublicKey();
    _mainPublicKey = mainPublicKey.bytes;
    // print("_mainPublicKey: ${_mainPublicKey.length}: ${_mainPublicKey}");
    // print("_mainPublicKeyHex: ${_mainPublicKey.length}: ${hex.encode(_mainPublicKey)}");

    // final bobPub = hex.decode(bobPubString);
    final bobPub = _peerPublicKey;
    // print('peer Public Key: $bobPub');
    // print('peer Public Key hex: ${hex.encode(bobPub)}');

    // _peerPublicKeyMnemonic = bip39.entropyToMnemonic(hex.encode(_peerPublicKey));


    final bobPublicKey = SimplePublicKey(bobPub, type: KeyPairType.x25519);
    final bobPubKeyBytes = bobPublicKey.bytes;

    final sharedSecret = await algorithm_exchange.sharedSecretKey(
      keyPair: ownerKeyPair,
      remotePublicKey: bobPublicKey,
    );

    final sharedSecretBytes = await sharedSecret.extractBytes();
    // print('Shared secret: $sharedSecretBytes');
    // print('Shared secret hex: ${hex.encode(sharedSecretBytes)}');

    // final sharedSecretKeyHash = await _cryptor.sha256(hex.encode(sharedSecretBytes));
    // print("shared secret key hash: ${sharedSecretKeyHash}");

    final expanded = await _cryptor.expandKey(sharedSecretBytes);
    // print('Shared secret expanded: $expanded');
    _Kenc = expanded.sublist(0, 32);
    _Kauth = expanded.sublist(32, 64);
    // print('secret _Kenc: ${hex.encode(_Kenc)}');
    // print('secret _Kauth: ${hex.encode(_Kauth)}');

    /// set public key values
    final mainPubSecretKey = SecretKey(_mainPublicKey);
    final bobPubSecretKey = SecretKey(bobPublicKey.bytes);

    final hmac = Hmac.sha256();
    final mac_e_receive = await hmac.calculateMac(
      _Kenc,
      secretKey: mainPubSecretKey!,
    );

    final mac_e_send = await hmac.calculateMac(
      _Kenc,
      secretKey: bobPubSecretKey!,
    );

    final Kwots_send = await hmac.calculateMac(
      _Kwots,
      secretKey: bobPubSecretKey!,
    );

    _Kenc_rec = mac_e_receive.bytes;
    _Kenc_send = mac_e_send.bytes;

    /// now do auth send/recieve keys
    final mac_auth_receive = await hmac.calculateMac(
      _Kauth,
      secretKey: mainPubSecretKey!,
    );

    final mac_auth_send = await hmac.calculateMac(
      _Kauth,
      secretKey: bobPubSecretKey!,
    );

    _Kauth_rec = mac_auth_receive.bytes;
    _Kauth_send = mac_auth_send.bytes;
    _Kwots_send = Kwots_send.bytes;
    // _logManager.logger.d("_Kwots_send: ${hex.encode(_Kwots_send)}");

    final toAddr = _cryptor.sha256(hex.encode(_peerPublicKey)).substring(0, 40);
    final fromAddr = _cryptor.sha256(hex.encode(_mainPublicKey)).substring(0,40);


    setState(() {
      _fromAddr = fromAddr;
      _toAddr = toAddr;
    });

    /// Generate WOTS private and pub keys
    ///
    if (_debugTestWots) {
      // await _wotsManager.createSimpleOverlapTopPubKey(_Kwots_send, 1);
    }

    if (AppConstants.debugKeyData) {
      _logManager.logger.d('secret _Kenc_recec: ${hex.encode(_Kenc_rec)}');
      _logManager.logger.d('secret _Kenc_sendend: ${hex.encode(_Kenc_send)}');
      _logManager.logger.d('secret _Kauth_recec: ${hex.encode(_Kauth_rec)}');
      _logManager.logger.d('secret _Kauth_sendend: ${hex.encode(_Kauth_send)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text('Message Encryption'),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: CloseButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [],
      ),
      body: SingleChildScrollView(
        child: Container(
          child: Column(
            children: <Widget>[
              Visibility(
                visible: !_isRootSymmetric,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child:Text(
                    "From: ${_mainKeyName}", //"${hex.encode(_mainPublicKey).substring(0, (_mainPublicKey.length/2).toInt())}...",
                    overflow: TextOverflow.fade,
                    maxLines: 3,
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
          Visibility(
            visible: !_isRootSymmetric,
            child:Padding(
              padding: EdgeInsets.all(4.0),
              child: Text(
              // textAlign: TextAlign.start,
              "Addr: ${_fromAddr} ", //"${hex.encode(_mainPublicKey).substring(0, (_mainPublicKey.length/2).toInt())}...",
                overflow: TextOverflow.fade,
                maxLines: 3,
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : null,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Visibility(
            visible: !_isRootSymmetric,
            child: Divider(
              thickness: 0.5,
              color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
            ),
          ),
              Visibility(
                visible: !_isRootSymmetric,
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child:Text(
                    textAlign: TextAlign.start,
                    "To: ${_peerKeyName}", //"${hex.encode(_peerPublicKey).substring(0,(_peerPublicKey.length/2).toInt())}...",
                    // "To: ${hex.encode(_peerPublicKey)}",
                    overflow: TextOverflow.fade,
                    maxLines: 3,
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              Visibility(
                visible: !_isRootSymmetric,
                child:Padding(
                  padding: EdgeInsets.all(4.0),
                  child:Text(
                  "Addr: ${_toAddr} ", //"${hex.encode(_mainPublicKey).substring(0, (_mainPublicKey.length/2).toInt())}...",
                  overflow: TextOverflow.fade,
                  maxLines: 3,
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : null,
                    fontSize: 14,
                  ),
                ),
                ),
              ),
              Visibility(
                visible: !_isRootSymmetric,
                child: Divider(
                  thickness: 0.9,
                  color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
                ),
              ),
              Visibility(
                visible: true,
                child: Row(
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
                          minLines: 4,
                          maxLines: 10,
                          decoration: InputDecoration(
                            labelText: 'Message',
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
                          textInputAction: TextInputAction.newline,
                          focusNode: _messageFocusNode,
                          controller: _messageTextController,
                        ),
                      ),
                    ),
                  ],
                ),),
              Row(
                children: [
                  Spacer(),
              Visibility(
                visible: true,
                child:
                ElevatedButton(
                  child: Text(
                    "Encrypt",
                  ),
                  style: ButtonStyle(
                      foregroundColor: _isDarkModeEnabled
                          ? MaterialStateProperty.all<Color>(
                          Colors.black)
                          : null,
                      backgroundColor: _fieldsAreValid
                          ? (_isDarkModeEnabled
                          ? MaterialStateProperty.all<Color>(
                          Colors.greenAccent)
                          : null)
                          : MaterialStateProperty.all<Color>(
                          Colors.blueGrey)
                  ),
                  onPressed: _fieldsAreValid ? () {
                    setState((){
                      _isDecrypting = false;
                    });

                    _encryptMessage();
                  } : null,
                  ),
                ),
                Spacer(),
                Visibility(
                visible: true,
                child: ElevatedButton(
                  child: Text(
                    "Decrypt",
                  ),
                  style: ButtonStyle(
                      foregroundColor: _isDarkModeEnabled
                          ? MaterialStateProperty.all<Color>(
                          Colors.black)
                          : null,
                      backgroundColor: _fieldsAreValid
                          ? (_isDarkModeEnabled
                          ? MaterialStateProperty.all<Color>(
                          Colors.greenAccent)
                          : null)
                          : MaterialStateProperty.all<Color>(
                          Colors.blueGrey)
                  ),
                  onPressed: _fieldsAreValid ? () {
                    setState((){
                      _isDecrypting = true;
                    });

                    _decryptMessage();
                  } : null,
                  ),
                ),
                Spacer(),
              ],),

              Visibility(
                visible: _debugTestWots,
                child:  Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              ),),
              Visibility(
                visible: _debugTestWots,
                child: Row(children: [
                  Spacer(),
                  RadioMenuButton(
                    value: true,
                    groupValue: _isUsingWOTS,
                    toggleable: true,
                    closeOnActivate: true,
                    trailingIcon: Icon(
                        Icons.sign_language,
                      color: _isDarkModeEnabled ? (_isUsingWOTS ? Colors.greenAccent : Colors.grey) : (_isUsingWOTS ? Colors.blueAccent : Colors.grey),
                      size: 30,
                    ),
                    style: ButtonStyle(
                      // backgroundColor: _isUsingWOTS ? MaterialStatePropertyAll<Color>(Colors.black54)
                      //     : MaterialStatePropertyAll<Color>(Colors.transparent),
                      // foregroundColor: _isUsingWOTS ? MaterialStatePropertyAll<Color>(Colors.black)
                      //     : MaterialStatePropertyAll<Color>(Colors.white),
                      iconColor: _isDarkModeEnabled ? MaterialStatePropertyAll<Color>(Colors.greenAccent)
                          : MaterialStatePropertyAll<Color>(Colors.blueAccent),
                      // surfaceTintColor: _isDarkModeEnabled ? MaterialStatePropertyAll<Color>(Colors.greenAccent)
                      //     : MaterialStatePropertyAll<Color>(Colors.blueAccent),
                      animationDuration: Duration(milliseconds: 300),
                      // iconColor:
                    ),
                    onChanged: (value){
                      setState(() {
                        _isUsingWOTS = !_isUsingWOTS;
                      });

                      _logManager.logger.d("_isUsingWOTS: $_isUsingWOTS");
                    },
                    child: Text(
                      "Use WOTS Signing",
                      style: TextStyle(
                        color: _isDarkModeEnabled ? Colors.white : Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Spacer(),
                  Padding(
                    padding: EdgeInsets.all(8), child: Text(
                    "signature: $_wotsSigningCounter",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                  ),),
                  Spacer(),
                ],),
              ),

              Visibility(
                visible: _isDecrypting,
                child:  Divider(
                  color: _isDarkModeEnabled ? Colors.greenAccent : null,
                ),
              ),
              Visibility(
                visible: _isDecrypting,
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Spacer(),
                      Icon(
                        _didDecryptSuccessfully ? Icons.security : Icons.security_update_warning,
                          color: _isDarkModeEnabled
                              ? (_fieldsAreValid && _didDecryptSuccessfully
                              ? Colors.greenAccent
                              : Colors.redAccent)
                              : (_fieldsAreValid && _didDecryptSuccessfully
                              ? Colors.blueAccent
                              : Colors.redAccent),
                          size: 30.0,
                      ),
                      Spacer(),
                      Text(
                        _didDecryptSuccessfully ? 'Decrypted Successfully' : "Decrypt Failure",
                          style: TextStyle(
                            fontSize: 16.0,
                            color: _isDarkModeEnabled
                                ? (_fieldsAreValid ? Colors.white : Colors.grey)
                                : (_fieldsAreValid ? Colors.black : Colors.grey),
                          ),
                        ),
                      Spacer(),
                    ],
                  ),
                ),
              ),
              Divider(
                  color: _isDarkModeEnabled ? Colors.greenAccent : null,
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: _fieldsAreValid
                          ? () async {
                        await Clipboard.setData(ClipboardData(
                            text: _messageTextController.text));

                        _settingsManager.setDidCopyToClipboard(true);

                        EasyLoading.showToast('Copied',
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
                        'Copy Message',
                        style: TextStyle(
                          fontSize: 16.0,
                          color: _isDarkModeEnabled
                              ? (_fieldsAreValid ? Colors.white : Colors.grey)
                              : (_fieldsAreValid ? Colors.black : Colors.grey),
                        ),
                      ),
                      onPressed: _fieldsAreValid
                          ? () async {
                        await Clipboard.setData(ClipboardData(
                            text: _messageTextController.text));

                        _settingsManager.setDidCopyToClipboard(true);

                        EasyLoading.showToast('Copied',
                            duration: Duration(milliseconds: 500));
                      } : null,
                    ),
                    Spacer(),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _messageTextController.text = "";
                        });
                        _validateFields();

                      },
                      icon: Icon(
                        Icons.highlight_remove_sharp,
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
                        'Clear',
                        style: TextStyle(
                          fontSize: 16.0,
                          color: _isDarkModeEnabled
                              ? (_fieldsAreValid ? Colors.white : Colors.grey)
                              : (_fieldsAreValid ? Colors.black : Colors.grey),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _messageTextController.text = "";
                        });
                        _validateFields();
                      },
                    ),
                    Spacer(),
                  ],
                ),
              ),

              Row(children: [
                SizedBox(width: 8,),
              IconButton(
                onPressed: () async {
                  Clipboard.getData("text/plain").then((value) {
                    final data = value?.text;
                    if (data != null) {

                      /// we want to append to any data already in the field
                      setState(() {
                        _messageTextController.text = _messageTextController.text + data.trim();
                      });

                      _validateFields();
                    }
                  });
                },
                icon: Icon(
                  Icons.paste,
                  color: _isDarkModeEnabled
                      ? Colors.greenAccent
                      : Colors.blueAccent,
                  size: 30.0,
                ),
              ),
              TextButton(
                child: Text(
                  'Paste From Clipboard',
                  maxLines: 3,
                  style: TextStyle(

                    fontSize: 16.0,
                    color: _isDarkModeEnabled
                        ? Colors.white : Colors.black,
                  ),
                ),
                onPressed: () async {
                  Clipboard.getData("text/plain").then((value) {
                    final data = value?.text;
                    if (data != null) {
                      /// we want to append to any data already in the field
                      setState(() {
                        _messageTextController.text = _messageTextController.text + data.trim();
                      });

                      _validateFields();
                    }
                  });
                },
              ),
              Spacer(),
              ],),
              Visibility(
                visible: false,
                child:  Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: _fieldsAreValid
                            ? () async {

                          EasyLoading.showToast('Message Saved',
                              duration: Duration(milliseconds: 500));
                        }
                            : null,
                        icon: Icon(
                          Icons.save,
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
                          'Save Encrypted Message',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: _isDarkModeEnabled
                                ? (_fieldsAreValid ? Colors.white : Colors.grey)
                                : (_fieldsAreValid ? Colors.black : Colors.grey),
                          ),
                        ),
                        onPressed: _fieldsAreValid
                            ? () async {
                          /// TODO: save verified encrypted message in history/chain
                          /// after it has been verified
                          ///

                          EasyLoading.showToast('Message Saved',
                              duration: Duration(milliseconds: 500));
                        } : null,
                      ),

                    ],
                  ),
                ),
              ),
              Visibility(
                visible: false,
                child:  Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: _fieldsAreValid
                            ? () async {

                          /// TODO: save verified encrypted message in history/chain
                          /// after it has been verified
                          ///


                          EasyLoading.showToast('Decrypted Message Saved',
                              duration: Duration(milliseconds: 500));
                        }
                            : null,
                        icon: Icon(
                          Icons.save,
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
                          'Save Decrypted Message',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: _isDarkModeEnabled
                                ? (_fieldsAreValid ? Colors.white : Colors.grey)
                                : (_fieldsAreValid ? Colors.black : Colors.grey),
                          ),
                        ),
                        onPressed: _fieldsAreValid
                            ? () async {
                          EasyLoading.showToast('Message Saved',
                              duration: Duration(milliseconds: 500));
                        } : null,
                      ),
                      Spacer(),
                    ],
                  ),
                ),
              ),

              Row(children: [
                Spacer(),
                IconButton(
                  onPressed: ((_didEncrypt && _showShareMessageAsQRCode) || (!_didEncrypt && _hasEmbeddedMessageObject))
                      ? () async {
                    /// Show Message QR Code
                    /// can only hold ~2KB
                    await _pressedShareEncryptedMessage();
                  }
                      : null,
                  icon: Icon(
                    Icons.qr_code,
                    color: _isDarkModeEnabled
                        ? (((_didEncrypt && _showShareMessageAsQRCode) || (!_didEncrypt && _hasEmbeddedMessageObject))
                        ? Colors.greenAccent
                        : Colors.grey)
                        : (((_didEncrypt && _showShareMessageAsQRCode) || (!_didEncrypt && _hasEmbeddedMessageObject))
                        ? Colors.blueAccent
                        : Colors.grey),
                    size: 30.0,
                  ),
                ),
                TextButton(
                  child: Text(
                    'Show Message Code',
                    style: TextStyle(
                      fontSize: 16.0,
                      color: _isDarkModeEnabled
                          ? (((_didEncrypt && _showShareMessageAsQRCode) || (!_didEncrypt && _hasEmbeddedMessageObject))? Colors.white : Colors.grey)
                          : (((_didEncrypt && _showShareMessageAsQRCode) || (!_didEncrypt && _hasEmbeddedMessageObject)) ? Colors.black : Colors.grey),
                    ),
                  ),
                  onPressed: ((_didEncrypt && _showShareMessageAsQRCode) || (!_didEncrypt && _hasEmbeddedMessageObject))
                      ? () async {
                    /// Show Message QR Code
                    /// can only hold ~2KB
                    await _pressedShareEncryptedMessage();
                  } : null,
                ),
                Spacer(),
              ],
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
    final message = _messageTextController.text;

    if (message.isEmpty) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    if (_seedKey.isEmpty && widget.keyItem == null) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    if ((_Kenc.isEmpty || _Kenc.isEmpty) && widget.keyItem != null) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    setState(() {
      _fieldsAreValid = true;
    });
  }


  _pressedShareEncryptedMessage() {

    if (_qrMessageItem == null) {
      _logManager.logger.e("QR item empty 1");
      return;
    }

    final qrItemString = _qrMessageItem?.toRawJson();

    if (qrItemString == null) {
      _logManager.logger.e("QR item empty 2");
      return;
    }

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

  /// Encrypt our message...
  /// limit is 864 characters to fit within a shareable encrypted QR Code
  /// we could compact this more if we agreed upon a standard format without JSON
  /// or a JSON object with one param with keyId and message concatenated
  void _encryptMessage() async {
    final messageVersionNumber = 1;
    final message = _messageTextController.text;

    if (message == null) {
      return;
    }

    if (message.isEmpty) {
     return;
    }

    // print("message length: ${message.length}");
    /// TODO: need to encrypt with shared secret key
    ///
    final encryptedMessage = await _cryptor.encryptWithKey(_Kenc_send, _Kauth_send, message);
    final encryptedBlobBytes = base64.decode(encryptedMessage);

    final iv = encryptedBlobBytes.sublist(0,16);
    final mac = encryptedBlobBytes.sublist(16,48);
    final blob = encryptedBlobBytes.sublist(48,encryptedBlobBytes.length);

    _logManager.logger.d("iv: ${hex.encode(iv)}\nmac: ${hex.encode(mac)}\nblob: ${hex.encode(blob)}");
    // _logManager.logger.d("mac: ${hex.encode(mac)}");
    // _logManager.logger.d("blob: ${hex.encode(blob)}");

    final toAddr = _cryptor.sha256(hex.encode(_peerPublicKey)).substring(0, 40);
    final fromAddr = _cryptor.sha256(hex.encode(_mainPublicKey)).substring(0,40);

    // final appendedMessage = "to:" + toAddr + ":" + encryptedMessage;

    final timestamp = DateTime.now().toIso8601String();

    EncryptedPeerMessage message_send_plain = EncryptedPeerMessage(
      version: messageVersionNumber,
      from: fromAddr,
      to: toAddr,
      message: encryptedMessage,
      time: timestamp,
      jmac: "",
    );

    final msg_hash = _cryptor.sha256(message_send_plain.toRawJson());
    final msgHashKey = SecretKey(hex.decode(msg_hash));

    final hmac = Hmac.sha256();
    final mac_msg = await hmac.calculateMac(
      _Kauth_send,
      secretKey: msgHashKey!,
    );


    EncryptedPeerMessage message_send_mac = EncryptedPeerMessage(
      version: messageVersionNumber,
      from: fromAddr,
      to: toAddr,
      message: encryptedMessage,
      time: timestamp,
      jmac: base64.encode(mac_msg.bytes),
    );

    /// TODO: get kek, lastBlockHash, thisSigatureIndex, and msgObject
    // final msg = BasicMessageData(
    //     time: timestamp,
    //     message: message_send_mac.toRawJson(),
    //     signature: "",
    // );

    final msgObject = WOTSMessageData(
      messageIndex: _wotsSigningCounter,
      previousHash: _wotsManager.lastBlockHash,
      publicKey: _wotsManager.topPublicKey,
      nextPublicKey: _wotsManager.nextTopPublicKey,
      time: timestamp,
      data: message_send_mac.toRawJson(),
    );

    GigaWOTSSignatureItem? wotsSignature1 = GigaWOTSSignatureItem(
      id: "",
      signature:[],
      checksum: "",
      message: msgObject,
    );

    if (_isUsingWOTS && _debugTestWots) {
      _wotsSigningCounter++;
      // final kek = List.filled(32, 0);

      wotsSignature1 = await _wotsManager.signGigaWotMessage(
          _Kwots_send,
          "main",
          "lastBlockHash",
          _wotsSigningCounter,
          msgObject,
      );

      _logManager.logger.d("wotsSignature1: ${wotsSignature1?.toRawJson()}");
    }


    setState(() {
      _didEncrypt = true;
      _didDecryptSuccessfully = false;
      // if (_isUsingWOTS && wotsSignature1 != null) {
      //   _messageTextController.text = wotsSignature1.toRawJson();
      // } else {
      //   _messageTextController.text = message_send_mac.toRawJson();
      // }

      _messageTextController.text = message_send_mac.toRawJson();
    });

    if (_isUsingWOTS && wotsSignature1 != null) {
      _qrMessageItem = QRCodeEncryptedMessageItem(
        keyId: base64.encode(hex.decode(toAddr)),
        message: wotsSignature1!.toRawJson(),
      );
    } else {
      _qrMessageItem = QRCodeEncryptedMessageItem(
        keyId: base64.encode(hex.decode(toAddr)),
        message: message_send_mac.toRawJson(),
      );
    }

    final qrItemString = _qrMessageItem?.toRawJson();
    if (qrItemString != null && !_isUsingWOTS) {
      // _logManager.logger.d("qrItemString length: ${qrItemString.length}");

      /// limit ability to show code for messages within code limit
      if (qrItemString.length >= 1286) {
        setState((){
          _showShareMessageAsQRCode = false;
        });
        _logManager.logger.wtf("too much data");
        _showErrorDialog("Too much data for QR code.\n\nLimit is 1286 bytes.");
      } else {
        setState((){
          _showShareMessageAsQRCode = true;
        });
      }
    } else {
      setState((){
        _showShareMessageAsQRCode = false;
      });
    }

  }

  void _decryptMessage() async {
    final message = _messageTextController.text.trim();

    EncryptedPeerMessage messageItem;
    try {
      /// decode this into an EncryptedPeerMessage object
      messageItem = EncryptedPeerMessage.fromRawJson(message);
    } catch (e) {
      _logManager.logger.e("Exception: decrypt: $e");
      setState(() {
        _didEncrypt = false;
        _didDecryptSuccessfully = false;
        _hasEmbeddedMessageObject = false;
      });
      return;
    }

    if (messageItem == null) {
      setState(() {
        _didEncrypt = false;
        _didDecryptSuccessfully = false;
        _hasEmbeddedMessageObject = false;
      });
      return;
    }

    if (messageItem.message.isEmpty) {
      setState(() {
        _didEncrypt = false;
        _didDecryptSuccessfully = false;
        _hasEmbeddedMessageObject = false;
      });
      return;
    }

    /// check against the from and to address
    final toAddr = _cryptor.sha256(base64.encode(_peerPublicKey)).substring(0, 40);
    final fromAddr = _cryptor.sha256(base64.encode(_mainPublicKey)).substring(0,40);

    final messageFromAddr = messageItem.from;
    final messageToAddr = messageItem.to;

    final jmac_msg_bytes = base64.decode(messageItem.jmac);

    var Kuse_e = _Kenc_send;
    var Kuse_a = _Kauth_send;

    if (messageToAddr == fromAddr) {
      Kuse_e = _Kenc_rec;
      Kuse_a = _Kauth_rec;
    } else if (messageToAddr == toAddr) {
      Kuse_e = _Kenc_send;
      Kuse_a = _Kauth_send;
    }

    /// check the jmac
    ///
    final check_received_message = EncryptedPeerMessage(
        version: messageItem.version,
        from: messageItem.from,
        to: messageItem.to,
        message: messageItem.message,
        time: messageItem.time,
        jmac: "",
    );

    final msg_rec_hash = _cryptor.sha256(check_received_message.toRawJson());
    // print("msg_rec_hash: ${msg_rec_hash}");

    final msgRecHashKey = SecretKey(hex.decode(msg_rec_hash));

    final hmac = Hmac.sha256();
    final mac_rec_msg = await hmac.calculateMac(
      Kuse_a,
      secretKey: msgRecHashKey!,
    );
    // print("mac_rec_msg: ${base64.encode(mac_rec_msg.bytes)}");

    if (messageItem.jmac != base64.encode(mac_rec_msg.bytes)) {
      setState(() {
        _hasEmbeddedMessageObject = false;
        _didEncrypt = false;
        _didDecryptSuccessfully = false;
      });
      _logManager.logger.w("JMACs DO NOT Equal!!");
      return;
    }

    // print("mac_rec_msg: ${mac_rec_msg}");



    /// need to decrypt with shared secret key
    final decryptedMessage = await _cryptor.decryptWithKey(Kuse_e, Kuse_a, messageItem.message);

    if (decryptedMessage == null) {
      setState(() {
        _didEncrypt = false;
        _hasEmbeddedMessageObject = false;
        _didDecryptSuccessfully = false;
      });
      return;
    }

    if (decryptedMessage.isEmpty) {
      setState(() {
        _didEncrypt = false;
        _hasEmbeddedMessageObject = false;
        _didDecryptSuccessfully = false;
      });
      return;
    }


    setState(() {
      _didEncrypt = false;
      _didDecryptSuccessfully = true;
      // _hasEmbeddedMessageObject = false;
      _messageTextController.text = decryptedMessage;
   });


    _qrMessageItem = QRCodeEncryptedMessageItem(
        keyId: base64.encode(hex.decode(toAddr)),
        message: decryptedMessage,
    );


    final qrItemString = _qrMessageItem?.toRawJson();
    if (qrItemString != null) {
      _logManager.logger.d("qrItemString length: ${qrItemString.length}");

      /// limit ability to show code for messages within code limit
      if (qrItemString.length >= 1286) {
        setState((){
          _showShareMessageAsQRCode = false;
        });
        // print("too much data");
        // _showErrorDialog("Too much data for QR code.\n\nLimit is 1286 bytes.");
      } else {
        setState((){
          _showShareMessageAsQRCode = true;
        });
      }
    } else {
      setState((){
        _showShareMessageAsQRCode = false;
      });
    }

    try {
      /// decode this into an EncryptedPeerMessage object
      var embeddedItem = EncryptedPeerMessage.fromRawJson(decryptedMessage);
      if (embeddedItem == null) {
        setState((){
          _hasEmbeddedMessageObject = false;
          _showShareMessageAsQRCode = false;
        });
      } else {
        setState((){
          _hasEmbeddedMessageObject = true;
          _showShareMessageAsQRCode = true;
        });
      }
    } catch (e) {
      _logManager.logger.e("Exception: Decrypt: ${e}");
      setState((){
        _hasEmbeddedMessageObject = false;
        _showShareMessageAsQRCode = false;
      });
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

