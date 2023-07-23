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

  final settingsManager = SettingsManager();
  final deviceManager = DeviceManager();
  final logManager = LogManager();
  final keyManager = KeychainManager();

  @override
  void initState() {
    super.initState();

    logManager.log("SettingsAboutScreen", "initState", "initState");

    _isDarkModeEnabled = settingsManager.isDarkModeEnabled;



    deviceManager.initialize().then((value) async {
      // print("device data: ${deviceManager.deviceData}");
      // print("device data: ${deviceManager.deviceData.toString()}");
      // print("model: ${await deviceManager.getDeviceModel()}");
      // print("data: ${deviceManager.deviceData}");

      if (Platform.isIOS) {
        setState(() {
          _deviceId = deviceManager.deviceData['identifierForVendor'];
          _deviceName = deviceManager.deviceData['name'];
        });
      } else if (Platform.isAndroid) {
        deviceManager.getDeviceId().then((value) {
          if (value != null) {
            setState(() {
              _deviceId = value;
            });
          }
        });
        setState(() {
          _deviceName = deviceManager.deviceData['device'];
        });
      }
    });

    _passwordFileSize = keyManager.passwordItemsSize;
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
                  settingsManager.versionAndBuildNumber(),
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
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
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
                  "${keyManager.vaultId.toUpperCase()}",
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
                title: Text(
                  "Vault Items:\n${keyManager.numberOfPasswordItems} items, ${keyManager.numberOfPreviousPasswords} old passwords",
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
                    _showEncryptionDetails ? "\n${settingsManager.numBytesEncrypted}"
                        " bytes = ${(settingsManager.numBytesEncrypted / 1024).toStringAsFixed(2)} KB\n${settingsManager.numBlocksEncrypted}"
                        " blocks encrypted\n${settingsManager.numRolloverEncryptionCounts} roll-overs" : "tap icon to show details\n\n${settingsManager.numBlocksEncrypted} blocks encrypted",

                  // "\n${(_passwordFileSize / 1024).toStringAsFixed(2)} KB",
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
                  "% ${(100* (AppConstants.maxEncryptionBlocks-settingsManager.numBlocksEncrypted)/AppConstants.maxEncryptionBlocks).toStringAsFixed(6)}",
                  // "\n${(_passwordFileSize / 1024).toStringAsFixed(2)} KB",
                  style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null),
                ),
              ),
              Divider(
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
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
}
