import '../models/GenericItem.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import "package:bip39/bip39.dart" as bip39;

import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/KeychainManager.dart';
import '../managers/Cryptor.dart';
import '../models/KeyItem.dart';
import '../models/PasswordItem.dart';
import '../models/NoteItem.dart';
import '../screens/edit_password_screen.dart';
import '../screens/add_note_screen.dart';
import 'add_password_screen.dart';
import 'add_public_encryption_key_screen.dart';
import 'edit_public_encryption_key_screen.dart';


class FavoritesListScreen extends StatefulWidget {
  const FavoritesListScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/favorites_list_screen';

  @override
  State<FavoritesListScreen> createState() => _FavoritesListScreenState();
}

class _FavoritesListScreenState extends State<FavoritesListScreen> {
  bool _isDarkModeEnabled = false;

  List<dynamic> _favoriteItems = [];
  List<String> _allTags = [];
  List<String> _decryptedPasswordList = [];

  final _allCategories = ["Password", "Secure Note", "Key"];

  final _keyManager = KeychainManager();
  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _cryptor = Cryptor();


  @override
  void initState() {
    super.initState();

    _logManager.log("FavoritesListScreen", "initState", "initState");
    _logManager.logger.d("FavoritesListScreen - initState");

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;

    _getFavoriteItems();
  }

  void _getFavoriteItems() async {
    _favoriteItems = [];
    _allTags = [];
    _decryptedPasswordList = [];

    final items = await _keyManager.getAllItems() as GenericItemList;

    // iterate through items
    for (var item in items.list) {
      if (item.type == "password") {
        var passwordItem = PasswordItem.fromRawJson(item.data);
        if (passwordItem != null) {
          for (var tag in (passwordItem?.tags)!) {
            if (!_allTags.contains(tag)) {
              _allTags.add(tag);
            }
          }
          // final keyIndex = (passwordItem.keyIndex)!;

          if (passwordItem.favorite) {
            final decryptedName = await _cryptor.decrypt(passwordItem.name);
            final decryptedUsername =
                await _cryptor.decrypt(passwordItem.username);

            passwordItem.name = decryptedName;
            passwordItem.username = decryptedUsername;

            _favoriteItems.add(passwordItem);
          }

          if (passwordItem.geoLock == null) {
            final decryptedPassword =
                await _cryptor.decrypt(passwordItem.password);
            if (passwordItem.isBip39) {
              final mnemonic = bip39.entropyToMnemonic(decryptedPassword);
              _decryptedPasswordList.add(mnemonic);
            } else {
              _decryptedPasswordList.add(decryptedPassword);
            }
          }
        }
      } else if (item.type == "note") {
        var noteItem = NoteItem.fromRawJson(item.data);
        if (noteItem != null) {
          // final checkMerkle = noteItem.calculateMerkleRootCheck();
          // if (!checkMerkle) {
          //   WidgetUtils.showToastMessage("Merkle Corrupt:NoteItem: ${noteItem.id}", 3);
          // }

          for (var tag in (noteItem?.tags)!) {
            if (!_allTags.contains(tag)) {
              _allTags.add(tag);
            }
          }
          // final keyIndex = (noteItem.keyIndex)!;

          if (noteItem.favorite) {
            if (noteItem.geoLock == null) {
              final decryptedName = await _cryptor.decrypt(noteItem.name);
              final decryptedNote = await _cryptor.decrypt(noteItem.notes);
              noteItem.name = decryptedName;
              noteItem.notes = decryptedNote;
            }
            _favoriteItems.add(noteItem);
          }
        }
      } else if (item.type == "key") {
        var keyItem = KeyItem.fromRawJson(item.data);
        if (keyItem != null) {
          for (var tag in (keyItem?.tags)!) {
            if (!_allTags.contains(tag)) {
              _allTags.add(tag);
            }
          }
          // final keyIndex = (keyItem.keyIndex)!;

          if (keyItem.favorite) {
            final decryptedName = await _cryptor.decrypt(keyItem.name);
            keyItem.name = decryptedName;

            final decryptedNote = await _cryptor.decrypt(keyItem.notes);
            keyItem.notes = decryptedNote;

            _favoriteItems.add(keyItem);
          }
        }
      }
    }

    /// sort passwords by name with tag
    // _passwordsWithTag.sort(
    //         (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // _favoriteItems.sort(
    //         (a, b) => b.mdate.toLowerCase().compareTo(a.mdate.toLowerCase()));

    _favoriteItems
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    _allTags.sort((e1, e2) => e1.compareTo(e2));
    // print("favorites _allTags: $_allTags");

    _settingsManager.saveItemTags(_allTags);

    // print("_passwordsWithTag: $_passwordsWithTag");
    // print("_decryptedPasswordList:${_decryptedPasswordList.length}: $_decryptedPasswordList");

    /// if this tag isn't associated with any password items, pop back
    // if (_favoriteItems.isEmpty) {
    //   Navigator.of(context).pop();
    // }

    /// update UI
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text("Favorites"),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        actions: [
          IconButton(
            icon: Icon(
              Icons.add,
              color: _isDarkModeEnabled ? Colors.greenAccent : null,
            ),
            onPressed: () {
              _showSelectCategoryModal(context);
            },
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: _favoriteItems.length,
        separatorBuilder: (context, index) => Divider(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
        ),
        itemBuilder: (context, index) {
          final convertedItem = _favoriteItems[index];
          final convertedItemType = convertedItem.runtimeType;

          if (convertedItemType == PasswordItem) {
            return ListTile(
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
                backgroundColor:
                    _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                child: Icon(Icons.star,
                    color: _isDarkModeEnabled ? Colors.black : Colors.white),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color:
                    _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
              ),
              onTap: () {
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
                  _getFavoriteItems();
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
              title: Text(
                nameString,
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
              leading: categoryIcon,
              trailing: Icon(
                Icons.arrow_forward_ios,
                color:
                    _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
              ),
              onTap: () {
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
                  _getFavoriteItems();
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

                /// check if asym key or sym key
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
                        // _didPopBackFrom = true;
                      });
                    }
                    _getFavoriteItems();
                  });
                }

              },
            );
          } else {
            return Text(
                "missing requirements",
              style: TextStyle(
                color: _isDarkModeEnabled ? Colors.red : null,
                fontSize: 16,
              ),
            );
          }
        },
      ),
    );
  }

  /// show the generate password screen
  _showSelectCategoryModal(BuildContext context) {
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
                Expanded(
                  child: ListView.separated(
                    itemCount: _allCategories.length,
                    separatorBuilder: (context, index) => Divider(
                      color: _isDarkModeEnabled ? Colors.greenAccent : null,
                    ),
                    itemBuilder: (context, index) {
                      var iconImage;
                      var isKey = false;
                      if (_allCategories[index] == "Password") {
                        if (_isDarkModeEnabled) {
                          iconImage =
                              "assets/icons8-key-security-100-greenAccent.png";
                        } else {
                          iconImage =
                              "assets/icons8-key-security-100-blueAccent.png";
                        }
                      } else if (_allCategories[index] == "Secure Note") {
                        if (_isDarkModeEnabled) {
                          iconImage = "assets/icons8-note-96-greenAccent.png";
                        } else {
                          iconImage = "assets/icons8-note-96-blueAccent.png";
                        }
                      } else if (_allCategories[index] == "Credit Card") {
                        if (_isDarkModeEnabled) {
                          iconImage =
                              "assets/icons8-credit-card-60-greenAccent.png";
                        } else {
                          iconImage =
                              "assets/icons8-credit-card-60-blueAccent.png";
                        }
                      } else if (_allCategories[index] == "Key") {
                        isKey = true;
                        // if (_isDarkModeEnabled) {
                        //   iconImage = "assets/icons8-pin-code-96.png";
                        // } else {
                        //   iconImage = "assets/icons8-pin-code-96.png";
                        //   // iconImage =
                        //   // "assets/icons8-credit-card-60-blueAccent.png";
                        // }
                      }
                      return ListTile(
                        visualDensity: VisualDensity(vertical: 4),
                        title: Text(
                          _allCategories[index],
                          style: TextStyle(
                            color: _isDarkModeEnabled ? Colors.white : null,
                          ),
                        ),
                        leading: isKey ?
                        Icon(
                          Icons.key,
                          size: 40,
                          color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                        ) :
                        Image.asset(
                          iconImage,
                          height: 40,
                          width: 40,
                        ),
                        onTap: () {
                          // print("selected category: ${_allCategories[index]}");
                          /// pass selected category
                          ///
                          Navigator.of(context).pop(_allCategories[index]);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          });
        }).then((value) {
      if (value != null) {
        // print("Chose: $value");

        // print("$_decryptedPasswordList");
        if (value == "Password") {
          Navigator.of(context)
              .push(MaterialPageRoute(
            builder: (context) => AddPasswordScreen(
              passwordList: _decryptedPasswordList,
            ),
          ))
              .then((value) {
            if (value == "savedItem") {
              EasyLoading.showToast("Saved Password Item",
                  duration: Duration(seconds: 2));
            }

            _getFavoriteItems();
          });
        } else if (value == "Secure Note") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddNoteScreen(note: null),
            ),
          ).then((value) {
            if (value == "savedItem") {
              EasyLoading.showToast("Saved Note Item",
                  duration: Duration(seconds: 2));
            }

            _getFavoriteItems();
          });
        } else if (value == "Credit Card") {
        } else if (value == "Key") {

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddPublicEncryptionKeyScreen(),
            ),
          ).then((value) {
            if (value == "savedItem") {
              EasyLoading.showToast("Saved Key Item",
                  duration: Duration(seconds: 2));
            }

            _getFavoriteItems();
          });

          // _showKeyTypeSelectionModal();
        }

        /// Add New Items here...
      }
      // else {
      //   print("Dismissed");
      // }
    });
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

                                  _getFavoriteItems();
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

        _getFavoriteItems();
      }
    });
  }


}
