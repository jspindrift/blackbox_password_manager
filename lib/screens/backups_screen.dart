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

import '../helpers/ivHelper.dart';
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
  int _localVaultNonceSequenceNumber = 0;
  int _externalVaultNonceSequenceNumber = 0;

  bool _shouldReKeyLocalVault = false;
  bool _shouldReKeyExternalVault = false;

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

  final _keyManager = KeychainManager();
  final _deviceManager = DeviceManager();
  final _cryptor = Cryptor();
  final _backupManager = BackupManager();
  final _settingsManager = SettingsManager();
  final _logManager = LogManager();
  final _fileManager = FileManager();


  @override
  void initState() {
    super.initState();

    _logManager.log("BackupsScreen", "initState", "initState");

    _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;

    _shouldSaveToSDCard = _settingsManager.saveToSDCard;
    _shouldSaveToSDCardOnly = _settingsManager.saveToSDCardOnly;

    _deviceManager.initialize();

    _deviceManager.getDeviceId().then((value) {
      if (value != null) {
        setState(() {
          _deviceId = value;
        });
      }
    });

    _fetchBackups();
  }

  _fetchBackups() async {

    _keyManager.readEncryptedKey().then((value) {
      setState(() {
        _loginScreenFlow = !_keyManager.hasPasswordItems;
      });
    });

    _isInitState = false;
    _localVaultItem = null;
    _externalVaultItem = null;

    /// get the vault from documents directory and find the matching backup
    var vaultFileString = "";
    var externalVaultFileString = "";

    if (Platform.isAndroid) {
      /// see if we have a vault backup from SD card
      externalVaultFileString = await _fileManager.readVaultDataSDCard();
      vaultFileString = await _fileManager.readNamedVaultData();

      if (externalVaultFileString.isNotEmpty) {
        _externalVaultRecoveryKeys = [];
        /// if no SD card vault, get default file vault location
        await _decryptExternalVault(externalVaultFileString);
      }
    } else {
      vaultFileString = await _fileManager.readNamedVaultData();
    }

    _localVaultHash = _cryptor.sha256(vaultFileString);
    _localVaultRecoveryKeys = [];
    _backups = [];

    await _decryptLocalVault(vaultFileString);


    setState(() {
      /// filter through the list if on Android for duplicate backups
      var backupIds = [];
      List<VaultItem> tempBackups = [];

      for (var backup in _backups) {
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

  bool _checkBackupNonceValidity(VaultItem backup) {
    if (backup?.blob != null) {
      final blobData = base64.decode(backup!.blob);
      var nonce = blobData.sublist(0,16);

      // final rndPart = nonce.sublist(0, 8);
      var seq = nonce.sublist(8, 12);
      var seqjoin = seq.join('');
      int numseq = int.parse(seqjoin);

      if (numseq < pow(2,31)) {
        return true;
      }
    }

    return false;
  }

  int _getBackupNonceSequenceNumber(VaultItem backup) {
    if (backup?.blob != null) {
      final blobData = base64.decode(backup!.blob);
      var nonce = blobData.sublist(0,16);

      var seq = nonce.sublist(8, 12);
      var seqjoin = seq.join('');
      int numseq = int.parse(seqjoin);

      return numseq;
    }

    return 0;
  }

  Future<void> _decryptLocalVault(String vaultItemString) async {
    if (vaultItemString.isNotEmpty) {
      try {
        _localVaultItem = VaultItem.fromRawJson(vaultItemString);
        if (_localVaultItem != null) {
          final isLocalVaultNonceValid = _checkBackupNonceValidity(
              _localVaultItem!);
          _shouldReKeyLocalVault = !isLocalVaultNonceValid;

          _localVaultNonceSequenceNumber =
              _getBackupNonceSequenceNumber(_localVaultItem!);

          _backups.add(_localVaultItem!);

          final encryptedBlob = (_localVaultItem?.blob)!;
          final vaultId = (_localVaultItem?.id)!;
          final deviceId = (_localVaultItem?.deviceId)!;
          final version = (_localVaultItem?.version)!;
          final cdate = (_localVaultItem?.cdate)!;
          final mdate = (_localVaultItem?.mdate)!;
          final name = (_localVaultItem?.name)!;

          final vaultDeviceData = (_localVaultItem?.deviceData)!;

          final currentDeviceData = _settingsManager.deviceManager.deviceData;
          final decryptedVaultDeviceData = await _cryptor.decrypt(
              vaultDeviceData);

          if (vaultDeviceData != null) {
            if (_cryptor.sha256(decryptedVaultDeviceData) !=
                _cryptor.sha256(currentDeviceData.toString())) {
              _logManager.logger.w(
                  "device data changed!\ndecryptedVaultDeviceData:${decryptedVaultDeviceData}\n"
                      "currentDeviceData: ${currentDeviceData}");
            }
          }


          final idString = "${vaultId}-${deviceId}-${version}-${cdate}-${mdate}-${name}";
          // _logManager.logger.wtf("idString: $idString");

          final decryptedBlob = await _cryptor.decryptBackupVault(
              encryptedBlob, idString);
          // _logManager.logger.d("decryption: ${decryptedBlob.length}");

          if (decryptedBlob.isNotEmpty) {
            try {
              /// TODO: add this in
              var genericItems = GenericItemList.fromRawJson(decryptedBlob);
              // _logManager.logger.d("decryption genericItems: ${genericItems.toRawJson()}");

              if (genericItems != null) {
                setState(() {
                  _vaultKeyIsDifferent = false;
                });
              }
            } catch (e) {
              _logManager.logger.e("can not decrypt current backup vault\n"
                  "vaultid: $vaultId: $e");

              // if (mounted) {
              //   setState(() {
              //     _hasMatchingLocalVaultId = _keyManager.vaultId == vaultId;
              //   });
              // }
            }
          } else {
            _logManager.logger.w(
                "can not decrypt current backup vault: $vaultId");
          }


          final encryptedKeyNonce = (_localVaultItem?.encryptedKey
              .keyNonce)!;

          final decryptedKeyNonce = await _cryptor.decrypt(
              encryptedKeyNonce);

          if (decryptedKeyNonce.isNotEmpty) {
            final keyNonce = hex.decode(decryptedKeyNonce);
            if (keyNonce.length != 16) {
              return;
            }
            final ablock = keyNonce.sublist(8, 12);
            final bblock = keyNonce.sublist(12, 16);
            _logManager.logger.d("ablock: ${ablock}\n"
                "bblock: ${bblock}");


            final rollBlockCount = int.parse(
                hex.encode(ablock), radix: 16);
            final encryptedBlockCount = int.parse(
                hex.encode(bblock), radix: 16);
            _logManager.logger.d(
                "rollBlockCount: $rollBlockCount"
                    "\nencryptedBlockCount: ${encryptedBlockCount}\n");

            if (mounted) {
              setState(() {
                _localVaultNumEncryptedBlocks = encryptedBlockCount;
              });
            }
          }
        }

        if (mounted) {
          setState(() {
            if ((_localVaultItem?.recoveryKeys)! != null) {
                  _localVaultRecoveryKeys = (_localVaultItem?.recoveryKeys)!;
                  if (_localVaultRecoveryKeys != null) {
                    _localVaultHasRecoveryKeys =
                    (_localVaultRecoveryKeys!.length > 0);
                  }
                }

                _hasMatchingLocalVaultKeyData =
                    (_localVaultItem?.encryptedKey.keyMaterial)! ==
                        _keyManager.encryptedKeyMaterial;

                _localVaultItemSize = (_localVaultItem
                    ?.toRawJson()
                   .length)!;
            });
        }
      } catch (e) {
        _logManager.logger.e("Exception: $e");
      }
    }
  }

  Future<void> _decryptExternalVault(String externalVaultItemString) async {
    logger.d("_decryptExternalVault");
    if (externalVaultItemString.isNotEmpty) {

      try {
        _externalVaultItem = VaultItem.fromRawJson(externalVaultItemString);
        _hasExternalVault = (_externalVaultItem != null);
        _externalVaultHash = _cryptor.sha256(externalVaultItemString);

        if (_externalVaultItem != null) {
          _backups.add(_externalVaultItem!);

          final isExternalVaultNonceValid = _checkBackupNonceValidity(
              _externalVaultItem!);
          _shouldReKeyExternalVault = !isExternalVaultNonceValid;

          _externalVaultNonceSequenceNumber =
              _getBackupNonceSequenceNumber(_externalVaultItem!);

          final encryptedBlob = (_externalVaultItem?.blob)!;
          final vaultId = (_externalVaultItem?.id)!;
          final deviceId = (_externalVaultItem?.deviceId)!;
          final version = (_externalVaultItem?.version)!;
          final cdate = (_externalVaultItem?.cdate)!;
          final mdate = (_externalVaultItem?.mdate)!;
          final name = (_externalVaultItem?.name)!;

          final vaultDeviceData = (_externalVaultItem?.deviceData)!;

          final currentDeviceData = _settingsManager.deviceManager.deviceData;
          final decryptedVaultDeviceData = await _cryptor.decrypt(
              vaultDeviceData);

          if (vaultDeviceData != null) {
            if (_cryptor.sha256(decryptedVaultDeviceData) !=
                _cryptor.sha256(currentDeviceData.toString())) {
              _logManager.logger.w(
                  "external device data changed!\ndecryptedVaultDeviceData:${decryptedVaultDeviceData}\n"
                      "currentDeviceData: ${currentDeviceData}");
            }
          }

          final idString =
              "${vaultId}-${deviceId}-${version}-${cdate}-${mdate}-${name}";

          final decryptedBlob = await _cryptor.decryptBackupVault(
              encryptedBlob, idString);
          // _logManager.logger.d("decryption: ${decryptedBlob.length}");

          if (decryptedBlob.isNotEmpty) {
            try {
              /// TODO: try decoding, if fail return
              final tryDecode = GenericItemList.fromRawJson(decryptedBlob);
              // _logManager.logger.d("decryption genericItems ext: ${genericItems.toRawJson()}");

            } catch (e) {
              _logManager.logger.e(
                  "can not decode current external backup vault\n"
                      "vaultid: $vaultId: $e");
              return;
            }
          } else {
            _logManager.logger.w(
                "can not decrypt current backup vault: $vaultId");
          }


          final encryptedKeyNonce = (_externalVaultItem?.encryptedKey
              .keyNonce)!;

          final decryptedKeyNonce = await _cryptor.decrypt(
              encryptedKeyNonce);

          if (decryptedKeyNonce.isNotEmpty) {
            final keyNonce = hex.decode(decryptedKeyNonce);
            if (keyNonce.length != 16) {
              return;
            }

            final ablock = keyNonce.sublist(8, 12);
            final bblock = keyNonce.sublist(12, 16);
            _logManager.logger.d("ablock: ${ablock}\n"
                "bblock: ${bblock}");


            final rollBlockCount = int.parse(
                hex.encode(ablock), radix: 16);
            final encryptedBlockCount = int.parse(
                hex.encode(bblock), radix: 16);
            _logManager.logger.d(
                "rollBlockCount: $rollBlockCount"
                    "\nencryptedBlockCount: ${encryptedBlockCount}\n");

            if (mounted) {
              setState(() {
                _localVaultNumEncryptedBlocks = encryptedBlockCount;
              });
            }
          }
        }

        if (mounted) {
          setState(() {
            if ((_externalVaultItem?.recoveryKeys)! != null) {
              _externalVaultRecoveryKeys = (_externalVaultItem?.recoveryKeys)!;
              if (_externalVaultRecoveryKeys != null) {
                _externalVaultHasRecoveryKeys =
                (_externalVaultRecoveryKeys!.length > 0);
              }
            }

            _hasMatchingExternalVaultKeyData =
                (_externalVaultItem?.encryptedKey.keyMaterial)! ==
                    _keyManager.encryptedKeyMaterial;

            _externalVaultItemSize = (_externalVaultItem
                ?.toRawJson()
                .length)!;
          });
        }
      } catch (e) {
        _logManager.logger.e("Exception: $e");
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
    final checkKeyMaterial = _keyManager.encryptedKeyMaterial;

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

    return Visibility(
      visible: _localVaultItem != null,
      child: Container(child:
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
                    ? "Name: ${(_localVaultItem?.name)!}" : "",
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
                  ? "${(_localVaultItem?.numItems)!} items\ncreated: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse((_localVaultItem?.cdate)!))}\nmodified: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse((_localVaultItem?.mdate)!))}\n\nvault id: ${(_localVaultItem?.id)!.toUpperCase()}"
                  "\n\nfingerprint: ${_localVaultHash.substring(0, 32)}\nsequence #: $_localVaultNonceSequenceNumber\n"
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
    ),);
  }

  Widget getExternalBackupTile() {
    var fsize = (_externalVaultItemSize / 1024);
    var funit = "KB";
    if (_externalVaultItemSize > pow(1024, 2)) {
      funit = "MB";
      fsize = (_externalVaultItemSize / pow(1024, 2));
    }

    return Visibility(
      visible: _externalVaultItem != null,
      child:  Container(child:
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
                ? "name: ${(_externalVaultItem?.name)!}" : "",
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
                ? "${(_externalVaultItem?.numItems)!} items\ncreated: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse((_externalVaultItem?.cdate)!))}"
                "\nmodified: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse((_externalVaultItem?.mdate)!))}"
                "\n\nvault id: ${(_externalVaultItem?.id)!.toUpperCase()}"
                  "\n\nfingerprint: ${_externalVaultHash.substring(0, 32)}\nsequence #: $_externalVaultNonceSequenceNumber\n"
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
    ),);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkModeEnabled ? Colors.black54 : Colors.blue[50],//Colors.grey[100],
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
                          WidgetUtils.showSnackBarDuration(context, "Backing Up Vault...", Duration(seconds: 2));

                          if ((_localVaultItem?.id)! == _keyManager.vaultId &&
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
                            _displayCreateBackupDialog(context, true, true);
                          }
                        } else {
                          _displayCreateBackupDialog(context, true, false);
                        }
                      },
                    ),
                  ),
                ),
              ),
              Visibility(
                visible: _shouldReKeyLocalVault || (_shouldReKeyExternalVault && _shouldSaveToSDCard),
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
                        "ReKey and Create Backup",
                        style: TextStyle(
                          color:
                          _isDarkModeEnabled ? Colors.black : Colors.white,
                        ),
                      ),
                      onPressed: () async {
                        if (_localVaultItem != null) {
                          WidgetUtils.showSnackBarDuration(context, "Re-Keying and Backing Up Vault...", Duration(seconds: 2));

                          if ((_localVaultItem?.id)! == _keyManager.vaultId &&
                              _hasMatchingLocalVaultKeyData) {

                            /// TODO: add rekey functionality here
                            ///

                            /// check master password
                            ///
                            /// re-key and backup vault

                            // WidgetUtils.showSnackBarDuration(context, "Backing Up Vault...", Duration(seconds: 2));
                            // final status = await _createBackup();

                            EasyLoading.dismiss();

                            _fetchBackups();

                            EasyLoading.showToast("Implement this.");
                            // if (status) {
                            //   EasyLoading.showToast("Backup Successful");
                            // } else {
                            //   _showErrorDialog("Could not backup vault.");
                            // }
                          } else {
                            _displayCreateBackupDialog(context, true, true);
                          }
                        } else {
                          _displayCreateBackupDialog(context, true, false);
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
            visible: (_localVaultItem == null) && _hasExternalVault,
            child: Divider(
              color: _isDarkModeEnabled ? Colors.greenAccent : null,
            ),
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

    _settingsManager.saveSaveToSDCard(value);
  }

  _pressedSDCardOnlySwitch(bool value) async {

    _settingsManager.saveSaveToSDCardOnly(value);
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    Navigator.of(context)
        .popUntil((route) => route.settings.name == HomeTabScreen.routeName);

    _settingsManager.changeRoute(index);
  }


  _scanForRecoveryKey(bool isLocal) async {
    // logger.d("_scanForRecoveryKey: $isLocal");
    _settingsManager.setIsScanningQRCode(true);

    if (Platform.isIOS) {
      // await _scanQRRecovery(context);
      String barcodeScanRes;
      // Platform messages may fail, so we use a try/catch PlatformException.
      try {
        barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
            "#ff6666", "Cancel", true, ScanMode.QR);

        // logger.d("barcodeScanRes: ${barcodeScanRes}");
        _settingsManager.setIsScanningQRCode(false);

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
        _logManager.logger.w("Platform exception");
        _settingsManager.setIsScanningQRCode(false);
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context)
            .push(MaterialPageRoute(
          builder: (context) => QRScanView(),
        )).then((value) async {
          // logger.d("returned value: $value");
          _settingsManager.setIsScanningQRCode(false);

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
    // logger.d("_decryptWithScannedRecoveryItem: $recoveryItem");
    try {
      RecoveryKeyCode key = RecoveryKeyCode.fromRawJson(recoveryItem);
      if (key != null && _localVaultRecoveryKeys != null) {
        for (var rkey in _localVaultRecoveryKeys!) {
          // logger.d("rkey: ${rkey.toRawJson()}");
          if (rkey.id == key.id) {
            // if (rkey.id == key.id && rkey.keyId == _localVaultItem?.encryptedKey.keyId) {
            // if (rkey.id == key.id && rkey.keyId == _keyManager.keyId) {
              SecretKey skey = SecretKey(base64.decode(key.key));
            final decryptedRootKey = await _cryptor.decryptRecoveryKey(skey, rkey.data);
            // logger.d("decryptedRootKey: ${decryptedRootKey.length}: ${decryptedRootKey}");

            if (!decryptedRootKey.isEmpty) {
              _cryptor.setAesRootKeyBytes(decryptedRootKey);
              await _cryptor.expandSecretRootKey(decryptedRootKey);

              final status = await _backupManager
                  .restoreLocalBackupItemRecovery(_localVaultItem!);
              // logger.d("restoreLocalBackupItemRecovery status: ${status}");

              if (status) {
                if (_loginScreenFlow) {
                  _settingsManager.setIsRecoveredSession(true);
                  // Navigator.of(context).pop();
                  Navigator.of(context).popUntil((route) => route.isFirst);
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
      logger.d("Exception: $e");
      _settingsManager.setIsScanningQRCode(false);
    }

    EasyLoading.dismiss();
  }

  _decryptExternalWithScannedRecoveryItem(String recoveryItem) async {
    logger.d("_decryptExternalWithScannedRecoveryItem");

    EasyLoading.show(status: "Decrypting...");

    try {
      RecoveryKeyCode key = RecoveryKeyCode.fromRawJson(recoveryItem);
      if (key != null && _externalVaultRecoveryKeys != null) {
        for (var rkey in _externalVaultRecoveryKeys!) {
          // logger.d("rkey: ${rkey.toJson()}");
          if (rkey.id == key.id) {
            // if (rkey.id == key.id && rkey.keyId == _externalVaultItem?.encryptedKey.keyId) {
            // if (rkey.id == key.id && rkey.keyId == _keyManager.keyId) {
            SecretKey skey = SecretKey(base64.decode(key.key));
            final decryptedRootKey = await _cryptor.decryptRecoveryKey(skey, rkey.data);
            // logger.d("decryptedRootKey: ${decryptedRootKey.length}: ${decryptedRootKey}");
            if (!decryptedRootKey.isEmpty) {
              _cryptor.setAesRootKeyBytes(decryptedRootKey);
              await _cryptor.expandSecretRootKey(decryptedRootKey);

              final status = await _backupManager
                  .restoreLocalBackupItemRecovery(_externalVaultItem!);
              // logger.d("restoreLocalBackupItemRecovery status: ${status}");

              if (status) {
                if (_loginScreenFlow) {
                  _settingsManager.setIsRecoveredSession(true);
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
      logger.e(e);
      _settingsManager.setIsScanningQRCode(false);
    }

    EasyLoading.dismiss();
  }


  /// create a backup
  ///
  Future<bool> _createBackup() async {

    EasyLoading.show(status: "Creating Backup...");

    var backupName = _dialogTextFieldController.text;

    var cdate = DateTime.now().toIso8601String();
    var mdate = DateTime.now().toIso8601String();

    if (_localVaultItem != null &&
        _localVaultItem?.id == _keyManager.vaultId &&
        _hasMatchingLocalVaultKeyData) {
      if (backupName.isEmpty) {
        backupName = (_localVaultItem?.name)!;
      }
      cdate = (_localVaultItem?.cdate)!;
    }

    try {
      if (_cryptor.aesEncryptionKeyBytes.isNotEmpty && _cryptor.aesAuthKeyBytes.isNotEmpty) {
        _logManager.log("BackupsScreen", "_createBackup", "create backup");
        _logManager.logger.d("BackupsScreen-create backup");

        var currentVault = _localVaultItem;
        var keyId = _keyManager.keyId;

        if (currentVault != null) {
          cdate = currentVault.cdate;
          keyId = currentVault.encryptedKey.keyId;
        }

        var numRounds = _cryptor.rounds;
        final salt = _keyManager.salt;
        final kdfAlgo = EnumToString.convertToString(KDFAlgorithm.pbkdf2_512);
        final rounds =  numRounds;
        final type = 0;
        final version = 1;
        final memoryPowerOf2 = 0;
        final encryptionAlgo =
            EnumToString.convertToString(EncryptionAlgorithm.aes_ctr_256);
        final keyMaterial = _keyManager.encryptedKeyMaterial;

        var items = await _keyManager.getAllItemsForBackup() as GenericItemList;
        final numItems = items.list.length;
        var testItems = json.encode(items);

        final myId = await _keyManager.getMyDigitalIdentity();
        final appVersion = _settingsManager.versionAndBuildNumber();
        // _logManager.logger.d('test4: ${appVersion}');

        final uuid = _keyManager.vaultId;

        /// create iv
        var nonce = _cryptor.getNewNonce();
        nonce = nonce.sublist(0,8) + [0,0,0,1] + [0,0,0,0];

        if (_localVaultItem?.blob != null) {
          final blobData = base64.decode(_localVaultItem!.blob);
          var currentNonce = blobData.sublist(0,16);
          // _logManager.logger.d('currentNonce: ${currentNonce}');
          final updatedNonce = ivHelper().incrementSequencedNonce(currentNonce);
          nonce = updatedNonce;
        }
        _logManager.logger.wtf("backupNonce: ${nonce}");

        final idString =
            "${uuid}-${_deviceId}-${appVersion}-${cdate}-${mdate}-${backupName}";
        // _logManager.logger.wtf("idString: $idString ");

        // _logManager.logger.d("testItems.length: ${testItems.length}\n"
        //     "utf8.encode(testItems).length: ${utf8.encode(testItems).length}");

        final identities = await _keyManager.getIdentities();
        final recoveryKeys = await _keyManager.getRecoveryKeyItems();
        final deviceDataString = _settingsManager.deviceManager.deviceData.toString();
        // _logManager.logLongMessage("deviceDataString: $deviceDataString");

        _settingsManager.doEncryption(utf8.encode(deviceDataString).length);
        final encryptedDeviceData = await _cryptor.encrypt(deviceDataString);
        // _logManager.logger.d("encryptedDeviceData: $encryptedDeviceData");
        // _logManager.logger.d("deviceDataString.length: ${deviceDataString.length}\n"
        //     "utf8.encode(deviceDataString).length: ${utf8.encode(deviceDataString).length}");

        _settingsManager.doEncryption(utf8.encode(testItems).length);

        final keyNonce = _convertEncryptedBlocksNonce();
        final encryptedKeyNonce = await _cryptor.encrypt(keyNonce);
        // _logManager.logger.d("encryptedKeyNonce: $encryptedKeyNonce");

        var encryptedBlob = await _cryptor.encryptBackupVault(testItems, nonce, idString);

        final encryptedKey = EncryptedKey(
          keyId: keyId!,
          derivationAlgorithm: kdfAlgo,
          salt: salt,
          rounds: rounds,
          type: type,
          version: version,
          memoryPowerOf2: memoryPowerOf2,
          encryptionAlgorithm: encryptionAlgo,
          keyMaterial: keyMaterial,
          keyNonce: encryptedKeyNonce,
          // mac: "",
        );

        // /// TODO: replace this HMAC function to use derived auth key
        // final keyParamsMac = await _cryptor.hmac256(encryptedKey.toRawJson());
        // encryptedKey.mac = base64.encode(hex.decode(keyParamsMac));
        // _logManager.logger.d('encryptedKey: ${encryptedKey.toJson()}');

        var backupItem = VaultItem(
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
          mac: "",
        );

        final backupMac = await _cryptor.hmac256(backupItem.toRawJson());
        backupItem.mac = base64.encode(hex.decode(backupMac));

        final backupItemString = backupItem.toRawJson();
        final backupHash = _cryptor.sha256(backupItemString);
        // _logManager.logLongMessage("backupItemJson-long: ${backupItemString.length}: ${backupItemString}");
        // _logManager.logger.d("backup hash: $backupHash");

        _logManager.log(
            "BackupsScreen", "_createBackup", "backup hash:\n$backupHash\n\nvault id: ${uuid}");

        /// TODO: change to detailed file name
        final normDate = mdate.replaceAll(":", "_");
        final backupFileName = "Blackbox-$backupName-(${numItems} items, ${recoveryKeys?.length} recovery keys)-${normDate}";

        if (Platform.isAndroid && _shouldSaveToSDCard
            || Platform.isAndroid && _shouldSaveToSDCardOnly) {

          await _createExternalBackup(backupName, mdate);
        }

        if (!_shouldSaveToSDCardOnly) {
          await _fileManager.writeNamedVaultData(
              backupFileName, backupItemString);
        }

        EasyLoading.dismiss();

        return true;
      }
      return false;
    } catch (e) {
      _logManager.logger.d("Exception: $e");
      return false;
    }
  }

  /// create external SD card backup
  ///
  Future<bool> _createExternalBackup(String userBackupName, String modifiedDateString) async {

    var backupName = userBackupName.isEmpty ? _dialogTextFieldController.text : userBackupName;

    var cdate = DateTime.now().toIso8601String();
    var mdate = modifiedDateString;

    var localKeyId = _keyManager.keyId;
    var keyId = localKeyId;

    // if (_externalVaultItem != null &&
    //     _externalVaultItem?.id == _keyManager.vaultId &&
    //     _hasMatchingExternalVaultKeyData) {
    //
    //   backupName = (_externalVaultItem?.name)!;
    //   cdate = (_externalVaultItem?.cdate)!;
    //   keyId = _externalVaultItem?.encryptedKey.keyId ?? "";
    // }

    if (localKeyId != keyId) {
      logger.wtf("keyId != localKeyId");
      return false;
    }

    try {
      if (_cryptor.aesEncryptionKeyBytes.isNotEmpty && _cryptor.aesAuthKeyBytes.isNotEmpty) {
        _logManager.log("BackupsScreen", "_createBackup", "create backup");
        _logManager.logger.d("BackupsScreen-create backup external");

        var currentVault = _externalVaultItem;
        cdate = (_externalVaultItem?.cdate)!;
        keyId = _externalVaultItem?.encryptedKey.keyId ?? "";

        if (currentVault != null) {
          cdate = currentVault.cdate;
          if (backupName.isEmpty) {
            backupName = currentVault.name;
          }
        }

        /// create EncryptedKey object
        final salt = _keyManager.salt;
        final kdfAlgo = EnumToString.convertToString(KDFAlgorithm.pbkdf2_512);
        final rounds =  _cryptor.rounds;
        final type = 0;
        final version = 1;
        final memoryPowerOf2 = 0;
        final encryptionAlgo =
        EnumToString.convertToString(EncryptionAlgorithm.aes_ctr_256);
        final keyMaterial = _keyManager.encryptedKeyMaterial;

        var items = await _keyManager.getAllItemsForBackup() as GenericItemList;
        final numItems = items.list.length;

        var testItems = json.encode(items);

        /// TODO: Digital ID
        final myId = await _keyManager.getMyDigitalIdentity();
        final appVersion = _settingsManager.versionAndBuildNumber();
        final uuid = _keyManager.vaultId;

        /// create iv
        var nonce = _cryptor.getNewNonce();
        nonce = nonce.sublist(0,8) + [0,0,0,1] + [0,0,0,0];

        if (_externalVaultItem?.blob != null) {
          final blobData = base64.decode(_externalVaultItem!.blob);
          var currentNonce = blobData.sublist(0,16);
          // _logManager.logger.d('currentNonce: ${currentNonce}');
          final updatedNonce = ivHelper().incrementSequencedNonce(currentNonce);
          nonce = updatedNonce;
        }
        // _logManager.logger.wtf("backupNonce: ${nonce}");

        final idString =
            "${uuid}-${_deviceId}-${appVersion}-${cdate}-${mdate}-${backupName}";
        // _logManager.logger.wtf("idString: $idString");

        final identities = await _keyManager.getIdentities();
        final recoveryKeys = await _keyManager.getRecoveryKeyItems();
        final deviceDataString = _settingsManager.deviceManager.deviceData.toString();
        // _logManager.logLongMessage("deviceDataString: $deviceDataString");

        _settingsManager.doEncryption(utf8.encode(deviceDataString).length);
        final encryptedDeviceData = await _cryptor.encrypt(deviceDataString);
        // _logManager.logger.d("encryptedDeviceData: $encryptedDeviceData");

        _settingsManager.doEncryption(utf8.encode(testItems).length);

        final keyNonce = _convertEncryptedBlocksNonce();
        final encryptedKeyNonce = await _cryptor.encrypt(keyNonce);
        // _logManager.logger.d("keyNonce: $keyNonce");
        // _logManager.logger.d("encryptedKeyNonce: $encryptedKeyNonce");

        var encryptedBlob = await _cryptor.encryptBackupVault(testItems, nonce, idString);
        // _logManager.logger.d('encryptedBlob: ${encryptedBlob.length}: $encryptedBlob');

        final encryptedKey = EncryptedKey(
          keyId: keyId!,
          derivationAlgorithm: kdfAlgo,
          salt: salt,
          rounds: rounds,
          type: type,
          version: version,
          memoryPowerOf2: memoryPowerOf2,
          encryptionAlgorithm: encryptionAlgo,
          keyMaterial: keyMaterial,
          keyNonce: encryptedKeyNonce,
          // mac: "",
        );

        /// TODO: replace this HMAC function to use derived auth key
        // final keyParamsMac = await _cryptor.hmac256(encryptedKey.toRawJson());
        // encryptedKey.mac = base64.encode(hex.decode(keyParamsMac));
        // _logManager.logger.d('encryptedKey: ${encryptedKey.toJson()}');

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
          mac: "",
        );

        final backupMac = await _cryptor.hmac256(backupItem.toRawJson());
        backupItem.mac = base64.encode(hex.decode(backupMac));

        final backupItemString = backupItem.toRawJson();
        final backupHash = _cryptor.sha256(backupItemString);
        // _logManager.logLongMessage("backupItemJson-long: ${backupItemString.length}: ${backupItemString}");

        _logManager.log(
            "BackupsScreen", "_createBackup", "backup hash:\n$backupHash\n\nvault id: ${uuid}");

        /// TODO: change to detailed file name
        final normDate = mdate.replaceAll(":", "_");
        final backupFileName = "Blackbox-$backupName-(${numItems} items, ${recoveryKeys?.length} recovery keys)-${normDate}";

        /// write backup to SD card
        await _fileManager.writeVaultDataSDCard(backupFileName, backupItemString);

        return true;
      }
      return false;
    } catch (e) {
      _logManager.logger.d("Exception: $e");
      return false;
    }
  }


  String _convertEncryptedBlocksNonce() {
    final zeroBlock = List<int>.filled(16, 0);

    /// account for what we are about to encrypt
    _settingsManager.doEncryption(16);
    
    final numRollover = _settingsManager.numRolloverEncryptionCounts;
    final numBlocks = _settingsManager.numBlocksEncrypted;
    // final currentNonce = zeroBlock.sublist(0, 8) + cbytes + zeroBlock.sublist(0, 4);
    // final shortNonce = zeroBlock.sublist(0, 8) + cbytes;// + zeroBlock.sublist(0, 4);
    // _logManager.logger.d("_convertEncryptedBlocksNonce: numBlocks: $numBlocks");

    var aindex = int.parse("${numRollover}").toRadixString(16);
    // _logManager.logger.d("aindex: $aindex");

    if (aindex.length % 2 == 1) {
      aindex = "0" + aindex;
    }


    // _logManager.logger.d("aindex: ${aindex.length}: ${aindex}");
    final abytes = hex.decode(aindex);
    // _logManager.logger.d("abytes: ${abytes.length}: ${abytes}");

    final blockNonceABytes = zeroBlock.sublist(0, 4 - abytes.length) +
        abytes;

    // _logManager.logger.d("abytes: ${abytes.length}: ${abytes}");

    var bindex = int.parse("${numBlocks}").toRadixString(16);
    // _logManager.logger.d("bindex: $bindex");

    if (bindex.length % 2 == 1) {
      bindex = "0" + bindex;
    }

    final bbytes = hex.decode(bindex);
    // _logManager.logger.d("bbytes: $bbytes");

    final blockNonceBBytes = zeroBlock.sublist(0, 4 - bbytes.length) +
        bbytes;
    
    // _logManager.logger.d("blockNonceBBytes: ${blockNonceBBytes.length}: ${hex.encode(
    //     blockNonceBBytes)}");
    
    /// form nonce based on message index
    final countingNonce = blockNonceABytes + blockNonceBBytes;
    // _logManager.logger.d("countingNonce: ${countingNonce.length}: ${hex.encode(
    //     countingNonce)}");
    
    final currentNonce = zeroBlock.sublist(0, 16-countingNonce.length) + countingNonce;
    // _logManager.logger.d("currentNonce: ${currentNonce.length}: ${hex.encode(
    //     currentNonce)}");
    
    
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
                          "name: ${item.name}\nDevice ID: ${item.deviceId}\nVault ID: ${item.id.toUpperCase()}\nKey ID: ${item.encryptedKey.keyId.toUpperCase()}"
                              "\n\ncreated: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse(item.cdate))}"
                              "\nmodified: ${DateFormat('MMM d y  hh:mm a').format(DateTime.parse(item.mdate))}"
                              "\napp version: ${item.version}"
                              // "\nsalt: ${(item.encryptedKey.salt)}"
                              "\nencryptedBlocks: ${(encryptedBlocks > 0 ? encryptedBlocks: "?")}"
                              "\nkey health: ${(100* (AppConstants.maxEncryptionBlocks-encryptedBlocks)/AppConstants.maxEncryptionBlocks).toStringAsFixed(6)} %"
                              "\n\nfingerprint: ${fingerprint}\n\n\n\n",
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

  /// change local backup name
  ///
  Future<bool> _changeLocalBackupName(String newName) async {
    if (newName.isEmpty) {
      return false;
    }

    var backupName = newName;

    if (_keyManager.hasPasswordItems) {
      _logManager.log(
          "BackupsScreen", "_changeBackupName", "change backup name: $newName");

      VaultItem? currentVault = _localVaultItem;

      if (currentVault == null) {
        return false;
      }

      final cdate = currentVault!.cdate;
      final mdate = DateTime.now().toIso8601String();

      final appVersion = _settingsManager.versionAndBuildNumber();
      final uuid = _keyManager.vaultId;

      final idStringPrevious =
          "${uuid}-${currentVault!.deviceId}-${currentVault!.version}-${cdate}-${currentVault!.mdate}-${currentVault!.name}";
      // _logManager.logger.wtf("idStringPrevious: $idStringPrevious");

      var tempDecryptedBlob =
          await _cryptor.decryptBackupVault(currentVault!.blob, idStringPrevious);

      if (tempDecryptedBlob == null || tempDecryptedBlob.isEmpty) {
        return false;
      }

      var itemList = GenericItemList.fromRawJson(tempDecryptedBlob);
      final numItems = itemList.list.length;
      if (itemList == null) {
        return false;
      }


      /// create iv
      var nonce = _cryptor.getNewNonce();
      nonce = nonce.sublist(0,8) + [0,0,0,1] + [0,0,0,0];

      if (currentVault?.blob != null) {
        final blobData = base64.decode(currentVault!.blob);
        var currentNonce = blobData.sublist(0,16);
        // _logManager.logger.d('currentNonce: ${currentNonce}');
        final updatedNonce = ivHelper().incrementSequencedNonce(currentNonce);
        nonce = updatedNonce;
      }

      _logManager.logger.wtf("backupNonce: ${nonce}");

      final idStringUpdated =
          "${uuid}-${_deviceId}-${appVersion}-${cdate}-${mdate}-${backupName}";
      // _logManager.logger.wtf("idStringUpdated: $idStringUpdated");

      final deviceDataString = _settingsManager.deviceManager.deviceData.toString();
      // _logManager.logger.d("deviceDataString: $deviceDataString");

      /// TODO: implement this outside of this function
      _settingsManager.doEncryption(utf8.encode(tempDecryptedBlob).length);

      _settingsManager.doEncryption(utf8.encode(deviceDataString).length);
      final encryptedDeviceData = await _cryptor.encrypt(deviceDataString);

      final keyNonce = _convertEncryptedBlocksNonce();
      final encryptedKeyNonce = await _cryptor.encrypt(keyNonce);

      var encryptedBlobUpdated =
      await _cryptor.encryptBackupVault(tempDecryptedBlob, nonce, idStringUpdated);

      final encryptedKey = EncryptedKey(
        keyId: currentVault!.encryptedKey.keyId,
        derivationAlgorithm: currentVault!.encryptedKey.derivationAlgorithm,
        salt: currentVault!.encryptedKey.salt,
        rounds: currentVault!.encryptedKey.rounds,
        type: currentVault!.encryptedKey.type,
        version: currentVault!.encryptedKey.version,
        memoryPowerOf2: currentVault!.encryptedKey.memoryPowerOf2,
        encryptionAlgorithm: currentVault!.encryptedKey.encryptionAlgorithm,
        keyMaterial: currentVault!.encryptedKey.keyMaterial,
        keyNonce: encryptedKeyNonce,
      );

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
        mac: "",
      );

      final backupMac = await _cryptor.hmac256(backupItem.toRawJson());
      backupItem.mac = base64.encode(hex.decode(backupMac));

      final backupItemString = backupItem.toRawJson();
      // _logManager.logger.d('backupItemString: $backupItemString');

      final backupHash =
          Hasher().sha256Hash(backupItemString);

      _logManager.log(
          "BackupsScreen", "_changeBackupName", "backup hash: $backupHash");

      /// TODO: named backup files
      final normDate = mdate.replaceAll(":", "_");
      final backupFileName = "Blackbox-$backupName-(${numItems} items, ${currentVault!.recoveryKeys?.length} recovery keys)-${normDate}";

      await _fileManager.writeNamedVaultData(backupFileName, backupItemString);

      return true;
    }
    return false;
  }

  /// change external SD card backup name
  ///
  Future<bool> _changeExternalBackupName(String newName) async {
    if (newName.isEmpty) {
      return false;
    }

    var backupName = newName;

    if (_keyManager.hasPasswordItems) {
      _logManager.log(
          "BackupsScreen", "_changeBackupName", "change backup name: $newName");

      VaultItem? currentVault = _externalVaultItem;

      if (currentVault == null) {
        return false;
      }

      final cdate = currentVault!.cdate;
      final mdate = DateTime.now().toIso8601String();

      final appVersion = _settingsManager.versionAndBuildNumber();
      final uuid = _keyManager.vaultId;

      // _logManager.logger.wtf("ivListHash: ${ivListHashPrevious}");

      final idStringPrevious =
          "${uuid}-${currentVault!.deviceId}-${currentVault!.version}-${cdate}-${currentVault!.mdate}-${currentVault!.name}";
      // _logManager.logger.wtf("idStringPrevious: $idStringPrevious");

      final tempDecryptedBlob =
      await _cryptor.decryptBackupVault(currentVault!.blob, idStringPrevious);
      // logger.d("tempDecryptedBlob: $tempDecryptedBlob");

      if (tempDecryptedBlob == null || tempDecryptedBlob.isEmpty) {
        return false;
      }

      var itemList = GenericItemList.fromRawJson(tempDecryptedBlob);
      final numItems = itemList.list.length;
      if (itemList == null) {
        return false;
      }

      /// create iv
      var nonce = _cryptor.getNewNonce();
      nonce = nonce.sublist(0,8) + [0,0,0,1] + [0,0,0,0];

      if (currentVault?.blob != null) {
        final blobData = base64.decode(currentVault!.blob);
        var currentNonce = blobData.sublist(0,16);
        // _logManager.logger.d('currentNonce: ${currentNonce}');
        final updatedNonce = ivHelper().incrementSequencedNonce(currentNonce);
        nonce = updatedNonce;
      }

      final idStringUpdated =
          "${uuid}-${_deviceId}-${appVersion}-${cdate}-${mdate}-${backupName}";

      _settingsManager.doEncryption(utf8.encode(tempDecryptedBlob).length);

      // logger.d("encryptedBlobUpdated: $encryptedBlobUpdated");

      final deviceDataString = _settingsManager.deviceManager.deviceData.toString();

      _settingsManager.doEncryption(utf8.encode(deviceDataString).length);
      final encryptedDeviceData = await _cryptor.encrypt(deviceDataString);
      // _logManager.logger.d("encryptedDeviceData: $encryptedDeviceData");

      final keyNonce = _convertEncryptedBlocksNonce();
      final encryptedKeyNonce = await _cryptor.encrypt(keyNonce);

      final encryptedBlobUpdated =
      await _cryptor.encryptBackupVault(tempDecryptedBlob, nonce, idStringUpdated);


      final encryptedKey = EncryptedKey(
        keyId: currentVault!.encryptedKey.keyId,
        derivationAlgorithm: currentVault!.encryptedKey.derivationAlgorithm,
        salt: currentVault!.encryptedKey.salt,
        rounds: currentVault!.encryptedKey.rounds,
        type: currentVault!.encryptedKey.type,
        version: currentVault!.encryptedKey.version,
        memoryPowerOf2: currentVault!.encryptedKey.memoryPowerOf2,
        encryptionAlgorithm: currentVault!.encryptedKey.encryptionAlgorithm,
        keyMaterial: currentVault!.encryptedKey.keyMaterial,
        keyNonce: encryptedKeyNonce,
      );

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
        mac: "",
      );

      final backupMac = await _cryptor.hmac256(backupItem.toRawJson());
      backupItem.mac = base64.encode(hex.decode(backupMac));

      final backupItemString = backupItem.toRawJson();
      // logger.d('backupItemString: $backupItemString');

      final backupHash =
      Hasher().sha256Hash(backupItemString);

      _logManager.log(
          "BackupsScreen", "_changeBackupName", "backup hash: $backupHash");

      /// TODO: named backup files
      final normDate = mdate.replaceAll(":", "_");
      final backupFileName = "Blackbox-$backupName-(${numItems} items, ${currentVault!.recoveryKeys?.length} recovery keys)-${normDate}";

      /// write backup to SD card
      await _fileManager.writeVaultDataSDCard(backupFileName, backupItemString);

      return true;
    }
    return false;
  }


  /// restore local backup
  ///
  Future<bool> _restoreLocalBackup(String salt) async {
    _logManager.logger.d("_restoreLocalBackup");

    final password = _dialogRestoreTextFieldController.text;
    if (password.isNotEmpty) {

      final status = await _backupManager.restoreBackupItem(
          _localVaultItem!,
          password,
          salt,
      );

      _logManager.logger.d("status: ${status}, code: ${_backupManager.responseStatusCode}");
      _logManager.log(
          "BackupsScreen", "_restoreLocalBackup", "restore: $status");

      if (_backupManager.responseStatusCode == 0) {
        if (_backupManager.backupErrorMessage.isNotEmpty) {
          EasyLoading.showToast(
              _backupManager.backupErrorMessage,
              duration: Duration(seconds: 5));
        } else {
          EasyLoading.showToast(
              'Backup Restored Successfully',
              duration: Duration(seconds: 3));
        }
        return status;
      } else {
        WidgetUtils.showSnackBar(context, _backupManager.backupErrorMessage + ": " + _backupManager.responseStatusCode.toString());
        return false;
      }
    } else {
      return false;
    }
  }

  Future<bool> _restoreExternalBackup(String salt) async {
    _logManager.logger.d("_restoreExternalBackup");

    final password = _dialogRestoreTextFieldController.text;
    if (password.isNotEmpty) {

      final status = await _backupManager.restoreBackupItem(
        _externalVaultItem!,
        password,
        salt,
      );

      _logManager.logger.d("status: ${status}, code: ${_backupManager.responseStatusCode}");
      _logManager.log(
          "BackupsScreen", "_restoreExternalBackup", "restore: $status");

      if (_backupManager.responseStatusCode == 0) {
        if (_backupManager.backupErrorMessage.isNotEmpty) {
          EasyLoading.showToast(
              _backupManager.backupErrorMessage,
              duration: Duration(seconds: 5));
        } else {
          EasyLoading.showToast(
              'Backup Restored Successfully',
              duration: Duration(seconds: 3));
        }
        return status;
      } else {
        WidgetUtils.showSnackBar(context, _backupManager.backupErrorMessage + ": " + _backupManager.responseStatusCode.toString());
        return false;
      }
    } else {
      return false;
    }
  }


  _displayCreateBackupDialog(BuildContext context, bool isLocal, bool willOverwrite) async {
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
                          // final status =
                          await _createBackup();
                          _fetchBackups();

                          setState(() {
                            _dialogTextFieldController.text = '';
                            _enableBackupNameOkayButton = false;
                          });

                          Navigator.of(context).pop();
                        }
                      : null,
                  child: Text('Save'),
                ),
              ],
              content: Column(
                mainAxisSize: MainAxisSize.min,
                  children:[
                Visibility(
                  visible: willOverwrite,
                  child: Padding(
                  padding: EdgeInsets.fromLTRB(0, 8, 0, 16),
                  child: Text(
                    "Warning: This will overwrite your existing backup!",
                    style: TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ),),
                TextField(
                  controller: _dialogTextFieldController,
                  focusNode: _dialogTextFieldFocusNode,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "Backup Name",
                  ),
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
                  },),
                ]),
            );
          });
        });
  }

  _displayRestoreLocalBackupDialog(
      BuildContext context, String id, String name, String salt) async {
    // _logManager.logger.wtf("here");
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
                            // EasyLoading.showToast(
                            //     'Backup Restored Successfully',
                            //     duration: Duration(seconds: 3));
                            if (_loginScreenFlow) {
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
                autofocus: true,
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
                autofocus: true,
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

    await _fileManager.clearNamedVaultFile();

    _localVaultItem = null;

    _fetchBackups();
  }

  void _confirmDeleteExternalBackup() async {

    await _fileManager.clearVaultFileSDCard();

    _externalVaultItem = null;

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
