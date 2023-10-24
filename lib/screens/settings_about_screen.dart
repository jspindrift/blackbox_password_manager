import 'dart:io';
import '../managers/Cryptor.dart';
import 'package:flutter/material.dart';
import '../helpers/AppConstants.dart';
import '../managers/SettingsManager.dart';
import '../managers/DeviceManager.dart';
import '../managers/LogManager.dart';
import '../managers/KeychainManager.dart';
import 'home_tab_screen.dart';

class SettingsAboutScreen extends StatefulWidget {
  const SettingsAboutScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/settings_about_screen';

  @override
  State<SettingsAboutScreen> createState() => _SettingsAboutScreenState();
}

class _SettingsAboutScreenState extends State<SettingsAboutScreen> {
  var _deviceId = '';
  var _deviceName = '';

  bool _isDarkModeEnabled = false;

  bool _showEncryptionDetails = false;

  int _passwordFileSize = 0;
  int _selectedIndex = 3;

  final _settingsManager = SettingsManager();
  final _deviceManager = DeviceManager();
  final _logManager = LogManager();
  final _keyManager = KeychainManager();

  @override
  void initState() {
    super.initState();

    _logManager.log("SettingsAboutScreen", "initState", "initState");

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;



    _deviceManager.initialize().then((value) async {
      // print("device data: ${_deviceManager.deviceData}");
      // print("device data: ${_deviceManager.deviceData.toString()}");
      // print("model: ${await _deviceManager.getDeviceModel()}");
      // print("data: ${_deviceManager.deviceData}");

      if (Platform.isIOS) {
        setState(() {
          _deviceId = _deviceManager.deviceData['identifierForVendor'];
          _deviceName = _deviceManager.deviceData['name'];
        });
      } else if (Platform.isAndroid) {
        _deviceManager.getDeviceId().then((value) {
          if (value != null) {
            setState(() {
              _deviceId = value;
            });
          }
        });
        setState(() {
          _deviceName = _deviceManager.deviceData['device'];
        });
      }
    });

    _passwordFileSize = _keyManager.passwordItemsSize;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text('About Blackbox'),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              ListTile(
                enabled: false,
                title: Text(
                  "App Version:",
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  _settingsManager.versionAndBuildNumber(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                    color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              ),
              ListTile(
                enabled: false,
                title: Text(
                  "Device Name:",
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  "${_deviceName}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                    color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              ),
              ListTile(
                enabled: false,
                title: Text(
                  "Device ID:",
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  "${_deviceId}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                    color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.grey[500] : Colors.grey,
              ),
              ListTile(
                enabled: false,
                title: Text(
                  "Vault ID:",
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  "${_keyManager.vaultId.toUpperCase()}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                    color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.grey[500] : Colors.grey,
              ),
              Visibility(
                visible: true,
                child: ListTile(
                  title: Text(
                    "Key ID:",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                    ),
                  ),
                  subtitle: Text(
                    "${_keyManager.keyId.toUpperCase()}\n",
                    style: TextStyle(
                      fontSize: 16,
                      color: _isDarkModeEnabled ? Colors.white : null,
                    ),
                  ),
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              ),
              ListTile(
                title: Text(
                  "Vault Items:\n${_keyManager.numberOfPasswordItems} items, ${_keyManager.numberOfPreviousPasswords} old passwords",
                  style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null),
                ),
                subtitle: Text(
                  "\n${(_passwordFileSize / 1024).toStringAsFixed(2)} KB",
                  style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null),
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              ),
              ListTile(
                title: Text(
                  "Vault Key Encryption Info",
                  style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null),
                ),
                subtitle: Text(
                    _showEncryptionDetails ? "\n${_settingsManager.numBytesEncrypted}"
                        " bytes = ${(_settingsManager.numBytesEncrypted / 1024).toStringAsFixed(2)} KB\n${_settingsManager.numBlocksEncrypted}"
                        " blocks encrypted\n${_settingsManager.numRolloverEncryptionCounts} roll-overs" : "tap icon to show details\n\n${_settingsManager.numBlocksEncrypted} blocks encrypted",

                  style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null),
                ),
                leading: IconButton(
                    icon: Icon(
                        Icons.info,
                      size: 40,
                      color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                    ),
                  onPressed: (){
                      setState(() {
                        _showEncryptionDetails = !_showEncryptionDetails;
                      });
                  },
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              ),
              ListTile(
                title: Text(
                  "Key Health",
                  style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null),
                ),
                subtitle: Text(
                  "% ${(100* (AppConstants.maxEncryptionBlocks-_settingsManager.numBlocksEncrypted)/AppConstants.maxEncryptionBlocks).toStringAsFixed(6)}",
                  style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                  ),
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              ),
              Visibility(
                visible: false,
                child: ListTile(
                  title: Text(
                    "Key ID:",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                    ),
                  ),
                  subtitle: Text(
                    "${_keyManager.keyId.toUpperCase()}\n",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                    ),
                  ),
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
              ),
              Visibility(
                visible: false,
                child: ListTile(
                title: Text(
                    "Device Data:\n",
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : null,
                  ),
                ),
                subtitle: Text(
                    "${_settingsManager.deviceManager.deviceData.toString()}\n",
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : null,
                  ),
                ),
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

    _settingsManager.changeRoute(index);
  }
}
