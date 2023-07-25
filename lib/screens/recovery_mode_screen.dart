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

import '../models/RecoveryKeyCode.dart';
import '../helpers/AppConstants.dart';
import '../managers/Cryptor.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/KeychainManager.dart';
import '../models/DigitalIdentity.dart';
import '../models/DigitalIdentityCode.dart';
import '../models/MyDigitalIdentity.dart';
import '../models/VaultItem.dart';
import '../widgets/QRScanView.dart';
import '../widgets/qr_code_view.dart';
import '../screens/home_tab_screen.dart';

/// show this BIP39 mnemonic as a numbered word list

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
  // bool _isRecoveryModeEnabled = false;

  bool _importFieldIsValid = false;
  bool _hasImportWarningMessage = false;

  List<String> _decryptedPublicKeysS = [];
  List<String> _decryptedPublicKeysE = [];

  List<DigitalIdentity> _publicIds = [];
  List<String> _publicKeyHashes = [];
  List<String> _recoveryKeyIds = [];
  List<int> _matchingRecoveryKeyIndexes = [];

  MyDigitalIdentity? myIdentity;

  String pubSigningKey = "";
  String pubExchangeKeySeed = "";
  String pubExchangeKeyPublic = "";

  DigitalIdentityCode? _myCode;
  bool _enableBackupNameOkayButton = false;

  int _selectedIndex = 3;

  final logManager = LogManager();
  final settingsManager = SettingsManager();
  final keyManager = KeychainManager();
  final cryptor = Cryptor();

  @override
  void initState() {
    super.initState();

    logManager.log("RecoveryModeScreen", "initState", "initState");

    _isDarkModeEnabled = settingsManager.isDarkModeEnabled;

    keyManager.hasRecoveryKeyItems().then((value) {

    });

    keyManager.getMyDigitalIdentity().then((value) async {
      // print("value: ${value!.toRawJson()}");

      myIdentity = value;
      if (value != null) {
        var ec = getS256();
        final algorithm_exchange = X25519();

        /// TODO: fix this
        final privateHexS = await cryptor.decrypt(value.privKeySignature);
        pubExchangeKeySeed = await cryptor.decrypt(value.privKeyExchange);

        var privS = PrivateKey(ec, BigInt.parse(privateHexS, radix: 16));
        final privSeedPair = await algorithm_exchange
            .newKeyPairFromSeed(hex.decode(pubExchangeKeySeed));

        var pubE = await privSeedPair.extractPublicKey();

        setState(() {
          pubSigningKey = privS.publicKey.toHex();
          pubExchangeKeyPublic = hex.encode(pubE.bytes);

          _myCode = DigitalIdentityCode(
            pubKeyExchange: pubExchangeKeyPublic,
            pubKeySignature: pubSigningKey,
          );
        });
      }
    });

    fetchIdentities();
  }

  Future<void> fetchIdentities() async {
    _publicKeyHashes = [];
    _decryptedPublicKeysS = [];
    _decryptedPublicKeysE = [];

    final ids = await keyManager.getIdentities();

    if (ids != null) {
      ids.sort((a, b) {
        return b.cdate.compareTo(a.cdate);
      });
      for (var id in ids) {
        /// TODO: fix this
        final xpub = await cryptor.decrypt(id.pubKeySignature);
        final ypub = await cryptor.decrypt(id.pubKeyExchange);
        // final z = await cryptor.decrypt(id.intermediateKey);

        final phash = cryptor.sha256(ypub);
        // print("phash identity: $phash");

        _publicKeyHashes.add(phash);

        if (AppConstants.debugKeyData) {
          logManager.logger.d("decrypt identity:\nx: $xpub\ny: $ypub");
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
    final recoveryKeys = await keyManager.getRecoveryKeyItems();
    // print("recovery items: ${recoveryKeys?.length}: $recoveryKeys");

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
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text('Recovery Mode'),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
                Icons.camera,
            ),
            color: _isDarkModeEnabled ? Colors.greenAccent : null,
            onPressed: () async {
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
            },
          ),
          IconButton(
            icon: Icon(Icons.import_export),
            color: _isDarkModeEnabled ? Colors.greenAccent : null,
            onPressed: () async {
              // settingsManager.setIsScanningQRCode(true);
              //   print("import public key");
              _showModalImportPublicKeyView();
              //   Uri sms = Uri.parse('sms:13147759429');
              //   Uri sms = Uri.parse('tel:13147759429');
              //   Uri sms = Uri.parse('file:');
              //   Uri sms = Uri.parse('${FileManager().localPath}');
              // Uri sms = Uri.parse('mailto:jspinner.deveng@gmail.com?subject=hello');
              //
              //   // launch
              //   if (await launchUrl(sms)) {
              //     //app opened
              //   }else{
              //     //app is not opened
              //   }
            },
          ),
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
              elevation: 4,
              color: _isDarkModeEnabled ? Colors.black54 : Colors.white,
              child: ListTile(
                visualDensity: VisualDensity(vertical: 4),
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
                    "pubKey: $pubExchangeKeyPublic",
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
            );
          } else {
            return Card(
              elevation: 4,
              color: _isDarkModeEnabled ? Colors.black54 : Colors.white,
              child: Column(
                children: [
                  ListTile(
                    // visualDensity: VisualDensity(vertical: 4),
                    title: Padding(
                      padding: EdgeInsets.fromLTRB(0, 4, 4, 4),
                      child: Text(
                        'Name: ${_publicIds[index - 1].name}',
                        style: TextStyle(
                          color: _isDarkModeEnabled ? Colors.white : null,
                        ),
                      ),
                    ),
                    subtitle: Padding(
                      padding: EdgeInsets.fromLTRB(0, 4, 4, 8),
                      child: Text(
                        "pubKeyExchange: ${_decryptedPublicKeysE[index - 1]}\n\nid: ${cryptor.sha256(_decryptedPublicKeysE[index - 1])}",
                        style: TextStyle(
                          color: _isDarkModeEnabled ? Colors.white : null,
                        ),
                      ),
                    ),
                    onTap: () {
                      _displayIdentityInfo(
                          _decryptedPublicKeysE[index - 1],
                          _decryptedPublicKeysS[index - 1],
                      );
                    },
                  ),
                  Card(
                    elevation: 1,
                    color: _isDarkModeEnabled ? Colors.black54 : Colors.white,
                    child: Row(
                      children: [
                        Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.info,
                            color: _isDarkModeEnabled
                                ? Colors.greenAccent
                                : Colors.blueAccent,
                          ),
                          onPressed: () {
                            _displayIdentityInfo(
                                _decryptedPublicKeysE[index - 1],
                                _decryptedPublicKeysS[index - 1],
                            );
                          },
                        ),
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
                                  cryptor
                                      .sha256(_decryptedPublicKeysE[index - 1]),
                                  index - 1);
                            } else {
                              _showAddRecoveryKeyDialog(
                                  _decryptedPublicKeysE[index - 1],
                                  (index - 1),
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
                            _computeAndShowRecoveryCode(_decryptedPublicKeysE[index - 1]);
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

    settingsManager.changeRoute(index);
  }

  _computeAndShowRecoveryCode(String bobPubKey) async {
    final algorithm = X25519();

    // print("bob pubKeyExchange: $bobPubKey");
    final pubBytes = hex.decode(bobPubKey);
    // print("bob pubBytes: $pubBytes");

    final bobPublicKey = SimplePublicKey(pubBytes, type: KeyPairType.x25519);
    // print('bobKeyPair pubMade: ${bobPublicKey.bytes}');
    // print('bobKeyPair pubMade.Hex: ${hex.encode(bobPublicKey.bytes)}');

    final aliceSeed = pubExchangeKeySeed;
    final seedBytes = hex.decode(aliceSeed);
    final privSeedPair = await algorithm.newKeyPairFromSeed(seedBytes);

    final mypublicKeyExchange = await privSeedPair.extractPublicKey();
    final ahash = cryptor.sha256(hex.encode(mypublicKeyExchange.bytes));

    // We can now calculate a shared secret.
    final sharedSecret = await algorithm.sharedSecretKey(
      keyPair: privSeedPair,
      remotePublicKey: bobPublicKey,
    );
    final sharedSecretBytes = await sharedSecret.extractBytes();
    final code = RecoveryKeyCode(id: ahash, key: base64.encode(sharedSecretBytes));
    // print("secret key: ${hex.encode(sharedSecretBytes)}");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRCodeView(
          data: code.toRawJson(),
          isDarkModeEnabled: _isDarkModeEnabled,
          isEncrypted: false,
        ),
      ),
    );
  }

  _showModalImportPublicKeyView() async {
    showModalBottomSheet(
        backgroundColor: _isDarkModeEnabled ? Colors.blueGrey : null,
        elevation: 8,
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
                    height: 64,
                  ),
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: _isDarkModeEnabled
                            ? MaterialStateProperty.all<Color>(
                                Colors.greenAccent)
                            : null,
                      ),
                      child: Text(
                        "Close",
                        style: TextStyle(
                          color:
                              _isDarkModeEnabled ? Colors.black : Colors.white,
                        ),
                      ),
                      onPressed: () async {
                        FocusScope.of(context).unfocus();
                        state(() {
                          _importPublicKeyDataTextFieldController.text = "";
                          _importPublicKeyNameTextFieldController.text = "";
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: TextFormField(
                      cursorColor:
                          _isDarkModeEnabled ? Colors.greenAccent : null,
                      autocorrect: false,
                      obscureText: false,
                      minLines: 1,
                      // maxLines: _hidePasscodeField ? 1 : 8,
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
                      onChanged: (pwd) {
                        _validateField(state);
                      },
                      onTap: () {
                        _validateField(state);
                      },
                      onFieldSubmitted: (_) {
                        _validateField(state);
                      },
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.done,
                      controller: _importPublicKeyNameTextFieldController,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: TextFormField(
                      cursorColor:
                          _isDarkModeEnabled ? Colors.greenAccent : null,
                      autocorrect: false,
                      obscureText: false,
                      minLines: 1,
                      // maxLines: _hidePasscodeField ? 1 : 8,
                      decoration: InputDecoration(
                        labelText: 'Public Key (Hex)',
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
                        // prefixIcon: Icon(
                        //   Icons.security,
                        //   color: _isDarkModeEnabled ? Colors.grey : null,
                        // ),
                        // suffixIcon: IconButton(
                        //   icon: Icon(
                        //     Icons.remove_red_eye,
                        //     color: _hidePasscodeField
                        //         ? Colors.grey
                        //         : _isDarkModeEnabled
                        //         ? Colors.greenAccent
                        //         : Colors.blueAccent,
                        //   ),
                        //   onPressed: () {
                        //     setState(
                        //             () => _hidePasscodeField = !_hidePasscodeField);
                        //   },
                        // ),
                      ),
                      style: TextStyle(
                        fontSize: 18.0,
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                      onChanged: (pwd) {
                        _validateField(state);
                      },
                      onTap: () {
                        _validateField(state);
                      },
                      onFieldSubmitted: (_) {
                        _validateField(state);
                      },
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      // focusNode: _passwordFocusNode,
                      controller: _importPublicKeyDataTextFieldController,
                    ),
                  ),
                  Visibility(
                    visible: _hasImportWarningMessage,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        "Invalid Format",
                        style: TextStyle(
                          color:
                              _isDarkModeEnabled ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: _isDarkModeEnabled
                            ? MaterialStateProperty.all<Color>(
                                Colors.greenAccent)
                            : null,
                      ),
                      child: Text(
                        "Import",
                        style: TextStyle(
                          color:
                              _isDarkModeEnabled ? Colors.black : Colors.white,
                        ),
                      ),
                      onPressed: _importFieldIsValid
                          ? () async {
                              FocusScope.of(context).unfocus();

                              // print("import identity");

                              DigitalIdentityCode code = DigitalIdentityCode(
                                pubKeyExchange:
                                    _importPublicKeyDataTextFieldController
                                        .text,
                                pubKeySignature: "",
                              );

                              await _saveScannedIdentity(code,
                                  _importPublicKeyNameTextFieldController.text);

                              state(() {
                                _importPublicKeyDataTextFieldController.text =
                                    "";
                                _importPublicKeyNameTextFieldController.text =
                                    "";
                              });

                              Navigator.of(context).pop();
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            );
          });
        });
  }

  void _validateField(StateSetter state) {
    state(() {
      _importFieldIsValid = _importPublicKeyNameTextFieldController
              .text.isNotEmpty &&
          _importPublicKeyDataTextFieldController.text.isNotEmpty &&
          _importPublicKeyDataTextFieldController.text.length == 64 &&
          _importPublicKeyDataTextFieldController.text != pubExchangeKeyPublic;

      _hasImportWarningMessage = !_importFieldIsValid;
    });
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
                      "publicKeyExchange: ${pubExchangeKeyPublic}\n\ndate: ${(myIdentity?.cdate)!}",
                      // "name: ${item.name}\nid: ${item.id}\ndeviceId: ${item.deviceId}\ncreated: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse(item.cdate))}\nmodified: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse(item.mdate))}\nCurrent Vault: ${(item.encryptedKey.keyMaterial == keyManager.encryptedKeyMaterial)}",
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
                        // print("press: $_myCode");
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
                            ClipboardData(text: pubExchangeKeyPublic));

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
    //     .then((value) {
    //     print("Chose value: $value");
    //
    // });
  }

  void _displayIdentityInfo(String pubE, String pubS) async {
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
                      "publicKeyExchange: ${pubE}\n\npublicKeySigning: ${pubS}",
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

                        final identity = DigitalIdentityCode(
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

  _showDialogImportOptions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Choose An Import Option'),
        content: Text('Import a digital identity using the below options'),
        actions: <Widget>[
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: TextButton.styleFrom(
              primary: Colors.white,
            ),
            onPressed: () async {
              // _confirmDeleteLocalBackup();
              Navigator.of(ctx).pop();
            },
            child: Text('Input Manually'),
          ),
          ElevatedButton(
            style: TextButton.styleFrom(
              primary: Colors.white,
            ),
            onPressed: () async {
              // _confirmDeleteLocalBackup();
              Navigator.of(ctx).pop();
            },
            child: Text('Scan ID Code'),
          ),
        ],
      ),
    );
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
      logManager.logger.w("Platform exception");
    }
  }

  Future<void> _saveScannedIdentity(
      DigitalIdentityCode item, String name) async {
    final createDate = DateTime.now();
    final uuid = cryptor.getUUID();

    final pubS = item.pubKeySignature;
    final pubE = item.pubKeyExchange;
    // final intKey = item.intermediateKey;

    logManager.log(
        "RecoveryModeScreen", "_saveScannedIdentity", "identity:{E: $pubE}");

    /// Encrypt password here
    final encryptedPubS = await cryptor.encrypt(pubS);
    final encryptedPubE = await cryptor.encrypt(pubE);
    // final encryptedIntKey = await cryptor.encrypt(intKey);

    /// TODO: encrypt name in recovery key and decrypt
    final identity = DigitalIdentity(
      id: uuid,
      version: AppConstants.digitalIdentityVersion,
      name: name,
      pubKeySignature: encryptedPubS,
      pubKeyExchange: encryptedPubE,
      // intermediateKey: encryptedIntKey,
      cdate: createDate.toIso8601String(),
      mdate: createDate.toIso8601String(),
    );

    final identityObjectString = identity.toRawJson();
    // print("identityObjectString: $identityObjectString");

    final statusId = await keyManager.saveIdentity(uuid, identityObjectString);

    if (statusId) {
      await fetchIdentities();
      EasyLoading.showToast("Saved Scanned Item");
    } else {
      _showErrorDialog("Could not save scanned item");
    }
  }

  Future<void> _createRecoveryKey(String pubKeyExchange) async {
    /// get my identity keys
    ///
    /// get this identity keys
    ///
    /// create secret key
    ///
    /// encrypt with secret key
    ///
    /// save recovery key
    ///
    final algorithm = X25519();

    // print("pubKeyExchange: $pubKeyExchange");
    final pubBytes = hex.decode(pubKeyExchange);
    // print("pubBytes: $pubBytes");

    final bobPublicKey = SimplePublicKey(pubBytes, type: KeyPairType.x25519);
    // print('bobKeyPair pubMade: ${bobPublicKey.bytes}');
    // print('bobKeyPair pubMade.Hex: ${hex.encode(bobPublicKey.bytes)}');

    final aliceSeed = pubExchangeKeySeed;
    final seedBytes = hex.decode(aliceSeed);
    final privSeedPair = await algorithm.newKeyPairFromSeed(seedBytes);

    // We can now calculate a shared secret.
    final sharedSecret = await algorithm.sharedSecretKey(
      keyPair: privSeedPair,
      remotePublicKey: bobPublicKey,
    );
    final sharedSecretBytes = await sharedSecret.extractBytes();
    // print('Shared secret: ${sharedSecretBytes.length}: ${sharedSecretBytes}');

    final secretKeyData = SecretKey(sharedSecretBytes);

    final rootKey = cryptor
        .aesRootSecretKeyBytes; //cryptor.aesSecretKeyBytes + cryptor.authSecretKeyBytes;

    final encryptedKeys = await cryptor.encryptRecoveryKey(secretKeyData, rootKey);

    // print("encrypted Keys: $encryptedKeys");

    final pubKeyHash = cryptor.sha256(pubKeyExchange);
    // _publicKeyHashes.add(pubKeyHash);

    final recoveryKey = RecoveryKey(
      id: pubKeyHash,
      data: encryptedKeys,
      cdate: DateTime.now().toIso8601String(),
    );

    // print("recoveryKey: ${recoveryKey.toRawJson()}");

    // final status =
    await keyManager.saveRecoveryKey(pubKeyHash, recoveryKey.toRawJson());

    // print("recoveryKey status: ${status}");

    // if (status) {
    //   setState(() {
    //     _publicKeyHashes.add(pubKeyHash);
    //     _matchingRecoveryKeyIndexes.add(index);
    //   });
    // }

    await fetchIdentities();
  }

  _displaySaveIdentityNameDialog(
      BuildContext context, DigitalIdentityCode item) async {
    return showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              title: Text('Create Backup'),
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
                            EasyLoading.showToast("Saved Scanned Item");
                            // _updatePasswordItemList();
                          });
                          // await _createBackup().then((value) {
                          //
                          //   // _fetchBackups();
                          //
                          setState(() {
                            _dialogIdentityNameTextFieldController.text = '';
                            _enableBackupNameOkayButton = false;
                          });
                          //
                          Navigator.of(context).pop();
                          // });
                        }
                      : null,
                  child: Text('Save'),
                ),
              ],
              content: TextField(
                // obscureText: ,
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
            onPressed: () async {
              // print("add recovery key");

              await _createRecoveryKey(pubKeyExchange);

              // fetchIdentities();
              // setState(() {
              //   _matchingRecoveryKeyIndexes.add(index);
              // });

              Navigator.of(ctx).pop();
            },
            child: Text("Add Recovery Key"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text("Cancel"),
          ),
        ],
      ),
    );
  }

  void _showDeleteRecoveryKeyDialog(String id, int index) {
    showDialog(
      context: context,
      // useRootNavigator: true,
      // barrierColor: Colors.black,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Recovery Key"),
        content: Text("Are you sure you want to delete the Recovery Key for this Backup?"),
        actions: <Widget>[
          ElevatedButton(

            style: ButtonStyle(
                foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
              backgroundColor: MaterialStateProperty.all<Color>(Colors.red),
            ),
            onPressed: () async {
              // print("delete recovery key");

              final status = await keyManager.deleteRecoveryKeyItem(id);
              // _createRecoveryKey(pubKeyExchange);
              // print("deleteRecoveryKeyItem: $status");
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
            child: Text("Delete Key"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text("Cancel"),
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
        content: Text("Are you sure you want to delete this identity?"),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () async {
              // print("delete identity");

              final statusID = await keyManager.deleteIdentity(id);

              final statusRecovery = await keyManager.deleteRecoveryKeyItem(pubHash);

              if (!statusID){
                logManager.logger.w("Could not delete identity with id: $id");

              }

              if (!statusRecovery){
                logManager.logger.w("Could not delete recovery key with pubHash: $pubHash");
              }

              await fetchIdentities();

              Navigator.of(ctx).pop();
            },
            child: Text("Delete"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text("Cancel"),
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
