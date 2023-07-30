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
import "package:bip39/bip39.dart" as bip39;
import '../helpers/AppConstants.dart';
import '../helpers/WidgetUtils.dart';
import '../helpers/bip39_dictionary.dart';
import '../managers/FileManager.dart';
import '../models/NoteItem.dart';
import '../models/PasswordItem.dart';
import '../models/KeyItem.dart';
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
  final _dialogChangeNameTextFieldController = TextEditingController();
  final _dialogLocalChangeNameTextFieldController = TextEditingController();
  final _saltTextFieldController = TextEditingController();

  FocusNode _dialogTextFieldFocusNode = FocusNode();
  FocusNode _dialogRestoreTextFieldFocusNode = FocusNode();
  FocusNode _dialogChangeNameFocusNode = FocusNode();
  FocusNode _dialogChangeLocalNameFocusNode = FocusNode();
  FocusNode _saltTextFieldFocusNode = FocusNode();

  List<VaultItem> _backups = [];
  List<bool> _matchingKeyList = [];
  List<bool> _matchingDeviceList = [];

  GenericItemList? _localGenericItemList = null;


  VaultItem? _localVaultItem;
  int _localVaultItemSize = 0;
  String _matchingLocalVaultId = "";
  bool _hasMatchingLocalVaultId = false;

  bool _hasMatchingLocalVaultKeyData = false;
  bool _localVaultHasRecoveryKeys = false;
  bool _shouldSaveToSDCard = false;

  // bool _localVaultHasSalt = false;
  int _localVaultNumEncryptedBlocks = 0;


  bool _vaultHasMerkleChanges = false;


  List<RecoveryKey>? _localVaultRecoveryKeys = [];

  String _localVaultHash = "";

  bool _shouldHideRecoveryPasswordField = true;

  // bool _hasBackups = false;
  bool _hasMatchingVault = false;
  bool _isInitState = true;
  bool _saltTextFieldValid = false;

  List<int> _backupFileSizes = [];
  List<String> _secretSalts = [];
  List<String> _filteredWordList = WORDLIST;
  List<String> _userEnteredWordList = [];
  int _wordNumber = 1;
  int _userSelectedWordIndex = 0;

  String _deviceId = '';

  int _selectedIndex = 3;

  bool _enableBackupNameOkayButton = false;
  bool _enableRestoreBackupOkayButton = false;

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
    // _localGenericItemList
    var finalGenericItemList = GenericItemList(list: []);
    var localGenericItemList = await keyManager.getAllItemsForBackup() as GenericItemList;
    var list = localGenericItemList.list;
    if (list == null) {
      return finalGenericItemList;
    }
    list.sort((a, b) {
      return b.data.compareTo(a.data);
    });

    // tempGenList.list = list;
    final itree = await localGenericItemList.calculateMerkleTree();
    finalGenericItemList = GenericItemList(list: list);

    // _localGenericItemList.list =
    // /// TODO: merkle root
    // _localGenericItemList.calculateMerkleRoot();

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
    _secretSalts = [];
    _localVaultItem = null;

    keyManager.getAllBackupItems().then((value) async {
      // print("getAllBackupItems: $value");

      /// get the vault from documents directory and find the matching backup
      var vaultFileString = "";
      if (Platform.isAndroid) {
        /// see if we have a vault backup from SD card
        vaultFileString = await fileManager.readVaultDataSDCard();
        if (vaultFileString.isEmpty) {
          /// if no SD card vault, get default file vault location
          vaultFileString = await fileManager.readVaultData();
        }
      } else {
        vaultFileString = await fileManager.readVaultData();
      }
      // final vaultFileString = await fileManager.readVaultData();
      // print("read vault file: ${vaultFileString}");

      _localVaultHash = cryptor.sha256(vaultFileString);
      _localVaultRecoveryKeys = [];
      if (vaultFileString.isNotEmpty) {
        try {
          _localVaultItem = VaultItem.fromRawJson(vaultFileString);
          if (_localVaultItem != null) {
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
                var genericItems2 = GenericItemList.fromRawJson(decryptedBlob);
                // logManager.logger.d("decryption genericItems2: $genericItems2");

                if (genericItems2 != null) {
                  setState(() {
                    _vaultHasMerkleChanges = false;
                  });
                }
              } catch (e) {
                logManager.logger.e("can not decrypt current backup vault\n"
                    "vaultid: $vaultId: $e");

                if (mounted) {
                  setState(() {
                    _hasMatchingLocalVaultId = keyManager.vaultId == vaultId;
                  });
                }
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
              logManager.logger.d("encryptedKeyNonce: ${encryptedKeyNonce}");

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
                logManager.logger.d(
                    "encryptedBlockCount: ${encryptedBlockCount}\n"
                        "rolloverBlockCount: ${rolloverBlockCount}");

                setState(() {
                  _localVaultNumEncryptedBlocks = encryptedBlockCount;
                });
              });

              _matchingLocalVaultId = (_localVaultItem?.id)!;

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

      // print("_matchingLocalVaultId: $_matchingLocalVaultId");
      /// TODO: decode object vaultFileString and check against which backup item
      ///

      _backups = [];

      if (Platform.isAndroid) {
        final androidBackup = settingsManager.androidBackup;
        if (androidBackup != null) {
          // _hasBackups = true;
          _backups = [androidBackup];
        }
      }

      setState(() {
        for (var backup in value) {
          _backups.add(backup);
        }

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
          // print("_backup: ${element.name}: ${element.toRawJson().length}");
          _backupFileSizes.add(element.toRawJson().length);
          if (element.id == keyManager.vaultId) {
            _hasMatchingVault = true;
          }
          // element.encryptedKey.salt.isEmpty
          final salt = await keyManager.getSecretSaltById(element.id);
          _secretSalts.add(salt);
          // print("secretSalts: ${_secretSalts}");
        });

        // if (_backups.length > 0) {
        //   _hasBackups = true;
        // }

        // print("secretSalts: ${_secretSalts}");
        _computeBackupList();
      });
    });
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

    _hasMatchingVault = false;

    _backups.forEach((element) {
      final encryptedKey = element.encryptedKey;
      final keyMaterial = encryptedKey.keyMaterial;
      final deviceId = element.deviceId;
      // print('encryptedKeyMaterial: $keyMaterial');

      if (element.id == keyManager.vaultId) {
        setState(() {
          _hasMatchingVault = true;
        });
      }

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


  Widget getOldBackupUI() {
    var fsize = (_localVaultItemSize / 1024);
    var funit = "KB";
    if (_localVaultItemSize > pow(1024, 2)) {
      funit = "MB";
      fsize = (_localVaultItemSize / pow(1024, 2));
    }

    return Visibility(
      visible: (_localVaultItem != null),
      child: ListTile(
        title: Text(
          _localVaultItem?.name != null ? (_localVaultItem?.name)! : "",
          style: TextStyle(
            color: _isDarkModeEnabled ? Colors.white : null,
          ),
        ),
        subtitle: Text(
          _localVaultItem?.id != null
              ? "${(_localVaultItem?.numItems)!} items\nvault id: ${(_localVaultItem?.id)!}\nmodified: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse((_localVaultItem?.mdate)!))}\nsize: ${fsize.toStringAsFixed(2)} $funit\nrecovery: ${_localVaultHasRecoveryKeys}\n"
              "encryptedBlocks: ${(_localVaultNumEncryptedBlocks > 0 ? _localVaultNumEncryptedBlocks: "?")}\nhealth %: ${(100* (AppConstants.maxEncryptionBlocks-_localVaultNumEncryptedBlocks)/AppConstants.maxEncryptionBlocks).toStringAsFixed(6)}\n\n"
              "hash: ${_localVaultHash.substring(0, 16)}\nchanged: ${_vaultHasMerkleChanges}" // \n\nsalt: ${base64.encode(cryptor.salt ?? [])}\nlocalVaultSalt: ${(_localVaultItem?.encryptedKey.salt)!}
              : "",
          // "${(_localVaultItem?.id)!}\nsize: ${(_localVaultItemSize/1024).toStringAsFixed(2)} KB",
          style: TextStyle(
            color: _isDarkModeEnabled ? Colors.white : null,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.edit,
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
              ),
              onPressed: () {
                _showChangeLocalBackupNameDialog();
              },
            ),
            IconButton(
              icon: Icon(
                Icons.restore_page_outlined,
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
              ),
              onPressed: () async {
                /// device remembers and stores local salts, unless on new device
                // final salt = await keyManager
                //     .getSecretSaltById((_localVaultItem?.id)!);
                //
                // if (salt.isNotEmpty) {
                  _displayRestoreLocalBackupDialog(
                    context,
                    (_localVaultItem?.id)!,
                    (_localVaultItem?.name)!,
                    (_localVaultItem?.encryptedKey.salt)!,
                  );
                // } else {
                //   /// check if local file has a salt value
                //   final ss = _localVaultItem?.encryptedKey?.salt != null;
                //   if (ss) {
                //     final salt = (_localVaultItem?.encryptedKey?.salt)!;
                //
                //     if (salt.isNotEmpty) {
                //       _displayRestoreLocalBackupDialog(
                //         context,
                //         (_localVaultItem?.id)!,
                //         (_localVaultItem?.name)!,
                //         salt,
                //       );
                //     } else {
                //       /// use must import salt value
                //       _showSecretKeyImportOptionsDialog(
                //           (_localVaultItem?.id)!,
                //           (_localVaultItem?.name)!,
                //           true);
                //     }
                //   } else {
                //     /// use must import salt value
                //     _showSecretKeyImportOptionsDialog(
                //         (_localVaultItem?.id)!,
                //         (_localVaultItem?.name)!,
                //         true);
                //   }
                // }
              },
            ),
            Visibility(
              visible: _loginScreenFlow && _localVaultHasRecoveryKeys,
              child: IconButton(
                icon: Icon(
                  Icons.qr_code,
                  color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
                ),
                onPressed: () {
                  _scanForRecoveryKey();
                },
              ),
            ),
            Visibility(
              visible: !_loginScreenFlow,
              child: IconButton(
                icon: Icon(
                  Icons.delete,
                  color: _isDarkModeEnabled ? Colors.redAccent : Colors.red,
                ),
                onPressed: () {
                  _showDeleteLocalBackupItemDialog();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget getNewBackupTile() {
    var fsize = (_localVaultItemSize / 1024);
    // var fblocksize = _localVaultItemSize/16;
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
            _localVaultItem?.name != null ? "name: ${(_localVaultItem?.name)!}" : "",
            style: TextStyle(
              color: _isDarkModeEnabled ? Colors.white : null,
              ),
            ),
              subtitle: Text(
                _localVaultItem?.id != null
                    ? "vault id: ${(_localVaultItem?.id)!.toUpperCase()}" : "",
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
                  ? "${(_localVaultItem?.numItems)!} items\nmodified: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse((_localVaultItem?.mdate)!))}"
                  "\nencryptedBlocks: ${(_localVaultNumEncryptedBlocks > 0 ? _localVaultNumEncryptedBlocks: "?")}\nkey health: ${(100* (AppConstants.maxEncryptionBlocks-_localVaultNumEncryptedBlocks)/AppConstants.maxEncryptionBlocks).toStringAsFixed(6)} %\n\n"
                  "fingerprint: ${_localVaultHash.substring(0, 32)}\nchanged: ${_vaultHasMerkleChanges}" // \n\nsalt: ${base64.encode(cryptor.salt ?? [])}\nlocalVaultSalt: ${(_localVaultItem?.encryptedKey.salt)!}
                  : "",
              style: TextStyle(
                color: _isDarkModeEnabled ? Colors.white : null,
                fontSize: 15,
              ),
            ),
          ),
        ),
          // SizedBox(
          //   height: 16,
          // ),
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
              final salt = await keyManager
                  .getSecretSaltById((_localVaultItem?.id)!);

              if (salt.isNotEmpty) {
                _displayRestoreLocalBackupDialog(
                  context,
                  (_localVaultItem?.id)!,
                  (_localVaultItem?.name)!,
                  (_localVaultItem?.encryptedKey.salt)!,
                );
              } else {
                /// check if local file has a salt value
                final ss = _localVaultItem?.encryptedKey?.salt != null;
                if (ss) {
                  final salt = (_localVaultItem?.encryptedKey?.salt)!;

                  if (salt.isNotEmpty) {
                    _displayRestoreLocalBackupDialog(
                      context,
                      (_localVaultItem?.id)!,
                      (_localVaultItem?.name)!,
                      salt,
                    );
                  } else {
                    /// use must import salt value
                    _showSecretKeyImportOptionsDialog(
                        (_localVaultItem?.id)!,
                        (_localVaultItem?.name)!,
                        true);
                  }
                } else {
                  /// use must import salt value
                  _showSecretKeyImportOptionsDialog(
                      (_localVaultItem?.id)!,
                      (_localVaultItem?.name)!,
                      true);
                }
              }
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
                Icons.qr_code,
                color: _isDarkModeEnabled ? Colors.greenAccent : Colors.blueAccent,
              ),
              onPressed: () {
                _scanForRecoveryKey();
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
                  _displayBackupInfo(_localVaultItem!);
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
                print("edit");
                _showChangeLocalBackupNameDialog();
              },
            ),
          ),),


          Visibility(
            visible: !_loginScreenFlow,
            child:Spacer(),
          ),
          Visibility(
            visible: !_loginScreenFlow,
            child:Padding(
              padding: EdgeInsets.all(8),
              child:IconButton(
                icon: Icon(
                  Icons.delete,
                  color: Colors.redAccent, //_isDarkModeEnabled ? Colors.redAccent : Colors.blueAccent,
                ),
                onPressed: () {
                  print("delete");
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

                            final status = await _createBackup(true);

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
                  _shouldSaveToSDCard = value;
                });

                _pressedSDCardSwitch(value);
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
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Text(
                "Local Backup",
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : null,
                ),
              ),
            ),
          ),
          Visibility(
            visible: (_localVaultItem != null),
            child: getNewBackupTile(),
          ),
          Visibility(
            visible: false,
            child: getOldBackupUI(),
          ),

          Visibility(
            visible: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Text(
                "Cloud Backups",
                style: TextStyle(
                  color: _isDarkModeEnabled ? Colors.white : null,
                ),
              ),
            ),
          ),
          Visibility(
            visible: false,
            child: Expanded(
              child: ListView.separated(
                separatorBuilder: (context, index) => Divider(
                  color: _isDarkModeEnabled ? Colors.greenAccent : null,
                ),
                itemCount: _backups.length,
                itemBuilder: (context, index) {
                  var fsize = (_backupFileSizes[index] / 1024);
                  var funit = "KB";
                  if (fsize > 1024) {
                    funit = "MB";
                    fsize = (fsize / 1024);
                  }
                  var dateLine =
                      '${DateFormat('MMM d y  hh:mm a').format(DateTime.parse(_backups[index].mdate))}\n${_matchingKeyList[index] ? '🔐 ' : ''}${_matchingDeviceList[index] ? "📲 " : ''}${fsize.toStringAsFixed(2)} $funit';

                  if (_backups[index].id == _matchingLocalVaultId) {
                    dateLine = dateLine + " - Local Vault";
                  }

                  return Container(
                    height: 120,
                    child: ListTile(
                      isThreeLine: true,
                      enabled: true,
                      title: Text(
                        "${_backups[index].name}\n${_backups[index].numItems} items",
                        style: TextStyle(
                          fontSize: 16,
                          color: _isDarkModeEnabled ? Colors.white : null,
                        ),
                      ),
                      subtitle: Padding(
                        padding: EdgeInsets.fromLTRB(0, 8, 0, 0),
                        child: Text(
                          dateLine,
                          style: TextStyle(
                            fontSize: 14,
                            color: _isDarkModeEnabled ? Colors.white : null,
                          ),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (_backups[index].id == keyManager.vaultId &&
                              _matchingKeyList[index] &&
                              keyManager.hasPasswordItems)
                            IconButton(
                              icon: Icon(Icons.edit),
                              color: _isDarkModeEnabled
                                  ? Colors.greenAccent
                                  : Colors.blueAccent,
                              onPressed: () async {
                                _showChangeBackupNameDialog();
                              },
                            ),
                          IconButton(
                            icon: Icon(Icons.info),
                            color: _isDarkModeEnabled
                                ? Colors.greenAccent
                                : Colors.blueAccent,
                            onPressed: () async {
                              _displayBackupInfo(_backups[index]);
                            },
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                icon: Icon(Icons.restore_page_outlined),
                                color: _isDarkModeEnabled
                                    ? Colors.greenAccent
                                    : Colors.blueAccent,
                                onPressed: () async {
                                  final ss =
                                      _backups[index].encryptedKey.salt !=
                                          null;

                                  /// if we have a salt value on data
                                  if (ss) {
                                    final salt =
                                        _backups[index].encryptedKey.salt;

                                    // if (salt.isNotEmpty) {
                                      _displayRestoreBackupDialog(
                                        context,
                                        _backups[index].id,
                                        _backups[index].name,
                                        salt!,
                                      );
                                  } else {
                                    /// check if we have salt stored locally
                                    if (_secretSalts[index].isEmpty) {
                                      /// user needs to input salt
                                      _showSecretKeyImportOptionsDialog(
                                          _backups[index].id,
                                          _backups[index].name,
                                          false);
                                    } else {
                                      _displayRestoreBackupDialog(
                                        context,
                                        _backups[index].id,
                                        _backups[index].name,
                                        _secretSalts[index],
                                      );
                                    }
                                  }
                                },
                              ),
                              if (keyManager.hasPasswordItems)
                                IconButton(
                                  icon: Icon(Icons.delete),
                                  color: Colors.redAccent,
                                  onPressed: () async {
                                    _showDeleteBackupItemDialog(
                                        _backups[index].id,
                                        _backups[index].name);
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    Navigator.of(context)
        .popUntil((route) => route.settings.name == HomeTabScreen.routeName);

    settingsManager.changeRoute(index);
  }

  void _showSecretKeyImportOptionsDialog(
      String vaultId, String backupName, bool isLocal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Import Secret Key'),
        content: Text(
            'You must import the secret key related to this vault.\n\nChoose as option below.'),
        actions: <Widget>[
          OutlinedButton(
            style: TextButton.styleFrom(
              primary: Colors.blueAccent,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();

              _scanSecretKey(context, vaultId, backupName, isLocal);
            },
            child: Text('Scan Secret Key'),
          ),
          OutlinedButton(
            style: TextButton.styleFrom(
              primary: Colors.blueAccent,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();

              _showEnterSecretSaltModal(vaultId, backupName, isLocal);
            },
            child: Text('Input Secret Key'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _scanSecretKey(BuildContext context, String vaultId, String backupName,
      bool isLocal) async {
    /// TODO: fix the Android bug that does not let the camera operate
    settingsManager.setIsScanningQRCode(true);

    if (Platform.isIOS) {
      await _scanQR(context, vaultId, backupName, isLocal);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context)
            .push(MaterialPageRoute(
          builder: (context) => QRScanView(),
        ))
            .then((value) {
          settingsManager.setIsScanningQRCode(false);

          try {
            if (value != null) {
              final base64Salt = value;
              final decodedSalt = base64.decode(base64Salt);
              if (decodedSalt.length == 16) {
                if (isLocal) {
                  _displayRestoreLocalBackupDialog(
                      context, vaultId, backupName, base64Salt);
                } else {
                  _displayRestoreBackupDialog(
                      context, vaultId, backupName, base64Salt);
                }
              } else {
                _showErrorDialog("Invalid code format");
              }
            } else {
              _showErrorDialog("Invalid code format");
            }
          } catch (e) {
            // print("Error: $e");
            _showErrorDialog("Invalid code format");
          }
        });
      });
    }
  }

  _scanForRecoveryKey() async {
    settingsManager.setIsScanningQRCode(true);

    if (Platform.isIOS) {
      await _scanQRRecovery(context);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context)
            .push(MaterialPageRoute(
          builder: (context) => QRScanView(),
        ))
            .then((value) {
          settingsManager.setIsScanningQRCode(false);

          try {
            if (value != null) {
              // final base64Salt = value;
              // final decodedSalt = base64.decode(base64Salt);
              // if (decodedSalt.length == 16) {
              //   if (isLocal) {
              //     _displayRestoreLocalBackupDialog(context, vaultId, backupName, base64Salt);
              //   } else {
              //     _displayRestoreBackupDialog(context, vaultId, backupName, base64Salt);
              //   }
              // } else {
              //   _showErrorDialog("Invalid code format");
              // }
            } else {
              _showErrorDialog("Invalid code format");
            }
          } catch (e) {
            // print("Error: $e");
            _showErrorDialog("Invalid code format");
          }
        });
      });
    }
  }

  Future<void> _scanQR(BuildContext context, String vaultId, String backupName,
      bool isLocal) async {
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
        // QRCodeItem item = QRCodeItem.fromRawJson(barcodeScanRes);
        if (barcodeScanRes != null) {
          final base64Salt = barcodeScanRes;
          final decodedSalt = base64.decode(base64Salt);
          if (decodedSalt.length == 16) {
            // print("code is correct");
            // final phrase = bip39.entropyToMnemonic(hex.encode(decodedSalt));
            // final entropyBytes = hex.decode(entropy);
            // final saltB64 = base64.encode(entropyBytes);
            ///convert to bytes and bse64 encode it
            /// Enter backup password now
            ///
            if (isLocal) {
              _displayRestoreLocalBackupDialog(
                  context, vaultId, backupName, base64Salt);
            } else {
              _displayRestoreBackupDialog(
                  context, vaultId, backupName, base64Salt);
            }
          }
        } else {
          _showErrorDialog("Invalid code format");
        }
      } catch (e) {
        print(e);
        settingsManager.setIsScanningQRCode(false);
      }
    } on PlatformException {
      barcodeScanRes = "Failed to get platform version.";
      logManager.logger.w("Platform exception");
      settingsManager.setIsScanningQRCode(false);
    }
  }

  Future<void> _scanQRRecovery(BuildContext context) async {
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

      try {
        RecoveryKeyCode key = RecoveryKeyCode.fromRawJson(barcodeScanRes);
        if (key != null && _localVaultRecoveryKeys != null) {
          for (var rkey in _localVaultRecoveryKeys!) {
            if (rkey.id == key.id) {
              SecretKey skey = SecretKey(base64.decode(key.key));
              final decryptedRootKey = await cryptor.decryptRecoveryKey(skey, rkey.data);
              // print("decryptedRootKey: ${decryptedRootKey.length}: ${decryptedRootKey}");

              if (!decryptedRootKey.isEmpty) {
                cryptor.setAesRootKeyBytes(decryptedRootKey);
                await cryptor.expandSecretRootKey(decryptedRootKey);

                final status = await backupManager
                    .restoreLocalBackupItemRecovery(_localVaultItem!);
                // print("restoreLocalBackupItemRecovery status: ${status}");

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
          // key.id
          // final base64Salt = barcodeScanRes;
          // final decodedSalt = base64.decode(base64Salt);

        } else {
          _showErrorDialog("Invalid code format");
        }
      } catch (e) {
        print(e);
        settingsManager.setIsScanningQRCode(false);
      }
    } on PlatformException {
      barcodeScanRes = "Failed to get platform version.";
      logManager.logger.w("Platform exception");
      settingsManager.setIsScanningQRCode(false);
    }
  }

  void _showEnterSecretSaltModal(
      String vaultId, String backupName, bool isLocal) async {
    _wordNumber = 1;
    _userSelectedWordIndex = 0;
    showModalBottomSheet(
        backgroundColor: _isDarkModeEnabled ? Colors.black : null,
        context: context,
        isScrollControlled: true,
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
                  padding: EdgeInsets.all(32),
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
                          _userEnteredWordList = [];
                          _wordNumber = 1;
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
                      // Visibility(
                      //   visible: _userEnteredWordList.length > 0 && _userSelectedWordIndex > 0,
                      //   child:
                      // OutlinedButton(
                      //   style: OutlinedButton.styleFrom(
                      //     side: _isDarkModeEnabled
                      //         ? BorderSide(color: Colors.greenAccent)
                      //         : BorderSide(color: Colors.blueAccent),
                      //   ),
                      //   onPressed: () {
                      //     state((){
                      //       // _userEnteredWordList = [];
                      //       _wordNumber -= 1;
                      //       _userSelectedWordIndex -= 1;
                      //       _saltTextFieldController.text = _userEnteredWordList[_userSelectedWordIndex];
                      //     });
                      //
                      //     // Navigator.of(context).pop();
                      //   },
                      //   child: Text(
                      //     "< Back",
                      //     style: TextStyle(
                      //       color: _isDarkModeEnabled
                      //           ? Colors.greenAccent
                      //           : Colors.blueAccent,
                      //     ),
                      //   ),
                      // ),),
                      // Visibility(
                      //   visible: _userEnteredWordList.length > 0 && _userSelectedWordIndex < _userEnteredWordList.length && _userEnteredWordList.length < 12,
                      //   child:
                      //   OutlinedButton(
                      //     style: OutlinedButton.styleFrom(
                      //       side: _isDarkModeEnabled
                      //           ? BorderSide(color: Colors.greenAccent)
                      //           : BorderSide(color: Colors.blueAccent),
                      //     ),
                      //     onPressed: () {
                      //       state((){
                      //         // _userEnteredWordList = [];
                      //         _wordNumber += 1;
                      //         _userSelectedWordIndex += 1;
                      //         if (_userSelectedWordIndex >= _userEnteredWordList.length) {
                      //           _saltTextFieldController.text = "";
                      //           // _userSelectedWordIndex += 1;
                      //         } else {
                      //           _saltTextFieldController.text = _userEnteredWordList[_userSelectedWordIndex];
                      //         }
                      //       });
                      //     },
                      //     child: Text(
                      //       "Forward >",
                      //       style: TextStyle(
                      //         color: _isDarkModeEnabled
                      //             ? Colors.greenAccent
                      //             : Colors.blueAccent,
                      //       ),
                      //     ),
                      //   ),),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(
                    "Word #$_wordNumber",
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.white : null,
                    ),
                  ),
                ),
                Divider(
                  color: _isDarkModeEnabled ? Colors.greenAccent : null,
                ),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 90,
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: TextFormField(
                            cursorColor:
                                _isDarkModeEnabled ? Colors.greenAccent : null,
                            autocorrect: false,
                            obscureText: false,
                            minLines: 1,
                            maxLines: 1,
                            decoration: InputDecoration(
                              labelText: 'Word',
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
                              prefixIcon: Icon(
                                Icons.tag,
                                color: _isDarkModeEnabled ? Colors.grey : null,
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
                                    _saltTextFieldController.text = "";
                                    _saltTextFieldValid = false;
                                    // _filteredTags = settingsManager.itemTags;
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
                            controller: _saltTextFieldController,
                            focusNode: _saltTextFieldFocusNode,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: _saltTextFieldValid
                              ? (_isDarkModeEnabled
                                  ? MaterialStateProperty.all<Color>(
                                      Colors.greenAccent)
                                  : null)
                              : MaterialStateProperty.all<Color>(
                                  Colors.blueGrey),
                        ),
                        child: Text(
                          _userSelectedWordIndex == 11 &&
                                  _userEnteredWordList.length == 11
                              ? "Done"
                              : "Next",
                          style: TextStyle(
                            color: _saltTextFieldValid
                                ? (_isDarkModeEnabled
                                    ? Colors.black
                                    : Colors.white)
                                : Colors.black54,
                          ),
                        ),
                        onPressed: _saltTextFieldValid
                            ? () {
                                final saltWord = _saltTextFieldController.text;

                                state(() {
                                  _saltTextFieldController.text = "";
                                  // _userEnteredWordList.add(saltWord);
                                  if (_wordNumber < 12) {
                                    _wordNumber += 1;
                                  }
                                  if (_userSelectedWordIndex <
                                          _wordNumber - 1 &&
                                      _wordNumber <= 12) {
                                    _userSelectedWordIndex += 1;
                                  }

                                  if (_userSelectedWordIndex <
                                      _userEnteredWordList.length - 1) {
                                    _saltTextFieldController.text =
                                        _userEnteredWordList[
                                            _userSelectedWordIndex];
                                    _userEnteredWordList[
                                        _userSelectedWordIndex] = saltWord;
                                  } else {
                                    _saltTextFieldValid = false;
                                    _userEnteredWordList.add(saltWord);
                                  }

                                  _validateModalField(state);
                                });

                                if (_userEnteredWordList.length == 12) {
                                  final test = _userEnteredWordList.join(" ");
                                  if (bip39.validateMnemonic(test)) {
                                    // print("valid mnemonic: $test");
                                    Navigator.of(context).pop();

                                    _userEnteredWordList = [];
                                    _wordNumber = 1;

                                    final entropy =
                                        bip39.mnemonicToEntropy(test);
                                    final entropyBytes = hex.decode(entropy);
                                    final saltB64 = base64.encode(entropyBytes);

                                    ///convert to bytes and bse64 encode it
                                    /// Enter backup password now
                                    ///
                                    if (isLocal) {
                                      _displayRestoreLocalBackupDialog(context,
                                          vaultId, backupName, saltB64);
                                    } else {
                                      _displayRestoreBackupDialog(context,
                                          vaultId, backupName, saltB64);
                                    }
                                  } else {
                                    // print("invalid mnemonic");
                                    Navigator.of(context).pop();

                                    _userEnteredWordList = [];
                                    _wordNumber = 1;

                                    _showErrorDialog("Secret Key is invalid");
                                  }
                                }
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
                Container(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 120,
                      childAspectRatio: 3 / 2,
                    ),
                    itemCount: _filteredWordList.length,
                    itemBuilder: (BuildContext ctx, index) {
                      return GestureDetector(
                        onTap: () {
                          state(() {
                            _saltTextFieldController.text =
                                _filteredWordList[index];
                            _saltTextFieldValid = true;
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              color: _isDarkModeEnabled
                                  ? Colors.greenAccent
                                  : Colors.grey[600],
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                                child: Text(
                                  _filteredWordList[index],
                                  style: TextStyle(
                                    color: _isDarkModeEnabled
                                        ? Colors.black
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          });
        });
  }

  _validateModalField(StateSetter state) async {
    final text = _saltTextFieldController.text;

    if (text.isEmpty) {
      state(() {
        _filteredWordList = WORDLIST;
        _saltTextFieldValid = false;
      });
    } else {
      _filteredWordList = [];
      for (var t in WORDLIST) {
        if (t.contains(text)) {
          _filteredWordList.add(t);
        }
      }
      state(() {
        if (WORDLIST.contains(text)) {
          _saltTextFieldValid = true;
        } else {
          _saltTextFieldValid = false;
        }
      });
    }
  }

  void _displayBackupInfo(VaultItem item) async {
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
                Divider(
                  color: _isDarkModeEnabled ? Colors.greenAccent : null,
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      "name: ${item.name}\nid: ${item.id}\ndeviceId: ${item.deviceId}\ncreated: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse(item.cdate))}\nmodified: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse(item.mdate))}\nCurrent Vault: ${(item.encryptedKey.keyMaterial == keyManager.encryptedKeyMaterial)}",
                      style: TextStyle(
                        color: _isDarkModeEnabled ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
                // Divider(
                //   color: _isDarkModeEnabled ? Colors.greenAccent : null,
                // ),
              ],
            );
          });
        });
    //     .then((value) {
    //     print("Chose value: $value");
    //
    // });
  }

  _showChangeBackupNameDialog() async {
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
                      _dialogChangeNameTextFieldController.text = '';
                      _enableBackupNameOkayButton = false;
                    });

                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _enableBackupNameOkayButton
                      ? () async {
                          final status = await _changeBackupName(
                              _dialogChangeNameTextFieldController.text);

                          Navigator.of(context).pop();

                          if (status) {
                            EasyLoading.showToast(
                                "Backup Name Change Successful");
                          } else {
                            _showErrorDialog("Failed to update Backup name.");
                          }

                          setState(() {
                            _dialogChangeNameTextFieldController.text = '';
                            _enableBackupNameOkayButton = false;
                          });
                        }
                      : null,
                  child: Text('Save'),
                ),
              ],
              content: TextField(
                onChanged: (value) {
                  setState(() {
                    _enableBackupNameOkayButton = value.isNotEmpty;
                  });
                },
                controller: _dialogChangeNameTextFieldController,
                focusNode: _dialogChangeNameFocusNode,
                decoration: InputDecoration(hintText: "New Backup Name"),
              ),
            );
          });
        });
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


  /// create a backup with a user specified name
  Future<bool> _createBackup(bool isLocal) async {
    // _startEasyLoadingScreen();

    var backupName = _dialogTextFieldController.text;
    print('_createBackup: backupName: $backupName');

    var cdate = DateTime.now().toIso8601String();
    var mdate = DateTime.now().toIso8601String();
    // print('cdate: $cdate');
    // print('mdate: $mdate');
    // mdate = "2023-04-08T17:43:11.591311";

    if (isLocal &&
        _localVaultItem != null &&
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

        var currentVault;
        if (_backups.length > 0) {
          _backups.forEach((element) {
            if (element.id == keyManager.vaultId) {
              currentVault = element;
              // break;
            }
          });
        }

        if (currentVault != null && !isLocal) {
          cdate = currentVault.cdate;
        }

        // logManager.logger.d('deviceData: ${settingsManager.deviceManager.deviceData}');
        // logManager.logger.d('test0: ${_localVaultItem?.toJson()}');

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
        // logManager.logger.d('test1');

        var items = await keyManager.getAllItemsForBackup() as GenericItemList;
        // logManager.logger.d('test2: ${items}');

        var testItems = json.encode(items);

        /// TODO: Digital ID
        final myId = await keyManager.getMyDigitalIdentity();
        // logManager.logger.d('test3: ${myId}');

        // var backupNameFinal = '$backupName - ${items.list.length} items';
        if (currentVault != null && !isLocal) {
          backupName = currentVault.name;
        }

        final appVersion = settingsManager.versionAndBuildNumber();
        // logManager.logger.d('test4: ${appVersion}');

        final uuid = keyManager.vaultId;

        final idString =
            "${uuid}-${_deviceId}-${appVersion}-${cdate}-${mdate}-${backupName}";
        logManager.logger.d("idString: $idString ");

        // final idHash = Hasher().sha256Hash(idString);
        // print("idHash: $idHash");
        /// TODO: implement this outside of this function
        settingsManager.doEncryption(utf8.encode(testItems).length);
        // cryptor.setTempKeyIndex(keyIndex);
        // logManager.logger.d("keyIndex: $keyIndex");

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

        /// save android backup in shared preferences, this is because secure
        /// storage doesn't transfer on Android backups.
        if (Platform.isAndroid) {
          final androidBackup = settingsManager.androidBackup;
          if (androidBackup != null) {
            final prevHashString = androidBackup.toRawJson();
            logManager.logger.d("settings current android data model hash: ${prevHashString}");
          }
          await settingsManager.saveAndroidBackup(backupItemString);
        }

        /// Save backup in Documents Directory
        if (isLocal) {
          if (Platform.isAndroid && _shouldSaveToSDCard) {
            /// write backup to SD card
            await fileManager.writeVaultDataSDCard(backupItemString);
          }

          /// write backup to default directory
          await fileManager.writeVaultData(backupItemString);

        } else {

          /// this is for synchronize-able iCloud Backups (not implemented for now)
          final status =
              await keyManager.saveBackupItem(backupItemString, uuid);
          logManager.logger.d("nonlocal: saved vault file: ${status}");

          _fetchBackups();

          if (status) {
            return true;
          } else {
            logManager.logger.d('error saving backup');
            return false;
          }
        }

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

  /// create a backup with a user specified name
  Future<bool> _changeBackupName(String newName) async {
    if (newName.isEmpty) {
      return false;
    }

    var backupName = newName;
    // print('backupName: $backupName');

    if (keyManager.hasPasswordItems) {
      logManager.log(
          "BackupsScreen", "_changeBackupName", "change backup name: $newName");

      // var cdate = DateTime.now().toIso8601String();
      // var mdate = DateTime.now().toIso8601String();

      VaultItem? currentVault;
      if (_backups.length > 0) {
        _backups.forEach((element) {
          if (element.id == keyManager.vaultId) {
            currentVault = element;
            // break;
          }
        });
      }

      if (currentVault == null) {
        return false;
      }

      final cdate = currentVault!.cdate;
      final mdate = DateTime.now().toIso8601String();

      // final items = await keyManager.getAllItems() as GenericItemList;
      // items.list.sort((a, b) {
      //   return b.data.compareTo(a.data);
      // });
      //
      // var testItems = json.encode(items);

      // var hashes = [];
      // for (var singleItem in items.list) {
      //   if (singleItem.type == "password") {
      //     // print("item: ${singleItem.data}");
      //     final pwdItem = PasswordItem.fromRawJson(singleItem.data);
      //     hashes.add(pwdItem.id);
      //
      //   } else if (singleItem.type == "note") {
      //     final noteItem = NoteItem.fromRawJson(singleItem.data);
      //     hashes.add(noteItem.id);
      //   }
      // }

      // print("hashes: ${hashes.length} $hashes");

      // print("items: ${(testItems.length/1024).toStringAsFixed(2)} KB:\n${testItems.toString()}");

      // final itemsHash = cryptor.sha256(testItems.substring(0, 1023));
      // final itemsHash = Hasher().sha256Hash(testItems); // .substring(0, 1023)

      // print("itemsHash: $itemsHash");

      // var backupNameFinal = '$backupName - ${items.list.length} items';
      // if (currentVault != null) {
      //   backupName = currentVault.name;
      // }

      final appVersion = settingsManager.versionAndBuildNumber();//AppConstants.appVersion + "-${AppConstants.appBuildNumber}";

      final uuid = keyManager.vaultId;

      final idStringPrevious =
          "${uuid}-${currentVault!.deviceId}-${currentVault!.version}-${cdate}-${currentVault!.mdate}-${currentVault!.name}";
      final idStringUpdated =
          "${uuid}-${_deviceId}-${appVersion}-${cdate}-${mdate}-${backupName}";

      // final idHash = Hasher().sha256Hash(idString);
      // print("idHash: $idHash");

      // final keyIndex = (currentVault?.keyIndex)!;
      // var keyIndex = 0;
      //
      // if (currentVault?.keyIndex != null) {
      //   keyIndex = (currentVault?.keyIndex)!;
      // }
      var tempDecryptedBlob =
          await cryptor.decryptBackupVault(currentVault!.blob, idStringPrevious);
      print("tempDecryptedBlob: $tempDecryptedBlob");

      if (tempDecryptedBlob == null || tempDecryptedBlob.isEmpty) {
        return false;
      }

      // final items = currentVault.blob; //await keyManager.getAllItems() as GenericItemList;
      var itemList = GenericItemList.fromRawJson(tempDecryptedBlob);
      if (itemList == null) {
        return false;
      }

      var genericItemListFinal;
      if (itemList != null) {
        itemList.list.sort((a, b) {
          return b.data.compareTo(a.data);
        });

        /// TODO: merkle root
        // final itree = await itemList.calculateMerkleTree();
        genericItemListFinal = GenericItemList(list: itemList.list);
      }

      if (genericItemListFinal == null) {
        return false;
      }

      final encodedLength = utf8.encode(tempDecryptedBlob).length;
      settingsManager.doEncryption(encodedLength);
      // cryptor.setTempKeyIndex(keyIndex);

      final keyNonce = _convertEncryptedBlocksNonce();
      logManager.logger.d("keyNonce: $keyNonce");

      final encryptedKeyNonce = await cryptor.encrypt(keyNonce);
      logManager.logger.d("encryptedKeyNonce: $encryptedKeyNonce");

      
      // logManager.logger.d("keyIndex: $keyIndex");

      final encryptedKey = EncryptedKey(
        derivationAlgorithm: currentVault!.encryptedKey.derivationAlgorithm,
        salt: currentVault!.encryptedKey.salt,
        rounds: currentVault!.encryptedKey.rounds,
        type: currentVault!.encryptedKey.type,
        version: currentVault!.encryptedKey.version,
        memoryPowerOf2: currentVault!.encryptedKey.memoryPowerOf2,
        encryptionAlgorithm: currentVault!.encryptedKey.encryptionAlgorithm,
        keyMaterial: currentVault!.encryptedKey.keyMaterial,
        keyNonce: encryptedKeyNonce, //currentVault!.encryptedKey.keyNonce,
        // blocksEncrypted: settingsManager.numBlocksEncrypted,
        // blockRolloverCount: settingsManager.numRolloverEncryptionCounts,
      );

      var testItems = json.encode(genericItemListFinal);
      logManager.logger.d("testItems: $testItems");


      var encryptedBlobUpdated =
          await cryptor.encryptBackupVault(testItems, idStringUpdated);
      // print("encryptedBlobUpdated: $encryptedBlobUpdated");

      // var encryptedBlob = currentVault!.blob; //await cryptor.encrypt2(testItems, idString);
      final blobHash = Hasher().sha256Hash(encryptedBlobUpdated);
      logManager.logger.d("blobHash: $blobHash");

      final deviceDataString = settingsManager.deviceManager.deviceData.toString();
      logManager.logger.d("deviceDataString: $deviceDataString");
      logManager.logger.d("deviceData[utsname.version:]: ${settingsManager.deviceManager.deviceData["utsname.version:"]}");

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
        encryptedKey: encryptedKey, // currentVault!.encryptedKey,
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
          Hasher().sha256Hash(backupItemString); // .substring(0, 1023)

      logManager.log(
          "BackupsScreen", "_changeBackupName", "backup hash: $backupHash");

      /// save android backup in shared preferences, this is because secure
      /// storage doesn't transfer on Android backups.  This is ok because
      /// the item is encrypted anyway.
      if (Platform.isAndroid) {
        await settingsManager.saveAndroidBackup(backupItemString);
      }

      /// TODO: save backup in Documents for iTunes file sharing
      ///
      // final vaultFile =
      await fileManager.writeVaultData(backupItemString);
      // print("saved vault file: ${vaultFile}");

      /// Save backup item in keychain
      /// TODO: await async here
      keyManager.saveBackupItem(backupItemString, uuid).then((value) {
        if (value) {
          _fetchBackups();
          return true;
        } else {
          logManager.logger.d('error saving backup');
          return false;
        }
      });
      return true;
    }
    return false;
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

      // var cdate = DateTime.now().toIso8601String();
      // var mdate = DateTime.now().toIso8601String();

      VaultItem? currentVault = _localVaultItem;
      // if (_backups.length > 0) {
      //   _backups.forEach((element) {
      //     if (element.id == keyManager.vaultId) {
      //       currentVault = element;
      //       // break;
      //     }
      //   });
      // }

      if (currentVault == null) {
        return false;
      }

      final cdate = currentVault!.cdate;
      final mdate = DateTime.now().toIso8601String();

      // final appVersion = settingsManager.packageInfo.version;
      final appVersion = settingsManager.versionAndBuildNumber();//settingsManager.packageInfo.version;
      // final appVersion = AppConstants.appVersion + "-${AppConstants.appBuildNumber}";

      final uuid = keyManager.vaultId;

      final idStringPrevious =
          "${uuid}-${currentVault!.deviceId}-${currentVault!.version}-${cdate}-${currentVault!.mdate}-${currentVault!.name}";
      final idStringUpdated =
          "${uuid}-${_deviceId}-${appVersion}-${cdate}-${mdate}-${backupName}";

      // final idHash = Hasher().sha256Hash(idString);
      // print("idHash: $idHash");
      // var keyIndex = 0;
      //
      // if (currentVault.keyIndex != null) {
      //   keyIndex = (currentVault?.keyIndex)!;
      // }
      // final keyIndex = (currentVault?.keyIndex)!;
      var tempDecryptedBlob =
          await cryptor.decryptBackupVault(currentVault!.blob, idStringPrevious);
      // print("tempDecryptedBlob: $tempDecryptedBlob");

      if (tempDecryptedBlob == null || tempDecryptedBlob.isEmpty) {
        return false;
      }

      var itemList = GenericItemList.fromRawJson(tempDecryptedBlob);
      if (itemList == null) {
        return false;
      }

      /// TODO: possibly use this??
      // var genericItemListFinal;
      // if (itemList != null) {
      //   itemList.list.sort((a, b) {
      //     return b.data.compareTo(a.data);
      //   });
      //
      //   /// TODO: merkle root
      //   final itree = await itemList.calculateMerkleTree();
      //   genericItemListFinal = GenericItemList(list: itemList.list, tree: itree);
      // }
      //
      // if (genericItemListFinal == null) {
      //   return false;
      // }

      /// TODO: implement this outside of this function
      settingsManager.doEncryption(utf8.encode(tempDecryptedBlob).length);
      // cryptor.setTempKeyIndex(keyIndex);
      // logManager.logger.d("keyIndex: $keyIndex");

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
        // blocksEncrypted: settingsManager.numBlocksEncrypted,
        // blockRolloverCount: settingsManager.numRolloverEncryptionCounts,
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
        encryptedKey: encryptedKey, //currentVault!.encryptedKey,
        myIdentity: currentVault!.myIdentity,
        identities: currentVault!.identities,
        recoveryKeys: currentVault!.recoveryKeys,
        numItems: currentVault!.numItems,
        blob: encryptedBlobUpdated,
        // secretShares: secretShareItems,
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
          Hasher().sha256Hash(backupItemString); // .substring(0, 1023)

      logManager.log(
          "BackupsScreen", "_changeBackupName", "backup hash: $backupHash");

      /// save android backup in shared preferences, this is because secure
      /// storage doesn't transfer on Android backups.  This is ok because
      /// the item is encrypted anyway.
      if (Platform.isAndroid) {
        await settingsManager.saveAndroidBackup(backupItemString);
      }

      /// TODO: save backup in Documents for iTunes file sharing
      ///
      await fileManager.writeVaultData(backupItemString);
      // print("saved vault file: ${vaultFile}");

      return true;
    }
    return false;
  }

  /// restore an existing backup with the user specified password
  /// for the backup item
  Future<bool> _restoreBackup(String id, String salt) async {
    logManager.logger.d("_restoreBackup: $salt");

    final password = _dialogRestoreTextFieldController.text;
    if (password.isNotEmpty) {
      final status = await backupManager.restoreBackupItem(password, id, salt);
      logManager.log(
          "BackupsScreen", "_restoreBackup", "restore: $status, id: $id");
      if (status) {
        _fetchBackups();
      }

      return status;
    } else {
      return false;
    }
  }

  Future<bool> _restoreLocalBackup(String salt) async {
    logManager.logger.d("_restoreLocalBackup: $salt");

    final password = _dialogRestoreTextFieldController.text;
    if (password.isNotEmpty) {
      // final status = await backupManager.restoreBackupItem(password, id, salt);
      final status = await backupManager.restoreLocalBackupItem(
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
                          await _createBackup(isLocal).then((value) {
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

  _displayRestoreBackupDialog(
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
                  onPressed: () {
                    _dialogRestoreTextFieldController.text = '';
                    setState(() {
                      _enableRestoreBackupOkayButton = false;
                    });

                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _enableRestoreBackupOkayButton
                      ? () async {
                          final status = await _restoreBackup(id, salt);
                          if (status) {
                            EasyLoading.showToast(
                                'Backup Restored Successfully',
                                duration: Duration(seconds: 3));
                            if (_loginScreenFlow) {
                              // print("login screen flow");
                              Navigator.of(context).pop();
                            }

                            if (!_loginScreenFlow) {
                              // Timer(const Duration(milliseconds: 200), () {
                              _fetchBackups();
                              // });
                            }

                            setState(() {
                              _dialogRestoreTextFieldController.text = '';
                              _enableRestoreBackupOkayButton = false;
                            });

                            Navigator.of(context).pop();
                          } else {
                            _showErrorDialog('Invalid password');
                          }
                        }
                      : null,
                  child: Text('Restore'),
                ),
              ],
              content: TextField(
                decoration: InputDecoration(
                  hintText: "Password",
                  suffix: IconButton(
                    icon: Icon(
                      Icons.remove_red_eye,
                    ),
                    onPressed: () {
                      setState(() {
                        _shouldHideRecoveryPasswordField =
                            !_shouldHideRecoveryPasswordField;
                      });
                    },
                  ),
                  // suffixIcon: Icon(
                  //     Icons.remove_red_eye,
                  //
                  // ),
                ),
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
                  onPressed: () {
                    _dialogRestoreTextFieldController.text = '';
                    setState(() {
                      _enableRestoreBackupOkayButton = false;
                    });

                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _enableRestoreBackupOkayButton
                      ? () async {
                          // show
                    // _startEasyLoadingScreen();

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
                        });

                        Navigator.of(context).pop();
                      } else {
                        _showErrorDialog('Invalid password');
                      }
                    });


                        }
                      : null,
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

  void _showDeleteBackupItemDialog(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Backup'),
        content:
            Text('Are you sure you want to delete this backup item?\n\n$name'),
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
            onPressed: () async {
              _confirmDeleteBackup(id);
              Navigator.of(ctx).pop();
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteBackup(String id) async {
    await keyManager.deleteBackupItem(id).then((value) async {
      // bool status = value;
      // print("deleted Android Backup in secure storage: $status");

      if (Platform.isAndroid) {
        await settingsManager.deleteAndroidBackup();
      }

      // Timer(const Duration(milliseconds: 200), () {
      _fetchBackups();
      // });
    });
  }

  void _showDeleteLocalBackupItemDialog() {
    var warnMsg = "";
    if (Platform.isAndroid) {
      warnMsg = "This will also delete the vault backup from your SD Card if you are using this feature.";
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Backup'),
        content:
            Text('Are you sure you want to delete this backup?\n\n$warnMsg'),
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

  void _confirmDeleteLocalBackup() async {

    if (Platform.isAndroid) {
      await settingsManager.deleteAndroidBackup();
      await fileManager.clearVaultFileSDCard();
    }

    await fileManager.clearVaultFile();

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
