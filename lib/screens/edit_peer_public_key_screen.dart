import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:bip39/bip39.dart' as bip39;

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
import '../screens/active_encryption_screen.dart';


class EditPeerPublicKeyScreen extends StatefulWidget {
  const EditPeerPublicKeyScreen({
    Key? key,
    required this.peerId,
    required this.keyItem,
  }) : super(key: key);
  static const routeName = '/add_peer_public_key_screen';

  final String peerId;
  final KeyItem keyItem;

  @override
  State<EditPeerPublicKeyScreen> createState() => _EditPeerPublicKeyScreenState();
}

class _EditPeerPublicKeyScreenState extends State<EditPeerPublicKeyScreen> {
  final _peerNameTextController = TextEditingController();
  final _importedKeyDataTextController = TextEditingController();
  final _scannedKeyDataTextController = TextEditingController();
  final _notesTextController = TextEditingController();

  final _peerNameFocusNode = FocusNode();
  final _importedKeyDataFocusNode = FocusNode();
  final _scannedKeyDataFocusNode = FocusNode();
  final _notesFocusNode = FocusNode();

  int _selectedIndex = 1;

  bool _isDarkModeEnabled = false;
  bool _shouldShowExtendedKeys = false;

  bool _isEditing = false;

  // bool _isFavorite = false;
  bool _fieldsAreValid = false;

  bool _isImportingManually = false;
  bool _isScanningQRCode = false;

  List<String> _keyTags = [];
  List<bool> _selectedTags = [];

  List<int> _peerPublicKeyData = [];
  String _peerAddr = "";

  List<int> _sharedSecretKey = [];

  String _otpTokenWords = "";
  int _numberTOTPWords = 4;
  int _numberTOTPDigits = 6;


  int _otpIntervalIncrement = 0;
  int _otpIterationNumber = 0;

  bool _otpUseNumbers = false;

  int _otpUseNumberOfDigits = 6;
  int _otpUseNumberOfWords = 4;


  KeyItem? _mainKeyItem;
  List<int> _mainPrivKey = [];
  List<int> _mainPubKey = [];

  String _modifiedDate = "";

  /// expanded keys from shared secret
  List<int> _Kenc = [];
  List<int> _Kauth = [];
  List<int> _Kxor = [];
  List<int> _Kmac = [];

  PeerPublicKey? _thisPeerPublicKey;

  bool _publicKeyIsValid = false;

  List<PeerPublicKey> _peerPublicKeys = [];

  String? _initialPeerPublicValue;


  Timer? otpTimer;

  final algorithm_exchange = X25519();
  final algorithm_nomac = AesCtr.with256bits(macAlgorithm: MacAlgorithm.empty);

  final logManager = LogManager();
  final settingsManager = SettingsManager();
  final keyManager = KeychainManager();
  final cryptor = Cryptor();

  @override
  void initState() {
    super.initState();

    logManager.log("EditPeerPublicKeyScreen", "initState", "initState");

    // print("tags note: ${settingsManager.itemTags}");
    // if (widget.note == null) {
    // print("starting new key item");

    // _generateKeyPair();
    // _filteredTags = settingsManager.itemTags;
    for (var tag in settingsManager.itemTags) {
      _selectedTags.add(false);
      // _filteredTags.add(tag);
    }

    _isDarkModeEnabled = settingsManager.isDarkModeEnabled;

    _selectedIndex = settingsManager.currentTabIndex;

    _mainKeyItem = widget.keyItem;

    _peerPublicKeys = widget.keyItem.peerPublicKeys!;

    /// TODO: check this timer location
    _startOTPTimer();

    if (_peerPublicKeys == null) {
      _peerPublicKeys = [];
    }

    for (var p in _peerPublicKeys) {
      if (p.id == widget.peerId) {
        _thisPeerPublicKey = p;
      }
    }

    // var keyIndex = 0;//(widget.keyItem.keyIndex)!;
    // if (widget.keyItem.keyIndex != null) {
    //   keyIndex = (widget.keyItem.keyIndex)!;
    // }

    /// decrypt root seed and expand
    cryptor.decrypt(widget.keyItem.key).then((value) {
      final decryptedSeedData = value;
      // print("decryptedSeedData: ${decryptedSeedData}");

      /// TODO: switch encoding !
      // final decodedRootKey = hex.decode(decryptedSeedData);
      final decodedMainPrivateKey = base64.decode(decryptedSeedData);

      // print("decodedMainPrivateKey: ${decodedMainPrivateKey}");

      algorithm_exchange
          .newKeyPairFromSeed(decodedMainPrivateKey).then((value) {

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
              _mainPrivKey = decodedMainPrivateKey;
              _mainPubKey = simplePublicKey.bytes;
              // _publicKeyMnemonic = bip39.entropyToMnemonic(hex.encode(_mainPubKey));
              // _scannedKeyDataTextController.text = base64.encode(_mainPubKey);

              if (_thisPeerPublicKey != null) {
                var peerPublicKeyIndex = 0;

                setState(() {
                  _modifiedDate = (_thisPeerPublicKey?.mdate)!;
                });
                // logManager.logger.d("_modifiedDate: ${_modifiedDate}");
                //
                // logManager.logger.d("cdate: ${_thisPeerPublicKey?.cdate}");
                //
                // logManager.logger.d("_mainKeyItem.cdate: ${_mainKeyItem?.cdate}");
                // logManager.logger.d("_mainKeyItem.mdate: ${_mainKeyItem?.mdate}");

                // if (_thisPeerPublicKey?.keyIndex != null) {
                //   peerPublicKeyIndex = (_thisPeerPublicKey?.keyIndex)!;
                // }
                // final peerPublicKeyIndex = (_thisPeerPublicKey?.keyIndex)!;

                final encryptedPeerPublicKey = _thisPeerPublicKey?.key;
                  // _isFavorite = (_thisPeerPublicKey?.favorite)!;

                  final encryptedPeerPublicKeyNote = _thisPeerPublicKey?.notes;
                  // print("encryptedPeerPublicKeyNote: ${encryptedPeerPublicKeyNote}");
                  if (encryptedPeerPublicKeyNote != null) {
                    cryptor.decrypt(encryptedPeerPublicKeyNote).then((value) {
                      final dnote = value;
                      setState(() {
                        _notesTextController.text = dnote;
                      });
                    });
                  }

                  if (encryptedPeerPublicKey != null) {
                    cryptor.decrypt(encryptedPeerPublicKey).then((value) {
                    // print("decryptedPeerPublicKeyData: ${value
                    //     .length}: ${value}");
                    final decryptedPeerPublicKeyData = value;
                    _scannedKeyDataTextController.text = decryptedPeerPublicKeyData;
                    _importedKeyDataTextController.text = decryptedPeerPublicKeyData;

                    _generatePeerKeyPair(decryptedPeerPublicKeyData);

                    final encryptedPeerPublicKeyName = _thisPeerPublicKey?.name;
                    if (encryptedPeerPublicKeyName != null) {
                      cryptor.decrypt(encryptedPeerPublicKeyName).then((value) {
                        if (value != null) {
                          setState(() {
                            _peerNameTextController.text = value;
                          });
                        }
                      });
                    }
                    });
                }
              }
              // final sharedSecretKeyHash = await cryptor.sha256(hex.encode(sharedSecretBytes));
              // print("shared secret key hash: ${sharedSecretKeyHash}");

            });
          } else {
            _mainPrivKey = decodedMainPrivateKey;
            _mainPubKey = simplePublicKey.bytes;
            // _publicKeyMnemonic = bip39.entropyToMnemonic(hex.encode(_mainPubKey));
            // _scannedKeyDataTextController.text = base64.encode(_mainPubKey);

            if (_thisPeerPublicKey != null) {
              // final peerPublicKeyIndex = (_thisPeerPublicKey?.keyIndex)!;
              // var peerPublicKeyIndex = 0;

              // if (_thisPeerPublicKey?.keyIndex != null) {
              //   peerPublicKeyIndex = (_thisPeerPublicKey?.keyIndex)!;
              // }

              final encryptedPeerPublicKey = _thisPeerPublicKey?.key;
              // _isFavorite = (_thisPeerPublicKey?.favorite)!;

              final encryptedPeerPublicKeyNote = _thisPeerPublicKey?.notes;
              // print("encryptedPeerPublicKeyNote: ${encryptedPeerPublicKeyNote}");
              if (encryptedPeerPublicKeyNote != null) {
                cryptor.decrypt(encryptedPeerPublicKeyNote).then((value) {
                  final dnote = value;
                  // setState(() {
                    _notesTextController.text = dnote;
                  // });
                });
              }
              if (encryptedPeerPublicKey != null) {
                cryptor.decrypt(encryptedPeerPublicKey).then((value) {
                  // print("decryptedPeerPublicKeyData: ${value
                  //     .length}: ${value}");
                  final decryptedPeerPublicKeyData = value;
                  _scannedKeyDataTextController.text = decryptedPeerPublicKeyData;
                  _importedKeyDataTextController.text = decryptedPeerPublicKeyData;

                  _generatePeerKeyPair(decryptedPeerPublicKeyData);

                  final encryptedPeerPublicKeyName = _thisPeerPublicKey?.name;
                  if (encryptedPeerPublicKeyName != null) {
                    cryptor.decrypt(encryptedPeerPublicKeyName).then((value) {
                      if (value != null) {
                        setState(() {
                          _peerNameTextController.text = value;
                        });
                      }
                    });
                  }
                });
              }
            }
          }
        });

      });


      // _pubKey = simplePublicKey.bytes;

      // if (mounted) {
      //   setState(() {
      //     _mainPrivKey = decodedRootKey;
      //   });
      // } else {
      //   _mainPrivKey = decodedRootKey;
      // }
    });


    // _peerPublicKeys = widget.keyItem.peerPublicKeys!;

    // if (_peerPublicKeys == null) {
    //   _peerPublicKeys = [];
    // }


    _validateFields();

  }

  Future<void> _refreshKeyData() async {
    if (_mainKeyItem == null) {
      return;
    }

    _peerPublicKeys = (_mainKeyItem?.peerPublicKeys)!;

    if (_peerPublicKeys == null) {
      _peerPublicKeys = [];
    }

    for (var p in _peerPublicKeys) {
      if (p.id == widget.peerId) {
        _thisPeerPublicKey = p;
      }
    }

    final mkey = (_mainKeyItem?.key)!;
    if (mkey == null) {
      return;
    }

    // var mainKeyIndex = 0;
    //
    // if (_mainKeyItem?.keyIndex != null) {
    //   mainKeyIndex = (_mainKeyItem?.keyIndex)!;
    // }
    /// decrypt root seed and expand
    cryptor.decrypt(mkey).then((value) {
      final decryptedSeedData = value;
      // print("decryptedSeedData: ${decryptedSeedData}");

      /// TODO: switch encoding !
      // final decodedRootKey = hex.decode(decryptedSeedData);
      final decodedMainPrivateKey = base64.decode(decryptedSeedData);

      // print("decodedMainPrivateKey: ${decodedMainPrivateKey}");

      algorithm_exchange
          .newKeyPairFromSeed(decodedMainPrivateKey).then((value) {

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
              _mainPrivKey = decodedMainPrivateKey;
              _mainPubKey = simplePublicKey.bytes;
              // _publicKeyMnemonic = bip39.entropyToMnemonic(hex.encode(_mainPubKey));
              // _scannedKeyDataTextController.text = base64.encode(_mainPubKey);
              // print("1_thisPeerPublicKey: ${_thisPeerPublicKey}");

              if (_thisPeerPublicKey != null) {
                // final peerPublicKeyIndex = (_thisPeerPublicKey?.keyIndex)!;
                // var peerPublicKeyIndex = 0;

                // if (_thisPeerPublicKey?.keyIndex != null) {
                //   peerPublicKeyIndex = (_thisPeerPublicKey?.keyIndex)!;
                // }
                final encryptedPeerPublicKey = _thisPeerPublicKey?.key;
                // _isFavorite = (_thisPeerPublicKey?.favorite)!;
                final encryptedPeerPublicKeyNote = _thisPeerPublicKey?.notes;
                // print("1encryptedPeerPublicKeyNote: ${encryptedPeerPublicKeyNote}");

                if (encryptedPeerPublicKeyNote != null) {
                  cryptor.decrypt(encryptedPeerPublicKeyNote).then((value) {
                    final dnote = value;
                    setState(() {
                      _notesTextController.text = dnote;
                    });
                  });
                }
                if (encryptedPeerPublicKey != null) {
                  cryptor.decrypt(encryptedPeerPublicKey).then((value) {
                    // print("decryptedPeerPublicKeyData: ${value
                    //     .length}: ${value}");
                    final decryptedPeerPublicKeyData = value;
                    _scannedKeyDataTextController.text = decryptedPeerPublicKeyData;
                    _importedKeyDataTextController.text = decryptedPeerPublicKeyData;

                    _generatePeerKeyPair(decryptedPeerPublicKeyData);

                    final encryptedPeerPublicKeyName = _thisPeerPublicKey?.name;
                    if (encryptedPeerPublicKeyName != null) {
                      cryptor.decrypt(encryptedPeerPublicKeyName).then((value) {
                        if (value != null) {
                          setState(() {
                            _peerNameTextController.text = value;
                          });
                        }
                      });
                    }
                  });
                }
              }
              // final sharedSecretKeyHash = await cryptor.sha256(hex.encode(sharedSecretBytes));
              // print("shared secret key hash: ${sharedSecretKeyHash}");

            });
          } else {
            _mainPrivKey = decodedMainPrivateKey;
            _mainPubKey = simplePublicKey.bytes;
            // _publicKeyMnemonic = bip39.entropyToMnemonic(hex.encode(_mainPubKey));
            // _scannedKeyDataTextController.text = base64.encode(_mainPubKey);
            // print("_thisPeerPublicKey: ${_thisPeerPublicKey}");

            if (_thisPeerPublicKey != null) {
              // final peerPublicKeyIndex = (_thisPeerPublicKey?.keyIndex)!;
              // var peerPublicKeyIndex = 0;
              //
              // if (_thisPeerPublicKey?.keyIndex != null) {
              //   peerPublicKeyIndex = (_thisPeerPublicKey?.keyIndex)!;
              // }
              final encryptedPeerPublicKey = _thisPeerPublicKey?.key;
              // _isFavorite = (_thisPeerPublicKey?.favorite)!;

              final encryptedPeerPublicKeyNote = _thisPeerPublicKey?.notes;
              // print("encryptedPeerPublicKeyNote: ${encryptedPeerPublicKeyNote}");
              if (encryptedPeerPublicKeyNote != null) {
                cryptor.decrypt(encryptedPeerPublicKeyNote).then((value) {
                  final dnote = value;
                  setState(() {
                    _notesTextController.text = dnote;
                  });
                });
              }

              if (encryptedPeerPublicKey != null) {
                cryptor.decrypt(encryptedPeerPublicKey).then((value) {
                  // print("decryptedPeerPublicKeyData: ${value
                  //     .length}: ${value}");
                  final decryptedPeerPublicKeyData = value;
                  _scannedKeyDataTextController.text = decryptedPeerPublicKeyData;
                  _importedKeyDataTextController.text = decryptedPeerPublicKeyData;

                  _generatePeerKeyPair(decryptedPeerPublicKeyData);

                  final encryptedPeerPublicKeyName = _thisPeerPublicKey?.name;
                  if (encryptedPeerPublicKeyName != null) {
                    cryptor.decrypt(encryptedPeerPublicKeyName).then((value) {
                      if (value != null) {
                        setState(() {
                          _peerNameTextController.text = value;
                        });
                      }
                    });
                  }
                });
              }
            }
          }
        });

      });


      // _pubKey = simplePublicKey.bytes;

      // if (mounted) {
      //   setState(() {
      //     _mainPrivKey = decodedRootKey;
      //   });
      // } else {
      //   _mainPrivKey = decodedRootKey;
      // }
    });
  }

  Future<void> _generatePeerKeyPair(String bobPubString) async {
    // print("edit_peer_public_key: _generatePeerKeyPair");

    if (_mainPrivKey == null) {
      return;
    }

    if (_mainPrivKey.isEmpty) {
      return;
    }

    final algorithm_exchange = X25519();

    // print("bobPubString: ${bobPubString.length}: ${bobPubString}");

    /// TODO: switch encoding !
    // final privKey = hex.decode(privateKeyString);
    // final privKey = base64.decode(privateKeyString);
    // print("privKey: ${privKey.length}: ${privKey}");

    // final ownerKeyPair = await algorithm_exchange.newKeyPairFromSeed(privKey);
    final ownerKeyPair = await algorithm_exchange.newKeyPairFromSeed(_mainPrivKey);
    final mainPublicKey = await ownerKeyPair.extractPublicKey();
    // print("mainPublicKey: ${mainPublicKey.bytes.length}: ${hex.encode(mainPublicKey.bytes)}");

    // final privKey = await ownerKeyPair.extractPrivateKeyBytes();
    // print("privKeyBytes: ${privKey.length}: ${privKey}");

    // final bobPub = hex.decode(bobPubString);
    final bobPub = base64.decode(bobPubString);
    // print('peer Public Key: $bobPub');
    // print('peer Public Key hex: ${hex.encode(bobPub)}');
    _peerPublicKeyData = bobPub;

    _peerAddr = cryptor.sha256(hex.encode(_peerPublicKeyData)).substring(0,40);

    // _publicKeyMnemonic = bip39.entropyToMnemonic(hex.encode(_peerPublicKeyData));


    final bobPublicKey = SimplePublicKey(bobPub, type: KeyPairType.x25519);

    final sharedSecret = await algorithm_exchange.sharedSecretKey(
      keyPair: ownerKeyPair,
      remotePublicKey: bobPublicKey,
    );

    final sharedSecretBytes = await sharedSecret.extractBytes();
    // print('Shared secret: $sharedSecretBytes');
    // print('Shared secret hex: ${hex.encode(sharedSecretBytes)}');

    // final sharedSecretKeyHash = await cryptor.sha256(hex.encode(sharedSecretBytes));
    // print("shared secret key hash: ${sharedSecretKeyHash}");

    // setState((){
    //   _sharedSecretKeyHash = sharedSecretKeyHash;
    // });

    final expanded = await cryptor.expandKey(sharedSecretBytes);
    // print('Shared secret expanded: $expanded');


    setState(() { //async {
      _Kenc = expanded.sublist(0, 32);
      _Kauth = expanded.sublist(32, 64);
    });

    final authSecret = SecretKey(_Kauth);
    final hmac = Hmac.sha256();
    final checkMac = await hmac.calculateMac(
      _Kenc,
      secretKey: authSecret!,
    );

    _Kmac = checkMac.bytes;

    _Kxor = cryptor.xor(Uint8List.fromList(_Kenc), Uint8List.fromList(_Kauth));
    // logManager.logger.d("KXOR: ${hex.encode(_Kxor)}");
    // logManager.logger.d("KEYMAC: ${hex.encode(_Kmac)}");


    _calculateOTPToken();
    // final otpTimeInterval = 30; // seconds
    // final t = AppConstants.appOTPStartTime;
    // final otpStartTime = DateTime.parse(t);
    // print("otpStartTime: ${otpStartTime} | ${otpStartTime.second}");
    //
    // final timestamp = DateTime.now();
    // print("now timestamp: ${timestamp} | ${timestamp.second}");
    //
    // if (timestamp.isAfter(otpStartTime)) {
    //   final diff_sec = timestamp.difference(otpStartTime).inSeconds;
    //   // final diff_sec2= otpStartTime.difference(timestamp).inSeconds;
    //
    //   print("diff_sec: ${diff_sec}");
    //   // print("diff_sec2: ${diff_sec2}");
    //
    //   /// this gives the current step within the time interval 1-30
    //   final mod_sec = diff_sec.toInt() % otpTimeInterval.toInt();
    //   print("mod_sec: ${mod_sec}");
    //
    //   /// this gives the iteration number we are on
    //   final div_sec = (diff_sec.toInt() / otpTimeInterval.toInt());
    //   final div_sec_floor = div_sec.floor();//diff_sec.toInt() / otpTimeInterval.toInt();
    //   print("div_sec: ${div_sec}");
    //   print("div_sec_floor: ${div_sec_floor}");
    //
    //   final mod_sec2 = otpTimeInterval.toInt() % diff_sec.toInt();
    //   print("mod_sec2: ${mod_sec2}");
    // }

  }

  void _calculateOTPToken() async {
    if (_Kmac.isEmpty) {
      return;
    }
    final otpTimeInterval = AppConstants.appTOTPDefaultTimeInterval;
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

      /// this gives the current step within the time interval 0-30
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

      /// add "0" if # of hex chars is odd
      if (divHex.length % 2 == 1) {
        divHex = "0" + divHex;
      }

      final divBytes = hex.decode(divHex);
      // print("divBytes: $divBytes");

      // final nonce = new List.generate(16, (_) => rng.nextInt(255));
      final nonce = List<int>.filled(16, 0);
      final pad = nonce;

      final iv = nonce.sublist(0, nonce.length - divBytes.length) + divBytes;
      // print("iv: $iv");
      // print("iv.hex: ${hex.encode(iv)}");

      final secretKeyMac = SecretKey(_Kmac);
      /// Encrypt the appended keys
      final secretBox = await algorithm_nomac.encrypt(
        pad,
        secretKey: secretKeyMac,
        nonce: iv,
      );

      // print("ciphertext: ${hex.encode(secretBox.cipherText)}");
      // print("mac: ${hex.encode(secretBox.mac.bytes)}");

      final tokenWords = bip39.entropyToMnemonic(hex.encode(secretBox.cipherText));
      // print("token words: ${tokenWords}");

      final tokenParts = tokenWords.split(" ");

      /// 3 words - (2048^3/30) = 286,331,153.0 guesses/second = 286 million/sec
      /// 4 words - (2048^4/30) = 586,406,201,480.5 guesses/second  = 586 billion/sec
      final otpTokenWords = tokenParts.sublist(0,_otpUseNumberOfWords).join(" ");
      // print("otpTokenWords[${mod_sec}]: ${otpTokenWords}");

      if (_otpUseNumbers) {
        final wordIndexes = cryptor.mnemonicToNumberString(tokenWords, _otpUseNumberOfDigits);

        final wordIndexString = "${wordIndexes}";
        _otpTokenWords = wordIndexString;
      } else {
        _otpTokenWords = otpTokenWords;
      }


      // final mod_sec2 = otpTimeInterval.toInt() % diff_sec.toInt();
      // print("mod_sec2: ${mod_sec2}");
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

  @override
  void dispose() {
    super.dispose();

    _cancelOTPTimer();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text('Peer Public Key'),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: !_isEditing ? BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () async {
            Navigator.of(context).pop();
          },
        ) : CloseButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () async {
            setState((){
              _isEditing = false;
            });

            await _refreshKeyData();
          },
        ),
        // leading:
        // BackButton(
        //   color: _isDarkModeEnabled ? Colors.greenAccent : null,
        //   onPressed: () {
        //     _cancelOTPTimer();
        //
        //     Navigator.of(context).pop();
        //   },
        // ),
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
                await _pressedSavePeerKeyItem();
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
                      ? Colors.greenAccent : Colors.white,
                  fontSize: 18,
                ),
              ),
              style: ButtonStyle(
                  foregroundColor: _isDarkModeEnabled
                      ? MaterialStateProperty.all<Color>(Colors.greenAccent)
                      : MaterialStateProperty.all<Color>(Colors.grey),
              ),
              onPressed: () async {
                // print("pressed done");
                // await _pressedSavePeerKeyItem();
                setState(() {
                  _isEditing = !_isEditing;
                });
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
                  focusNode: _peerNameFocusNode,
                  controller: _peerNameTextController,
                ),
              ),

              /// symmetric options
              ///
              // Divider(color: _isDarkModeEnabled ? Colors.greenAccent : null),


              Visibility(
                visible: false,// _isEditing,
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

                          _validateFields();
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

                          _validateFields();

                          /// HERE: scanQRCode
                          ///
                          print("scan qr code");

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
                  ],),
              ),
              // Divider(color: _isDarkModeEnabled ? Colors.greenAccent : null),

              Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Public Address:\n${_peerAddr}",
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : null,
                    fontSize: 14,
                  ),
                ),
              ),
              Row(children: [
                Padding(
                  padding: EdgeInsets.all(4.0),
                  child: IconButton(
                    icon: Icon(
                      Icons.copy_all,
                      color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                    ),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(
                        text: hex.encode(_peerPublicKeyData),
                      ));

                      settingsManager.setDidCopyToClipboard(true);

                      EasyLoading.showToast('Copied Public Key',
                          duration: Duration(milliseconds: 500));
                    },
                  ),
                ),
                TextButton(child: Text(
                    "Copy Public Key",
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : Colors.blueGrey,
                    fontSize: 16,
                  ),
                ),
                  // "Public Key:\n${hex.encode(_peerPublicKeyData)}\n\nPublic Mnemonic:\n${_publicKeyMnemonic}"
                  onPressed: () async {
                    // print("copy");
                    await Clipboard.setData(ClipboardData(
                      text: hex.encode(_peerPublicKeyData),
                    ));

                    settingsManager.setDidCopyToClipboard(true);

                    EasyLoading.showToast('Copied Public Key',
                        duration: Duration(milliseconds: 500));
                  },
                ),
              ],),

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
                          WidgetUtils.showToastMessage("Public Key Can't be the same as the Main Public Key", 3);
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

                          WidgetUtils.showToastMessage("Public Key Can't be the same as the Main Public Key", 3);

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
                                _importedKeyDataTextController.text = data;
                              });

                              _validateFields();
                            }
                          });

                          // EasyLoading.showToast('Pasted',
                          //     duration: Duration(milliseconds: 500));
                        },
                        icon: Icon(
                          Icons.paste,
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
                                _importedKeyDataTextController.text = data;
                              });

                              _validateFields();
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
                visible: false,// !_isImportingManually,
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
                          focusNode: _scannedKeyDataFocusNode,
                          controller: _scannedKeyDataTextController,
                        ),
                      ),
                    ),
                  ],
                ),),
              Visibility(
                visible: !_isEditing,
                child: Divider(
                  color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
                ),
              ),
              Visibility(
                visible: !_isEditing,
                child:
              Padding(
                  padding: EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(
                      "Encrypt/Decrypt",
                      style: TextStyle(
                        color: _isDarkModeEnabled ? Colors.white : Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                    ),
                    onTap: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ActiveEncryptionScreen(
                            id: widget.peerId,
                            keyItem: widget.keyItem,
                          ),
                        ),
                      );
                    },
                  )
              ),),
              Visibility(
                visible: true,//!_isEditing,
                child: Divider(
                    color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
                ),
              ),
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
                      "time: ${AppConstants.appTOTPDefaultTimeInterval - _otpIntervalIncrement}",
                      style: TextStyle(
                        color: _isDarkModeEnabled ? Colors.white : null,
                        fontSize: 16,
                      ),
                    ),
                    trailing: CircularProgressIndicator(
                      color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                      backgroundColor: _isDarkModeEnabled ? Colors.grey : Colors.grey,
                      value: _otpIntervalIncrement == 0 ? 0.0 : (_otpIntervalIncrement/30),
                      // valueColor: _isDarkModeEnabled ? AlwaysStoppedAnimation<Color>(Colors.pinkAccent) : AlwaysStoppedAnimation<Color>(Colors.redAccent),
                      semanticsLabel: "time interval",
                      semanticsValue: (_otpIntervalIncrement/30).toString(),
                    ),
                  ),
                ),
              ),
              Row(children: [
                Spacer(),
                Visibility(
                  visible: _otpTokenWords.isNotEmpty,
                  child: Text(
                    _otpUseNumbers ? "$_otpUseNumberOfDigits" : "$_otpUseNumberOfWords",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : Colors.blueGrey,
                      fontSize: 16,
                    ),
                  ),
                ),
                Spacer(),
                Visibility(
                  visible: _otpTokenWords.isNotEmpty,
                  child: IconButton(
                    icon: Icon(
                      _otpUseNumbers ? Icons.sort_by_alpha : Icons.numbers,
                      color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                    ),
                    onPressed: () async {
                      setState(() {
                        _otpUseNumbers = !_otpUseNumbers;
                      });

                      _calculateOTPToken();
                    },
                  ),
                ),

                Spacer(),
                // SizedBox(width: 16,),
                Visibility(
                  visible: _otpTokenWords.isNotEmpty,
                  child: IconButton(
                    icon: Icon(
                      Icons.download_outlined,
                      color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                    ),
                    onPressed: () async {
                      if (_otpUseNumbers) {
                        if (_otpUseNumberOfDigits <= AppConstants.appTOTPDefaultMinNumberDigits) {
                          return;
                        }
                        setState(() {
                          _otpUseNumberOfDigits -= 1;
                        });
                      } else {
                        if (_otpUseNumberOfWords <= AppConstants.appTOTPDefaultMinNumberWords) {
                          return;
                        }
                        setState(() {
                          _otpUseNumberOfWords -= 1;
                        });
                      }
                      _calculateOTPToken();
                    },
                  ),
                ),
                Spacer(),
                // SizedBox(width: 32,),
                Visibility(
                  visible: _otpTokenWords.isNotEmpty,
                  child: IconButton(
                    icon: Icon(
                      Icons.upload,
                      color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                    ),
                    onPressed: () async {
                      if (_otpUseNumbers) {
                        if (_otpUseNumberOfDigits >= AppConstants.appTOTPDefaultMaxNumberDigits) {
                          return;
                        }
                        setState(() {
                          _otpUseNumberOfDigits += 1;
                        });
                      } else {
                        if (_otpUseNumberOfWords >= AppConstants.appTOTPDefaultMaxNumberWords) {
                          return;
                        }
                        setState(() {
                          _otpUseNumberOfWords += 1;
                        });
                      }


                      _calculateOTPToken();
                    },
                  ),
                ),
                Spacer(),
              ],),

                Visibility(
                  visible: _otpTokenWords.isNotEmpty,
                  child: Divider(
                    color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: TextFormField(
                  cursorColor: _isDarkModeEnabled ? Colors.greenAccent : null,
                  autofocus: false,
                  autocorrect: false,
                  enabled: true,
                  readOnly: !_isEditing,
                  minLines: 5,
                  maxLines: 10,
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
                            ? (_isEditing ? Colors.greenAccent : Colors.grey)
                            : (_isEditing ? Colors.blueAccent : Colors.grey),
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
                  textInputAction: TextInputAction.newline,
                  focusNode: _notesFocusNode,
                  controller: _notesTextController,
                ),
              ),
              Divider(
                  color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "id: ${(_mainKeyItem?.id)!}",
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
                  "created: ${DateFormat('MMM d y  hh:mm:ss a').format(DateTime.parse((_mainKeyItem?.cdate)!))}",
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
                    "modified: ${DateFormat('MMM d y  hh:mm:ss a').format(DateTime.parse((_thisPeerPublicKey?.mdate)!))}",
                    // _modifiedDate != "" ? "modified: ${DateFormat('MMM d y  hh:mm:ss a').format(DateTime.parse((_modifiedDate!)))}" : "",
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
                      padding: EdgeInsets.all(8.0),
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
                          _showConfirmDeletePeerKeyDialog();
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

  Future<void> _scanCode(BuildContext context) async {
    settingsManager.setIsScanningQRCode(true);

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
          settingsManager.setIsScanningQRCode(false);

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

      settingsManager.setIsScanningQRCode(false);

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
        logManager.logger.w("Platform exception: $e");

        /// decide to decrypt or save item.
        _showErrorDialog("Invalid code format");

      }
    } on PlatformException {
      barcodeScanRes = "Failed to get platform version.";
      logManager.logger.w("Platform exception");
    }
  }


  /// TODO: fix this validation with key encodings
  void _validateFields() {
    final name = _peerNameTextController.text;
    final importedData = _importedKeyDataTextController.text;
    final scannedData = _scannedKeyDataTextController.text;

    _publicKeyIsValid = true;

    if (name.isEmpty) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    // if (_mainPubKey.isEmpty) {
    //   setState(() {
    //     _fieldsAreValid = false;
    //   });
    //   return;
    // }

    // if (_isImportingManually && !bip39.validateMnemonic(importedData)) {
    //   setState(() {
    //     _fieldsAreValid = false;
    //   });
    //   return;
    // }
    // if ((_isImportingManually && importedData.isEmpty) || (_isImportingManually && importedData.length != 32)) {
    //   setState(() {
    //     _fieldsAreValid = false;
    //   });
    //   return;
    // }
    try {
      if (_isImportingManually) {
        if (importedData.isEmpty || base64
            .decode(importedData)
            .length != 32) {
          setState(() {
            _fieldsAreValid = false;
          });
          return;
        } else if (importedData.isNotEmpty) {
          // print("_mainPubKey: ${_mainPubKey}");
          final isValid = _mainPubKey != base64.decode(importedData);
          setState(() {
            _fieldsAreValid = isValid;
            _publicKeyIsValid = isValid;
          });
          if (!isValid) {
            // _publicKeyIsValid = false;
            // WidgetUtils.showToastMessage("Public Key Can't be the Main Public Key", 3);

            return;
          }
        }
      }

      // if (!_isImportingManually && !bip39.validateMnemonic(scannedData)) {
      //   setState(() {
      //     _fieldsAreValid = false;
      //   });
      //   return;
      // }
      // if ((!_isImportingManually && scannedData.isEmpty) || (!_isImportingManually && scannedData.length != 32)) {
      //   setState(() {
      //     _fieldsAreValid = false;
      //   });
      //   return;
      // }
      if (!_isImportingManually) {
        if (scannedData.isEmpty || base64
            .decode(scannedData)
            .length != 32) {
          setState(() {
            _fieldsAreValid = false;
          });
          return;
        } else if (scannedData.isNotEmpty) {
          // print("_mainPubKey: ${_mainPubKey}");
          final isValid = _mainPubKey != base64.decode(scannedData);
          setState(() {
            _fieldsAreValid = isValid;
            _publicKeyIsValid = isValid;
          });

          if (!isValid) {
            // _publicKeyIsValid = false;
            // WidgetUtils.showToastMessage("Public Key Can't be the Main Public Key", 3);
            return;
          }
        }
      }
    } catch (e) {
      logManager.logger.d("Platform Exception: $e");
      setState(() {
        _fieldsAreValid = false;
        // _publicKeyIsValid = isValid;
      });
      return;
    }

    setState(() {
      _shouldShowExtendedKeys = true;
      _fieldsAreValid = true;

      if (_isImportingManually) {
        _computeSecretKeyHash(importedData);
      } else {
        _computeSecretKeyHash(scannedData);
      }
    });
  }

  Future<void> _computeSecretKeyHash(String bobPubKey) async {
    final algorithm = X25519();

    if (_initialPeerPublicValue == null) {
      _initialPeerPublicValue = bobPubKey;
    }

    // print("bob pubKeyExchange: $bobPubKey");
    final pubBytes = base64.decode(bobPubKey);
    // print("bob pubBytes: $pubBytes");

    final bobPublicKey = SimplePublicKey(pubBytes, type: KeyPairType.x25519);
    // print('bobKeyPair pubMade: ${bobPublicKey.bytes}');
    // print('bobKeyPair pubMade.Hex: ${hex.encode(bobPublicKey.bytes)}');

    // final aliceSeed = pubExchangeKeySeed;
    final seedBytes = _mainPrivKey;
    final mainKeyPair = await algorithm.newKeyPairFromSeed(seedBytes);

    // final mypublicKeyExchange = await mainKeyPair.extractPublicKey();
    // final ahash = cryptor.sha256(hex.encode(mypublicKeyExchange.bytes));

    // We can now calculate a shared secret.
    final sharedSecret = await algorithm.sharedSecretKey(
      keyPair: mainKeyPair,
      remotePublicKey: bobPublicKey,
    );
    // final sharedSecretBytes = await sharedSecret.extractBytes();

    // final code = RecoveryKeyCode(id: ahash, key: hex.encode(sharedSecretBytes));
    // print("secret key bytes: ${sharedSecretBytes}");
    // print("secret key hex: ${hex.encode(sharedSecretBytes)}");
    // print("shared secret key hash: ${_sharedSecretKeyHash}");


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

    var modifiedDate = DateTime.now().toIso8601String();
    // var peer_uuid = cryptor.getUUID();

    final peerName = _peerNameTextController.text;
    final peerNotes = _notesTextController.text;
    final peerPubKey = _importedKeyDataTextController.text;
    // print("peerNotes: ${peerNotes}");

    /// we don't neet to re-encrypt key items
    ///
    // final encryptedName = await cryptor.encrypt(name);
    //
    // final encryptedNotes = await cryptor.encrypt(notes);
    // final encryptedKey = await cryptor.encrypt(hex.encode(_mainPrivKey));
    final encodedLength = utf8.encode(peerName).length + utf8.encode(peerNotes).length + utf8.encode(peerPubKey).length;
    settingsManager.doEncryption(encodedLength);

    final encryptedPeerName = await cryptor.encrypt(peerName);
    final encryptedPeerNotes = await cryptor.encrypt(peerNotes);
    // print("encryptedPeerNotes: ${encryptedPeerNotes}");

    var encryptedPeerPublicKey = "";

    // if (_isImportingManually) {
    //   print(
    //       "_importedKeyDataTextController.text: ${_importedKeyDataTextController
    //           .text}");
      encryptedPeerPublicKey =
      await cryptor.encrypt(peerPubKey);
      // print("encryptedPeerPublicKey: ${encryptedPeerPublicKey}");
    // } else {
    //   encryptedPeerPublicKey =
    //   await cryptor.encrypt(_scannedKeyDataTextController.text);
    // }
    final thisKey = _thisPeerPublicKey;

    if (thisKey == null) {
      return;
    }

    _modifiedDate = DateTime.now().toIso8601String();

    PeerPublicKey newPeerPublicKey = PeerPublicKey(
      id: widget.peerId,
      version: AppConstants.peerPublicKeyItemVersion,
      name: encryptedPeerName,
      key: encryptedPeerPublicKey,
      notes: encryptedPeerNotes,
      sentMessages: thisKey.sentMessages,
      receivedMessages: thisKey.receivedMessages, // TODO: add this back in
      cdate: (_thisPeerPublicKey?.cdate)!,
      mdate: _modifiedDate, //DateTime.now().toIso8601String(),
    );

    /// TODO: check peerPublicKey list and make sure we only save desired item
    ///
    // _peerPublicKeys.add(newPeerPublicKey);
    List<PeerPublicKey> tempPeers = [];
    for (var xpeer in _peerPublicKeys) {
      if (xpeer.id == widget.peerId) {
        tempPeers.add(newPeerPublicKey);

      } else {
        tempPeers.add(xpeer);
      }
    }

    _peerPublicKeys = tempPeers;

    var keyItem = KeyItem(
      id: widget.keyItem.id,
      keyId: keyManager.keyId,
      version: AppConstants.keyItemVersion,
      name: widget.keyItem.name,
      key: widget.keyItem.key,
      keyType: EnumToString.convertToString(EncryptionKeyType.asym),
      purpose: EnumToString.convertToString(KeyPurposeType.keyexchange),
      algo: EnumToString.convertToString(KeyExchangeAlgoType.x25519),
      notes: widget.keyItem.notes,
      favorite: widget.keyItem.favorite,
      isBip39: true,
      peerPublicKeys: _peerPublicKeys,
      tags: widget.keyItem.tags,
      mac: "",
      cdate: widget.keyItem.cdate,
      mdate: widget.keyItem.mdate,
    );

    final itemMac = await cryptor.hmac256(keyItem.toRawJson());
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
    final status = await keyManager.saveItem(widget.keyItem.id, genericItemString);

    // final status = true;

    if (status) {
      EasyLoading.showToast('Saved Item', duration: Duration(seconds: 1));

      setState(() {
        _mainKeyItem = keyItem;
        _isEditing = false;
      });

      await _refreshKeyData();

      // Navigator.of(context).pop('savedItem');
    } else {
      _showErrorDialog('Could not save the item.');
    }
  }


  void _showConfirmDeletePeerKeyDialog() {
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
              _confirmedDeletePeerKeyItem();
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmedDeletePeerKeyItem() async {

    final check = (widget.keyItem?.peerPublicKeys)!;
    List<PeerPublicKey> plist = [];
    for (var a in check) {
      /// gather peerKeys which we dont want to remove
      if (a.id != widget.peerId) {
        plist.add(a);
      }
    }

    var modifiedDate = DateTime.now().toIso8601String();

    var tempKeyItem = KeyItem(
      id: widget.keyItem.id,
      keyId: widget.keyItem.keyId,
      version: widget.keyItem.version,
      name: widget.keyItem.name,
      key: widget.keyItem.key,
      keyType: EnumToString.convertToString(EncryptionKeyType.asym),
      purpose: EnumToString.convertToString(KeyPurposeType.keyexchange),
      algo: EnumToString.convertToString(KeyExchangeAlgoType.x25519),
      notes: widget.keyItem.notes,
      favorite: widget.keyItem.favorite,
      isBip39: true,
      peerPublicKeys: plist,
      tags: _keyTags,
      mac: "",
      cdate: widget.keyItem.cdate,
      mdate: modifiedDate,
    );

    final itemMac = await cryptor.hmac256(tempKeyItem.toRawJson());
    tempKeyItem.mac = itemMac;

    final keyItemJson = tempKeyItem.toRawJson();
    // print("save add peer key keyItem.toRawJson: $keyItemJson");
    // print("save add peer key keyItem.toJson: ${tempKeyItem.toJson()}");

    final genericItem = GenericItem(type: "key", data: keyItemJson);
    // print('genericItem toRawJson: ${genericItem.toRawJson()}');

    final genericItemString = genericItem.toRawJson();
    // print("save key item genericItemString: $genericItemString");

    /// save key item in keychain
    ///
    final status = await keyManager.saveItem(widget.keyItem.id, genericItemString);

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
