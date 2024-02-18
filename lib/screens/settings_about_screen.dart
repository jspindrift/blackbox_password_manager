import 'dart:async';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ecdsa/ecdsa.dart' as ecdsa;
import 'package:elliptic/elliptic.dart' as elliptic;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bip39/bip39.dart' as bip39;

import '../helpers/AppConstants.dart';
import '../managers/Cryptor.dart';
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
  int _modIndex = 0;

  Timer? otpTimer;
  String _otpTokenWords = "";

  List<int> _appKeyBytes = [];

  final algorithm_secp256k1 = elliptic.getS256();
  final algorithm_nomac = AesCtr.with256bits(macAlgorithm: MacAlgorithm.empty);


  final _settingsManager = SettingsManager();
  final _deviceManager = DeviceManager();
  final _logManager = LogManager();
  final _keyManager = KeychainManager();
  final _cryptor = Cryptor();


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

      await _generateAppTOTP();

      await _calculateOTPToken();

      await _startOTPTimer();
    });

    _passwordFileSize = _keyManager.passwordItemsSize;
  }

  Future<void> _generateAppTOTP() async {
    final keyEnv = dotenv.env["KEY_COMPANY_APP"];
    if (keyEnv == null) {
      return;
    }

    if (keyEnv.isEmpty) {
      return;
    }

    final appVersionAndBuildNumber = _settingsManager.versionAndBuildNumber();
    final convertedSeed = _cryptor.mnemonicToEntropy(keyEnv!);
    // final seedEntropy = hex.decode(convertedSeed);
    // _logManager.logger.d("keyEnv: ${keyEnv}");

    // _logManager.logger.d("converted: ${"${convertedSeed}:$appVersionAndBuildNumber"}");
    final Kpriv = _cryptor.sha256("${convertedSeed}:$appVersionAndBuildNumber");
    // _logManager.logger.d("Kpriv: ${Kpriv}");
    _appKeyBytes = hex.decode(Kpriv); // seedEntropy

    // final privateKeyGen = elliptic.PrivateKey(
    //   algorithm_secp256k1,
    //   BigInt.parse(Kpriv, radix: 16),
    // );
    //
    // final pubGen = privateKeyGen.publicKey;
    // final xpub = algorithm_secp256k1.publicKeyToCompressedHex(pubGen);
    // _logManager.logger.d("xpub: ${xpub}");
  }

  Future<void> _calculateOTPToken() async {
    if (_appKeyBytes.isEmpty) {
      return;
    }
    final otpTimeInterval = AppConstants.appTOTPDefaultTimeInterval;
    final t = AppConstants.appTOTPStartTime;
    final otpStartTime = DateTime.parse(t);
    // print("otpStartTime: ${otpStartTime} | ${otpStartTime.second}");

    final timestamp = DateTime.now();

    if (timestamp.isAfter(otpStartTime)) {
      final diff_sec = timestamp.difference(otpStartTime).inSeconds;
      // print("diff_sec: ${diff_sec}");

      /// this gives the current step within the time interval 0-30
      final mod_sec = diff_sec.toInt() % otpTimeInterval.toInt();
      setState(() {
        _modIndex = mod_sec;
      });

      /// this gives the iteration number we are on
      final div_sec = (diff_sec.toInt() / otpTimeInterval.toInt());
      final div_sec_floor = div_sec.floor();
      // print("div_sec: ${div_sec}");
      // print("div_sec_floor: ${div_sec_floor}");

      var divHex = div_sec_floor.toRadixString(16);
      // print("divHex: $divHex");

      /// add "0" if # of hex chars is odd
      if (divHex.length % 2 == 1) {
        divHex = "0" + divHex;
      }

      final divBytes = hex.decode(divHex);
      final nonce = List<int>.filled(16, 0);
      final pad = nonce;

      final iv = nonce.sublist(0, nonce.length - divBytes.length) + divBytes;
      // print("iv: $iv");
      // print("iv.hex: ${hex.encode(iv)}");

      final secretKeyMac = SecretKey(_appKeyBytes);
      /// Encrypt the appended keys
      final secretBox = await algorithm_nomac.encrypt(
        pad,
        secretKey: secretKeyMac,
        nonce: iv,
      );

      final tokenWords = bip39.entropyToMnemonic(hex.encode(secretBox.cipherText));
      // print("token words: ${tokenWords}");
      final tokenParts = tokenWords.split(" ");

      final macWords = tokenParts[0] + " " + tokenParts[1] + " " + tokenParts[2] + " " + tokenParts.last;
      _otpTokenWords = macWords;
    }
  }

  Future<void> _startOTPTimer() async {
    otpTimer = Timer.periodic(Duration(seconds:1),(value) async {
      // print("timer: ${value.tick}");

      await _calculateOTPToken();
    });
  }

  void _cancelOTPTimer() {
    if (otpTimer != null) {
      otpTimer!.cancel();
      otpTimer = null;
    }
  }

  @override
  void dispose() {
    super.dispose();

    _cancelOTPTimer();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? (Platform.isAndroid ? (AppConstants.useMaterial3 ? Colors.black12 : Colors.black54) : (AppConstants.useMaterial3 ? Colors.black26 : Colors.black54)) : Colors.white70, //Colors.blue[50],//Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "About Blackbox",
          style: TextStyle(
            color: _isDarkModeEnabled ? Colors.white : Colors.white,
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : Colors.blueAccent,
        leading: BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
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
                  "App Version: ${_settingsManager.versionAndBuildNumber()}",
                  style: TextStyle(
                    color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: kDebugMode ? Text(
                  "[${AppConstants.appTOTPDefaultTimeInterval - _modIndex}] app phrase:\n$_otpTokenWords",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                    color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  ),
                ) : null,
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
              Visibility(
                visible: true,
                child:Divider(
                    color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
                ),
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
                  textAlign: TextAlign.center,
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
        currentIndex: _selectedIndex,
        selectedItemColor:
        _isDarkModeEnabled ? Colors.white : Colors.white,
        unselectedItemColor: Colors.green,
        unselectedIconTheme: IconThemeData(color: Colors.greenAccent),
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(
              Icons.star,
              color: Colors.grey,
            ),
            label: 'Favorites',
            backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
            activeIcon: Icon(
              Icons.star,
              color:
              _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
            ),
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.category,
              color: Colors.grey,
            ),
            label: 'Categories',
            backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
            activeIcon: Icon(
              Icons.category,
              color:
              _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
            ),
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.discount,
              color: Colors.grey,
            ),
            label: 'Tags',
            backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
            activeIcon: Icon(
              Icons.discount,
              color:
              _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
            ),
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.settings,
              color: Colors.grey,
            ),
            label: 'Settings',
            backgroundColor: _isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
            activeIcon: Icon(
              Icons.settings,
              color:
              _isDarkModeEnabled ? Colors.greenAccent : Colors.white,
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


