import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import 'package:flutter/foundation.dart';
import 'package:elliptic/elliptic.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import '../helpers/AppConstants.dart';
import '../managers/Cryptor.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/KeychainManager.dart';
import '../models/RecoveryKeyCode.dart';
import '../models/DigitalIdentity.dart';
import '../models/DigitalIdentityCode.dart';
import '../models/MyDigitalIdentity.dart';
import '../models/VaultItem.dart';
import '../widgets/QRScanView.dart';
import '../widgets/qr_code_view.dart';
import '../screens/home_tab_screen.dart';


class RecoveryModeScreen extends StatefulWidget {
  const RecoveryModeScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/recovery_mode_screen';

  @override
  State<RecoveryModeScreen> createState() => _RecoveryModeScreenState();
}

class _RecoveryModeScreenState extends State<RecoveryModeScreen> {
  final _dialogIdentityNameTextFieldController = TextEditingController();
  final _importPublicKeyNameTextFieldController = TextEditingController();
  final _importPublicKeyDataTextFieldController = TextEditingController();

  FocusNode _dialogIdentityNameTextFieldFocusNode = FocusNode();

  bool _isDarkModeEnabled = false;
  bool _importFieldIsValid = false;
  bool _hasImportWarningMessage = false;
  bool _recoverModeEnabled = false;

  List<String> _decryptedPublicKeysS = [];
  List<String> _decryptedPublicKeysE = [];

  List<DigitalIdentity> _publicIds = [];
  List<DigitalIdentity> _decryptedPublicIdentities = [];

  List<String> _publicKeyHashes = [];
  List<String> _recoveryKeyIds = [];
  List<int> _matchingRecoveryKeyIndexes = [];

  MyDigitalIdentity? myIdentity;

  String _pubSigningKey = "";
  String _pubExchangeKeySeed = "";
  String _pubExchangeKeyPublic = "";
  String _pubExchangeKeyAddress = "";

  DigitalIdentityCode? _myCode;
  bool _enableBackupNameOkayButton = false;

  int _selectedIndex = 3;

  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _keyManager = KeychainManager();
  final _cryptor = Cryptor();


  @override
  void initState() {
    super.initState();

    _logManager.log("RecoveryModeScreen", "initState", "initState");

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;

    _recoverModeEnabled = _settingsManager.isRecoveryModeEnabled;

    _keyManager.getMyDigitalIdentity().then((value) async {
      // print("value: ${value!.toRawJson()}");

      myIdentity = value;
      if (value != null) {
        var ec = getS256();
        final algorithm_exchange = X25519();

        /// TODO: fix this
        final privateHexS = await _cryptor.decryptWithPadding(value.privKeySignature);
        _pubExchangeKeySeed = await _cryptor.decryptWithPadding(value.privKeyExchange);

        var privateSigningKey = PrivateKey(ec, BigInt.parse(privateHexS, radix: 16));
        final privSeedPair = await algorithm_exchange
            .newKeyPairFromSeed(hex.decode(_pubExchangeKeySeed));

        var pubExchange = await privSeedPair.extractPublicKey();

        setState(() {
          _pubSigningKey = base64.encode(hex.decode(privateSigningKey.publicKey.toCompressedHex()));
          _pubExchangeKeyPublic = base64.encode(pubExchange.bytes);
          _pubExchangeKeyAddress = _cryptor.sha256(_pubExchangeKeyPublic).substring(0,40);

          _myCode = DigitalIdentityCode(
            keyId: myIdentity!.keyId,
            pubKeyExchange: _pubExchangeKeyPublic,
            pubKeySignature: _pubSigningKey,
          );
        });
      }
    });

    fetchRecoveryIdentities();
  }

  /// recovery identities
  Future<void> fetchRecoveryIdentities() async {
    _publicKeyHashes = [];
    _decryptedPublicKeysS = [];
    _decryptedPublicKeysE = [];
    _decryptedPublicIdentities = [];

    final ids = await _keyManager.getIdentities();


    if (ids != null) {
      ids.sort((a, b) {
        return b.cdate.compareTo(a.cdate);
      });
      for (var id in ids) {
        // _logManager.logLongMessage(id.toRawJson());
        final xpub = await _cryptor.decryptWithPadding(id.pubKeySignature);
        final ypub = await _cryptor.decryptWithPadding(id.pubKeyExchange);
        final dname = await _cryptor.decryptWithPadding(id.name);
        final dkeyId = await _cryptor.decryptWithPadding(id.keyId);

        var digitalIdentity = DigitalIdentity(
            id: id.id,
            keyId: dkeyId,
            index: id.index,
            name: dname,
            version: id.version,
            pubKeyExchange: ypub,
            pubKeySignature: xpub,
            mac: "",
            cdate: id.cdate,
            mdate: id.mdate,
        );

        final identityMac = await _cryptor.hmac256(digitalIdentity.toRawJson());
        digitalIdentity.mac = identityMac;

        _decryptedPublicIdentities.add(digitalIdentity);

        /// hash of public exchange key
        final phash = _cryptor.sha256(ypub);
        // print("phash identity: $phash");
        _publicKeyHashes.add(phash);

        if (AppConstants.debugKeyData) {
          _logManager.logger.d("decrypt identity:\nx: $xpub\ny: $ypub");
        }

        setState(() {
          _decryptedPublicKeysS.add(xpub);
          _decryptedPublicKeysE.add(ypub);
        });
      }
      setState(() {
        _publicIds = ids!;
      });
    }

    _matchingRecoveryKeyIndexes = [];
    _recoveryKeyIds = [];
    final recoveryKeys = await _keyManager.getRecoveryKeyItems();
    // print("recovery items: ${recoveryKeys?.length}: ${recoveryKeys!.first.toJson()}");

    if (recoveryKeys != null) {
      for (var rkey in recoveryKeys) {
        _recoveryKeyIds.add(rkey.id);
      }
    }

    for (var recoveryId in _recoveryKeyIds) {
      if (_publicKeyHashes.contains(recoveryId)) {
        // print("contains recoveryId: $recoveryId");
        _matchingRecoveryKeyIndexes.add(_publicKeyHashes.indexOf(recoveryId));
      }
    }
    // print("_matchingRecoveryKeyIndexes: $_matchingRecoveryKeyIndexes");

    setState(() {});

  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? (Platform.isAndroid ? (AppConstants.useMaterial3 ? Colors.black12 : Colors.black54) : (AppConstants.useMaterial3 ? Colors.black12 : Colors.black54)) : Colors.white70, //Colors.blue[50],//Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Recovery Mode",
          style: TextStyle(
            color: _isDarkModeEnabled ? Colors.white : Colors.white,
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : Colors.blueAccent,
        leading: BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
                Icons.camera,
            ),
            color: _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
            onPressed: () async {
              _settingsManager.setIsScanningQRCode(true);
              await _scanQR(context);
            },
          ),
          // Visibility(
          //   visible: false,
          //   child: IconButton(
          //   icon: Icon(Icons.import_export),
          //   color: _isDarkModeEnabled ? Colors.greenAccent : null,
          //   onPressed: () async {
          //     _showModalImportPublicKeyView();
          //   },
          // ),),
        ],
      ),
      body: ListView.separated(
        itemCount: _publicIds.length + 1,
        separatorBuilder: (context, index) => Divider(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
        ),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Card(
              elevation: 2,
              color: _isDarkModeEnabled ? Colors.black54 : Colors.white,
              child: Column(children: [
                Padding(
                    padding: EdgeInsets.all(4),
                  child: ListTile(
                    title: Text(
                        "Enable Recovery Mode",
                      style: TextStyle(
                        color: _isDarkModeEnabled ? Colors.white : Colors.black,
                      ),
                    ),
                    subtitle:  Padding(
                      padding: EdgeInsets.fromLTRB(0,4,4,4),
                      child: Text(
                      "This allows you to scan recovery keys from the login page.",
                      style: TextStyle(
                        color: Colors.grey[500],
                      ),
                    ),),
                    trailing: Switch(
                      thumbColor:
                      MaterialStateProperty.all<Color>(Colors.white),
                      trackColor: _recoverModeEnabled ? (_isDarkModeEnabled
                          ? MaterialStateProperty.all<Color>(
                          Colors.greenAccent)
                          : MaterialStateProperty.all<Color>(
                          Colors.blue)) : MaterialStateProperty.all<Color>(
                          Colors.grey),
                      value: _recoverModeEnabled,
                      onChanged: (value){
                        setState(() {
                          _recoverModeEnabled = value;
                        });

                        _settingsManager.saveRecoveryModeEnabled(value);
                      },
                    ),
                  ),
                ),
                Divider(
                  color: Colors.grey,
                ),
                ListTile(
                  title: Padding(
                    padding: EdgeInsets.fromLTRB(0, 4, 4, 4),
                    child: Text(
                      'My Digital Identity',
                      style: TextStyle(
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                    ),
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.fromLTRB(0, 4, 4, 4),
                    child: Text(
                      "Public Address:\n$_pubExchangeKeyAddress",
                      style: TextStyle(
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                    ),
                  ),
                  leading: Icon(
                    Icons.perm_identity,
                    color: _isDarkModeEnabled
                        ? Colors.greenAccent
                        : Colors.blueAccent,
                    size: 40,
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.qr_code),
                    color: _isDarkModeEnabled
                        ? Colors.greenAccent
                        : Colors.blueAccent,
                    onPressed: () {
                      if (_myCode != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QRCodeView(
                              data: _myCode!.toRawJson(),
                              isDarkModeEnabled: _isDarkModeEnabled,
                              isEncrypted: false,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  onTap: () {
                    _displayMyIdentityInfo();
                  },
                ),
              ],),
            );
          } else {
            return Card(
              elevation: 2,
              color: _isDarkModeEnabled ? Colors.black54 : Colors.white,
              child: Column(
                children: [
                  ListTile(
                    title: Padding(
                      padding: EdgeInsets.fromLTRB(0, 4, 4, 4),
                      child: Text(
                        'Name: ${_decryptedPublicIdentities[index - 1].name}',
                        style: TextStyle(
                          color: _isDarkModeEnabled ? Colors.white : null,
                        ),
                      ),
                    ),
                    subtitle: Padding(
                      padding: EdgeInsets.fromLTRB(0, 4, 4, 8),
                      child: Text(
                        "Address: ${_publicKeyHashes[index-1].substring(0, 32)}\nkeyID: ${_decryptedPublicIdentities[index-1].keyId}",
                        style: TextStyle(
                          color: _isDarkModeEnabled ? Colors.white : null,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    onTap: () {
                      _displayIdentityInfo(
                          _decryptedPublicKeysE[index - 1],
                          _decryptedPublicKeysS[index - 1],
                        _publicIds[index-1].index,
                      );
                    },
                  ),
                  Card(
                    elevation: 1,
                    color: _isDarkModeEnabled ? Colors.black54 : Colors.white,
                    child: Row(
                      children: [
                        // Spacer(),
                        // IconButton(
                        //   icon: Icon(
                        //     Icons.info,
                        //     color: _isDarkModeEnabled
                        //         ? Colors.greenAccent
                        //         : Colors.blueAccent,
                        //   ),
                        //   onPressed: () {
                        //     _displayIdentityInfo(
                        //         _decryptedPublicKeysE[index - 1],
                        //         _decryptedPublicKeysS[index - 1],
                        //       _publicIds[index-1].index,
                        //     );
                        //   },
                        // ),
                        Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.social_distance,
                            color: _isDarkModeEnabled
                                ? (_matchingRecoveryKeyIndexes
                                        .contains(index - 1)
                                    ? Colors.redAccent
                                    : Colors.greenAccent)
                                : (_matchingRecoveryKeyIndexes
                                .contains(index - 1)
                                ? Colors.redAccent
                                : Colors.blueAccent),
                          ),
                          onPressed: () {
                            if (_matchingRecoveryKeyIndexes
                                .contains(index - 1)) {
                              _showDeleteRecoveryKeyDialog(
                                  _cryptor
                                      .sha256(_decryptedPublicKeysE[index - 1]),
                                  index - 1);
                            } else {
                              _showAddRecoveryKeyDialog(
                                  _decryptedPublicKeysE[index - 1],
                                  1,
                              );
                            }
                          },
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.password,
                            color: _isDarkModeEnabled
                                ? Colors.greenAccent
                                : Colors.blueAccent,
                          ),
                          onPressed: () {
                            _computeAndShowRecoveryCode(_decryptedPublicIdentities[index - 1]);
                          },
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: _isDarkModeEnabled
                                ? Colors.redAccent
                                : Colors.redAccent,
                          ),
                          onPressed: () async {
                            _showDeleteIdentityDialog(
                                _publicIds[index - 1].id,
                                _publicKeyHashes[index - 1],
                            );
                          },
                        ),
                        Spacer(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        },
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

  _computeAndShowRecoveryCode(DigitalIdentity identity) async {
    final algorithm = X25519();

    // print("bob pubKeyExchange: $bobPubKey");
    // final pubBytes = hex.decode(identity.pubKeyExchange);
    final pubBytes = base64.decode(identity.pubKeyExchange);

    // print("bob pubBytes: $pubBytes");

    final bobPublicKey = SimplePublicKey(pubBytes, type: KeyPairType.x25519);
    // print('bobKeyPair pubMade: ${bobPublicKey.bytes}');
    // print('bobKeyPair pubMade.Hex: ${hex.encode(bobPublicKey.bytes)}');

    final aliceSeed = _pubExchangeKeySeed;
    final seedBytes = hex.decode(aliceSeed);
    final privSeedPair = await algorithm.newKeyPairFromSeed(seedBytes);

    final mypublicKeyExchange = await privSeedPair.extractPublicKey();
    final ahash = _cryptor.sha256(base64.encode(mypublicKeyExchange.bytes));

    // We can now calculate a shared secret.
    final sharedSecret = await algorithm.sharedSecretKey(
      keyPair: privSeedPair,
      remotePublicKey: bobPublicKey,
    );
    final sharedSecretBytes = await sharedSecret.extractBytes();
    // final secretKey = SecretKey(sharedSecretBytes);

    // final ikey_recovery = await _cryptor.keyedHmac256("${identity.index}", sharedSecret);
    // _logManager.logger.d('Shared secret: ${sharedSecretBytes.length}: ${sharedSecretBytes}');
    // _logManager.logger.d('Shared ikey_recovery: ${identity.index}: ${ikey_recovery}');


    // final secretIndexKey = SecretKey(hex.decode(ikey_recovery));
    // final secretIndexKeyBytes = await secretIndexKey.extractBytes();

    final recoveryCode = RecoveryKeyCode(
      id: ahash,
      keyId: identity.keyId,
      key: base64.encode(sharedSecretBytes),
    );
    _logManager.logger.d("recoveryCode key: ${recoveryCode.toRawJson()}");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRCodeView(
          data: recoveryCode.toRawJson(),
          isDarkModeEnabled: _isDarkModeEnabled,
          isEncrypted: false,
        ),
      ),
    );
  }


  void _displayMyIdentityInfo() async {
    /// show modal bottom sheet
    showModalBottomSheet(
        backgroundColor: _isDarkModeEnabled ? Colors.black : null,
        context: context,
        isScrollControlled: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        builder: (context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter state) {
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: _isDarkModeEnabled
                              ? BorderSide(color: Colors.greenAccent)
                              : BorderSide(color: Colors.blueAccent),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          "Close",
                          style: TextStyle(
                            color: _isDarkModeEnabled
                                ? Colors.greenAccent
                                : Colors.blueAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  color: _isDarkModeEnabled ? Colors.greenAccent : null,
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      "publicKeyExchange: ${_pubExchangeKeyPublic}\n\ndate: ${(myIdentity?.cdate)!}",
                      // "name: ${item.name}\nid: ${item.id}\ndeviceId: ${item.deviceId}\ncreated: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse(item.cdate))}\nmodified: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse(item.mdate))}\nCurrent Vault: ${(item.encryptedKey.keyMaterial == _keyManager.encryptedKeyMaterial)}",
                      style: TextStyle(
                        color: _isDarkModeEnabled ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
                Divider(
                  color: _isDarkModeEnabled ? Colors.greenAccent : null,
                ),
                Row(
                  children: [
                    Spacer(),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: _isDarkModeEnabled
                            ? BorderSide(color: Colors.greenAccent)
                            : BorderSide(color: Colors.blueAccent),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();

                        if (_myCode != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QRCodeView(
                                data: _myCode!.toRawJson(),
                                isDarkModeEnabled: _isDarkModeEnabled,
                                isEncrypted: false,
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(
                        "Show Code",
                        style: TextStyle(
                          color: _isDarkModeEnabled
                              ? Colors.greenAccent
                              : Colors.blueAccent,
                        ),
                      ),
                    ),
                    Spacer(),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: _isDarkModeEnabled
                            ? BorderSide(color: Colors.greenAccent)
                            : BorderSide(color: Colors.blueAccent),
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop();

                        await Clipboard.setData(
                            ClipboardData(text: _pubExchangeKeyPublic));

                        EasyLoading.showToast('Copied Public Key',
                            duration: Duration(milliseconds: 500));
                      },
                      child: Text(
                        "Copy Public Key",
                        style: TextStyle(
                          color: _isDarkModeEnabled
                              ? Colors.greenAccent
                              : Colors.blueAccent,
                        ),
                      ),
                    ),
                    Spacer(),
                  ],
                )
              ],
            );
          });
        });
  }

  void _displayIdentityInfo(String pubE, String pubS, int keyIndex) async {
    /// show modal bottom sheet
    showModalBottomSheet(
        backgroundColor: _isDarkModeEnabled ? Colors.black : null,
        context: context,
        isScrollControlled: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        builder: (context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter state) {
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: _isDarkModeEnabled
                              ? BorderSide(color: Colors.greenAccent)
                              : BorderSide(color: Colors.blueAccent),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          "Close",
                          style: TextStyle(
                            color: _isDarkModeEnabled
                                ? Colors.greenAccent
                                : Colors.blueAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  color: _isDarkModeEnabled ? Colors.greenAccent : null,
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      "publicKeyExchange: ${pubE}\n\npublicKeySigning: ${pubS}\nkeyIndex: $keyIndex",
                      style: TextStyle(
                        color: _isDarkModeEnabled ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
                Divider(
                  color: _isDarkModeEnabled ? Colors.greenAccent : null,
                ),
                Row(
                  children: [
                    Spacer(),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: _isDarkModeEnabled
                            ? BorderSide(color: Colors.greenAccent)
                            : BorderSide(color: Colors.blueAccent),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();

                        _logManager.logger.d("pubE: $pubE");
                        final identity = DigitalIdentityCode(
                            keyId: _keyManager.keyId,
                            pubKeyExchange: pubE,
                            pubKeySignature: pubS,
                            // intermediateKey: intKey,
                        );

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QRCodeView(
                                data: identity!.toRawJson(),
                                isDarkModeEnabled: _isDarkModeEnabled,
                                isEncrypted: false,
                              ),
                            ),
                          );
                      },
                      child: Text(
                        "Show Code",
                        style: TextStyle(
                          color: _isDarkModeEnabled
                              ? Colors.greenAccent
                              : Colors.blueAccent,
                        ),
                      ),
                    ),
                    Spacer(),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: _isDarkModeEnabled
                            ? BorderSide(color: Colors.greenAccent)
                            : BorderSide(color: Colors.blueAccent),
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop();

                        await Clipboard.setData(ClipboardData(text: pubE));

                        EasyLoading.showToast('Copied',
                            duration: Duration(milliseconds: 500));
                      },
                      child: Text(
                        "Copy Public Key",
                        style: TextStyle(
                          color: _isDarkModeEnabled
                              ? Colors.greenAccent
                              : Colors.blueAccent,
                        ),
                      ),
                    ),
                    Spacer(),
                  ],
                )
              ],
            );
          });
        });
  }


  Future<void> _scanQR(BuildContext context) async {

    if (Platform.isIOS) {
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
          DigitalIdentityCode item =
          DigitalIdentityCode.fromRawJson(barcodeScanRes);
          if (item != null) {
            _displaySaveIdentityNameDialog(context, item);
          } else {
            _showErrorDialog("Invalid code format");
          }
        } catch (e) {
          /// decide to decrypt or save item.
          _showErrorDialog("Exception: Could not scan code: $e");
        }
      } on PlatformException {
        barcodeScanRes = "Failed to get platform version.";
        _logManager.logger.w("Platform exception");
      }
    } else if (Platform.isAndroid) {

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context)
            .push(MaterialPageRoute(
          builder: (context) => QRScanView(),
        ))
            .then((value) {

              print("value obtained: $value");
          _settingsManager.setIsScanningQRCode(false);

          try {
            DigitalIdentityCode item =
            DigitalIdentityCode.fromRawJson(value);

            if (item != null) {
              _displaySaveIdentityNameDialog(context, item);
            } else {
              _showErrorDialog("Invalid code format");
            }
          } catch (e) {
            _showErrorDialog("Exception: Could not scan code: $e");
          }
        });
      });

    }
  }

  Future<void> _saveScannedIdentity(
      DigitalIdentityCode item, String name) async {
    final createDate = DateTime.now();
    final uuid = _cryptor.getUUID();

    final pubS = item.pubKeySignature;
    final pubE = item.pubKeyExchange;
    // final intKey = item.intermediateKey;

    _logManager.log(
        "RecoveryModeScreen", "_saveScannedIdentity", "identity:{E: $pubE}");

    /// Encrypt password here
    final encryptedPubS = await _cryptor.encryptWithPadding(pubS);
    final encryptedPubE = await _cryptor.encryptWithPadding(pubE);
    final encryptedName = await _cryptor.encryptWithPadding(name);
    final encryptedKeyId = await _cryptor.encryptWithPadding(item.keyId);

    // final encryptedIntKey = await _cryptor.encryptWithPadding(intKey);

    /// TODO: save encrypted block number with encryption
    /// TODO: change to encryptParams method for object
    var identity = DigitalIdentity(
      id: uuid,
      keyId: encryptedKeyId,
      index: 1,
      version: AppConstants.digitalIdentityVersion,
      name: encryptedName,
      pubKeySignature: encryptedPubS,
      pubKeyExchange: encryptedPubE,
      mac: "",
      cdate: createDate.toIso8601String(),
      mdate: createDate.toIso8601String(),
    );

    final identityMac = await _cryptor.hmac256(identity.toRawJson());
    identity.mac = identityMac;

    final identityObjectString = identity.toRawJson();
    print("identityObjectString: $identityObjectString");

    final statusId = await _keyManager.saveIdentity(uuid, identityObjectString);

    if (statusId) {
      await fetchRecoveryIdentities();
      EasyLoading.showToast("Saved Scanned Item");
    } else {
      _showErrorDialog("Could not save scanned item");
    }
  }

  Future<void> _createRecoveryKey(String pubKeyExchange, String keyId) async {
    final algorithm = X25519();

    // final pubBytes = hex.decode(pubKeyExchange);
    final pubBytes = base64.decode(pubKeyExchange);

    // print("pubBytes: $pubBytes");

    final bobPublicKey = SimplePublicKey(pubBytes, type: KeyPairType.x25519);

    final aliceSeed = _pubExchangeKeySeed;
    final seedBytes = hex.decode(aliceSeed);
    final privSeedPair = await algorithm.newKeyPairFromSeed(seedBytes);

    // We can now calculate a shared secret.
    final sharedSecret = await algorithm.sharedSecretKey(
      keyPair: privSeedPair,
      remotePublicKey: bobPublicKey,
    );
    final sharedSecretBytes = await sharedSecret.extractBytes();
    
    // final indexedNonce = ivHelper().convertToBytes(keyIndex, 16);
    // final indexedSharedSecret = await _cryptor.keyedHmac256_2(hex.encode(indexedNonce), sharedSecret);
    // _logManager.logger.d('indexedNonce: ${indexedNonce.length}: ${indexedNonce}');
    // _logManager.logger.d('Shared ikey_recovery: ${keyIndex}: ${ikey_recovery}');

    final sharedSecretKey = SecretKey(sharedSecretBytes);
    // final secretIndexKey = SecretKey(hex.decode(sharedSecretBytes));

    final rootKey = _cryptor.aesRootSecretKeyBytes;

    final encryptedRootKey = await _cryptor.encryptRecoveryKey(sharedSecretKey, rootKey);
    final encryptedKeyId = await _cryptor.encryptWithPadding(keyId);
    _logManager.logger.d('encryptedRootKey:[${encryptedRootKey.length}]: ${encryptedRootKey}');
    _logManager.logger.d('encryptedKeyId:[${encryptedKeyId.length}]: ${encryptedKeyId}');

    final pubKeyHash = _cryptor.sha256(pubKeyExchange);
    _publicKeyHashes.add(pubKeyHash);

    final recoveryKey = RecoveryKey(
      id: pubKeyHash,
      keyId: encryptedKeyId,
      data: encryptedRootKey,
      cdate: DateTime.now().toIso8601String(),
    );
    
    _logManager.logger.d("recoveryKey: ${recoveryKey.toRawJson()}");

    await _keyManager.saveRecoveryKey(pubKeyHash, recoveryKey.toRawJson());

    await fetchRecoveryIdentities();
  }



  _displaySaveIdentityNameDialog(
      BuildContext context, DigitalIdentityCode item) async {
    return showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              title: Text('Recovery Identity Name'),
              actions: <Widget>[
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _dialogIdentityNameTextFieldController.text = '';
                      _enableBackupNameOkayButton = false;
                    });

                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _enableBackupNameOkayButton
                      ? () async {
                          _saveScannedIdentity(item,
                                  _dialogIdentityNameTextFieldController.text)
                              .then((value) {
                            EasyLoading.showToast("Saved Recovery Item");
                          });

                          setState(() {
                            _dialogIdentityNameTextFieldController.text = '';
                            _enableBackupNameOkayButton = false;
                          });

                          Navigator.of(context).pop();
                        }
                      : null,
                  child: Text('Save'),
                ),
              ],
              content: TextField(
                decoration: InputDecoration(
                  hintText: "Identity Name",
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _enableBackupNameOkayButton = true;
                    });
                  } else {
                    setState(() {
                      _enableBackupNameOkayButton = false;
                    });
                  }
                },
                controller: _dialogIdentityNameTextFieldController,
                focusNode: _dialogIdentityNameTextFieldFocusNode,
              ),
            );
          });
        });
  }

  void _showAddRecoveryKeyDialog(String pubKeyExchange, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Recovery Key"),
        content: Text("Add Recovery Key for this Identity?"),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await _createRecoveryKey(pubKeyExchange, _decryptedPublicIdentities[index-1].keyId);

              Navigator.of(ctx).pop();
            },
            child: Text("Add Recovery Key"),
          ),
        ],
      ),
    );
  }

  void _showDeleteRecoveryKeyDialog(String id, int index) {
    showDialog(
      context: context,
      // barrierColor: Colors.black,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Recovery Key"),
        content: Text("Are you sure you want to delete the Recovery Key for this Backup?"),
        actions: <Widget>[
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ButtonStyle(
                foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
              backgroundColor: MaterialStateProperty.all<Color>(Colors.red),
            ),
            onPressed: () async {
              // print("delete recovery key");

              final status = await _keyManager.deleteRecoveryKeyItem(id);
              // _createRecoveryKey(pubKeyExchange);
              print("deleteRecoveryKeyItem-dialog-status: $status");
              if (status) {
                setState(() {
                  var idx = 0;
                  for (var m in _matchingRecoveryKeyIndexes) {
                    if (m == index) {
                      break;
                    }
                    idx += 1;
                  }
                  _matchingRecoveryKeyIndexes.removeAt(idx);
                });
              }

              Navigator.of(ctx).pop();
            },
            child: Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showDeleteIdentityDialog(String id, String pubHash) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Identity"),
        content: Text("Are you sure you want to delete this identity?\n\nThis will also delete the Recovery Key for this identity if it is available."),
        actions: <Widget>[
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor:
              MaterialStateProperty.all<Color>(Colors.redAccent),
            ),
            onPressed: () async {
              // print("delete identity");
              Navigator.of(ctx).pop();

              final statusRecovery = await _keyManager.deleteRecoveryKeyItem(pubHash);

              final statusID = await _keyManager.deleteIdentity(id);

              if (!statusID){
                _logManager.logger.w("Could not delete identity with id: $id");

              }

              if (!statusRecovery){
                _logManager.logger.w("Could not delete recovery key with pubHash: $pubHash");
              }

              await fetchRecoveryIdentities();
              },
            child: Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Error"),
        content: Text(message),
        actions: <Widget>[
          ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: Text("Okay"))
        ],
      ),
    );
  }

}
