import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:enum_to_string/enum_to_string.dart';

import '../helpers/AppConstants.dart';
import '../models/DigitalIdentity.dart';
import '../models/KeyItem.dart';
import '../models/MyDigitalIdentity.dart';
import '../models/VaultItem.dart';
import '../models/PasswordItem.dart';
import '../models/NoteItem.dart';
import '../models/GenericItem.dart';
import 'DeviceManager.dart';
import 'KeychainManager.dart';
import 'Cryptor.dart';
import 'LogManager.dart';
import 'SettingsManager.dart';
import 'FileManager.dart';


class KeyScheduler {
  static final KeyScheduler _shared = KeyScheduler._internal();

  factory KeyScheduler() {
    return _shared;
  }

  VaultItem? _currentDeviceVault;
  EncryptedKey? _currentEncryptedKey;
  GenericItemList? _currentItemList;
  GenericItemList? _reKeyedItemList;

  MyDigitalIdentity? _currentMyDigitalIdentity;
  MyDigitalIdentity? _reKeyedMyDigitalIdentity;

  List<DigitalIdentity>? _currentIdentites;
  List<DigitalIdentity> _reKeyedIdentities = [];

  List<PreviousRootKey> _previousRootKeys = [];

  List<RecoveryKey>? _currentRecoveryKeys;   // different re-key function
  List<RecoveryKey> _reKeyedRecoveryKeys = [];


  String _mainPrivExchangeKeySeed = "";

  final _logManager = LogManager();
  final _settingsManager = SettingsManager();
  final _fileManager = FileManager();
  final _deviceManager = DeviceManager();
  final _keyManager = KeychainManager();
  final _cryptor = Cryptor();

  KeyScheduler._internal();


  Future<bool> startReKeyService(String password) async {

    final status = await _reKeyDeviceVault(password);
    _logManager.logger.d("startReKeyService: $status");

    if (!status) {
      /// Recover and re-save temp backup vault into keychain
      ///

      final statusRecover = await _recoverVault();
      _logManager.logger.d("🔐🔑statusRecover Vault: $statusRecover");

      return statusRecover;
    }

    // delete pin code and biometrics
    //
    await _keyManager.deletePinCode();
    await _keyManager.deleteBiometricKey();



    await _fileManager.clearTempVaultFile();

    _logManager.logger.d("startReKeyService: success!!!!!!!!!!!🔐🔑");

    return true;
  }

  Future<bool> _recoverVault() async {
    if (_currentDeviceVault == null) {
      return false;
    }

    final status2 = await _resaveAllOriginalItems();

    final status3 = await _resaveAllOriginalIdentities();
    final status4 = await _resaveAllOriginalRecoveryKeys();

    _logManager.logger.d("status2: $status2, status3: $status3, status4: $status4");

    /// TODO: shouldnt have to re-save master password key data
    ///


    return status2 && status3 && status4;
  }


  Future<bool> _reKeyDeviceVault(String password) async {
    _logManager.log("KeyScheduler", "reKeyDeviceVault", "hello");

    // /// First - check current password
    // final status = await _cryptor.deriveKeyCheck(password, _keyManager.salt);
    // _logManager.logger.d("deriveKeyCheck: $status: salt(now): ${_keyManager.salt}");

    /// Second - backup current vault to temp file
    final tempVaultItem = await _getCurrentVaultBackup();


    if (tempVaultItem == null) {
      return false;
    }

    _currentDeviceVault = tempVaultItem;
    _currentEncryptedKey = tempVaultItem.encryptedKey;

    final tempBackupItemString = tempVaultItem.toRawJson();
    // _logManager.logger.d("tempBackupItemString: $tempBackupItemString");

    /// write to temp file
    try {
      // final status =
      await _fileManager.writeTempVaultData(tempBackupItemString);
    } catch(e) {
      return false;
    }


    var kid = _cryptor.getUUID();
    _keyManager.setNewReKeyId(kid);

    /// Third - derive new key to re-key
    final newEncryptedKey = await _cryptor.deriveNewKeySchedule(password, kid);
    // _logManager.logger.d("newEncryptedKey: $newEncryptedKey");

    if (newEncryptedKey == null) {
      return false;
    }

    /// re-key Items (Passwords, Notes, Keys)
    ///
    ///

    final statusReKeyList = await reKeyItemList();
    _logManager.logger.d("statusReKeyItemList: $statusReKeyList");

    if (!statusReKeyList) {
      return false;
    }

    final statusReKeyMyId = await _reKeyMyDigitalId();
    _logManager.logger.d("statusReKeyMyDigitalId: $statusReKeyMyId");

    if (!statusReKeyMyId) {
      return false;
    }

    /// re-key everything outside of items
    ///
    ///

    final statusReKeyIds = await _reKeyIdentities();
    _logManager.logger.d("statusReKeyIds: $statusReKeyIds");

    if (!statusReKeyIds) {
      return false;
    }



    /// Resave all our generic items into the keychain
    final statusReSaveAllItems = await _resaveAllReKeyedItems();
    _logManager.logger.d("statusReSaveAllItems: $statusReSaveAllItems");

    if (!statusReSaveAllItems) {
      return false;
    }


    /// Resave MyDigitalIdentity
    final tempMyRKId = _reKeyedMyDigitalIdentity;
    if (tempMyRKId == null) {
      return false;
    }

    final statusId = await _keyManager.saveMyIdentity(
      _keyManager.vaultId,
      tempMyRKId.toRawJson(),
    );
    _logManager.logger.d("_reKeyedMyDigitalIdentity: statusId: $statusId");

    if (!statusId) {
      return false;
    }


    /// save Identities
    ///

    final statusReSaveIds = await _resaveAllReKeyedIdentities();
    _logManager.logger.d("statusReSaveIds: $statusReSaveIds");

    if (!statusReSaveIds) {
      return false;
    }

    /// save recovery keys
    ///

    final statusReSaveRecoveryKeys = await _resaveAllReKeyedRecoveryKeys();
    _logManager.logger.d("statusReSaveRecoveryKeys: $statusReSaveRecoveryKeys");

    if (!statusReSaveRecoveryKeys) {
      return false;
    }


    /// save new master password
    ///

    final vaultId = _keyManager.vaultId;
    final rekeyId = _keyManager.reKeyId;

    final newSalt = newEncryptedKey.salt;
    if (newSalt == null) {
      return false;
    }

    /// TODO: check this function
    // _cryptor.setSecretSaltBytes(base64.decode(newSalt));

    KeyMaterial newKeyParams = KeyMaterial(
      id: vaultId,
      keyId: rekeyId,
      salt: newSalt,
      rounds: newEncryptedKey.rounds,
      key: newEncryptedKey.keyMaterial,
      hint: _keyManager.hint,
    );

    /// save master passwaord key data (NEW ROOT KEY!!)
    ///
    final statusSaveReKeyedMaster = await _keyManager.saveMasterPassword(
        newKeyParams,
    );

    _logManager.logger.d("statusSaveReKeyedMaster: $statusSaveReKeyedMaster");
    if (!statusSaveReKeyedMaster) {
      return false;
    }


    /// Set new KeyId for Vault
    _keyManager.setKeyId(rekeyId);


    /// transition the live AES Keys for app vault session
    _cryptor.switchTempKeysToCurrent();


    /// TODO: do this after we have safe everything
    ///

    /// re-save log key in-case we needed to create a new one
    await _keyManager.saveLogKey(_cryptor.logKeyMaterial);

    /// re-read and refresh our variables
    await _keyManager.readEncryptedKey();

    return true;
  }


  /// Get current keychain and app state into a Backup Item
  Future<VaultItem?> _getCurrentVaultBackup() async {

    /// create EncryptedKey object
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

    final deviceId = await _deviceManager.getDeviceId();

    if (deviceId == null) {
      return null;
    }

    final timestamp = DateTime.now().toIso8601String();
    final backupName = "temp-vault";

    final appVersion = _settingsManager.versionAndBuildNumber();

    final vaultId = _keyManager.vaultId;
    final keyId = _keyManager.keyId;

    var testItems = json.encode(items);


    final idString =
        "${vaultId}-${deviceId}-${appVersion}-${timestamp}-${timestamp}-${backupName}";

    /// create iv
    var nonce = _cryptor.getNewNonce();
    nonce = nonce.sublist(0,12) + [0,0,0,0];

    /// TODO: implement this outside of this function
    _settingsManager.doEncryption(utf8.encode(testItems).length);

    final keyNonce = _convertEncryptedBlocksNonce();
    _logManager.logger.d("keyNonce: ${keyNonce.length}: ${keyNonce}\n"
        "keyNonce utf8: ${utf8.encode(keyNonce).length}: ${utf8.encode(keyNonce)}");

    final encryptedKeyNonce = await _cryptor.encryptWithPadding(keyNonce);
    _logManager.logger.d("encryptedKeyNonce: $encryptedKeyNonce");

    var encryptedBlob = await _cryptor.encryptBackupVault(testItems, nonce, idString);

    final encryptedKey = EncryptedKey(
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
    );

    /// identities
    final identities = await _keyManager.getIdentities();
    _currentIdentites = identities;

    /// Recovery Keys
    final recoveryKeys = await _keyManager.getRecoveryKeyItems();
    final previousRootKeys = await _keyManager.getAllPreviousRootKeys();

    _currentRecoveryKeys = recoveryKeys;

    final deviceDataString = _settingsManager.deviceManager.deviceData.toString();
    // _logManager.logger.d("deviceDataString: $deviceDataString");

    _settingsManager.doEncryption(utf8.encode(deviceDataString).length);
    final encryptedDeviceData = await _cryptor.encryptWithPadding(deviceDataString);
    // _logManager.logger.d("encryptedDeviceData: $encryptedDeviceData");

    final backupItem = VaultItem(
      id: vaultId,
      version: appVersion,
      name: backupName,
      deviceId: deviceId,
      deviceData: encryptedDeviceData,
      encryptedKey: encryptedKey,
      previousKeys: previousRootKeys,
      myIdentity: myId,
      identities: identities,
      recoveryKeys: recoveryKeys,
      numItems: items.list.length,
      blob: encryptedBlob,
      cdate: timestamp,
      mdate: timestamp,
      mac: "",
    );

    final backupMac = await _cryptor.hmac256(backupItem.toRawJson());
    backupItem.mac = base64.encode(hex.decode(backupMac));
    // _logManager.logLongMessage("backupItemJson-long: ${backupItem.toRawJson().length}: ${backupItem.toRawJson()}");

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
    _logManager.logger.d("aindex: $aindex");

    if (aindex.length % 2 == 1) {
      aindex = "0" + aindex;
    }

    final abytes = hex.decode(aindex);
    final blockNonceABytes = zeroBlock.sublist(0, 4 - abytes.length) +
        abytes;

    var bindex = int.parse("${numBlocks}").toRadixString(16);
    _logManager.logger.d("bindex: $bindex");

    if (bindex.length % 2 == 1) {
      bindex = "0" + bindex;
    }

    final bbytes = hex.decode(bindex);
    final blockNonceBBytes = zeroBlock.sublist(0, 4 - bbytes.length) +
        bbytes;

    _logManager.logger.d("blockNonceBBytes: ${blockNonceBBytes.length}: ${hex.encode(
        blockNonceBBytes)}");

    /// form nonce based on message index
    final countingNonce = blockNonceABytes + blockNonceBBytes;
    _logManager.logger.d("countingNonce: ${countingNonce.length}: ${hex.encode(
        countingNonce)}");

    final currentNonce = zeroBlock.sublist(0, 16-countingNonce.length) + countingNonce;
    _logManager.logger.d("currentNonce: ${currentNonce.length}: ${hex.encode(
        currentNonce)}");


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
    final itree = await localGenericItemList.calculateMerkleTree();
    finalGenericItemList = GenericItemList(list: list);

    // _localGenericItemList.list =
    // /// TODO: merkle root
    // _localGenericItemList.calculateMerkleRoot();

    return finalGenericItemList;

  }


  /// REKEYING ---------------------------------------------------------
  ///
  Future<bool> reKeyItemList() async {

    final items = _currentItemList!;
    if (items == null) {
      return false;
    }

    List<dynamic> _reKeyedItems = [];
    _reKeyedItemList = GenericItemList(list: []);


    List<GenericItem> genericList = [];

    // final items = _currentItemList!;
    // iterate through items
    for (var item in items.list) {
      if (item.type == "password") {
        var passwordItem = PasswordItem.fromRawJson(item.data);
        if (passwordItem != null) {
          /// decrypt with current key first
          // final keyIndex = (passwordItem?.keyIndex)!;
          // final decryptedName = await _cryptor.decryptWithPadding((passwordItem.name);
          // final decryptedUsername = await _cryptor.decryptWithPadding((passwordItem.username);

          if (passwordItem.geoLock == null) {
            /// decrypt with current key first
            // final decryptedPassword =
            // await _cryptor.decryptWithPadding((passwordItem.password);
            // _logManager.logger.d("rekey enc: ${passwordItem.name}\nusername: ${passwordItem.username}");

            final name = passwordItem.name;
            final username = passwordItem.username;
            final password = passwordItem.password;
            final notes = passwordItem.notes;

            final reecryptedName = await _cryptor.reKeyEncryption(false, name);
            final reecryptedUsername = await _cryptor.reKeyEncryption(false, username);
            final reecryptedPassword = await _cryptor.reKeyEncryption(false, password);
            final reecryptedNotes = await _cryptor.reKeyEncryption(false, notes);

            // print("reecryptedName enc: ${reecryptedName}\nreecryptedUsername: ${reecryptedUsername}");
            // print("reecryptedPassword enc: ${reecryptedPassword}\n");

            passwordItem.keyId = _keyManager.reKeyId;
            passwordItem.name = reecryptedName;
            passwordItem.username = reecryptedUsername;
            passwordItem.password = reecryptedPassword;
            passwordItem.notes = reecryptedNotes;

            List<PreviousPassword> newPreviousPasswordList = [];
            for (var pp in passwordItem.previousPasswords) {
              var decryptedPreviousPassword = "";
              if (pp.isBip39) {
                final seed = _cryptor.mnemonicToEntropy(pp.password);
                /// Encrypt seed here
                decryptedPreviousPassword = await _cryptor.decryptWithPadding((seed));
              } else {
                /// Encrypt password here
                decryptedPreviousPassword = await _cryptor.decryptWithPadding((pp.password));
              }

              final reecryptedPreviousPassword = await _cryptor.reKeyEncryption(false, decryptedPreviousPassword);
              final newPp = PreviousPassword(
                  password: reecryptedPreviousPassword,
                  isBip39: pp.isBip39,
                  cdate: pp.cdate,
              );

              newPreviousPasswordList.add(newPp);
            }

            passwordItem.previousPasswords = newPreviousPasswordList;

            passwordItem.mac = "";

            /// compute MAC of JSON object with empty mac
            final computedMac = await _cryptor.hmac256(passwordItem.toRawJson());
            final newMac = base64.encode(hex.decode(computedMac));

            /// set object MAC
            passwordItem.mac = newMac;

            _reKeyedItems.add(passwordItem);

            final gitem = GenericItem(type: "password", data: passwordItem.toRawJson());

            genericList.add(gitem);
          } else {
            /// TODO: can't re-key geo encrypted items!!!
            ///
            _logManager.logger.w("geo lock needs attention");

            /// note the keyId for the item
            final passwordItemKeyId = passwordItem.keyId;
            _logManager.logger.wtf("passwordItemKeyId: $passwordItemKeyId");

            if (_currentEncryptedKey != null) {
              final rootKeyId = _currentEncryptedKey?.keyId;
              _logManager.logger.wtf("rootKeyId: $rootKeyId");

              if (rootKeyId != null) {
                final prevRootKey = utf8.decode(_cryptor.aesRootSecretKeyBytes);
                final reecryptedPreviousRootKey = await _cryptor.reKeyEncryption(false, prevRootKey);

                PreviousRootKey prk = PreviousRootKey(
                    keyId: rootKeyId, keyData: reecryptedPreviousRootKey);

                /// check to see if we already have the previous root key in list
                var shouldAddRootKey = true;
                for (var tprk in _previousRootKeys) {
                  _logManager.logger.wtf("_previousRootKeys tprk: ${tprk.toRawJson()}");

                  if (tprk.keyId == rootKeyId) {
                    shouldAddRootKey = false;
                    break;
                  }
                }

                /// add previous root key to list if not there
                if (shouldAddRootKey) {
                  _previousRootKeys.add(prk);
                }


                final previousRootKeyString = prk.toRawJson();

                /// save encrypted previous root key object
                final status = await _keyManager.savePreviousRootKey(rootKeyId, previousRootKeyString);

                /// save password with same data (not re-keyed)
                if (status) {
                  final gitem = GenericItem(type: "password", data: passwordItem.toRawJson());

                  genericList.add(gitem);
                }
              } else {
                return false;
              }
            } else {
              return false;
            }
          }

        } else {
          return false;
        }
      } else if (item.type == "note") {
        var noteItem = NoteItem.fromRawJson(item.data);
        if (noteItem != null) {

          // final keyIndex = (noteItem?.keyIndex)!;

          if (noteItem.geoLock == null) {
            final reecryptedName = await _cryptor.reKeyEncryption(false, noteItem.name);
            final reecryptedNote = await _cryptor.reKeyEncryption(false, noteItem.notes);

            noteItem.notes = reecryptedNote;
            noteItem.name = reecryptedName;
            noteItem.keyId = _keyManager.reKeyId;

            noteItem.mac = "";

            /// compute mac of JSON object with empty mac
            final computedMac = await _cryptor.hmac256(noteItem.toRawJson());
            final newMac = base64.encode(hex.decode(computedMac));

            noteItem.mac = newMac;

            _reKeyedItems.add(noteItem);

            final gitem = GenericItem(type: "note", data: noteItem.toRawJson());

            genericList.add(gitem);

          } else {
            _logManager.logger.w("geo lock needs attention");
            return false;
          }

        } else {
          return false;
        }
      } else if (item.type == "key") {
        var keyItem = KeyItem.fromRawJson(item.data);
        if (keyItem != null) {
          final name = keyItem.name;
          final notes = keyItem.notes;

          final privKeyX = keyItem.keys.privX;
          final privKeyS = keyItem.keys.privS;
          final privKeyK = keyItem.keys.privK;

          final reecryptedName = await _cryptor.reKeyEncryption(false, name);
          final reecryptedNotes = await _cryptor.reKeyEncryption(false, notes);
          final reecryptedKeyX = await _cryptor.reKeyEncryption(false, privKeyX!);
          final reecryptedKeyS = await _cryptor.reKeyEncryption(false, privKeyS!);
          final reecryptedKeyK = await _cryptor.reKeyEncryption(false, privKeyK!);

          // final reecryptedKey = await _cryptor.reKeyEncryption(keyItem.);

          keyItem.keyId = _keyManager.reKeyId;
          keyItem.name = reecryptedName;
          keyItem.notes = reecryptedNotes;
          keyItem.keys.privX = reecryptedKeyX;
          keyItem.keys.privS = reecryptedKeyS;
          keyItem.keys.privK = reecryptedKeyK;

          final peerPubs = keyItem.peerPublicKeys;
          List<PeerPublicKey> newPeerPublicKeys = [];
          for (var peerKey in peerPubs) {

              final reecryptedPeerPublicKeyX = await _cryptor.reKeyEncryption(false, peerKey.pubKeyX);
              final reecryptedPeerName = await _cryptor.reKeyEncryption(false, peerKey.name);

              peerKey.name = reecryptedPeerName;
              peerKey.pubKeyX = reecryptedPeerPublicKeyX;

              newPeerPublicKeys.add(peerKey);
          }

          keyItem.peerPublicKeys = newPeerPublicKeys;

          /// add newly keyed keyItem
          _reKeyedItems.add(keyItem);

          final gitem = GenericItem(type: "key", data: keyItem.toRawJson());

          genericList.add(gitem);

        } else {
          return false;
        }
      }
    }

    // final igen = GenericItemList(list: genericList);
    // final tree = await igen.calculateReKeyMerkleTree();

    _reKeyedItemList = GenericItemList(list: genericList);

    return true;
  }

  Future<bool> _reKeyMyDigitalId() async {
    final myDigitalId = await _keyManager.getMyDigitalIdentity();
      // print("value: ${value!.toRawJson()}");

    final timestamp = DateTime.now().toIso8601String();
      // myIdentity = myDigitalId;
      if (myDigitalId != null) {
        _currentMyDigitalIdentity = myDigitalId;
        // var ec = getS256();
        // final algorithm_exchange = X25519();

        // print("value.privateHexS: ${value.privKeySignature}");
        // print("value.privateHexE: ${value.privKeyExchange}");

        /// TODO: fix this
        final privateHexS = await _cryptor.decryptWithPadding(myDigitalId.privKeySignature);
        _mainPrivExchangeKeySeed = await _cryptor.decryptWithPadding(myDigitalId.privKeyExchange);
        // print("privateHexS: $privateHexS");
        // print("pubExchangeKeySeed: $pubExchangeKeySeed");

        // var privS = PrivateKey(ec, BigInt.parse(privateHexS, radix: 16));
        // final privSeedPair = await algorithm_exchange
        //     .newKeyPairFromSeed(hex.decode(_mainPrivExchangeKeySeed));

        // var pubE = await privSeedPair
        //     .extractPublicKey(); // PrivateKey(algorithm_exchange, BigInt.parse(privateHexE,radix: 16));

        /// TODO: fix this
        final reencryptedEKey = await _cryptor.reKeyEncryption(false, myDigitalId.privKeyExchange);
        final reencryptedSKey = await _cryptor.reKeyEncryption(false, myDigitalId.privKeySignature);

        /// TODO: check keyId state
        _reKeyedMyDigitalIdentity = MyDigitalIdentity(
            keyId: _keyManager.reKeyId,
            version: AppConstants.myDigitalIdentityItemVersion,
            privKeyExchange: reencryptedEKey,
            privKeySignature: reencryptedSKey,
            mac: "",
            cdate: myDigitalId.cdate,
            mdate: timestamp,
        );

        if (_reKeyedMyDigitalIdentity != null) {
          final myIdMac = await _cryptor.hmac256(
              _reKeyedMyDigitalIdentity?.toRawJson());
          _reKeyedMyDigitalIdentity?.mac = myIdMac;
        }

        return true;
      }

    return false;
  }


  /// recovery items
  Future<bool> _reKeyIdentities() async {
    _reKeyedIdentities = [];

    final identities = await _keyManager.getIdentities();
    List<String> decryptedKeyExchangePubKey = [];
    List<String> pubKeyFingerprints = [];

    Map<String, String> fingerprintToPubKeyExchangeMap = {};

    try {
      if (identities != null) {
        identities.sort((a, b) {
          return b.cdate.compareTo(a.cdate);
        });
        for (var id in identities) {
          final decryptedName = await _cryptor.decryptWithPadding(id.name);
          final dKeySignature = await _cryptor.decryptWithPadding(id.pubKeySignature);
          final dKeyExchange = await _cryptor.decryptWithPadding(id.pubKeyExchange);

          decryptedKeyExchangePubKey.add(dKeyExchange);
          final phash = _cryptor.sha256(dKeyExchange);

          pubKeyFingerprints.add(phash);
          fingerprintToPubKeyExchangeMap.addAll({phash: dKeyExchange});

          final reencryptedName =  await _cryptor.reKeyEncryption(false, decryptedName);
          final reencryptedX = await _cryptor.reKeyEncryption(false, dKeySignature);
          final reencryptedY = await _cryptor.reKeyEncryption(false, dKeyExchange);

          /// TODO: check this encryption
          final reencryptedKeyId = await _cryptor.reKeyEncryption(false, id.keyId);

          var rekeyedIdentity = DigitalIdentity(
            id: id.id,
            keyId: reencryptedKeyId,
            index: id.index,
            version: AppConstants.digitalIdentityVersion,
            name: reencryptedName,
            pubKeyExchange: reencryptedY,
            pubKeySignature: reencryptedX,
            mac: "",
            cdate: id.cdate,
            mdate: DateTime.now().toIso8601String(),
          );

          final identityMac = await _cryptor.hmac256ReKey(rekeyedIdentity.toRawJson());
          rekeyedIdentity.mac = identityMac;
          // _logManager.logger.d('encryptedKey: ${encryptedKey.toJson()}');

          _reKeyedIdentities.add(rekeyedIdentity);
        }
      }
    } catch (e) {
      _logManager.logger.w("$e");
      return false;
    }
    _logManager.logger.d("pubKeyFingerprints: ${pubKeyFingerprints}");
    _logManager.logger.d("fingerprintKeyMap: ${fingerprintToPubKeyExchangeMap}");
    _logManager.logger.d("peer identity decryptedKeyExchangePubKey: ${decryptedKeyExchangePubKey}");

    final recoveryKeys = await _keyManager.getRecoveryKeyItems();
    // print("recovery items: ${recoveryKeys?.length}: $recoveryKeys");

    if (recoveryKeys != null) {
      for (var rkey in recoveryKeys) {
        final fp = rkey.id;
        if (pubKeyFingerprints.contains(fp)) {
          final identityPubKeyExchange = fingerprintToPubKeyExchangeMap[fp];
          if (identityPubKeyExchange != null) {

            /// Re-Key Recovery Key
            final newRecoveryKey = await _reKeyRecoveryKey(
                _mainPrivExchangeKeySeed,
                identityPubKeyExchange,
                rkey.keyId,
                // rkey.index,
            );

            if (newRecoveryKey != null) {
              _reKeyedRecoveryKeys.add(newRecoveryKey);
            } else {
              return false;
            }
          } else {
            _logManager.logger.e("identityPubKeyExchange == null");
            return false;
          }
        }
      }
    }

    return true;
  }


  /// Used in above _reKeyIdentities() function
  Future<RecoveryKey?> _reKeyRecoveryKey(String privMainSeedExchange, String pubKeyExchange, String keyId) async {
    /// get my identity keys
    ///
    /// get this identity keys
    ///
    /// create secret key
    ///
    /// encrypt with secret key
    ///
    /// save recovery key
    ///
    try {
      final algorithm = X25519();

      // print("pubKeyExchange: $pubKeyExchange");
      final pubBytes = hex.decode(pubKeyExchange);
      // print("pubBytes: $pubBytes");

      final bobPublicKey = SimplePublicKey(pubBytes, type: KeyPairType.x25519);
      // print('bobKeyPair pubMade.Hex: ${hex.encode(bobPublicKey.bytes)}');

      final aliceSeed = privMainSeedExchange;
      final seedBytes = hex.decode(aliceSeed);
      final privSeedPair = await algorithm.newKeyPairFromSeed(seedBytes);

      // We can now calculate a shared secret.
      final sharedSecret = await algorithm.sharedSecretKey(
        keyPair: privSeedPair,
        remotePublicKey: bobPublicKey,
      );
      final sharedSecretBytes = await sharedSecret.extractBytes();
      // print('Shared secret: ${sharedSecretBytes.length}: ${sharedSecretBytes}');

      final secretKeyData = SecretKey(sharedSecretBytes);

      final rootKey = _cryptor
          .tempReKeyRootSecretKeyBytes;

      final encryptedKeys = await _cryptor.encryptRecoveryKey(secretKeyData, rootKey);

      /// TODO: check this encryption
      final encryptedKeyId = await _cryptor.reKeyEncryption(false, keyId);

      final pubKeyHash = _cryptor.sha256(pubKeyExchange);
      // _publicKeyHashes.add(pubKeyHash);

      final recoveryKey = RecoveryKey(
        id: pubKeyHash,
        keyId: encryptedKeyId,
        data: encryptedKeys,
        cdate: DateTime.now().toIso8601String(),
      );

      return recoveryKey;
    } catch (e) {
      _logManager.logger.w("Exception: $e");
      return null;
    }
  }


  /// RESAVING ---------------------------------------------------------
  ///
  ///
  Future<bool> _resaveAllReKeyedItems() async {

    final tempAllGenericItemList = _reKeyedItemList;
    if (tempAllGenericItemList == null) {
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


  Future<bool> _resaveAllReKeyedIdentities() async {

    for (var newId in _reKeyedIdentities) {
      final identityObjectString = newId.toRawJson();
      // print("identityObjectString: $identityObjectString");

      final statusId = await _keyManager.saveIdentity(newId.id, identityObjectString);
      if (!statusId) {
        return false;
      }

    }

    return true;
  }

  Future<bool> _resaveAllReKeyedRecoveryKeys() async {

    for (var newRecoveryKey in _reKeyedRecoveryKeys) {
      // final identityObjectString = newRecoveryKey.toRawJson();

      final status = await _keyManager.saveRecoveryKey(newRecoveryKey.id, newRecoveryKey.toRawJson());

      if (!status) {
        return false;
      }

    }

    return true;
  }


  /// RESAVING ORIGINAL DATA - Recovery
  /// We call this if re-key fails
  ///
  Future<bool> _resaveAllOriginalItems() async {

    final tempAllGenericItemList = _currentItemList;
    if (tempAllGenericItemList == null) {
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

    final origIds = _currentIdentites;
    if (origIds == null) {
      return false;
    }
    for (var id in origIds) {
      final identityObjectString = id.toRawJson();
      // print("identityObjectString: $identityObjectString");

      final statusId = await _keyManager.saveIdentity(id.id, identityObjectString);
      if (!statusId) {
        return false;
      }

    }

    return true;
  }

  Future<bool> _resaveAllOriginalRecoveryKeys() async {
    final origRecoveryKeys  =_currentRecoveryKeys;
    if (origRecoveryKeys == null) {
      return false;
    }

    for (var recoveryKey in origRecoveryKeys) {
      final status = await _keyManager.saveRecoveryKey(recoveryKey.id, recoveryKey.toRawJson());
      if (!status) {
        return false;
      }
    }

    return true;
  }


}