import 'dart:io';
import 'dart:async';
import 'dart:convert';

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
import '../managers/WOTSManager.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/KeychainManager.dart';
import '../managers/Cryptor.dart';
import '../models/WOTSSignatureItem.dart';
import '../widgets/qr_code_view.dart';
import 'home_tab_screen.dart';


/// This is where encryption and decryption of messages with a set key takes place
class ActiveEncryptionScreen extends StatefulWidget {
  const ActiveEncryptionScreen({
    Key? key,
    required this.peerId,
    KeyItem? this.keyItem,
  }) : super(key: key);
  static const routeName = '/active_encryption_key_screen';

  final String peerId;
  final KeyItem? keyItem;

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

  String _lastBlockHash = "";

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
  int _wotsSigningCounter = 1;

  String _lastRecievedHashState = "";
  String _lastSentHashState = "";


  KeyItem? _keyItem;
  PeerPublicKey? _peerKey;

  GenericMessageList? _sentMessages;
  GenericMessageList? _receivedMessages;

  QRCodeEncryptedMessageItem? _qrMessageItem;

  final algorithm_exchange = X25519();

  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _keyManager = KeychainManager();
  final _cryptor = Cryptor();
  final _wotsManager = WOTSManager();


  @override
  void initState() {
    super.initState();

    _logManager.log("ActiveEncryptionScreen", "initState", "initState");

    _wotsManager.reset();

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;
    _selectedIndex = _settingsManager.currentTabIndex;

    /// read key info from keychain
    _getItem().then((value) {
      _keyItem = widget.keyItem;
      _sentMessages = _keyItem?.peerPublicKeys.first.sentMessages;
      _receivedMessages = _keyItem?.peerPublicKeys.first.receivedMessages;
      if (_keyItem!.peerPublicKeys.first.sentMessages!.list.isNotEmpty) {
        _isUsingWOTS =
        (_keyItem?.peerPublicKeys.first.sentMessages?.list.first.type ==
            MessageType.wotsEncryptedMesh.name);
      }

      _logManager.logger.wtf("_sentMessages: ${_sentMessages?.toJson()}");
      _logManager.logger.wtf("_receivedMessages: ${_receivedMessages?.toJson()}");

      if (_sentMessages!.list.length > 0) {
        _lastBlockHash = _cryptor.sha256(_sentMessages!.list.last.toRawJson());
      }
      _logManager.logger.wtf("_lastBlockHash: ${_lastBlockHash}");


      _validateFields();
    });

  }

  Future<void> _getItem() async {

    // if (widget.keyItem == null) {
    //   _isRootSymmetric = true;
    //   /// get the password item and decrypt the data
    //   final item = await _keyManager.getItem(widget.peerId);
    //   final genericItem = GenericItem.fromRawJson(item);
    //   if (genericItem.type == "key") {
    //     /// must be a PasswordItem type
    //     _keyItem = KeyItem.fromRawJson(genericItem.data);
    //
    //     if (_keyItem != null) {
    //       var keydata = (_keyItem?.keys)!;
    //
    //       if (keydata == null) {
    //         return;
    //       }
    //
    //       try {
    //         if (keydata.privX == null) {
    //           _logManager.logger.wtf("keydata.privX == null");
    //           return;
    //         }
    //
    //         if (keydata.privS == null) {
    //           _logManager.logger.wtf("keydata.privS == null");
    //           return;
    //         }
    //
    //         if (keydata.privK == null) {
    //           _logManager.logger.wtf("keydata.privK == null");
    //           return;
    //         }
    //
    //         final decrypedPrivX = await _cryptor.decryptReturnData(
    //             keydata.privX!);
    //         _logManager.logger.wtf("decrypedPrivX: ${decrypedPrivX}");
    //
    //         final decrypedPrivS = await _cryptor.decryptReturnData(
    //             keydata.privS!);
    //         _logManager.logger.wtf("decrypedPrivS: ${decrypedPrivS}");
    //
    //         final decrypedPrivK = await _cryptor.decryptReturnData(
    //             keydata.privK!);
    //         _logManager.logger.wtf("decrypedPrivK: ${decrypedPrivK}");
    //
    //
    //         var decodedSeedData = decrypedPrivX;
    //         if (_keyItem?.keyType == "sym") {
    //           decodedSeedData = base64.decode(utf8.decode(decrypedPrivX));
    //         }
    //
    //
    //         _seedKey = decodedSeedData;
    //         _logManager.logger.d("_seedKey: ${hex.encode(_seedKey)}");
    //
    //         final expanded = await _cryptor.expandKey(_seedKey);
    //         if (AppConstants.debugKeyData) {
    //           _logManager.logger.d("decrypedSeedData: ${decrypedPrivX
    //               .length}: $decrypedPrivX");
    //           _logManager.logger.d("decodedSeedData: ${decodedSeedData
    //               .length}: $decodedSeedData");
    //           _logManager.logger.d("expanded: ${expanded.length}: $expanded");
    //         }
    //
    //
    //         setState(() {
    //           _Kenc = expanded.sublist(0, 32);
    //           _Kauth = expanded.sublist(32, 64);
    //         });
    //
    //         var name = (_keyItem?.name)!;
    //
    //         _logManager.logger.d("_Kenc: ${hex.encode(_Kenc)}\n"
    //             "_Kauth: ${hex.encode(_Kauth)}");
    //
    //         _cryptor.decrypt(name).then((value) {
    //           name = value;
    //
    //           _validateFields();
    //         });
    //
    //         _Kwots = _cryptor.aesGenKeyBytes;
    //         if (_Kwots != null && _Kwots.isNotEmpty) {
    //           _logManager.logger.d("got a wots key: ${hex.encode(_Kwots)}");
    //         }
    //       } catch (e) {
    //         _logManager.logger.wtf("exception: $e");
    //       }
    //     }
    //   }
    // } else {
    if (widget.keyItem != null) {
      _isRootSymmetric = false;

      try {
        var keydata = (widget.keyItem?.keys)!;
        if (keydata == null) {
          return;
        }

        var keyName = (widget.keyItem?.name)!;
        final decryptedName = await _cryptor.decrypt(keyName);

        // var version = widget.keyItem?.version;
        var peerIndex = 0;
        for (var peerKey in widget.keyItem!.peerPublicKeys) {
          if (peerKey.id == widget.peerId) {
            break;
          }
          peerIndex++;
        }

        // if (_sentMessages != null) {

          _isUsingWOTS = (_keyItem?.peerPublicKeys[peerIndex].sentMessages?.list.first.type == MessageType.wotsEncryptedMesh.name);
        // }
        _logManager.logger.d("${_isUsingWOTS}");
        // _logManager.logger.d("${_keyItem?.peerPublicKeys[peerIndex].receivedMessages?.list}");

        setState(() {
          _sentMessages = _keyItem?.peerPublicKeys[peerIndex].sentMessages;
          if (_sentMessages != null) {
            if (_sentMessages!.list.length > 0) {
              _wotsSigningCounter = (_sentMessages!.list.length + 1)!;
            }
          }
          _receivedMessages = _keyItem?.peerPublicKeys[peerIndex].receivedMessages;
          _mainKeyName = decryptedName;
        });

        if (_sentMessages != null) {
          if (_sentMessages!.list.length > 0) {
            _lastBlockHash =
                _cryptor.sha256(_sentMessages!.list.last.toRawJson());
          }
        }

        // (_receivedMessages.first.list);

        // _validateFields();

        var peerPublicKeys = (widget.keyItem?.peerPublicKeys)!;

        for (var peerKey in peerPublicKeys) {
          if (peerKey.id == widget.peerId) {
            var keyIndex = 0;
            // if (peerKey.version != null) {
            //   version = (peerKey?.version)!;
            // }
            final decryptedPeerPublicKey = await _cryptor.decrypt(
                peerKey.pubKeyX);
            // _peerPublicKey = base64.decode(decryptedPeerPublicKey);

            final decryptedPeerName = await _cryptor.decrypt(peerKey.name);
            // _peerKeyName = decryptedPeerName;
            setState(() {
              _peerPublicKey = base64.decode(decryptedPeerPublicKey);
              _peerKeyName = decryptedPeerName;
            });

            _peerKey = peerKey;
            break;
          }
        }

        if (keydata.privX == null) {
          _logManager.logger.wtf("keydata.privX == null");

          return;
        }

        if (keydata.privS == null) {
          _logManager.logger.wtf("keydata.privS == null");

          return;
        }

        if (keydata.privK == null) {
          _logManager.logger.wtf("keydata.privK == null");
          return;
        }

        /// TODO: set seedKey and encryption/auth keys
        // final decrypedSeedData = await _cryptor.decrypt(keydata);
        final decrypedPrivX = await _cryptor.decrypt(keydata.privX!);
        // _logManager.logger.wtf("decrypedPrivX: ${decrypedPrivX}");

        final decrypedPrivS = await _cryptor.decrypt(
            keydata.privS!);
        // _logManager.logger.wtf("decrypedPrivS: ${decrypedPrivS}");

        final decrypedPrivK = await _cryptor.decrypt(
            keydata.privK!);
        // _logManager.logger.wtf("decrypedPrivK: ${decrypedPrivK}");

        // setState(() {
          _mainPrivateKey = base64.decode(decrypedPrivX);
        // });
      } catch (e) {
        _logManager.logger.e("exception: ${e}");
      }

      await _generatePeerKeyPair();

      _validateFields();
    }

  }

  Future<void> _generatePeerKeyPair() async {
    if (_mainPrivateKey == null || _mainPrivateKey.isEmpty || _peerPublicKey == null || _peerPublicKey.isEmpty) {
      return;
    }

    final ownerKeyPair = await algorithm_exchange.newKeyPairFromSeed(_mainPrivateKey);


    // final privKey = await ownerKeyPair.extractPrivateKeyBytes();
    // print("privKeyBytes: ${privKey.length}: ${privKey}");

    final mainPublicKey = await ownerKeyPair.extractPublicKey();
    _mainPublicKey = mainPublicKey.bytes;
    // print("_mainPublicKeyHex: ${_mainPublicKey.length}: ${hex.encode(_mainPublicKey)}");

    // final bobPub = hex.decode(bobPubString);
    final bobPub = _peerPublicKey;
    // print('peer Public Key hex: ${hex.encode(bobPub)}');

    final bobPublicKey = SimplePublicKey(bobPub, type: KeyPairType.x25519);
    final bobPubKeyBytes = bobPublicKey.bytes;

    final sharedSecret = await algorithm_exchange.sharedSecretKey(
      keyPair: ownerKeyPair,
      remotePublicKey: bobPublicKey,
    );

    final sharedSecretBytes = await sharedSecret.extractBytes();
    // _logManager.logger.d('Shared secret hex: ${hex.encode(sharedSecretBytes)}');

    // final sharedSecretKeyHash = await _cryptor.sha256(hex.encode(sharedSecretBytes));
    // _logManager.logger.dnt("shared secret key hash: ${sharedSecretKeyHash}");

    final expanded = await _cryptor.expandKey(sharedSecretBytes);
    // _logManager.logger.d('Shared secret expanded: $expanded');
    _Kenc = expanded.sublist(0, 32);
    _Kauth = expanded.sublist(32, 64);
    // _logManager.logger.d('secret _Kenc: ${hex.encode(_Kenc)}');
    // _logManager.logger.d('secret _Kauth: ${hex.encode(_Kauth)}');

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
      backgroundColor: _isDarkModeEnabled ? (Platform.isAndroid ? (AppConstants.useMaterial3 ? Colors.black12 : Colors.black54) : (AppConstants.useMaterial3 ? Colors.black26 : Colors.black54)) : Colors.blue[50],//Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Message Encryption",
          style: TextStyle(
            color: _isDarkModeEnabled ? Colors.white : Colors.black,
          ),
        ),
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
                  padding: EdgeInsets.all(8.0),
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
              //   "${_fromAddr} ",
                "Address:\n${_fromAddr} ", //"${hex.encode(_mainPublicKey).substring(0, (_mainPublicKey.length/2).toInt())}...",
                textAlign: TextAlign.center,
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
                  "Address:\n${_toAddr} ", //"${hex.encode(_mainPublicKey).substring(0, (_mainPublicKey.length/2).toInt())}...",
                  textAlign: TextAlign.center,
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
                          maxLines: 8,
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
                  onPressed: _fieldsAreValid ? () async {
                    setState((){
                      _isDecrypting = false;
                    });

                    await _encryptMessage();
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
                  onPressed: _fieldsAreValid ? () async {
                    setState((){
                      _isDecrypting = true;
                    });

                    await _decryptMessage();
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
                  // Padding(
                  //   padding: EdgeInsets.all(8), child: Text(
                  //   "signature: $_wotsSigningCounter",
                  //   style: TextStyle(
                  //     color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  //     fontSize: 16,
                  //   ),
                  // ),),
                  // Spacer(),
                ],),
              ),
              Visibility(
                visible: _debugTestWots,
                child: Padding(
                    padding: EdgeInsets.all(8), child: Text(
                    "signature: $_wotsSigningCounter",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
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
                          _sentMessages?.list = [];
                          _receivedMessages?.list = [];
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

                          // _pressedShareEncryptedMessage();

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

                          // _pressedShareEncryptedMessage();

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
                      ? () {
                    /// Show Message QR Code
                    /// can only hold ~2KB
                    _pressedShareEncryptedMessage();
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
                      ? () {
                    /// Show Message QR Code
                    /// can only hold ~2KB
                    _pressedShareEncryptedMessage();
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
        currentIndex: _selectedIndex,
        selectedItemColor:
        _isDarkModeEnabled ? Colors.white : Colors.white,
        unselectedItemColor: Colors.green,
        unselectedIconTheme: IconThemeData(color: Colors.greenAccent),
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(
              Icons.star,
              color: Colors.grey,
            ),
            label: 'Favorites',
            backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
            activeIcon: Icon(
              Icons.star,
              color:
              _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
            ),
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.category,
              color: Colors.grey,
            ),
            label: 'Categories',
            backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
            activeIcon: Icon(
              Icons.category,
              color:
              _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
            ),
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.discount,
              color: Colors.grey,
            ),
            label: 'Tags',
            backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
            activeIcon: Icon(
              Icons.discount,
              color:
              _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
            ),
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.settings,
              color: Colors.grey,
            ),
            label: 'Settings',
            backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
            activeIcon: Icon(
              Icons.settings,
              color:
              _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
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


  void _pressedShareEncryptedMessage() {
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => CameraScreen(cameras: _cameras,),
    //   ),
    // );
    //
    // return;

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
  Future<void> _encryptMessage() async {
    var messageVersionNumber = 1;

    if (_sentMessages != null) {
       messageVersionNumber = _sentMessages!.list.length + 1;
    }
    final message = _messageTextController.text;

    if (message == null) {
      return;
    }

    if (message.isEmpty) {
     return;
    }

    /// TODO: need to encrypt with shared secret key
    ///
    final encryptedMessage = await _cryptor.encryptWithKey(_Kenc_send, _Kauth_send, message);
    final encryptedBlobBytes = base64.decode(encryptedMessage);

    // final secMessage = SecureMessage(version: "test-v1", data: encryptedMessage);
    // _sentMessages?.list.add(secMessage);
    // _logManager.logger.e("_sentMessage: ${secMessage.toJson()}");


    final iv = encryptedBlobBytes.sublist(0,16);
    final mac = encryptedBlobBytes.sublist(16,48);
    final blob = encryptedBlobBytes.sublist(48,encryptedBlobBytes.length);
    _logManager.logger.d("iv: ${hex.encode(iv)}\nmac: ${hex.encode(mac)}\nblob: ${hex.encode(blob)}");

    final toAddr = _cryptor.sha256(hex.encode(_peerPublicKey)).substring(0, 40);
    final fromAddr = _cryptor.sha256(hex.encode(_mainPublicKey)).substring(0, 40);

    final timestamp = DateTime.now().toIso8601String();

    // EncryptedPeerMessage epm = EncryptedPeerMessage(
    //     index: messageVersionNumber,
    //     from: fromAddr,
    //     to: toAddr,
    //     message: encryptedMessage,
    //     time: DateTime.now().toIso8601String(),
    //     mac: "",
    // );

    var recieverState;
    if (_receivedMessages!.list!.isNotEmpty) {
      recieverState = _cryptor.sha256(_receivedMessages?.list.last.toRawJson());
    }

    var sentState;
    if (_sentMessages!.list!.isNotEmpty) {
      sentState = _cryptor.sha256(_sentMessages?.list!.last.toRawJson());
      _wotsSigningCounter = _sentMessages!.list.length + 1;
    }

    EncryptedMeshPeerMessage messageToSend = EncryptedMeshPeerMessage(
      index: messageVersionNumber,
      sstate: sentState ?? "",
      rstate: recieverState ?? "",
      from: fromAddr,
      to: toAddr,
      message: encryptedMessage,
      time: timestamp,
      mac: "",
    );

    GenericPeerMessage genericMessage = GenericPeerMessage(
      type: MessageType.encryptedMesh.name,
      data: messageToSend.toRawJson(),
    );

    // _lastRecievedHashState = hex.decode(msg_hashv1);
    _lastSentHashState = _cryptor.sha256(genericMessage.toRawJson());

    final msgHashKeyv1 = SecretKey(hex.decode(_lastSentHashState));

    // final msg_hash = _cryptor.sha256(message_send_plain.toRawJson());
    // final msgHashKey = SecretKey(hex.decode(msg_hash));

    final hmac = Hmac.sha256();
    final mac_msg = await hmac.calculateMac(
      _Kauth_send,
      secretKey: msgHashKeyv1!,
    );

    messageToSend.mac = base64.encode(mac_msg.bytes);
    // message_send_mac.mac = base64.encode(mac_msg.bytes);

    GenericPeerMessage updateGenericMessage = GenericPeerMessage(
      type: MessageType.encryptedMesh.name,
      data: messageToSend.toRawJson(),
    );

    /// add message to our list
    // _sentMessages?.list.add(updateGenericMessage);

    EncryptedWotsMeshPeerMessage messageToSendWots = EncryptedWotsMeshPeerMessage(
      index: messageVersionNumber,
      // sstate: sentState ?? "",
      rstate: recieverState ?? "",
      from: fromAddr,
      to: toAddr,
      message: encryptedMessage,
      time: timestamp,
      mac: "",
    );

    GenericPeerMessage genericMessageWots = GenericPeerMessage(
      type: MessageType.wotsEncryptedMesh.name,
      data: messageToSendWots.toRawJson(),
    );

    // _lastRecievedHashState = hex.decode(msg_hashv1);
    final wotsMsgHash = _cryptor.sha256(genericMessageWots.toRawJson());

    final wotsMsgHashKey = SecretKey(hex.decode(wotsMsgHash));

    // final msg_hash = _cryptor.sha256(message_send_plain.toRawJson());
    // final msgHashKey = SecretKey(hex.decode(msg_hash));

    // final hmac = Hmac.sha256();
    final mac_msg_wots = await hmac.calculateMac(
      _Kauth_send,
      secretKey: wotsMsgHashKey!,
    );

    messageToSendWots.mac = base64.encode(mac_msg_wots.bytes);


    final msgObject = WOTSMessageData(
      messageIndex: _wotsSigningCounter,
      previousHash: _lastBlockHash,
      publicKey: _wotsManager.topPublicKey,
      nextPublicKey: _wotsManager.nextTopPublicKey,
      data: messageToSendWots.toRawJson(),
    );

    _lastBlockHash = _lastSentHashState;

    GigaWOTSSignatureItem? wotsSignature1 = GigaWOTSSignatureItem(
      id: "",
      recovery: "",
      signature:[],
      checksum: "",
      message: msgObject,
    );

    if (_isUsingWOTS && _debugTestWots) {
      _wotsSigningCounter++;

      // updateGenericMessage = GenericPeerMessage(
      //   type: MessageType.wotsEncryptedMesh.name,
      //   data: messageToSend.toRawJson(),
      // );

      wotsSignature1 = await _wotsManager.signGigaWotMessage(
          _Kwots_send,
          "main",
          _wotsManager.lastBlockHash,
          msgObject,
          256,
          false,
      );

      updateGenericMessage = GenericPeerMessage(
        type: MessageType.wotsEncryptedMesh.name,
        data: wotsSignature1!.toRawJson(),
      );

      setState(() {
        _sentMessages?.list.add(updateGenericMessage);
      });

      await _saveEncryptedMessage();

      // _logManager.logger.d("wotsSignature1: ${wotsSignature1?.toRawJson()}");
      _logManager.logLongMessage("wotsSignature1: ${wotsSignature1?.toRawJson()}");
    } else {

      setState(() {
        _sentMessages?.list.add(updateGenericMessage);
      });

      await _saveEncryptedMessage();
    }

    setState(() {
      _didEncrypt = true;
      _didDecryptSuccessfully = false;

      _messageTextController.text = genericMessage.toRawJson();
      // _messageTextController.text = updateGenericMessage.toRawJson();
    });

    if (_isUsingWOTS && wotsSignature1 != null) {
      _qrMessageItem = QRCodeEncryptedMessageItem(
        keyId: base64.encode(hex.decode(toAddr)),
        message: wotsSignature1!.toRawJson(),
      );

      _messageTextController.text = updateGenericMessage.toRawJson();

    } else {
      _qrMessageItem = QRCodeEncryptedMessageItem(
        keyId: base64.encode(hex.decode(toAddr)),
        message: messageToSend.toRawJson(),
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

  Future<void> _decryptMessage() async {
    final message = _messageTextController.text.trim();

    GenericPeerMessage messageItem;
    try {
      /// decode this into an EncryptedPeerMessage object
      messageItem = GenericPeerMessage.fromRawJson(message);
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

    if (messageItem.data.isEmpty) {
      setState(() {
        _didEncrypt = false;
        _didDecryptSuccessfully = false;
        _hasEmbeddedMessageObject = false;
      });
      return;
    }

    var receivedMessage;
    var wotsSignature;
    var wotsMsgObj;

    try {
      switch (messageItem.type) {
        case "plain":
          receivedMessage = PlaintextPeerMessage.fromRawJson(messageItem.data);
          break;
        case "encrypted"://MessageType.encrypted:
          receivedMessage = EncryptedPeerMessage.fromRawJson(messageItem.data);
          break;
        case "encryptedMesh"://MessageType.encryptedMesh:
          receivedMessage = EncryptedMeshPeerMessage.fromRawJson(messageItem.data);
          break;
        case "wotsPlain"://MessageType.wotsPlain:
          receivedMessage = PlaintextPeerMessage.fromRawJson(messageItem.data);
          break;
        case "wotsEncrypted"://MessageType.wotsEncrypted:
          receivedMessage = EncryptedPeerMessage.fromRawJson(messageItem.data);
          break;
        case "wotsEncryptedMesh"://MessageType.wotsEncryptedMesh:
          wotsSignature = GigaWOTSSignatureItem.fromRawJson(messageItem.data);

          wotsMsgObj = wotsSignature.message;
          receivedMessage =  EncryptedWotsMeshPeerMessage.fromRawJson(wotsSignature.message.data);

          // var message = receivedMessage.message;
          _logManager.logger.d("receivedMessage: ${receivedMessage.toRawJson()}");

          final isValid = await _wotsManager.verifyGigaWotSignature(wotsSignature);
          _logManager.logger.d("isValid: $isValid");

          if (!isValid) {
            return;
          }
          break;
        case "unknown":
          receivedMessage = EncryptedPeerMessage.fromRawJson(messageItem.data);
          break;
      }
    } catch (e) {
      _logManager.logger.e("Exception: $e");
    }

    /// check against the from and to address
    final peerAddr = _cryptor.sha256(base64.encode(_peerPublicKey)).substring(0, 40);
    final myAddr = _cryptor.sha256(base64.encode(_mainPublicKey)).substring(0,40);

    final messageFromAddr = receivedMessage.from;
    final messageToAddr = receivedMessage.to;

    _logManager.logger.d("myAddr: ${myAddr}, peerAddr: ${peerAddr}");
    _logManager.logger.d("messageFromAddr: ${messageFromAddr}, messageToAddr: ${messageToAddr}");

    // final mac_msg_bytes = base64.decode(messageItem.mac);

    var Kuse_e = _Kenc_rec;
    var Kuse_a = _Kauth_rec;

    // var isOwnMessage = false;
    // if (messageToAddr == myAddr) {
    //   Kuse_e = _Kenc_rec;
    //   Kuse_a = _Kauth_rec;
    // }
    // else if (messageToAddr == peerAddr) {
    //   isOwnMessage = true;
    //   Kuse_e = _Kenc_send;
    //   Kuse_a = _Kauth_send;
    // }

    // var Kuse_e = _Kenc_rec;
    // var Kuse_a = _Kauth_rec;

    var isOwnMessage = false;
    if (messageToAddr == myAddr) {
      Kuse_e = _Kenc_send;
      Kuse_a = _Kauth_send;
    }
    else if (messageFromAddr == myAddr) {
      isOwnMessage = true;
      Kuse_e = _Kenc_rec;
      Kuse_a = _Kauth_rec;
    }

    // var sentState;
    // if (_sentMessages!.list!.isNotEmpty) {
    //   sentState = _sentMessages?.list!.last;
    // }
    /// check the mac
    ///
    // final check_received_message = EncryptedPeerMessage(
    //     index: messageItem.index,
    //     from: messageItem.from,
    //     to: messageItem.to,
    //     message: messageItem.message,
    //     time: messageItem.time,
    //     mac: "",
    // );
    final macToCheck = receivedMessage.mac;
    receivedMessage.mac = "";



    GenericPeerMessage genericMessageWots = GenericPeerMessage(
      type: MessageType.wotsEncryptedMesh.name,
      data: receivedMessage.toRawJson(),
    );

    // GenericPeerMessage genericMessageWots = GenericPeerMessage(
    //   type: messageItem.type,
    //   data: wotsSignatureUpgraded.toRawJson(),
    // );


    final msg_rec_hash = _cryptor.sha256(genericMessageWots.toRawJson());
    print("msg_rec_hash: ${msg_rec_hash}");

    var recieverState;
    // if (isOwnMessage) {
      if (_receivedMessages!.list!.isNotEmpty) {
        recieverState = _receivedMessages?.list.last;
      }
    // }


    final msgRecHashKey = SecretKey(hex.decode(msg_rec_hash));

    final hmac = Hmac.sha256();
    final computedMac = await hmac.calculateMac(
      Kuse_a,
      secretKey: msgRecHashKey!,
    );

    _logManager.logger.d("$macToCheck == ${base64.encode(computedMac.bytes)}");

    if (macToCheck != base64.encode(computedMac.bytes)) {
      setState(() {
        _hasEmbeddedMessageObject = false;
        _didEncrypt = false;
        _didDecryptSuccessfully = false;
      });
      _logManager.logger.w("MACs DO NOT Equal!!");
      return;
    }


    receivedMessage.mac = macToCheck;

    var newWotsMsgObj = WOTSMessageData(
      messageIndex: wotsMsgObj.messageIndex,
      previousHash: wotsMsgObj.previousHash,
      publicKey: wotsMsgObj.publicKey,
      nextPublicKey: wotsMsgObj.nextPublicKey,
      data: receivedMessage.toRawJson(),
    );

    GigaWOTSSignatureItem wotsSignatureUpgraded = GigaWOTSSignatureItem(
      id: wotsSignature.id,
      recovery: wotsSignature.recovery,
      signature: wotsSignature.signature,
      checksum: wotsSignature.checksum,
      message: newWotsMsgObj,
    );
    GenericPeerMessage updatedGenericMessageWots = GenericPeerMessage(
      type: MessageType.wotsEncryptedMesh.name,
      data: wotsSignatureUpgraded.toRawJson(),
    );

    /// need to decrypt with shared secret key
    final decryptedMessage = await _cryptor.decryptWithKey(Kuse_e, Kuse_a, receivedMessage.message);

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

    if (isOwnMessage) {
      _receivedMessages?.list.add(updatedGenericMessageWots);
    }
    // _logManager.logger.e("decrypted secMessage: ${secMessage.toJson()}");

    if (!isOwnMessage) {
      await _saveDecryptedMessage();
    }

    setState(() {
      _didEncrypt = false;
      _didDecryptSuccessfully = true;
      _messageTextController.text = decryptedMessage;
   });

    _qrMessageItem = QRCodeEncryptedMessageItem(
        keyId: base64.encode(hex.decode(peerAddr)),
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

  Future<void> _saveEncryptedMessage() async {

    if (_peerKey != null && _sentMessages != null) {

      final timestamp = DateTime.now().toIso8601String();

      PeerPublicKey newPeerPublicKey = PeerPublicKey(
        id: widget.peerId,
        version: AppConstants.peerPublicKeyItemVersion,
        name: (_peerKey?.name)!,
        pubKeyX: (_peerKey?.pubKeyX)!,
        pubKeyS: (_peerKey?.pubKeyS)!,
        notes: (_peerKey?.notes)!,
        sentMessages: _sentMessages!,
        // TODO: add back in
        receivedMessages: _receivedMessages!,
        // TODO: add back in
        cdate: (_peerKey?.cdate)!,
        mdate: timestamp,
      );

      var peerIndex = 0;
      var peerPubKeys = widget.keyItem!.peerPublicKeys;
      for (var peerKey in widget.keyItem!.peerPublicKeys) {
        if (peerKey.id == widget.peerId) {
          break;
        }
        peerIndex++;
      }

      peerPubKeys.removeAt(peerIndex);
      peerPubKeys.insert(peerIndex, newPeerPublicKey);


      var keyItem = KeyItem(
        id: widget.keyItem!.id,
        keyId: widget.keyItem!.keyId,
        version: AppConstants.keyItemVersion,
        name: widget.keyItem!.name,
        keys: widget.keyItem!.keys,
        keyType: widget.keyItem!.keyType,
        purpose: widget.keyItem!.purpose,
        algo: widget.keyItem!.algo,
        notes: widget.keyItem!.notes,
        favorite: widget.keyItem!.favorite,
        isBip39: widget.keyItem!.isBip39,
        peerPublicKeys: peerPubKeys,
        tags: widget.keyItem!.tags,
        mac: "",
        cdate: widget.keyItem!.cdate,
        mdate: timestamp,
      );

      final itemMac = await _cryptor.hmac256(keyItem.toRawJson());
      keyItem.mac = itemMac;

      final keyItemJson = keyItem.toRawJson();
      _logManager.logLongMessage("save add peer key keyItem.toRawJson: $keyItemJson");

      final genericItem = GenericItem(type: "key", data: keyItemJson);
      final genericItemString = genericItem.toRawJson();
      // _logManager.logger.d("genericItemString: ${genericItemString}");

      /// save key item in keychain
      ///
      final status = await _keyManager.saveItem(widget.keyItem!.id, genericItemString);

      if (status) {
        // await _getItem();
        EasyLoading.showToast('Saved Peer Message', duration: Duration(seconds: 1));
      } else {
        _showErrorDialog('Could not save the item.');
      }

    }
  }

  Future<void> _saveDecryptedMessage() async {

    if (_peerKey != null && _receivedMessages != null) {

      final timestamp = DateTime.now().toIso8601String();

      PeerPublicKey newPeerPublicKey = PeerPublicKey(
        id: widget.peerId,
        version: AppConstants.peerPublicKeyItemVersion,
        name: (_peerKey?.name)!,
        pubKeyX: (_peerKey?.pubKeyX)!,
        pubKeyS: (_peerKey?.pubKeyS)!,
        notes: (_peerKey?.notes)!,
        sentMessages: _sentMessages!,
        // TODO: add back in
        receivedMessages: _receivedMessages!,
        // TODO: add back in
        cdate: (_peerKey?.cdate)!,
        mdate: timestamp,
      );

      var peerIndex = 0;
      var peerPubKeys = widget.keyItem!.peerPublicKeys;
      for (var peerKey in widget.keyItem!.peerPublicKeys) {
        if (peerKey.id == widget.peerId) {
          break;
        }
        peerIndex++;
      }

      peerPubKeys.removeAt(peerIndex);
      peerPubKeys.insert(peerIndex, newPeerPublicKey);


      var keyItem = KeyItem(
        id: widget.keyItem!.id,
        keyId: widget.keyItem!.keyId,
        version: AppConstants.keyItemVersion,
        name: widget.keyItem!.name,
        keys: widget.keyItem!.keys,
        keyType: widget.keyItem!.keyType,
        purpose: widget.keyItem!.purpose,
        algo: widget.keyItem!.algo,
        notes: widget.keyItem!.notes,
        favorite: widget.keyItem!.favorite,
        isBip39: widget.keyItem!.isBip39,
        peerPublicKeys: peerPubKeys,
        tags: widget.keyItem!.tags,
        mac: "",
        cdate: widget.keyItem!.cdate,
        mdate: timestamp,
      );

      final itemMac = await _cryptor.hmac256(keyItem.toRawJson());
      keyItem.mac = itemMac;

      final keyItemJson = keyItem.toRawJson();
      _logManager.logLongMessage("save add peer key keyItem.toRawJson: $keyItemJson");

      final genericItem = GenericItem(type: "key", data: keyItemJson);
      final genericItemString = genericItem.toRawJson();
      // _logManager.logger.d("genericItemString: ${genericItemString}");

      /// save key item in keychain
      ///
      final status = await _keyManager.saveItem(widget.keyItem!.id, genericItemString);

      if (status) {
        // await _getItem();
        EasyLoading.showToast('Saved Peer Message', duration: Duration(seconds: 1));
      } else {
        _showErrorDialog('Could not save the item.');
      }

    }
 }

 Future<void> _signMessageWOTS(String message) async {

   _wotsSigningCounter++;

   // _lastRecievedHashState = hex.decode(msg_hashv1);
   // final msgHash = _cryptor.sha256(message);
   // final kAuthSend = SecretKey(_Kauth_send);
   //
   // final hmac = Hmac.sha256();
   // final mac_msg_wots = await hmac.calculateMac(
   //   hex.decode(msgHash),
   //   secretKey: kAuthSend!,
   // );

   // messageToSendWots.mac = base64.encode(mac_msg_wots.bytes);


   final msgObject = WOTSMessageData(
     messageIndex: _wotsSigningCounter,
     previousHash: _lastBlockHash,
     publicKey: _wotsManager.topPublicKey,
     nextPublicKey: _wotsManager.nextTopPublicKey,
     data: message,
   );

   _lastBlockHash = _lastSentHashState;

   GigaWOTSSignatureItem? wotsSignature1 = GigaWOTSSignatureItem(
     id: "",
     recovery: "",
     signature:[],
     checksum: "",
     message: msgObject,
   );

     // updateGenericMessage = GenericPeerMessage(
     //   type: MessageType.wotsEncryptedMesh.name,
     //   data: messageToSend.toRawJson(),
     // );

     final wotsSignature = await _wotsManager.signGigaWotMessage(
       _Kwots_send,
       "main",
       _wotsManager.lastBlockHash,
       msgObject,
       256,
       false,
     );

     // updateGenericMessage = GenericPeerMessage(
     //   type: MessageType.wotsEncryptedMesh.name,
     //   data: wotsSignature1!.toRawJson(),
     // );

     // setState(() {
     //   _sentMessages?.list.add(updateGenericMessage);
     // });

     // await _saveEncryptedMessage();

     // _logManager.logger.d("wotsSignature1: ${wotsSignature1?.toRawJson()}");
     _logManager.logLongMessage("wotsSignature1: ${wotsSignature?.toRawJson()}");
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

