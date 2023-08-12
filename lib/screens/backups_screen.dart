import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import '../helpers/AppConstants.dart';
import '../helpers/WidgetUtils.dart';
import '../managers/FileManager.dart';
import '../models/RecoveryKeyCode.dart';
import '../models/VaultItem.dart';
import '../models/GenericItem.dart';
import '../managers/Cryptor.dart';
import '../managers/KeychainManager.dart';
import '../managers/DeviceManager.dart';
import '../managers/BackupManager.dart';
import '../managers/SettingsManager.dart';
import '../managers/LogManager.dart';
import '../managers/Hasher.dart';
import '../widgets/QRScanView.dart';
import 'home_tab_screen.dart';


class BackupsScreen extends StatefulWidget {
  const BackupsScreen({
    Key? key,
  }) : super(key: key);
  static const routeName = '/backups_screen';

  @override
  State<BackupsScreen> createState() => _BackupsScreenState();
}

class _BackupsScreenState extends State<BackupsScreen> {
  final _dialogTextFieldController = TextEditingController();
  final _dialogRestoreTextFieldController = TextEditingController();
  final _dialogLocalChangeNameTextFieldController = TextEditingController();

  FocusNode _dialogTextFieldFocusNode = FocusNode();
  FocusNode _dialogRestoreTextFieldFocusNode = FocusNode();
  FocusNode _dialogChangeLocalNameFocusNode = FocusNode();

  List<VaultItem> _backups = [];
  List<bool> _matchingKeyList = [];
  List<bool> _matchingDeviceList = [];

  VaultItem? _externalVaultItem; // SD card vault on Android
  int _externalVaultItemSize = 0;
  bool _hasExternalVault = false;
  bool _externalVaultHasRecoveryKeys = false;
  String _externalVaultHash = "";
  bool _hasMatchingExternalVaultKeyData = false;


  VaultItem? _localVaultItem;
  int _localVaultItemSize = 0;


  bool _hasMatchingLocalVaultKeyData = false;
  bool _localVaultHasRecoveryKeys = false;
  bool _shouldSaveToSDCard = false;
  bool _shouldSaveToSDCardOnly = false;

  bool _vaultKeyIsDifferent = false;

  int _localVaultNumEncryptedBlocks = 0;
  int _externalVaultNumEncryptedBlocks = 0;

  List<RecoveryKey>? _localVaultRecoveryKeys = [];
  List<RecoveryKey>? _externalVaultRecoveryKeys = [];

  String _deviceId = "";
  String _localVaultHash = "";

  bool _shouldHideRecoveryPasswordField = true;

  bool _isInitState = true;

  List<int> _backupFileSizes = [];

  int _selectedIndex = 3;

  bool _enableBackupNameOkayButton = false;
  bool _enableRestoreBackupOkayButton = false;
  bool _enableRestoreBackupCancelButton = true;

  // determine if we are accessing this screen from login screen or within
  // a session in the app
  bool _loginScreenFlow = false;
  bool _isDarkModeEnabled = false;

  final keyManager = KeychainManager();
  final deviceManager = DeviceManager();
  final cryptor = Cryptor();
  final backupManager = BackupManager();
  final settingsManager = SettingsManager();
  final logManager = LogManager();
  final fileManager = FileManager();

  @override
  void initState() {
    super.initState();

    logManager.log("BackupsScreen", "initState", "initState");

    _isDarkModeEnabled = settingsManager.isDarkModeEnabled;

    _shouldSaveToSDCard = settingsManager.saveToSDCard;
    _shouldSaveToSDCardOnly = settingsManager.saveToSDCardOnly;

    deviceManager.initialize();

    deviceManager.getDeviceId().then((value) {
      if (value != null) {
        setState(() {
          _deviceId = value;
        });
      }
    });

    _fetchBackups();
  }

  Future<GenericItemList> _getKeychainVaultState() async {
    var finalGenericItemList = GenericItemList(list: []);
    var localGenericItemList = await keyManager.getAllItemsForBackup() as GenericItemList;
    var list = localGenericItemList.list;
    if (list == null) {
      return finalGenericItemList;
    }
    list.sort((a, b) {
      return b.data.compareTo(a.data);
    });

    final itree = await localGenericItemList.calculateMerkleTree();
    finalGenericItemList = GenericItemList(list: list);

    return finalGenericItemList;
  }

  _fetchBackups() async {

    keyManager.readEncryptedKey().then((value) {
      setState(() {
        _loginScreenFlow = !keyManager.hasPasswordItems;
      });
    });

    if (!_isInitState) {
      WidgetUtils.showSnackBarDuration(
          context, "Refreshing Backup List...", Duration(seconds: 2));
    }

    _isInitState = false;
    _localVaultItem = null;
    _externalVaultItem = null;

    /// get the vault from documents directory and find the matching backup
    var vaultFileString = "";
    var externalVaultFileString = "";

    if (Platform.isAndroid) {
      /// see if we have a vault backup from SD card
      externalVaultFileString = await fileManager.readVaultDataSDCard();
      vaultFileString = await fileManager.readNamedVaultData();

      if (externalVaultFileString.isNotEmpty) {
        _externalVaultRecoveryKeys = [];
        /// if no SD card vault, get default file vault location
        _decryptExternalVault(externalVaultFileString);
      }
    } else {
      vaultFileString = await fileManager.readNamedVaultData();
      logManager.logger.d("read named vault file: ${vaultFileString}");
    }

    // logManager.logger.d("read vault file: ${vaultFileString}");

    _localVaultHash = cryptor.sha256(vaultFileString);
    _localVaultRecoveryKeys = [];
    _backups = [];

    _decryptLocalVault(vaultFileString);


    setState(() {
      /// filter through the list if on Android for duplicate backups
      var backupIds = [];
      List<VaultItem> tempBackups = [];

      for (var backup in _backups) {
        // print("backup ${backup.id}");
        if (!backupIds.contains(backup.id)) {
          backupIds.add(backup.id);
          tempBackups.add(backup);
        }
      }

      _backups = tempBackups;

      /// sort backups by date with latest first
      _backups.sort((a, b) {
        return b.cdate.compareTo(a.cdate);
      });

      _backupFileSizes = [];
      _backups.forEach((element) async {
        _backupFileSizes.add(element.toRawJson().length);
      });

      _computeBackupList();
    });
  }

  _decryptLocalVault(String vaultItemString) async {
    if (vaultItemString.isNotEmpty) {
      try {
        _localVaultItem = VaultItem.fromRawJson(vaultItemString);
        if (_localVaultItem != null) {
          _backups.add(_localVaultItem!);

          final encryptedBlob = (_localVaultItem?.blob)!;
          final vaultId = (_localVaultItem?.id)!;
          final deviceId = (_localVaultItem?.deviceId)!;
          final version = (_localVaultItem?.version)!;
          final cdate = (_localVaultItem?.cdate)!;
          final mdate = (_localVaultItem?.mdate)!;
          final name = (_localVaultItem?.name)!;

          final vaultDeviceData = (_localVaultItem?.deviceData)!;

          final currentDeviceData = settingsManager.deviceManager.deviceData;
          final decryptedVaultDeviceData = await cryptor.decrypt(vaultDeviceData);

          if (vaultDeviceData != null) {
            if (cryptor.sha256(decryptedVaultDeviceData) !=
                cryptor.sha256(currentDeviceData.toString())) {
              logManager.logger.w(
                  "device data changed!\ndecryptedVaultDeviceData:${decryptedVaultDeviceData}\n"
                      "currentDeviceData: ${currentDeviceData}");
            }
          }

          final idString =
              "${vaultId}-${deviceId}-${version}-${cdate}-${mdate}-${name}";

          final decryptedBlob = await cryptor.decryptBackupVault(
              encryptedBlob, idString);
          // logManager.logger.d("decryption: ${decryptedBlob.length}");

          if (decryptedBlob.isNotEmpty) {
            try {
              /// TODO: add this in
              var genericItems = GenericItemList.fromRawJson(decryptedBlob);
              // logManager.logger.d("decryption genericItems2: $genericItems2");

              if (genericItems != null) {
                setState(() {
                  _vaultKeyIsDifferent = false;
                });
              }
            } catch (e) {
              logManager.logger.e("can not decrypt current backup vault\n"
                  "vaultid: $vaultId: $e");

              // if (mounted) {
              //   setState(() {
              //     _hasMatchingLocalVaultId = keyManager.vaultId == vaultId;
              //   });
              // }
            }
          } else {
            logManager.logger.w(
                "can not decrypt current backup vault: $vaultId");
          }
        }

        if (mounted) {
          setState(() {
            final encryptedKeyNonce = (_localVaultItem?.encryptedKey
                .keyNonce)!;
            // logManager.logger.d("encryptedKeyNonce: ${encryptedKeyNonce}");

            cryptor.decrypt(encryptedKeyNonce).then((value) {
              final decryptedKeyNonce = value;
              logManager.logger.d("decryptedKeyNonce: ${decryptedKeyNonce}\n"
                  "base64decoded keyNonce: ${hex.decode(decryptedKeyNonce)}");

              final keyNonce = hex.decode(decryptedKeyNonce);
              final ablock = keyNonce.sublist(8, 12);
              final bblock = keyNonce.sublist(12, 16);

              // logManager.logger.d("ablock: ${ablock}\n"
              //     "bblock: ${bblock}");

              final rolloverBlockCount = int.parse(
                  hex.encode(ablock), radix: 16);
              final encryptedBlockCount = int.parse(
                  hex.encode(bblock), radix: 16);
              // logManager.logger.d(
              //     "encryptedBlockCount: ${encryptedBlockCount}\n"
              //         "rolloverBlockCount: ${rolloverBlockCount}");

              setState(() {
                _localVaultNumEncryptedBlocks = encryptedBlockCount;
              });
            });

            if ((_localVaultItem?.recoveryKeys)! != null) {
              _localVaultRecoveryKeys = (_localVaultItem?.recoveryKeys)!;
              if (_localVaultRecoveryKeys != null) {
                _localVaultHasRecoveryKeys =
                (_localVaultRecoveryKeys!.length > 0);
              }
            }

            _hasMatchingLocalVaultKeyData =
                (_localVaultItem?.encryptedKey.keyMaterial)! ==
                    keyManager.encryptedKeyMaterial;

            _localVaultItemSize = (_localVaultItem
                ?.toRawJson()
                .length)!;
          });
        }
      } catch (e) {
        logManager.logger.e("Exception: $e");
      }
    }
  }

  _decryptExternalVault(String externalVaultItemString) async {
    print("_decryptExternalVault");
    if (externalVaultItemString.isNotEmpty) {

      try {
        _externalVaultItem = VaultItem.fromRawJson(externalVaultItemString);
        _hasExternalVault = (_externalVaultItem != null);
        _externalVaultHash = cryptor.sha256(externalVaultItemString);

        if (_externalVaultItem != null) {
          _backups.add(_externalVaultItem!);

          final encryptedBlob = (_externalVaultItem?.blob)!;
          final vaultId = (_externalVaultItem?.id)!;
          final deviceId = (_externalVaultItem?.deviceId)!;
          final version = (_externalVaultItem?.version)!;
          final cdate = (_externalVaultItem?.cdate)!;
          final mdate = (_externalVaultItem?.mdate)!;
          final name = (_externalVaultItem?.name)!;

          final vaultDeviceData = (_externalVaultItem?.deviceData)!;

          final currentDeviceData = settingsManager.deviceManager.deviceData;
          final decryptedVaultDeviceData = await cryptor.decrypt(vaultDeviceData);

          if (vaultDeviceData != null) {
            if (cryptor.sha256(decryptedVaultDeviceData) !=
                cryptor.sha256(currentDeviceData.toString())) {
              logManager.logger.w(
                  "external device data changed!\ndecryptedVaultDeviceData:${decryptedVaultDeviceData}\n"
                      "currentDeviceData: ${currentDeviceData}");
            }
          }

          final idString =
              "${vaultId}-${deviceId}-${version}-${cdate}-${mdate}-${name}";

          final decryptedBlob = await cryptor.decryptBackupVault(
              encryptedBlob, idString);
          // logManager.logger.d("decryption: ${decryptedBlob.length}");

          if (decryptedBlob.isNotEmpty) {
            try {
              /// TODO: add this in
              var genericItems = GenericItemList.fromRawJson(decryptedBlob);
              // logManager.logger.d("decryption genericItems2: $genericItems2");

              if (genericItems != null) {
                // setState(() {
                //   _vaultKeyIsDifferent = false;
                // });
              }
            } catch (e) {
              logManager.logger.e("can not decrypt current external backup vault\n"
                  "vaultid: $vaultId: $e");

              // if (mounted) {
              //   setState(() {
              //     _hasMatchingLocalVaultId = keyManager.vaultId == vaultId;
              //   });
              // }
            }
          } else {
            logManager.logger.w(
                "can not decrypt current backup vault: $vaultId");
          }
        }

        if (mounted) {
          setState(() {
            final encryptedKeyNonce = (_externalVaultItem?.encryptedKey
                .keyNonce)!;
            // logManager.logger.d("external encryptedKeyNonce: ${encryptedKeyNonce}");

            cryptor.decrypt(encryptedKeyNonce).then((value) {
              final decryptedKeyNonce = value;
              // logManager.logger.d("decryptedKeyNonce: ${decryptedKeyNonce}\n"
              //     "base64decoded keyNonce: ${hex.decode(decryptedKeyNonce)}");

              final keyNonce = hex.decode(decryptedKeyNonce);
              final ablock = keyNonce.sublist(8, 12);
              final bblock = keyNonce.sublist(12, 16);

              // logManager.logger.d("ablock: ${ablock}\n"
              //     "bblock: ${bblock}");

              final rolloverBlockCount = int.parse(
                  hex.encode(ablock), radix: 16);
              final encryptedBlockCount = int.parse(
                  hex.encode(bblock), radix: 16);
              // logManager.logger.d(
              //     "encryptedBlockCount: ${encryptedBlockCount}\n"
              //         "rolloverBlockCount: ${rolloverBlockCount}");

              setState(() {
                _externalVaultNumEncryptedBlocks = encryptedBlockCount;
              });
            });

            if ((_externalVaultItem?.recoveryKeys)! != null) {
              _externalVaultRecoveryKeys = (_externalVaultItem?.recoveryKeys)!;
              if (_externalVaultRecoveryKeys != null) {
                _externalVaultHasRecoveryKeys =
                (_externalVaultRecoveryKeys!.length > 0);
              }
            }

            _hasMatchingExternalVaultKeyData =
                (_externalVaultItem?.encryptedKey.keyMaterial)! ==
                    keyManager.encryptedKeyMaterial;

            _externalVaultItemSize = (_localVaultItem
                ?.toRawJson()
                .length)!;
          });
        }
      } catch (e) {
        logManager.logger.e("Exception: $e");
      }
    }
  }

  /// iterate through our backups and see which ones have matching encrypted
  /// keys and device id's.  If matching encrypted key, then master passwords
  /// are the same as the current vault.  If matching device id's then the
  /// current device is the device that saved the backup.
  void _computeBackupList() async {
    _matchingKeyList = [];
    _matchingDeviceList = [];

    /// current key material to check against to signify same password backup
    final checkKeyMaterial = keyManager.encryptedKeyMaterial;
    // print('checkKeyMaterial: $checkKeyMaterial');

    _backups.forEach((element) {
      final encryptedKey = element.encryptedKey;
      final keyMaterial = encryptedKey.keyMaterial;
      final deviceId = element.deviceId;

      setState(() {
        /// check encrypted key material
        if (keyMaterial == checkKeyMaterial) {
          _matchingKeyList.add(true);
        } else {
          _matchingKeyList.add(false);
        }

        /// check deviceId
        if (_deviceId == deviceId) {
          _matchingDeviceList.add(true);
        } else {
          _matchingDeviceList.add(false);
        }
      });
    });
  }


  Widget getBackupTile() {
    var fsize = (_localVaultItemSize / 1024);
    var funit = "KB";
    if (_localVaultItemSize > pow(1024, 2)) {
      funit = "MB";
      fsize = (_localVaultItemSize / pow(1024, 2));
    }

    return Container(child:
      Column(children: [
        Padding(
          padding: EdgeInsets.all(8),
          child: ListTile(
              title: Text(
                "Local Backup\n",
                // _localVaultItem?.name != null ? "name: ${(_localVaultItem?.name)!}" : "",
            style: TextStyle(
              color: _isDarkModeEnabled ? Colors.white : null,
              fontWeight: FontWeight.bold,
              ),
            ),
              subtitle: Text(
                _localVaultItem?.id != null
                    ? "name: ${(_localVaultItem?.name)!}\n${(_localVaultItem?.numItems)!} items" : "",
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : null,
                  fontSize: 16,
                ),
              ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(8),
          child: ListTile(
            subtitle: Text(
              _localVaultItem?.id != null
                  ? "created: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse((_localVaultItem?.cdate)!))}\nmodified: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse((_localVaultItem?.mdate)!))}\n\nvault id: ${(_localVaultItem?.id)!.toUpperCase()}"
                  // "\nencryptedBlocks: ${(_localVaultNumEncryptedBlocks > 0 ? _localVaultNumEncryptedBlocks: "?")}\nkey health: ${(100* (AppConstants.maxEncryptionBlocks-_localVaultNumEncryptedBlocks)/AppConstants.maxEncryptionBlocks).toStringAsFixed(6)} %\n\n"
                  "\n\nfingerprint: ${_localVaultHash.substring(0, 32)}"
                  : "",
              style: TextStyle(
                color: _isDarkModeEnabled ? Colors.white : null,
                fontSize: 15,
              ),
            ),
          ),
        ),
        Divider(
          color: _isDarkModeEnabled ? Colors.grey : Colors.grey,
        ),
          Padding(
              padding: EdgeInsets.all(8),
              child:Text(
                  "size: ${fsize.toStringAsFixed(2)} $funit\nrecovery available: ${(_localVaultHasRecoveryKeys ? "✅ YES" : "❌ NO")}",
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
              ),
          ),
        Divider(
          color: _isDarkModeEnabled ? Colors.grey : Colors.grey,
        ),
        Row(children: [
          Spacer(),

          Padding(
          padding: EdgeInsets.all(8),
          child: IconButton(
            icon: Icon(
              Icons.restart_alt,
              color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
            ),
            onPressed: () async {
              _displayRestoreLocalBackupDialog(
                context,
                (_localVaultItem?.id)!,
                (_localVaultItem?.name)!,
                (_localVaultItem?.encryptedKey.salt)!,
              );
            }
          ),),
          Visibility(
            visible: _loginScreenFlow && _localVaultHasRecoveryKeys,
            child:Spacer(),
          ),
          Visibility(
            visible: _loginScreenFlow && _localVaultHasRecoveryKeys,
            child: IconButton(
              icon: Icon(
                Icons.camera,
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
              ),
              onPressed: () {
                _scanForRecoveryKey(true);
              },
            ),
          ),
          Spacer(),
          Padding(
            padding: EdgeInsets.all(8),
            child:IconButton(
              icon: Icon(
                Icons.info,
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
              ),
              onPressed: () {
                if (_localVaultItem != null) {
                  _displayBackupInfo(_localVaultItem!, _localVaultNumEncryptedBlocks, _localVaultHash.substring(0, 32));
                }
              },
            ),
          ),
          Visibility(
            visible: !_loginScreenFlow,
            child: Spacer(),
          ),
          Visibility(
            visible: !_loginScreenFlow,
            child:
          Padding(
            padding: EdgeInsets.all(8),
            child:IconButton(
              icon: Icon(
                Icons.edit,
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
              ),
              onPressed: () {
                _showChangeLocalBackupNameDialog();
              },
            ),
          ),
          ),
          Visibility(
            visible: !_loginScreenFlow,
            child: Spacer(),
          ),
          Visibility(
            visible: !_loginScreenFlow,
            child:Padding(
              padding: EdgeInsets.all(8),
              child:IconButton(
                icon: Icon(
                  Icons.delete,
                  color: Colors.redAccent,
                ),
                onPressed: () {
                  _showDeleteLocalBackupItemDialog();
                },
              ),
            ),
          ),
          Spacer(),
        ],),
        Divider(
          color: _isDarkModeEnabled ? Colors.grey : Colors.grey,
        ),
      ],),
    );
  }

  Widget getExternalBackupTile() {
    var fsize = (_externalVaultItemSize / 1024);
    var funit = "KB";
    if (_externalVaultItemSize > pow(1024, 2)) {
      funit = "MB";
      fsize = (_externalVaultItemSize / pow(1024, 2));
    }

    return Container(child:
    Column(children: [
      Padding(
        padding: EdgeInsets.all(8),
        child: ListTile(
          title: Text(
            "SD Card Backup\n",
            style: TextStyle(
              color: _isDarkModeEnabled ? Colors.white : null,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            _externalVaultItem?.id != null
                ? "name: ${(_externalVaultItem?.name)!}\n${(_externalVaultItem?.numItems)!} items" : "",
            style: TextStyle(
              color: _isDarkModeEnabled ? Colors.white : null,
              fontSize: 16,
            ),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.all(8),
        child: ListTile(
          subtitle: Text(
            _externalVaultItem?.id != null
                ? "created: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse((_externalVaultItem?.cdate)!))}"
                "\nmodified: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse((_externalVaultItem?.mdate)!))}"
                "\n\nvault id: ${(_externalVaultItem?.id)!.toUpperCase()}"
                  "\n\nfingerprint: ${_externalVaultHash.substring(0, 32)}"
                : "",
            style: TextStyle(
              color: _isDarkModeEnabled ? Colors.white : null,
              fontSize: 15,
            ),
          ),
        ),
      ),
      Divider(
        color: _isDarkModeEnabled ? Colors.grey : Colors.grey,
      ),
      Padding(
        padding: EdgeInsets.all(8),
        child:Text(
          "size: ${fsize.toStringAsFixed(2)} $funit\nrecovery available: ${(_externalVaultHasRecoveryKeys ? "✅ YES" : "❌ NO")}",
          style: TextStyle(
            color: _isDarkModeEnabled ? Colors.white : Colors.black,
            fontSize: 16,
          ),
        ),
      ),
      Divider(
        color: _isDarkModeEnabled ? Colors.grey : Colors.grey,
      ),
      Row(children: [
        Spacer(),

        Padding(
          padding: EdgeInsets.all(8),
          child: IconButton(
              icon: Icon(
                Icons.restart_alt,
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
              ),
              onPressed: () async {
                _displayRestoreExternalBackupDialog(
                  context,
                  (_externalVaultItem?.id)!,
                  (_externalVaultItem?.name)!,
                  (_externalVaultItem?.encryptedKey.salt)!,
                );
              }
          ),),
        Visibility(
          visible: _loginScreenFlow && _externalVaultHasRecoveryKeys,
          child:Spacer(),
        ),
        Visibility(
          visible: _loginScreenFlow && _externalVaultHasRecoveryKeys,
          child: IconButton(
            icon: Icon(
              Icons.camera,
              color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
            ),
            onPressed: () {
              _scanForRecoveryKey(false);
            },
          ),
        ),
        Spacer(),
        Padding(
          padding: EdgeInsets.all(8),
          child:IconButton(
            icon: Icon(
              Icons.info,
              color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
            ),
            onPressed: () {
              if (_externalVaultItem != null) {
                _displayBackupInfo(_externalVaultItem!, _externalVaultNumEncryptedBlocks, _externalVaultHash.substring(0, 32));
              }
            },
          ),
        ),
        Visibility(
          visible: !_loginScreenFlow,
          child: Spacer(),
        ),
        Visibility(
          visible: !_loginScreenFlow,
          child:
          Padding(
            padding: EdgeInsets.all(8),
            child:IconButton(
              icon: Icon(
                Icons.edit,
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
              ),
              onPressed: () {
                _showChangeExternalBackupNameDialog();
              },
            ),
          ),
        ),
        Visibility(
          visible: !_loginScreenFlow,
          child: Spacer(),
        ),
        Visibility(
          visible: !_loginScreenFlow,
          child:Padding(
            padding: EdgeInsets.all(8),
            child:IconButton(
              icon: Icon(
                Icons.delete,
                color: Colors.redAccent,
              ),
              onPressed: () {
                _showDeleteExternalBackupItemDialog();
              },
            ),
          ),
        ),
        Spacer(),
      ],),
      Divider(
        color: _isDarkModeEnabled ? Colors.grey : Colors.grey,
      ),
    ],),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black87 : null,
      appBar: AppBar(
        title: Text('Backups'),
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
        leading: BackButton(
          color: _isDarkModeEnabled ? Colors.greenAccent : null,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: <Widget>[
          Visibility(
            visible: _loginScreenFlow,
            child:
          IconButton(
            icon: Icon(
              Icons.refresh_outlined,
              color: _isDarkModeEnabled ? Colors.greenAccent : null,
            ),
            onPressed: () async {
              _fetchBackups();
            },
            tooltip: "Refresh backup list",
          ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          child: Column(
            children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Visibility(
                visible: !_loginScreenFlow,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: _isDarkModeEnabled
                            ? MaterialStateProperty.all<Color>(
                                Colors.greenAccent)
                            : null,
                      ),
                      child: Text(
                        "Create Backup",
                        style: TextStyle(
                          color:
                              _isDarkModeEnabled ? Colors.black : Colors.white,
                        ),
                      ),
                      onPressed: () async {
                        if (_localVaultItem != null) {
                          // WidgetUtils.showSnackBarDuration(context, "Backing Up Vault...", Duration(seconds: 2));

                          if ((_localVaultItem?.id)! == keyManager.vaultId &&
                              _hasMatchingLocalVaultKeyData) {

                            final status = await _createBackup();

                            EasyLoading.dismiss();

                            _fetchBackups();

                            if (status) {
                              EasyLoading.showToast("Backup Successful");
                            } else {
                              _showErrorDialog("Could not backup vault.");
                            }
                          } else {
                            _displayCreateBackupDialog(context, true);
                          }
                        } else {
                          _displayCreateBackupDialog(context, true);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          Visibility(
          visible: Platform.isAndroid && !_loginScreenFlow,
            child: ListTile(
              title: Text(
                "Save to SD Card",
                style: TextStyle(
                  fontSize: 16,
                  color: _isDarkModeEnabled ? Colors.white : Colors.black,
                ),
              ),
              trailing: Switch(
              thumbColor:
              MaterialStateProperty.all<Color>(Colors.white),
              trackColor: _shouldSaveToSDCard ? (_isDarkModeEnabled
                  ? MaterialStateProperty.all<Color>(
                  Colors.greenAccent)
                  : MaterialStateProperty.all<Color>(
                  Colors.blue)) : MaterialStateProperty.all<Color>(
                  Colors.grey),
              value: _shouldSaveToSDCard,
              onChanged: (value) {
                setState(() {
                  if (!value) {
                    _shouldSaveToSDCardOnly = value;
                  }
                  _shouldSaveToSDCard = value;
                });

                if (!value) {
                  _pressedSDCardOnlySwitch(value);
                }
                _pressedSDCardSwitch(value);
              },
            ),
            ),
          ),

              Visibility(
                visible: Platform.isAndroid && !_loginScreenFlow,
                child: ListTile(
                  title: Text(
                    "Save to SD Card Only",
                    style: TextStyle(
                      fontSize: 16,
                      color: _isDarkModeEnabled ? Colors.white : Colors.black,
                    ),
                  ),
                  trailing: Switch(
                    thumbColor:
                    MaterialStateProperty.all<Color>(Colors.white),
                    trackColor: _shouldSaveToSDCardOnly ? (_isDarkModeEnabled
                        ? MaterialStateProperty.all<Color>(
                        Colors.greenAccent)
                        : MaterialStateProperty.all<Color>(
                        Colors.blue)) : MaterialStateProperty.all<Color>(
                        Colors.grey),
                    value: _shouldSaveToSDCardOnly,
                    onChanged: (value) {
                      setState(() {
                        if (value) {
                          _shouldSaveToSDCard = value;
                        }
                        _shouldSaveToSDCardOnly = value;
                      });

                      if (value) {
                        _pressedSDCardSwitch(value);
                      }
                      _pressedSDCardOnlySwitch(value);
                    },
                  ),
                ),
              ),

          Visibility(
            visible: (_localVaultItem != null),
            child: Divider(
              color: _isDarkModeEnabled ? Colors.greenAccent : null,
            ),
          ),
          Visibility(
            visible: (_localVaultItem != null),
            child: getBackupTile(),
          ),
          Visibility(
            visible: _hasExternalVault,
            child: getExternalBackupTile(),
          ),
        ],
      ),),),
      bottomNavigationBar: !_loginScreenFlow
          ? BottomNavigationBar(
              elevation: 2.0,
              backgroundColor:
                  _isDarkModeEnabled ? Colors.black12 : Colors.white,
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
                  backgroundColor:
                      _isDarkModeEnabled ? Colors.black87 : Colors.white,
                  activeIcon: Icon(
                    Icons.star,
                    color: _isDarkModeEnabled
                        ? Colors.greenAccent
                        : Colors.blueAccent,
                  ),
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.category,
                    color: Colors.grey,
                  ),
                  label: 'Categories',
                  backgroundColor:
                      _isDarkModeEnabled ? Colors.black87 : Colors.white,
                  activeIcon: Icon(
                    Icons.category,
                    color: _isDarkModeEnabled
                        ? Colors.greenAccent
                        : Colors.blueAccent,
                  ),
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.discount,
                    color: Colors.grey,
                  ),
                  label: 'Tags',
                  backgroundColor:
                      _isDarkModeEnabled ? Colors.black87 : Colors.white,
                  activeIcon: Icon(
                    Icons.discount,
                    color: _isDarkModeEnabled
                        ? Colors.greenAccent
                        : Colors.blueAccent,
                  ),
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.settings,
                    color: Colors.grey,
                  ),
                  label: 'Settings',
                  backgroundColor:
                      _isDarkModeEnabled ? Colors.black87 : Colors.white,
                  activeIcon: Icon(
                    Icons.settings,
                    color: _isDarkModeEnabled
                        ? Colors.greenAccent
                        : Colors.blueAccent,
                  ),
                ),
              ],
              onTap: _onItemTapped,
            )
          : null,
    );
  }

  _pressedSDCardSwitch(bool value) async {

    settingsManager.saveSaveToSDCard(value);
  }

  _pressedSDCardOnlySwitch(bool value) async {

    settingsManager.saveSaveToSDCardOnly(value);
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    Navigator.of(context)
        .popUntil((route) => route.settings.name == HomeTabScreen.routeName);

    settingsManager.changeRoute(index);
  }


  _scanForRecoveryKey(bool isLocal) async {
    print("_scanForRecoveryKey: $isLocal");
    settingsManager.setIsScanningQRCode(true);

    if (Platform.isIOS) {
      // await _scanQRRecovery(context);
      String barcodeScanRes;
      // Platform messages may fail, so we use a try/catch PlatformException.
      try {
        barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
            "#ff6666", "Cancel", true, ScanMode.QR);

        // print("barcodeScanRes: ${barcodeScanRes}");

        settingsManager.setIsScanningQRCode(false);

        /// user pressed cancel
        if (barcodeScanRes == "-1") {
          return;
        }

        if (isLocal) {
          await _decryptWithScannedRecoveryItem(barcodeScanRes);
        } else {
          await _decryptExternalWithScannedRecoveryItem(barcodeScanRes);
        }

      } on PlatformException {
        barcodeScanRes = "Failed to get platform version.";
        logManager.logger.w("Platform exception");
        settingsManager.setIsScanningQRCode(false);
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context)
            .push(MaterialPageRoute(
          builder: (context) => QRScanView(),
        )).then((value) async {
          print("returned value: $value");
          settingsManager.setIsScanningQRCode(false);

          if (isLocal) {
            await _decryptWithScannedRecoveryItem(value);
          } else {
            await _decryptExternalWithScannedRecoveryItem(value);
          }
        });
      });
    }
  }

  _decryptWithScannedRecoveryItem(String recoveryItem) async {
    EasyLoading.show(status: "Decrypting...");
    print("_decryptWithScannedRecoveryItem");

    try {
      RecoveryKeyCode key = RecoveryKeyCode.fromRawJson(recoveryItem);
      if (key != null && _localVaultRecoveryKeys != null) {
        for (var rkey in _localVaultRecoveryKeys!) {
          if (rkey.id == key.id) {
            SecretKey skey = SecretKey(base64.decode(key.key));
            final decryptedRootKey = await cryptor.decryptRecoveryKey(skey, rkey.data);
            print("decryptedRootKey: ${decryptedRootKey.length}: ${decryptedRootKey}");

            if (!decryptedRootKey.isEmpty) {
              cryptor.setAesRootKeyBytes(decryptedRootKey);
              await cryptor.expandSecretRootKey(decryptedRootKey);

              final status = await backupManager
                  .restoreLocalBackupItemRecovery(_localVaultItem!);
              print("restoreLocalBackupItemRecovery status: ${status}");

              if (status) {
                if (_loginScreenFlow) {
                  settingsManager.setIsRecoveredSession(true);
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                }
              } else {
                _showErrorDialog("could not decrypt vault");
              }
            } else {
              _showErrorDialog("could not decrypt vault");
            }
          }
        }
      } else {
        _showErrorDialog("Invalid code format");
      }
    } catch (e) {
      print("Exception: $e");
      settingsManager.setIsScanningQRCode(false);
    }

    EasyLoading.dismiss();
  }

  _decryptExternalWithScannedRecoveryItem(String recoveryItem) async {
    EasyLoading.show(status: "Decrypting...");

    print("_decryptExternalWithScannedRecoveryItem");

    try {
      RecoveryKeyCode key = RecoveryKeyCode.fromRawJson(recoveryItem);
      if (key != null && _externalVaultRecoveryKeys != null) {
        for (var rkey in _externalVaultRecoveryKeys!) {
          print("rkey: ${rkey.toJson()}");
          if (rkey.id == key.id) {
            SecretKey skey = SecretKey(base64.decode(key.key));
            final decryptedRootKey = await cryptor.decryptRecoveryKey(skey, rkey.data);
            print("decryptedRootKey: ${decryptedRootKey.length}: ${decryptedRootKey}");

            if (!decryptedRootKey.isEmpty) {
              cryptor.setAesRootKeyBytes(decryptedRootKey);
              await cryptor.expandSecretRootKey(decryptedRootKey);

              final status = await backupManager
                  .restoreLocalBackupItemRecovery(_externalVaultItem!);
              print("restoreLocalBackupItemRecovery status: ${status}");

              if (status) {
                if (_loginScreenFlow) {
                  settingsManager.setIsRecoveredSession(true);
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                }
              } else {
                _showErrorDialog("could not decrypt vault");
              }
            } else {
              _showErrorDialog("could not decrypt vault");
            }
          }
        }
      } else {
        _showErrorDialog("Invalid code format");
      }
    } catch (e) {
      print(e);
      settingsManager.setIsScanningQRCode(false);
    }

    EasyLoading.dismiss();
  }


  /// create a backup with a user specified name
  Future<bool> _createBackup() async {

    EasyLoading.show(status: "Creating Backup...");

    var backupName = _dialogTextFieldController.text;

    var cdate = DateTime.now().toIso8601String();
    var mdate = DateTime.now().toIso8601String();

    if (_localVaultItem != null &&
        _localVaultItem?.id == keyManager.vaultId &&
        _hasMatchingLocalVaultKeyData) {
      backupName = (_localVaultItem?.name)!;
      cdate = (_localVaultItem?.cdate)!;
    }
    // print('backupName: $backupName');

    try {
      if (cryptor.aesSecretKeyBytes.isNotEmpty && cryptor.authSecretKeyBytes.isNotEmpty) {
        logManager.log("BackupsScreen", "_createBackup", "create backup");
        logManager.logger.d("BackupsScreen-create backup");

        // var cdate = DateTime.now().toIso8601String();
        // var mdate = DateTime.now().toIso8601String();

        var currentVault = _localVaultItem;
        // if (_backups.length > 0) {
        //   _backups.forEach((element) {
        //     if (element.id == keyManager.vaultId) {
        //       currentVault = element;
        //       // break;
        //     }
        //   });
        // }

        if (currentVault != null) {
          cdate = currentVault.cdate;
        }

        var numRounds = cryptor.rounds;

        /// create EncryptedKey object
        final salt = keyManager.salt;
        final kdfAlgo = EnumToString.convertToString(KDFAlgorithm.pbkdf2_512);
        final rounds =  numRounds;
        final type = 0;
        final version = 1;
        final memoryPowerOf2 = 0;
        final encryptionAlgo =
            EnumToString.convertToString(EncryptionAlgorithm.aes_ctr_256);
        final keyMaterial = keyManager.encryptedKeyMaterial;

        var items = await keyManager.getAllItemsForBackup() as GenericItemList;
        final numItems = items.list.length;

        var testItems = json.encode(items);

        /// TODO: Digital ID
        final myId = await keyManager.getMyDigitalIdentity();

        if (currentVault != null) {
          backupName = currentVault.name;
        }

        final appVersion = settingsManager.versionAndBuildNumber();
        // logManager.logger.d('test4: ${appVersion}');

        final uuid = keyManager.vaultId;

        final idString =
            "${uuid}-${_deviceId}-${appVersion}-${cdate}-${mdate}-${backupName}";
        logManager.logger.d("idString-ext: $idString ");


        // logManager.logger.d('items: ${items.toJson()}');
        // logManager.logger.d('items.toString: ${items.toString().length}: ${items.toString()}');
        // logManager.logger.d('testItems: ${testItems.length}: ${testItems}');

        var encryptedBlob = await cryptor.encryptBackupVault(testItems, idString);
        // logManager.logger.d('encryptedBlob: ${encryptedBlob.length}: $encryptedBlob');

        final identities = await keyManager.getIdentities();
        final recoveryKeys = await keyManager.getRecoveryKeyItems();

        final deviceDataString = settingsManager.deviceManager.deviceData.toString();
        // logManager.logger.d("deviceDataString: $deviceDataString");
        logManager.logLongMessage("deviceDataString: $deviceDataString");
        // logManager.logger.d("deviceData[utsname.version:]: ${settingsManager.deviceManager.deviceData["utsname.version:"]}");

        settingsManager.doEncryption(utf8.encode(deviceDataString).length);
        final encryptedDeviceData = await cryptor.encrypt(deviceDataString);
        // logManager.logger.d("encryptedDeviceData: $encryptedDeviceData");

        /// TODO: implement this outside of this function
        settingsManager.doEncryption(utf8.encode(testItems).length);

        final keyNonce = _convertEncryptedBlocksNonce();
        logManager.logger.d("keyNonce: $keyNonce");

        final encryptedKeyNonce = await cryptor.encrypt(keyNonce);
        logManager.logger.d("encryptedKeyNonce: $encryptedKeyNonce");

        final encryptedKey = EncryptedKey(
          derivationAlgorithm: kdfAlgo,
          salt: salt,
          rounds: rounds,
          type: type,
          version: version,
          memoryPowerOf2: memoryPowerOf2,
          encryptionAlgorithm: encryptionAlgo,
          keyMaterial: keyMaterial,
          keyNonce: encryptedKeyNonce,
        );
        logManager.logger.d('encryptedKey: ${encryptedKey.toJson()}');

        final backupItem = VaultItem(
          id: uuid,
          version: appVersion,
          name: backupName,
          deviceId: _deviceId,
          deviceData: encryptedDeviceData,
          encryptedKey: encryptedKey,
          myIdentity: myId,
          identities: identities,
          recoveryKeys: recoveryKeys,
          numItems: items.list.length,
          blob: encryptedBlob,
          cdate: cdate,
          mdate: mdate,
        );
        // logManager.logger.d('encryptedKey: ${encryptedKey.toJson()}');

        logManager.logLongMessage("backupItemJson-long: ${backupItem.toRawJson().length}: ${backupItem.toRawJson()}");
        // log("backupItemJson: ${backupItem.toRawJson().length}: ${backupItem.toRawJson()}");

        final backupItemString = backupItem.toRawJson();
        // logManager.logger.d('backupItemString: $backupItemString');
        final backupHash = cryptor.sha256(backupItemString);
        // logManager.logger.d("backup hash: $backupHash");

        logManager.log(
            "BackupsScreen", "_createBackup", "backup hash:\n$backupHash\n\nvault id: ${uuid}");

        /// TODO: change to detailed file name
        final normDate = mdate.replaceAll(":", "_");
        final backupFileName = "Blackbox-$backupName-(${numItems} items, ${recoveryKeys?.length} recovery keys)-${normDate}";

        if (Platform.isAndroid && _shouldSaveToSDCard
            || Platform.isAndroid && _shouldSaveToSDCardOnly) {

          await _createExternalBackup(mdate);
          /// write backup to SD card
          // await fileManager.writeVaultDataSDCard(backupFileName, backupItemString);
        }

        if (!_shouldSaveToSDCardOnly) {
          await fileManager.writeNamedVaultData(
              backupFileName, backupItemString);
        }

        EasyLoading.dismiss();

        return true;
      }
      return false;
    } catch (e) {
      logManager.logger.d("Exception: $e");
      return false;
    }
  }

  Future<bool> _createExternalBackup(String modifiedDateString) async {

    var backupName = _dialogTextFieldController.text;

    var cdate = DateTime.now().toIso8601String();
    var mdate = modifiedDateString;//DateTime.now().toIso8601String();

    if (_externalVaultItem != null &&
        _externalVaultItem?.id == keyManager.vaultId &&
        _hasMatchingExternalVaultKeyData) {
      backupName = (_externalVaultItem?.name)!;
      cdate = (_externalVaultItem?.cdate)!;
    }

    try {
      if (cryptor.aesSecretKeyBytes.isNotEmpty && cryptor.authSecretKeyBytes.isNotEmpty) {
        logManager.log("BackupsScreen", "_createBackup", "create backup");
        logManager.logger.d("BackupsScreen-create backup");

        var currentVault = _externalVaultItem;

        if (currentVault != null) {
          cdate = currentVault.cdate;
        }

        var numRounds = cryptor.rounds;

        /// create EncryptedKey object
        final salt = keyManager.salt;
        final kdfAlgo = EnumToString.convertToString(KDFAlgorithm.pbkdf2_512);
        final rounds =  numRounds;
        final type = 0;
        final version = 1;
        final memoryPowerOf2 = 0;
        final encryptionAlgo =
        EnumToString.convertToString(EncryptionAlgorithm.aes_ctr_256);
        final keyMaterial = keyManager.encryptedKeyMaterial;

        var items = await keyManager.getAllItemsForBackup() as GenericItemList;
        final numItems = items.list.length;

        var testItems = json.encode(items);

        /// TODO: Digital ID
        final myId = await keyManager.getMyDigitalIdentity();

        if (currentVault != null) {
          backupName = currentVault.name;
        }

        final appVersion = settingsManager.versionAndBuildNumber();
        // logManager.logger.d('test4: ${appVersion}');

        final uuid = keyManager.vaultId;

        final idString =
            "${uuid}-${_deviceId}-${appVersion}-${cdate}-${mdate}-${backupName}";
        logManager.logger.d("idString: $idString ");


        // logManager.logger.d('items: ${items.toJson()}');
        // logManager.logger.d('items.toString: ${items.toString().length}: ${items.toString()}');
        // logManager.logger.d('testItems: ${testItems.length}: ${testItems}');

        var encryptedBlob = await cryptor.encryptBackupVault(testItems, idString);
        // logManager.logger.d('encryptedBlob: ${encryptedBlob.length}: $encryptedBlob');

        final identities = await keyManager.getIdentities();
        final recoveryKeys = await keyManager.getRecoveryKeyItems();

        final deviceDataString = settingsManager.deviceManager.deviceData.toString();
        // logManager.logger.d("deviceDataString: $deviceDataString");
        logManager.logLongMessage("deviceDataString: $deviceDataString");
        // logManager.logger.d("deviceData[utsname.version:]: ${settingsManager.deviceManager.deviceData["utsname.version:"]}");

        settingsManager.doEncryption(utf8.encode(deviceDataString).length);
        final encryptedDeviceData = await cryptor.encrypt(deviceDataString);
        // logManager.logger.d("encryptedDeviceData: $encryptedDeviceData");

        /// TODO: implement this outside of this function
        settingsManager.doEncryption(utf8.encode(testItems).length);

        final keyNonce = _convertEncryptedBlocksNonce();
        logManager.logger.d("keyNonce: $keyNonce");

        final encryptedKeyNonce = await cryptor.encrypt(keyNonce);
        logManager.logger.d("encryptedKeyNonce: $encryptedKeyNonce");

        final encryptedKey = EncryptedKey(
          derivationAlgorithm: kdfAlgo,
          salt: salt,
          rounds: rounds,
          type: type,
          version: version,
          memoryPowerOf2: memoryPowerOf2,
          encryptionAlgorithm: encryptionAlgo,
          keyMaterial: keyMaterial,
          keyNonce: encryptedKeyNonce,
        );
        logManager.logger.d('encryptedKey: ${encryptedKey.toJson()}');

        final backupItem = VaultItem(
          id: uuid,
          version: appVersion,
          name: backupName,
          deviceId: _deviceId,
          deviceData: encryptedDeviceData,
          encryptedKey: encryptedKey,
          myIdentity: myId,
          identities: identities,
          recoveryKeys: recoveryKeys,
          numItems: items.list.length,
          blob: encryptedBlob,
          cdate: cdate,
          mdate: mdate,
        );
        // logManager.logger.d('encryptedKey: ${encryptedKey.toJson()}');

        logManager.logLongMessage("backupItemJson-long: ${backupItem.toRawJson().length}: ${backupItem.toRawJson()}");
        // log("backupItemJson: ${backupItem.toRawJson().length}: ${backupItem.toRawJson()}");

        final backupItemString = backupItem.toRawJson();
        // logManager.logger.d('backupItemString: $backupItemString');
        final backupHash = cryptor.sha256(backupItemString);
        // logManager.logger.d("backup hash: $backupHash");

        logManager.log(
            "BackupsScreen", "_createBackup", "backup hash:\n$backupHash\n\nvault id: ${uuid}");

        /// TODO: change to detailed file name
        final normDate = mdate.replaceAll(":", "_");
        final backupFileName = "Blackbox-$backupName-(${numItems} items, ${recoveryKeys?.length} recovery keys)-${normDate}";

        /// write backup to SD card
        await fileManager.writeVaultDataSDCard(backupFileName, backupItemString);

        return true;
      }
      return false;
    } catch (e) {
      logManager.logger.d("Exception: $e");
      return false;
    }
  }


  String _convertEncryptedBlocksNonce() {
    final zeroBlock = List<int>.filled(16, 0);

    /// account for what we are about to encrypt
    settingsManager.doEncryption(16);
    
    final numRollover = settingsManager.numRolloverEncryptionCounts;
    final numBlocks = settingsManager.numBlocksEncrypted;
    // final currentNonce = zeroBlock.sublist(0, 8) + cbytes + zeroBlock.sublist(0, 4);
    // final shortNonce = zeroBlock.sublist(0, 8) + cbytes;// + zeroBlock.sublist(0, 4);
    logManager.logger.d("_convertEncryptedBlocksNonce: numBlocks: $numBlocks");

    var aindex = int.parse("${numRollover}").toRadixString(16);
    logManager.logger.d("aindex: $aindex");

    if (aindex.length % 2 == 1) {
      aindex = "0" + aindex;
    }


    logManager.logger.d("aindex: ${aindex.length}: ${aindex}");
    final abytes = hex.decode(aindex);
    logManager.logger.d("abytes: ${abytes.length}: ${abytes}");

    final blockNonceABytes = zeroBlock.sublist(0, 4 - abytes.length) +
        abytes;

    logManager.logger.d("abytes: ${abytes.length}: ${abytes}");

    var bindex = int.parse("${numBlocks}").toRadixString(16);
    logManager.logger.d("bindex: $bindex");

    if (bindex.length % 2 == 1) {
      bindex = "0" + bindex;
    }

    final bbytes = hex.decode(bindex);
    logManager.logger.d("bbytes: $bbytes");

    final blockNonceBBytes = zeroBlock.sublist(0, 4 - bbytes.length) +
        bbytes;
    
    logManager.logger.d("blockNonceBBytes: ${blockNonceBBytes.length}: ${hex.encode(
        blockNonceBBytes)}");
    
    /// form nonce based on message index
    final countingNonce = blockNonceABytes + blockNonceBBytes;
    logManager.logger.d("countingNonce: ${countingNonce.length}: ${hex.encode(
        countingNonce)}");
    
    final currentNonce = zeroBlock.sublist(0, 16-countingNonce.length) + countingNonce;
    logManager.logger.d("currentNonce: ${currentNonce.length}: ${hex.encode(
        currentNonce)}");
    
    
    return hex.encode(currentNonce);
  }


  void _displayBackupInfo(VaultItem item, int encryptedBlocks, String fingerprint) async {
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
                return SingleChildScrollView(child: Column(
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
                    Divider(
                      color: _isDarkModeEnabled ? Colors.greenAccent : null,
                    ),
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          "name: ${item.name}\nvault id: ${item.id.toUpperCase()}\ndeviceId: ${item.deviceId}"
                              "\n\ncreated: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse(item.cdate))}"
                              "\nmodified: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse(item.mdate))}"
                              "\napp version: ${item.version}"
                              // "\nCurrent Vault: ${(item.encryptedKey.keyMaterial == keyManager.encryptedKeyMaterial)}"
                              "\nencryptedBlocks: ${(encryptedBlocks > 0 ? encryptedBlocks: "?")}"
                              "\nkey health: ${(100* (AppConstants.maxEncryptionBlocks-encryptedBlocks)/AppConstants.maxEncryptionBlocks).toStringAsFixed(6)} %"
                              "\n\nfingerprint: ${fingerprint}\n",
                          style: TextStyle(
                            color: _isDarkModeEnabled ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    // Divider(
                    //   color: _isDarkModeEnabled ? Colors.greenAccent : null,
                    // ),
                  ],),
                );
              });
        });
    //     .then((value) {
    //     print("Chose value: $value");
    //
    // });
  }


  _showChangeLocalBackupNameDialog() async {
    _enableBackupNameOkayButton = false;
    return showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              title: Text('Change Backup Name'),
              actions: <Widget>[
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _dialogLocalChangeNameTextFieldController.text = '';
                      _enableBackupNameOkayButton = false;
                    });

                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _enableBackupNameOkayButton
                      ? () async {
                    final status = await _changeLocalBackupName(
                        _dialogLocalChangeNameTextFieldController.text);

                    Navigator.of(context).pop();

                    if (status) {
                      _fetchBackups();
                      EasyLoading.showToast(
                          "Backup Name Change Successful");
                    } else {
                      _showErrorDialog("Failed to update Backup name.");
                    }

                    setState(() {
                      _dialogLocalChangeNameTextFieldController.text = '';
                      _enableBackupNameOkayButton = false;
                    });
                  }
                      : null,
                  child: Text('Save'),
                ),
              ],
              content: TextField(
                decoration: InputDecoration(
                  hintText: "New Backup Name",
                ),
                onChanged: (value) {
                  setState(() {
                    _enableBackupNameOkayButton = value.isNotEmpty;
                  });
                },
                controller: _dialogLocalChangeNameTextFieldController,
                focusNode: _dialogChangeLocalNameFocusNode,
              ),
            );
          });
        });
  }


  _showChangeExternalBackupNameDialog() async {
    _enableBackupNameOkayButton = false;
    return showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              title: Text('Change Backup Name'),
              actions: <Widget>[
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _dialogLocalChangeNameTextFieldController.text = '';
                      _enableBackupNameOkayButton = false;
                    });

                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _enableBackupNameOkayButton
                      ? () async {
                    final status = await _changeExternalBackupName(
                        _dialogLocalChangeNameTextFieldController.text);

                    Navigator.of(context).pop();

                    if (status) {
                      _fetchBackups();
                      EasyLoading.showToast(
                          "Backup Name Change Successful");
                    } else {
                      _showErrorDialog("Failed to update Backup name.");
                    }

                    setState(() {
                      _dialogLocalChangeNameTextFieldController.text = '';
                      _enableBackupNameOkayButton = false;
                    });
                  }
                      : null,
                  child: Text('Save'),
                ),
              ],
              content: TextField(
                decoration: InputDecoration(
                  hintText: "New Backup Name",
                ),
                onChanged: (value) {
                  setState(() {
                    _enableBackupNameOkayButton = value.isNotEmpty;
                  });
                },
                controller: _dialogLocalChangeNameTextFieldController,
                focusNode: _dialogChangeLocalNameFocusNode,
              ),
            );
          });
        });
  }

  /// create a backup with a user specified name
  Future<bool> _changeLocalBackupName(String newName) async {
    if (newName.isEmpty) {
      return false;
    }

    var backupName = newName;
    // print('backupName: $backupName');

    if (keyManager.hasPasswordItems) {
      logManager.log(
          "BackupsScreen", "_changeBackupName", "change backup name: $newName");

      VaultItem? currentVault = _localVaultItem;

      if (currentVault == null) {
        return false;
      }

      final cdate = currentVault!.cdate;
      final mdate = DateTime.now().toIso8601String();

      // final appVersion = settingsManager.packageInfo.version;
      final appVersion = settingsManager.versionAndBuildNumber();

      final uuid = keyManager.vaultId;

      final idStringPrevious =
          "${uuid}-${currentVault!.deviceId}-${currentVault!.version}-${cdate}-${currentVault!.mdate}-${currentVault!.name}";
      final idStringUpdated =
          "${uuid}-${_deviceId}-${appVersion}-${cdate}-${mdate}-${backupName}";

      var tempDecryptedBlob =
          await cryptor.decryptBackupVault(currentVault!.blob, idStringPrevious);
      // print("tempDecryptedBlob: $tempDecryptedBlob");

      if (tempDecryptedBlob == null || tempDecryptedBlob.isEmpty) {
        return false;
      }

      var itemList = GenericItemList.fromRawJson(tempDecryptedBlob);
      final numItems = itemList.list.length;
      if (itemList == null) {
        return false;
      }

      /// TODO: implement this outside of this function
      settingsManager.doEncryption(utf8.encode(tempDecryptedBlob).length);

      final encryptedKey = EncryptedKey(
        derivationAlgorithm: currentVault!.encryptedKey.derivationAlgorithm,
        salt: currentVault!.encryptedKey.salt,
        rounds: currentVault!.encryptedKey.rounds,
        type: currentVault!.encryptedKey.type,
        version: currentVault!.encryptedKey.version,
        memoryPowerOf2: currentVault!.encryptedKey.memoryPowerOf2,
        encryptionAlgorithm: currentVault!.encryptedKey.encryptionAlgorithm,
        keyMaterial: currentVault!.encryptedKey.keyMaterial,
        keyNonce: currentVault!.encryptedKey.keyNonce,
      );

      var encryptedBlobUpdated =
          await cryptor.encryptBackupVault(tempDecryptedBlob, idStringUpdated);
      // print("encryptedBlobUpdated: $encryptedBlobUpdated");


      final deviceDataString = settingsManager.deviceManager.deviceData.toString();
      logManager.logger.d("deviceDataString: $deviceDataString");
      // logManager.logger.d("deviceData[utsname.version:]: ${settingsManager.deviceManager.deviceData["utsname.version:"]}");

      settingsManager.doEncryption(utf8.encode(deviceDataString).length);
      final encryptedDeviceData = await cryptor.encrypt(deviceDataString);
      logManager.logger.d("encryptedDeviceData: $encryptedDeviceData");

      // final backupNameFinal = '$backupName - ${items.list.length} items, v${settingsManager.packageInfo.version}';
      /// TODO: add in updatedBlob, remove blobDigest
      final backupItem = VaultItem(
        id: uuid,
        version: appVersion,
        name: backupName,
        deviceId: _deviceId,
        deviceData: encryptedDeviceData,
        encryptedKey: encryptedKey,
        myIdentity: currentVault!.myIdentity,
        identities: currentVault!.identities,
        recoveryKeys: currentVault!.recoveryKeys,
        numItems: currentVault!.numItems,
        blob: encryptedBlobUpdated,
        cdate: cdate,
        mdate: mdate,
      );

      // print("passwordItems: $passwordItems");
      // print("genericItems: $items");

      // print("backupItem: $backupItem");
      // print("backupItemJson: ${backupItem.toRawJson().length}: ${backupItem.toRawJson()}");

      final backupItemString = backupItem.toRawJson();
      // print('backupItemString: $backupItemString');

      final backupHash =
          Hasher().sha256Hash(backupItemString);

      logManager.log(
          "BackupsScreen", "_changeBackupName", "backup hash: $backupHash");

      /// TODO: named backup files
      final normDate = mdate.replaceAll(":", "_");
      final backupFileName = "Blackbox-$backupName-(${numItems} items, ${currentVault!.recoveryKeys?.length} recovery keys)-${normDate}";

      if (Platform.isAndroid && _shouldSaveToSDCard) {
        /// write backup to SD card
        await fileManager.writeVaultDataSDCard(backupFileName, backupItemString);
      }

      // await fileManager.writeVaultData(backupItemString);
      await fileManager.writeNamedVaultData(backupFileName, backupItemString);

      return true;
    }
    return false;
  }

  Future<bool> _changeExternalBackupName(String newName) async {
    if (newName.isEmpty) {
      return false;
    }

    var backupName = newName;
    // print('backupName: $backupName');

    if (keyManager.hasPasswordItems) {
      logManager.log(
          "BackupsScreen", "_changeBackupName", "change backup name: $newName");

      VaultItem? currentVault = _externalVaultItem;

      if (currentVault == null) {
        return false;
      }

      final cdate = currentVault!.cdate;
      final mdate = DateTime.now().toIso8601String();

      // final appVersion = settingsManager.packageInfo.version;
      final appVersion = settingsManager.versionAndBuildNumber();

      final uuid = keyManager.vaultId;

      final idStringPrevious =
          "${uuid}-${currentVault!.deviceId}-${currentVault!.version}-${cdate}-${currentVault!.mdate}-${currentVault!.name}";
      final idStringUpdated =
          "${uuid}-${_deviceId}-${appVersion}-${cdate}-${mdate}-${backupName}";

      var tempDecryptedBlob =
      await cryptor.decryptBackupVault(currentVault!.blob, idStringPrevious);
      // print("tempDecryptedBlob: $tempDecryptedBlob");

      if (tempDecryptedBlob == null || tempDecryptedBlob.isEmpty) {
        return false;
      }

      var itemList = GenericItemList.fromRawJson(tempDecryptedBlob);
      final numItems = itemList.list.length;
      if (itemList == null) {
        return false;
      }

      /// TODO: figure out how to manage encryption blocks for external vaults
      ///
      settingsManager.doEncryption(utf8.encode(tempDecryptedBlob).length);

      final encryptedKey = EncryptedKey(
        derivationAlgorithm: currentVault!.encryptedKey.derivationAlgorithm,
        salt: currentVault!.encryptedKey.salt,
        rounds: currentVault!.encryptedKey.rounds,
        type: currentVault!.encryptedKey.type,
        version: currentVault!.encryptedKey.version,
        memoryPowerOf2: currentVault!.encryptedKey.memoryPowerOf2,
        encryptionAlgorithm: currentVault!.encryptedKey.encryptionAlgorithm,
        keyMaterial: currentVault!.encryptedKey.keyMaterial,
        keyNonce: currentVault!.encryptedKey.keyNonce,
      );

      var encryptedBlobUpdated =
      await cryptor.encryptBackupVault(tempDecryptedBlob, idStringUpdated);
      // print("encryptedBlobUpdated: $encryptedBlobUpdated");


      final deviceDataString = settingsManager.deviceManager.deviceData.toString();
      logManager.logger.d("deviceDataString: $deviceDataString");
      // logManager.logger.d("deviceData[utsname.version:]: ${settingsManager.deviceManager.deviceData["utsname.version:"]}");

      /// TODO: figure out how to manage encryption blocks for external vaults
      ///
      settingsManager.doEncryption(utf8.encode(deviceDataString).length);
      final encryptedDeviceData = await cryptor.encrypt(deviceDataString);
      logManager.logger.d("encryptedDeviceData: $encryptedDeviceData");

      /// TODO: add in updatedBlob, remove blobDigest
      final backupItem = VaultItem(
        id: uuid,
        version: appVersion,
        name: backupName,
        deviceId: _deviceId,
        deviceData: encryptedDeviceData,
        encryptedKey: encryptedKey,
        myIdentity: currentVault!.myIdentity,
        identities: currentVault!.identities,
        recoveryKeys: currentVault!.recoveryKeys,
        numItems: currentVault!.numItems,
        blob: encryptedBlobUpdated,
        cdate: cdate,
        mdate: mdate,
      );

      // print("backupItemJson: ${backupItem.toRawJson().length}: ${backupItem.toRawJson()}");

      final backupItemString = backupItem.toRawJson();
      // print('backupItemString: $backupItemString');

      final backupHash =
      Hasher().sha256Hash(backupItemString);

      logManager.log(
          "BackupsScreen", "_changeBackupName", "backup hash: $backupHash");

      /// TODO: named backup files
      final normDate = mdate.replaceAll(":", "_");
      final backupFileName = "Blackbox-$backupName-(${numItems} items, ${currentVault!.recoveryKeys?.length} recovery keys)-${normDate}";

      /// write backup to SD card
      await fileManager.writeVaultDataSDCard(backupFileName, backupItemString);

      return true;
    }
    return false;
  }


  Future<bool> _restoreLocalBackup(String salt) async {
    logManager.logger.d("_restoreLocalBackup");

    final password = _dialogRestoreTextFieldController.text;
    if (password.isNotEmpty) {
      // final status = await backupManager.restoreBackupItem(password, id, salt);
      final status = await backupManager.restoreBackupItem(
          _localVaultItem!,
          password,
          salt,
      );


      logManager.logger.d("status: ${status}, code: ${backupManager.responseStatusCode}");
      logManager.log(
          "BackupsScreen", "_restoreLocalBackup", "restore: $status");

      if (backupManager.responseStatusCode == 0) {
        return status;
      } else {
        WidgetUtils.showSnackBar(context, backupManager.backupErrorMessage + ": " + backupManager.responseStatusCode.toString());
        return false;
      }
      if (!status) {
        // _fetchBackups();
      // } else {
      //   WidgetUtils.showSnackBar(context, backupManager.backupErrorMessage);
      }
      WidgetUtils.showSnackBar(context, backupManager.backupErrorMessage + ": " + backupManager.responseStatusCode.toString());

      return status;
    } else {
      return false;
    }
  }

  Future<bool> _restoreExternalBackup(String salt) async {
    logManager.logger.d("_restoreExternalBackup");

    final password = _dialogRestoreTextFieldController.text;
    if (password.isNotEmpty) {
      // final status = await backupManager.restoreBackupItem(password, id, salt);
      final status = await backupManager.restoreBackupItem(
        _externalVaultItem!,
        password,
        salt,
      );


      logManager.logger.d("status: ${status}, code: ${backupManager.responseStatusCode}");
      logManager.log(
          "BackupsScreen", "_restoreExternalBackup", "restore: $status");

      if (backupManager.responseStatusCode == 0) {
        return status;
      } else {
        WidgetUtils.showSnackBar(context, backupManager.backupErrorMessage + ": " + backupManager.responseStatusCode.toString());
        return false;
      }
      if (!status) {
        // _fetchBackups();
        // } else {
        //   WidgetUtils.showSnackBar(context, backupManager.backupErrorMessage);
      }
      WidgetUtils.showSnackBar(context, backupManager.backupErrorMessage + ": " + backupManager.responseStatusCode.toString());

      return status;
    } else {
      return false;
    }
  }


  _displayCreateBackupDialog(BuildContext context, bool isLocal) async {
    return showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              title: Text('Create Backup'),
              actions: <Widget>[
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _dialogTextFieldController.text = '';
                      _enableBackupNameOkayButton = false;
                    });

                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _enableBackupNameOkayButton
                      ? () async {
                          await _createBackup().then((value) {
                            _fetchBackups();

                            setState(() {
                              _dialogTextFieldController.text = '';
                              _enableBackupNameOkayButton = false;
                            });

                            Navigator.of(context).pop();
                          });
                        }
                      : null,
                  child: Text('Save'),
                ),
              ],
              content: TextField(
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _enableBackupNameOkayButton = true;
                    });
                  } else {
                    setState(() {
                      _enableBackupNameOkayButton = false;
                    });
                  }
                },
                controller: _dialogTextFieldController,
                focusNode: _dialogTextFieldFocusNode,
                decoration: InputDecoration(hintText: "Backup Name"),
              ),
            );
          });
        });
  }

  _displayRestoreLocalBackupDialog(
      BuildContext context, String id, String name, String salt) async {
    return showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              title: Text('Restore Backup\n\n$name'),
              icon: Icon(
                Icons.restore_page_outlined,
                color: Colors.blueAccent,
              ),
              // backgroundColor: Colors.white,
              actions: <Widget>[
                OutlinedButton(
                  onPressed: _enableRestoreBackupCancelButton ? () {
                    _dialogRestoreTextFieldController.text = '';
                    setState(() {
                      _enableRestoreBackupOkayButton = false;
                    });

                    Navigator.of(context).pop();
                  } : null,
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _enableRestoreBackupOkayButton
                      ? () async {

                        setState((){
                          _enableRestoreBackupOkayButton = false;
                          _enableRestoreBackupCancelButton = false;
                        });

                        Timer(const Duration(milliseconds: 200), () async {
                          final status = await _restoreLocalBackup(salt);
                          // EasyLoading.dismiss();

                          if (status) {
                            EasyLoading.showToast(
                                'Backup Restored Successfully',
                                duration: Duration(seconds: 3));
                            if (_loginScreenFlow) {
                              // print("login screen flow");
                              Navigator.of(context).pop();
                            }

                            if (!_loginScreenFlow) {
                              _fetchBackups();
                            }

                            setState(() {
                              _dialogRestoreTextFieldController.text = '';
                              _enableRestoreBackupOkayButton = false;
                              _enableRestoreBackupCancelButton = true;
                            });

                            Navigator.of(context).pop();
                          } else {
                            setState((){
                              _enableRestoreBackupOkayButton = true;
                              _enableRestoreBackupCancelButton = true;
                            });
                            _showErrorDialog('Invalid password');
                          }

                        });

                        } : null,
                  child: Text('Restore'),
                ),
              ],
              content: TextField(
                obscureText: _shouldHideRecoveryPasswordField,
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _enableRestoreBackupOkayButton = true;
                    });
                  } else {
                    setState(() {
                      _enableRestoreBackupOkayButton = false;
                    });
                  }
                },
                controller: _dialogRestoreTextFieldController,
                focusNode: _dialogRestoreTextFieldFocusNode,
                decoration: InputDecoration(
                  hintText: "Password",
                  suffix: IconButton(
                    icon: Icon(
                      Icons.remove_red_eye,
                      color: _shouldHideRecoveryPasswordField
                          ? Colors.black
                          : Colors.blueAccent,
                    ),
                    onPressed: () {
                      setState(() {
                        _shouldHideRecoveryPasswordField =
                            !_shouldHideRecoveryPasswordField;
                      });
                    },
                  ),
                ),
              ),
            );
          });
        });
  }

  _displayRestoreExternalBackupDialog(
      BuildContext context, String id, String name, String salt) async {
    return showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              title: Text('Restore Backup\n\n$name'),
              icon: Icon(
                Icons.restore_page_outlined,
                color: Colors.blueAccent,
              ),
              // backgroundColor: Colors.white,
              actions: <Widget>[
                OutlinedButton(
                  onPressed: _enableRestoreBackupCancelButton ? () {
                    _dialogRestoreTextFieldController.text = '';
                    setState(() {
                      _enableRestoreBackupOkayButton = false;
                    });

                    Navigator.of(context).pop();
                  } : null,
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _enableRestoreBackupOkayButton
                      ? () async {

                    setState((){
                      _enableRestoreBackupOkayButton = false;
                      _enableRestoreBackupCancelButton = false;
                    });

                    Timer(const Duration(milliseconds: 200), () async {
                      final status = await _restoreExternalBackup(salt);
                      // EasyLoading.dismiss();

                      if (status) {
                        EasyLoading.showToast(
                            'Backup Restored Successfully',
                            duration: Duration(seconds: 3));
                        if (_loginScreenFlow) {
                          // print("login screen flow");
                          Navigator.of(context).pop();
                        }

                        if (!_loginScreenFlow) {
                          _fetchBackups();
                        }

                        setState(() {
                          _dialogRestoreTextFieldController.text = '';
                          _enableRestoreBackupOkayButton = false;
                          _enableRestoreBackupCancelButton = true;
                        });

                        Navigator.of(context).pop();
                      } else {
                        setState((){
                          _enableRestoreBackupOkayButton = true;
                          _enableRestoreBackupCancelButton = true;
                        });
                        _showErrorDialog('Invalid password');
                      }

                    });

                  } : null,
                  child: Text('Restore'),
                ),
              ],
              content: TextField(
                obscureText: _shouldHideRecoveryPasswordField,
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _enableRestoreBackupOkayButton = true;
                    });
                  } else {
                    setState(() {
                      _enableRestoreBackupOkayButton = false;
                    });
                  }
                },
                controller: _dialogRestoreTextFieldController,
                focusNode: _dialogRestoreTextFieldFocusNode,
                decoration: InputDecoration(
                  hintText: "Password",
                  suffix: IconButton(
                    icon: Icon(
                      Icons.remove_red_eye,
                      color: _shouldHideRecoveryPasswordField
                          ? Colors.black
                          : Colors.blueAccent,
                    ),
                    onPressed: () {
                      setState(() {
                        _shouldHideRecoveryPasswordField =
                        !_shouldHideRecoveryPasswordField;
                      });
                    },
                  ),
                ),
              ),
            );
          });
        });
  }

  void _showDeleteLocalBackupItemDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Backup'),
        content:
            Text('Are you sure you want to delete this backup?'),
        actions: <Widget>[
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel'),
          ),
          OutlinedButton(
            style: ButtonStyle(
              foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
              backgroundColor: MaterialStateProperty.all<Color>(Colors.red),
            ),
            // style: TextButton.styleFrom(
            //   primary: Colors.redAccent,
            // ),
            onPressed: () async {
              _confirmDeleteLocalBackup();
              Navigator.of(ctx).pop();
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteExternalBackupItemDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete SD Card Backup'),
        // backgroundColor: Colors.black,
        content:
        Text('Are you sure you want to delete this SD card backup?'),
        actions: <Widget>[
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel'),
          ),
          OutlinedButton(
            style: ButtonStyle(
              foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
              backgroundColor: MaterialStateProperty.all<Color>(Colors.red),
            ),
            onPressed: () async {
              _confirmDeleteExternalBackup();
              Navigator.of(ctx).pop();
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteLocalBackup() async {

    await fileManager.clearNamedVaultFile();

    _fetchBackups();
  }

  void _confirmDeleteExternalBackup() async {

    await fileManager.clearVaultFileSDCard();

    _fetchBackups();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Error'),
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
