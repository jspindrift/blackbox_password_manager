import 'dart:io';

import 'package:flutter/material.dart';
import "package:flutter_easyloading/flutter_easyloading.dart";
import "package:bip39/bip39.dart" as bip39;

import '../managers/Cryptor.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/KeychainManager.dart';
import '../models/KeyItem.dart';
import '../models/PasswordItem.dart';
import '../models/NoteItem.dart';
import '../screens/add_password_screen.dart';
import '../screens/add_note_screen.dart';
import '../screens/note_list_screen.dart';
import '../screens/welcome_screen.dart';
import '../screens/key_list_screen.dart';
import '../screens/welcome_all_list_screen.dart';
import 'add_public_encryption_key_screen.dart';


class WelcomeCategoriesScreen extends StatefulWidget {
  const WelcomeCategoriesScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/welcome_categories_screen';

  @override
  State<WelcomeCategoriesScreen> createState() =>
      _WelcomeCategoriesScreenState();
}

class _WelcomeCategoriesScreenState extends State<WelcomeCategoriesScreen> {
  bool _isDarkModeEnabled = false;

  List<String> _availableCategories = [];
  List<String> _allCategories = [
    "Password",
    "Secure Note",
    "Key",
  ]; //, "Credit Card"];

  Map<String, int> _categoryCounts = {};
  Map<String, int> _sortedCategoryCounts = {};
  List<String> _allTags = [];
  List<String> _decryptedPasswordList = [];

  final _keyManager = KeychainManager();
  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _cryptor = Cryptor();


  @override
  void initState() {
    super.initState();

    _logManager.log("WelcomeCategoriesScreen", "initState", "initState");

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;

    _getAvailableCategories();
  }

  Future<void> _getAvailableCategories() async {
    _availableCategories = [];
    _categoryCounts = {};
    _sortedCategoryCounts = {};
    _allTags = [];
    _decryptedPasswordList = [];

    final items = await _keyManager.getAllItems();

    // iterate through items
    for (var item in items.list) {

      if (item.type == "password") {
        /// TODO: increment favorite counts
        final passwordItem = PasswordItem.fromRawJson(item.data);


        if (!_availableCategories.contains("Passwords")) {
          _availableCategories.add("All");
          _availableCategories.add("Passwords");
          _categoryCounts["Passwords"] = 1;
        } else {
          _categoryCounts["Passwords"] = _categoryCounts["Passwords"]! + 1;
        }

        if (passwordItem != null) {
          if (_categoryCounts["All"] == null) {
            _categoryCounts["All"] = 1;
          } else {
            _categoryCounts["All"] = _categoryCounts["All"]! + 1;
          }

          for (var tag in (passwordItem?.tags)!) {
            if (!_allTags.contains(tag)) {
              _allTags.add(tag);
            }
          }

          // _logManager.logger.d("passwordItem: ${passwordItem.toRawJson()}");

          if (passwordItem.geoLock == null) {
            final decryptedPassword =
                await _cryptor.decrypt(passwordItem.password);
            // _logManager.logger.d("decryptedPassword: $decryptedPassword");

            if (passwordItem.isBip39) {
              try {
                final mnemonic = bip39.entropyToMnemonic(decryptedPassword);
                _decryptedPasswordList.add(mnemonic);
              } catch (e) {
                _logManager.logger.e("exception: $e");
              }
            } else {
              _decryptedPasswordList.add(decryptedPassword);
            }
          } else {
            _decryptedPasswordList.add(passwordItem.password);
          }
        }
      } else if (item.type == "note") {
        /// TODO: increment favorite counts
        final noteItem = NoteItem.fromRawJson(item.data);

        if (!_availableCategories.contains("Notes")) {
          _availableCategories.add("All");
          _availableCategories.add("Notes");
          _categoryCounts["Notes"] = 1;
        } else {
          _categoryCounts["Notes"] = _categoryCounts["Notes"]! + 1;
        }
        if (noteItem != null) {
          if (_categoryCounts["All"] == null) {
            _categoryCounts["All"] = 1;
          } else {
            _categoryCounts["All"] = _categoryCounts["All"]! + 1;
          }

          for (var tag in (noteItem?.tags)!) {
            if (!_allTags.contains(tag)) {
              _allTags.add(tag);
            }
          }
        }
      } else if (item.type == "key") {
        /// TODO: increment favorite counts
        final keyItem = KeyItem.fromRawJson(item.data);

        if (!_availableCategories.contains("Keys")) {
          _availableCategories.add("All");
          _availableCategories.add("Keys");
          _categoryCounts["Keys"] = 1;
        } else {
          _categoryCounts["Keys"] = _categoryCounts["Keys"]! + 1;
        }
        if (keyItem != null) {
          if (_categoryCounts["All"] == null) {
            _categoryCounts["All"] = 1;
          } else {
            _categoryCounts["All"] = _categoryCounts["All"]! + 1;
          }

          for (var tag in (keyItem?.tags)!) {
            if (!_allTags.contains(tag)) {
              _allTags.add(tag);
            }
          }
        }
      }
    }

    _sortedCategoryCounts = Map.fromEntries(_categoryCounts.entries.toList()
      ..sort((e1, e2) => e2.value.compareTo(e1.value)));

    var sortedCategoryNames = Map.fromEntries(_categoryCounts.entries.toList()
      ..sort((e1, e2) => e1.key.compareTo(e2.key)));

    _allTags.sort((e1, e2) => e1.compareTo(e2));

    _settingsManager.saveItemTags(_allTags);

    _availableCategories = [];
    var tempCategoryCounts = [];
    var currentCategoryCount = 0;
    for (var selTagCount in _sortedCategoryCounts.values) {
      if (!tempCategoryCounts.contains(selTagCount) && selTagCount > 0) {
        tempCategoryCounts.add(selTagCount);
        currentCategoryCount = selTagCount;

        for (var x in sortedCategoryNames.keys) {
          if (!_availableCategories.contains(x) &&
              _sortedCategoryCounts[x] == currentCategoryCount) {
            _availableCategories.add(x);
          }
        }
      }
    }

    /// update UI
    if (mounted) {
      setState(() {});
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? (Platform.isAndroid ? Colors.black87 : Colors.black87) : Colors.white70, //Colors.blue[50],//Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Categories",
          style: TextStyle(
            color: _isDarkModeEnabled ? Colors.white : Colors.white,
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(
                Icons.add,
              color: _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
            ),
            color: _isDarkModeEnabled ? Colors.greenAccent : null,
            onPressed: () {
              /// add category
              _showSelectCategoryModal(context);
            },
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: _availableCategories.length,
        separatorBuilder: (context, index) => Divider(
          color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
        ),
        itemBuilder: (context, index) {
          var categoryIcon = IconButton(
            icon: Image.asset(
              "assets/icons8-key-security-100-greenAccent.png",
              height: 30,
              width: 30,
            ),
            onPressed: null,
          );
          if (_availableCategories[index] == "Passwords") {
            if (!_isDarkModeEnabled) {
              categoryIcon = IconButton(
                icon: Image.asset(
                  "assets/icons8-key-security-100-blueAccent.png",
                  height: 30,
                  width: 30,
                ),
                onPressed: null,
              );
            }
          }
          if (_availableCategories[index] == "Notes") {
            categoryIcon = IconButton(
              icon: Icon(
                Icons.sticky_note_2_outlined,
                color:
                    _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                size: 40,
              ),
              onPressed: null,
            );
          }
          if (_availableCategories[index] == "Keys") {
            if (!_isDarkModeEnabled) {
              categoryIcon = IconButton(
                icon: Icon(
                    Icons.key,
                  size: 40,
                  color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                ),
                onPressed: null,
              );
            } else {
              categoryIcon = IconButton(
                icon: Icon(
                  Icons.key,
                  size: 40,
                  color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                ),
                onPressed: null,
              );
            }
          }
          if (_availableCategories[index] == "All") {
            categoryIcon = IconButton(
              icon: Icon(
                Icons.all_inclusive,
                color:
                    _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                size: 40,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WelcomeAllListScreen(),
                  ),
                ).then((value) async {
                  await _getAvailableCategories();
                });
              },
            );
          }

          return ListTile(
            visualDensity: VisualDensity(vertical: 4),
            title: Text(
              '${_availableCategories[index]}',
              style: TextStyle(
                color: _isDarkModeEnabled ? Colors.white : null,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              (_categoryCounts[_availableCategories[index]] == 0 ||
                      _categoryCounts[_availableCategories[index]]! > 1)
                  ? "${_categoryCounts[_availableCategories[index]]} items"
                  : "${_categoryCounts[_availableCategories[index]]} item",
              style: TextStyle(
                color: _isDarkModeEnabled ? Colors.grey[200] : Colors.grey,
                fontSize: 16,
                // fontWeight: FontWeight.bold,
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
              if (_availableCategories[index] == "Passwords") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WelcomeScreen(),
                  ),
                ).then((value) async {
                  await _getAvailableCategories();
                });
              } else if (_availableCategories[index] == "Notes") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NoteListScreen(),
                  ),
                ).then((value) async {
                  await _getAvailableCategories();
                });
              } else if (_availableCategories[index] == "Keys") {
                /// Modal to ask key type
                ///
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => KeyListScreen(),
                  ),
                ).then((value) async {
                  await _getAvailableCategories();
                });
              } else if (_availableCategories[index] == "All") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WelcomeAllListScreen(),
                  ),
                ).then((value) async {
                  await _getAvailableCategories();
                });
              }
            },
          );
        },
      ),
    );
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
                        if (_isDarkModeEnabled) {
                          iconImage = "assets/icons8-pin-code-96.png";
                        } else {
                          iconImage = "assets/icons8-pin-code-96.png";
                          // iconImage =
                          // "assets/icons8-credit-card-60-blueAccent.png";
                        }
                      }
                      return ListTile(
                        visualDensity: VisualDensity(vertical: 4),
                        title: Text(
                          _allCategories[index],
                          style: TextStyle(
                            color: _isDarkModeEnabled ? Colors.white : null,
                            fontSize: 18,
                            // fontFamily: ,
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
                          Navigator.of(context).pop(_allCategories[index]);
                        },
                      );
                    },
                  ),
                ),
                // Divider(
                //   color: _isDarkModeEnabled ? Colors.greenAccent : null,
                // ),
              ],
            );
          });
        }).then((value) {
      if (value != null) {
        if (value == "Password") {
          Navigator.of(context)
              .push(MaterialPageRoute(
            builder: (context) => AddPasswordScreen(
              passwordList: _decryptedPasswordList,
            ),
          ))
              .then((value) async {
            if (value == "savedItem") {
              EasyLoading.showToast("Saved Password Item",
                  duration: Duration(seconds: 2));
            }

            await _getAvailableCategories();
          });
        } else if (value == "Secure Note") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddNoteScreen(
                  id: null,
              ),
            ),
          ).then((value) async {
            if (value == "savedItem") {
              EasyLoading.showToast("Saved Note Item",
                  duration: Duration(seconds: 2));
            }

            await _getAvailableCategories();
          });
        } else if (value == "Credit Card") {
        } else if (value == "Key") {

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddPublicEncryptionKeyScreen(), //AddKeyItemScreen(),
            ),
          ).then((value) async {
            if (value == "savedItem") {
              EasyLoading.showToast("Saved Key Item",
                  duration: Duration(seconds: 2));
            }

            await _getAvailableCategories();
          });

          // _showKeyTypeSelectionModal();
        }

        /// Add New Items here...
      }
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
                                ).then((value) async {
                                  if (value == "savedItem") {
                                    EasyLoading.showToast("Saved Key Item",
                                        duration: Duration(seconds: 2));
                                  }

                                  await _getAvailableCategories();
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
        }).then((value) async {
          if (value != null) {
            // print("Chose: $value");

            if (value == "savedItem") {
              EasyLoading.showToast("Saved Key Item",
                  duration: Duration(seconds: 2));

            }

            await _getAvailableCategories();
          }
    });
  }

}
