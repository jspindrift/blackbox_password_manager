import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:enum_to_string/enum_to_string.dart';

import '../helpers/AppConstants.dart';
import '../models/MyDigitalIdentity.dart';
import '../models/KeyItem.dart';
import '../models/VaultItem.dart';
import '../models/PasswordItem.dart';
import '../models/NoteItem.dart';
import '../models/GenericItem.dart';
import 'DeviceManager.dart';
import 'Hasher.dart';
import 'KeychainManager.dart';
import 'Cryptor.dart';
import 'LogManager.dart';
import 'SettingsManager.dart';
import 'FileManager.dart';

/*
* TODO: Keep a list of initialization vectors used to ensure no repetition
* occurs.  Then when the lookup gets too inefficient we will just re-key
* and re-encrypt all our data.
*
* */

class BackupManager {
  static final BackupManager _shared = BackupManager._internal();

  factory BackupManager() {
    return _shared;
  }

  /// debug testing recovery failure modes
  static const bool testFail1 = false;  // fail decode item list after good password
  static const bool testFail2 = false;  // fail save items
  static const bool testFail3 = false;  // fail save identities - true
  static const bool testFail4 = false;  // fail save  my identity
  static const bool testFail5 = false;  // fail save recovery keys
  static const bool testFail6 = false;  // fail save master password

  int responseStatusCode = 0; // 0 == success, 1 = fail restore, recover success, 2 = fail restore, recover failure

  String backupErrorMessage = "Backup Restore Failed";
  String tempHint = "";
  VaultItem? _currentDeviceVault;
  GenericItemList? _currentItemList;
  // MyDigitalIdentity? _currentMyDigitalIdentity;
  // List<DigitalIdentity>? _currentIdentites;
  // List<RecoveryKey>? _currentRecoveryKeys;

  List<int>? _tempRootKey;

  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _fileManager = FileManager();
  final _deviceManager = DeviceManager();
  final _keyManager = KeychainManager();
  final _cryptor = Cryptor();

  BackupManager._internal();


  /// call this before restoring a backup in case we fail and have to recover
  ///
  Future<bool> _prepareToRestore() async {
    _logManager.logger.d("prepareToRestore");

    /// get all keychain vault items
    final tempVaultItem = await _backupCurrentVaultState();
    if (tempVaultItem == null) {
      return false;
    }

    _tempRootKey = _cryptor.aesRootSecretKeyBytes;

    tempHint = _keyManager.hint;
    _logManager.logger.d("tempHint: $tempHint");
    // _logManager.logger.d("_cryptor.aesRootSecretKeyBytes: ${hex.encode(_tempRootKey!)}");

    final tempBackupItemString = tempVaultItem.toRawJson();
    // _logManager.logger.d("tempBackupItemString: $tempBackupItemString");

    /// backup current vault to temp file
    try {
      await _fileManager.writeTempVaultData(tempBackupItemString);
      return true;
    } catch(e) {
      return false;
    }
  }


  Future<bool> restoreBackupItem(
      VaultItem vault, String password, String salt) async {
    /// first must check password before restoring
    // final _keyManager = KeychainManager();
    // final _cryptor = Cryptor();

    _logManager.logger.d("restoreLocalBackupItem:\nvaultId: ${vault.id}:\ndeviceId: ${vault.deviceId}\n"
        "name: ${vault.name}");
    _logManager.log(
        "BackupManager", "restoreLocalBackupItem", "id: ${vault.id}");
    _logManager.logger.d("restoreLocalBackupItem:\neKey: ${vault.encryptedKey.toJson()}:\n"
        "mdate: ${vault.mdate}\ncdate: ${vault.cdate}");

    try {
      // if (!_keyManager.salt.isEmpty) {
        final prepareStatus = await _prepareToRestore();
        if (!prepareStatus) {
          _logManager.logger.d("here-prepare");

          return false;
        }
      // }

      final backupHash = _cryptor.sha256(vault.toRawJson());
      _logManager.log("BackupManager", "restoreLocalBackupItem",
          "backup hash: $backupHash");

      final ek = vault.encryptedKey;
      final keyMaterial = ek.keyMaterial;

      final result = await _cryptor.deriveKeyCheckAgainst(
        password,
        ek.rounds,
        salt,
        keyMaterial,
      );

      if (AppConstants.debugKeyData) {
        _logManager.logger.d('deriveKeyCheckAgainst result: $result');
        _logManager.logger.d('password: ${password}\nek.rounds: ${ek
            .rounds}\nsalt:$salt\nkeyMaterial: ${keyMaterial}');
      }

      if (result) {
        _logManager.logger.d("here!! result good");

        KeyMaterial newKeyMaterial = KeyMaterial(
          id: vault.id,
          keyId: vault.encryptedKey.keyId,
          salt: salt,
          rounds: ek.rounds,
          key: keyMaterial,
          hint: "",
        );

        /// delete keys
        ///
        var encryptedBlob = vault.blob;

        var idString =
            "${vault.id}-${vault.deviceId}-${vault.version}-${vault.cdate}-${vault.mdate}-${vault.name}";

        if (vault.usedIVs != null) {
          _logManager.logger.wtf("usedIVs: ${vault.usedIVs}");
          if (vault.usedIVs!.isNotEmpty) {
            final ivListHash = _cryptor.sha256(vault.usedIVs.toString());

            idString =
            "${vault.id}-${vault.deviceId}-${vault.version}-${vault.cdate}-${vault.mdate}-${ivListHash}-${vault.name}";
          }
        }

        _logManager.logger.d("decryption-idString: ${idString}");

        final decryptedBlob = await _cryptor.decryptBackupVault(encryptedBlob, idString);
        _logManager.logger.d("decryption blob-length: ${decryptedBlob.length}");

        if (testFail1) {
          _logManager.logger.d("here1");
          responseStatusCode = 1;
          backupErrorMessage = "Backup Restore Failed: Blob Decryption";
          return await _recoverVault();
        }

        if (decryptedBlob.isNotEmpty) {
          _logManager.logger.d("here-decryptedBlob no empty");

          var genericItems;
          try {
            genericItems = GenericItemList.fromRawJson(decryptedBlob);
            _logManager.logger.d("GenericItemList protocol");


            if (genericItems != null) {
              // await _keyManager.deleteForBackup();

              final encryptedKeyNonce = vault.encryptedKey.keyNonce;
              // _logManager.logger.d("encryptedKeyNonce: ${encryptedKeyNonce}");

              final decryptedKeyNonce = await _cryptor.decrypt(encryptedKeyNonce);//.then((value) {
                // final decryptedKeyNonce = value;
                // _logManager.logger.d("decryptedKeyNonce: ${decryptedKeyNonce}\n"
                //     "base64decoded keyNonce: ${hex.decode(decryptedKeyNonce)}");

                final keyNonce = hex.decode(decryptedKeyNonce);
                final ablock = keyNonce.sublist(8, 12);
                final bblock = keyNonce.sublist(12, 16);
                // _logManager.logger.d("ablock: ${ablock}\n"
                //     "bblock: ${bblock}");

                final rolloverBlockCount = int.parse(hex.encode(ablock), radix: 16);
                final encryptedBlockCount = int.parse(hex.encode(bblock), radix: 16);
                // _logManager.logger.d("encryptedBlockCount: ${encryptedBlockCount}\n"
                //     "rolloverBlockCount: ${rolloverBlockCount}");

              if (encryptedBlockCount != null) {
                await _settingsManager.saveNumBytesEncrypted(
                  encryptedBlockCount * 16,
                );

                await _settingsManager.saveNumBlocksEncrypted(
                    encryptedBlockCount);
              }

              if (rolloverBlockCount != null) {
                await _settingsManager.saveEncryptionRolloverCount(
                  rolloverBlockCount,
                );
              }

              await _keyManager.deleteForBackup();

            } else {
              _logManager.logger.d("here-fail3");

              backupErrorMessage = "Backup Restore Failed: Generic Object Decoding 2";
              responseStatusCode = 1;
              _logManager.logger.d("object could not be decoded");
              return await _recoverVault();
            }
          } catch(e) {
            _logManager.logger.d("here-Esxception: $e");

            backupErrorMessage = "Backup Restore Failed: Generic Object Decoding";
            responseStatusCode = 1;
            _logManager.logger.d("object could not be:$e");
            return await _recoverVault();
          }

          // print("jbird: ${genericItems2.list}");
          if (genericItems.list.isNotEmpty) {
            // _logManager.logger.d("try genericItems2 iteration");

            /// Go through each GenericItem
            for (var genericItem in genericItems.list) {
              var itemId = "";
              if (genericItem.type == "password") {
                // _logManager.logger.d("try password");

                final passwordItem = PasswordItem.fromRawJson(genericItem.data);
                itemId = passwordItem.id;
              } else if (genericItem.type == "note") {
                // _logManager.logger.d("try note");

                final noteItem = NoteItem.fromRawJson(genericItem.data);
                itemId = noteItem.id;
              } else if (genericItem.type == "key") {
                // _logManager.logger.d("try key");

                final keyItem = KeyItem.fromRawJson(genericItem.data);
                itemId = keyItem.id;
              }
              final genericItemString = genericItem.toRawJson();

              if (itemId.isEmpty) {
                _logManager.logger.d("BackupManager: itemId is EMPTY!!");
                continue;
              }

              /// save generic item
              final status = await _keyManager.saveItem(itemId, genericItemString);
              if (testFail2) {
                _logManager.logger.d("here2");
                responseStatusCode = 1;
                backupErrorMessage = "Backup Restore Failed: Saving Vault Item";
                return await _recoverVault();
              }

              if (!status) {
                _logManager.logger.d("here2");
                await _keyManager.deleteAllItems();
                responseStatusCode = 1;
                backupErrorMessage = "Backup Restore Failed: Saving Vault Item";
                /// TODO: revert back
                return await _recoverVault();
              }
            }
          }
          _logManager.logger.d("here-fallthrough4");

        } else if (vault.numItems > 0) {
          // _logManager.logger.d("here-decryptedBlob no empty");

          responseStatusCode = 1;
          backupErrorMessage = "Backup Restore Failed: Blob is Empty/Decryption";

          _logManager.logger.d("object could not be decoded2");
          return await _recoverVault();
        }

        /// save my identity
        ///
        if (vault.myIdentity != null) {
          _logManager.logger.d("here-restore myIdentity");

          final myId = vault.myIdentity as MyDigitalIdentity;
          final status = await _keyManager.saveMyIdentity(vault.id, myId.toRawJson());
          if (testFail3) {
            _logManager.logger.d("here-restore myIdentity 1");

            responseStatusCode = 1;
            backupErrorMessage = "Backup Restore Failed: Saving My Digital Identity";
            return await _recoverVault();
          }
          if (!status) {
            _logManager.logger.d("here-restore myIdentity 2");

            await _keyManager.deleteAllItems();
            responseStatusCode = 1;
            backupErrorMessage = "Backup Restore Failed: Saving My Digital Identity";
            /// TODO: revert back
            return await _recoverVault();
          }
        }


        /// save identities
        ///
        if (vault.identities != null) {
          _logManager.logger.d("here-restore identities");

          for (var id in vault.identities!) {
            final status = await _keyManager.saveIdentity(id.id, id.toRawJson());
            if (testFail4) {
              _logManager.logger.d("here-restore identities 4");

              responseStatusCode = 1;
              await _keyManager.deleteAllItems();
              _keyManager.deleteMyDigitalIdentity();
              await _keyManager.deleteAllPeerIdentities();
              backupErrorMessage = "Backup Restore Failed: Saving Identity";
              return await _recoverVault();
            }
            if (!status) {
              _logManager.logger.d("here-restore identities 4b");

              await _keyManager.deleteAllItems();
              await _keyManager.deleteMyDigitalIdentity();
              await _keyManager.deleteAllPeerIdentities();

              responseStatusCode = 1;
              backupErrorMessage = "Backup Restore Failed: Saving Identity";
              /// TODO: revert back
              return await _recoverVault();
            }
          }
        }


        /// save recovery keys
        ///
        if (vault.recoveryKeys != null) {
          _logManager.logger.d("here-restore recoveryKeys");

          for (var key in vault.recoveryKeys!) {
            final status = await _keyManager.saveRecoveryKey(key.id, key.toRawJson());
            if (testFail5) {
              _logManager.logger.d("here-restore recoveryKeys - 5");

              responseStatusCode = 1;
              await _keyManager.deleteAllItems();
              await _keyManager.deleteMyDigitalIdentity();
              await _keyManager.deleteAllPeerIdentities();
              await _keyManager.deleteAllRecoveryKeys();

              backupErrorMessage = "Backup Restore Failed: Saving Recovery Key";
              return await _recoverVault();
            }
            if (!status) {
              _logManager.logger.d("here-restore recoveryKeys - 5a");

              responseStatusCode = 1;
              await _keyManager.deleteAllItems();
              await _keyManager.deleteMyDigitalIdentity();
              await _keyManager.deleteAllPeerIdentities();
              await _keyManager.deleteAllRecoveryKeys();

              backupErrorMessage = "Backup Restore Failed: Saving Recovery Key";
              /// TODO: revert back
              return await _recoverVault();
            }
          }
        }


        /// save master password details
        ///
        final status = await _keyManager.saveMasterPassword(
            newKeyMaterial,
        );
        _logManager.logger.d("here-restore saveMasterPassword: $status");

        if (testFail6) {
          _logManager.logger.d("here-restore saveMasterPassword: fail 6");

          await _keyManager.deleteAllItems();
          await _keyManager.deleteMyDigitalIdentity();
          await _keyManager.deleteAllPeerIdentities();
          await _keyManager.deleteAllRecoveryKeys();

          backupErrorMessage = "Backup Restore Failed: Saving Master Password";
          responseStatusCode = 1;
          return await _recoverVault();
        }

        if (!status) {
          _logManager.logger.d("here-restore saveMasterPassword: fail 6a");

          await _keyManager.deleteAllItems();
          await _keyManager.deleteMyDigitalIdentity();
          await _keyManager.deleteAllPeerIdentities();
          await _keyManager.deleteAllRecoveryKeys();

          backupErrorMessage = "Backup Restore Failed: Saving Master Password";
          /// TODO: revert back
          responseStatusCode = 1;
          return await _recoverVault();
        }


        /// re-save log key in-case we needed to create a new one
        await _keyManager.saveLogKey(_cryptor.logKeyMaterial);

        /// re-read and refresh our variables
        await _keyManager.readEncryptedKey();

        await _fileManager.clearTempVaultFile();

        _logManager.logger.w("BackupManager - restoreLocalBackupItem - true");
        _logManager.logger.d("here-restore restoreLocalBackupItem: true");
        responseStatusCode = 0;

        return true;
      }

      _logManager.logger.d("here-restore restoreLocalBackupItem: false: _reExpandCurrentKey");

      await _reExpandCurrentKey();
      responseStatusCode = 1;
      backupErrorMessage = "Backup Restore Failed: Incorrect Password";
      _logManager.logger.w("BackupManager - restoreLocalBackupItem - Failure");
      return false; //await _recoverVault();
    } catch (e) {

      _logManager.logger
          .w("BackupManager - restoreLocalBackupItem - Exception: $e");
      _logManager.log("BackupManager", "restoreLocalBackupItem", "$e");
      return await _recoverVault();
    }
  }

  Future<bool> restoreLocalBackupItemRecovery(VaultItem localVault) async {
    _logManager.log("BackupManager", "restoreLocalBackupItemRecovery",
        "id: ${localVault.id}");

    try {
      final prepareStatus = await _prepareToRestore();
      if (!prepareStatus) {
        return false;
      }

      final backupHash = Hasher().sha256Hash(localVault.toRawJson());
      _logManager.log("BackupManager", "restoreLocalBackupItemRecovery",
          "backup hash: $backupHash");

      final ek = localVault.encryptedKey;
      final keyMaterial = ek.keyMaterial;

      final salt = localVault.encryptedKey.salt;
      var encryptedBlob = localVault.blob;

      final idString =
          "${localVault.id}-${localVault.deviceId}-${localVault.version}-${localVault.cdate}-${localVault.mdate}-${localVault.name}";


      final decryptedBlob = await _cryptor.decryptBackupVault(encryptedBlob, idString);

      if (decryptedBlob.isNotEmpty) {
        /// since our decryption is valid we can now delete local keys to re-save
        await _keyManager.deleteForBackup();

        if (localVault.encryptedKey != null) {
          /// version 1
          // final keyRollIndex = localVault.encryptedKey.blockRolloverCount;
          // await _settingsManager.saveEncryptionRolloverCount(keyRollIndex!);

          /// version 2
          final encryptedKeyNonce = localVault.encryptedKey.keyNonce;
          _logManager.logger.d("encryptedKeyNonce: ${encryptedKeyNonce}");

          final decryptedKeyNonce = await _cryptor.decrypt(encryptedKeyNonce);
          _logManager.logger.d("decryptedKeyNonce: ${decryptedKeyNonce}\n"
              "base64decoded keyNonce: ${hex.decode(decryptedKeyNonce)}");

          final keyNonce = hex.decode(decryptedKeyNonce);
          final ablock = keyNonce.sublist(8, 12);
          final bblock = keyNonce.sublist(12, 16);

          // _logManager.logger.d("ablock: ${ablock}\n"
          //     "bblock: ${bblock}");

          final rolloverBlockCount = int.parse(hex.encode(ablock), radix: 16);
          final encryptedBlockCount = int.parse(hex.encode(bblock), radix: 16);
          _logManager.logger.d("encryptedBlockCount: ${encryptedBlockCount}\n"
              "rolloverBlockCount: ${rolloverBlockCount}");
          // });

          if (encryptedBlockCount != null) {
            await _settingsManager.saveNumBytesEncrypted(
              encryptedBlockCount * 16,
            );

            await _settingsManager.saveNumBlocksEncrypted(
                encryptedBlockCount);
          }

          if (rolloverBlockCount != null) {
            await _settingsManager.saveEncryptionRolloverCount(
              rolloverBlockCount,
            );
          }
        }
        // print("decryption successfull");

        /// TODO: add this in
        ///
        var genericItems = GenericItemList.fromRawJson(decryptedBlob);
          _logManager.logger.e("GenericItemList protocol");


        if (!genericItems.list.isEmpty) {
          // genericItems2.list.sort((a, b) {
          //   return b.data.compareTo(a.data);
          // });

          /// Go through each GenericItem
          for (var genericItem in genericItems.list) {
            var itemId = "";
            if (genericItem.type == "password") {
              final passwordItem = PasswordItem.fromRawJson(genericItem.data);
              itemId = passwordItem.id;
            } else if (genericItem.type == "note") {
              final noteItem = NoteItem.fromRawJson(genericItem.data);
              itemId = noteItem.id;
            } else if (genericItem.type == "key") {
              final keyItem = KeyItem.fromRawJson(genericItem.data);
              itemId = keyItem.id;
            }
            final genericItemString = genericItem.toRawJson();

            if (itemId.isEmpty) {
              _logManager.logger.d("BackupManager: itemId is EMPTY!!");
              continue;
            }

            /// save generic item
            final status = await _keyManager.saveItem(itemId, genericItemString);
            // _logManager.logger.d("BackupManager - saveItem - status: $status");
            if (!status) {
              /// TODO: revert back
              return await _recoverVault();
            }
          }
        }
      } else {
        _logManager.logger.d("could not decrypt blob");
        return await _recoverVault();
      }

      /// save my identity
      ///
      if (localVault.myIdentity != null) {
        final myId = localVault.myIdentity as MyDigitalIdentity;

        final status = await _keyManager.saveMyIdentity(localVault.id, myId.toRawJson());
        if (!status) {
          /// TODO: revert back
          return await _recoverVault();
        }
      }

      /// save identities
      ///
      if (localVault.identities != null) {
        for (var id in localVault.identities!) {
          final status = await _keyManager.saveIdentity(id.id, id.toRawJson());
          if (!status) {
            /// TODO: revert back
            return await _recoverVault();
          }
        }
      }

      /// save recovery keys
      ///
      if (localVault.recoveryKeys != null) {
        for (var key in localVault.recoveryKeys!) {
          final status = await _keyManager.saveRecoveryKey(key.id, key.toRawJson());
          if (!status) {
            /// TODO: revert back
            return await _recoverVault();
          }
        }
      }

      KeyMaterial newKeyMaterial = KeyMaterial(
        id: localVault.id,
        keyId: localVault.encryptedKey.keyId,
        salt: salt!,
        rounds: ek.rounds,
        key: keyMaterial,
        hint: "",
      );

      /// save master password details
      ///
      if (salt != null) {
        final status = await _keyManager.saveMasterPassword(
            newKeyMaterial,
        );

        if (!status) {
          /// TODO: revert back
          return await _recoverVault();
        }


        // final thisDeviceId = await _deviceManager.getDeviceId();
        if (status) {
          /// re-save log key in-case we needed to create a new one
          await _keyManager.saveLogKey(_cryptor.logKeyMaterial);

          /// re-read and refresh our variables
          await _keyManager.readEncryptedKey();
        }

        return status;
      } else {
        return await _recoverVault();
      }

    } catch (e) {
      _logManager.logger
          .w("BackupManager - restoreLocalBackupItem - Exception: $e");

      _logManager.log("BackupManager", "restoreLocalBackupItem", "$e");
      return await _recoverVault();
    }
  }


  /// RECOVERY SERVICE - In Case of Failure
  ///
  ///

  Future<VaultItem?> _backupCurrentVaultState() async {
    _logManager.logger.d("_backupCurrentVaultState");

    /// create EncryptedKey object
    var keyId = _keyManager.keyId;

    final salt = _keyManager.salt;
    final kdfAlgo = EnumToString.convertToString(KDFAlgorithm.pbkdf2_512);
    final rounds = _cryptor.rounds;
    final type = 0;
    final version = 1;
    final memoryPowerOf2 = 0;
    final encryptionAlgo = EnumToString.convertToString(EncryptionAlgorithm.aes_ctr_256);
    final keyMaterial = _keyManager.encryptedKeyMaterial;

    // var items = await _keyManager.getAllItemsForBackup() as GenericItemList;
    var items = await _getKeychainGenericItemListState();

    _currentItemList = items;

    /// TODO: Digital ID
    final myId = await _keyManager.getMyDigitalIdentity();
    // _currentMyDigitalIdentity = myId; // await _keyManager.getMyDigitalIdentity();

    final deviceId = await _deviceManager.getDeviceId();
    if (deviceId == null) {
      return null;
    }

    final timestamp = DateTime.now().toIso8601String();
    final backupName = "temp-vault";

    final appVersion = _settingsManager.versionAndBuildNumber();//"v" + AppConstants.appVersion + " (${AppConstants.appBuildNumber})";
    // final uuid = _cryptor.getUUID();
    final vaultId = _keyManager.vaultId;


    /// TODO: get iv and add to iv list
    final iv = _cryptor.getNewNonce();

    List<String>? currentIVList = [];

    currentIVList?.add(base64.encode(iv));

    /// get hash of iv list
    final ivListHash = _cryptor.sha256(currentIVList.toString());

    final idString =
        "${vaultId}-${deviceId}-${appVersion}-${timestamp}-${timestamp}-${ivListHash}-${backupName}";
    // final idHash = Hasher().sha256Hash(idString);
    // print("idHash: $idHash");

    var testItems = json.encode(items);

    var encryptedBlob = await _cryptor.encryptBackupVault(testItems, iv, idString);


    final identities = await _keyManager.getIdentities();
    // _currentIdentites = identities;

    final recoveryKeys = await _keyManager.getRecoveryKeyItems();
    // _currentRecoveryKeys = recoveryKeys;

    final deviceDataString = _settingsManager.deviceManager.deviceData.toString();
    // _logManager.logger.d("deviceDataString: $deviceDataString");
    // _logManager.logger.d("deviceData[utsname.version:]: ${_settingsManager.deviceManager.deviceData["utsname.version:"]}");

    _settingsManager.doEncryption(utf8.encode(deviceDataString).length);
    final encryptedDeviceData = await _cryptor.encrypt(deviceDataString);
    // _logManager.logger.d("encryptedDeviceData: $encryptedDeviceData");

    _settingsManager.doEncryption(utf8.encode(testItems).length);

    final keyNonce = _convertEncryptedBlocksNonce();
    _logManager.logger.d("keyNonce: ${keyNonce.length}: ${keyNonce}\n"
        "keyNonce utf8: ${utf8.encode(keyNonce).length}: ${utf8.encode(keyNonce)}");

    final encryptedKeyNonce = await _cryptor.encrypt(keyNonce);
    // _logManager.logger.d("encryptedKeyNonce: $encryptedKeyNonce");

    var encryptedKey = EncryptedKey(
      keyId: keyId,
      derivationAlgorithm: kdfAlgo,
      salt: salt,
      rounds: rounds,
      type: type,
      version: version,
      memoryPowerOf2: memoryPowerOf2,
      encryptionAlgorithm: encryptionAlgo,
      keyMaterial: keyMaterial,
      keyNonce: encryptedKeyNonce,
      mac: "",
    );

    final keyParamsMac = await _cryptor.hmac256(encryptedKey.toRawJson());
    encryptedKey.mac = keyParamsMac;


    var backupItem = VaultItem(
      id: vaultId,
      version: appVersion,
      name: backupName,
      deviceId: deviceId,
      deviceData: encryptedDeviceData,
      encryptedKey: encryptedKey,
      myIdentity: myId,
      identities: identities,
      recoveryKeys: recoveryKeys,
      numItems: items.list.length,
      blob: encryptedBlob,
      cdate: timestamp,
      mdate: timestamp,
      mac: "",
      usedIVs: currentIVList,
    );

    final backupMac = await _cryptor.hmac256(backupItem.toRawJson());
    backupItem.mac = backupMac;

    // _logManager.logLongMessage("backupItemJson-long: ${backupItem.toRawJson().length}: ${backupItem.toRawJson()}");

    // print("passwordItems: $passwordItems");
    // print("genericItems: $items");

    // print("backupItemJson: ${backupItem.toRawJson().length}: ${backupItem.toRawJson()}");
    _currentDeviceVault = backupItem;

    return backupItem;
  }

  String _convertEncryptedBlocksNonce() {
    final zeroBlock = List<int>.filled(16, 0);

    /// account for what we are about to encrypt
    _settingsManager.doEncryption(16);

    final numRollover = _settingsManager.numRolloverEncryptionCounts;
    final numBlocks = _settingsManager.numBlocksEncrypted;
    // final currentNonce = zeroBlock.sublist(0, 8) + cbytes + zeroBlock.sublist(0, 4);
    // final shortNonce = zeroBlock.sublist(0, 8) + cbytes;// + zeroBlock.sublist(0, 4);

    var aindex = int.parse("${numRollover}").toRadixString(16);
    // _logManager.logger.d("aindex: $aindex");

    if (aindex.length % 2 == 1) {
      aindex = "0" + aindex;
    }

    final abytes = hex.decode(aindex);
    final blockNonceABytes = zeroBlock.sublist(0, 4 - abytes.length) +
        abytes;

    var bindex = int.parse("${numBlocks}").toRadixString(16);
    // _logManager.logger.d("bindex: $bindex");

    if (bindex.length % 2 == 1) {
      bindex = "0" + bindex;
    }

    final bbytes = hex.decode(bindex);
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


  Future<GenericItemList> _getKeychainGenericItemListState() async {
    var finalGenericItemList = GenericItemList(list: []);
    var localGenericItemList = await _keyManager.getAllItemsForBackup() as GenericItemList;
    var list = localGenericItemList.list;
    if (list == null) {
      return finalGenericItemList;
    }
    list.sort((a, b) {
      return b.data.compareTo(a.data);
    });

    // tempGenList.list = list;
    // final itree = await localGenericItemList.calculateMerkleTree();
    finalGenericItemList = GenericItemList(list: list);


    return finalGenericItemList;
  }

  Future<bool> _recoverVault() async {
    _logManager.logger.w("_recoverVault in action");

    if (_currentDeviceVault == null) {
      await _reExpandCurrentKey();
      responseStatusCode = 2;
      _logManager.logger.w("_currentDeviceVault == null");
      return false;
    }

    try {
      await _reExpandCurrentKey();

      final status2 = await _resaveAllOriginalItems();

      final status3 = await _resaveAllOriginalIdentities();
      final status4 = await _resaveAllOriginalRecoveryKeys();

      _logManager.logger.d(
          "status2: $status2, status3: $status3, status4: $status4");

      final keyId = (_currentDeviceVault?.encryptedKey.keyId)!;
      final vaultId = (_currentDeviceVault?.id)!;
      final keyMaterial = (_currentDeviceVault?.encryptedKey.keyMaterial)!;
      final nrounds = (_currentDeviceVault?.encryptedKey.rounds)!;

      // await _reExpandCurrentKey();
      final encodedSalt = (_currentDeviceVault?.encryptedKey.salt)!;

      KeyMaterial newKeyMaterial = KeyMaterial(
        id: vaultId,
        keyId: keyId,
        salt: encodedSalt,
        rounds: nrounds,
        key: keyMaterial,
        hint: tempHint,
      );

      /// TODO: re-save master password key data
      ///
      final statusMaster = await _keyManager.saveMasterPassword(
        newKeyMaterial,
      );

      // _logManager.logger.d("statusMaster: $statusMaster");

      final statusFinal = await _keyManager.readEncryptedKey();
      _logManager.logger.d("statusFinal: $statusFinal");

      final isAllValid = (status2 && status3
          && status4 && statusFinal
          && statusMaster);

      responseStatusCode = isAllValid ? 0 : 2;

      return status2 && status3 && status4 && statusFinal && statusMaster;
    } catch (e) {
      _logManager.logger.w("_recoverVault failure: $e");
      return false;
    }
  }

  Future<void> _reExpandCurrentKey() async {
    final encodedSalt = (_currentDeviceVault?.encryptedKey.salt)!;

    _cryptor.setSecretSaltBytes(base64.decode(encodedSalt));

    if (_tempRootKey != null) {
      await _cryptor.expandSecretRootKey(_tempRootKey!);
    }
  }

  /// RESAVING ORIGINAL DATA - Recovery
  /// We call this if restore fails
  ///
  Future<bool> _resaveAllOriginalItems() async {

    final tempAllGenericItemList = _currentItemList;
    if (tempAllGenericItemList == null) {
      // responseStatusCode =
      return false;
    }

    for (var item in tempAllGenericItemList.list) {
      if (item.type == "password") {
        var passwordItem = PasswordItem.fromRawJson(item.data);
        if (passwordItem != null) {
          final status = await _keyManager.saveItem(passwordItem.id, item.toRawJson());
          if (!status) {
            return false;
          }
        } else {
          return false;
        }
      } else if (item.type == "note") {
        var noteItem = NoteItem.fromRawJson(item.data);
        if (noteItem != null) {
          // final keyIndex = (noteItem?.keyIndex)!;
          final status = await _keyManager.saveItem(noteItem.id, item.toRawJson());
          if (!status) {
            return false;
          }
        } else {
          return false;
        }
      } else if (item.type == "key") {
        var keyItem = KeyItem.fromRawJson(item.data);
        if (keyItem != null) {
          final status = await _keyManager.saveItem(keyItem.id, item.toRawJson());
          if (!status) {
            return false;
          }

        } else {
          return false;
        }
      }
    }

    return true;
  }

  Future<bool> _resaveAllOriginalIdentities() async {
    /// owner digital identity
    final myId = (_currentDeviceVault?.myIdentity)!;
    if (myId != null) {
      final statusMyId = await _keyManager.saveMyIdentity(
        _keyManager.vaultId,
        myId.toRawJson(),
      );
      if (!statusMyId) {
        return false;
      }
    }

    /// peer identities
    final origIds = (_currentDeviceVault?.identities)!; //_currentIdentites;
    if (origIds != null) {
      for (var id in origIds) {
        final identityObjectString = id.toRawJson();
        // print("identityObjectString: $identityObjectString");
        final statusId = await _keyManager.saveIdentity(
          id.id,
          identityObjectString,
        );
        if (!statusId) {
          return false;
        }
      }
    }
    return true;
  }

  Future<bool> _resaveAllOriginalRecoveryKeys() async {
    final origRecoveryKeys  = (_currentDeviceVault?.recoveryKeys)!; //_currentRecoveryKeys;
    if (origRecoveryKeys != null) {
      for (var recoveryKey in origRecoveryKeys) {
        final status = await _keyManager.saveRecoveryKey(
          recoveryKey.id,
          recoveryKey.toRawJson(),
        );
        if (!status) {
          return false;
        }
      }
    }
    return true;
  }

}
