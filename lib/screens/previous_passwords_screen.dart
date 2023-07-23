import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:password_strength/password_strength.dart';
import '../models/PasswordItem.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import 'home_tab_screen.dart';

class PreviousPasswordsScreen extends StatefulWidget {
  const PreviousPasswordsScreen({
    Key? key,
    required this.items,
  }) : super(key: key);
  static const routeName = '/previous_passwords_screen';

  final List<PreviousPassword> items;

  @override
  State<PreviousPasswordsScreen> createState() =>
      _PreviousPasswordsScreenState();
}

class _PreviousPasswordsScreenState extends State<PreviousPasswordsScreen> {
  List<bool> _hideItemValues = [];
  List<PreviousPassword> _previousPasswords = [];

  bool _isDarkModeEnabled = false;

  int _selectedIndex = 0;

  final logManager = LogManager();
  final settingsManager = SettingsManager();

  @override
  void initState() {
    super.initState();

    logManager.log("PreviousPasswordsScreen", "initState", "initState");

    setState(() {
      _isDarkModeEnabled = settingsManager.isDarkModeEnabled;
      _selectedIndex = settingsManager.currentTabIndex;
    });

    final dummyPrevious = PreviousPassword(
      password: "Press and Hold to copy to clipboard",
      isBip39: false,
      cdate: DateTime.now().toIso8601String(),
    );
    _previousPasswords.add(dummyPrevious);

    _hideItemValues.add(true);

    var reversedList = widget.items.reversed.toList();

    // int index = 0;
    for (var index = 0; index < widget.items.length; index++) {
      _hideItemValues.add(true);
      _previousPasswords.add(reversedList[index]);
      // index++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text('Previous Passwords'),
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        automaticallyImplyLeading: false,
        leading: BackButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: ListView.separated(
        separatorBuilder: (context, index) => Divider(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
        ),
        itemCount: _previousPasswords.length,
        itemBuilder: (context, index) {
          final pwdStrength =
              estimatePasswordStrength(_previousPasswords[index].password);

          DateTime a = DateTime.parse(_previousPasswords[index].cdate);

          DateTime b = DateTime.now();
          Duration difference = b.difference(a);

          // int years = difference.inYears;

          int days = difference.inDays;
          // double years = days / 365;

          int hours = difference.inHours % 24;
          int minutes = difference.inMinutes % 60;
          int seconds = difference.inSeconds % 60;
          // print("$index: $years years");

          var elapsedTimeString = ""; //"$a\n";
          // if (years.toInt() > 1) {
          //   elapsedTimeString += "${years.toInt()} years, ";
          // }
          if (days > 1) {
            elapsedTimeString += "$days days, ";
          }
          if (hours > 0) {
            elapsedTimeString += "$hours hours, ";
          }
          if (minutes > 0) {
            elapsedTimeString += "$minutes minutes, ";
          }
          if (seconds > 0) {
            elapsedTimeString += "$seconds seconds";
          }

          elapsedTimeString += "  | ${pwdStrength.toStringAsFixed(2)}";

          return index == 0
              ? ListTile(
                  title: TextFormField(
                    enabled: false,
                    initialValue: _previousPasswords[index].password,
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                    ),
                    decoration: InputDecoration(
                      disabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: _isDarkModeEnabled
                              ? Colors.greenAccent
                              : Colors.black,
                          width: 0.0,
                        ),
                      ),
                    ),
                  ),
                )
              : ListTile(
                  visualDensity: VisualDensity(vertical: 4),
                  subtitle: Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Text(
                      elapsedTimeString,
                      style: TextStyle(
                        color: _isDarkModeEnabled ? Colors.white : null,
                      ),
                    ),
                  ),
                  title: TextFormField(
                    initialValue: _previousPasswords[index].password,
                    obscureText: _hideItemValues[index],
                    enabled: !_hideItemValues[index],
                    maxLines: _hideItemValues[index] ? 1 : 8,
                    minLines: _hideItemValues[index] ? 1 : 1,
                    style: TextStyle(
                      // color: Colors.grey[800],
                      color: _isDarkModeEnabled ? Colors.white : null,
                      fontWeight: FontWeight.normal,
                      fontSize: 16,
                      height: 1,
                    ),
                    decoration: InputDecoration(
                      disabledBorder: OutlineInputBorder(
                        // width: 0.0 produces a thin "hairline" border
                        borderSide: BorderSide(
                          color: _isDarkModeEnabled
                              ? Colors.greenAccent
                              : Colors.grey,
                          width: 0.0,
                        ),
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _hideItemValues[index] = !_hideItemValues[index];
                      });
                    },
                  ),
                  onTap: () {
                    setState(() {
                      _hideItemValues[index] = !_hideItemValues[index];
                    });
                  },
                  onLongPress: () async {
                    // print('on long press');
                    await Clipboard.setData(ClipboardData(
                        text: _previousPasswords[index].password));
                    EasyLoading.showToast('Copied',
                        duration: Duration(milliseconds: 500));
                  },
                );
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
}
