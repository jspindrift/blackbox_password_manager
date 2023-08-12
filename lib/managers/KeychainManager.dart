import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import '../models/DigitalIdentity.dart';
import '../models/KeyItem.dart';
import '../models/MyDigitalIdentity.dart';
import '../models/PasswordItem.dart';
import '../models/GenericItem.dart';
import '../models/VaultItem.dart';
import '../models/NoteItem.dart';
import '../managers/SettingsManager.dart';
import '../managers/LogManager.dart';
import '../models/PinCodeItem.dart';
import 'Cryptor.dart';


class SecItem {
  SecItem(this.key, this.value);

  final String key;
  final String value;
}

class KeychainManager {
  var logger = Logger(
    printer: PrettyPrinter(),
  );

  static final KeychainManager _shared = KeychainManager._internal();

  factory KeychainManager() {
    return _shared;
  }

  /// Secure Storage
  final _storage = const FlutterSecureStorage();
  List<SecItem> _keyItems = [];
  Map<String, String> _items = {};

  String _vaultId = "";
  String _encryptedKeyMaterial = '';
  String _salt = '';
  String _encodedLogKeyMaterial = '';
  String _scanCode = '';
  String _hint = '';

  int _passwordItemsSize = 0;
  int _numberOfPreviousPasswords = 0;

  final cryptor = Cryptor();
  final settingsManager = SettingsManager();
  final logManager = LogManager();

  get numberOfPreviousPasswords {
    return _numberOfPreviousPasswords;
  }

  get hint {
    return _hint;
  }

  get numberOfPasswordItems {
    return _items.length;
  }

  get passwordItemsSize {
    return _passwordItemsSize;
  }

  get salt {
    return _salt;
  }

  get scanCode {
    return _scanCode;
  }

  get encryptedKeyMaterial {
    return _encryptedKeyMaterial;
  }

  get vaultId {
    return _vaultId;
  }

  List<int> get decodedKeyMaterial {
    if (_encryptedKeyMaterial.isNotEmpty) {
      return base64.decode(_encryptedKeyMaterial);
    } else {
      return [];
    }
  }

  get encodedLogKeyMaterial {
    return _encodedLogKeyMaterial;
  }

  List<int> get decodedLogKeyMaterial {
    if (_encodedLogKeyMaterial.isNotEmpty) {
      return base64.decode(_encodedLogKeyMaterial);
    } else {
      return [];
    }
  }

  bool get hasPasswordItems {
    return (!_salt.isEmpty && !_encryptedKeyMaterial.isEmpty);
  }

  bool get isAuthenticated {
    return (!cryptor.aesRootSecretKeyBytes.isEmpty);
  }

  bool _isBiometricLoginEnabled = false;

  bool get isBiometricLoginEnabled {
    return _isBiometricLoginEnabled;
  }

  bool _isPinCodeEnabled = false;

  bool get isPinCodeEnabled {
    return _isPinCodeEnabled;
  }

  KeychainManager._internal();

  /// Encryption Key Options for iOS and Android
  ///
  IOSOptions _getIOSOptionsKey() => IOSOptions(
        // groupId: "com.example.blackboxPasswordManager",
        accountName: 'com.blackboxsystems.key',
        synchronizable: false,
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  MacOsOptions _getMacOptionsKey() => MacOsOptions(
        // groupId: '',
        // groupId: 'com.example.blackboxPasswordManager',
        accountName: 'com.blackboxsystems.key',
        synchronizable: false,
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  AndroidOptions _getAndroidOptionsKey() => const AndroidOptions(
        encryptedSharedPreferences: true,
        preferencesKeyPrefix: 'com.blackboxsystems.key',
        sharedPreferencesName: 'keyData',
      );


  /// My Identity Key Options
  ///
  IOSOptions _getIOSOptionsMyIdentity() => IOSOptions(
        accountName: 'com.blackboxsystems.myIdentity',
        synchronizable: false,
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  MacOsOptions _getMacOptionsMyIdentity() => MacOsOptions(
        // groupId: 'com.example.blackboxPasswordManager',
        accountName: 'com.blackboxsystems.myIdentity',
        synchronizable: false,
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  AndroidOptions _getAndroidOptionsMyIdentity() => const AndroidOptions(
        encryptedSharedPreferences: true,
        preferencesKeyPrefix: 'com.blackboxsystems.myIdentity',
        sharedPreferencesName: 'myIdentity',
      );

  /// Social Identity Key Options
  ///
  IOSOptions _getIOSOptionsIdentity() => IOSOptions(
        accountName: 'com.blackboxsystems.identity',
        synchronizable: false,
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  MacOsOptions _getMacOptionsIdentity() => MacOsOptions(
        // groupId: 'com.example.blackboxPasswordManager',
        accountName: 'com.blackboxsystems.identity',
        synchronizable: false,
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  AndroidOptions _getAndroidOptionsIdentity() => const AndroidOptions(
        encryptedSharedPreferences: true,
        preferencesKeyPrefix: 'com.blackboxsystems.identity',
        sharedPreferencesName: 'identity',
      );

  /// Log Key Options
  ///
  IOSOptions _getIOSOptionsLogKey() => IOSOptions(
        accountName: 'com.blackboxsystems.logKey',
        synchronizable: false,
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  MacOsOptions _getMacOptionsLogKey() => MacOsOptions(
        // groupId: 'com.example.blackboxPasswordManager',
        accountName: 'com.blackboxsystems.logKey',
        synchronizable: false,
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  AndroidOptions _getAndroidOptionsLogKey() => const AndroidOptions(
        encryptedSharedPreferences: true,
        preferencesKeyPrefix: 'com.blackboxsystems.logKey',
        sharedPreferencesName: 'logKey',
      );

  /// Biometric Key Options
  ///
  IOSOptions _getIOSOptionsBiometric() => IOSOptions(
        accountName: 'com.blackboxsystems.biometric',
        synchronizable: false,
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  MacOsOptions _getMacOptionsBiometric() => MacOsOptions(
        // groupId: 'com.blackboxsystems',
        accountName: 'com.blackboxsystems.biometric',
        synchronizable: false,
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  AndroidOptions _getAndroidOptionsBiometric() => const AndroidOptions(
        encryptedSharedPreferences: true,
        preferencesKeyPrefix: 'com.blackboxsystems.biometric',
        sharedPreferencesName: 'biometric',
      );


  /// Local Device ID's Key
  ///
  IOSOptions _getIOSOptionsLocalDeviceKey() => IOSOptions(
        accountName: 'com.blackboxsystems.localDevice',
        synchronizable: false,
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  AndroidOptions _getAndroidOptionsLocalDeviceKey() => const AndroidOptions(
        encryptedSharedPreferences: true,
        preferencesKeyPrefix: 'com.blackboxsystems.localDevice',
        sharedPreferencesName: 'localDevice',
      );

  /// Pin Code Key Options
  ///
  IOSOptions _getIOSOptionsPinCode() => IOSOptions(
        accountName: 'com.blackboxsystems.pin',
        synchronizable: false,
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  MacOsOptions _getMacOptionsPinCode() => MacOsOptions(
        // groupId: 'com.blackboxsystems',
        accountName: 'com.blackboxsystems.pin',
        synchronizable: false,
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  AndroidOptions _getAndroidOptionsPinCode() => const AndroidOptions(
        encryptedSharedPreferences: true,
        preferencesKeyPrefix: 'com.blackboxsystems.pin',
        sharedPreferencesName: 'pin',
      );

  /// Recovery Key Options
  /// for social vault recovery
  IOSOptions _getIOSOptionsRecoveryKey() => IOSOptions(
        accountName: 'com.blackboxsystems.recovery',
        synchronizable: false,
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  MacOsOptions _getMacOptionsRecoveryKey() => MacOsOptions(
        // groupId: 'com.blackboxsystems',
        accountName: 'com.blackboxsystems.recovery',
        synchronizable: false,
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  AndroidOptions _getAndroidOptionsRecoveryKey() => const AndroidOptions(
        encryptedSharedPreferences: true,
        preferencesKeyPrefix: 'com.blackboxsystems.recovery',
        sharedPreferencesName: 'recovery',
      );


  /// Password Item Options
  ///
  IOSOptions _getIOSOptionsItem() => IOSOptions(
        accountName: 'com.blackboxsystems.item',
        synchronizable: false,
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  MacOsOptions _getMacOptionsItem() => MacOsOptions(
        // groupId: 'com.blackboxsystems',
        accountName: 'com.blackboxsystems.item',
        synchronizable: false,
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  AndroidOptions _getAndroidOptionsItem() => const AndroidOptions(
        encryptedSharedPreferences: true,
        preferencesKeyPrefix: 'com.blackboxsystems.item',
        sharedPreferencesName: 'item',
      );


  /// save the encrypted key and salt for the master password
  Future<bool> saveMasterPassword(KeyMaterial key) async {
    logger.d("saveMasterPassword");
    try {
      if (Platform.isIOS || Platform.isMacOS) {

        await _storage.write(
          key: "keyMaterial",
          value: key.toRawJson(),
          iOptions: _getIOSOptionsKey(),
          aOptions: _getAndroidOptionsKey(),
          mOptions: _getMacOptionsKey(),
        );

        _salt = key.salt;
        _encryptedKeyMaterial = key.key;
        _vaultId = key.id;
        _hint = key.hint;

        logManager.log("KeychainManager", "saveMasterPassword", "success");
        return true;
      } else if (Platform.isAndroid) {
        /// Found a bug on Android simulator where writing to storage doesn't work
        /// on first try.  Trying to save key twice works...No idea why

        await _storage.write(
          key: "keyMaterial",
          value: key.toRawJson(),
          iOptions: _getIOSOptionsKey(),
          aOptions: _getAndroidOptionsKey(),
          mOptions: _getMacOptionsKey(),
        );

        await _storage.write(
          key: "keyMaterial",
          value: key.toRawJson(),
          iOptions: _getIOSOptionsKey(),
          aOptions: _getAndroidOptionsKey(),
          mOptions: _getMacOptionsKey(),
        );

        _salt = key.salt;
        _encryptedKeyMaterial = key.key;
        _vaultId = key.id;
        _hint = key.hint;

        /// Method for extra caution on invalid saving with Android

        var keyStorage = await _storage.readAll(
          iOptions: _getIOSOptionsKey(),
          aOptions: _getAndroidOptionsKey(),
          mOptions: _getMacOptionsKey(),
        );

        var tries = 0;

        if (keyStorage.entries.length == 0) {
          logger.w("Creating Master Password - write again");

          while (keyStorage.entries.length == 0) {
            await _storage.write(
              key: "keyMaterial",
              value: key.toRawJson(),
              iOptions: _getIOSOptionsKey(),
              aOptions: _getAndroidOptionsKey(),
              mOptions: _getMacOptionsKey(),
            );

            keyStorage = await _storage.readAll(
              iOptions: _getIOSOptionsKey(),
              aOptions: _getAndroidOptionsKey(),
              mOptions: _getMacOptionsKey(),
            );

            tries += 1;

            if (tries > 100) {
              logger.w("EXHAUSTED TRIES CREATING KEY");
              return false;
              // break;
            }
          }

          return true;
        }

        logManager.logger.d("KeychainManager: saveMasterPassword success");
        logManager.log("KeychainManager", "saveMasterPassword", "success");
        return true;
      }

      logManager.log("KeychainManager", "saveMasterPassword", "failure");
      logManager.logger.w("Keychain saveMasterPassword failure");
      return false;
    } catch (e) {
      logManager.log("KeychainManager", "saveMasterPassword", "failure: $e");
      logManager.logger.w("Keychain saveMasterPassword failure: $e");
      return false;
    }
  }

  /// get the encrypted key and salt
  ///
  Future<bool> readEncryptedKey() async {
    logger.d("readEncryptedKey");
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        final key = await _storage.readAll(
          iOptions: _getIOSOptionsKey(),
          aOptions: _getAndroidOptionsKey(),
          mOptions: _getMacOptionsKey(),
        );

        _keyItems = key.entries
            .map((entry) => SecItem(entry.key, entry.value))
            .toList(growable: false);

        for (var element in _keyItems) {
          if (element.key == 'keyMaterial') {
            KeyMaterial keyParams = KeyMaterial.fromRawJson(element.value);
            _encryptedKeyMaterial = keyParams.key;
            _vaultId = keyParams.id;
            _hint = keyParams.hint;
            _salt = keyParams.salt;
            cryptor.setSecretSaltBytes(_salt.codeUnits);
            cryptor.setCurrentKeyMaterial(keyParams);
          }
        }

        if (_encryptedKeyMaterial.isNotEmpty && _salt.isNotEmpty) {
          logManager.log("KeychainManager", "readEncryptedKey", "success");
          return true;
        }

        logManager.log("KeychainManager", "readEncryptedKey", "failure");
        return false;
      } else if (Platform.isAndroid) {

        final key = await _storage.readAll(
          iOptions: _getIOSOptionsKey(),
          aOptions: _getAndroidOptionsKey(),
          mOptions: _getMacOptionsKey(),
        );

        _keyItems = key.entries
            .map((entry) => SecItem(entry.key, entry.value))
            .toList(growable: false);

        if (_keyItems.length == 0) {
          return false;
        }

        for (var element in _keyItems) {
          if (element.key == 'keyMaterial') {
            KeyMaterial keyParams = KeyMaterial.fromRawJson(element.value);
            _encryptedKeyMaterial = keyParams.key;
            _vaultId = keyParams.id;
            _hint = keyParams.hint;
            _salt = keyParams.salt;
            cryptor.setSecretSaltBytes(_salt.codeUnits);
            cryptor.setCurrentKeyMaterial(keyParams);
          }
        }

        if (_encryptedKeyMaterial.isNotEmpty && _salt.isNotEmpty) {
          logManager.log("KeychainManager", "readEncryptedKey", "success");
          logManager.logger.d("Keychain readEncryptedKey success");
          return true;
        }
      }

      logManager.log("KeychainManager", "readEncryptedKey", "failure");
      logManager.logger.d("Keychain readEncryptedKey failure");
      return false;
    } catch (e) {
      logManager.log("KeychainManager", "readEncryptedKey", "failure: $e");
      logManager.logger.w("Keychain readEncryptedKey failure: $e");
      return false;
    }
  }


  /// vault owner's digital identity
  Future<bool> saveMyIdentity(String uuid, String identity) async {
    logger.d("saveMyIdentity: $uuid");
    try {
      /// NOTE: write it twice just in case...bug observed in Android simulator
      await _storage.write(
        key: uuid,
        value: identity,
        iOptions: _getIOSOptionsMyIdentity(),
        aOptions: _getAndroidOptionsMyIdentity(),
        mOptions: _getMacOptionsMyIdentity(),
      );

      await _storage.write(
        key: uuid,
        value: identity,
        iOptions: _getIOSOptionsMyIdentity(),
        aOptions: _getAndroidOptionsMyIdentity(),
        mOptions: _getMacOptionsMyIdentity(),
      );

      var keyStorage = await _storage.readAll(
        iOptions: _getIOSOptionsMyIdentity(),
        aOptions: _getAndroidOptionsMyIdentity(),
        mOptions: _getMacOptionsMyIdentity(),
      );

      var tries = 0;

      if (keyStorage.entries.length == 0) {
        logger.w("Creating saveMyIdentity - write again");

        while (keyStorage.entries.length == 0) {
          await _storage.write(
            key: uuid,
            value: identity,
            iOptions: _getIOSOptionsMyIdentity(),
            aOptions: _getAndroidOptionsMyIdentity(),
            mOptions: _getMacOptionsMyIdentity(),
          );

          keyStorage = await _storage.readAll(
            iOptions: _getIOSOptionsMyIdentity(),
            aOptions: _getAndroidOptionsMyIdentity(),
            mOptions: _getMacOptionsMyIdentity(),
          );

          tries += 1;

          if (tries > 100) {
            logger.w("EXHAUSTED TRIES Saving saveMyIdentity");
            return false;
          }
        }

        return true;
      }

      logManager.log("KeychainManager", "saveMyIdentity", "success: $vaultId");
      logManager.logger
          .d("KeychainManager - saveMyIdentity: success: $vaultId");
      return true;
    } catch (e) {
      logManager.log("KeychainManager", "saveMyIdentity", "failure: $e");
      logManager.logger.w("Keychain saveMyIdentity failure: $e");
      return false;
    }
  }

  Future<MyDigitalIdentity?> getMyDigitalIdentity() async {
    logger.d("getMyDigitalIdentity");
    try {
      final idStorage = await _storage.readAll(
        iOptions: _getIOSOptionsMyIdentity(),
        aOptions: _getAndroidOptionsMyIdentity(),
        mOptions: _getMacOptionsMyIdentity(),
      );

      if (idStorage != null) {
        final idItem =
            MyDigitalIdentity.fromRawJson(idStorage.entries.first.value);

        if (idItem != null) {
          logManager.log("KeychainManager", "getMyDigitalIdentity", "success");
          return idItem;
        } else {
          logManager.log("KeychainManager", "getMyDigitalIdentity", "failure");
          logManager.logger.w("Keychain getMyDigitalIdentity failure");
          return null;
        }
      }
    } catch (e) {
      logger.w("Exception: $e");
      return null;
    }
  }

  Future<bool> deleteMyDigitalIdentity() async {
    logger.d("getMyDigitalIdentity");
    try {
      await _storage.deleteAll(
        iOptions: _getIOSOptionsMyIdentity(),
        aOptions: _getAndroidOptionsMyIdentity(),
        mOptions: _getMacOptionsMyIdentity(),
      );

     return true;
    } catch (e) {
      logger.w("Exception: $e");
      return false;
    }
  }


  /// save identity item in keychain
  Future<bool> saveIdentity(String id, String value) async {
    logger.d("saveIdentity: $id");
    try {
      /// NOTE: write it twice just in case...bug observed in Android simulator
      await _storage.write(
        key: id,
        value: value,
        iOptions: _getIOSOptionsIdentity(),
        aOptions: _getAndroidOptionsIdentity(),
        mOptions: _getMacOptionsIdentity(),
      );

      await _storage.write(
        key: id,
        value: value,
        iOptions: _getIOSOptionsIdentity(),
        aOptions: _getAndroidOptionsIdentity(),
        mOptions: _getMacOptionsIdentity(),
      );

      logManager.log("KeychainManager", "saveItem", "success: $id");
      logManager.logger.d("KeychainManager - saveItem: success: $id");
      return true;
    } catch (e) {
      logManager.log("KeychainManager", "saveItem", "failure: $e");
      logManager.logger.w("Keychain saveItem failure: $e");
      return false;
    }
  }

  Future<List<DigitalIdentity>?> getIdentities() async {
    logger.d("getIdentities");
    try {
      final idStorage = await _storage.readAll(
        iOptions: _getIOSOptionsIdentity(),
        aOptions: _getAndroidOptionsIdentity(),
        mOptions: _getMacOptionsIdentity(),
      );

      List<DigitalIdentity> idList = [];
      for (var id in idStorage.entries) {
        if (id != null) {
          final idItem = DigitalIdentity.fromRawJson(id.value);
          if (idItem != null) {
            idList.add(idItem);
          }
        }
      }

      logManager.log("KeychainManager", "getMyDigitalIdentity", "success");

      return idList;
    } catch (e) {
      logger.w("Exception: $e");
      return null;
    }
  }

  Future<bool> deleteIdentity(String id) async {
    logger.d("deleteIdentity: $id");
    try {
      /// NOTE: write it twice just in case...bug observed in Android simulator
      await _storage.delete(
        key: id,
        iOptions: _getIOSOptionsIdentity(),
        aOptions: _getAndroidOptionsIdentity(),
        mOptions: _getMacOptionsIdentity(),
      );

      await _storage.delete(
        key: id,
        iOptions: _getIOSOptionsIdentity(),
        aOptions: _getAndroidOptionsIdentity(),
        mOptions: _getMacOptionsIdentity(),
      );

      logManager.log("KeychainManager", "deleteIdentity", "success: $id");
      logManager.logger.d("KeychainManager - deleteIdentity: success: $id");
      return true;
    } catch (e) {
      logManager.log("KeychainManager", "deleteIdentity", "failure: $e");
      logManager.logger.w("Keychain deleteIdentity failure: $e");
      return false;
    }
  }

  Future<bool> deleteAllPeerIdentities() async {
    logger.d("deleteAllPeerIdentities");
    try {
      await _storage.deleteAll(
        iOptions: _getIOSOptionsIdentity(),
        aOptions: _getAndroidOptionsIdentity(),
        mOptions: _getMacOptionsIdentity(),
      );

      logManager.log("KeychainManager", "deleteAllPeerIdentities", "success");
      logManager.logger.d("KeychainManager - deleteAllPeerIdentities: success");
      return true;
    } catch (e) {
      // print('error writing data');
      logManager.log("KeychainManager", "deleteAllPeerIdentities", "failure: $e");
      logManager.logger.w("Keychain deleteAllPeerIdentities failure: $e");
      return false;
    }
  }


  /// save our log key that exists for the lifetime of the device
  Future<bool> saveLogKey(String key) async {
    logger.d("saveLogKey");
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        await _storage.write(
          key: 'logKey',
          value: key,
          iOptions: _getIOSOptionsLogKey(),
          aOptions: _getAndroidOptionsLogKey(),
          mOptions: _getMacOptionsLogKey(),
        );

        _encodedLogKeyMaterial = key;
        logManager.log("KeychainManager", "saveLogKey", "success");
        return true;
      } else if (Platform.isAndroid) {
        /// TODO: try saving key twice, for some reason Android Simulator fails unless
        /// you save the key twice as below...No idea why.
        ///
        await _storage.write(
          key: 'logKey',
          value: key,
          iOptions: _getIOSOptionsLogKey(),
          aOptions: _getAndroidOptionsLogKey(),
          mOptions: _getMacOptionsLogKey(),
        );

        await _storage.write(
          key: 'logKey',
          value: key,
          iOptions: _getIOSOptionsLogKey(),
          aOptions: _getAndroidOptionsLogKey(),
          mOptions: _getMacOptionsLogKey(),
        );

        _encodedLogKeyMaterial = key;

        logManager.log("KeychainManager", "saveLogKey", "success");
        return true;
      }

      logManager.log("KeychainManager", "saveLogKey", "failure");
      return false;
    } catch (e) {
      logManager.log("KeychainManager", "saveLogKey", "failure: $e");
      logManager.logger.w("Keychain saveLogKey failure: $e");
      return false;
    }
  }

  /// get the log key
  Future<String> readLogKey() async {
    logger.d("readLogKey");
    try {
      final key = await _storage.readAll(
        iOptions: _getIOSOptionsLogKey(),
        aOptions: _getAndroidOptionsLogKey(),
        mOptions: _getMacOptionsLogKey(),
      );

      var keyItems = key.entries
          .map((entry) => SecItem(entry.key, entry.value))
          .toList(growable: false);

      for (var element in keyItems) {
        if (element.key == 'logKey') {
          _encodedLogKeyMaterial = element.value;
        }
      }

      cryptor.setLogKeyBytes(decodedLogKeyMaterial);
      logManager.log("KeychainManager", "readLogKey", "success");

      return _encodedLogKeyMaterial;
    } catch (e) {
      logManager.log("KeychainManager", "readLogKey", "failure: $e");
      logManager.logger.w("Keychain readLogKey failure: $e");
      return '';
    }
  }

  /// PIN CODE
  ///

  /// save pin code item
  Future<bool> savePinCode(String item) async {
    logger.d("savePinCode");
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        await _storage.write(
          key: 'pin',
          value: item,
          iOptions: _getIOSOptionsPinCode(),
          aOptions: _getAndroidOptionsPinCode(),
          mOptions: _getMacOptionsPinCode(),
        );

        logManager.log("KeychainManager", "savePinCode", "success");
        return true;
      } else if (Platform.isAndroid) {
        /// TODO: figure out why we need to save key twice, for some reason Android fails unless
        /// you save the key twice as below...No idea why.
        ///
        await _storage.write(
          key: 'pin',
          value: item,
          iOptions: _getIOSOptionsPinCode(),
          aOptions: _getAndroidOptionsPinCode(),
          mOptions: _getMacOptionsPinCode(),
        );

        await _storage.write(
          key: 'pin',
          value: item,
          iOptions: _getIOSOptionsPinCode(),
          aOptions: _getAndroidOptionsPinCode(),
          mOptions: _getMacOptionsPinCode(),
        );

        logManager.log("KeychainManager", "savePinCode", "success");
        return true;
      }

      logManager.log("KeychainManager", "savePinCode", "failure");
      logManager.logger.w("Keychain savePinCode failure");
      return false;
    } catch (e) {
      logManager.log("KeychainManager", "savePinCode", "failure: $e");
      logManager.logger.w("Keychain savePinCode failure: $e");
      return false;
    }
  }

  /// check for pin code existence
  Future<bool> readPinCodeKey() async {
    // logger.d("readPinCodeKey");
    try {
      final items = await _storage.readAll(
        iOptions: _getIOSOptionsPinCode(),
        aOptions: _getAndroidOptionsPinCode(),
        mOptions: _getMacOptionsPinCode(),
      );

      // logger.d("readPinCodeKey: ${(items != null)}");

      if (items != null) {
        final pinItem = PinCodeItem.fromRawJson(items.entries.first.value);
        if (pinItem != null) {
          logManager.log("KeychainManager", "readPinCodeKey", "success");
          _isPinCodeEnabled = true;
          return true;
        } else {
          logManager.log("KeychainManager", "readPinCodeKey", "failure");
          logManager.logger.w("Keychain readPinCodeKey failure");
          _isPinCodeEnabled = false;
          return false;
        }
      }
      logManager.log("KeychainManager", "readPinCodeKey", "failure");
      logManager.logger.w("Keychain readPinCodeKey failure");
      _isPinCodeEnabled = false;
      return false;
    } catch (e) {
      _isPinCodeEnabled = false;
      return false;
    }
  }

  /// return our pin code item
  Future<PinCodeItem?> getPinCodeItem() async {
    // logger.d("getPinCodeItem");
    try {
      final item = await _storage.read(
        key: 'pin',
        iOptions: _getIOSOptionsPinCode(),
        aOptions: _getAndroidOptionsPinCode(),
        mOptions: _getMacOptionsPinCode(),
      );

      if (item != null) {
        final pinCodeItem = PinCodeItem.fromRawJson(item);
        logManager.log("KeychainManager", "getPinCodeItem", "success");
        return pinCodeItem;
      } else {
        /// try reading twice for Android...simulator issue
        final item2 = await _storage.read(
          key: 'pin',
          iOptions: _getIOSOptionsPinCode(),
          aOptions: _getAndroidOptionsPinCode(),
          mOptions: _getMacOptionsPinCode(),
        );
        if (item2 != null) {
          final pinCodeItem2 = PinCodeItem.fromRawJson(item2);
          logManager.log("KeychainManager", "getPinCodeItem", "success");
          return pinCodeItem2;
        }
      }

      logManager.log("KeychainManager", "getPinCodeItem", "failure");
      logManager.logger.w("Keychain getPinCodeItem failure");
      return null;
    } catch (e) {
      logManager.log("KeychainManager", "getPinCodeItem", "failure: $e");
      logManager.logger.w("Keychain getPinCodeItem failure: $e");
      return null;
    }
  }

  /// Local Device ID keys
  /// TODO: add android implementation
  Future<bool> saveLocalDeviceKey(String id, String time) async {
    logger.d("saveLocalDeviceKey");
    try {
      if (Platform.isIOS) {
        await _storage.write(
          key: id,
          value: time,
          iOptions: _getIOSOptionsLocalDeviceKey(),
        );

        logManager.log("KeychainManager", "saveLocalDeviceKey", "success");
        return true;
      }

      return false;
    } catch (e) {
      logManager.log("KeychainManager", "saveLocalDeviceKey", "failure: $e");
      logManager.logger.w("Keychain saveCloudDeviceKey failure: $e");
      return false;
    }
  }

  /// reads the local device key(s) and returns if available
  /// should probably be storing the last device id/key and the current one
  /// TODO: add android implementation
  Future<List<SecItem>> readLocalDeviceKeys() async {
    logger.d("readLocalDeviceKeys");
    try {
      if (Platform.isIOS) {
        var items = await _storage.readAll(
          iOptions: _getIOSOptionsLocalDeviceKey(),
        );

        final localDeviceItems = items.entries
            .map((entry) => SecItem(entry.key, entry.value))
            .toList(growable: false);

        logManager.log("KeychainManager", "readLocalDeviceKeys", "success");
        return localDeviceItems;
      }
      return [];
    } catch (e) {
      logManager.log("KeychainManager", "readLocalDeviceKeys", "failure: $e");
      logManager.logger.w("Keychain readLocalDeviceKeys failure: $e");
      return [];
    }
  }

  // /// delete our local device keys
  // Future<bool> deleteLocalDeviceKeys() async {
  //   logger.d("deleteLocalDeviceKeys");
  //
  //   try {
  //     await _storage.deleteAll(
  //       iOptions: _getIOSOptionsLocalDeviceKey(),
  //     );
  //
  //     logManager.log("KeychainManager", "deleteLocalDeviceKeys", 'success');
  //     return true;
  //   } catch (e) {
  //     logManager.log("KeychainManager", "deleteLocalDeviceKeys", 'failure: $e');
  //     logManager.logger.w("Keychain deleteLocalDeviceKeys failure: $e");
  //     return false;
  //   }
  // }


  /// BIOMETRIC KEY
  ///

  /// save biometric key
  Future<bool> saveBiometricKey() async {
    logger.d("saveBiometricKey");

    if (cryptor.aesSecretKeyBytes.isNotEmpty &&
        cryptor.authSecretKeyBytes.isNotEmpty) {
      /// append our encryption and authentication key together and save in keychain
      final keys =
          base64.encode(cryptor.aesSecretKeyBytes + cryptor.authSecretKeyBytes);
      final key = base64.encode(cryptor.aesRootSecretKeyBytes);
      try {
        if (Platform.isIOS || Platform.isMacOS) {
          await _storage.write(
            key: 'biometric',
            value: key,
            iOptions: _getIOSOptionsBiometric(),
            aOptions: _getAndroidOptionsBiometric(),
            mOptions: _getMacOptionsPinCode(),
          );

          logManager.log("KeychainManager", "saveBiometricKey", "success");
          _isBiometricLoginEnabled = true;
          return true;
        } else if (Platform.isAndroid) {
          await _storage.write(
            key: 'biometric',
            value: key,
            iOptions: _getIOSOptionsBiometric(),
            aOptions: _getAndroidOptionsBiometric(),
            mOptions: _getMacOptionsPinCode(),
          );

          await _storage.write(
            key: 'biometric',
            value: key,
            iOptions: _getIOSOptionsBiometric(),
            aOptions: _getAndroidOptionsBiometric(),
            mOptions: _getMacOptionsPinCode(),
          );

          logManager.log("KeychainManager", "saveBiometricKey", "success");
          _isBiometricLoginEnabled = true;
          return true;
        }

        logManager.log("KeychainManager", "saveBiometricKey", "failure");
        logManager.logger.w("Keychain saveBiometricKey failure");
        return false;
      } catch (e) {
        logManager.log("KeychainManager", "saveBiometricKey", "failure: $e");
        logManager.logger.w("Keychain saveBiometricKey failure: $e");
        return false;
      }
    } else {
      logManager.log("KeychainManager", "saveBiometricKey", "failure");
      logManager.logger.w("Keychain saveBiometricKey failure");
      return false;
    }
  }

  /// reads the key and returns if available
  Future<bool> renderBiometricKey() async {
    logger.d("renderBiometricKey");
    try {
      var items = await _storage.readAll(
        iOptions: _getIOSOptionsBiometric(),
        aOptions: _getAndroidOptionsBiometric(),
        mOptions: _getMacOptionsBiometric(),
      );

      final bioItems = items.entries
          .map((entry) => SecItem(entry.key, entry.value))
          .toList(growable: false);

      /// theres only one biometric key allowed
      var encodedAesKey = bioItems.first.value;

      if (encodedAesKey != null && encodedAesKey.isNotEmpty) {
        logManager.log("KeychainManager", "renderBiometricKey", "success");
        _isBiometricLoginEnabled = true;
        return true;
      }

      logManager.log("KeychainManager", "renderBiometricKey", "failure");
      logManager.logger.w("Keychain renderBiometricKey failure");
      _isBiometricLoginEnabled = false;
      return false;
    } catch (e) {
      logManager.log("KeychainManager", "renderBiometricKey", "failure: $e");
      logManager.logger.w("Keychain renderBiometricKey failure: $e");
      _isBiometricLoginEnabled = false;
      return false;
    }
  }

  /// reads the key and sets it in cryptor manager
  Future<bool> setBiometricKey() async {
    logger.d("setBiometricKey");

    var hasKey = await _storage.containsKey(
      key: 'biometric',
      iOptions: _getIOSOptionsBiometric(),
      aOptions: _getAndroidOptionsBiometric(),
      mOptions: _getMacOptionsBiometric(),
    );

    if (hasKey) {
      try {
        final encodedAesKey = await _storage.read(
          key: 'biometric',
          iOptions: _getIOSOptionsBiometric(),
          aOptions: _getAndroidOptionsBiometric(),
          mOptions: _getMacOptionsBiometric(),
        );

        if (encodedAesKey != null && encodedAesKey.isNotEmpty) {
          final keyBytes = base64.decode(encodedAesKey);
          if (keyBytes != null && keyBytes.isNotEmpty) {
            cryptor.setAesRootKeyBytes(keyBytes);
            await cryptor.expandSecretRootKey(keyBytes);

            _isBiometricLoginEnabled = true;
            logManager.log("KeychainManager", "setBiometricKey", "success");
            return true;
          }

          _isBiometricLoginEnabled = false;
          logManager.log("KeychainManager", "setBiometricKey", "failure");
          logManager.logger.w("Keychain setBiometricKey failure - 1");
          return false;
        }

        logManager.log("KeychainManager", "setBiometricKey", "failure");
        logManager.logger.w("Keychain setBiometricKey failure - 2");
        _isBiometricLoginEnabled = false;
        return false;
      } catch (e) {
        logManager.log("KeychainManager", "setBiometricKey", "failure: $e");
        logManager.logger.w("Keychain setBiometricKey failure: $e");
        _isBiometricLoginEnabled = false;
        return false;
      }
    } else {
      hasKey = await _storage.containsKey(
        key: 'biometric',
        iOptions: _getIOSOptionsBiometric(),
        aOptions: _getAndroidOptionsBiometric(),
        mOptions: _getMacOptionsBiometric(),
      );

      if (hasKey) {
        try {
          final encodedAesKey = await _storage.read(
            key: 'biometric',
            iOptions: _getIOSOptionsBiometric(),
            aOptions: _getAndroidOptionsBiometric(),
            mOptions: _getMacOptionsBiometric(),
          );

          if (encodedAesKey != null && encodedAesKey.isNotEmpty) {
            final keyBytes = base64.decode(encodedAesKey);
            if (keyBytes != null && keyBytes.isNotEmpty) {
              cryptor.setAesRootKeyBytes(keyBytes);
              await cryptor.expandSecretRootKey(keyBytes);

              _isBiometricLoginEnabled = true;
              logManager.log("KeychainManager", "setBiometricKey", "success");
              return true;
            }

            _isBiometricLoginEnabled = false;
            logManager.log("KeychainManager", "setBiometricKey", "failure");
            logManager.logger.w("Keychain setBiometricKey failure - 1");
            return false;
          }

          logManager.log("KeychainManager", "setBiometricKey", "failure");
          logManager.logger.w("Keychain setBiometricKey failure - 2");
          _isBiometricLoginEnabled = false;
          return false;
        } catch (e) {
          logManager.log("KeychainManager", "setBiometricKey", "failure: $e");
          logManager.logger.w("Keychain setBiometricKey failure: $e");
          _isBiometricLoginEnabled = false;
          return false;
        }
      } else {
        logManager.log("KeychainManager", "setBiometricKey", "failure");
        logManager.logger.w("Keychain setBiometricKey failure");
        _isBiometricLoginEnabled = false;
        return false;
      }
    }
  }

  /// delete the biometric key wrapping our encryption keys
  Future<bool> deleteBiometricKey() async {
    logger.d("deleteBiometricKey");
    try {
      /// maybe get rid of hasKey check and just delete...
      final hasKey = await _storage.containsKey(
        key: 'biometric',
        iOptions: _getIOSOptionsBiometric(),
        aOptions: _getAndroidOptionsBiometric(),
        mOptions: _getMacOptionsBiometric(),
      );

      if (hasKey) {
        /// delete twice for Android simulator bug
        await _storage.deleteAll(
          iOptions: _getIOSOptionsBiometric(),
          aOptions: _getAndroidOptionsBiometric(),
          mOptions: _getMacOptionsBiometric(),
        );

        await _storage.deleteAll(
          iOptions: _getIOSOptionsBiometric(),
          aOptions: _getAndroidOptionsBiometric(),
          mOptions: _getMacOptionsBiometric(),
        );

        logManager.log("KeychainManager", "deleteBiometricKey", 'success');
        _isBiometricLoginEnabled = false;
        return true;
      }

      _isBiometricLoginEnabled = false;
      logManager.logger.w("Keychain deleteBiometricKey failure");
      logManager.log("KeychainManager", "deleteBiometricKey", 'failure');
      return false;
    } catch (e) {
      logManager.log("KeychainManager", "deleteBiometricKey", 'failure: $e');
      logManager.logger.w("Keychain deleteBiometricKey failure: $e");
      return false;
    }
  }

  /// PASSWORD ITEMS
  ///

  /// save our password item in keychain
  Future<bool> saveItem(String id, String value) async {
    logger.d("saveItem: $id");
    try {
      /// NOTE: write it twice just in case...bug observed in Android simulator
      ///
      await _storage.write(
        key: id,
        value: value,
        iOptions: _getIOSOptionsItem(),
        aOptions: _getAndroidOptionsItem(),
        mOptions: _getMacOptionsItem(),
      );

      await _storage.write(
        key: id,
        value: value,
        iOptions: _getIOSOptionsItem(),
        aOptions: _getAndroidOptionsItem(),
        mOptions: _getMacOptionsItem(),
      );

      logManager.log("KeychainManager", "saveItem", "success: $id");
      logManager.logger.d("KeychainManager - saveItem: success: $id");
      return true;
    } catch (e) {
      logManager.log("KeychainManager", "saveItem", "failure: $e");
      logManager.logger.w("Keychain saveItem failure: $e");
      return false;
    }
  }

  /// get all our password items
  Future<GenericItemList> getAllItems() async {
    logger.d("getAllItems");
    try {
      _items = await _storage.readAll(
        iOptions: _getIOSOptionsItem(),
        aOptions: _getAndroidOptionsItem(),
        mOptions: _getMacOptionsItem(),
      );

      var allItems = _items.entries
          .map((entry) => GenericItem.fromRawJson(entry.value))
          .toList(growable: false);

      _passwordItemsSize = 0;
      _numberOfPreviousPasswords = 0;

      allItems.forEach((element) {
        if (element.type == "password") {
          final item = PasswordItem.fromRawJson(element.data);
          if (item != null) {
            _numberOfPreviousPasswords += item.previousPasswords.length;
            _passwordItemsSize += element.data.length;
          }
        } else if (element.type == "note") {
          final item = NoteItem.fromRawJson(element.data);
          if (item != null) {
            _passwordItemsSize += element.data.length;
          }
        } else if (element.type == "key") {
          final item = KeyItem.fromRawJson(element.data);
          if (item != null) {
            _passwordItemsSize += element.data.length;
          }
        }
      });

      logManager.log("KeychainManager", "getAllItems",
          "success: ${allItems.length} items");

      final genItemList = GenericItemList(list: allItems);

      return genItemList;
    } catch (e) {
      logManager.log("KeychainManager", "getAllItems", "failure: $e");
      logManager.logger.w("Keychain getAllItems Exception: $e");
      return GenericItemList(list: []);
    }
  }


  Future<GenericItemList> getAllItemsForBackup() async {
    logger.d("getAllItemsForBackup");

    try {
      _items = await _storage.readAll(
        iOptions: _getIOSOptionsItem(),
        aOptions: _getAndroidOptionsItem(),
        mOptions: _getMacOptionsItem(),
      );

      var allItems = _items.entries
          .map((entry) => GenericItem.fromRawJson(entry.value))
          .toList(growable: false);

      allItems.sort((a, b) {
        return b.data.compareTo(a.data);
      });

      _passwordItemsSize = 0;
      _numberOfPreviousPasswords = 0;
      allItems.forEach((element) {
        if (element.type == "password") {
          final item = PasswordItem.fromRawJson(element.data);
          if (item != null) {
            _numberOfPreviousPasswords += item.previousPasswords.length;
            _passwordItemsSize += element.data.length;
          }
        } else if (element.type == "note") {
          final item = NoteItem.fromRawJson(element.data);
          if (item != null) {
            _passwordItemsSize += element.data.length;
          }
        } else if (element.type == "key") {
          final item = KeyItem.fromRawJson(element.data);
          if (item != null) {
            _passwordItemsSize += element.data.length;
          }
        }
      });

      logManager.log("KeychainManager", "getAllItemsForBackup",
          "success: ${allItems.length} items");

      final genItemListFinal = GenericItemList(list: allItems);

      return genItemListFinal;
    } catch (e) {
      logManager.log("KeychainManager", "getAllItems", "failure: $e");
      logManager.logger.w("Keychain getAllItems Exception: $e");
      return GenericItemList(list: []);
    }
  }

  /// get a password item based on the id
  Future<String> getItem(String id) async {
    logger.d("getItem: $id");
    try {
      var hasKey = await _storage.containsKey(
        key: id,
        iOptions: _getIOSOptionsItem(),
        aOptions: _getAndroidOptionsItem(),
        mOptions: _getMacOptionsItem(),
      );

      if (Platform.isAndroid && !hasKey) {
        /// call it again and somehow it works...dont know why 🤷🏼
        hasKey = await _storage.containsKey(
          key: id,
          iOptions: _getIOSOptionsItem(),
          aOptions: _getAndroidOptionsItem(),
          mOptions: _getMacOptionsItem(),
        );

        if (hasKey) {
          final item = await _storage.read(
            key: id,
            iOptions: _getIOSOptionsItem(),
            aOptions: _getAndroidOptionsItem(),
            mOptions: _getMacOptionsItem(),
          );

          if (item != null) {
            logManager.log("KeychainManager", "getItem", "success: $id");
            return item;
          }

          logManager.log("KeychainManager", "getItem", "failure: $id");
          logManager.logger.w("Keychain getItem failure: $id");
          return '';
        } else {
          logManager.log("KeychainManager", "getItem", "failure: $id");
          logManager.logger.w("Keychain getItem failure: $id");
          return '';
        }
      } else {
        if (hasKey) {
          final item = await _storage.read(
            key: id,
            iOptions: _getIOSOptionsItem(),
            aOptions: _getAndroidOptionsItem(),
            mOptions: _getMacOptionsItem(),
          );

          logManager.log("KeychainManager", "getItem", "success: $id");

          return item!;
        } else {
          logManager.log("KeychainManager", "getItem", "failure: $id");
          logManager.logger.w("Keychain getItem failure: $id");
          return '';
        }
      }
    } catch (e) {
      logManager.log("KeychainManager", "getItem", "failure: $e");
      logManager.logger.w("Keychain getItem failure: $e");
      return '';
    }
  }

  /// delete a password item based on the id
  Future<bool> deleteItem(String id) async {
    logger.d("deleteItem: $id");
    try {
      var hasKey = await _storage.containsKey(
        key: id,
        iOptions: _getIOSOptionsItem(),
        aOptions: _getAndroidOptionsItem(),
        mOptions: _getMacOptionsItem(),
      );

      if (hasKey) {
        await _storage.delete(
          key: id,
          iOptions: _getIOSOptionsItem(),
          aOptions: _getAndroidOptionsItem(),
          mOptions: _getMacOptionsItem(),
        );
        logManager.log("KeychainManager", "deleteItem", "success: $id");
        return true;
      } else {
        /// try again, encountered bug/scenario where 2 times works for some reason
        hasKey = await _storage.containsKey(
          key: id,
          iOptions: _getIOSOptionsItem(),
          aOptions: _getAndroidOptionsItem(),
          mOptions: _getMacOptionsItem(),
        );

        if (hasKey) {
          await _storage.delete(
            key: id,
            iOptions: _getIOSOptionsItem(),
            aOptions: _getAndroidOptionsItem(),
            mOptions: _getMacOptionsItem(),
          );
          logManager.log("KeychainManager", "deleteItem", "success: $id");
          return true;
        }
        logManager.log("KeychainManager", "deleteItem", "failure: $id");
        logManager.logger.w("Keychain deleteItem failure: $id");
        return false;
      }
    } catch (e) {
      logManager.log("KeychainManager", "deleteItem", "failure: $e");
      logManager.logger.w("Keychain deleteItem failure: $e");
      return false;
    }
  }

  /// delete a password item based on the id
  Future<bool> deleteAllItems() async {
    logger.d("deleteAllItems");
    try {
        await _storage.deleteAll(
          iOptions: _getIOSOptionsItem(),
          aOptions: _getAndroidOptionsItem(),
          mOptions: _getMacOptionsItem(),
        );
        logManager.log("KeychainManager", "deleteItem", "success");
        return true;
    } catch (e) {
      logManager.log("KeychainManager", "deleteItem", "failure: $e");
      logManager.logger.w("Keychain deleteItem failure: $e");
      return false;
    }
  }



  /// Recovery Keys
  ///
  ///
  Future<bool> saveRecoveryKey(String id, String data) async {
    logger.d("saveRecoveryKey: $id");
    try {
      await _storage.write(
        key: id,
        value: data,
        iOptions: _getIOSOptionsRecoveryKey(),
        aOptions: _getAndroidOptionsRecoveryKey(),
        mOptions: _getMacOptionsRecoveryKey(),
      );

      await _storage.write(
        key: id,
        value: data,
        iOptions: _getIOSOptionsRecoveryKey(),
        aOptions: _getAndroidOptionsRecoveryKey(),
        mOptions: _getMacOptionsRecoveryKey(),
      );

      logger.d("saveRecoveryKey: success");
      logManager.log("KeychainManager", "saveRecoveryKey", "success: $id");
      return true;
    } catch (e) {
      logger.d("saveBackupItem: failure");
      logManager.log("KeychainManager", "saveRecoveryKey", "failure: $e");
      logManager.logger.w("Keychain saveRecoveryKey failure: $e");
      return false;
    }
  }

  Future<RecoveryKey?> getRecoveryKeyItem(String id) async {
    logger.d("getRecoveryKeyItem: $id");
    try {
      var recItem = await _storage.read(
        key: id,
        iOptions: _getIOSOptionsRecoveryKey(),
        aOptions: _getAndroidOptionsRecoveryKey(),
        mOptions: _getMacOptionsRecoveryKey(),
      );

      /// try this method again...seems to be a bug in Android
      if (recItem == null) {
        recItem = await _storage.read(
          key: id,
          iOptions: _getIOSOptionsRecoveryKey(),
          aOptions: _getAndroidOptionsRecoveryKey(),
          mOptions: _getMacOptionsRecoveryKey(),
        );
      }

      final item = RecoveryKey.fromRawJson(recItem!);
      // logger.d("getRecoveryKeyItem: ${item.toJson()}");
      logManager.log("KeychainManager", "getRecoveryKeyItem", "success: $id");
      return item;
    } catch (e) {
      logManager.log("KeychainManager", "getRecoveryKeyItem", "failure: $e");
      logManager.logger.w("Keychain getRecoveryKeyItem failure: $e");
      return null;
    }
  }

  Future<List<RecoveryKey>?> getRecoveryKeyItems() async {
    logger.d("getRecoveryKeyItems");
    try {
      final recoveryItems = await _storage.readAll(
        iOptions: _getIOSOptionsRecoveryKey(),
        aOptions: _getAndroidOptionsRecoveryKey(),
        mOptions: _getMacOptionsRecoveryKey(),
      );

      logManager.logger.d("KeychainManager: success: ${recoveryItems.entries.first}");

      final items = recoveryItems.entries
          .map((entry) => RecoveryKey.fromRawJson(entry.value))
          .toList(growable: false);

      logManager.log("KeychainManager", "getRecoveryKeyItems", "success");

      return items;
    } catch (e) {
      logManager.log("KeychainManager", "getRecoveryKeyItems", "failure: $e");
      logManager.logger.w("Keychain getRecoveryKeyItems failure: $e");
      return [];
    }
  }

  // Future<bool> hasRecoveryKeyItems() async {
  //   // print('debug: hasBackupItems');
  //   logger.d("hasRecoveryKeyItems");
  //
  //   try {
  //     final backupItems = await _storage.readAll(
  //       iOptions: _getIOSOptionsRecoveryKey(),
  //       aOptions: _getAndroidOptionsRecoveryKey(),
  //       mOptions: _getMacOptionsRecoveryKey(),
  //     );
  //
  //     final items = backupItems.entries
  //         .map((entry) => RecoveryKey.fromRawJson(entry.value))
  //         .toList(growable: false);
  //
  //     logManager.log("KeychainManager", "hasBackupItems", "success");
  //
  //     return (items.length > 0);
  //   } catch (e) {
  //     logManager.log("KeychainManager", "hasBackupItems", "failure: $e");
  //     logManager.logger.w("Keychain hasBackupItems failure: $e");
  //     return false;
  //   }
  // }

  Future<bool> deleteRecoveryKeyItem(String id) async {
    logger.d("deleteRecoveryKeyItem: $id");
    try {
      final hasKey = await _storage.containsKey(
        key: id,
        iOptions: _getIOSOptionsRecoveryKey(),
        aOptions: _getAndroidOptionsRecoveryKey(),
        mOptions: _getMacOptionsRecoveryKey(),
      );
      // logger.d("deleteRecoveryKeyItem-hasKey: $hasKey");

      if (hasKey) {
        await _storage.delete(
          key: id,
          iOptions: _getIOSOptionsRecoveryKey(),
          aOptions: _getAndroidOptionsRecoveryKey(),
          mOptions: _getMacOptionsRecoveryKey(),
        );
        // logger.d("deleteRecoveryKeyItem: success");

        logManager.log(
            "KeychainManager", "deleteRecoveryKeyItem", "success: $id");
        return true;
      }

      // logger.e("deleteRecoveryKeyItem: failure");

      logManager.log(
          "KeychainManager", "deleteRecoveryKeyItem", "failure: $id");
      return false;
    } catch (e) {
      logManager.log("KeychainManager", "deleteRecoveryKeyItem", "failure: $e");
      logManager.logger.w("Keychain deleteRecoveryKeyItem failure: $e");
      return false;
    }
  }

  Future<bool> deleteAllRecoveryKeys() async {
    logger.d("deleteAllRecoveryKeys");
    try {
        await _storage.deleteAll(
          iOptions: _getIOSOptionsRecoveryKey(),
          aOptions: _getAndroidOptionsRecoveryKey(),
          mOptions: _getMacOptionsRecoveryKey(),
        );
        logManager.logger.d("Keychain deleteAllRecoveryKeys success");
        logManager.log(
            "KeychainManager", "deleteAllRecoveryKeys", "success");
        return true;
    } catch (e) {
      logManager.log("KeychainManager", "deleteAllRecoveryKeys", "failure: $e");
      logManager.logger.w("Keychain deleteAllRecoveryKeys failure: $e");
      return false;
    }
  }

  /// DELETING KEYS AND ITEMS
  ///

  /// delete our pin code item
  Future<bool> deletePinCode() async {
    logger.d("deletePinCode");
    try {
      await _storage.deleteAll(
        iOptions: _getIOSOptionsPinCode(),
        aOptions: _getAndroidOptionsPinCode(),
        mOptions: _getMacOptionsPinCode(),
      );
      logManager.log("KeychainManager", "deletePinCode", "success");
      return true;
    } catch (e) {
      logManager.log("KeychainManager", "deletePinCode", "failure: $e");
      logManager.logger.w("Keychain deletePinCode failure: $e");
      return false;
    }
  }

  /// should only use for testing
  Future<bool> deleteAll() async {
    logger.d("deleteAll");
    try {
      await _storage.deleteAll(
        iOptions: _getIOSOptionsKey(),
        aOptions: _getAndroidOptionsKey(),
        mOptions: _getMacOptionsKey(),
      );
      await _storage.deleteAll(
        iOptions: _getIOSOptionsLogKey(),
        aOptions: _getAndroidOptionsLogKey(),
        mOptions: _getMacOptionsLogKey(),
      );
      await _storage.deleteAll(
        iOptions: _getIOSOptionsMyIdentity(),
        aOptions: _getAndroidOptionsMyIdentity(),
        mOptions: _getMacOptionsMyIdentity(),
      );
      await _storage.deleteAll(
        iOptions: _getIOSOptionsIdentity(),
        aOptions: _getAndroidOptionsIdentity(),
        mOptions: _getMacOptionsIdentity(),
      );
      await _storage.deleteAll(
        iOptions: _getIOSOptionsRecoveryKey(),
        aOptions: _getAndroidOptionsRecoveryKey(),
        mOptions: _getMacOptionsRecoveryKey(),
      );
      await _storage.deleteAll(
        iOptions: _getIOSOptionsPinCode(),
        aOptions: _getAndroidOptionsPinCode(),
        mOptions: _getMacOptionsPinCode(),
      );
      await _storage.deleteAll(
        iOptions: _getIOSOptionsItem(),
        aOptions: _getAndroidOptionsItem(),
        mOptions: _getMacOptionsItem(),
      );

      await _storage.deleteAll(
        iOptions: _getIOSOptionsBiometric(),
        aOptions: _getAndroidOptionsBiometric(),
        mOptions: _getMacOptionsBiometric(),
      );

      _salt = '';
      _encryptedKeyMaterial = '';
      _vaultId = "";

      logManager.deleteLogFile();

      return true;
    } catch (e) {
      logManager.logger.w("Keychain deletePinCode failure: $e");
      return false;
    }
  }

  /// delete our local vault items and keys except for backup items and log key
  Future<bool> deleteForBackup() async {
    logger.d("deleteForBackup");
    try {
      await _storage.deleteAll(
        iOptions: _getIOSOptionsKey(),
        aOptions: _getAndroidOptionsKey(),
        mOptions: _getMacOptionsKey(),
      );
      await _storage.deleteAll(
        iOptions: _getIOSOptionsItem(),
        aOptions: _getAndroidOptionsItem(),
        mOptions: _getMacOptionsItem(),
      );
      await _storage.deleteAll(
        iOptions: _getIOSOptionsMyIdentity(),
        aOptions: _getAndroidOptionsMyIdentity(),
        mOptions: _getMacOptionsMyIdentity(),
      );
      await _storage.deleteAll(
        iOptions: _getIOSOptionsIdentity(),
        aOptions: _getAndroidOptionsIdentity(),
        mOptions: _getMacOptionsIdentity(),
      );
      await _storage.deleteAll(
        iOptions: _getIOSOptionsPinCode(),
        aOptions: _getAndroidOptionsPinCode(),
        mOptions: _getMacOptionsPinCode(),
      );
      await _storage.deleteAll(
        iOptions: _getIOSOptionsRecoveryKey(),
        aOptions: _getAndroidOptionsRecoveryKey(),
        mOptions: _getMacOptionsRecoveryKey(),
      );
      await _storage.deleteAll(
        iOptions: _getIOSOptionsBiometric(),
        aOptions: _getAndroidOptionsBiometric(),
        mOptions: _getMacOptionsBiometric(),
      );

      _salt = '';
      _encryptedKeyMaterial = '';
      _vaultId = "";

      logManager.log("KeychainManager", "deleteForBackup", "success");
      return true;
    } catch (e) {
      logManager.log("KeychainManager", "deleteForBackup", "failure: $e");
      logManager.logger.w("Keychain deleteForBackup failure: $e");
      return false;
    }
  }

  Future<bool> deleteForStartup() async {
    logger.d("deleteForStartup");
    try {
      await _storage.deleteAll(
        iOptions: _getIOSOptionsKey(),
        aOptions: _getAndroidOptionsKey(),
        mOptions: _getMacOptionsKey(),
      );
      await _storage.deleteAll(
        iOptions: _getIOSOptionsItem(),
        aOptions: _getAndroidOptionsItem(),
        mOptions: _getMacOptionsItem(),
      );
      await _storage.deleteAll(
        iOptions: _getIOSOptionsPinCode(),
        aOptions: _getAndroidOptionsPinCode(),
        mOptions: _getMacOptionsPinCode(),
      );
      await _storage.deleteAll(
        iOptions: _getIOSOptionsMyIdentity(),
        aOptions: _getAndroidOptionsMyIdentity(),
        mOptions: _getMacOptionsMyIdentity(),
      );
      await _storage.deleteAll(
        iOptions: _getIOSOptionsIdentity(),
        aOptions: _getAndroidOptionsIdentity(),
        mOptions: _getMacOptionsIdentity(),
      );
      await _storage.deleteAll(
        iOptions: _getIOSOptionsRecoveryKey(),
        aOptions: _getAndroidOptionsRecoveryKey(),
        mOptions: _getMacOptionsRecoveryKey(),
      );
      await _storage.deleteAll(
        iOptions: _getIOSOptionsBiometric(),
        aOptions: _getAndroidOptionsBiometric(),
        mOptions: _getMacOptionsBiometric(),
      );

      _salt = "";
      _encryptedKeyMaterial = "";
      _vaultId = "";

      logManager.log("KeychainManager", "deleteForStartup", "success");
      return true;
    } catch (e) {
      logManager.log("KeychainManager", "deleteForStartup", "failure: $e");
      logManager.logger.w("Keychain deleteForStartup failure: $e");
      return false;
    }
  }

}

/// encrypted key material for local vault (saved in Keychain)
class KeyMaterial {
  final String id;
  final String salt;
  final int rounds;
  final String key;
  final String hint;

  KeyMaterial({
    required this.id,
    required this.salt,
    required this.rounds,
    required this.key,
    required this.hint,
  });

  factory KeyMaterial.fromRawJson(String str) =>
      KeyMaterial.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory KeyMaterial.fromJson(Map<String, dynamic> json) {
    return KeyMaterial(
      id: json['id'],
      salt: json['salt'],
      rounds: json["rounds"],
      key: json['key'],
      hint: json['hint'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "id": id,
      "salt": salt,
      "rounds": rounds,
      "key": key,
      "hint": hint,
    };
    return jsonMap;
  }
}
