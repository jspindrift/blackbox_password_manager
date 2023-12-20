import 'dart:convert';
import 'dart:typed_data';

import 'package:argon2/argon2.dart';
import 'package:flutter/material.dart';
import "package:bip39/bip39.dart" as bip39;

import '../managers/KeychainManager.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../widgets/qr_code_view.dart';
import 'home_tab_screen.dart';

class EmergencyKitScreen extends StatefulWidget {
  const EmergencyKitScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/emergency_kit_screen';

  @override
  State<EmergencyKitScreen> createState() => _EmergencyKitScreenState();
}

class _EmergencyKitScreenState extends State<EmergencyKitScreen> {
  List _wordList = [];
  bool _isDarkModeEnabled = false;

  int _selectedIndex = 3;

  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _keyManager = KeychainManager();


  @override
  void initState() {
    super.initState();

    _logManager.log("EmergencyKitScreen", "initState", "initState");

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;

    _selectedIndex = _settingsManager.currentTabIndex;

    final salt = _keyManager.salt;
    final decodedSalt = base64.decode(salt);
    final salty = Uint8List.fromList(decodedSalt);

    final phrase = bip39.entropyToMnemonic(salty.toHexString());
    _wordList = phrase.split(" ");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text('Emergency Kit'),
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QRCodeView(
                    data: _keyManager.salt,
                    isDarkModeEnabled: _isDarkModeEnabled,
                    isEncrypted: false,
                  ),
                ),
              ).then((value) {
                // _didPressSecretShare = false;
              });
            },
            icon: Icon(
              Icons.qr_code,
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Text(
              "Secret Key",
              style: TextStyle(
                color: _isDarkModeEnabled ? Colors.white : null,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Divider(
            color: _isDarkModeEnabled ? Colors.greenAccent : null,
          ),
          SizedBox(
            height: 16,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Center(
              child: Row(
                children: [
                  Spacer(),
                  // ListTile(title: Text(
                  //   "1. ${_wordList[0]}",
                  //   style: TextStyle(
                  //     color: _isDarkModeEnabled ? Colors.white : null,
                  //     fontSize: 16,
                  //   ),
                  // ) ,),
                  Text(
                    "1. ${_wordList[0]}",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                  // ListTile(title: Text(
                  //   "7. ${_wordList[6]}",
                  //   style: TextStyle(
                  //     color: _isDarkModeEnabled ? Colors.white : null,
                  //     fontSize: 16,
                  //   ),
                  // ) ,),
                  Text(
                    "7. ${_wordList[6]}",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Center(
              child: Row(
                children: [
                  Spacer(),
                  Text(
                    "2. ${_wordList[1]}",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                  Text(
                    "8. ${_wordList[7]}",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Center(
              child: Row(
                children: [
                  Spacer(),
                  Text(
                    "3. ${_wordList[2]}",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                  Text(
                    "9. ${_wordList[8]}",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Center(
              child: Row(
                children: [
                  Spacer(),
                  Text(
                    "4. ${_wordList[3]}",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                  Text(
                    "10. ${_wordList[9]}",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Center(
              child: Row(
                children: [
                  Spacer(),
                  Text(
                    "5. ${_wordList[4]}",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                  Text(
                    "11. ${_wordList[10]}",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Center(
              child: Row(
                children: [
                  Spacer(),
                  Text(
                    "6. ${_wordList[5]}",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                  Text(
                    "12. ${_wordList[11]}",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                ],
              ),
            ),
          ),

          // Padding(
          //   padding: EdgeInsets.all(16),
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          //     children: <Widget>[
          //       OutlinedButton(
          //         style: OutlinedButton.styleFrom(
          //           side: _isDarkModeEnabled
          //               ? BorderSide(color: Colors.greenAccent)
          //               : BorderSide(color: Colors.blueAccent),
          //         ),
          //         onPressed: () {
          //           Navigator.of(context).pop();
          //         },
          //         child: Text(
          //           "I wrote it down",
          //           style: TextStyle(
          //             color: _isDarkModeEnabled
          //                 ? Colors.greenAccent
          //                 : Colors.blueAccent,
          //           ),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
      // ListView.separated(
      //   itemCount: _wordList.length,
      //   separatorBuilder: (context, index) => Divider(
      //     color: _isDarkModeEnabled ? Colors.greenAccent : null,
      //   ),
      //   itemBuilder: (context, index) {
      //     return ListTile(
      //       visualDensity: VisualDensity(vertical: 4),
      //       title: Text(
      //         '${index + 1}. ${_wordList[index]}',
      //         style: TextStyle(
      //           color: _isDarkModeEnabled ? Colors.white : null,
      //         ),
      //       ),
      //     );
      //   },
      // ),
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

    _settingsManager.changeRoute(index);
  }
}
