import 'dart:convert';

import '../helpers/AppConstants.dart';
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter/material.dart';
import '../models/KeyItem.dart';

import '../managers/LogManager.dart';
import '../managers/Cryptor.dart';
import '../managers/SettingsManager.dart';
import '../managers/KeychainManager.dart';

import 'add_public_encryption_key_screen.dart';
import 'edit_public_encryption_key_screen.dart';
import 'home_tab_screen.dart';

/// Copied code from NoteListScreen

class KeyListScreen extends StatefulWidget {
  const KeyListScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/key_list_screen';

  @override
  State<KeyListScreen> createState() => _KeyListScreenState();
}

class _KeyListScreenState extends State<KeyListScreen> {
  bool _isDarkModeEnabled = false;

  List<KeyItem> _keys = [];
  List<String> _pubKeys = [];


  int _selectedIndex = 1;

  final _keyManager = KeychainManager();
  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _cryptor = Cryptor();

  @override
  void initState() {
    super.initState();

    _logManager.log("KeyListScreen", "initState", "initState");

    setState(() {
      _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;
      _selectedIndex = _settingsManager.currentTabIndex;
    });

    _getAllKeyItems();
  }

  void _getAllKeyItems() async {
    _keys = [];
    _pubKeys = [];

    final items = await _keyManager.getAllItems();

    // iterate through items
    for (var item in items.list) {
      if (item.type == "key") {
        var keyItem = KeyItem.fromRawJson(item.data);
        if (keyItem != null) {
          // final itemId = noteItem.id + "-" + noteItem.cdate + "-" + noteItem.mdate;
          // final keyIndex = (keyItem?.keyIndex)!;
          // var keyIndex = 0;
          //
          // if (keyItem?.keyIndex != null) {
          //   keyIndex = (keyItem?.keyIndex)!;
          // }
          final keyType = keyItem.keyType;
          final keyAlgo = keyItem.algo;
          final keyPurpose = keyItem.purpose;
          // print("keyType: ${keyType}");
          // print("keyAlgo: ${keyAlgo}");
          // print("keyPurpose: ${keyPurpose}");


          var decryptedName = await _cryptor.decrypt(keyItem.name);
          keyItem.name = decryptedName;

          var decryptedPrivateKey = await _cryptor.decrypt(keyItem.key);
          // keyItem.key = decryptedKey;
          if (keyType == "asym") {
            keyItem.key = await _generateKeyPair(decryptedPrivateKey);
          } else {
            keyItem.key = "private symmetric key";
          }

          var decryptedNote = await _cryptor.decrypt(keyItem.notes);
          keyItem.notes = decryptedNote;
          _keys.add(keyItem);
          // var tempTags = noteItem.tags;
          // if (tempTags != null) {
          //   // iterate through item tags
          //   for (var tag in tempTags) {
          //     if (!_tags.contains(tag)) {
          //       _tags.add(tag);
          //       _tagCounts[tag] = 1;
          //     } else {
          //       if (_tagCounts[tag] != null) {
          //         _tagCounts[tag] = _tagCounts[tag]! + 1;
          //       }
          //     }
          //   }
          // }
        }
      }
    }

    _keys.sort(
            (e1, e2) => e1.name.toLowerCase().compareTo(e2.name.toLowerCase()));

    /// update UI
    if (mounted) {
      setState(() {});
    }
  }


  /// return the public key
  Future<String> _generateKeyPair(String privateKeyString) async {
    // print("_generateKeyPair");

    final algorithm_exchange = X25519();

    /// TODO: switch encoding !
    final privKey = base64.decode(privateKeyString);

    if (AppConstants.debugKeyData) {
      logger.d("_privKey: ${privKey.length}: ${privKey}");
    }

    /// Get private key pair
    final privSeedPair = await algorithm_exchange
        .newKeyPairFromSeed(privKey);

    // final tempPrivKey = await privSeedPair.extractPrivateKeyBytes();
    // print("tempPrivKey: ${tempPrivKey}");

    /// convert to public key
    final simplePublicKey = await privSeedPair.extractPublicKey();

    // final expanded = await _cryptor.expandKey(_seedKey);
    final pubKey = simplePublicKey.bytes;
    // print("pubKey: ${pubKey}");


    final toAddr = _cryptor.sha256(hex.encode(pubKey)).substring(0, 40);
    // final fromAddr = _cryptor.sha256(base64.encode(_mainPublicKey)).substring(0,40);

    return toAddr;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text('Keys'),
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

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddPublicEncryptionKeyScreen(), //AddKeyItemScreen(),
                ),
              ).then((value) {
                if (value == "savedItem") {
                  EasyLoading.showToast("Saved Key Item",
                      duration: Duration(seconds: 2));
                }

                _getAllKeyItems();
              });

              // _showKeyTypeSelectionModal();
            },
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: _keys.length,
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
                      ? (_keys[index].keyType == "asym" ? Colors.greenAccent : Colors.red)
                      : (_keys[index].keyType == "asym" ? Colors.blueAccent : Colors.red),
                  size: 40,
                ),
                onPressed: null,
              ),
              Visibility(
                visible: _keys[index].favorite,
                child: Positioned(
                  bottom: 20,
                  right: 35,
                  child: Icon(
                    Icons.star,
                    size: 15,
                    color: _isDarkModeEnabled
                        ? Colors.greenAccent
                        : Colors.blueAccent,
                  ),
                ),
              ),
            ],
          );

          final keyItem = _keys[index];

          final keyItemType = keyItem.keyType;

          final cnote = keyItem.notes.replaceAll("\n", "... ");
          var nameString =
              '${keyItem.name.substring(0, keyItem.name.length <= 50 ? keyItem.name.length : keyItem.name.length > 50 ? 50 : keyItem.name.length)}';

          if (keyItem.name.length > 50) {
            nameString += '...';
          }
          if (keyItem.name.length <= 50 &&
              keyItem.name.length >= 30) {
            nameString += '...';
          }

          // TODO: show address equivalent?
          if (keyItem.keyType == "asym") {
            // nameString += "\npubKey: " + keyItem.key;
            nameString += "\naddress: " + keyItem.key.substring(0,40);
          }
          // else {
          //   // nameString += "\nkey: " + keyItem.key;
          // }

          var trimmedNote = cnote.substring(0, cnote.length <= 50 ? cnote.length : cnote.length > 50 ? 50 : cnote.length);
          if (trimmedNote.length > 0) {
            trimmedNote = "\nnotes: ${trimmedNote}...";
          }

          return
            // Container(
            // // height: 60,
            // child:
            ListTile(
              // visualDensity: VisualDensity(vertical: 4),
              isThreeLine: false,
              title: Text(
                nameString,
                // _notes[index].name,
                // '${_notes[index].name.substring(0, _notes[index].name.length <= 50 ? _notes[index].name.length : _notes[index].name.length > 50 ? 50 : _notes[index].name.length)}',
                // '${_tags[index]} (${_sortedTagCounts[_tags[index]]})',
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : null,
                  fontSize: 18,
                ),
              ),
              subtitle: Text(
                //yyyy-MM-dd, dd-MM-yyyy
                'type: ${keyItemType}${trimmedNote}', // DateFormat('MMM d y  hh:mm a').format(DateTime.parse(_notes[index].mdate))
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.grey : null,
                  fontSize: 14,
                ),
              ),
              leading: categoryIcon,
              trailing: Icon(
                Icons.arrow_forward_ios,
                color:
                _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
              ),
              onTap: () {
                /// forward user to password list with the selected tag
                ///
                // print("onTap: selected key item type: ${keyItemType}");

                if (keyItemType == EnumToString.convertToString(EncryptionKeyType.asym)) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditPublicEncryptionKeyScreen(
                        id: keyItem.id,
                      ),
                    ),
                  ).then((value) {
                    /// TODO: refresh tag items
                    ///
                    _getAllKeyItems();
                  });
                }
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

  _showKeyTypeSelectionModal() {
    /// show modal bottom sheet
    showModalBottomSheet(
        backgroundColor: _isDarkModeEnabled ? Colors.black : null,
        elevation: 8,
        context: context,
        isScrollControlled: false,
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
                                // FocusScope.of(context).unfocus();

                                state(() {
                                  // _tagTextController.text = "";
                                  // _tagTextFieldValid = false;
                                  // _filteredTags = _settingsManager.itemTags;
                                });

                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                          Spacer(),
                        ],
                      ),

                      Container(
                        // height: MediaQuery.of(context).size.height * 0.7,
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Container(
                            child: ElevatedButton(
                              style: ButtonStyle(
                                backgroundColor: _isDarkModeEnabled
                                    ? MaterialStateProperty.all<Color>(
                                    Colors.greenAccent)
                                    : null,
                                foregroundColor: MaterialStateProperty.all<Color>(
                                    Colors.black),
                              ),
                              child: Text("Asymmetric Key Pair"),
                              onPressed: (){

                                Navigator.of(context).pop();

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddPublicEncryptionKeyScreen(), //AddKeyItemScreen(),
                                  ),
                                ).then((value) {
                                  if (value == "savedItem") {
                                    EasyLoading.showToast("Saved Key Item",
                                        duration: Duration(seconds: 2));
                                  }

                                  _getAllKeyItems();
                                });

                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              });
        }).then((value) {
      if (value != null) {
        // print("Chose: $value");

        if (value == "savedItem") {
          EasyLoading.showToast("Saved Key Item",
              duration: Duration(seconds: 2));

        }

        _getAllKeyItems();
      }
    });
  }

}
