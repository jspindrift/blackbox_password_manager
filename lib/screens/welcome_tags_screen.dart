import 'package:argon2/argon2.dart';
import '../screens/items_by_tag_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import "package:bip39/bip39.dart" as bip39;

import '../managers/Cryptor.dart';
import '../models/KeyItem.dart';
import '../models/PasswordItem.dart';
import '../models/NoteItem.dart';

import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/KeychainManager.dart';
import 'add_key_item_screen.dart';
import 'add_note_screen.dart';
import 'add_password_screen.dart';
import 'add_public_encryption_key_screen.dart';

class WelcomeTagsScreen extends StatefulWidget {
  const WelcomeTagsScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/welcome_tags_screen';

  @override
  State<WelcomeTagsScreen> createState() => _WelcomeTagsScreenState();
}

class _WelcomeTagsScreenState extends State<WelcomeTagsScreen> {
  bool _isDarkModeEnabled = false;

  List<String> _tags = [];

  Map<String, int> _tagCounts = {};
  Map<String, int> _sortedTagCounts = {};

  List<String> _decryptedPasswordList = [];

  final _allCategories = ["Password", "Secure Note", "Key"];

  final _keyManager = KeychainManager();
  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _cryptor = Cryptor();

  @override
  void initState() {
    super.initState();

    _logManager.log("WelcomeTagsScreen", "initState", "initState");
    // _logManager.logger.d("WelcomeTagsScreen - initState");

    setState(() {
      _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;
    });

    _getAllTags();
  }

  void _getAllTags() async {
    _tags = [];
    _tagCounts = {};
    _sortedTagCounts = {};
    _decryptedPasswordList = [];

    final items = await _keyManager.getAllItems();

    // iterate through items
    for (var item in items.list) {
      if (item.type == "password") {
        var passwordItem = PasswordItem.fromRawJson(item.data);
        // final keyIndex = (passwordItem?.keyIndex)!;
        // var keyIndex = 0;
        //
        // if (passwordItem?.keyIndex != null) {
        //   keyIndex = (passwordItem?.keyIndex)!;
        // }

        if (passwordItem != null) {
          var tempTags = passwordItem.tags;
          if (tempTags != null) {
            // iterate through item tags
            for (var tag in tempTags) {
              if (!_tags.contains(tag)) {
                _tags.add(tag);
                _tagCounts[tag] = 1;
              } else {
                if (_tagCounts[tag] != null) {
                  _tagCounts[tag] = _tagCounts[tag]! + 1;
                }
              }
            }
          }

          if (passwordItem.geoLock == null) {
            final decryptedPassword =
                await _cryptor.decrypt(passwordItem.password);
            // print("bip39: ${passwordItem.isBip39}");
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
          var tempTags = noteItem.tags;
          // final keyIndex = (noteItem?.keyIndex)!;

          if (tempTags != null) {
            // iterate through item tags
            for (var tag in tempTags) {
              if (!_tags.contains(tag)) {
                _tags.add(tag);
                _tagCounts[tag] = 1;
              } else {
                if (_tagCounts[tag] != null) {
                  _tagCounts[tag] = _tagCounts[tag]! + 1;
                }
              }
            }
          }
        }
      } else if (item.type == "key") {
        var keyItem = KeyItem.fromRawJson(item.data);
        if (keyItem != null) {
          var tempTags = keyItem.tags;
          if (tempTags != null) {
            // iterate through item tags
            for (var tag in tempTags) {
              if (!_tags.contains(tag)) {
                _tags.add(tag);
                _tagCounts[tag] = 1;
              } else {
                if (_tagCounts[tag] != null) {
                  _tagCounts[tag] = _tagCounts[tag]! + 1;
                }
              }
            }
          }
        }
      }
    }

    _sortedTagCounts = Map.fromEntries(_tagCounts.entries.toList()
      ..sort((e1, e2) => e2.value.compareTo(e1.value)));

    var sortedTagNames = Map.fromEntries(_tagCounts.entries.toList()
      ..sort((e1, e2) => e1.key.compareTo(e2.key)));
    // print("sortedTagNames: $sortedTagNames");

    /// TODO: sort again by alphabetic order while keeping the tag count relevant
    ///
    _tags = [];
    var tempTagCounts = [];
    var currentTagCount = 0;
    for (var selTagCount in _sortedTagCounts.values) {
      if (!tempTagCounts.contains(selTagCount)) {
        tempTagCounts.add(selTagCount);
        currentTagCount = selTagCount;

        for (var x in sortedTagNames.keys) {
          if (!_tags.contains(x) && _sortedTagCounts[x] == currentTagCount) {
            _tags.add(x);
          }
        }
      }
    }

    final _sortedAlphabeticTags = _tags.copy();

    _sortedAlphabeticTags.sort((e1, e2) => e1.compareTo(e2));

    _settingsManager.saveItemTags(_sortedAlphabeticTags);

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
        title: Text('Tags'),
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
        itemCount: _sortedTagCounts.length,
        separatorBuilder: (context, index) => Divider(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
        ),
        itemBuilder: (context, index) {
          return Container(
            height: 60,
            child: ListTile(
              // visualDensity: VisualDensity(vertical: 4),
              title: Text(
                _tags[index],
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : null,
                  fontSize: 18,
                ),
              ),
              subtitle: Text(
                '${_sortedTagCounts[_tags[index]]} items',
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.grey : null,
                  fontSize: 14,
                ),
              ),
              leading: Icon(
                Icons.discount,
                color:
                    _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color:
                    _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
              ),
              onTap: () {
                /// forward user to item list with the selected tag
                ///
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ItemsByTagScreen(
                      tag: _tags[index],
                    ),
                  ),
                ).then((value) {
                  _getAllTags();
                });
              },
            ),
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

            _getAllTags();
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

            _getAllTags();
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

            _getAllTags();
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
                                ).then((value) {
                                  if (value == "savedItem") {
                                    EasyLoading.showToast("Saved Key Item",
                                        duration: Duration(seconds: 2));
                                  }

                                  _getAllTags();
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

        _getAllTags();
      }
    });
  }

}
