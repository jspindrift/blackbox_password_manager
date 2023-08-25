import 'dart:convert';

import '../helpers/AppConstants.dart';
import '../models/DigitalIdentity.dart';
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:enum_to_string/enum_to_string.dart';

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
  GenericItemList? _currentItemList;
  GenericItemList? _reKeyedItemList;

  MyDigitalIdentity? _currentMyDigitalIdentity;
  MyDigitalIdentity? _reKeyedMyDigitalIdentity;

  List<DigitalIdentity>? _currentIdentites;
  List<DigitalIdentity> _reKeyedIdentities = [];

  List<RecoveryKey>? _currentRecoveryKeys;   // different re-key function
  List<RecoveryKey> _reKeyedRecoveryKeys = [];


  String _mainPrivExchangeKeySeed = "";

  final logManager = LogManager();
  final settingsManager = SettingsManager();
  final fileManager = FileManager();
  final deviceManager = DeviceManager();
  final keyManager = KeychainManager();
  final cryptor = Cryptor();

  KeyScheduler._internal();


  Future<bool> startReKeyService(String password) async {

    final status = await _reKeyDeviceVault(password);
    logManager.logger.d("startReKeyService: $status");

    if (!status) {
      /// Recover and re-save temp backup vault into keychain
      ///

      final statusRecover = await _recoverVault();
      logManager.logger.d("🔐🔑statusRecover Vault: $statusRecover");

      return statusRecover;
    }

    // delete pin code and biometrics
    //
    await keyManager.deletePinCode();
    await keyManager.deleteBiometricKey();



    await fileManager.clearTempVaultFile();

    logManager.logger.d("startReKeyService: success!!!!!!!!!!!🔐🔑");

    return true;
  }

  Future<bool> _recoverVault() async {
    if (_currentDeviceVault == null) {
      return false;
    }

    final status2 = await _resaveAllOriginalItems();

    final status3 = await _resaveAllOriginalIdentities();
    final status4 = await _resaveAllOriginalRecoveryKeys();

    logManager.logger.d("status2: $status2, status3: $status3, status4: $status4");

    /// TODO: shouldnt have to re-save master password key data
    ///


    return status2 && status3 && status4;
  }


  Future<bool> _reKeyDeviceVault(String password) async {
    logManager.log("KeyScheduler", "reKeyDeviceVault", "hello");


    // /// First - check current password
    // final status = await cryptor.deriveKeyCheck(password, keyManager.salt);
    // logManager.logger.d("deriveKeyCheck: $status: salt(now): ${keyManager.salt}");


    /// Second - backup current vault to temp file
    final tempVaultItem = await _getCurrentVaultBackup();


    if (tempVaultItem == null) {
      return false;
    }

    _currentDeviceVault = tempVaultItem;

    final tempBackupItemString = tempVaultItem.toRawJson();
    // logManager.logger.d("tempBackupItemString: $tempBackupItemString");

    /// write to temp file
    try {
      // final status =
      await fileManager.writeTempVaultData(tempBackupItemString);
    } catch(e) {
      return false;
    }




    /// Third - derive new key to re-key
    final newEncryptedKey = await cryptor.deriveNewKeySchedule(password);
    // logManager.logger.d("newEncryptedKey: $newEncryptedKey");

    if (newEncryptedKey == null) {
      return false;
    }

    /// re-key Items (Passwords, Notes, Keys)
    ///
    ///

    final statusReKeyList = await reKeyItemList();
    logManager.logger.d("statusReKeyItemList: $statusReKeyList");

    if (!statusReKeyList) {
      return false;
    }

    final statusReKeyMyId = await _reKeyMyDigitalId();
    logManager.logger.d("statusReKeyMyDigitalId: $statusReKeyMyId");

    if (!statusReKeyMyId) {
      return false;
    }

    /// re-key everything outside of items
    ///
    ///

    final statusReKeyIds = await _reKeyIdentities();
    logManager.logger.d("statusReKeyIds: $statusReKeyIds");

    if (!statusReKeyIds) {
      return false;
    }



    /// Resave all our generic items into the keychain
    final statusReSaveAllItems = await _resaveAllReKeyedItems();
    logManager.logger.d("statusReSaveAllItems: $statusReSaveAllItems");

    if (!statusReSaveAllItems) {
      return false;
    }


    /// Resave MyDigitalIdentity
    final tempMyRKId = _reKeyedMyDigitalIdentity;
    if (tempMyRKId == null) {
      return false;
    }

    final statusId = await keyManager.saveMyIdentity(
      keyManager.vaultId,
      tempMyRKId.toRawJson(),
    );
    logManager.logger.d("_reKeyedMyDigitalIdentity: statusId: $statusId");

    if (!statusId) {
      return false;
    }


    /// save Identities
    ///

    final statusReSaveIds = await _resaveAllReKeyedIdentities();
    logManager.logger.d("statusReSaveIds: $statusReSaveIds");

    if (!statusReSaveIds) {
      return false;
    }

    /// save recovery keys
    ///

    final statusReSaveRecoveryKeys = await _resaveAllReKeyedRecoveryKeys();
    logManager.logger.d("statusReSaveRecoveryKeys: $statusReSaveRecoveryKeys");

    if (!statusReSaveRecoveryKeys) {
      return false;
    }


    /// save new master password
    ///

    final vaultId = keyManager.vaultId;
    final rekeyId = keyManager.rekeyId;

    final newSalt = newEncryptedKey.salt;
    if (newSalt == null) {
      return false;
    }

    /// TODO: check this function
    // cryptor.setSecretSaltBytes(base64.decode(newSalt));

    KeyMaterial newKeyParams = KeyMaterial(
      id: vaultId,
      keyId: rekeyId,
      salt: newSalt,
      rounds: newEncryptedKey.rounds,
      key: newEncryptedKey.keyMaterial,
      hint: keyManager.hint,
    );

    /// save master passwaord key data (NEW ROOT KEY!!)
    ///
    final statusSaveReKeyedMaster = await keyManager.saveMasterPassword(
        newKeyParams,
    );

    logManager.logger.d("statusSaveReKeyedMaster: $statusSaveReKeyedMaster");
    if (!statusSaveReKeyedMaster) {
      return false;
    }


    /// Set new KeyId for Vault
    keyManager.setKeyId(rekeyId);


    /// transition the live AES Keys for app vault session
    cryptor.switchTempKeysToCurrent();


    /// TODO: do this after we have safe everything
    ///

    /// re-save log key in-case we needed to create a new one
    await keyManager.saveLogKey(cryptor.logKeyMaterial);

    /// re-read and refresh our variables
    await keyManager.readEncryptedKey();

    return true;
  }


  /// Get current keychain and app state into a Backup Item
  Future<VaultItem?> _getCurrentVaultBackup() async {

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

    final deviceId = await deviceManager.getDeviceId();

    if (deviceId == null) {
      return null;
    }

    final timestamp = DateTime.now().toIso8601String();
    final backupName = "temp-vault";

    final appVersion = settingsManager.versionAndBuildNumber();

    final vaultId = keyManager.vaultId;
    final keyId = keyManager.keyId;

    final idString =
        "${vaultId}-${deviceId}-${appVersion}-${timestamp}-${timestamp}-${backupName}";

    var testItems = json.encode(items);

    var encryptedBlob = await cryptor.encryptBackupVault(testItems, idString);

    /// TODO: implement this outside of this function
    settingsManager.doEncryption(utf8.encode(testItems).length);
    // cryptor.setTempKeyIndex(keyIndex);
    // logManager.logger.d("keyIndex: $keyIndex");

    final keyNonce = _convertEncryptedBlocksNonce();
    logManager.logger.d("keyNonce: ${keyNonce.length}: ${keyNonce}\n"
        "keyNonce utf8: ${utf8.encode(keyNonce).length}: ${utf8.encode(keyNonce)}");

    final encryptedKeyNonce = await cryptor.encrypt(keyNonce);
    logManager.logger.d("encryptedKeyNonce: $encryptedKeyNonce");


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
      mac: "",
    );

    final keyParamsMac = await cryptor.hmac256(encryptedKey.toRawJson());
    encryptedKey.mac = keyParamsMac;

    /// identities
    final identities = await keyManager.getIdentities();
    _currentIdentites = identities;

    /// Recovery Keys
    final recoveryKeys = await keyManager.getRecoveryKeyItems();

    _currentRecoveryKeys = recoveryKeys;

    final deviceDataString = settingsManager.deviceManager.deviceData.toString();
    // logManager.logger.d("deviceDataString: $deviceDataString");
    // logManager.logger.d("deviceData[utsname.version:]: ${settingsManager.deviceManager.deviceData["utsname.version:"]}");

    settingsManager.doEncryption(utf8.encode(deviceDataString).length);
    final encryptedDeviceData = await cryptor.encrypt(deviceDataString);
    // logManager.logger.d("encryptedDeviceData: $encryptedDeviceData");



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
      mac: "",
    );

    final backupMac = await cryptor.hmac256(backupItem.toRawJson());
    backupItem.mac = backupMac;

    // logManager.logLongMessage("backupItemJson-long: ${backupItem.toRawJson().length}: ${backupItem.toRawJson()}");

    // print("passwordItems: $passwordItems");
    // print("genericItems: $items");

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
    logManager.logger.d("aindex: $aindex");

    if (aindex.length % 2 == 1) {
      aindex = "0" + aindex;
    }

    final abytes = hex.decode(aindex);
    final blockNonceABytes = zeroBlock.sublist(0, 4 - abytes.length) +
        abytes;

    var bindex = int.parse("${numBlocks}").toRadixString(16);
    logManager.logger.d("bindex: $bindex");

    if (bindex.length % 2 == 1) {
      bindex = "0" + bindex;
    }

    final bbytes = hex.decode(bindex);
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
    final itree = await localGenericItemList.calculateMerkleTree();
    finalGenericItemList = GenericItemList(list: list);

    // _localGenericItemList.list =
    // /// TODO: merkle root
    // _localGenericItemList.calculateMerkleRoot();

    return finalGenericItemList;

  }


  /// REKEYING ---------------------------------------------------------
  ///
  ///
  Future<bool> reKeyItemList() async {

    final items = _currentItemList!;
    if (items == null) {
      return false;
    }

    // _allItems = [];
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
          // final decryptedName = await cryptor.decrypt(passwordItem.name);
          // final decryptedUsername = await cryptor.decrypt(passwordItem.username);

          if (passwordItem.geoLock == null) {
            /// decrypt with current key first
            // final decryptedPassword =
            // await cryptor.decrypt(passwordItem.password);
            // logManager.logger.d("rekey enc: ${passwordItem.name}\nusername: ${passwordItem.username}");

            final name = passwordItem.name;
            final username = passwordItem.username;
            final password = passwordItem.password;
            final notes = passwordItem.notes;

            final reecryptedName = await cryptor.reKeyEncryption(false, name);
            final reecryptedUsername = await cryptor.reKeyEncryption(false, username);
            final reecryptedPassword = await cryptor.reKeyEncryption(false, password);
            final reecryptedNotes = await cryptor.reKeyEncryption(false, notes);

            // print("reecryptedName enc: ${reecryptedName}\nreecryptedUsername: ${reecryptedUsername}");
            // print("reecryptedPassword enc: ${reecryptedPassword}\n");

            passwordItem.name = reecryptedName;
            passwordItem.username = reecryptedUsername;
            passwordItem.password = reecryptedPassword;
            passwordItem.notes = reecryptedNotes;

            List<PreviousPassword> newPreviousPasswordList = [];
            for (var pp in passwordItem.previousPasswords) {
              // final x = pp.password;
              final reecryptedPreviousPassword = await cryptor.reKeyEncryption(false, pp.password);
              final newPp = PreviousPassword(
                  password: reecryptedPreviousPassword,
                  isBip39: pp.isBip39,
                cdate: pp.cdate,
              );

              newPreviousPasswordList.add(newPp);
            }

            passwordItem.previousPasswords = newPreviousPasswordList;

            _reKeyedItems.add(passwordItem);

            final gitem = GenericItem(type: "password", data: passwordItem.toRawJson());

            genericList.add(gitem);

          } else {
            logManager.logger.w("geo lock needs attention");
            return false;
          }

        } else {
          return false;
        }
      } else if (item.type == "note") {
        var noteItem = NoteItem.fromRawJson(item.data);
        if (noteItem != null) {

          // final keyIndex = (noteItem?.keyIndex)!;

          if (noteItem.geoLock == null) {
            final reecryptedNote = await cryptor.reKeyEncryption(false, noteItem.notes);
            noteItem.notes = reecryptedNote;

            _reKeyedItems.add(noteItem);

            final gitem = GenericItem(type: "note", data: noteItem.toRawJson());

            genericList.add(gitem);

          } else {
            logManager.logger.w("geo lock needs attention");
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
          final key = keyItem.key;
          final reecryptedName = await cryptor.reKeyEncryption(false, name);
          final reecryptedNotes = await cryptor.reKeyEncryption(false, notes);
          final reecryptedKey = await cryptor.reKeyEncryption(false, key);
          // final reecryptedKey = await cryptor.reKeyEncryption(keyItem.);

          keyItem.name = reecryptedName;
          keyItem.notes = reecryptedNotes;
          keyItem.key = reecryptedKey;

          final peerPubs = keyItem.peerPublicKeys;
          List<PeerPublicKey> newPeerPublicKeys = [];
          for (var peerKey in peerPubs) {

              final reecryptedPeerPublicKey = await cryptor.reKeyEncryption(false, peerKey.key);
              final reecryptedPeerName = await cryptor.reKeyEncryption(false, peerKey.name);

              peerKey.name = reecryptedPeerName;
              peerKey.key = reecryptedPeerPublicKey;

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

    final igen = GenericItemList(list: genericList);
    // final tree = await igen.calculateReKeyMerkleTree();

    _reKeyedItemList = GenericItemList(list: genericList);

    return true;
  }

  Future<bool> _reKeyMyDigitalId() async {
    final myDigitalId = await keyManager.getMyDigitalIdentity();
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
        final privateHexS = await cryptor.decrypt(myDigitalId.privKeySignature);
        _mainPrivExchangeKeySeed = await cryptor.decrypt(myDigitalId.privKeyExchange);
        // print("privateHexS: $privateHexS");
        // print("pubExchangeKeySeed: $pubExchangeKeySeed");

        // var privS = PrivateKey(ec, BigInt.parse(privateHexS, radix: 16));
        // final privSeedPair = await algorithm_exchange
        //     .newKeyPairFromSeed(hex.decode(_mainPrivExchangeKeySeed));

        // var pubE = await privSeedPair
        //     .extractPublicKey(); // PrivateKey(algorithm_exchange, BigInt.parse(privateHexE,radix: 16));

        /// TODO: fix this
        final reencryptedEKey = await cryptor.reKeyEncryption(false, myDigitalId.privKeyExchange);
        final reencryptedSKey = await cryptor.reKeyEncryption(false, myDigitalId.privKeySignature);

        /// TODO: check keyId state
        _reKeyedMyDigitalIdentity = MyDigitalIdentity(
            keyId: keyManager.keyId,
            version: AppConstants.myDigitalIdentityItemVersion,
            privKeyExchange: reencryptedEKey,
            privKeySignature: reencryptedSKey,
            mac: "",
            cdate: myDigitalId.cdate,
            mdate: timestamp,
        );

        if (_reKeyedMyDigitalIdentity != null) {
          final myIdMac = await cryptor.hmac256(
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

    final identities = await keyManager.getIdentities();
    List<String> decryptedKeyExchangePubKey = [];
    List<String> pubKeyFingerprints = [];

    Map<String, String> fingerprintKeyMap = {};

    try {
      if (identities != null) {
        identities.sort((a, b) {
          return b.cdate.compareTo(a.cdate);
        });
        for (var id in identities) {
          /// TODO: fix this
          final x = await cryptor.decrypt(id.pubKeySignature);
          final y = await cryptor.decrypt(id.pubKeyExchange);
          // final z = await cryptor.decrypt(id.intermediateKey);
          decryptedKeyExchangePubKey.add(y);
          final phash = cryptor.sha256(y);
          // print("phash identity: $phash");
          pubKeyFingerprints.add(phash);
          fingerprintKeyMap.addAll({phash: y});

          // final reencryptedName =  await cryptor.reKeyEncryption(id.name);

          final reencryptedX = await cryptor.reKeyEncryption(false,
              id.pubKeySignature);
          final reencryptedY = await cryptor.reKeyEncryption(false, id.pubKeyExchange);
          // final reencryptedZ = await cryptor.reKeyEncryption(false,
          //     id.intermediateKey);

          final timestamp = DateTime.now().toIso8601String();

          var rekeyedIdentity = DigitalIdentity(
            id: id.id,
            keyId: id.keyId,
            index: id.index,
            version: AppConstants.digitalIdentityVersion,
            name: id.name,
            pubKeyExchange: reencryptedY,
            pubKeySignature: reencryptedX,
            mac: "",
            cdate: id.cdate,
            mdate: timestamp,
          );

          final identityMac = await cryptor.hmac256ReKey(rekeyedIdentity.toRawJson());
          rekeyedIdentity.mac = identityMac;
          // logManager.logger.d('encryptedKey: ${encryptedKey.toJson()}');


          _reKeyedIdentities.add(rekeyedIdentity);
        }
        //
        // logManager.logger.d("pubKeyFingerprints: ${pubKeyFingerprints}");
        // logManager.logger.d("fingerprintKeyMap: ${fingerprintKeyMap}");
        // logManager.logger.d("peer identity decryptedKeyExchangePubKey: ${decryptedKeyExchangePubKey}");
      }
    } catch (e) {
      logManager.logger.w("$e");
      return false;
    }
    logManager.logger.d("pubKeyFingerprints: ${pubKeyFingerprints}");
    logManager.logger.d("fingerprintKeyMap: ${fingerprintKeyMap}");
    logManager.logger.d("peer identity decryptedKeyExchangePubKey: ${decryptedKeyExchangePubKey}");

    final recoveryKeys = await keyManager.getRecoveryKeyItems();
    // print("recovery items: ${recoveryKeys?.length}: $recoveryKeys");

    if (recoveryKeys != null) {
      for (var rkey in recoveryKeys) {
        final fp = rkey.id;
        if (pubKeyFingerprints.contains(fp)) {
          final identityPubKeyExchange = fingerprintKeyMap[fp];
          if (identityPubKeyExchange != null) {

            /// Re-Key Recovery Key
            final newRecoveryKey = await _reKeyRecoveryKey(
                _mainPrivExchangeKeySeed,
                identityPubKeyExchange,
                // rkey.index,
            );

            if (newRecoveryKey != null) {
              _reKeyedRecoveryKeys.add(newRecoveryKey);
            } else {
              return false;
            }
          } else {
            print("identityPubKeyExchange == null");
            return false;
          }
        }
      }
    }

    return true;
  }


  /// Used in above _reKeyIdentities() function
  Future<RecoveryKey?> _reKeyRecoveryKey(String privMainSeedExchange, String pubKeyExchange) async {
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
      // print('bobKeyPair pubMade: ${bobPublicKey.bytes}');
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

      final rootKey = cryptor
          .tempReKeyRootSecretKeyBytes;

      final encryptedKeys = await cryptor.encryptRecoveryKey(secretKeyData, rootKey);

      // print("encrypted Keys: $encryptedKeys");

      final pubKeyHash = cryptor.sha256(pubKeyExchange);
      // _publicKeyHashes.add(pubKeyHash);

      final recoveryKey = RecoveryKey(
        id: pubKeyHash,
        data: encryptedKeys,
        cdate: DateTime.now().toIso8601String(),
      );

      // print("recoveryKey: ${recoveryKey.toRawJson()}");

      return recoveryKey;
    } catch (e) {
      logManager.logger.w("Exception: $e");
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


  Future<bool> _resaveAllReKeyedIdentities() async {

    for (var newId in _reKeyedIdentities) {
      final identityObjectString = newId.toRawJson();
      // print("identityObjectString: $identityObjectString");

      final statusId = await keyManager.saveIdentity(newId.id, identityObjectString);
      if (!statusId) {
        return false;
      }

    }

    return true;
  }

  Future<bool> _resaveAllReKeyedRecoveryKeys() async {

    for (var newRecoveryKey in _reKeyedRecoveryKeys) {
      // final identityObjectString = newRecoveryKey.toRawJson();

      final status = await keyManager.saveRecoveryKey(newRecoveryKey.id, newRecoveryKey.toRawJson());

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

    final origIds = _currentIdentites;
    if (origIds == null) {
      return false;
    }
    for (var id in origIds) {
      final identityObjectString = id.toRawJson();
      // print("identityObjectString: $identityObjectString");

      final statusId = await keyManager.saveIdentity(id.id, identityObjectString);
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
      final status = await keyManager.saveRecoveryKey(recoveryKey.id, recoveryKey.toRawJson());
      if (!status) {
        return false;
      }
    }

    return true;
  }


}