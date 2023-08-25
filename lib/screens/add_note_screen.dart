import 'dart:async';
import 'dart:convert';
import 'package:argon2/argon2.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '../helpers/AppConstants.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/KeychainManager.dart';
import '../managers/Cryptor.dart';

import '../models/NoteItem.dart';
import '../models/GenericItem.dart';
import 'home_tab_screen.dart';

/// Acts as Add Note and Edit Note screen depending on the note passed in

class AddNoteScreen extends StatefulWidget {
  const AddNoteScreen({
    Key? key,
    required this.note,
  }) : super(key: key);
  static const routeName = '/add_note_screen';

  final NoteItem? note;

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final _nameTextController = TextEditingController();
  final _notesTextController = TextEditingController();
  final _tagTextController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _notesFocusNode = FocusNode();

  int _selectedIndex = 0;

  bool _isDarkModeEnabled = false;
  bool _tagTextFieldValid = false;

  bool _isEditing = false;
  bool _isNewNote = true;
  bool _isFavorite = false;
  bool _fieldsAreValid = false;
  bool _enableTagNameOkayButton = false;

  NoteItem? _noteItem;

  List<String> _noteTags = [];
  List<bool> _selectedTags = [];
  List<String> _filteredTags = [];

  String _modifiedDate = DateTime.now().toIso8601String();

  final logManager = LogManager();
  final settingsManager = SettingsManager();
  final keyManager = KeychainManager();
  final cryptor = Cryptor();

  @override
  void initState() {
    super.initState();

    logManager.log("AddNoteScreen", "initState", "initState");

    if (widget.note == null) {
      _isEditing = true;
      _isNewNote = true;

      _filteredTags = settingsManager.itemTags;
      for (var tag in settingsManager.itemTags) {
        _selectedTags.add(false);
      }

    } else {
      _isEditing = false;
      _isNewNote = false;
      var item = widget.note;
      _noteItem = item;

      setState(() {
        _noteTags = (item?.tags)!;
        _isFavorite = (item?.favorite)!;
        _modifiedDate = (item?.mdate)!;
      });

      for (var tag in _noteTags) {
        _selectedTags.add(false);
      }

      _filteredTags = settingsManager.itemTags;

      _nameTextController.text = (item?.name)!;
      _notesTextController.text = (item?.notes)!;
    }

    _isDarkModeEnabled = settingsManager.isDarkModeEnabled;
    _selectedIndex = settingsManager.currentTabIndex;

    _validateFields();
  }

  Future<void> _refreshNoteItem() async {
    if (_noteItem == null) {
      logManager.logger.e("_noteItem is empty");
      return;
    }

    setState(() {
      _noteTags = (_noteItem?.tags)!;
      _isFavorite = (_noteItem?.favorite)!;
      _modifiedDate = (_noteItem?.mdate)!;
    });

    for (var tag in _noteTags) {
      _selectedTags.add(false);
    }

    _filteredTags = settingsManager.itemTags;

    _nameTextController.text = (_noteItem?.name)!;
    _notesTextController.text = (_noteItem?.notes)!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text('Note'),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: !_isEditing ? BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () async {
            Navigator.of(context).pop();
          },
        ) : CloseButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () async {
            setState((){
              _isEditing = false;
            });

            /// need to hold the widget.note as an item and hold onto it,
            /// widget.note is only needed for initState...
            ///
            await _refreshNoteItem();
          },
        ),
        // leading: BackButton(
        //   color: _isDarkModeEnabled ? Colors.greenAccent : null,
        //   onPressed: () {
        //     Navigator.of(context).pop();
        //   },
        // ),
        actions: [
          if (_isEditing)
            TextButton(
              child: Text(
                "Save",
                style: TextStyle(
                  color: _isDarkModeEnabled
                      ? (_fieldsAreValid ? Colors.greenAccent : Colors.grey)
                      : (_fieldsAreValid ? Colors.white : Colors.grey[400]),
                  fontSize: 18,
                ),
              ),
              style: ButtonStyle(
                  foregroundColor: _isDarkModeEnabled
                      ? (_fieldsAreValid
                          ? MaterialStateProperty.all<Color>(Colors.greenAccent)
                          : MaterialStateProperty.all<Color>(Colors.grey))
                      : null),
              onPressed: () async {
                // print("pressed done");
                await _pressedSaveNoteItem();

                setState(() {
                  _isEditing = !_isEditing;
                });

                if (!_isNewNote) {
                  Timer(Duration(milliseconds: 100), () {
                    FocusScope.of(context).unfocus();
                  });
                }
              },
            ),
          if (!_isEditing)
            TextButton(
              child: Text(
                "Edit",
                style: TextStyle(
                  color: _isDarkModeEnabled
                      ? (_fieldsAreValid ? Colors.greenAccent : Colors.grey)
                      : (_fieldsAreValid ? Colors.white : Colors.grey),
                  fontSize: 18,
                ),
              ),
              onPressed: _fieldsAreValid
                  ? () async {
                      // print("pressed done");
                      // await _pressedSaveNoteItem();

                      setState(() {
                        _isEditing = !_isEditing;
                      });
                      // if (!_isNewNote) {
                      //   Timer(Duration(milliseconds: 100), () {
                      //     FocusScope.of(context).unfocus();
                      //   });
                      // }
                    }
                  : null,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(16.0),
                child: TextFormField(
                  cursorColor: _isDarkModeEnabled ? Colors.greenAccent : null,
                  autofocus: true,
                  autocorrect: false,
                  enabled: _isEditing,
                  decoration: InputDecoration(
                    labelText: 'Note Name',
                    // icon: Icon(
                    //   Icons.edit_outlined,
                    //   color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                    // ),
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
                    disabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color:
                            _isDarkModeEnabled ? Colors.blueGrey : Colors.grey,
                        width: 0.0,
                      ),
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 18.0,
                    color: _isDarkModeEnabled ? Colors.white : null,
                  ),
                  onChanged: (_) {
                    _validateFields();
                  },
                  onTap: () {
                    _validateFields();
                  },
                  onFieldSubmitted: (_) {
                    _validateFields();
                  },
                  // keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.done,
                  focusNode: _nameFocusNode,
                  controller: _nameTextController,
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: TextFormField(
                  cursorColor: _isDarkModeEnabled ? Colors.greenAccent : null,
                  autofocus: true,
                  autocorrect: false,
                  enabled: true,
                  minLines: 5,
                  maxLines: 10,
                  readOnly: !_isEditing,
                  decoration: InputDecoration(
                    labelText: 'Notes',
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
                            ?  (_isEditing ? Colors.greenAccent : Colors.grey)
                            : (_isEditing ? Colors.blueAccent : Colors.grey),
                        width: 0.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: _isDarkModeEnabled ?
                               (_isEditing ? Colors.greenAccent : Colors.grey)
                              : (_isEditing ? Colors.blueAccent : Colors.grey),
                        width: 0.0,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color:
                            _isDarkModeEnabled ?
                            (_isEditing ? Colors.greenAccent : Colors.grey)
                            : (_isEditing ? Colors.blueAccent : Colors.grey),
                        width: 0.0,
                      ),
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 18.0,
                    color: _isDarkModeEnabled ? Colors.white : null,
                  ),
                  onChanged: (_) {
                    _validateFields();
                  },
                  onTap: () {
                    _validateFields();
                  },
                  onFieldSubmitted: (_) {
                    _validateFields();
                  },
                  // keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.newline,
                  focusNode: _notesFocusNode,
                  controller: _notesTextController,
                ),
              ),
              // Divider(color: _isDarkModeEnabled ? Colors.greenAccent : null),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isFavorite = !_isFavorite;
                          _isEditing = true;
                        });

                        _validateFields();
                      },
                      icon: Icon(
                        Icons.favorite,
                        color: _isFavorite
                            ? (_isDarkModeEnabled
                                ? Colors.greenAccent
                                : Colors.blue)
                            : Colors.grey,
                        size: 30.0,
                      ),
                    ),
                    TextButton(
                      child: Text(
                        'Favorite',
                        style: TextStyle(
                          fontSize: 16.0,
                          color:
                              _isDarkModeEnabled ? Colors.white : Colors.black,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _isFavorite = !_isFavorite;
                          _isEditing = true;
                        });

                        _validateFields();
                      },
                    ),
                    Spacer(),
                  ],
                ),
              ),
              // if (_noteTags.isNotEmpty)
              Divider(color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey),
              // if (_noteTags.isNotEmpty)
              Center(
                child: Text(
                  "Tags",
                  style: TextStyle(
                    color: _isDarkModeEnabled
                        ? Colors.greenAccent
                        : Colors.blueAccent,
                    fontSize: 18,
                    // decoration: TextDecoration.underline,
                  ),
                ),
              ),
              // if (_noteTags.isNotEmpty)
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Container(
                  height: 44,
                  child: ListView.separated(
                    itemCount: _noteTags.length + 1,
                    separatorBuilder: (context, index) => Divider(
                      color: _isDarkModeEnabled ? Colors.greenAccent : null,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      // var addTagItem;
                      // if (index == 0)
                      final addTagItem = Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              _showModalAddTagView();
                              // _displayCreateTagDialog(context);
                            },
                            icon: Icon(
                              Icons.add_circle,
                              color: Colors.blueAccent,
                            ),
                          ),
                          TextButton(
                            child: Text(
                              "Add Tag",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            onPressed: () {
                              _showModalAddTagView();
                              // _displayCreateTagDialog(context);
                            },
                          ),
                          SizedBox(
                            width: 16,
                          ),
                        ],
                      );

                      var currentTagItem;
                      // final len = _selectedTags.length;
                      if (index > 0) {
                        currentTagItem = GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTags[index - 1] =
                                  !_selectedTags[index - 1];
                            });
                          },
                          child: Row(
                            children: [
                              // if (!_selectedTags[index-1])
                              SizedBox(
                                width: 8,
                              ),
                              Padding(
                                padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
                                child: Text(
                                  "${_noteTags[index - 1]}",
                                  style: TextStyle(
                                    color: _isDarkModeEnabled
                                        ? Colors.greenAccent
                                        : Colors.blueAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (_selectedTags.length >= index - 1 &&
                                  _selectedTags[index - 1])
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _noteTags.removeAt(index - 1);
                                      _selectedTags.removeAt(index - 1);
                                      _isEditing = true;
                                    });

                                    _validateFields();
                                  },
                                  icon: Icon(
                                    Icons.cancel_sharp,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              if (!_selectedTags[index - 1])
                                SizedBox(
                                  width: 8,
                                ),
                            ],
                          ),
                        );
                      }

                      return Padding(
                        padding: EdgeInsets.all(4),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTags[index - 1] =
                                  !_selectedTags[index - 1];
                            });
                          },
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: _isDarkModeEnabled
                                  ? Colors.greenAccent.withOpacity(0.25)
                                  : Colors.blueAccent.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: (index == 0 ? addTagItem : currentTagItem),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : null,
              ),
              if (!_isNewNote)
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      // SizedBox(height: 8),
                      Text(
                        widget.note == null ? '' : 'id: ${(widget.note?.id)!}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _isDarkModeEnabled ? Colors.white : null,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'created: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse((widget.note?.cdate)!))}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _isDarkModeEnabled ? Colors.white : null,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'modified: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse(_modifiedDate))}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _isDarkModeEnabled ? Colors.white : null,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        widget.note == null
                            ? ''
                            : 'size: ${(((widget.note)!).toRawJson().length / 1024).toStringAsFixed(2)} KB',
                        style: TextStyle(
                          fontSize: 14,
                          color: _isDarkModeEnabled ? Colors.white : null,
                        ),
                      ),
                      if (!_isNewNote)
                        Divider(
                          color: _isDarkModeEnabled ? Colors.greenAccent : null,
                        ),
                      if (!_isNewNote)
                        Padding(
                          padding: EdgeInsets.all(16.0),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: _isDarkModeEnabled
                                  ? BorderSide(color: Colors.greenAccent)
                                  : null,
                            ),
                            child: Text(
                              'Delete Item',
                              style: TextStyle(
                                color: _isDarkModeEnabled
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                              ),
                            ),
                            onPressed: () {
                              _showConfirmDeleteItemDialog();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
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

  void _validateFields() {
    final name = _nameTextController.text;
    final notes = _notesTextController.text;

    if (name.isEmpty) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    if (notes.isEmpty) {
      setState(() {
        _fieldsAreValid = false;
      });
      return;
    }

    setState(() {
      _fieldsAreValid = true;
    });
  }

  _pressedSaveNoteItem() async {

    var createDate = DateTime.now().toIso8601String();
    var uuid = cryptor.getUUID();

    _modifiedDate = createDate;

    if (!_isNewNote) {
      createDate = (widget.note?.cdate)!;
      uuid = (widget.note?.id)!;
      setState(() {
        _modifiedDate = DateTime.now().toIso8601String();
      });
    }

    final name = _nameTextController.text;
    final notes = _notesTextController.text;

    /// TODO: remove this
    // final encodedAllPlaintextLength = utf8.encode(name).length + utf8.encode(notes).length;
    // settingsManager.doEncryption(encodedAllPlaintextLength);
    // cryptor.setTempKeyIndex(keyIndex);

    // final itemId = uuid + "-" + createDate + "-" + _modifiedDate;

    // final encryptedName = await cryptor.encrypt(name);
    //
    // final encryptedNotes = await cryptor.encrypt(notes);

    final noteItem = NoteItem(
      id: uuid,
      keyId: keyManager.keyId,
      version: AppConstants.noteItemVersion,
      name: name,
      notes: notes,
      favorite: _isFavorite,
      tags: _noteTags,
      geoLock: null,
      mac: "",
      cdate: createDate,
      mdate: _modifiedDate,
    );

    /// call to encrypt our parameters
    await noteItem.encryptParams();

    _noteItem = noteItem;

    final noteItemJson = noteItem.toRawJson();
    // logManager.logger.d("save noteItem: $noteItemJson");

    final genericItem = GenericItem(type: "note", data: noteItemJson);
    // logger.d('genericItem toRawJson: ${genericItem.toRawJson()}');

    final genericItemString = genericItem.toRawJson();

    /// save generic item in keychain
    final status = await keyManager.saveItem(uuid, genericItemString);

    if (status) {
      EasyLoading.showToast('Saved Item', duration: Duration(seconds: 1));
      if (_isNewNote) {
        Navigator.of(context).pop('savedItem');
      }
    } else {
      _showErrorDialog('Could not save the item.');
    }
  }

  void _showConfirmDeleteItemDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Item'),
        content: Text('Are you sure you want to delete this item?'),
        actions: <Widget>[
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel'),
          ),
          OutlinedButton(
            style: TextButton.styleFrom(
              primary: Colors.redAccent,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _confirmedDeleteItem();
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmedDeleteItem() async {
    final status = await keyManager.deleteItem((widget.note?.id)!);

    if (status) {
      Navigator.of(context).pop();
    } else {
      _showErrorDialog('Delete item failed');
    }
  }

  _showModalAddTagView() async {
    showModalBottomSheet(
        backgroundColor: _isDarkModeEnabled ? Colors.black : null,
        elevation: 8,
        context: context,
        isScrollControlled: true,
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
                            FocusScope.of(context).unfocus();

                            state(() {
                              _tagTextController.text = "";
                              _tagTextFieldValid = false;
                              _filteredTags = settingsManager.itemTags;
                            });

                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      Spacer(),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 90,
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: TextFormField(
                              cursorColor: _isDarkModeEnabled
                                  ? Colors.greenAccent
                                  : null,
                              autocorrect: false,
                              obscureText: false,
                              minLines: 1,
                              maxLines: 1,
                              decoration: InputDecoration(
                                labelText: 'Tag',
                                hintStyle: TextStyle(
                                  fontSize: 18.0,
                                  color:
                                      _isDarkModeEnabled ? Colors.white : null,
                                ),
                                labelStyle: TextStyle(
                                  fontSize: 18.0,
                                  color:
                                      _isDarkModeEnabled ? Colors.white : null,
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
                                prefixIcon: Icon(
                                  Icons.tag,
                                  color:
                                      _isDarkModeEnabled ? Colors.grey : null,
                                ),
                                suffix: IconButton(
                                  icon: Icon(
                                    Icons.cancel_outlined,
                                    size: 20,
                                    color: _isDarkModeEnabled
                                        ? Colors.greenAccent
                                        : null,
                                  ),
                                  onPressed: () {
                                    state(() {
                                      _tagTextController.text = "";
                                      _tagTextFieldValid = false;
                                      _filteredTags = settingsManager.itemTags;
                                    });
                                  },
                                ),
                              ),
                              style: TextStyle(
                                fontSize: 18.0,
                                color: _isDarkModeEnabled ? Colors.white : null,
                              ),
                              onChanged: (pwd) {
                                _validateModalField(state);
                              },
                              onTap: () {
                                _validateModalField(state);
                              },
                              onFieldSubmitted: (_) {
                                _validateModalField(state);
                              },
                              keyboardType: TextInputType.visiblePassword,
                              textInputAction: TextInputAction.done,
                              // focusNode: _passwordFocusNode,
                              controller: _tagTextController,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: ElevatedButton(
                          style: ButtonStyle(
                            backgroundColor: _tagTextFieldValid
                                ? (_isDarkModeEnabled
                                    ? MaterialStateProperty.all<Color>(
                                        Colors.greenAccent)
                                    : null)
                                : MaterialStateProperty.all<Color>(
                                    Colors.blueGrey),
                          ),
                          child: Text(
                            "Add",
                            style: TextStyle(
                              color: _tagTextFieldValid
                                  ? (_isDarkModeEnabled
                                      ? Colors.black
                                      : Colors.white)
                                  : Colors.black54,
                            ),
                          ),
                          onPressed: _tagTextFieldValid
                              ? () {
                                  FocusScope.of(context).unfocus();

                                  final userTag = _tagTextController.text;
                                  if (!_noteTags.contains(userTag)) {
                                    state(() {
                                      _noteTags.add(userTag);
                                      _selectedTags.add(false);
                                    });

                                    if (!settingsManager.itemTags
                                        .contains(userTag)) {
                                      var updatedTagList =
                                          settingsManager.itemTags.copy();
                                      updatedTagList.add(userTag);

                                      updatedTagList
                                          .sort((e1, e2) => e1.compareTo(e2));

                                      settingsManager
                                          .saveItemTags(updatedTagList);

                                      state(() {
                                        _filteredTags = updatedTagList;
                                      });
                                    }
                                  }

                                  state(() {
                                    _isEditing = true;
                                    _tagTextController.text = "";
                                    _tagTextFieldValid = false;
                                    _filteredTags = settingsManager.itemTags;
                                  });

                                  _validateFields();
                                  _validateModalField(state);
                                  Navigator.of(context).pop();
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Container(
                        child: ListView.separated(
                          itemCount: _filteredTags.length,
                          separatorBuilder: (context, index) => Divider(
                            color:
                                _isDarkModeEnabled ? Colors.greenAccent : null,
                          ),
                          scrollDirection: Axis.vertical,
                          itemBuilder: (context, index) {
                            final isCurrentTag =
                                _noteTags.contains(_filteredTags[index]);
                            return ListTile(
                              title: Text(
                                _filteredTags[index],
                                // settingsManager.itemTags[index],
                                // "test",
                                style: TextStyle(
                                  color: isCurrentTag
                                      ? Colors.grey
                                      : (_isDarkModeEnabled
                                          ? Colors.white
                                          : Colors.blueAccent),
                                ),
                              ),
                              leading: Icon(
                                Icons.discount,
                                color: isCurrentTag
                                    ? Colors.grey
                                    : (_isDarkModeEnabled
                                        ? Colors.greenAccent
                                        : Colors.blueAccent),
                              ),
                              onTap: !isCurrentTag
                                  ? () {
                                      setState(() {
                                        _tagTextController.text =
                                            _filteredTags[index];
                                        _validateModalField(state);
                                      });
                                    }
                                  : null,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          });
        });
  }

  _validateModalField(StateSetter state) async {
    final text = _tagTextController.text;

    state(() {
      _tagTextFieldValid =
          _tagTextController.text.isNotEmpty && !_noteTags.contains(text);
    });

    if (text.isEmpty) {
      state(() {
        _filteredTags = settingsManager.itemTags;
      });
    } else {
      _filteredTags = [];
      for (var t in settingsManager.itemTags) {
        if (t.contains(text)) {
          _filteredTags.add(t);
        }
      }
      state(() {});
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('An error occured'),
        content: Text(message),
        actions: <Widget>[
          ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: Text('Okay'))
        ],
      ),
    );
  }
}
