import 'dart:io';

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import 'package:flutter/foundation.dart';
import "package:flutter_easyloading/flutter_easyloading.dart";
import "package:flutter_slidable/flutter_slidable.dart";
import "package:flutter_barcode_scanner/flutter_barcode_scanner.dart";
import "package:bip39/bip39.dart" as bip39;

import '../helpers/AppConstants.dart';
import "../screens/edit_password_screen.dart";
import "../screens/add_password_screen.dart";
import "../managers/KeychainManager.dart";
import "../managers/SettingsManager.dart";
import "../managers/Cryptor.dart";
import "../managers/LogManager.dart";
import "../models/PasswordItem.dart";
import "../models/GenericItem.dart";
import '../models/QRCodeItem.dart';
import "../widgets/my_alphabetical_list.dart";
import "../widgets/QRScanView.dart";
import '../widgets/qr_code_view.dart';
import 'home_tab_screen.dart';


/// PasswordItems are translated to Items for viewing in the
/// alphabetical list view
class Item {
  final String id;
  final String name;
  final String username;
  final bool favorite;

  Item(this.id, this.name, this.username, this.favorite);
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = "/welcome_screen";

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _selectedIndex = 1;

  List<PasswordItem> _decryptedPasswordItemList = [];
  List<String> _decryptedPasswordList = [];

  List<String> _strList = [];
  List<Widget> _favoriteList = [];
  List<Widget> _normalList = [];

  TextEditingController _searchController = TextEditingController();

  bool _isDarkModeEnabled = false;

  final keyManager = KeychainManager();
  final settingsManager = SettingsManager();
  final cryptor = Cryptor();
  final logManager = LogManager();

  @override
  void initState() {
    super.initState();

    setState(() {
      _isDarkModeEnabled = settingsManager.isDarkModeEnabled;
    });

    _selectedIndex = settingsManager.currentTabIndex;
    // print("_selectedIndex: $_selectedIndex");

    // keyManager.readRecoveryPasscodeKey();

    logManager.log("WelcomeScreen", "initState", "initState");
    // logManager.logger.d("WelcomeScreen - initState");

    keyManager.getAllItems().then((value) {
      // passwordList = value;
      // passwordListByDate = value;

      /// decrypt the names and usernames and set them
      ///
      _decryptPasswordItemList(value).then((value) {
        _filterList();
      });

      // passwordListByDate.sort(
      //     (a, b) => a.cdate.toLowerCase().compareTo(b.cdate.toLowerCase()));
      //
      // /// TODO: change to decrypted password list
      // passwordList
      //     .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });

    _searchController.addListener(() {
      _filterList();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// decrypt password item list
  Future<void> _decryptPasswordItemList(GenericItemList items) async {
    _decryptedPasswordItemList = [];
    _decryptedPasswordList = [];
    // var pindex = 0;

    if (items.list.length == 0) {
      _filterList();
      return;
    }

    var numOfPasswords = 0;

    for (var item in items.list) {
      // print("welcome screen item type: ${item.type}");
      if (item.type == "password") {
        // print("welcome screen item data: ${item.data}");
        numOfPasswords += 1;
        var passwordItem = PasswordItem.fromRawJson(item.data);
        // final itemId = passwordItem.id + "-" + passwordItem.cdate + "-" + passwordItem.mdate;
        // var keyIndex = 0;
        //
        // if (passwordItem?.keyIndex != null) {
        //   keyIndex = (passwordItem?.keyIndex)!;
        // }
        final decryptedName = await cryptor.decrypt(passwordItem.name);
        var thisItem = items.list.firstWhere((element) {
          if (element.type == "password") {
            var checkItem = PasswordItem.fromRawJson(element.data);

            // final elm = element as PasswordItem;
            if (checkItem != null) {
              return checkItem.id == passwordItem.id;
            }
          }
          return false;
        });

        var updatedPasswordItem = PasswordItem.fromRawJson(thisItem.data);

        // print("thisItem: $updatedPasswordItem");
        updatedPasswordItem.name = decryptedName;
        final decryptedUsername = await cryptor.decrypt(passwordItem.username);
        updatedPasswordItem.username = decryptedUsername;

        /// TODO: get all passwords (decrypted) and hold to flag any reused passwords
        ///
        if (passwordItem.geoLock == null) {
          final decryptedPassword =
              await cryptor.decrypt(passwordItem.password);

          if (passwordItem.isBip39) {
            final mnemonic = bip39.entropyToMnemonic(decryptedPassword);

            _decryptedPasswordList.add(mnemonic);
          } else {
            _decryptedPasswordList.add(decryptedPassword);
          }

          _decryptedPasswordItemList.add(updatedPasswordItem);
        } else {
          // _decryptedPasswordItemList.add(null);
          _decryptedPasswordItemList.add(updatedPasswordItem);
        }
      }
    }

    // call for a UI update
    setState(() {
      _decryptedPasswordItemList.sort((a, b) => a.name.compareTo(
          b.name)); //a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });

    _filterList();
  }

  /// get password items, sort and filter
  void _updatePasswordItemList() async {
    final items = await keyManager.getAllItems(); //.then((value) {
    // passwordList = value;
    // passwordListByDate = value;

    /// TODO: check if this is correct
    await _decryptPasswordItemList(items); //.then((value) {
    // _filterList();
    // });

    // passwordListByDate.sort(
    //     (a, b) => a.cdate.toLowerCase().compareTo(b.cdate.toLowerCase()));
    // passwordList
    //     .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // });
  }

  String _getTimeDifferences(String date) {
    DateTime a = DateTime.parse(date);

    DateTime b = DateTime.now();
    Duration difference = b.difference(a);

    // int years = difference.;

    int days = difference.inDays;
    double years = days / 365;
    int daysAdjusted = days % 365;

    int hours = difference.inHours % 24;
    int minutes = difference.inMinutes % 60;
    int seconds = difference.inSeconds % 60;
    // print("$years years");

    var elapsedTimeString = "";
    if (years >= 1.0) {
      if (years.toInt() > 1) {
        elapsedTimeString += "${years.toInt()} years, ";
      } else {
        elapsedTimeString += "${years.toInt()} year, ";
      }
    }
    if (days > 1) {
      if (years >= 1.0) {
        if (daysAdjusted > 0) {
          elapsedTimeString += "⏰ - $daysAdjusted days, ";
        }
        // else {
        //   elapsedTimeString += "$daysAdjusted days, ";
        // }
      } else {
        if (days > 90) {
          elapsedTimeString += "⏰ - $days days, ";
        } else {
          elapsedTimeString += "$days days, ";
        }
      }
    }
    if (hours > 0) {
      elapsedTimeString += "$hours hours, ";
    }
    if (minutes > 0) {
      elapsedTimeString += "$minutes minutes";
    }
    // if (seconds > 0) {
    //   elapsedTimeString += "$seconds seconds";
    // }

    return elapsedTimeString;
  }

  /// filter the normal items from the favorite item widgets
  void _filterList() {
    List<PasswordItem> items = [];

    /// TODO: Check if this is correct
    items.addAll(_decryptedPasswordItemList);
    // items.addAll(passwordList);

    _favoriteList = [];
    _normalList = [];
    _strList = [];
    if (_searchController.text.isNotEmpty) {
      items.retainWhere((item) => item.name
          .toLowerCase()
          .contains(_searchController.text.toLowerCase()));
    }
    items.forEach((item) {
      if (item.favorite) {
        _favoriteList.add(
          Slidable(
            enabled: true,
            startActionPane: ActionPane(
              // A motion is a widget used to control how the pane animates.
              motion: const ScrollMotion(),
              // All actions are defined in the children parameter.
              children: [
                // A SlidableAction can have an icon and/or a label.
                SlidableAction(
                  // key: Key(item.id), // has problems with duplicate keys
                  onPressed: (buildContext) {
                    _showDeleteDialog(item.id);
                  },
                  backgroundColor: Color(0xFFFE4A49),
                  foregroundColor: Colors.white,
                  icon: Icons.delete,
                  label: "Delete",
                ),
                SlidableAction(
                  // key: Key(item.id), // has problems with duplicate keys
                  onPressed: (buildContext) {
                    _pressedShareItem(item.id);
                  },
                  backgroundColor: Color(0xFF21B7CA),
                  foregroundColor: Colors.white,
                  icon: Icons.share,
                  label: "Share",
                ),
              ],
            ),
            endActionPane: ActionPane(
              motion: ScrollMotion(),
              children: [
                SlidableAction(
                  key: Key(item.id),
                  onPressed: (buildContext) {
                    _duplicateItem(item.id);
                  },
                  backgroundColor: Color(0xFF0392CF),
                  foregroundColor: Colors.white,
                  icon: Icons.save,
                  label: "Duplicate",
                ),
              ],
            ),
            child: ListTile(
              tileColor: _isDarkModeEnabled ? Colors.black54 : Colors.white,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditPasswordScreen(
                      id: item.id,
                      passwordList: _decryptedPasswordList,
                    ),
                  ),
                ).then((value) {
                  _updatePasswordItemList();
                });
              },
              leading: Stack(
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor:
                        _isDarkModeEnabled ? Colors.greenAccent : null,
                    foregroundColor: _isDarkModeEnabled ? Colors.black : null,
                    child: Text(
                      "",
                      // item.name.length >=2 ? item.name.substring(0, 2) : item.name.substring(0, 1),
                    ),
                  ),
                  Container(
                    height: 40,
                    width: 40,
                    child: Center(
                      child: Icon(
                        Icons.star,
                        color: _isDarkModeEnabled
                            ? Colors.black
                            : Colors.yellow[100],
                      ),
                    ),
                  ),
                ],
              ),
              // trailing: Icon(
              //   Icons.arrow_forward_ios,
              //   color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
              // ),
              title: Text(
                item.name,
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : null,
                ),
              ),
              subtitle: Text(
                "${item.username}", //, ${_getTimeDifferences(item.cdate)}",
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : null,
                ),
              ),
            ),
          ),
        );
      } else {
        _normalList.add(
          Slidable(
            enabled: true,
            startActionPane: ActionPane(
              // A motion is a widget used to control how the pane animates.
              motion: const ScrollMotion(),
              // All actions are defined in the children parameter.
              children: [
                // A SlidableAction can have an icon and/or a label.
                SlidableAction(
                  onPressed: (buildContext) {
                    _showDeleteDialog(item.id);
                  },
                  backgroundColor: Color(0xFFFE4A49),
                  foregroundColor: Colors.white,
                  icon: Icons.delete,
                  label: "Delete",
                ),
                SlidableAction(
                  onPressed: (buildContext) {
                    _pressedShareItem(item.id);
                  },
                  backgroundColor: Color(0xFF21B7CA),
                  foregroundColor: Colors.white,
                  icon: Icons.share,
                  label: "Share",
                ),
              ],
            ),
            endActionPane: ActionPane(
              motion: ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (buildContext) {
                    _duplicateItem(item.id);
                  },
                  backgroundColor: Color(0xFF0392CF),
                  foregroundColor: Colors.white,
                  icon: Icons.save,
                  label: "Duplicate",
                ),
              ],
            ),
            child: ListTile(
              tileColor: _isDarkModeEnabled ? Colors.black54 : Colors.white,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditPasswordScreen(
                      id: item.id,
                      passwordList: _decryptedPasswordList,
                    ),
                  ),
                ).then((value) {
                  _updatePasswordItemList();
                });
              },
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8.0), //or 15.0
                child: Container(
                  height: 40.0,
                  width: 40.0,
                  color: _isDarkModeEnabled
                      ? Colors.greenAccent
                      : Colors.blueAccent,
                  child: Center(
                    child: Text(
                      item.name.length >= 2
                          ? item.name.substring(0, 2)
                          : item.name.substring(0, 1),
                      style: TextStyle(
                        fontSize: 16,
                        color: _isDarkModeEnabled ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              // trailing: Icon(
              //   Icons.arrow_forward_ios,
              //   color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
              // ),
              // CircleAvatar(
              //   backgroundColor: _isDarkModeEnabled ? Colors.greenAccent : null,
              //   foregroundColor: _isDarkModeEnabled ? Colors.black : null,
              //   child: Text(
              //     item.name.length >=2 ? item.name.substring(0, 2) : item.name.substring(0, 1),
              //     style: TextStyle(fontSize: 16),
              //   ), // .toLowerCase()
              // ),
              title: Text(
                item.name,
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : null,
                ),
              ),
              subtitle: Text(
                // item.username,
                "${item.username}", //, ${_getTimeDifferences(item.cdate)}",
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : null,
                ),
              ),
            ),
          ),
        );
        _strList.add(item.name);
      }
    });

    /// update our UI
    setState(() {});
  }

  _pressedShareItem(String id) async {
    try {
      /// get item by id and convert
      ///
      final itemString = await keyManager.getItem(id);
      final item = PasswordItem.fromRawJson(itemString);

      /// get item fields
      ///
      if (item == null) {
        _showErrorDialog("Error retrieving item.");
        return;
      }

      final encryptedName = (item?.name)!;
      final encryptedUsername = (item?.username)!;
      final encryptedPassword = (item?.password)!;

      final itemId = id + "-" + (item?.cdate)! + "-" + (item?.mdate)!;

      /// decrypt fields
      ///
      // final keyIndex = (item?.keyIndex)!;
      // var keyIndex = 0;
      //
      // if (item?.keyIndex != null) {
      //   keyIndex = (item?.keyIndex)!;
      // }

      final name = await cryptor.decrypt(encryptedName);
      final username = await cryptor.decrypt(encryptedUsername);
      final password = await cryptor.decrypt(encryptedPassword);

      /// build QR Code item
      ///
      final qrItem =
          QRCodeItem(name: name, username: username, password: password);
      final qrItemString = qrItem.toRawJson();

      /// check QR Code data length and show QR Code view
      if (qrItemString.length >= 1286) {
        _showErrorDialog("Too much data for QR code.\n\nLimit is 1286 bytes.");
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QRCodeView(
              data: qrItemString,
              isDarkModeEnabled: _isDarkModeEnabled,
              isEncrypted: false,
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorDialog("Error sharing item.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Passwords",
        ),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.camera),
            color: _isDarkModeEnabled ? Colors.greenAccent : null,
            onPressed: () async {
              settingsManager.setIsScanningQRCode(true);

              if (Platform.isIOS) {
                await _scanQR();
              } else {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.of(context)
                      .push(MaterialPageRoute(
                    builder: (context) => QRScanView(),
                  ))
                      .then((value) {
                    settingsManager.setIsScanningQRCode(false);

                    try {
                      QRCodeItem item = QRCodeItem.fromRawJson(value);

                      if (item != null) {
                        _saveScannedItem(item).then((value) {
                          EasyLoading.showToast("Saved Scanned Item");
                          _updatePasswordItemList();
                        });
                      } else {
                        _showErrorDialog("Invalid code format");
                      }
                    } catch (e) {
                      // _showErrorDialog("Exception: $e");
                      logManager.logger.w("Exception: $e");
                    }
                  });
                });
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.add),
            color: _isDarkModeEnabled ? Colors.greenAccent : null,
            onPressed: () {
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

                _updatePasswordItemList();
              });
            },
          ),
        ],
      ),
      body: AlphabetListScrollView(
        strList: _strList,
        normalTextStyle: _isDarkModeEnabled
            ? TextStyle(color: Colors.white)
            : TextStyle(color: Colors.black),
        highlightTextStyle: TextStyle(
          color: Colors.yellow,
        ),
        showPreview: true,
        itemBuilder: (context, index) {
          return _normalList[index];
        },
        indexedHeight: (i) {
          return 80;
        },
        keyboardUsage: true,
        headerWidgetList: <AlphabetScrollListHeader>[
          AlphabetScrollListHeader(
            widgetList: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextFormField(
                  controller: _searchController,
                  style: TextStyle(
                    fontSize: 18.0,
                    color: _isDarkModeEnabled ? Colors.white : null,
                  ),
                  decoration: InputDecoration(
                    labelText: "Search",
                    border: OutlineInputBorder(),
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
                    suffix: Icon(
                      Icons.search,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            ],
            icon: Icon(Icons.search),
            indexedHeaderHeight: (index) => 80,
          ),
          AlphabetScrollListHeader(
              widgetList: _favoriteList,
              icon: Icon(Icons.star),
              indexedHeaderHeight: (index) {
                return 80;
              }),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 2.0,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : Colors.white,
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

  Future<void> _scanQR() async {
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
        QRCodeItem item = QRCodeItem.fromRawJson(barcodeScanRes);
        if (item != null) {
          _saveScannedItem(item).then((value) {
            EasyLoading.showToast("Saved Scanned Item");
            _updatePasswordItemList();
          });
        } else {
          _showErrorDialog("Invalid code format");
        }
      } catch (e) {
        logManager.logger.w("exception: $e");
      }
    } on PlatformException {
      barcodeScanRes = "Failed to get platform version.";
      logManager.logger.w("Platform exception");
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    Navigator.of(context)
        .popUntil((route) => route.settings.name == HomeTabScreen.routeName);

    settingsManager.changeRoute(index);
  }


  Future<void> _saveScannedItem(QRCodeItem item) async {
    final createDate = DateTime.now();
    final uuid = cryptor.getUUID();

    final name = item.name;
    final username = item.username;
    final password = item.password;

    // final itemId = uuid +
    //     "-" +
    //     createDate.toIso8601String() +
    //     "-" +
    //     createDate.toIso8601String();

    /// Encrypt password and items here
    /// ...
    final encryptedName = await cryptor.encrypt(name);
    final encryptedUsername = await cryptor.encrypt(username);

    var isBip39Valid = bip39.validateMnemonic(password);

    String encryptedPassword = "";
    if (isBip39Valid) {
      final seed = bip39.mnemonicToEntropy(password);

      /// Encrypt seed here
      encryptedPassword = await cryptor.encrypt(seed);
    } else {
      /// Encrypt password here
      encryptedPassword = await cryptor.encrypt(password);
    }

    /// Encrypt notes
    final encryptedNotes = await cryptor.encrypt("Shared item");

    final passwordItem = PasswordItem(
      id: uuid,
      version: AppConstants.passwordItemVersion,
      name: encryptedName,
      username: encryptedUsername,
      password: encryptedPassword,
      previousPasswords: [],
      favorite: false,
      isBip39: isBip39Valid,
      tags: ["shared"],
      geoLock: null,
      notes: encryptedNotes,
      cdate: createDate.toIso8601String(),
      mdate: createDate.toIso8601String(),
    );

    final passwordItemString = passwordItem.toRawJson();
    // print("passwordItem toRawJson: $passwordItemString");

    final genericItem = GenericItem(type: "password", data: passwordItemString);
    // print('genericItem toRawJson: ${genericItem.toRawJson()}');

    final genericItemString = genericItem.toRawJson();

    final status = await keyManager.saveItem(uuid, genericItemString);
    // print("passwordItem status: $status");

    if (status) {
      // Navigator.of(context).pop();
      EasyLoading.showToast("Saved Scanned Item");
    } else {
      _showErrorDialog("Could not save scanned item");
    }
  }

  /// TODO: cannot duplicate geoLocked items
  void _duplicateItem(String id) async {
    try {
      /// get item by id and convert
      final itemString = await keyManager.getItem(id);

      final item = GenericItem.fromRawJson(itemString);

      final passwordItem = PasswordItem.fromRawJson(item.data);

      /// get item fields
      ///
      if (passwordItem == null) {
        _showErrorDialog("Error retrieving item.");
        return;
      }

      /// get timestamp and uuid
      final timestamp = DateTime.now();
      final uuid = cryptor.getUUID();

      final encryptedName = (passwordItem?.name)!;
      final encryptedUsername = (passwordItem?.username)!;
      final encryptedPassword = (passwordItem?.password)!;

      // final itemId = uuid +
      //     "-" +
      //     timestamp.toIso8601String() +
      //     "-" +
      //     timestamp.toIso8601String();
      // final keyIndex = (passwordItem?.keyIndex)!;
      // var keyIndex = 0;
      //
      // if (passwordItem?.keyIndex != null) {
      //   keyIndex = (passwordItem?.keyIndex)!;
      // }
      /// decrypt fields
      ///
      final name = await cryptor.decrypt(encryptedName);
      final username = await cryptor.decrypt(encryptedUsername);

      /// if bip39, password is the seed hex
      final password = await cryptor.decrypt(encryptedPassword);

      /// TODO: change to use key index on encryption
      /// re-encrypt item fields
      ///
      final reEncryptedName = await cryptor.encrypt(name);

      final reEncryptedUsername = await cryptor.encrypt(username);

      // final isBip39Valid = bip39.validateMnemonic(password);
      final isBip39 = (passwordItem?.isBip39)!;

      // String reEncryptedPassword = '';
      // if (isBip39) {
      // final seed = bip39.mnemonicToEntropy(password);
      // final seed = bip39.mnemonicToEntropy(password);

      /// Encrypt seed here
      final reEncryptedPassword = await cryptor.encrypt(password);
      // } else {
      //   /// Encrypt password here
      //   reEncryptedPassword = await cryptor.encrypt(password);
      // }

      /// Encrypt empty notes
      final reEncryptedNotes = await cryptor.encrypt("");

      /// build item
      ///
      final newPasswordItem = PasswordItem(
        id: uuid,
        version: AppConstants.passwordItemVersion,
        name: reEncryptedName,
        username: reEncryptedUsername,
        password: reEncryptedPassword,
        previousPasswords: [],
        favorite: false,
        isBip39: isBip39,
        tags: [],
        geoLock: null,
        notes: reEncryptedNotes,
        cdate: timestamp.toIso8601String(),
        mdate: timestamp.toIso8601String(),
      );

      final passwordItemString = newPasswordItem.toRawJson();
      // print('passwordItem toRawJson: $passwordItemString');

      /// TODO: add GenericItem
      ///
      final genericItem =
          GenericItem(type: "password", data: passwordItemString);
      // print('genericItem toRawJson: ${genericItem.toRawJson()}');

      final genericItemString = genericItem.toRawJson();

      /// save item
      ///
      final status = await keyManager.saveItem(uuid, genericItemString);

      /// open edit_password screen with newly duplicated item
      ///
      if (status) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditPasswordScreen(
              id: uuid,
              passwordList: _decryptedPasswordList,
            ),
          ),
        ).then((value) {
          _updatePasswordItemList();
        });
      } else {
        _showErrorDialog("Could not duplicate item.");
      }
    } catch (e) {
      _showErrorDialog("Could not duplicate item: $e");
      logManager.logger.d("$e");
    }
  }

  void _showDeleteDialog(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Password Item"),
        content: Text("Are you sure you want to delete this password item?"),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text("Cancel"),
          ),
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor:
                  MaterialStateProperty.all<Color>(Colors.redAccent),
            ),
            onPressed: () async {
              /// delete the item using id
              final status = await keyManager.deleteItem(id);

              Navigator.of(context).pop();
              if (status) {
                EasyLoading.showToast("Item deleted");
                _updatePasswordItemList();
              } else {
                _showErrorDialog('Delete item failed');
              }
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
