import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blackbox_password_manager/models/EncryptedPeerMessage.dart';
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:string_validator/string_validator.dart';

import '../helpers/WidgetUtils.dart';
import '../models/KeyItem.dart';
import '../helpers/AppConstants.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/KeychainManager.dart';
import '../managers/Cryptor.dart';
import '../models/GenericItem.dart';
import '../models/QRCodeItem.dart';
import '../widgets/QRScanView.dart';
import 'home_tab_screen.dart';


/// Adding a Peer Public Key Set
///
///
class AddPeerPublicKeyScreen extends StatefulWidget {
  const AddPeerPublicKeyScreen({
    Key? key,
    required this.keyItem,
  }) : super(key: key);
  static const routeName = '/add_peer_public_key_screen';

  final KeyItem keyItem;

  @override
  State<AddPeerPublicKeyScreen> createState() => _AddPeerPublicKeyScreenState();
}

class _AddPeerPublicKeyScreenState extends State<AddPeerPublicKeyScreen> {
  final _peerNameTextController = TextEditingController();
  final _notesTextController = TextEditingController();
  final _importedKeyDataTextController = TextEditingController();
  final _scannedKeyDataTextController = TextEditingController();

  final _peerNameFocusNode = FocusNode();
  final _notesFocusNode = FocusNode();
  final _importedKeyDataFocusNode = FocusNode();
  final _scannedKeyDataFocusNode = FocusNode();

  int _selectedIndex = 1;

  bool _isDarkModeEnabled = false;
  bool _fieldsAreValid = false;
  bool _isImportingManually = false;

  List<String> _keyTags = [];
  List<bool> _selectedTags = [];

  bool _isImportedKeyHex = false;
  bool _isImportedKeyBase64 = false;

  List<int> _publicKey = [];

  KeyItem? _mainKeyItem;
  List<int> _mainPrivKey = [];
  List<int> _mainPubKey = [];

  bool _publicKeyIsValid = false;

  String _sharedSecretKeyHash = "";

  List<PeerPublicKey> _peerPublicKeys = [];

  List<int> _Kenc = [];
  List<int> _Kauth = [];
  List<int> _Kxor = [];
  List<int> _Kmac = [];

  /// blackbox-TOTP methods
  int _otpIterationNumber = 0;
  int _otpIntervalIncrement = 0;
  String _otpTokenWords = "";

  Timer? otpTimer;

  String? _initialPeerPublicValue;


  /// algos
  ///
  /// symmetric
  final algorithm_nomac = AesCtr.with256bits(macAlgorithm: MacAlgorithm.empty);

  final algorithm_exchange = X25519();


  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _keyManager = KeychainManager();
  final _cryptor = Cryptor();


  @override
  void initState() {
    super.initState();

    _logManager.log("AddPeerPublicKeyScreen", "initState", "initState");

    _mainKeyItem = widget.keyItem;


    if (widget.keyItem.peerPublicKeys == null) {
      _peerPublicKeys = [];
    }

    _peerPublicKeys = widget.keyItem.peerPublicKeys;

    // final keyIndex = (widget.keyItem.keyIndex)!;
    /// decrypt root seed and expand
    _cryptor.decrypt(widget.keyItem.keys.privX!).then((privKeyX) async {
      final decryptedSeedData = privKeyX;
      // print("decryptedSeedData: ${decryptedSeedData}");

      /// TODO: switch encoding !
      // final decodedRootKey = hex.decode(decryptedSeedData);
      final decodedRootKey = base64.decode(decryptedSeedData);

      // await _getChainedKey(decryptedSeedData);
      // print("decodedRootKey: ${decodedRootKey}");

      algorithm_exchange
          .newKeyPairFromSeed(decodedRootKey).then((value) {

        final privSeedPair = value;
        privSeedPair.extractPublicKey().then((value) {
          final simplePublicKey = value;
          // _mainPubKey = simplePublicKey.bytes;
          // privSeedPair.extractPrivateKeyBytes().then((value) {
          //   print("privkeyseed check: ${value}");
          //   print("privkeyseed check hex: ${hex.encode(value)}");
          // });


          if (mounted) {
            setState(() {
              _mainPrivKey = decodedRootKey;
              _mainPubKey = simplePublicKey.bytes;
            });
          } else {
            _mainPrivKey = decodedRootKey;
            _mainPubKey = simplePublicKey.bytes;
          }
        });

      });
    });


    _peerPublicKeys = widget.keyItem.peerPublicKeys;

    // if (_peerPublicKeys.isEmpty) {
    //   _peerPublicKeys = [];
    // }

    // _filteredTags = _settingsManager.itemTags;
    for (var _ in _settingsManager.itemTags) {
      _selectedTags.add(false);
      // _filteredTags.add(tag);
    }

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;

    _selectedIndex = _settingsManager.currentTabIndex;

    _validateFields(true);

    _startOTPTimer();
    
  }

  Future<void> _getChainedKey(String rootKey) async {
    final privSeedPair = await algorithm_exchange.newKeyPairFromSeed(base64.decode(rootKey));

      // final privSeedPair = pair;
    final pubKey = await privSeedPair.extractPublicKey();
    var pubKeyHash = _cryptor.sha256(hex.encode(pubKey.bytes));
    _logManager.logger.d("pubKeyHash1: $pubKeyHash");

    for (var index = 0; index < 8; index++) {
      final keyPair = await algorithm_exchange.newKeyPairFromSeed(hex.decode(pubKeyHash));
      final pubKey = await keyPair.extractPublicKey();
      pubKeyHash = _cryptor.sha256(hex.encode(pubKey.bytes));
      _logManager.logger.d("pubKeyHash-$index: $pubKeyHash");
    }

    _logManager.logger.d("pubKeyHash-last: $pubKeyHash");
        // final simplePublicKey = value;
        // _mainPubKey = simplePublicKey.bytes;
        // privSeedPair.extractPrivateKeyBytes().then((value) {
        //   print("privkeyseed check: ${value}");
        //   print("privkeyseed check hex: ${hex.encode(value)}");
        // });


    if (mounted) {
      setState(() {
        _mainPrivKey = base64.decode(rootKey);
        _mainPubKey = pubKey.bytes;
      });
    } else {
      _mainPrivKey = base64.decode(rootKey);
      _mainPubKey = pubKey.bytes;
    }

  }

  void _startOTPTimer() async {
    otpTimer = Timer.periodic(Duration(seconds:1),(value){
      // print("timer: ${value.tick}");

      _calculateOTPToken();
    });
  }

  void _cancelOTPTimer() {
    if (otpTimer != null) {
      otpTimer!.cancel();
      otpTimer = null;
    }
  }

  void _calculateOTPToken() async {
    if (_Kmac.isEmpty) {
      return;
    }
    final otpTimeInterval = AppConstants.peerTOTPDefaultTimeInterval; // seconds
    final t = AppConstants.appTOTPStartTime;
    final otpStartTime = DateTime.parse(t);
    // print("otpStartTime: ${otpStartTime} | ${otpStartTime.second}");

    final timestamp = DateTime.now();
    // print("now timestamp: ${timestamp} | ${timestamp.second}");

    if (timestamp.isAfter(otpStartTime)) {
      final diff_sec = timestamp.difference(otpStartTime).inSeconds;
      // final diff_sec2= otpStartTime.difference(timestamp).inSeconds;

      // print("diff_sec: ${diff_sec}");
      // print("diff_sec2: ${diff_sec2}");

      /// this gives the current step within the time interval 1-30
      final mod_sec = diff_sec.toInt() % otpTimeInterval.toInt();
      // print("mod_sec: ${mod_sec}");

      setState((){
        _otpIntervalIncrement = mod_sec;
      });

      /// this gives the iteration number we are on
      final div_sec = (diff_sec.toInt() / otpTimeInterval.toInt());
      final div_sec_floor = div_sec.floor();//diff_sec.toInt() / otpTimeInterval.toInt();
      // print("div_sec: ${div_sec}");
      // print("div_sec_floor: ${div_sec_floor}");

      setState((){
        _otpIterationNumber = div_sec_floor;
      });

      var divHex = div_sec_floor.toRadixString(16);
      // print("divHex: $divHex");

      if (divHex.length % 2 == 1) {
        divHex = "0" + divHex;
        // print("divHex: $divHex");
      }

      final divBytes = hex.decode(divHex);
      // print("divBytes: $divBytes");

      // final nonce = new List.generate(16, (_) => rng.nextInt(255));
      final nonce = List<int>.filled(16, 0);
      final pad = nonce;

      final iv = nonce.sublist(0, nonce.length - divBytes.length) + divBytes;
      // print("iv: $iv");
      // print("iv.hex: ${hex.encode(iv)}");

      final secretKeyXor = SecretKey(_Kmac);
      /// Encrypt the appended keys
      final secretBox = await algorithm_nomac.encrypt(
        pad,
        secretKey: secretKeyXor,
        nonce: iv,
      );

      // print("ciphertext: ${hex.encode(secretBox.cipherText)}");
      // print("mac: ${hex.encode(secretBox.mac.bytes)}");

      final tokenWords = bip39.entropyToMnemonic(hex.encode(secretBox.cipherText));
      // print("token words: ${tokenWords}");

      final tokenParts = tokenWords.split(" ");

      final otpTokenWords = tokenParts.sublist(0,4).join(" ");
      // print("otpTokenWords[${mod_sec}]: ${otpTokenWords}");

      _otpTokenWords = otpTokenWords;

      // final mod_sec2 = otpTimeInterval.toInt() % diff_sec.toInt();
      // print("mod_sec2: ${mod_sec2}");
    }
  }

  @override
  void dispose() {
    super.dispose();

    _cancelOTPTimer();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? (Platform.isAndroid ? (AppConstants.useMaterial3 ? Colors.black12 : Colors.black54) : (AppConstants.useMaterial3 ? Colors.black26 : Colors.black54)) : Colors.blue[50],//Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Add Peer Public Key",
          style: TextStyle(
            color: _isDarkModeEnabled ? Colors.white : Colors.black,
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          Visibility(
            visible: true,
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
                await _pressedSavePeerKeyItem();
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
                  enabled: true,
                  decoration: InputDecoration(
                    labelText: 'Peer Name',
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
                    _validateFields(true);
                  },
                  onTap: () {
                    _validateFields(false);
                  },
                  onFieldSubmitted: (_) {
                    _validateFields(false);
                  },
                  // keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.done,
                  focusNode: _peerNameFocusNode,
                  controller: _peerNameTextController,
                ),
              ),

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
                            _isImportingManually = true;
                          });

                          _validateFields(true);
                          // await _generateKeyPair();
                        },
                        child: Text(
                          "Import Key Manually",
                        ),
                      ),
                    ),
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
                          // await _generateKeyPair();
                          setState((){
                            _isImportingManually = false;
                          });

                          _validateFields(true);

                          /// HERE: scanQRCode
                          /// 
                          // print("scan qr code");

                          await _scanCode(context);
                          // _showModalImportKeyOptionsView();
                        },
                        child: Text(
                          "Scan Key QR Code",
                        ),
                      ),
                    ),
                    Visibility(
                      visible: true,
                      child: Spacer(),
                    ),
                  ],),),
              // Divider(color: _isDarkModeEnabled ? Colors.greenAccent : null),

              // Padding(
              //   padding: EdgeInsets.all(16.0),
              //   child: Text(
              //     "Public Key:\n${hex.encode(_publicKey)}\n\nPublic Mnemonic:\n${_publicKeyMnemonic}",
              //     style: TextStyle(
              //       color: _isDarkModeEnabled ? Colors.white : null,
              //       fontSize: 16,
              //     ),
              //   ),
              // ),
              Visibility(
                visible: _isImportingManually,
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
                            _validateFields(true);
                          },
                          onTap: () {
                            _validateFields(true);
                          },
                          onFieldSubmitted: (_) {
                            _validateFields(true);
                          },
                          // keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.done,
                          focusNode: _importedKeyDataFocusNode,
                          controller: _importedKeyDataTextController,
                        ),
                      ),
                    ),
                    //
                  ],
                ),),
              // Visibility(
              //   visible: _publicKeyIsValid,
              //   child: Text(""),
              // ),
              Visibility(
                visible: !_publicKeyIsValid,
                child:
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () async {
                          WidgetUtils.showToastMessage("Public Key cannot be the same as the Primary Account", 3);
                        },
                        icon: Icon(
                          Icons.error,
                          color: Colors.red,
                          size: 30.0,
                        ),
                      ),
                      TextButton(
                        child: Text(
                          'Public Key is Invalid',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: _isDarkModeEnabled
                                ? Colors.white
                                : Colors.grey,
                          ),
                        ),
                        onPressed: () async {

                          // WidgetUtils.showToastMessage("Public Key Can't be the same as the Main Public Key", 3);
                          WidgetUtils.showToastMessage("Public Key cannot be the same as the Primary Account", 3);

                        },
                      ),
                      Spacer(),

                    ],
                  ),
                ),),
              Visibility(
                visible: _isImportingManually,
                child:
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () async {
                          Clipboard.getData("text/plain").then((value) {
                            final data = value?.text;
                            if (data != null) {
                              setState(() {
                                _importedKeyDataTextController.text = data.trim();
                              });
                              // print("pasted: ${data}");

                              /// auto clear clipboard?
                              // Clipboard.setData(ClipboardData(text: ""));

                              _validateFields(true);
                            }
                          });

                          // EasyLoading.showToast('Pasted',
                          //     duration: Duration(milliseconds: 500));
                        },
                        icon: Icon(
                          Icons.copy_rounded,
                          color: _isDarkModeEnabled
                              ? Colors.greenAccent
                              : Colors.grey,
                          size: 30.0,
                        ),
                      ),
                      TextButton(
                        child: Text(
                          'Paste Key from Clipboard',
                          style: TextStyle(
                            fontSize: 16.0,
                            color: _isDarkModeEnabled
                                ? Colors.white
                                : Colors.grey,
                          ),
                        ),
                        onPressed: () async {
                          Clipboard.getData("text/plain").then((value) {
                            final data = value?.text;
                            if (data != null) {
                              setState(() {
                                _importedKeyDataTextController.text = data.trim();
                              });
                              // print("pasted: ${data}");

                              _validateFields(true);

                              /// auto clear clipboard?
                              // Clipboard.setData(ClipboardData(text: ""));
                            }
                          });

                          // EasyLoading.showToast('Copied',
                          //     duration: Duration(milliseconds: 500));
                        },
                      ),
                      Spacer(),

                    ],
                  ),
                ),),
              Visibility(
                visible: !_isImportingManually,
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
                            _validateFields(true);
                          },
                          onTap: () {
                            _validateFields(true);
                          },
                          onFieldSubmitted: (_) {
                            _validateFields(true);
                          },
                          // keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.done,
                          focusNode: _scannedKeyDataFocusNode,
                          controller: _scannedKeyDataTextController,
                        ),
                      ),
                    ),
                    //
                  ],
                ),),


              // Visibility(
              //   visible: _sharedSecretKeyHash.isNotEmpty,
              //   child:
              //   Padding(
              //     padding: EdgeInsets.all(16),
              //     child: Text(
              //       "Shared Secret Hash:\n\n${_sharedSecretKeyHash}",
              //       style: TextStyle(
              //         color: _isDarkModeEnabled ? Colors.white : null,
              //       ),
              //       textAlign: TextAlign.left,
              //     ),
              //   ),),


              Visibility(
                visible: _otpTokenWords.isNotEmpty,
                child: Divider(
                    color: _isDarkModeEnabled ? Colors.greenAccent : null,
                ),),
              // Visibility(
              //   visible: _otpTokenWords.isNotEmpty,
              //   child:
              //   Padding(
              //     padding: EdgeInsets.all(16.0),
              //     child: Text(
              //       "OTP Token: ${_otpTokenWords}\n\ninterval: ${_otpIntervalIncrement}\nincrement: ${_otpIterationNumber}",
              //       // "Public Key:\n${hex.encode(_peerPublicKeyData)}\n\nPublic Mnemonic:\n${_publicKeyMnemonic}",
              //       style: TextStyle(
              //         color: _isDarkModeEnabled ? Colors.white : null,
              //         fontSize: 16,
              //       ),
              //     ),
              //   ),),
              Visibility(
                visible: _otpTokenWords.isNotEmpty,
                child:
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: ListTile(
                      title: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TOTP:",
                            style: TextStyle(
                              color: _isDarkModeEnabled ? Colors.greenAccent : Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8,),
                          Text(
                            "${_otpTokenWords}",
                            // "Public Key:\n${hex.encode(_peerPublicKeyData)}\n\nPublic Mnemonic:\n${_publicKeyMnemonic}",
                            style: TextStyle(
                              color: _isDarkModeEnabled ? Colors.white : Colors.blueAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16,),

                        ],),
                    subtitle: Text(
                      "interval: ${30-_otpIntervalIncrement}",
                      // "interval: ${_otpIntervalIncrement}\nincrement: ${_otpIterationNumber}",
                      // "Public Key:\n${hex.encode(_peerPublicKeyData)}\n\nPublic Mnemonic:\n${_publicKeyMnemonic}",
                      style: TextStyle(
                        color: _isDarkModeEnabled ? Colors.white : Colors.blueAccent,
                        fontSize: 16,
                      ),
                    ),
                    trailing: CircularProgressIndicator(
                        color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                      backgroundColor: _isDarkModeEnabled ? Colors.grey : Colors.grey,
                      value: _otpIntervalIncrement == 0 ? 0.0 : (_otpIntervalIncrement/30),
                      // valueColor: _isDarkModeEnabled ? AlwaysStoppedAnimation<Color>(Colors.pinkAccent) : AlwaysStoppedAnimation<Color>(Colors.redAccent),
                    ),
                  ),
                  // Text(
                  //   "OTP Token: ${_otpTokenWords}\n\ninterval: ${_otpIntervalIncrement}\nincrement: ${_otpIterationNumber}",
                  //   // "Public Key:\n${hex.encode(_peerPublicKeyData)}\n\nPublic Mnemonic:\n${_publicKeyMnemonic}",
                  //   style: TextStyle(
                  //     color: _isDarkModeEnabled ? Colors.white : null,
                  //     fontSize: 16,
                  //   ),
                  // ),
                ),),
              Divider(color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey),

              Padding(
                padding: EdgeInsets.all(16.0),
                child: TextFormField(
                  cursorColor: _isDarkModeEnabled ? Colors.greenAccent : null,
                  autofocus: true,
                  autocorrect: false,
                  enabled: true,
                  minLines: 5,
                  maxLines: 10,
                  readOnly: false,
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
                    // _validateFields(false);
                  },
                  onTap: () {
                    // _validateFields(false);
                  },
                  onFieldSubmitted: (_) {
                    // _validateFields(false);
                  },
                  // keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.newline,
                  focusNode: _notesFocusNode,
                  controller: _notesTextController,
                ),
              ),
              // Padding(
              //   padding: EdgeInsets.all(16.0),
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.start,
              //     children: [
              //       IconButton(
              //         onPressed: () {
              //           setState(() {
              //             _isFavorite = !_isFavorite;
              //           });
              //
              //           _validateFields();
              //         },
              //         icon: Icon(
              //           Icons.favorite,
              //           color: _isFavorite
              //               ? (_isDarkModeEnabled
              //               ? Colors.greenAccent
              //               : Colors.blue)
              //               : Colors.grey,
              //           size: 30.0,
              //         ),
              //       ),
              //       TextButton(
              //         child: Text(
              //           'Favorite',
              //           style: TextStyle(
              //             fontSize: 16.0,
              //             color:
              //             _isDarkModeEnabled ? Colors.white : Colors.black,
              //           ),
              //         ),
              //         onPressed: () {
              //           setState(() {
              //             _isFavorite = !_isFavorite;
              //           });
              //
              //           _validateFields();
              //         },
              //       ),
              //       Spacer(),
              //     ],
              //   ),
              // ),
              // Divider(color: _isDarkModeEnabled ? Colors.greenAccent : null),
              // Center(
              //   child: Text(
              //     "Tags",
              //     style: TextStyle(
              //       color: _isDarkModeEnabled
              //           ? Colors.greenAccent
              //           : Colors.blueAccent,
              //       fontSize: 18,
              //     ),
              //   ),
              // ),
              // Padding(
              //   padding: EdgeInsets.all(16.0),
              //   child: Container(
              //     height: 44,
              //     child: ListView.separated(
              //       itemCount: _keyTags.length + 1,
              //       separatorBuilder: (context, index) => Divider(
              //         color: _isDarkModeEnabled ? Colors.greenAccent : null,
              //       ),
              //       scrollDirection: Axis.horizontal,
              //       itemBuilder: (context, index) {
              //         // var addTagItem;
              //         // if (index == 0)
              //         final addTagItem = Row(
              //           children: [
              //             IconButton(
              //               onPressed: () {
              //                 _showModalAddTagView();
              //               },
              //               icon: Icon(
              //                 Icons.add_circle,
              //                 color: Colors.blueAccent,
              //               ),
              //             ),
              //             TextButton(
              //               child: Text(
              //                 "Add Tag",
              //                 style: TextStyle(
              //                   color: Colors.white,
              //                   fontWeight: FontWeight.bold,
              //                   fontSize: 16,
              //                 ),
              //               ),
              //               onPressed: () {
              //                 _showModalAddTagView();
              //               },
              //             ),
              //             SizedBox(
              //               width: 16,
              //             ),
              //           ],
              //         );
              //
              //         var currentTagItem;
              //         if (index > 0) {
              //           currentTagItem = GestureDetector(
              //             onTap: () {
              //               setState(() {
              //                 _selectedTags[index - 1] =
              //                 !_selectedTags[index - 1];
              //               });
              //             },
              //             child: Row(
              //               children: [
              //                 SizedBox(
              //                   width: 8,
              //                 ),
              //                 Padding(
              //                   padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
              //                   child: Text(
              //                     "${_keyTags[index - 1]}",
              //                     style: TextStyle(
              //                       color: _isDarkModeEnabled
              //                           ? Colors.greenAccent
              //                           : Colors.blueAccent,
              //                       fontWeight: FontWeight.bold,
              //                       fontSize: 16,
              //                     ),
              //                   ),
              //                 ),
              //                 if (_selectedTags.length >= index - 1 &&
              //                     _selectedTags[index - 1])
              //                   IconButton(
              //                     onPressed: () {
              //                       setState(() {
              //                         _keyTags.removeAt(index - 1);
              //                         _selectedTags.removeAt(index - 1);
              //                       });
              //
              //                       _validateFields();
              //                     },
              //                     icon: Icon(
              //                       Icons.cancel_sharp,
              //                       color: Colors.redAccent,
              //                     ),
              //                   ),
              //                 if (!_selectedTags[index - 1])
              //                   SizedBox(
              //                     width: 8,
              //                   ),
              //               ],
              //             ),
              //           );
              //         }
              //
              //         return Padding(
              //           padding: EdgeInsets.all(4),
              //           child: GestureDetector(
              //             onTap: () {
              //               setState(() {
              //                 _selectedTags[index - 1] =
              //                 !_selectedTags[index - 1];
              //               });
              //             },
              //             child: Container(
              //               height: 44,
              //               decoration: BoxDecoration(
              //                 color: _isDarkModeEnabled
              //                     ? Colors.greenAccent.withOpacity(0.25)
              //                     : Colors.blueAccent.withOpacity(0.25),
              //                 borderRadius: BorderRadius.circular(20),
              //               ),
              //               child: (index == 0 ? addTagItem : currentTagItem),
              //             ),
              //           ),
              //         );
              //       },
              //     ),
              //   ),
              // ),
              // Divider(
              //   color: _isDarkModeEnabled ? Colors.greenAccent : null,
              // ),

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

  Future<void> _scanCode(BuildContext context) async {
    _settingsManager.setIsScanningQRCode(true);

    /// TODO: fix the Android bug that does not let the camera operate
    if (Platform.isIOS) {
      await _scanQR(context);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context)
            .push(MaterialPageRoute(
          builder: (context) => QRScanView(),
        ))
            .then((value) {
          _settingsManager.setIsScanningQRCode(false);

          try {
            QRCodeKeyItem item =
            QRCodeKeyItem.fromRawJson(value);

            if (item != null) {
              setState(() {
                _scannedKeyDataTextController.text = item.key;
              });
            } else {
              _showErrorDialog("Invalid code format");
            }
          } catch (e) {
            // print("Error: $e");
            _showErrorDialog("Invalid code format");
          }
        });
      });
    }
  }

  Future<void> _scanQR(BuildContext context) async {
    String barcodeScanRes;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          "#ff6666", "Cancel", true, ScanMode.QR);

      _settingsManager.setIsScanningQRCode(false);

      /// user pressed cancel
      if (barcodeScanRes == "-1") {
        return;
      }

      try {
        QRCodeKeyItem item =
        QRCodeKeyItem.fromRawJson(barcodeScanRes);

        if (item != null) {
          setState(() {
            _scannedKeyDataTextController.text = item.key;
          });
        } else {
          _showErrorDialog("Invalid code format");
        }
      } catch (e) {
        _logManager.logger.w("Platform exception: $e");

        /// decide to decrypt or save item.
        _showErrorDialog("Invalid code format");
      }
    } on PlatformException {
      barcodeScanRes = "Failed to get platform version.";
      _logManager.logger.w("Platform exception");
    }
  }


  /// TODO: fix this validation with key encodings
  void _validateFields(bool genKey) {
    final name = _peerNameTextController.text;
    final importedData = _importedKeyDataTextController.text;
    final scannedData = _scannedKeyDataTextController.text;

    _sharedSecretKeyHash = "";
    _publicKeyIsValid = true;

    if (name.isEmpty) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    if (!genKey) {
      return;
    }

    bool _isHexEncoding = false;
    bool _isB64Encoding = false;

    // print("_mainPubKey: ${base64.encode(_mainPubKey)}");

    try {
      /// Importing (keyboard/clipboard) public key data
      ///
      if (_isImportingManually) {
        // print("imported data-----");

        if (importedData == null) {
          return;
        }
        if (importedData.isEmpty) {
          return;
        }

        final checkB64 = isBase64(importedData);
        final checkHex = isHexadecimal(importedData);
        // print("checkB64[${importedData.length}]: $checkB64");
        // print("checkHex[${importedData.length}]: $checkHex");


        if (checkB64 && (base64.decode(importedData).length == 32)){
            _isHexEncoding = false;
            _isB64Encoding = true;
            final isValid = base64.encode(_mainPubKey) != importedData;
            // print("isValid: ${isValid}");

            setState(() {
              _isImportedKeyBase64 = isValid;
              _isImportedKeyHex = false;
              _fieldsAreValid = isValid;
              _publicKeyIsValid = isValid;
            });
            if (!isValid) {
              return;
            }

        } else if (checkHex && (importedData.length == 64)) {
            _isHexEncoding = true;
            _isB64Encoding = false;
            final isValid = hex.encode(_mainPubKey) != importedData;
            // print("isValid: ${isValid}");

            setState(() {
              _isImportedKeyBase64 = false;
              _isImportedKeyHex = isValid;
              _fieldsAreValid = isValid;
              _publicKeyIsValid = isValid;
            });
            if (!isValid) {
              return;
            }

        } else {
            // print("checkHex: ${checkHex}, checkB64: ${checkB64}; INvalid!!!");
            setState(() {
              _fieldsAreValid = false;
            });
            print("GOING NOWHERE !!!");
            return;
        }
      } else {
        /// Scanning-in public key data
        ///
        if (scannedData == null) {
          return;
        }
        if (scannedData.isEmpty) {
          return;
        }

        final checkB64 = isBase64(scannedData);
        final checkHex = isHexadecimal(scannedData);
        // print("checkB64[${scannedData.length}]: $checkB64");
        // print("checkHex[${scannedData.length}]: $checkHex");

        if (checkB64){
          if (base64.decode(scannedData).length == 32) {
            _isHexEncoding = false;
            _isB64Encoding = true;

            final isValid = base64.encode(_mainPubKey) != scannedData;
            // print("isValid: ${isValid}");

            setState(() {
              _fieldsAreValid = isValid;
              _publicKeyIsValid = isValid;
            });
            if (!isValid) {
              return;
            }

          } else {
            setState(() {
              _fieldsAreValid = false;
            });
            return;
          }
        } else if (checkHex) {
          if (scannedData.length == 64) {
            _isHexEncoding = true;
            _isB64Encoding = false;

            final isValid = hex.encode(_mainPubKey) != scannedData;
            // final isValid = _mainPubKey != hex.decode(scannedData);
            // print("isValid: ${isValid}");

            setState(() {
              _fieldsAreValid = isValid;
              _publicKeyIsValid = isValid;
            });
            if (!isValid) {
              return;
            }
          } else {
            setState(() {
              _fieldsAreValid = false;
            });
            return;
          }
        }
      }
    } catch (e) {
      _logManager.logger.d("Platform Exception: $e");
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    setState(() {
      // _shouldShowExtendedKeys = true;
      _fieldsAreValid = true;

      if (_isImportingManually) {
        if (_initialPeerPublicValue == null) {
          // _isHexEncoding;
          // var convertedData = "";
          if (_isImportedKeyBase64) {
            _initialPeerPublicValue = importedData;
            // var temp = base64.decode(importedData);
          } else if (_isImportedKeyHex) {
            _initialPeerPublicValue = base64.encode(hex.decode(importedData));
          } else {
            print("nothing1");
          }
          // _initialPeerPublicValue = importedData;
          _computeSecretKeyHash(_initialPeerPublicValue!);
        } else if (_initialPeerPublicValue != importedData) {

          if (_isImportedKeyBase64) {
            _initialPeerPublicValue = importedData;
            // var temp = base64.decode(importedData);
          } else if (_isImportedKeyHex) {
            _initialPeerPublicValue = base64.encode(hex.decode(importedData));
          } else {
            print("nothing2");
          }

          // _initialPeerPublicValue = importedData;
          _computeSecretKeyHash(_initialPeerPublicValue!);
        }
        // _computeSecretKeyHash(importedData);
      } else {
        print("scanning data");

        if (_initialPeerPublicValue == null) {
          _initialPeerPublicValue = scannedData;
          _computeSecretKeyHash(scannedData);
        } else if (_initialPeerPublicValue != scannedData) {
          _initialPeerPublicValue = scannedData;
          _computeSecretKeyHash(scannedData);
        }

        // _computeSecretKeyHash(scannedData);
      }
      });
  }

  Future<void> _computeSecretKeyHash(String bobPubKey) async {
    final algorithm = X25519();

    // print("bob pubKeyExchange: $bobPubKey");
    final pubBytes = base64.decode(bobPubKey);
    // print("bob pubBytes: $pubBytes");

    final bobPublicKey = SimplePublicKey(pubBytes, type: KeyPairType.x25519);
    // print('bobKeyPair pubMade: ${bobPublicKey.bytes}');
    // print('peer Public Key Hex: ${hex.encode(bobPublicKey.bytes)}');

    // final aliceSeed = pubExchangeKeySeed;
    final seedBytes = _mainPrivKey;
    final mainKeyPair = await algorithm.newKeyPairFromSeed(seedBytes);
    // final mainPublicKey = await mainKeyPair.extractPublicKey();
    // print("_mainPublicKey: ${_mainPublicKey.length}: ${_mainPublicKey}");
    // print("mainPublicKey: ${mainPublicKey.bytes.length}: ${hex.encode(mainPublicKey.bytes)}");

    // print('peer Public Key Hex: ${hex.encode(bobPublicKey.bytes)}');

    // final mypublicKeyExchange = await mainKeyPair.extractPublicKey();
    // final ahash = _cryptor.sha256(hex.encode(mypublicKeyExchange.bytes));

    // We can now calculate a shared secret.
    final sharedSecret = await algorithm.sharedSecretKey(
      keyPair: mainKeyPair,
      remotePublicKey: bobPublicKey,
    );
    final sharedSecretBytes = await sharedSecret.extractBytes();

    final sharedSecretKeyHash = await _cryptor.sha256(hex.encode(sharedSecretBytes));
    // final code = RecoveryKeyCode(id: ahash, key: hex.encode(sharedSecretBytes));
    // print("secret key bytes: ${sharedSecretBytes}");
    // print("secret key hex: ${hex.encode(sharedSecretBytes)}");
    // print("shared secret key hash: ${_sharedSecretKeyHash}");

    setState((){
      _sharedSecretKeyHash = sharedSecretKeyHash;
    });

    /// expand our shared secret
    final expanded = await _cryptor.expandKey(sharedSecretBytes);
    // print('Shared secret expanded: $expanded');

    setState(() { //async {
      _Kenc = expanded.sublist(0, 32);
      _Kauth = expanded.sublist(32, 64);
    });

    final authSecret = SecretKey(_Kauth);
    final hmac = Hmac.sha256();
    final checkMac = await hmac.calculateMac(
      _Kenc,
      secretKey: authSecret,
    );

    _Kmac = checkMac.bytes;
    _Kxor = _cryptor.xor(Uint8List.fromList(_Kenc), Uint8List.fromList(_Kauth));

    _calculateOTPToken();

  }

  _pressedSavePeerKeyItem() async {

    if (_mainPrivKey == null) {
      _showErrorDialog('Could not save the item.');
      return;
    }

    if (_mainPrivKey.isEmpty) {
      _showErrorDialog('Could not save the item.');
      return;
    }

    if (_mainKeyItem == null){
      _showErrorDialog('Could not save the item.');
      return;
    }
    // final createdDate = (_mainKeyItem?.cdate)!;
     var createdDate = DateTime.now().toIso8601String();
    var peer_uuid = _cryptor.getUUID();

    final peerName = _peerNameTextController.text;
    final peerNotes = _notesTextController.text;
    var peerPubKey = "";

    if (_isImportingManually) {
      peerPubKey = _importedKeyDataTextController.text;
    } else {
      peerPubKey = _scannedKeyDataTextController.text;
    }

    /// we don't neet to re-encrypt key items
    ///
    // final encryptedName = await _cryptor.encrypt(name);
    //
    // final encryptedNotes = await _cryptor.encrypt(notes);
    // final encryptedKey = await _cryptor.encrypt(hex.encode(_mainPrivKey));
    final encodedLength = utf8.encode(peerName).length + utf8.encode(peerNotes).length + utf8.encode(peerPubKey).length;
    final keyIndex = _settingsManager.doEncryption(encodedLength);
    // _logManager.logger.d("keyIndex: $keyIndex");

    final encryptedPeerName = await _cryptor.encrypt(peerName);
    final encryptedPeerNotes = await _cryptor.encrypt(peerNotes);

    var encryptedPeerPublicKey = "";

    if (_isImportingManually) {
      // print("_importedKeyDataTextController.text: ${_importedKeyDataTextController.text}");
      if (_isImportedKeyBase64) {
        encryptedPeerPublicKey =
        await _cryptor.encrypt(_importedKeyDataTextController.text);
      } else if (_isImportedKeyHex) {
        encryptedPeerPublicKey =
        await _cryptor.encrypt(base64.encode(hex.decode(_importedKeyDataTextController.text)));
      }
      // print("encryptedPeerPublicKey: ${encryptedPeerPublicKey}");

    } else {
      encryptedPeerPublicKey = await _cryptor.encrypt(_scannedKeyDataTextController.text);
    }

    if (encryptedPeerPublicKey == null) {
      return;
    }

    if (encryptedPeerPublicKey.isEmpty) {
      return;
    }


    PeerPublicKey newPeerPublicKey = PeerPublicKey(
      id: peer_uuid,
      version: AppConstants.peerPublicKeyItemVersion,
      name: encryptedPeerName,
      pubKeyX: encryptedPeerPublicKey,
      pubKeyS: "",
      notes: encryptedPeerNotes,
      sentMessages: GenericMessageList(list: []), // TODO: add back in
      receivedMessages: GenericMessageList(list: []), // TODO: add back in
      cdate: createdDate,
      mdate: createdDate,
    );

    _peerPublicKeys.add(newPeerPublicKey);

    var keyItem = KeyItem(
      id: widget.keyItem.id,
      keyId: widget.keyItem.keyId,
      version: AppConstants.keyItemVersion,
      name: widget.keyItem.name,
      // key: widget.keyItem.key,
      keys: widget.keyItem.keys,
      keyType: EnumToString.convertToString(EncryptionKeyType.asym),
      purpose: EnumToString.convertToString(KeyPurposeType.keyexchange),
      algo: EnumToString.convertToString(KeyExchangeAlgoType.x25519),
      notes: widget.keyItem.notes,
      favorite: widget.keyItem.favorite,
      isBip39: true,
      peerPublicKeys: _peerPublicKeys,
      tags: _keyTags,
      mac: "",
      cdate: widget.keyItem.cdate,
      mdate: widget.keyItem.mdate,
    );

    final itemMac = await _cryptor.hmac256(keyItem.toRawJson());
    keyItem.mac = itemMac;

    final keyItemJson = keyItem.toRawJson();
    // print("save add peer key keyItem.toRawJson: $keyItemJson");
    // print("save add peer key keyItem.toJson: ${keyItem.toJson()}");

    final genericItem = GenericItem(type: "key", data: keyItemJson);
    // print('genericItem toRawJson: ${genericItem.toRawJson()}');

    final genericItemString = genericItem.toRawJson();
    // print("save key item genericItemString: $genericItemString");

    /// save key item in keychain
    ///
    final status = await _keyManager.saveItem(widget.keyItem.id, genericItemString);

    // final status = true;

    if (status) {
      EasyLoading.showToast('Saved Item', duration: Duration(seconds: 1));

      Navigator.of(context).pop('savedItem');
    } else {
      _showErrorDialog('Could not save the item.');
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
