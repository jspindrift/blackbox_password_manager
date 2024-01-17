import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter/material.dart';

import '../models/NoteItem.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/KeychainManager.dart';
import '../screens/add_note_screen.dart';
import 'home_tab_screen.dart';


class NoteListScreen extends StatefulWidget {
  const NoteListScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/note_list_screen';

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  bool _isDarkModeEnabled = false;

  int _selectedIndex = 1;

  List<NoteItem> _notes = [];


  final _keyManager = KeychainManager();
  final _logManager = LogManager();
  final _settingsManager = SettingsManager();


  @override
  void initState() {
    super.initState();

    _logManager.log("NoteListScreen", "initState", "initState");

    setState(() {
      _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;
      _selectedIndex = _settingsManager.currentTabIndex;
    });

    _getAllNoteItems();
  }

  void _getAllNoteItems() async {
    _notes = [];
    final items = await _keyManager.getAllItems();

    // iterate through items
    for (var item in items.list) {
      if (item.type == "note") {
        var noteItem = NoteItem.fromRawJson(item.data);
        if (noteItem != null) {

          final checkNoteMac = await noteItem.checkMAC();
          if (checkNoteMac) {
            await noteItem.decryptObject();

            _notes.add(noteItem);
          }
        }
      }
    }

    if (_notes.isEmpty) {
      Navigator.of(context).pop();
    }

    /// update UI
    setState(() {
      _notes.sort(
              (e1, e2) => e1.name.toLowerCase().compareTo(e2.name.toLowerCase()));
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.blue[50],//Colors.grey[100],
      appBar: AppBar(
        title: Text('Notes'),
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
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(
                builder: (context) => const AddNoteScreen(
                    id: null,
                ),
              ))
                  .then((value) {
                if (value == "savedItem") {
                  EasyLoading.showToast("Saved Note Item",
                      duration: Duration(seconds: 2));
                }

                _getAllNoteItems();
              });
            },
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: _notes.length,

        separatorBuilder: (context, index) => Divider(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
        ),
        itemBuilder: (context, index) {
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
                visible: _notes[index].favorite,
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

          final note = _notes[index];

          final cnote = note.notes.replaceAll("\n", "... ");
          var nameString =
              '${note.name.substring(0, note.name.length <= 50 ? note.name.length : note.name.length > 50 ? 50 : note.name.length)}';

          if (note.name.length > 50) {
            nameString += '...';
          }
          if (_notes[index].name.length <= 50 &&
              _notes[index].name.length >= 30) {
            nameString += '...';
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
              '${cnote.substring(0, cnote.length <= 50 ? cnote.length : cnote.length > 50 ? 50 : cnote.length)}...', // DateFormat('MMM d y  hh:mm a').format(DateTime.parse(_notes[index].mdate))
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
              // print("selected tag: ${_tags[index]}");

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddNoteScreen(
                    id: _notes[index].id,
                  ),
                ),
              ).then((value) {
                /// TODO: refresh tag items
                ///
                _getAllNoteItems();
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
