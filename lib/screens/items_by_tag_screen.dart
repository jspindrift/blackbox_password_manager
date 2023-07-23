import '../screens/edit_public_encryption_key_screen.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import "package:bip39/bip39.dart" as bip39;
import '../helpers/WidgetUtils.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/KeychainManager.dart';
import '../managers/Cryptor.dart';
import '../models/KeyItem.dart';
import '../models/PasswordItem.dart';
import '../models/NoteItem.dart';
import '../screens/edit_password_screen.dart';
import '../screens/add_note_screen.dart';
import 'home_tab_screen.dart';

class ItemsByTagScreen extends StatefulWidget {
  const ItemsByTagScreen({
    Key? key,
    required this.tag,
  }) : super(key: key);
  static const routeName = '/items_by_tag_screen';

  final String tag;

  @override
  State<ItemsByTagScreen> createState() => _ItemsByTagScreenState();
}

class _ItemsByTagScreenState extends State<ItemsByTagScreen> {
  bool _isDarkModeEnabled = false;
  bool _didPopBackFrom = false;

  int _selectedIndex = 1;

  List<PasswordItem> _passwordsWithTag = [];
  List<dynamic> _itemsWithTag = [];
  List<String> _decryptedPasswordList = [];

  final keyManager = KeychainManager();
  final logManager = LogManager();
  final settingsManager = SettingsManager();
  final cryptor = Cryptor();

  @override
  void initState() {
    super.initState();

    logManager.log("ItemsByTagScreen", "initState", "initState");
    // logManager.logger.d("ItemsByTagScreen - initState");

    _isDarkModeEnabled = settingsManager.isDarkModeEnabled;

    _selectedIndex = settingsManager.currentTabIndex;

    _getAllTags();
  }

  /// get items by tag
  ///
  void _getAllTags() async {
    _passwordsWithTag = [];
    _itemsWithTag = [];
    _decryptedPasswordList = [];

    final items = await keyManager.getAllItems();

    // iterate through items
    for (var item in items.list) {
      if (item.type == "password") {
        var passwordItem = PasswordItem.fromRawJson(item.data);
        if (passwordItem != null) {
          // print("is of type PasswordItem");
          var tempTags = passwordItem.tags;
          if (tempTags != null) {
            // iterate through item tags
            for (var tag in tempTags) {
              if (tag == widget.tag) {
                /// add modified item
                _passwordsWithTag.add(passwordItem);
                _itemsWithTag.add(passwordItem);
              }
            }
          }
          // final keyIndex = (passwordItem?.keyIndex)!;
          // var keyIndex = 0;
          //
          // if (passwordItem?.keyIndex != null) {
          //   keyIndex = (passwordItem?.keyIndex)!;
          // }
          /// decrypt item fields
          final decryptedName = await cryptor.decrypt(passwordItem.name);
          final decryptedUsername =
              await cryptor.decrypt(passwordItem.username);

          /// set decrypted fields
          passwordItem.name = decryptedName;
          passwordItem.username = decryptedUsername;

          final geoLockItem = passwordItem.geoLock;
          if (geoLockItem == null) {
            final decryptedPassword =
                await cryptor.decrypt(passwordItem.password);
            if (passwordItem.isBip39) {
              final mnemonic = bip39.entropyToMnemonic(decryptedPassword);
              _decryptedPasswordList.add(mnemonic);
            } else {
              _decryptedPasswordList.add(decryptedPassword);
            }
          }
          // final decryptedPassword = await cryptor.decrypt(passwordItem.password);
          // if (passwordItem.isBip39) {
          //   final mnemonic = bip39.entropyToMnemonic(decryptedPassword);
          //   _decryptedPasswordList.add(mnemonic);
          // } else {
          //   _decryptedPasswordList.add(decryptedPassword);
          // }

        }
      } else if (item.type == "note") {
        var noteItem = NoteItem.fromRawJson(item.data);
        if (noteItem != null) {
          // final checkMerkle = noteItem.calculateMerkleRootCheck();
          // if (!checkMerkle) {
          //   WidgetUtils.showToastMessage("Merkle Corrupt:NoteItem: ${noteItem.id}", 3);
          // }

          // print("is of type NoteItem");
          var tempTags = noteItem.tags;
          // final keyIndex = (noteItem?.keyIndex)!;
          // var keyIndex = 0;
          //
          // if (noteItem?.keyIndex != null) {
          //   keyIndex = (noteItem?.keyIndex)!;
          // }

          if (tempTags != null) {
            // iterate through item tags
            for (var tag in tempTags) {
              if (tag == widget.tag) {
                /// decrypt item fields
                // final itemId = noteItem.id + "-" + noteItem.cdate + "-" + noteItem.mdate;

                // final decryptedName = await cryptor.decrypt(noteItem.name);
                final geoLockItem = noteItem.geoLock;
                if (geoLockItem == null) {
                  final decryptedName = await cryptor.decrypt(noteItem.name);
                  final decryptedNote = await cryptor.decrypt(noteItem.notes);

                  /// set decrypted fields
                  noteItem.name = decryptedName;
                  noteItem.notes = decryptedNote;
                }

                /// add modified item
                _itemsWithTag.add(noteItem);
              }
            }
          }
        }
      } else if (item.type == "key") {
        var keyItem = KeyItem.fromRawJson(item.data);
        if (keyItem != null) {
          // print("is of type KeyItem");
          // final keyIndex = (keyItem?.keyIndex)!;
          // var keyIndex = 0;
          //
          // if (keyItem?.keyIndex != null) {
          //   keyIndex = (keyItem?.keyIndex)!;
          // }
          var tempTags = keyItem.tags;
          if (tempTags != null) {
            // iterate through item tags
            for (var tag in tempTags) {
              if (tag == widget.tag) {
                /// decrypt item fields
                // final itemId = noteItem.id + "-" + noteItem.cdate + "-" + noteItem.mdate;

                final decryptedName = await cryptor.decrypt(keyItem.name);
                final decryptedNote = await cryptor.decrypt(keyItem.notes);

                /// set decrypted fields
                keyItem.name = decryptedName;
                keyItem.notes = decryptedNote;


                /// add modified item
                _itemsWithTag.add(keyItem);
              }
            }
          }
        }
      }
    }

    /// sort passwords by name with tag
    _passwordsWithTag
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // _itemsWithTag.sort(
    //         (a, b) => b.mdate.toLowerCase().compareTo(a.mdate.toLowerCase()));
    _itemsWithTag
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    // print("_passwordsWithTag: $_passwordsWithTag");
    // print("_decryptedPasswordList: $_decryptedPasswordList");

    /// update UI
    // if (mounted) {
    //   setState(() {});
    // }
    /// if this tag isn't associated with any password items, pop back
    if (_itemsWithTag.isEmpty && _didPopBackFrom) {
      logManager.logger.d("popping ms poppins");
      Navigator.of(context).pop();
    }

    if (mounted) {
      setState(() {
        _didPopBackFrom = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text("${widget.tag}"),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: ListView.separated(
        itemCount: _itemsWithTag.length,
        separatorBuilder: (context, index) => Divider(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
        ),
        itemBuilder: (context, index) {
          final convertedItem = _itemsWithTag[index];
          final convertedItemType = convertedItem.runtimeType;
          // print("convertedItem type: $convertedItemType");

          final itemIcon = _itemsWithTag[index].favorite
              ? Icon(Icons.star,
                  color: _isDarkModeEnabled ? Colors.black : Colors.white)
              : Text(
                  _itemsWithTag[index].name.substring(
                      0, _itemsWithTag[index].name.length >= 2 ? 2 : 1),
                  style: TextStyle(
                    fontSize: 16,
                    // fontWeight: FontWeight.bold,
                  ),
                );

          if (convertedItemType == PasswordItem) {
            return ListTile(
              // visualDensity: VisualDensity(vertical: 4),
              title: Text(
                convertedItem.name,
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : null,
                ),
              ),
              subtitle: Text(
                convertedItem.username,
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : null,
                ),
              ),
              leading: CircleAvatar(
                minRadius: 15,
                maxRadius: 20,
                backgroundColor: _isDarkModeEnabled ? Colors.greenAccent : null,
                foregroundColor: _isDarkModeEnabled ? Colors.black : null,
                child: itemIcon,
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color:
                    _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
              ),
              onTap: () {
                // print("selected item: ${_passwordsWithTag[index].name}, ${_passwordsWithTag[index].username}");

                /// forward user to password list with the selected tag
                ///
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditPasswordScreen(
                      id: convertedItem.id,
                      passwordList: _decryptedPasswordList,
                    ),
                  ),
                ).then((value) {
                  // print("trace 251");
                  if (value != null) {
                    setState(() {
                      _didPopBackFrom = true;
                    });
                  }
                  _getAllTags();
                });
              },
            );
          } else if (convertedItemType == NoteItem) {
            var categoryIcon = Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.sticky_note_2_outlined,
                    color: _isDarkModeEnabled
                        ? Colors.greenAccent
                        : Colors.blueAccent,
                    size: 40,
                  ),
                  onPressed: null,
                ),
                Visibility(
                  visible: convertedItem.favorite,
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
            // var categoryIcon = IconButton(
            //   icon: Icon(
            //     Icons.sticky_note_2_outlined,
            //     color:
            //         _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
            //     size: 40,
            //   ),
            //   onPressed: null,
            // );
            // if (!_isDarkModeEnabled) {
            //   categoryIcon = IconButton(
            //     icon: Image.asset(
            //       "assets/icons8-note-96-blueAccent.png",
            //       height: 60,
            //       width: 60,
            //     ),
            //     onPressed: null,
            //   );
            // }
            // final note = _notes[index];

            final cnote = convertedItem.notes.replaceAll("\n", "... ");
            var nameString =
                '${convertedItem.name.substring(0, convertedItem.name.length <= 50 ? convertedItem.name.length : convertedItem.name.length > 50 ? 50 : convertedItem.name.length)}';

            if (convertedItem.name.length > 50) {
              nameString += '...';
            }
            if (convertedItem.name.length <= 50 &&
                convertedItem.name.length >= 30) {
              nameString += '...';
            }
            return ListTile(
              // visualDensity: VisualDensity(vertical: 4),
              title: Text(
                nameString,
                // convertedItem.name,
                // convertedItem.favorite ? "${convertedItem.name}" : "${convertedItem.name}",
                // "${convertedItem.name} ⭐",
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : null,
                ),
              ),
              subtitle: Text(
                //yyyy-MM-dd, dd-MM-yyyy
                '${cnote.substring(0, cnote.length <= 50 ? cnote.length : cnote.length >= 50 ? 50 : cnote.length)}...', // \n\n${DateFormat('MMM d y  hh:mm a').format(DateTime.parse(convertedItem.mdate))}
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.grey : null,
                  fontSize: 14,
                ),
              ),
              // Text(convertedItem.favorite ?
              //   "modified: ${DateFormat('yyyy-MM-dd  hh:mm a').format(DateTime.parse(convertedItem.mdate))}\n⭐"
              //   : "modified: ${DateFormat('yyyy-MM-dd  hh:mm a').format(DateTime.parse(convertedItem.mdate))}",
              //   // convertedItem.notes,
              //   style: TextStyle(
              //     color: _isDarkModeEnabled ? Colors.white : null,
              //   ),
              // ),
              leading: categoryIcon,
              trailing: Icon(
                Icons.arrow_forward_ios,
                color:
                    _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
              ),
              onTap: () {
                // print("selected item: ${_passwordsWithTag[index].name}, ${_passwordsWithTag[index].username}");

                /// forward user to password list with the selected tag
                ///
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddNoteScreen(
                      note: convertedItem,
                    ),
                  ),
                ).then((value) {
                  // print("trace 335");
                  if (value != null) {
                    setState(() {
                      _didPopBackFrom = true;
                    });
                  }
                  _getAllTags();
                });
              },
            );
          } else if (convertedItemType == KeyItem) {
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
                Visibility(
                  visible: convertedItem.favorite,
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


            final cnote = convertedItem.notes.replaceAll("\n", "... ");
            var nameString =
                '${convertedItem.name.substring(0, convertedItem.name.length <= 50 ? convertedItem.name.length : convertedItem.name.length > 50 ? 50 : convertedItem.name.length)}';

            if (convertedItem.name.length > 50) {
              nameString += '...';
            }
            if (convertedItem.name.length <= 50 &&
                convertedItem.name.length >= 30) {
              nameString += '...';
            }
            return ListTile(
              // visualDensity: VisualDensity(vertical: 4),
              title: Text(
                nameString,
                // convertedItem.name,
                // convertedItem.favorite ? "${convertedItem.name}" : "${convertedItem.name}",
                // "${convertedItem.name} ⭐",
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : null,
                ),
              ),
              subtitle: Text(
                //yyyy-MM-dd, dd-MM-yyyy
                '${convertedItem.keyType}: ${cnote.substring(0, cnote.length <= 50 ? cnote.length : cnote.length >= 50 ? 50 : cnote.length)}...', // \n\n${DateFormat('MMM d y  hh:mm a').format(DateTime.parse(convertedItem.mdate))}
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
                if (convertedItem.keyType == EnumToString.convertToString(EncryptionKeyType.asym)) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditPublicEncryptionKeyScreen(
                        id: convertedItem.id,
                      ),
                    ),
                  ).then((value) {
                    // print("trace 335");
                    if (value != null) {
                      setState(() {
                        _didPopBackFrom = true;
                      });
                    }
                    _getAllTags();
                  });
                }

              },
            );
          } else {
            return Text("test");
          }
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

    settingsManager.changeRoute(index);
  }


}
