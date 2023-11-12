import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter/material.dart';

import '../helpers/AppConstants.dart';
import '../models/GenericItem.dart';
import '../models/KeyItem.dart';
import '../managers/LogManager.dart';
import '../managers/Cryptor.dart';
import '../managers/SettingsManager.dart';
import '../managers/KeychainManager.dart';
import '../screens/add_peer_public_key_screen.dart';

import 'edit_peer_public_key_screen.dart';
import 'home_tab_screen.dart';

/// Copied code from NoteListScreen

class PeerPublicKeyListScreen extends StatefulWidget {
  const PeerPublicKeyListScreen({
    Key? key,
    required this.id,
  }) : super(key: key);
  static const routeName = '/peer_public_key_list_screen';

  final String id;

  @override
  State<PeerPublicKeyListScreen> createState() => _PeerPublicKeyListScreenState();
}

class _PeerPublicKeyListScreenState extends State<PeerPublicKeyListScreen> {
  bool _isDarkModeEnabled = false;

  bool _hasPeerPublicKeys = false;

  List<int> _ownerPrivateKey = [];
  List<int> _ownerPublicKey = [];

  List<KeyItem> _keys = [];
  List<PeerPublicKey> _peerPublicKeys = [];
  List<PeerPublicKey> _peerPublicKeysShowing = [];

  KeyItem _keyItem = KeyItem(
    id: "",
    keyId: "",
    version: 0,
    name: "",
    key: "",
    keyType: "",
    purpose: "",
    algo: "",
    notes: "",
    favorite: false,
    isBip39: true,
    peerPublicKeys: [],
    tags: [],
    mac: "",
    cdate: "",
    mdate: "",
  );

  int _selectedIndex = 1;

  bool _hasForwaredScreenAlready = false;

  final _keyManager = KeychainManager();
  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _cryptor = Cryptor();

  @override
  void initState() {
    super.initState();

    _logManager.log("PeerPublicKeyListScreen", "initState", "initState");

    setState(() {
      _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;
      _selectedIndex = _settingsManager.currentTabIndex;
    });


    _getItem();
  }


  void _getItem() async {
    // _peerPublicKeys = [];
    // _peerPublicKeysShowing = [];

    /// get the password item and decrypt the data
    _keyManager.getItem(widget.id).then((value) async {
      final genericItem = GenericItem.fromRawJson(value);

      if (genericItem.type == "key") {
        // print("edit password: value: $value");

        /// must be a PasswordItem type
        _keyItem = KeyItem.fromRawJson(genericItem.data);

        if (_keyItem != null) {

          /// owner private key pair data...
          var keydata = (_keyItem?.key)!;
          // final keyIndex = (_keyItem?.keyIndex)!;
          // var keyIndex = 0;
          //
          // if (_keyItem?.keyIndex != null) {
          //   keyIndex = (_keyItem?.keyIndex)!;
          // }

          if (keydata == null) {
            return;
          }
          // print("keydata: ${keydata.length}: ${keydata}");

          // final keyType = (_keyItem?.keyType)!;


          /// decrypt root seed and expand
          final decryptedOwnerPrivateKey = await _cryptor.decrypt(keydata);
          // print("_getItem decryptedOwnerPrivateKey: ${decryptedOwnerPrivateKey.length}: ${decryptedOwnerPrivateKey}");


          /// TODO: switch encoding !
          // final decodedOwnerPrivateKey = hex.decode(decryptedOwnerPrivateKey);
          final decodedOwnerPrivateKey = base64.decode(decryptedOwnerPrivateKey);
          // print("_getItem decodedOwnerPrivateKey: ${decodedOwnerPrivateKey.length}: ${decodedOwnerPrivateKey}");

          // if (keyType == EnumToString.convertToString(EncryptionKeyType.asym)) {
          setState(() {
            _ownerPrivateKey = decodedOwnerPrivateKey;
          });

          final peerPublicKeys = (_keyItem?.peerPublicKeys)!;
          // print("_getItem peerPublicKeys: ${peerPublicKeys}");

          if (peerPublicKeys == null) {
            setState(() {
              _hasPeerPublicKeys = false;
              _peerPublicKeys = [];
            });

            if (!_hasForwaredScreenAlready) {
              /// autmatically go to add key screen
              Navigator.of(context)
                  .push(MaterialPageRoute(
                builder: (context) => AddPeerPublicKeyScreen(keyItem: _keyItem),
              ))
                  .then((value) {
                if (value == "savedItem") {
                  EasyLoading.showToast("Saved Key Item",
                      duration: Duration(seconds: 2));
                }

                setState(() {
                  _hasForwaredScreenAlready = true;
                });
                _getItem();
              });
            }

          } else {
            if (peerPublicKeys.isEmpty) {
              setState(() {
                _hasPeerPublicKeys = false;
                _peerPublicKeys = [];
              });

              if (!_hasForwaredScreenAlready) {
                /// automatically go to add key screen
                Navigator.of(context)
                    .push(MaterialPageRoute(
                  builder: (context) =>
                      AddPeerPublicKeyScreen(keyItem: _keyItem),
                ))
                    .then((value) {
                  if (value == "savedItem") {
                    EasyLoading.showToast("Saved Key Item",
                        duration: Duration(seconds: 2));
                  }
                  setState(() {
                    _hasForwaredScreenAlready = true;
                  });

                  _getItem();
                });
              }
            } else {
              setState(() {
                _hasPeerPublicKeys = true;
                _peerPublicKeys = [];
                _peerPublicKeysShowing = [];
              });

              for (var peerKey in peerPublicKeys) {
                // final da = await _cryptor.decrypt(peerKey.key);
                setState(() {
                  _peerPublicKeys.add(peerKey);
                });

                // final peerKeyIndex = (peerKey?.keyIndex)!;
                // var peerKeyIndex = 0;
                //
                // if (peerKey?.keyIndex != null) {
                //   peerKeyIndex = (peerKey?.keyIndex)!;
                // }
                /// decrypting public key (not private)
                // print("peerKey.key: ${peerKey.key.length}: ${peerKey.key}");

                final decryptedPeerPublicKeyData = await _cryptor.decrypt(peerKey.key);
                // print("decryptedPeerPublicKeyData: ${decryptedPeerPublicKeyData.length}: ${decryptedPeerPublicKeyData}");

                final decodedPeerPublicKeyData = base64.decode(decryptedPeerPublicKeyData);
                // print("decodedPeerPublicKeyData: ${decodedPeerPublicKeyData.length}: ${decodedPeerPublicKeyData}");
                // print("decodedPeerPublicKeyData: ${decodedPeerPublicKeyData.length}: ${hex.encode(decodedPeerPublicKeyData)}");

                final decryptedPeerPublicKeyName = await _cryptor.decrypt(peerKey.name);

                /// create a temp key
                PeerPublicKey tempPeerKey = PeerPublicKey(
                    id: peerKey.id,
                    version: AppConstants.peerPublicKeyItemVersion,
                    name: decryptedPeerPublicKeyName,
                    key: hex.encode(decodedPeerPublicKeyData),
                    // favorite: peerKey.favorite,
                    notes: peerKey.notes,
                    sentMessages: peerKey.sentMessages,
                    receivedMessages: peerKey.receivedMessages, // TODO: add this back in
                  // recievedMessages: peerKey.recievedMessages,
                    mdate: peerKey.mdate,
                    cdate: peerKey.cdate,
                );

                await _generatePeerKeyPair(decryptedPeerPublicKeyData);

                /// add temp key to list to show
                setState(() {
                  _peerPublicKeysShowing.add(tempPeerKey);
                });
              }

            }
          }


        }
      }
    });
  }


  Future<void> _generatePeerKeyPair(String bobPubString) async {
    // print("peer_public_key_list: _generatePeerKeyPair");

    if (_ownerPrivateKey == null) {
      return;
    }

    if (_ownerPrivateKey.isEmpty) {
      return;
    }

    final algorithm_exchange = X25519();

    // print("bobPubString: ${bobPubString.length}: ${bobPubString}");

    /// TODO: switch encoding !
    // final privKey = hex.decode(privateKeyString);
    // final privKey = base64.decode(privateKeyString);
    // print("privKey: ${privKey.length}: ${privKey}");

    // final ownerKeyPair = await algorithm_exchange.newKeyPairFromSeed(privKey);
    final ownerKeyPair = await algorithm_exchange.newKeyPairFromSeed(_ownerPrivateKey);

    // final privKey = await ownerKeyPair.extractPrivateKeyBytes();
    // print("privKeyBytes: ${privKey.length}: ${privKey}");

    // final bobPub = hex.decode(bobPubString);
    final bobPub = base64.decode(bobPubString);
    // print('peer Public Key: $bobPub');
    // print('peer Public Key hex: ${hex.encode(bobPub)}');

    final bobPublicKey = SimplePublicKey(bobPub, type: KeyPairType.x25519);

    try {
      final sharedSecret = await algorithm_exchange.sharedSecretKey(
        keyPair: ownerKeyPair,
        remotePublicKey: bobPublicKey,
      );

      final sharedSecretBytes = await sharedSecret.extractBytes();

      // print('Shared secret: $sharedSecretBytes');
      // print('Shared secret hex: ${hex.encode(sharedSecretBytes)}');

      final sharedSecretKeyHash = await _cryptor.sha256(
          hex.encode(sharedSecretBytes));
    } catch (e) {
      _logManager.logger.w("$e");
    }
    // print("shared secret key hash: ${sharedSecretKeyHash}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text('Peer Public Keys'),
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
            icon: Icon(Icons.add),
            color: _isDarkModeEnabled ? Colors.greenAccent : null,
            onPressed: () async {

              /// TODO: Show Modal for key type
              ///

              /// add peer key page
              ///
              // print("add peer key page");

              // _showKeyTypeSelectionModal();

              Navigator.of(context)
                  .push(MaterialPageRoute(
                builder: (context) => AddPeerPublicKeyScreen(keyItem: _keyItem),
              ))
                  .then((value) {
                if (value == "savedItem") {
                  EasyLoading.showToast("Saved Key Item",
                      duration: Duration(seconds: 2));
                }

                _getItem();
              });
            },
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: _peerPublicKeysShowing.length,
        separatorBuilder: (context, index) => Divider(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
        ),
        itemBuilder: (context, index) {
          // var decryptedNote = _cryptor.decrypt(_notes[index].notes);
          var categoryIcon = Stack(
            children: [
              IconButton(
                icon: Icon(
                  Icons.key,
                  color: _isDarkModeEnabled
                      ? Colors.greenAccent
                      : Colors.blueAccent,
                  size: 40,
                ),
                onPressed: null,
              ),
              // Visibility(
              //   visible: _peerPublicKeysShowing[index].favorite,
              //   child: Positioned(
              //     bottom: 20,
              //     right: 35,
              //     child: Icon(
              //       Icons.star,
              //       size: 15,
              //       color: _isDarkModeEnabled
              //           ? Colors.greenAccent
              //           : Colors.blueAccent,
              //     ),
              //   ),
              // ),
            ],
          );

          final peerKeyItem = _peerPublicKeysShowing[index];

          /// decrypt these fields
          final keyData = peerKeyItem.key;
          final keyName = peerKeyItem.name;

          // final decryptedSeedData = await _cryptor.decrypt(keyData);
          // print("decryptedSeedData: ${decryptedSeedData}");
          //
          // final decodedRootKey = hex.decode(decryptedSeedData);

          final cnote = "";//keyItem.notes.replaceAll("\n", "... ");
          var nameString =
              '${keyName.substring(0, peerKeyItem.name.length <= 50 ? keyName.length : peerKeyItem.name.length > 50 ? 50 : peerKeyItem.name.length)}';

          if (peerKeyItem.name.length > 50) {
            nameString += '...';
          }
          if (peerKeyItem.name.length <= 50 &&
              peerKeyItem.name.length >= 30) {
            nameString += '...';
          }

          var pubAddress = "address: ${_cryptor.sha256(peerKeyItem.key).substring(0,40)}";


          return
            // Container(
            // // height: 60,
            // child:
            ListTile(
              // visualDensity: VisualDensity(vertical: 4),
              isThreeLine: false,
              title: Text(
                nameString,
                // keyData,
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : null,
                  fontSize: 18,
                ),
              ),
              subtitle: Padding(
                padding: EdgeInsets.fromLTRB(0,8,8,8),
                child: Text(
                      pubAddress,
                  // "publicKey: ${keyData.substring(0, 20)}...",

                  // "key:\n${keyData.substring(0, (keyData.length/2).toInt())}...",
                // '${cnote.substring(0, cnote.length <= 50 ? cnote.length : cnote.length > 50 ? 50 : cnote.length)}...', // DateFormat('MMM d y  hh:mm a').format(DateTime.parse(_notes[index].mdate))
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.grey[300] : null,
                  fontSize: 14,
                ),
              ),),
              leading: categoryIcon,
              trailing: Icon(
                Icons.arrow_forward_ios,
                color:
                _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
              ),
              onTap: () {
                /// forward user to password list with the selected tag
                ///
                // print("onTap: edit peerKey: ${peerKeyItem.id}");

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditPeerPublicKeyScreen(
                      keyItem: _keyItem,
                      peerId: peerKeyItem.id,
                    ),
                  ),
                ).then((value) {
                  /// TODO: refresh tag items
                  ///
                  _getItem();
                });
              },
              // ),
            );
        },
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

}
