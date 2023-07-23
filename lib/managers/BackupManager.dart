import 'dart:convert';
import 'dart:io';
import '../helpers/AppConstants.dart';
import 'package:convert/convert.dart';
import 'package:enum_to_string/enum_to_string.dart';

import '../models/DigitalIdentity.dart';
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

  final logManager = LogManager();
  final settingsManager = SettingsManager();
  final fileManager = FileManager();
  final deviceManager = DeviceManager();
  final keyManager = KeychainManager();
  final cryptor = Cryptor();

  BackupManager._internal();


  /// call this before restoring a backup in case we fail and have to recover
  ///
  Future<bool> _prepareToRestore() async {
    logManager.logger.d("prepareToRestore");

    /// get all keychain vault items
    final tempVaultItem = await _backupCurrentVaultState();
    if (tempVaultItem == null) {
      return false;
    }

    _tempRootKey = cryptor.aesRootSecretKeyBytes;

    tempHint = keyManager.hint;
    logManager.logger.d("tempHint: $tempHint");
    // logManager.logger.d("cryptor.aesRootSecretKeyBytes: ${hex.encode(_tempRootKey!)}");

    final tempBackupItemString = tempVaultItem.toRawJson();
    logManager.logger.d("tempBackupItemString: $tempBackupItemString");

    /// backup current vault to temp file
    try {
      await fileManager.writeTempVaultData(tempBackupItemString);
      return true;
    } catch(e) {
      return false;
    }
  }

  /// restore the backup item with the master password for the item
  ///
  /// TODO: restore Android backup from shared preferences
  Future<bool> restoreBackupItem(
      String password, String id, String salt) async {
    /// first must check password before restoring
    final keyManager = KeychainManager();
    logManager.log("BackupManager", "restoreBackupItem", "id: $id");

    try {
      /// determine if we need to backup from Android shared preferences backup
      var androidBackup;
      var restoreAndroidBackup = false;
      if (Platform.isAndroid) {
        androidBackup = settingsManager.androidBackup;
        if (androidBackup != null) {
          final androidBackupId = androidBackup?.id;
          if (androidBackupId == id) {
            restoreAndroidBackup = true;
          }
        }
      }

      /// get backup item key and check password
      final backupItem = await keyManager.getBackupItem(id);
      var vault;
      if (restoreAndroidBackup) {
        vault = androidBackup as VaultItem;
      } else {
        vault = backupItem as VaultItem;
      }

      final backupHash = Hasher().sha256Hash(vault.toRawJson());
      logManager.log(
          "BackupManager", "restoreBackupItem", "backup hash: $backupHash");

      final ek = vault.encryptedKey;
      final keyMaterial = ek.keyMaterial;
      if (vault.bytesEncrypted != null) {
        final numBytesEncrypted = vault.bytesEncrypted;
        final keyRolloverIndex = vault.encryptionKey.keyRollIndex;

        await settingsManager.saveNumBytesEncrypted(numBytesEncrypted);
        await settingsManager.saveNumBlocksEncrypted((numBytesEncrypted/16).ciel());

        await settingsManager.saveEncryptionRolloverCount(keyRolloverIndex);

      }

      final cryptor = Cryptor();

      final result = await cryptor.deriveKeyCheckAgainst(
        password,
        ek.rounds,
        salt,
        keyMaterial,
      );
      // print('password: $password');
      //
      // print('result: $result');
      // print('rounds: ${ek.rounds}');
      // print('salt: ${ek.salt}');
      // print('keyMaterial: $keyMaterial');

      // final ek = backupItem.encryptedKey;

      if (result) {

        KeyMaterial newKeyMaterial = KeyMaterial(
            id: id,
            salt: salt,
            rounds: ek.rounds,
            key: keyMaterial,
            hint: "",
        );

        // cryptor.setCurrentKeyMaterial(newKeyMaterial);
        /// delete keys
        ///
        var encryptedBlob = vault.blob;

        final idString =
            "${vault.id}-${vault.deviceId}-${vault.version}-${vault.cdate}-${vault.mdate}-${vault.name}";

        final decryptedBlob = await cryptor.decryptBackupVault(encryptedBlob, idString);
        // logManager.logger.d("decryptedBlob: ${decryptedBlob}");
        if (decryptedBlob.isNotEmpty) {
          /// since our decryption is valid we can now delete local keys to re-save
          ///
          /// TODO: add this in
          var genericItems2 = GenericItemList.fromRawJson(decryptedBlob);
          // print("genericItems2: ${genericItems2}");
          // return false;

          await keyManager.deleteForBackup();

          // print("decryption successfull: $decryptedBlob");


          // return;
          if (!genericItems2.list.isEmpty) {
            genericItems2.list.sort((a, b) {
              return b.data.compareTo(a.data);
            });
            // print("sorted genericItems2: ${genericItems2}");

            /// Go through each GenericItem
            for (var genericItem in genericItems2.list) {
              var itemId = "";
              // print("generic item: ${genericItem}");

              // print("item type: ${genericItem.type}");
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
                logManager.logger.d("BackupManager: itemId is EMPTY!!");
                // print("generic item: ${genericItem}");

                continue;
              }

              /// save generic item
              // final status =
              await keyManager.saveItem(itemId, genericItemString);
              // logManager.logger.d("BackupManager - saveItem - status: $status");
            }
          }
        } else if (vault.numItems > 0) {
          logManager.logger.d("object could not be decoded");
          return false;
        }

        /// save my identity
        if (vault.myIdentity != null) {
          final myId = vault.myIdentity as MyDigitalIdentity;

          await keyManager.saveMyIdentity(vault.id, myId.toRawJson());
        }

        /// save identities
        ///
        if (vault.identities != null) {
          for (var id in vault.identities!) {
            await keyManager.saveIdentity(id.id, id.toRawJson());
          }
        }

        /// save recovery keys
        ///
        if (vault.recoveryKeys != null) {
          for (var key in vault.recoveryKeys!) {
            await keyManager.saveRecoveryKey(key.id, key.toRawJson());
          }
        }

        /// save master password details
        ///
        final status = await keyManager.saveMasterPassword(
            newKeyMaterial,
        );

        /// TODO: save secret salt if imported backup
        ///
        // final statusSalt =
        await keyManager.saveSalt(
          vault.id,
          salt,
        );
        // print("save Secret Salt: $statusSalt");

        if (status) {
          /// re-save log key in-case we needed to create a new one
          await keyManager.saveLogKey(cryptor.logKeyMaterial);

          /// re-read and refresh our variables
          await keyManager.readEncryptedKey();

          await fileManager.clearTempVaultFile();

          /// TODO: dont create local when restoring cloud
          // final backupDocumentFile =
          // await fileManager.writeVaultData(backupItem!.toRawJson());

          // if (backupDocumentFile != null) {
          //   logManager.logger.d("create backup vault file: $backupDocumentFile");
          // }
        }
        logManager.logger.d("BackupManager - restoreBackupItem - $status");

        return status;
      }

      logManager.logger.w("BackupManager - restoreBackupItem - Failure");
      return false;
    } catch (e) {
      // print(e);
      logManager.logger.w("BackupManager - restoreBackupItem - Exception: $e");

      logManager.log("BackupManager", "restoreBackupItem", "$e");
      return false;
    }
  }

  Future<bool> restoreLocalBackupItem(
      VaultItem localVault, String password, String salt) async {
    /// first must check password before restoring
    // final keyManager = KeychainManager();
    // final cryptor = Cryptor();

    logManager.logger.d("restoreLocalBackupItem:\nvaultId: ${localVault.id}:\ndeviceId: ${localVault.deviceId}\n"
        "name: ${localVault.name}");
    logManager.log(
        "BackupManager", "restoreLocalBackupItem", "id: ${localVault.id}");
    logManager.logger.d("restoreLocalBackupItem:\neKey: ${localVault.encryptedKey.toJson()}:\n"
        "mdate: ${localVault.mdate}\ncdate: ${localVault.cdate}");

    try {
      // if (!keyManager.salt.isEmpty) {
        final prepareStatus = await _prepareToRestore();
        if (!prepareStatus) {
          logManager.logger.d("here-prepare");

          return false;
        }
      // }

      final backupHash = cryptor.sha256(localVault.toRawJson());
      logManager.log("BackupManager", "restoreLocalBackupItem",
          "backup hash: $backupHash");

      final ek = localVault.encryptedKey;
      final keyMaterial = ek.keyMaterial;

      final result = await cryptor.deriveKeyCheckAgainst(
        password,
        ek.rounds,
        salt,
        keyMaterial,
      );

      logManager.logger.d('deriveKeyCheckAgainst result: $result');
      logManager.logger.d('password: ${password}\nek.rounds: ${ek.rounds}\nsalt:$salt\nkeyMaterial: ${keyMaterial}');

      if (result) {
        logManager.logger.d("here!! result good");

        KeyMaterial newKeyMaterial = KeyMaterial(
          id: localVault.id,
          salt: salt,
          rounds: ek.rounds,
          key: keyMaterial,
          hint: "",
        );

        /// delete keys
        ///
        var encryptedBlob = localVault.blob;

        final idString =
            "${localVault.id}-${localVault.deviceId}-${localVault.version}-${localVault.cdate}-${localVault.mdate}-${localVault.name}";
        logManager.logger.d("decryption: ${idString}");


        final decryptedBlob = await cryptor.decryptBackupVault(encryptedBlob, idString);
        logManager.logger.d("decryption: ${decryptedBlob.length}");

        if (testFail1) {
          logManager.logger.d("here1");
          responseStatusCode = 1;
          backupErrorMessage = "Backup Restore Failed: Blob Decryption";
          return await _recoverVault();
        }

        if (decryptedBlob.isNotEmpty) {
          logManager.logger.d("here-decryptedBlob no empty");

          /// since our decryption is valid we can now delete local keys to re-save

          // logManager.logger.d("decryption successfull: $decryptedBlob");

          /// TODO: add this in
          /// TODO: change this to GenericItemList after conversion
          ///
          var genericItems;
          try {
            genericItems = GenericItemList.fromRawJson(decryptedBlob);
            logManager.logger.d("GenericItemList protocol");


            if (genericItems != null) {
              // await keyManager.deleteForBackup();

              final encryptedKeyNonce = localVault.encryptedKey.keyNonce;
              logManager.logger.d("encryptedKeyNonce: ${encryptedKeyNonce}");

              final decryptedKeyNonce = await cryptor.decrypt(encryptedKeyNonce);//.then((value) {
                // final decryptedKeyNonce = value;
                logManager.logger.d("decryptedKeyNonce: ${decryptedKeyNonce}\n"
                    "base64decoded keyNonce: ${hex.decode(decryptedKeyNonce)}");

                final keyNonce = hex.decode(decryptedKeyNonce);
                final ablock = keyNonce.sublist(8, 12);
                final bblock = keyNonce.sublist(12, 16);

                // logManager.logger.d("ablock: ${ablock}\n"
                //     "bblock: ${bblock}");

                final rolloverBlockCount = int.parse(hex.encode(ablock), radix: 16);
                final encryptedBlockCount = int.parse(hex.encode(bblock), radix: 16);
                logManager.logger.d("encryptedBlockCount: ${encryptedBlockCount}\n"
                    "rolloverBlockCount: ${rolloverBlockCount}");
              // });

              if (encryptedBlockCount != null) {
                await settingsManager.saveNumBytesEncrypted(
                  encryptedBlockCount * 16,
                );

                await settingsManager.saveNumBlocksEncrypted(
                    encryptedBlockCount);
              }

              if (rolloverBlockCount != null) {
                await settingsManager.saveEncryptionRolloverCount(
                  rolloverBlockCount,
                );
              }

              await keyManager.deleteForBackup();

              // if (false) {
              //   /// Version 1 -----------------------------------------------------
              //   if (localVault.encryptedKey.blocksEncrypted != null) {
              //     final numBlocksEncrypted = localVault.encryptedKey
              //         .blocksEncrypted;
              //     if (numBlocksEncrypted != null) {
              //       await settingsManager.saveNumBytesEncrypted(
              //         numBlocksEncrypted * 16,
              //       );
              //
              //       await settingsManager.saveNumBlocksEncrypted(
              //           numBlocksEncrypted);
              //     }
              //   }
              //
              //   if (localVault.encryptedKey.blockRolloverCount != null) {
              //     final blockRolloverCount = localVault.encryptedKey
              //         .blockRolloverCount;
              //     if (blockRolloverCount != null) {
              //       await settingsManager.saveEncryptionRolloverCount(
              //         blockRolloverCount,
              //       );
              //     }
              //   }
              //
              //
              //   /// Version 1 -----------------------------------------------------
              // }
            } else {
              logManager.logger.d("here-fail3");

              backupErrorMessage = "Backup Restore Failed: Generic Object Decoding 2";
              responseStatusCode = 1;
              logManager.logger.d("object could not be decoded");
              return await _recoverVault();
            }
          } catch(e) {
            logManager.logger.d("here-Esxception: $e");

            backupErrorMessage = "Backup Restore Failed: Generic Object Decoding";
            responseStatusCode = 1;
            logManager.logger.d("object could not be:$e");
            return await _recoverVault();
          }

          // print("jbird: ${genericItems2.list}");
          if (genericItems.list.isNotEmpty) {
            // logManager.logger.d("try genericItems2 iteration");

            // genericItems2.list.sort((a, b) {
            //   return b.data.compareTo(a.data);
            // });

            /// Go through each GenericItem
            for (var genericItem in genericItems.list) {
              var itemId = "";
              if (genericItem.type == "password") {
                // logManager.logger.d("try password");

                final passwordItem = PasswordItem.fromRawJson(genericItem.data);
                itemId = passwordItem.id;
              } else if (genericItem.type == "note") {
                // logManager.logger.d("try note");

                final noteItem = NoteItem.fromRawJson(genericItem.data);
                itemId = noteItem.id;
              } else if (genericItem.type == "key") {
                // logManager.logger.d("try key");

                final keyItem = KeyItem.fromRawJson(genericItem.data);
                itemId = keyItem.id;
              }
              final genericItemString = genericItem.toRawJson();

              if (itemId.isEmpty) {
                logManager.logger.d("BackupManager: itemId is EMPTY!!");
                continue;
              }

              /// save generic item
              final status = await keyManager.saveItem(itemId, genericItemString);
              if (testFail2) {
                logManager.logger.d("here2");
                responseStatusCode = 1;
                backupErrorMessage = "Backup Restore Failed: Saving Vault Item";
                return await _recoverVault();
              }

              if (!status) {
                logManager.logger.d("here2");
                await keyManager.deleteAllItems();
                responseStatusCode = 1;
                backupErrorMessage = "Backup Restore Failed: Saving Vault Item";
                /// TODO: revert back
                return await _recoverVault();
              }
            }
          }
          logManager.logger.d("here-fallthrough4");

        } else if (localVault.numItems > 0) {
          // logManager.logger.d("here-decryptedBlob no empty");

          responseStatusCode = 1;
          backupErrorMessage = "Backup Restore Failed: Blob is Empty/Decryption";

          logManager.logger.d("object could not be decoded2");
          return await _recoverVault();
        }

        // logManager.logger.d("try myIdentity");


        /// save my identity
        ///
        if (localVault.myIdentity != null) {
          logManager.logger.d("here-restore myIdentity");

          final myId = localVault.myIdentity as MyDigitalIdentity;
          final status = await keyManager.saveMyIdentity(localVault.id, myId.toRawJson());
          if (testFail3) {
            logManager.logger.d("here-restore myIdentity 1");

            responseStatusCode = 1;
            backupErrorMessage = "Backup Restore Failed: Saving My Digital Identity";
            return await _recoverVault();
          }
          if (!status) {
            logManager.logger.d("here-restore myIdentity 2");

            await keyManager.deleteAllItems();
            responseStatusCode = 1;
            backupErrorMessage = "Backup Restore Failed: Saving My Digital Identity";
            /// TODO: revert back
            return await _recoverVault();
          }
        }

        // logManager.logger.d("try identities");


        /// save identities
        ///
        if (localVault.identities != null) {
          logManager.logger.d("here-restore identities");

          for (var id in localVault.identities!) {
            final status = await keyManager.saveIdentity(id.id, id.toRawJson());
            if (testFail4) {
              logManager.logger.d("here-restore identities 4");

              responseStatusCode = 1;
              await keyManager.deleteAllItems();
              keyManager.deleteMyDigitalIdentity();
              await keyManager.deleteAllPeerIdentities();
              backupErrorMessage = "Backup Restore Failed: Saving Identity";
              return await _recoverVault();
            }
            if (!status) {
              logManager.logger.d("here-restore identities 4b");

              await keyManager.deleteAllItems();
              await keyManager.deleteMyDigitalIdentity();
              await keyManager.deleteAllPeerIdentities();

              responseStatusCode = 1;
              backupErrorMessage = "Backup Restore Failed: Saving Identity";
              /// TODO: revert back
              return await _recoverVault();
            }
          }
        }

        // logManager.logger.d("try recovery keys");

        /// save recovery keys
        ///
        if (localVault.recoveryKeys != null) {
          logManager.logger.d("here-restore recoveryKeys");

          for (var key in localVault.recoveryKeys!) {
            final status = await keyManager.saveRecoveryKey(key.id, key.toRawJson());
            if (testFail5) {
              logManager.logger.d("here-restore recoveryKeys - 5");

              responseStatusCode = 1;
              await keyManager.deleteAllItems();
              await keyManager.deleteMyDigitalIdentity();
              await keyManager.deleteAllPeerIdentities();
              await keyManager.deleteAllRecoveryKeys();

              backupErrorMessage = "Backup Restore Failed: Saving Recovery Key";
              return await _recoverVault();
            }
            if (!status) {
              logManager.logger.d("here-restore recoveryKeys - 5a");

              responseStatusCode = 1;
              await keyManager.deleteAllItems();
              await keyManager.deleteMyDigitalIdentity();
              await keyManager.deleteAllPeerIdentities();
              await keyManager.deleteAllRecoveryKeys();

              backupErrorMessage = "Backup Restore Failed: Saving Recovery Key";
              /// TODO: revert back
              return await _recoverVault();
            }
          }
        }


        /// save master password details
        ///
        final status = await keyManager.saveMasterPassword(
            newKeyMaterial,
        );
        logManager.logger.d("here-restore saveMasterPassword: $status");

        if (testFail6) {
          logManager.logger.d("here-restore saveMasterPassword: fail 6");

          await keyManager.deleteAllItems();
          await keyManager.deleteMyDigitalIdentity();
          await keyManager.deleteAllPeerIdentities();
          await keyManager.deleteAllRecoveryKeys();

          backupErrorMessage = "Backup Restore Failed: Saving Master Password";
          responseStatusCode = 1;
          return await _recoverVault();
        }

        if (!status) {
          logManager.logger.d("here-restore saveMasterPassword: fail 6a");

          await keyManager.deleteAllItems();
          await keyManager.deleteMyDigitalIdentity();
          await keyManager.deleteAllPeerIdentities();
          await keyManager.deleteAllRecoveryKeys();

          backupErrorMessage = "Backup Restore Failed: Saving Master Password";
          /// TODO: revert back
          responseStatusCode = 1;
          return await _recoverVault();
        }

        /// TODO: save secret salt if imported backup
        ///
        // final thisDeviceId = await deviceManager.getDeviceId();
        // final statusSalt =
        await keyManager.saveSalt(
          localVault.id,
          salt,
        );
        // print("status salt: $statusSalt");

        /// re-save log key in-case we needed to create a new one
        await keyManager.saveLogKey(cryptor.logKeyMaterial);

        /// re-read and refresh our variables
        await keyManager.readEncryptedKey();

        await fileManager.clearTempVaultFile();

        logManager.logger.w("BackupManager - restoreLocalBackupItem - true");
        logManager.logger.d("here-restore restoreLocalBackupItem: true");
        responseStatusCode = 0;

        return true;
      }

      logManager.logger.d("here-restore restoreLocalBackupItem: false: _reExpandCurrentKey");

      await _reExpandCurrentKey();
      responseStatusCode = 1;
      backupErrorMessage = "Backup Restore Failed: Incorrect Password";
      logManager.logger.w("BackupManager - restoreLocalBackupItem - Failure");
      return false; //await _recoverVault();
    } catch (e) {
      // logManager.logger.d("here-restore restoreLocalBackupItem: false: _reExpandCurrentKey");

      // print(e);
      logManager.logger
          .w("BackupManager - restoreLocalBackupItem - Exception: $e");

      logManager.log("BackupManager", "restoreLocalBackupItem", "$e");
      return await _recoverVault();
    }
  }

  Future<bool> restoreLocalBackupItemRecovery(VaultItem localVault) async {
    // final keyManager = KeychainManager();
    // final cryptor = Cryptor();

    logManager.log("BackupManager", "restoreLocalBackupItemRecovery",
        "id: ${localVault.id}");

    try {
      final prepareStatus = await _prepareToRestore();
      if (!prepareStatus) {
        return false;
      }

      final backupHash = Hasher().sha256Hash(localVault.toRawJson());
      logManager.log("BackupManager", "restoreLocalBackupItemRecovery",
          "backup hash: $backupHash");

      final ek = localVault.encryptedKey;
      final keyMaterial = ek.keyMaterial;

      final salt = localVault.encryptedKey.salt;
      var encryptedBlob = localVault.blob;

      final idString =
          "${localVault.id}-${localVault.deviceId}-${localVault.version}-${localVault.cdate}-${localVault.mdate}-${localVault.name}";


      final decryptedBlob = await cryptor.decryptBackupVault(encryptedBlob, idString);

      if (decryptedBlob.isNotEmpty) {
        /// since our decryption is valid we can now delete local keys to re-save
        await keyManager.deleteForBackup();

        if (localVault.encryptedKey != null) {
          /// version 1
          // final keyRollIndex = localVault.encryptedKey.blockRolloverCount;
          // await settingsManager.saveEncryptionRolloverCount(keyRollIndex!);

          /// version 2
          final encryptedKeyNonce = localVault.encryptedKey.keyNonce;
          logManager.logger.d("encryptedKeyNonce: ${encryptedKeyNonce}");

          final decryptedKeyNonce = await cryptor.decrypt(encryptedKeyNonce);
          logManager.logger.d("decryptedKeyNonce: ${decryptedKeyNonce}\n"
              "base64decoded keyNonce: ${hex.decode(decryptedKeyNonce)}");

          final keyNonce = hex.decode(decryptedKeyNonce);
          final ablock = keyNonce.sublist(8, 12);
          final bblock = keyNonce.sublist(12, 16);

          // logManager.logger.d("ablock: ${ablock}\n"
          //     "bblock: ${bblock}");

          final rolloverBlockCount = int.parse(hex.encode(ablock), radix: 16);
          final encryptedBlockCount = int.parse(hex.encode(bblock), radix: 16);
          logManager.logger.d("encryptedBlockCount: ${encryptedBlockCount}\n"
              "rolloverBlockCount: ${rolloverBlockCount}");
          // });

          if (encryptedBlockCount != null) {
            await settingsManager.saveNumBytesEncrypted(
              encryptedBlockCount * 16,
            );

            await settingsManager.saveNumBlocksEncrypted(
                encryptedBlockCount);
          }

          if (rolloverBlockCount != null) {
            await settingsManager.saveEncryptionRolloverCount(
              rolloverBlockCount,
            );
          }
        }
        // print("decryption successfull");

        /// TODO: add this in
        ///
        var genericItems = GenericItemList.fromRawJson(decryptedBlob);
          logManager.logger.e("GenericItemList protocol");


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
              logManager.logger.d("BackupManager: itemId is EMPTY!!");
              continue;
            }

            /// save generic item
            final status = await keyManager.saveItem(itemId, genericItemString);
            // logManager.logger.d("BackupManager - saveItem - status: $status");
            if (!status) {
              /// TODO: revert back
              return await _recoverVault();
            }
          }
        }
      } else {
        logManager.logger.d("could not decrypt blob");
        return await _recoverVault();
      }

      /// save my identity
      ///
      if (localVault.myIdentity != null) {
        final myId = localVault.myIdentity as MyDigitalIdentity;

        final status = await keyManager.saveMyIdentity(localVault.id, myId.toRawJson());
        if (!status) {
          /// TODO: revert back
          return await _recoverVault();
        }
      }

      /// save identities
      ///
      if (localVault.identities != null) {
        for (var id in localVault.identities!) {
          final status = await keyManager.saveIdentity(id.id, id.toRawJson());
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
          final status = await keyManager.saveRecoveryKey(key.id, key.toRawJson());
          if (!status) {
            /// TODO: revert back
            return await _recoverVault();
          }
        }
      }

      KeyMaterial newKeyMaterial = KeyMaterial(
        id: localVault.id,
        salt: salt!,
        rounds: ek.rounds,
        key: keyMaterial,
        hint: "",
      );

      /// save master password details
      ///
      if (salt != null) {
        final status = await keyManager.saveMasterPassword(
            newKeyMaterial,
        );

        if (!status) {
          /// TODO: revert back
          return await _recoverVault();
        }


        // final thisDeviceId = await deviceManager.getDeviceId();
        if (status) {
          final statusSalt = await keyManager.saveSalt(
            localVault.id,
            salt,
          );

          // print("status salt: $statusSalt");

          /// re-save log key in-case we needed to create a new one
          await keyManager.saveLogKey(cryptor.logKeyMaterial);

          /// re-read and refresh our variables
          await keyManager.readEncryptedKey();

          // final backupDocumentFile =
          // await fileManager.writeVaultData(backupItem!.toRawJson());

          // if (backupDocumentFile != null) {
          //   logManager.logger.d("create backup vault file: $backupDocumentFile");
          // }
        }

        return status;
      } else {
        return await _recoverVault();
      }

      logManager.logger.w("BackupManager - restoreLocalBackupItem - Failure");
      return false;
    } catch (e) {
      logManager.logger
          .w("BackupManager - restoreLocalBackupItem - Exception: $e");

      logManager.log("BackupManager", "restoreLocalBackupItem", "$e");
      return await _recoverVault();
    }
  }


  /// RECOVERY SERVICE - In Case of Failure
  ///
  ///

  Future<VaultItem?> _backupCurrentVaultState() async {
    logManager.logger.d("_backupCurrentVaultState");

    /// create EncryptedKey object
    final salt = keyManager.salt;
    final kdfAlgo = EnumToString.convertToString(KDFAlgorithm.pbkdf2_512);
    final rounds = cryptor.rounds;
    final type = 0;
    final version = 1;
    final memoryPowerOf2 = 0;
    final encryptionAlgo = EnumToString.convertToString(EncryptionAlgorithm.aes_ctr_256);
    final keyMaterial = keyManager.encryptedKeyMaterial;

    // var items = await keyManager.getAllItemsForBackup() as GenericItemList;
    var items = await _getKeychainGenericItemListState();

    _currentItemList = items;

    /// TODO: Digital ID
    final myId = await keyManager.getMyDigitalIdentity();
    // _currentMyDigitalIdentity = myId; // await keyManager.getMyDigitalIdentity();

    final deviceId = await deviceManager.getDeviceId();
    if (deviceId == null) {
      return null;
    }

    final timestamp = DateTime.now().toIso8601String();
    final backupName = "temp-vault";

    final appVersion = settingsManager.versionAndBuildNumber();//"v" + AppConstants.appVersion + " (${AppConstants.appBuildNumber})";
    // final uuid = cryptor.getUUID();
    final vaultId = keyManager.vaultId;

    final idString =
        "${vaultId}-${deviceId}-${appVersion}-${timestamp}-${timestamp}-${backupName}";
    // final idHash = Hasher().sha256Hash(idString);
    // print("idHash: $idHash");

    var testItems = json.encode(items);

    var encryptedBlob = await cryptor.encryptBackupVault(testItems, idString);
    settingsManager.doEncryption(utf8.encode(testItems).length);


    final keyNonce = _convertEncryptedBlocksNonce();
    logManager.logger.d("keyNonce: ${keyNonce.length}: ${keyNonce}\n"
        "keyNonce utf8: ${utf8.encode(keyNonce).length}: ${utf8.encode(keyNonce)}");

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
      // blocksEncrypted: settingsManager.numBlocksEncrypted,
      // blockRolloverCount: settingsManager.numRolloverEncryptionCounts,
    );


    final identities = await keyManager.getIdentities();
    // _currentIdentites = identities;

    final recoveryKeys = await keyManager.getRecoveryKeyItems();
    // _currentRecoveryKeys = recoveryKeys;

    final deviceDataString = settingsManager.deviceManager.deviceData.toString();
    logManager.logger.d("deviceDataString: $deviceDataString");
    // logManager.logger.d("deviceData[utsname.version:]: ${settingsManager.deviceManager.deviceData["utsname.version:"]}");

    settingsManager.doEncryption(utf8.encode(deviceDataString).length);
    final encryptedDeviceData = await cryptor.encrypt(deviceDataString);
    logManager.logger.d("encryptedDeviceData: $encryptedDeviceData");


    final backupItem = VaultItem(
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
    );

    // print("passwordItems: $passwordItems");
    // print("genericItems: $items");

    // print("backupItemJson: ${backupItem.toRawJson().length}: ${backupItem.toRawJson()}");
    _currentDeviceVault = backupItem;

    return backupItem;
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
    // logManager.logger.d("aindex: $aindex");

    if (aindex.length % 2 == 1) {
      aindex = "0" + aindex;
    }

    final abytes = hex.decode(aindex);
    final blockNonceABytes = zeroBlock.sublist(0, 4 - abytes.length) +
        abytes;

    var bindex = int.parse("${numBlocks}").toRadixString(16);
    // logManager.logger.d("bindex: $bindex");

    if (bindex.length % 2 == 1) {
      bindex = "0" + bindex;
    }

    final bbytes = hex.decode(bindex);
    final blockNonceBBytes = zeroBlock.sublist(0, 4 - bbytes.length) +
        bbytes;

    // logManager.logger.d("blockNonceBBytes: ${blockNonceBBytes.length}: ${hex.encode(
    //     blockNonceBBytes)}");

    /// form nonce based on message index
    final countingNonce = blockNonceABytes + blockNonceBBytes;
    // logManager.logger.d("countingNonce: ${countingNonce.length}: ${hex.encode(
    //     countingNonce)}");

    final currentNonce = zeroBlock.sublist(0, 16-countingNonce.length) + countingNonce;
    // logManager.logger.d("currentNonce: ${currentNonce.length}: ${hex.encode(
    //     currentNonce)}");


    return hex.encode(currentNonce);
  }


  Future<GenericItemList> _getKeychainGenericItemListState() async {
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
    // final itree = await localGenericItemList.calculateMerkleTree();
    finalGenericItemList = GenericItemList(list: list);


    return finalGenericItemList;
  }

  Future<bool> _recoverVault() async {
    logManager.logger.w("_recoverVault in action");

    if (_currentDeviceVault == null) {
      await _reExpandCurrentKey();
      responseStatusCode = 2;
      logManager.logger.w("_currentDeviceVault == null");
      return false;
    }

    try {
      await _reExpandCurrentKey();

      final status2 = await _resaveAllOriginalItems();

      final status3 = await _resaveAllOriginalIdentities();
      final status4 = await _resaveAllOriginalRecoveryKeys();

      logManager.logger.d(
          "status2: $status2, status3: $status3, status4: $status4");

      final vaultId = (_currentDeviceVault?.id)!;
      final keyMaterial = (_currentDeviceVault?.encryptedKey.keyMaterial)!;
      final nrounds = (_currentDeviceVault?.encryptedKey.rounds)!;

      // await _reExpandCurrentKey();
      final encodedSalt = (_currentDeviceVault?.encryptedKey.salt)!;
      //
      // cryptor.setSecretSaltBytes(base64.decode(encodedSalt));
      //
      // if (_tempRootKey != null) {
      //
      //   await cryptor.expandSecretRootKey(_tempRootKey!);
      // }

      KeyMaterial newKeyMaterial = KeyMaterial(
        id: vaultId,
        salt: encodedSalt,
        rounds: nrounds,
        key: keyMaterial,
        hint: tempHint,
      );

      /// TODO: re-save master password key data
      ///
      final statusMaster = await keyManager.saveMasterPassword(
        newKeyMaterial,
      );

      // logManager.logger.d("statusMaster: $statusMaster");

      // if (status) {
      /// save our salt
      final statusSalt = await keyManager.saveSalt(
        vaultId,
        base64.encode(cryptor.salt!),
      );
      // logManager.logger.d("statusSalt: $statusSalt");

      final statusFinal = await keyManager.readEncryptedKey();

      logManager.logger.d("statusMaster: $statusMaster\n"
          "statusSalt: $statusSalt\nstatusFinal: $statusFinal");

      final isAllValid = (status2 && status3 && status4
          && statusSalt && statusFinal && statusMaster);
      responseStatusCode = isAllValid ? 0 : 2;


      return status2 && status3 && status4 && statusSalt && statusFinal &&
          statusMaster;
    } catch (e) {
      logManager.logger.w("_recoverVault failure: $e");
      return false;
    }
  }

  Future<void> _reExpandCurrentKey() async {
    final encodedSalt = (_currentDeviceVault?.encryptedKey.salt)!;

    cryptor.setSecretSaltBytes(base64.decode(encodedSalt));

    if (_tempRootKey != null) {
      await cryptor.expandSecretRootKey(_tempRootKey!);
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
          final status = await keyManager.saveItem(passwordItem.id, item.toRawJson());
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
          final status = await keyManager.saveItem(noteItem.id, item.toRawJson());
          if (!status) {
            return false;
          }
        } else {
          return false;
        }
      } else if (item.type == "key") {
        var keyItem = KeyItem.fromRawJson(item.data);
        if (keyItem != null) {
          final status = await keyManager.saveItem(keyItem.id, item.toRawJson());
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
      final statusMyId = await keyManager.saveMyIdentity(
        keyManager.vaultId,
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
        final statusId = await keyManager.saveIdentity(
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
        final status = await keyManager.saveRecoveryKey(
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
