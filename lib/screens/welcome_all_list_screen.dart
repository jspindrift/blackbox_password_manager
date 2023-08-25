import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:intl/intl.dart';
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

import 'add_key_item_screen.dart';
import 'add_password_screen.dart';
import 'add_public_encryption_key_screen.dart';
import 'edit_public_encryption_key_screen.dart';
import 'home_tab_screen.dart';

const List<String> sortList = <String>[
  'Title',
  'Time Created',
  'Time Modified',
];

class WelcomeAllListScreen extends StatefulWidget {
  const WelcomeAllListScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/welcome_all_list_screen';

  @override
  State<WelcomeAllListScreen> createState() => _WelcomeAllListScreenState();
}

class _WelcomeAllListScreenState extends State<WelcomeAllListScreen> {
  bool _isDarkModeEnabled = false;

  int _selectedIndex = 0;

  List<dynamic> _favoriteItems = [];
  List<dynamic> _allItems = [];

  List<String> _allTags = [];
  String _dropDownValue = "Title";

  final _allCategories = ["Password", "Secure Note", "Key"];

  List<String> _decryptedPasswordList = [];

  final keyManager = KeychainManager();
  final logManager = LogManager();
  final settingsManager = SettingsManager();
  final cryptor = Cryptor();

  @override
  void initState() {
    super.initState();

    logManager.log("WelcomeAllListScreen", "initState", "initState");
    logManager.logger.d("WelcomeAllListScreen - initState");

    _isDarkModeEnabled = settingsManager.isDarkModeEnabled;

    _selectedIndex = settingsManager.currentTabIndex;

    _getItems();
  }

  Future<void> _getItems() async {
    _favoriteItems = [];
    _allItems = [];
    _allTags = [];
    _decryptedPasswordList = [];

    try {
      final items = await keyManager.getAllItems();

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

            // logManager.logger.d("passwordItem: ${passwordItem.toRawJson()}");
            passwordItem.decryptObject();

            if (passwordItem.favorite) {
              _favoriteItems.add(passwordItem);
            }

            _decryptedPasswordList.add(passwordItem.password);

            _allItems.add(passwordItem);
          }
        } else if (item.type == "note") {
          var noteItem = NoteItem.fromRawJson(item.data);
          if (noteItem != null) {
            for (var tag in (noteItem?.tags)!) {
              if (!_allTags.contains(tag)) {
                _allTags.add(tag);
              }
            }
            // var keyIndex = 0;
            //
            // if (noteItem?.keyIndex != null) {
            //   keyIndex = (noteItem?.keyIndex)!;
            // }

            // final keyIndex = (noteItem?.keyIndex)!;

            if (noteItem.geoLock == null) {
              final decryptedName = await cryptor.decrypt(noteItem.name);
              final decryptedNote = await cryptor.decrypt(noteItem.notes);

              noteItem.name = decryptedName;
              noteItem.notes = decryptedNote;
              // _favoriteItems.add(noteItem);
            }

            if (noteItem.favorite) {
              // final itemId = noteItem.id + "-" + noteItem.cdate + "-" + noteItem.mdate;
              _favoriteItems.add(noteItem);
            }

            _allItems.add(noteItem);
          }
        } else if (item.type == "key") {
          var keyItem = KeyItem.fromRawJson(item.data);
          if (keyItem != null) {
            for (var tag in (keyItem?.tags)!) {
              if (!_allTags.contains(tag)) {
                _allTags.add(tag);
              }
            }

            final decryptedName = await cryptor.decrypt(keyItem.name);
            keyItem.name = decryptedName;

            final decryptedNote = await cryptor.decrypt(keyItem.notes);
            keyItem.notes = decryptedNote;

            if (keyItem.favorite) {
              _favoriteItems.add(keyItem);
            }

            _allItems.add(keyItem);
          }
        }
      }

      _favoriteItems
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (_dropDownValue == sortList[0]) {
        setState(() {
          _allItems.sort(
                  (a, b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        });
      } else if (_dropDownValue == sortList[1]) {
        setState(() {
          _allItems.sort(
                  (a, b) =>
                  b.cdate.toLowerCase().compareTo(a.cdate.toLowerCase()));
        });
      } else if (_dropDownValue == sortList[2]) {
        setState(() {
          _allItems.sort(
                  (a, b) =>
                  b.mdate.toLowerCase().compareTo(a.mdate.toLowerCase()));
        });
      }

      _allTags.sort((e1, e2) => e1.compareTo(e2));

      settingsManager.saveItemTags(_allTags);

    } catch (e) {
      logManager.logger.wtf("Exception: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text("All"),
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
              Icons.add,
              color: _isDarkModeEnabled ? Colors.greenAccent : null,
            ),
            onPressed: () {
              _showSelectCategoryModal(context);
            },
          ),
          Card(
            color: _isDarkModeEnabled ? Colors.greenAccent : null,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 0, 0),
              child: DropdownButton(
                value: _dropDownValue,
                dropdownColor: _isDarkModeEnabled ? Colors.greenAccent : null,
                iconEnabledColor: _isDarkModeEnabled ? Colors.black : null,
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.greenAccent : null,
                ),
                items: sortList.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: Colors.black,
                      ), //_isDarkModeEnabled ? Colors.black : Colors.black),
                    ),
                  );
                }).toList(),
                onChanged: (String? value) {
                  _getItems();

                  setState(() {
                    if (value != null) {
                      _dropDownValue = value;
                    }
                  });
                  // state(() {
                  //   _dropdownValue = value!;
                  // });
                  //
                  // _generatePassword(state);
                },
              ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: _allItems.length,
        separatorBuilder: (context, index) => Divider(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
        ),
        itemBuilder: (context, index) {
          final convertedItem = _allItems[index];
          final convertedItemType = convertedItem.runtimeType;

          // final itemIcon = _itemsWithTag[index].favorite
          //     ? Icon(Icons.star, color: _isDarkModeEnabled ? Colors.black : Colors.white)
          //     : Text(
          //   _itemsWithTag[index].name.substring(0, _itemsWithTag[index].name.length >= 2 ? 2 : 1),
          //   style: TextStyle(
          //     fontSize: 16,
          //     // fontWeight: FontWeight.bold,
          //   ),
          // );

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
              leading: convertedItem.favorite
                  ? CircleAvatar(
                      minRadius: 15,
                      maxRadius: 20,
                      backgroundColor: _isDarkModeEnabled
                          ? Colors.greenAccent
                          : Colors.blueAccent,
                      child: Icon(Icons.star,
                          color:
                              _isDarkModeEnabled ? Colors.black : Colors.white),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8.0), //or 15.0
                      child: Container(
                        height: 40.0,
                        width: 40.0,
                        color: _isDarkModeEnabled
                            ? Colors.greenAccent
                            : Colors.blueAccent,
                        child: Center(
                          child: Text(
                            convertedItem.name.length >= 2
                                ? convertedItem.name.substring(0, 2)
                                : convertedItem.name.substring(0, 1),
                            style: TextStyle(
                              fontSize: 16,
                              color: _isDarkModeEnabled
                                  ? Colors.black
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
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
                  _getItems();
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
                  _getItems();
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
                    _getItems();
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
      bottomNavigationBar: BottomNavigationBar(
        elevation: 2.0,
        backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.white,
        // fixedColor: _isDarkModeEnabled ? Colors.black87 : Colors.white,
        // fixedColor: Colors.blue,
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

  /// show the generate password screen
  void _showSelectCategoryModal(BuildContext context) {
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

            _getItems();
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

            _getItems();
          });
        } else if (value == "Credit Card") {
        } else if (value == "Key") {

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

            _getItems();
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
                                  // _filteredTags = settingsManager.itemTags;
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
                              child: Text("Public Asymmetric Key"),
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

                                  _getItems();
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

        _getItems();
      }
    });
  }

}
