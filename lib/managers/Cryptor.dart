import "dart:math";
import "dart:convert";
import "dart:typed_data";

import "package:cryptography/cryptography.dart";
import "package:convert/convert.dart";
import "package:argon2/argon2.dart";
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/foundation.dart';
import "package:uuid/uuid.dart";
import "package:bip39/bip39.dart" as bip39;
import 'package:ecdsa/ecdsa.dart' as ecdsa;
import 'package:elliptic/elliptic.dart';

import "../helpers/bip39_dictionary.dart";
import '../helpers/WidgetUtils.dart';
import '../helpers/AppConstants.dart';
import '../models/DecryptedGeoLockItem.dart';
import '../models/MyDigitalIdentity.dart';
import '../models/VaultItem.dart';
import "../models/PinCodeItem.dart";
import "../models/EncryptedGeoLockItem.dart";
import 'Hasher.dart';
import "KeychainManager.dart";
import "SettingsManager.dart";
import 'package:logger/logger.dart';

/// this creates a stackoverflow
// import "LogManager.dart";

class Cryptor {
  static final Cryptor _shared = Cryptor._internal();

  /// logging
  var logger = Logger(
    printer: PrettyPrinter(),
  );

  var loggerNoStack = Logger(
    printer: PrettyPrinter(methodCount: 0),
  );


  factory Cryptor() {
    return _shared;
  }

  var _uuid = Uuid();

  // PBKDF2 derived key parameters
  static const _saltLength = 32;
  static const _rounds = 300000;
  static const _roundsPin = 100000; // pin code rounds

  List<int> _salt = [];

  List<int>? get salt {
    return _salt;
  }

  int get rounds {
    return _rounds;
  }

  late KeyMaterial _currentKeyMaterial;


  var hmac_algo_256 = Hmac.sha256();
  var hmac_algo_512 = Hmac.sha512();

  /// secure random bytes algorithm
  final sec_rng = Random.secure();


  /// root secret key bytes
  List<int> _aesRootSecretKeyBytes = [];

  List<int> get aesRootSecretKeyBytes {
    return _aesRootSecretKeyBytes;
  }


  List<int> _tempReKeyRootSecretKeyBytes = [];

  List<int> get tempReKeyRootSecretKeyBytes {
    return _tempReKeyRootSecretKeyBytes;
  }

  SecretKey? _tempReKeyRootSecretKey;

  SecretKey? get tempReKeyRootSecretKey {
    return _tempReKeyRootSecretKey;
  }

  /// secret key for encrypting data - DEK
  SecretKey? _aesEncryptionKey;

  SecretKey? get aesEncryptionKey {
    return _aesEncryptionKey;
  }

  /// secret key bytes
  List<int> _aesEncryptionKeyBytes = [];

  List<int> get aesEncryptionKeyBytes {
    return _aesEncryptionKeyBytes;
  }

  /// authentication key for MAC - KAK
  SecretKey? _aesAuthKey;

  SecretKey? get aesAuthKey {
    return _aesAuthKey;
  }

  /// authentication key bytes
  List<int> _aesAuthKeyBytes = [];

  List<int> get aesAuthKeyBytes {
    return _aesAuthKeyBytes;
  }

  /// key gen key
  SecretKey? _aesGenKey;

  SecretKey? get aesGenSecretKey {
    return _aesGenKey;
  }

  /// key gen key bytes
  List<int> _aesGenKeyBytes = [];

  List<int> get aesGenKeyBytes {
    return _aesGenKeyBytes;
  }

  /// Temp Encryption Keys...For REKEY
  ///
  /// secret key for encrypting data - DEK
  SecretKey? _tempAesEncryptionKey;

  SecretKey? get tempAesEncryptionKey {
    return _tempAesEncryptionKey;
  }

  /// secret key bytes
  List<int> _tempAesEncryptionKeyBytes = [];

  List<int> get tempAesEncryptionKeyBytes {
    return _tempAesEncryptionKeyBytes;
  }

  /// authentication key for MAC - KAK
  SecretKey? _tempAuthKey;

  SecretKey? get tempAuthKey {
    return _tempAuthKey;
  }

  /// authentication key bytes
  List<int> _tempAuthKeyBytes = [];

  List<int> get tempAuthKeyBytes {
    return _tempAuthKeyBytes;
  }

  SecretKey? _tempAesGenKey;

  SecretKey? get tempAesGenKey {
    return _tempAesGenKey;
  }

  /// secret key bytes
  List<int> _tempAesGenKeyBytes = [];

  List<int> get tempAesGenKeyBytes {
    return _tempAesGenKeyBytes;
  }


  /// logging secret key for authorizing logs
  SecretKey? _logSecretKey;

  SecretKey? get logSecretKey {
    return _logSecretKey;
  }

  /// logging secret key bytes
  List<int> _logSecretKeyBytes = [];

  List<int> get logSecretKeyBytes {
    return _logSecretKeyBytes;
  }

  String _logKeyMaterial = "";
  String get logKeyMaterial {
    return _logKeyMaterial;
  }

  final settingsManager = SettingsManager();

  /// Encryption Algorithm
  final algorithm_nomac = AesCtr.with256bits(macAlgorithm: MacAlgorithm.empty);

  /// this creates a stackoverflow
  // final logManager = LogManager();
  // final keyManager = KeychainManager();

  Cryptor._internal();

  void clearAESKeys() {
    logger.d("clearAESKeys: ❌ 🔑");
    _aesRootSecretKeyBytes = [];

    _aesEncryptionKeyBytes = [];
    _aesEncryptionKey = null;

    _aesAuthKeyBytes = [];
    _aesAuthKey = null;

    _aesGenKeyBytes = [];
    _aesGenKey = null;

    _tempAesGenKeyBytes = [];
    _tempAesGenKey = null;

    _tempAesEncryptionKeyBytes = [];
    _tempAesEncryptionKey = null;

    _tempAuthKeyBytes = [];
    _tempAuthKey = null;
  }


  void clearAllKeys() {
    // logger.d("Clear AES key");
    clearAESKeys();

    /// do not clear this key
    // clearLogKey();
  }

  void setCurrentKeyMaterial(KeyMaterial material) {
    _currentKeyMaterial = material;
  }

  void setSecretSaltBytes(List<int> bytes) {
    // logger.d("setAesKeyBytes: $bytes");
    _salt = bytes;
  }

  void setAesRootKeyBytes(List<int> bytes) {
    // logger.d("setAesKeyBytes: $bytes");
    _aesRootSecretKeyBytes = bytes;
  }

  void setAesKeyBytes(List<int> bytes) {
    // logger.d("setAesKeyBytes: $bytes");
    _aesEncryptionKeyBytes = bytes;
    _aesEncryptionKey = SecretKey(bytes);
  }

  void setAuthKeyBytes(List<int> bytes) {
    // logger.d("setAuthKeyBytes: $bytes");
    _aesAuthKeyBytes = bytes;
    _aesAuthKey = SecretKey(bytes);
  }

  void switchTempKeysToCurrent() {
    if (_tempAuthKeyBytes == null || _tempAesGenKeyBytes == null
    || _tempReKeyRootSecretKeyBytes == null || _tempAesEncryptionKeyBytes == null
    || _tempReKeyRootSecretKey == null || _tempAesEncryptionKey == null
    || _tempAesGenKey == null || _tempAuthKey == null) {
      return;
    }

    _aesRootSecretKeyBytes = _tempReKeyRootSecretKeyBytes;

    _aesEncryptionKeyBytes = _tempAesEncryptionKeyBytes;
    _aesEncryptionKey = _tempAesEncryptionKey;

    _aesAuthKeyBytes = _tempAuthKeyBytes;
    _aesAuthKey = _tempAuthKey;

    _aesGenKeyBytes = _tempAesGenKeyBytes;
    _aesGenKey = _tempAesGenKey;
  }

  void setLogKeyBytes(List<int> bytes) {
    logger.d("LOG: setLogKeyBytes: ${hex.encode(bytes)}");
    _logSecretKeyBytes = bytes;
    _logSecretKey = SecretKey(bytes);
  }

  Future<void> createLogKey() async {
    _logSecretKey = await algorithm_nomac.newSecretKey();
    _logSecretKeyBytes = (await _logSecretKey?.extractBytes())!;
    _logKeyMaterial = base64.encode(_logSecretKeyBytes);
    logger.d("LOG: createLogKey: ${hex.encode(_logSecretKeyBytes)}");

    KeychainManager().saveLogKey(_logKeyMaterial);
  }

  String getUUID() {
    // var uuid = Uuid();
    return _uuid.v4();
  }

  /// XOR function
  /// used for un/masking our MAC's on encrypted password items
  Uint8List xor(Uint8List a, Uint8List b) {
    if (a.lengthInBytes == 0 || b.lengthInBytes == 0) {
      throw ArgumentError.value(
          "lengthInBytes of Uint8List arguments must be > 0");
    }

    bool aIsBigger = a.lengthInBytes > b.lengthInBytes;
    int length = aIsBigger ? a.lengthInBytes : b.lengthInBytes;

    Uint8List buffer = Uint8List(length);

    for (int i = 0; i < length; i++) {
      var aa, bb;
      try {
        aa = a.elementAt(i);
      } catch (e) {
        aa = 0;
      }
      try {
        bb = b.elementAt(i);
      } catch (e) {
        bb = 0;
      }

      buffer[i] = aa ^ bb;
    }

    return buffer;
  }

  List<int> getRandomBytes(int nbytes) {
    // final rng = Random.secure();
    final rand = new List.generate(nbytes, (_) => sec_rng.nextInt(256));
    return rand;
  }


  bool validateMnemonic(String mnemonic) {
    return bip39.validateMnemonic(mnemonic);
  }

  String mnemonicToEntropy(String mnemonic) {
    final seed = bip39.mnemonicToEntropy(mnemonic);

    return seed;
  }

  String entropyToMnemonic(String entropy) {
    final mnemonic = bip39.entropyToMnemonic(entropy);
    return mnemonic;
  }

  String mnemonicToNumberString(String mnemonic, int digitLength) {
    List<int> indexes = [];

    if (digitLength < 3) {
      digitLength = 3;
    }
    /// highest max number of digits (12*1)
    if (digitLength >= 12) {
      digitLength = 12;
    }
    final arr = mnemonic.trim().split(" ");

    var added = 0;
    String digitString = "";
    // String trueIndexes = "";

    for (var word in arr) {
      indexes.add(WORDLIST.indexOf(word));
      digitString = digitString + "${WORDLIST.indexOf(word)}";
      // trueIndexes = trueIndexes + "${WORDLIST.indexOf(word)}-";
      added += 1;
      if (digitString.length+added >= digitLength+added) {
        break;
      }
    }
    // logger.d("trueIndexes: $trueIndexes");

    final len = digitString.length;

    var newestString = "";
    var added2 = 0;

    var leftOver = (digitLength % 3);
    // logger.d("digitString: ${digitString}, digitLength: ${(digitLength)}, leftOver: ${leftOver}");

    for (var j = 0 ; j < len; j++){
      newestString = newestString + digitString.substring(j, j+1);
      if ((j+1) % 3 == 0 && j > 0){
        added2 += 1;
        newestString = newestString + "-";
      }
      if ((newestString.length-added2) >= digitLength) {
        // logger.d("break: ${(newestString.length-added2)}, ${added2}, ${leftOver}");
        break;
      }
    }

    if(newestString.substring(newestString.length - 1, newestString.length) == "-") {
      newestString = newestString.substring(0, newestString.length-1);
    }
    // logger.d("newestString: $newestString");

    return newestString;
  }

  String randomMnemonic(int strength) {
    final phrase = bip39.generateMnemonic(strength: 128);
    return phrase;
  }


  /// log key
  ///
  Future<String> readLogKeyAndSet() async {
    try {
      _logKeyMaterial = await KeychainManager().readLogKey();
      var material = base64.decode(_logKeyMaterial);
      _logSecretKeyBytes = material;
      return _logKeyMaterial;
    } catch (e) {
      logger.e("Exception: $e");
      return "";
    }

  }
  ///
  /// Key Derivation.............................................................
  ///

  /// deriveKey - derives a key using PBKDF2 with password and salt
  /// called on createAccount
  Future<KeyMaterial?> deriveKey(String uuid, String password, String hint) async {
    // logger.d("PBKDF2 - deriving key");
    try {
      // final startTime = DateTime.now();
      final pbkdf2 = Pbkdf2(
        macAlgorithm: hmac_algo_512,
        iterations: _rounds,
        bits: 512,
      );

      // double strength = estimatePasswordStrength(password.trim());
      // logger.d("pwd strength: ${strength.toStringAsFixed(3)}");

      // password we want to hash
      final secretKey = SecretKey(utf8.encode(password.trim()));

      // create a random salt
      _salt = getRandomBytes(_saltLength);

      // logger.d("random salt: $_salt");

      // derive key encryption key
      final derivedSecretKey = await pbkdf2.deriveKey(
        secretKey: secretKey,
        nonce: _salt,
      );

      // final endTime = DateTime.now();

      // final timeDiff = endTime.difference(startTime);
      // logger.d("pbkdf2 time diff: ${timeDiff.inMilliseconds} ms");

      final derivedSecretKeyBytes = await derivedSecretKey.extractBytes();
      final Kx = derivedSecretKeyBytes.sublist(0,32);
      final Ky = derivedSecretKeyBytes.sublist(32,64);
      // logger.d("Kx: $Kx");
      // logger.d("Ky: $Ky");

      final secretKx = SecretKey(Kx);
      final secretKy = SecretKey(Ky);

      /// create new aes key and encrypt with nonce
      /// Generate a random 256-bit encryption key
      final _aesRootSecretKey = await algorithm_nomac.newSecretKey();

      // _aesEncryptionKeyBytes = (await _aesSecretKey?.extractBytes())!;
      _aesRootSecretKeyBytes = (await _aesRootSecretKey?.extractBytes())!;
      // logger.d("_aesRootSecretKeyBytes: $_aesRootSecretKeyBytes");

      // final words_root = bip39.entropyToMnemonic(hex.encode(_aesRootSecretKeyBytes));
      // logger.d("words_root: $words_root");

      // final dk =
      await expandSecretRootKey(_aesRootSecretKeyBytes);
      // final Ka = dk.sublist(0, 32);
      // final Kb = dk.sublist(32, 64);
      // logger.d("Ka: $Ka");
      // logger.d("Kb: $Kb");
      //
      // final Kc = xor(Uint8List.fromList(Ka), Uint8List.fromList(Kb));
      // logger.d("Kc: $Kc");

      // logger.d("_aesEncryptionKeyBytes: _aesEncryptionKeyBytes");

      /// add auth secret key, KAK (Key Authentication Key)
      // _aesAuthKey = await algorithm_nomac.newSecretKey();
      // _aesAuthKeyBytes = (await _aesAuthKey?.extractBytes())!;
      // logger.d("_aesAuthKeyBytes: $_aesAuthKeyBytes");

      /// create log key
      /// if we already have one, dont create it.
      /// only created once per device per app instance
      if (_logSecretKeyBytes == null || _logSecretKeyBytes.isEmpty) {
        await createLogKey();
      }
      // logger.d("created log key bytes: $_logSecretKeyBytes");

      // logger.d("_aesKeyBytes: $_aesSecretKeyBytes");

      // Generate a random 128-bit nonce/iv.
      final iv = algorithm_nomac.newNonce();
      // logger.d("deriveKey encryption nonce: $nonce");

      // final appendedKeys = _aesSecretKeyBytes + _aesAuthKeyBytes;
      // final appendedKeys = _aesRootSecretKeyBytes;// + _aesAuthKeyBytes;

      // logger.d("appendedKeys: $appendedKeys");

      /// Encrypt the appended keys
      final secretBox = await algorithm_nomac.encrypt(
        _aesRootSecretKeyBytes,
        secretKey: secretKx,
        nonce: iv,
      );

      // logger.d("sbox nonce: ${secretBox.nonce}");
      // logger.d("sbox mac: ${secretBox.mac.bytes}");
      // logger.d("sbox ciphertext: ${secretBox.cipherText}");

      /// check mac with iv and ciphertext
      final blob = iv + secretBox.cipherText;
      final hashedBlob = hex.decode(sha256(base64.encode(blob)));
      // logger.d("hashedBlob: ${hashedBlob}");

      final mac = await hmac_algo_256.calculateMac(
        hashedBlob,
        secretKey: secretKy,
      );

      final macBytes = mac.bytes;

      final macPhrase = bip39.entropyToMnemonic(hex.encode(macBytes));

      final macWordList = macPhrase.split(" ");

      // var confirmMacPhrase = macWordList[0] + " " + macWordList[1] + " " + macWordList[2] + " " + macWordList.last;
      // var confirmMacPhrase = macWordList[0] + " " + macWordList[1] + " " + macWordList.last;
      var confirmMacPhrase = macWordList[0] + " " + macWordList.last;

      if (AppConstants.debugKeyData) {
        logger.d("confirmMacPhrase: $confirmMacPhrase");
      }

      var keyMaterial = iv + mac.bytes + secretBox.cipherText;

      _logKeyMaterial = base64.encode(_logSecretKeyBytes);
      // logger.d("check got log key material: $_logKeyMaterial");

      if (AppConstants.debugKeyData){
        logger.d("_aesRootSecretKeyBytes: ${hex.encode(_aesRootSecretKeyBytes)}\n ");
        // logger.d("${},${},${},${},${}");
      }

      final keyId = getUUID();

      KeyMaterial keyParams = KeyMaterial(
        id: uuid,
        keyId: keyId,
        rounds: _rounds,
        salt: base64.encode(_salt),
        key: base64.encode(keyMaterial),
        hint: hint,
      );

      _currentKeyMaterial = keyParams;

      return keyParams;
    } catch (e) {
      logger.d(e);
      return null;
    }
  }

  Future<void> expandSecretRootKey(List<int> skey) async  {
    if (AppConstants.debugKeyData) {
      logger.d("expandSecretRootKey: 🔑: ${hex.encode(skey)}");
    }
    // logger.d("expandSecretRootKey: 🔑");

    if (skey.length != 32) {
      return;
    }

    final skx = skey.sublist(0, 16);
    final sky = skey.sublist(16, 32);

    final wx = bip39.entropyToMnemonic(hex.encode(skx));
    final wy = bip39.entropyToMnemonic(hex.encode(sky));
    // final salt = sky;
    // logger.d("pwd words: ${wx}");

    // logger.d("salt words: ${wy}");

    final pbkdf2 = Pbkdf2(
      macAlgorithm: hmac_algo_512,
      iterations: 2048,
      bits: 512,
    );

    final secretKey = SecretKey(utf8.encode(wx.trim()));

    // logger.d("salt utf8 words: ${utf8.encode(wy.trim()).length}: ${utf8.encode(wy.trim())}");

    // derive key encryption key
    final derivedSecretKey = await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: utf8.encode(wy.trim()),
    );
    final derivedSecretKeyBytes = await derivedSecretKey.extractBytes();

    // logger.d("derivedSecretKey: $derivedSecretKeyBytes");
    final Ka = derivedSecretKeyBytes.sublist(0, 32);
    final Kb = derivedSecretKeyBytes.sublist(32, 64);
    // logger.d("_aesSecretKeyBytes Ka: $Ka");
    // logger.d("_aesGenKeyBytes Kb: $Kb");

    // final wa = bip39.entropyToMnemonic(hex.encode(Ka));
    // final wb = bip39.entropyToMnemonic(hex.encode(Kb));
    // logger.d("Ka words: ${wa}");
    // logger.d("Kb words: ${wb}");

    final Kc = xor(Uint8List.fromList(Ka), Uint8List.fromList(Kb));
    // logger.d("_aesAuthKeyBytes Kc: $Kc");

    // final wc = bip39.entropyToMnemonic(hex.encode(Kc));
    // logger.d("Kc words: ${wc}");

    _aesEncryptionKeyBytes = Ka;
    _aesGenKeyBytes = Kb;
    _aesAuthKeyBytes = Kc;

    _aesEncryptionKey = SecretKey(Ka);
    _aesGenKey = SecretKey(Kb);
    _aesAuthKey = SecretKey(Kc);

    if (AppConstants.debugKeyData){
      logger.d("skey: $skey\n_aesEncryptionKeyBytes: ${_aesEncryptionKeyBytes}\n"
          "_aesGenKeyBytes: ${_aesGenKeyBytes}\n"
          "_aesAuthKeyBytes: ${_aesAuthKeyBytes}");
    }

    return;
  }

  Future<void> expandSecretTempRootKey(List<int> skey) async {

    if (skey.length != 32) {
      return;
    }

    final skx = skey.sublist(0, 16);
    final sky = skey.sublist(16, 32);

    final wx = bip39.entropyToMnemonic(hex.encode(skx));
    final wy = bip39.entropyToMnemonic(hex.encode(sky));
    // final salt = sky;
    // logger.d("pwd words: ${wx}");

    // logger.d("salt words: ${wy}");

    final pbkdf2 = Pbkdf2(
      macAlgorithm: hmac_algo_512,
      iterations: 2048,
      bits: 512,
    );

    final secretKey = SecretKey(utf8.encode(wx.trim()));

    // logger.d("salt utf8 words: ${utf8.encode(wy.trim()).length}: ${utf8.encode(wy.trim())}");

    // derive key encryption key
    final derivedSecretKey = await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: utf8.encode(wy.trim()),
    );
    final derivedSecretKeyBytes = await derivedSecretKey.extractBytes();

    // logger.d("derivedSecretKey: $derivedSecretKeyBytes");
    final Ka = derivedSecretKeyBytes.sublist(0, 32);
    final Kb = derivedSecretKeyBytes.sublist(32, 64);
    // logger.d("_aesEncryptionKeyBytes Ka: $Ka");
    // logger.d("_aesGenKeyBytes Kb: $Kb");

    // final wa = bip39.entropyToMnemonic(hex.encode(Ka));
    // final wb = bip39.entropyToMnemonic(hex.encode(Kb));
    // logger.d("Ka words: ${wa}");
    // logger.d("Kb words: ${wb}");

    final Kc = xor(Uint8List.fromList(Ka), Uint8List.fromList(Kb));
    // logger.d("_aesAuthKeyBytes Kc: $Kc");

    // final wc = bip39.entropyToMnemonic(hex.encode(Kc));
    // logger.d("Kc words: ${wc}");

    _tempAesEncryptionKeyBytes = Ka;
    _tempAesGenKeyBytes = Kb;
    _tempAuthKeyBytes = Kc;

    _tempAesGenKey = SecretKey(Kb);
    _tempAesEncryptionKey = SecretKey(Ka);
    _tempAuthKey = SecretKey(Kc);

    if (AppConstants.debugKeyData){
      logger.d("_tempAesEncryptionKeyBytes: ${_tempAesEncryptionKeyBytes}\n"
          "_tempAesGenKeyBytes: ${_tempAesGenKeyBytes}\n"
          "_tempAuthKeyBytes: ${_tempAuthKeyBytes}");
    }

    return;
  }

  Future<List<int>> expandKey(List<int> skey) async {
    logger.d("expandKey: 🔑");

    if (skey.length != 32) {
      return [];
    }

    final skx = skey.sublist(0, 16);
    final sky = skey.sublist(16, 32);

    final wx = bip39.entropyToMnemonic(hex.encode(skx));
    final wy = bip39.entropyToMnemonic(hex.encode(sky));
    // final salt = sky;
    if (AppConstants.debugKeyData) {
      logger.d("expanded key words:\n${wx}\n${wy}");
    }

    // logger.d("salt words: ${wy}");

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha512(),
      iterations: 2048,
      bits: 512,
    );

    final secretKey = SecretKey(utf8.encode(wx.trim()));

    final derivedSecretKey = await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: utf8.encode(wy.trim()),
    );
    final derivedSecretKeyBytes = await derivedSecretKey.extractBytes();

    if (AppConstants.debugKeyData){
      // logger.d("derivedSecretKeyBytes: ${derivedSecretKeyBytes}\n");
      logger.d("derivedSecretKeyBytes: ${hex.encode(derivedSecretKeyBytes)}\n");

    }
    return derivedSecretKeyBytes;
  }


  Future<MyDigitalIdentity?> createMyDigitalID() async {
    logger.d("createMyDigitalID");

    try {
      final cdate = DateTime.now().toIso8601String();

      final Kx = await createDigitalIdentityExchange();
      final Ky = await createDigitalIdentitySigning();

      var myId = MyDigitalIdentity(
        keyId: KeychainManager().keyId,
        version: AppConstants.myDigitalIdentityItemVersion,
        privKeyExchange: Kx, // encrypted
        privKeySignature: Ky, // encrypted
        mac: "",
        cdate: cdate,
        mdate: cdate,
      );

      final myIdMac = await hmac256(myId.toRawJson());
      myId.mac = myIdMac;

      return myId;
    } catch (e) {
      logger.w("Exception: $e");
      return null;
    }
  }

  /// Create keys for signing and key exchange
  Future<String> createDigitalIdentityExchange() async {
    logger.d("createDigitalIdentityExchange");

    try {
      // final algorithm = X25519();
      // final aliceKeyPair = await algorithm.newKeyPair();
      // logger.d('algorithm: ${algorithm}');
      // final priv = await aliceKeyPair.extractPrivateKeyBytes();
      // logger.d('aliceKeyPair Priv: ${priv}');
      // logger.d('aliceKeyPair Priv.Hex: ${hex.encode(priv)}');

      final randomSeed = getRandomBytes(32);
      // logger.d('randomSeed X25519: ${randomSeed}');
      if (AppConstants.debugKeyData){
        logger.d("randomSeed: ${randomSeed}\n");
      }

      settingsManager.doEncryption(utf8.encode(hex.encode(randomSeed)).length);

      /// base64 encoded encrypted hex string key
      final encryptedKey = await encrypt(hex.encode(randomSeed));
      // logger.d('encryptedKeyExchange: ${encryptedKey}');


      return encryptedKey;
    } catch (e) {
      // logger.d("Exception: $e");
      logger.w("Exception: $e");
      return "";
    }
  }

  /// Create keys for signing and key exchange
  /// base 64 encoded encrypted string of base64 encoded data
  Future<String> createEncryptedPeerKeyExchangeKey() async {
    logger.d("createEncryptedPeerKeyExchangeKey");

    try {
      // final algorithm = X25519();
      // final aliceKeyPair = await algorithm.newKeyPair();
      // logger.d('algorithm: ${algorithm}');
      // final priv = await aliceKeyPair.extractPrivateKeyBytes();
      // logger.d('aliceKeyPair Priv: ${priv}');
      // logger.d('aliceKeyPair Priv.Hex: ${hex.encode(priv)}');

      final randomSeed = getRandomBytes(32);
      // logger.d('randomSeed X25519: ${randomSeed}');

      final keyIndex = settingsManager.doEncryption(utf8.encode(base64.encode(randomSeed)).length);
      // logger.d("keyIndex: $keyIndex");

      /// base64 encoded encrypted hex string key
      final encryptedKey = await encrypt(base64.encode(randomSeed));
      // logger.d('encryptedKeyExchange: ${encryptedKey}');
      if (AppConstants.debugKeyData){
        logger.d("randomSeed: ${randomSeed}\n"
            "encryptedKey: ${encryptedKey}\n");
      }

      return encryptedKey;
    } catch (e) {
      // logger.d("Exception: $e");
      logger.w("Exception: $e");
      return "";
    }
  }

  /// Create keys for signing and key exchange
  Future<String> createDigitalIdentitySigning() async {
    logger.d("createDigitalIdentitySigning");

    try {
      var algorithm = getS256();

      var priv = algorithm.generatePrivateKey();
      var privKeyBytes = priv.bytes;
      // logger.d("privateKey.D: ${priv.D}");
      // logger.d("privateKey.bytes: ${priv.bytes}");
      // logger.d("privateKey.hex: ${hex.encode(priv.bytes)}");
      // logger.d("priv: $priv");

      var pub = priv.publicKey;
      var xpub = algorithm.publicKeyToCompressedHex(pub);
      // logger.d("pubKey.compressed: ${xpub.length}: ${xpub}");
      final keyIndex = settingsManager.doEncryption(utf8.encode(hex.encode(priv.bytes)).length);
      // logger.d("keyIndex: $keyIndex");

      final encryptedKey = await encrypt(hex.encode(priv.bytes));
      // logger.d('encryptedKeySigning: ${encryptedKey}');
      if (AppConstants.debugKeyData){
        logger.d("privKeyBytes: ${hex.encode(privKeyBytes)}\n"
            "pub: ${pub}\n"
            "xpub: ${xpub}\nencryptedPrivKeyBytes: $encryptedKey");
      }
      return encryptedKey;
    } catch (e) {
      // logger.d("Exception: $e");
      logger.w("Exception: $e");
      return "";
    }
  }

  /// deriveKeyCheck using PBKDF2
  /// used for checking the master password on log in
  Future<bool> deriveKeyCheck(String password, String salt) async {
    logger.d("PBKDF2 - deriveKeyCheck");

    final keyMaterial = _currentKeyMaterial;
    if (keyMaterial == null) {
      return false;
    }

    final nrounds = keyMaterial.rounds;
    // final salt = keyMaterial.salt;

    try {
      // final startTime = DateTime.now();
      final pbkdf2 = Pbkdf2(
        macAlgorithm: hmac_algo_512,
        iterations: nrounds,
        bits: 512, // 512
      );

      // double strength = estimatePasswordStrength(password.trim());
      // logger.d("master pwd strength: ${strength.toStringAsFixed(3)}");

      // password we want to hash
      // final secretKey = SecretKey(password.codeUnits);
      final secretKey = SecretKey(utf8.encode(password.trim()));

      _salt = base64.decode(salt);
      if (AppConstants.debugKeyData) {
        logger.d("derive key check: salt: $salt");
      }

      // Calculate a hash that can be stored in the database
      final derivedSecretKey = await pbkdf2.deriveKey(
        secretKey: secretKey,
        nonce: _salt,
      );


      // final endTime = DateTime.now();

      // final timeDiff = endTime.difference(startTime);
      // logger.d("pbkdf2 time diff: ${timeDiff.inMilliseconds} ms");

      final derivedSecretKeyBytes = await derivedSecretKey.extractBytes();
      final Kx = derivedSecretKeyBytes.sublist(0,32);
      final Ky = derivedSecretKeyBytes.sublist(32,64);
      // logger.d("Kx: $Kx");
      // logger.d("Ky: $Ky");
      if (AppConstants.debugKeyData){
        logger.d("Kx: ${hex.encode(Kx)}\n"
            "Ky: ${hex.encode(Ky)}\n");
      }
      final secretKx = SecretKey(Kx);
      final secretKy = SecretKey(Ky);

      // logger.d("pbkdf2 newSecretKeyBytes: $newSecretKeyBytes");

      final keyMaterial = KeychainManager().decodedKeyMaterial;

      // logger.d("keyMaterial length: ${keyMaterial.length}");
      /// iv + mac + encrypedRootKey
      if (keyMaterial.length == 16+32+32) {
        final iv = keyMaterial.sublist(0, 16);
        final mac = keyMaterial.sublist(16, 48);
        // _cipherText = keyMaterial.sublist(48, 80);
        final cipherText = keyMaterial.sublist(48, keyMaterial.length);

        if (AppConstants.debugKeyData) {
          logger.d('iv: $iv\nmac: $mac\nciphertext length: ${cipherText
              .length}: $cipherText');
        }

        /// check mac
        final blob = iv + cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));
        // logger.d("hashedBlob: ${hashedBlob}");

        final macCheck = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: secretKy,
        );

        // final secretBoxMac = xor(Uint8List.fromList(_aesAuthKeyBytes), Uint8List.fromList(macCheck.bytes));

        final encodedMac = base64.encode(mac);
        final encodedMacCheck = base64.encode(macCheck.bytes);
        if (AppConstants.debugKeyData){
          logger.d("encodedMac: ${encodedMac}\n"
              "encodedMacCheck: ${encodedMacCheck}\n");
        }

        final macPhrase = bip39.entropyToMnemonic(hex.encode(macCheck.bytes));

        final macWordList = macPhrase.split(" ");

        // var confirmMacPhrase = macWordList[0] + " " + macWordList[1] + " " + macWordList[2] + " " + macWordList.last;
        // var confirmMacPhrase = macWordList[0] + " " + macWordList[1] + " " + macWordList.last;
        var confirmMacPhrase = macWordList[0] + " " + macWordList.last;

        if (AppConstants.debugKeyData) {
          logger.d("confirmMacPhrase: $confirmMacPhrase");
        }

        if (encodedMac == encodedMacCheck) {
          List<int> empty_mac = [];
          SecretBox sbox =
              SecretBox(cipherText, nonce: iv, mac: Mac(empty_mac));

          /// Decrypt
          final rootKey = await algorithm_nomac.decrypt(
            sbox,
            secretKey: secretKx,
          );

          _aesRootSecretKeyBytes = rootKey;

          await expandSecretRootKey(rootKey);

          _logKeyMaterial = await KeychainManager().readLogKey();
          // logger.d("check got log key material: $_logKeyMaterial");

          var material = base64.decode(_logKeyMaterial);
          _logSecretKeyBytes = material;

          return true;
        }
      }
      return false;
    } catch (e) {
      logger.w(e);
      return false;
    }
  }

  /// deriveKeyCheckAgainst using PBKDF2
  /// used for checking the master password on backup items
  Future<bool> deriveKeyCheckAgainst(
    String password,
    int rounds,
    String salt,
    String keyMaterial,
  ) async {
    logger.d("PBKDF2 - deriveKeyCheckAgainst");

    try {
      // final startTime = DateTime.now();
      final pbkdf2 = Pbkdf2(
        macAlgorithm: hmac_algo_512,
        iterations: rounds,
        bits: 512,
      );

      // password we want to hash
      // final secretKey = SecretKey(password.codeUnits);
      final secretKey = SecretKey(utf8.encode(password.trim()));

      // create a random salt
      final decodedSalt = base64.decode(salt);
      // logger.d("decodedSalt: $decodedSalt");

      // Calculate a hash that can be stored in the database
      final derivedSecretKey = await pbkdf2.deriveKey(
        secretKey: secretKey,
        nonce: decodedSalt,
      );
      // logger.d("derivedSecretKey: $derivedSecretKey");

      // final endTime = DateTime.now();

      // final timeDiff = endTime.difference(startTime);
      // logger.d("pbkdf2 time diff: ${timeDiff.inMilliseconds} ms");

      final derivedSecretKeyBytes = await derivedSecretKey.extractBytes();
      final Kx = derivedSecretKeyBytes.sublist(0,32);
      final Ky = derivedSecretKeyBytes.sublist(32,64);
      if (AppConstants.debugKeyData){
        logger.d("Kx: ${hex.encode(Kx)}\n"
            "Ky: ${hex.encode(Ky)}\n");
      }

      final secretKx = SecretKey(Kx);
      final secretKy = SecretKey(Ky);

      var decodedKeyMaterial =
          base64.decode(keyMaterial);

      if (decodedKeyMaterial.length == 16+32+32) {
        final iv = decodedKeyMaterial.sublist(0, 16);
        final mac = decodedKeyMaterial.sublist(16, 48);
        final cipherText =
            decodedKeyMaterial.sublist(48, decodedKeyMaterial.length);
        logger.d("iv: ${iv}\nmac: ${mac}\ncipherText: ${cipherText}");

        /// check mac
        final blob = iv + cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));
        logger.d("hashedBlob: ${hashedBlob}");

        final macCheck = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: secretKy, //derivedSecretKey, // secretKy
        );

        final encodedMac = base64.encode(mac);
        final encodedMacCheck = base64.encode(macCheck.bytes);

        // if (AppConstants.debugKeyData){
          logger.d("encodedMac: ${encodedMac}\n"
              "encodedMacCheck: ${encodedMacCheck}\n");
        // }

        final macPhrase = bip39.entropyToMnemonic(hex.encode(macCheck.bytes));

        final macWordList = macPhrase.split(" ");

        // var confirmMacPhrase = macWordList[0] + " " + macWordList[1] + " " + macWordList[2] + " " + macWordList.last;
        // var confirmMacPhrase = macWordList[0] + " " + macWordList[1] + " " + macWordList.last;
        var confirmMacPhrase = macWordList[0] + " " + macWordList.last;

        if (AppConstants.debugKeyData) {
          logger.d("confirmMacPhrase: $confirmMacPhrase");
        }

        if (encodedMac == encodedMacCheck) {
          List<int> empty_mac = [];

          SecretBox secretBox =
              SecretBox(cipherText, nonce: iv, mac: Mac(empty_mac));

          /// Decrypt
          var rootKey = await algorithm_nomac.decrypt(
            secretBox,
            secretKey: secretKx,
          );

          _aesRootSecretKeyBytes = rootKey;

          if (AppConstants.debugKeyData){
            logger.d("rootKey: ${hex.encode(rootKey)}\n");
          }

          await expandSecretRootKey(rootKey);

          _logKeyMaterial = await KeychainManager().readLogKey();
          if (_logKeyMaterial == null || logKeyMaterial.isEmpty) {
            /// create a new log key
            /// user is restoring a backup on new device app instance
            ///
            await createLogKey();
          } else {
            var material = base64.decode(_logKeyMaterial);
            _logSecretKeyBytes = material;
          }
          logger.d("deriveKeyCheckAgainst: true");

          return true;
        }
      }
      logger.e("deriveKeyCheckAgainst: false");

      return false;
    } catch (e) {
      logger.w(e);
      return false;
    }
  }

  /// deriveNewKey - Derive new key on a master password change
  ///
  Future<KeyMaterial?> deriveNewKey(String password, String hint) async {
    // logger.d("deriveNewKey");
    final currentKeyParams = _currentKeyMaterial;
    if (currentKeyParams == null) {
      return null;
    }

    try {
      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha512(),
        iterations: currentKeyParams.rounds,
        bits: 512, // 512
      );

      if (_salt.isEmpty || _salt == null) {
        logger.e("_salt is empty!!!");
        return null;
      }

      // password we want to hash
      final secretKey = SecretKey(utf8.encode(password.trim()));

      /// generate new salt
      _salt = List.generate(_saltLength, (_) => sec_rng.nextInt(256));
      // logger.d("new salt: ${hex.encode(_salt)}\n");

      final derivedSecretKey = await pbkdf2.deriveKey(
        secretKey: secretKey,
        nonce: _salt,
      );

      final derivedSecretKeyBytes = await derivedSecretKey.extractBytes();
      final Kx = derivedSecretKeyBytes.sublist(0,32);
      final Ky = derivedSecretKeyBytes.sublist(32,64);

      final secretKx = SecretKey(Kx);
      final secretKy = SecretKey(Ky);

      if (AppConstants.debugKeyData){
        logger.d("Kx: ${Kx}\n"
            "Ky: ${Ky}\n");
      }

      if (_aesRootSecretKeyBytes.isNotEmpty) {
        final iv_new = algorithm_nomac.newNonce();

        if (AppConstants.debugKeyData){
          logger.d("rootKey: ${hex.encode(_aesRootSecretKeyBytes)}\n");
        }

        /// Encrypt root key
        final secretBox = await algorithm_nomac.encrypt(
          _aesRootSecretKeyBytes,
          secretKey: secretKx,
          nonce: iv_new,
        );

        /// compute mac
        final blob = iv_new + secretBox.cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));

        /// compute mac
        final mac = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: secretKy,
        );

        final macPhrase = bip39.entropyToMnemonic(hex.encode(mac.bytes));
        final macWordList = macPhrase.split(" ");

        // var confirmMacPhrase = macWordList[0] + " " + macWordList[1] + " " + macWordList.last;
        var confirmMacPhrase = macWordList[0] + " " + macWordList.last;
        logger.d("confirmMacPhrase: $confirmMacPhrase");
        // for (var mword in macWordList) {
        //   confirmMacPhrase = confirmMacPhrase + " " + mword;
        // }

        if (AppConstants.debugKeyData) {
          logger.d("confirmMacPhrase: $confirmMacPhrase");
          logger.d("mac: ${mac}\n");
        }

        var keyMaterial = iv_new + mac.bytes + secretBox.cipherText;

        KeyMaterial newKeyMaterial = KeyMaterial(
          id: currentKeyParams.id,
          keyId: currentKeyParams.keyId,
          salt: base64.encode(_salt),
          rounds: currentKeyParams.rounds,
          key: base64.encode(keyMaterial),
          hint: hint,
        );

        return newKeyMaterial;
      } else {
        logger.wtf("_aesRootSecretKeyBytes was empty!!!");
        return null;
      }
    } catch (e) {
      logger.w(e);
      return null;
    }
  }

  /// Used when re-keying our vault
  ///
  Future<EncryptedKey?> deriveNewKeySchedule(String password) async {
    // logger.d("PBKDF2 - deriveNewKeySchedule");
    try {
      // final startTime = DateTime.now();
      final pbkdf2 = Pbkdf2(
        macAlgorithm: hmac_algo_512,
        iterations: _rounds,
        bits: 512, // 512
      );

      if (_salt.isEmpty) {
        logger.d("_salt is empty!!!");
        return null;
      }

      var newSalt = getRandomBytes(_saltLength);
      // logger.d("newSalt: ${newSalt}");

      // double strength = estimatePasswordStrength(password.trim());
      // logger.d("master pwd strength: ${strength.toStringAsFixed(3)}");

      // final secretKey = SecretKey(password.codeUnits);
      final secretKey = SecretKey(utf8.encode(password.trim()));

      final derivedSecretKey = await pbkdf2.deriveKey(
        secretKey: secretKey,
        nonce: newSalt,
      );

      // final endTime = DateTime.now();
      // final timeDiff = endTime.difference(startTime);
      // logger.d("pbkdf2 time diff: ${timeDiff.inMilliseconds} ms");

      final derivedSecretKeyBytes = await derivedSecretKey.extractBytes();
      final Kx = derivedSecretKeyBytes.sublist(0,32);
      final Ky = derivedSecretKeyBytes.sublist(32,64);
      // logger.d("Kx: $Kx\nKy: $Ky");

      final secretKx = SecretKey(Kx);
      final secretKy = SecretKey(Ky);

      if (AppConstants.debugKeyData){
        logger.d("deriveNewKeySchedule\nKx: ${Kx}\n"
            "Ky: ${Ky}\n");
      }

      if (_aesRootSecretKeyBytes.isNotEmpty) {
        /// generate new root secret
        final newRootSecret = getRandomBytes(32);
        // logger.d("newRootSecret: ${newRootSecret}");
        if (AppConstants.debugKeyData){
          logger.d("newRootSecret: ${hex.encode(newRootSecret)}\n");
        }
        /// after we verify the vault has been ke-keyed
        /// we need to set the _aesRootKey to the temp and expand into the
        /// new symmetric keys to use
        _tempReKeyRootSecretKeyBytes = newRootSecret;
        _tempReKeyRootSecretKey = SecretKey(_tempReKeyRootSecretKeyBytes);

        var kid = getUUID();
        KeychainManager().setNewReKeyId(kid);

        await expandSecretTempRootKey(_tempReKeyRootSecretKeyBytes);
        final iv_new = algorithm_nomac.newNonce();
        // logger.d("ctr new nonce: ${newNonce.length}, $newNonce");

        /// Encrypt
        final secretBox = await algorithm_nomac.encrypt(
          newRootSecret,
          secretKey: secretKx,
          nonce: iv_new,
        );

        final blob = iv_new + secretBox.cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));
        // logger.d("hashedBlob: ${hashedBlob}");

        final mac = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: secretKy,
        );

        var keyMaterial = iv_new + mac.bytes + secretBox.cipherText;

        final kdfAlgo = EnumToString.convertToString(KDFAlgorithm.pbkdf2_512);
        final type = 0;
        final version = 0;
        final memoryPowerOf2 = 0;
        final encryptionAlgo = EnumToString.convertToString(EncryptionAlgorithm.aes_ctr_256);

        final zeroBlock = List<int>.filled(16, 0);
        final iv_keyNonce = algorithm_nomac.newNonce();

        /// Encrypt
        final secretBoxKeyNonce = await algorithm_nomac.encrypt(
          zeroBlock,
          secretKey: secretKx,
          nonce: iv_keyNonce,
        );

        /// Key nonce
        final blob_keyNoncei = iv_keyNonce + secretBoxKeyNonce.cipherText;
        // logger.d("blob_keyNoncei: ${blob_keyNoncei}");

        final hashedBlob_keyNonce = hex.decode(sha256(base64.encode(blob_keyNoncei)));
        // logger.d("hashedBlob_keyNonce: ${hashedBlob_keyNonce}");


        final mac_keyNonce = await hmac_algo_256.calculateMac(
          hashedBlob_keyNonce,
          secretKey: secretKy,
        );

        final blob_keyNonce = iv_keyNonce + mac_keyNonce.bytes + secretBoxKeyNonce.cipherText;
        // logger.d("blob_keyNonce: ${blob_keyNonce}");

        var encryptedKey = EncryptedKey(
            keyId: kid,
            derivationAlgorithm: kdfAlgo,
            salt: base64.encode(newSalt),
            rounds: rounds,
            type: type,
            version: version,
            memoryPowerOf2: memoryPowerOf2,
            encryptionAlgorithm: encryptionAlgo,
            keyMaterial: base64.encode(keyMaterial),
            keyNonce: base64.encode(blob_keyNonce),
            mac: "",
        );

        final paramsHash = sha256(encryptedKey.toRawJson());

        final keyParamsMac = await hmac_algo_256.calculateMac(
          hex.decode(paramsHash),
          secretKey: secretKy,
        );

        encryptedKey.mac = hex.encode(keyParamsMac.bytes);

        if (AppConstants.debugKeyData){
          logger.d("ek.json: ${encryptedKey.toJson()}\n");
        }

        return encryptedKey;
      } else {
        logger.w("_aesEncryptionKeyBytes was empty!!!");
        return null;
      }
    } catch (e) {
      logger.w(e);
      return null;
    }
  }


  /// Set the log key after reading it
  Future<void> decodeAndSetLogKey(String encodedLogKey) async {
    // logger.d("decodeAndSetLogKey: encodedLogKey");

    if (encodedLogKey != null && encodedLogKey.isNotEmpty) {
      final material = base64.decode(encodedLogKey);
      _logKeyMaterial = encodedLogKey;
      _logSecretKeyBytes = material;
    } else {
      logger.w("decodeAndSetLogKey: failure");
    }
  }


  /// derivePinKey using PBKDF2
  /// derives our pin code key to wrap our encryption key
  /// (and authentication key)
  Future<String> derivePinKey(String pin) async {
    logger.d("PBKDF2 - deriving key from pin");

    try {
      final startTime = DateTime.now();
      final pbkdf2 = Pbkdf2(
        macAlgorithm: hmac_algo_256,
        iterations: _roundsPin,
        bits: 256,
      );

      // pin to hash
      final secretKey = SecretKey(utf8.encode(pin.trim()));

      // create a random salt
      // final rng = Random.secure();
      final salt = List.generate(_saltLength, (_) => sec_rng.nextInt(256));

      // Calculate a hash that can be stored in the database
      final derivedSecretKey = await pbkdf2.deriveKey(
        secretKey: secretKey,
        nonce: salt,
      );

      // final endTime = DateTime.now();
      // final timeDiff = endTime.difference(startTime);
      // logger.d("pbkdf2 time diff: ${timeDiff.inMilliseconds} ms");

      final iv = algorithm_nomac.newNonce();

      final rootKey = _aesRootSecretKeyBytes;
      if (rootKey == null || rootKey.isEmpty) {
        logger.wtf("derivePinKey: rootKey is NULL");
        return "";
      }

      /// Encrypt
      final secretBox = await algorithm_nomac.encrypt(
        rootKey,
        secretKey: derivedSecretKey,
        nonce: iv,
      );

      final blob = iv + secretBox.cipherText;
      final hashedBlob = hex.decode(sha256(base64.encode(blob)));

      final mac = await hmac_algo_256.calculateMac(
        hashedBlob,
        secretKey: derivedSecretKey,
      );

      var keyMaterial = iv + mac.bytes + secretBox.cipherText;
      // logger.d("keyMaterial: ${keyMaterial.length} : $keyMaterial");

      String encodedSalt = base64.encode(salt);
      String encodedEncryptedKey = base64.encode(keyMaterial);

      final pinUuid = getUUID();
      final pinItem = PinCodeItem(
        id: pinUuid,
        version: AppConstants.pinCodeItemVersion,
        attempts: 0,
        rounds: _rounds,
        salt: encodedSalt,
        keyMaterial: encodedEncryptedKey,
        cdate: startTime.toIso8601String(),
      );

      final pinItemString = pinItem.toRawJson();

      return pinItemString;
    } catch (e) {
      logger.w(e);
      return "";
    }
  }

  /// derivePinKeyCheck
  /// checking our pin code
  Future<bool> derivePinKeyCheck(PinCodeItem item, String pin) async {
    // logger.d("PBKDF2 - deriving key check against");

    final encodedSalt = item.salt;
    final encryptedKeyMaterial = item.keyMaterial;

    try {
      // final startTime = DateTime.now();
      final pbkdf2 = Pbkdf2(
        macAlgorithm: hmac_algo_256,
        iterations: _roundsPin,
        bits: 256,
      );

      // password we want to hash
      final secretKey = SecretKey(utf8.encode(pin.trim()));
      final decodedSalt = base64.decode(encodedSalt);

      final derivedSecretKey = await pbkdf2.deriveKey(
        secretKey: secretKey,
        nonce: decodedSalt,
      );
      // final derivedSecretKeyBytes = await derivedSecretKey.extractBytes();
      // logger.d("derivedSecretKeyBytes length: ${derivedSecretKeyBytes.length}: ${derivedSecretKeyBytes}");

      // final endTime = DateTime.now();
      // final timeDiff = endTime.difference(startTime);
      // logger.d("pbkdf2 time diff: ${timeDiff.inMilliseconds} ms");

      var decodedKeyMaterial = base64.decode(encryptedKeyMaterial);
      // logger.d("decodedKeyMaterial length: ${decodedKeyMaterial.length}");

      if (decodedKeyMaterial.length == 16+32+32) {
        final iv = decodedKeyMaterial.sublist(0, 16);
        final mac = decodedKeyMaterial.sublist(16, 48);
        final cipherText =
            decodedKeyMaterial.sublist(48, decodedKeyMaterial.length);

        /// check mac
        final blob = iv + cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));

        final macCheck = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: derivedSecretKey,
        );

        final encodedMac = base64.encode(mac);
        final encodedMacCheck = base64.encode(macCheck.bytes);
        // logger.d("check mac: ${encodedMac == encodedMacCheck}");

        if (encodedMac == encodedMacCheck) {
          List<int> empty_mac = [];

          SecretBox secretBox =
              SecretBox(cipherText, nonce: iv, mac: Mac(empty_mac));

          /// Decrypt
          final rootKey = await algorithm_nomac.decrypt(
            secretBox,
            secretKey: derivedSecretKey,
          );

          _aesRootSecretKeyBytes = rootKey;

          await expandSecretRootKey(rootKey);

          _logKeyMaterial = await KeychainManager().readLogKey();

          var material = base64.decode(_logKeyMaterial);
          _logSecretKeyBytes = material;

          return true;
        }
      }
      return false;
    } catch (e) {
      logger.w(e);
      return false;
    }
  }

  /// derive key using Argon2
  /// may be used in future versions or enable the user to select which
  /// derivation method should be used
  Future<List<int>> deriveKeyArgon2(String password) async {
    logger.d("Argon2 - deriving key");
    try {
      // var password = "test";
      final argonPassword = password.toBytesLatin1();
      final argonPassword2 = password.toBytesUTF8();

      logger.d("Latin1 pwd: $argonPassword");
      logger.d("UTF8 pwd: $argonPassword2");
      // var salt = "somesalt".toBytesLatin1();
      // create a random salt
      // final rng = Random.secure();
      _salt = List.generate(_saltLength, (_) => sec_rng.nextInt(256));

      logger.d("argon2: starting time");
      final uint8Salt = Uint8List.fromList(_salt);
      logger.d("uint8Salt: $uint8Salt");

      final startTime = DateTime.now();
      var parameters = Argon2Parameters(
        Argon2Parameters.ARGON2_i,
        uint8Salt,
        secret: argonPassword2,
        version: Argon2Parameters.ARGON2_VERSION_10,
        iterations: 300,
        memoryPowerOf2: 10,
      );

      logger.d("argon2 parameters: $parameters");

      var argon2 = Argon2BytesGenerator();

      argon2.init(parameters);

      var passwordBytes = parameters.converter.convert(password);

      logger.d("Generating key from password...");

      var result = Uint8List(32);
      argon2.generateBytes(passwordBytes, result, 0, result.length);

      var resultHex = result.toHexString();
      final endTime = DateTime.now();
      final timeDiff = endTime.difference(startTime);
      logger.d("argon time diff: ${timeDiff.inMilliseconds} ms");

      logger.d("argon2 result: $resultHex");

      // final derivedKeyBytes = await derivedSecretKey.extractBytes();
      // logger.d("pbkdf2 result: $derivedKeyBytes");

      /// create new aes key and encrypt with nonce
      final algorithm = AesCtr.with256bits(macAlgorithm: hmac_algo_256);

      // Generate a random 256-bit secret key
      _aesEncryptionKey = await algorithm.newSecretKey();

      _aesEncryptionKeyBytes = (await _aesEncryptionKey?.extractBytes())!;
      // logger.d("_aesEncryptionKeyBytes: $_aesEncryptionKeyBytes");

      // Generate a random 128-bit nonce.
      final nonce = algorithm.newNonce();
      // logger.d("ctr nonce: ${_nonce.length}, $_nonce");

      final argon2SecretKey = SecretKey(result);

      /// Encrypt
      final secretBox = await algorithm.encrypt(
        _aesEncryptionKeyBytes,
        secretKey: argon2SecretKey,
        nonce: nonce,
      );
      // logger.d("ctr MAC: ${secretBox.mac}");
      // logger.d("ctr Ciphertext: ${secretBox.cipherText}");

      var keyMaterial = nonce + secretBox.mac.bytes + secretBox.cipherText;

      // logger.d("keyMaterial: ${keyMaterial.length} : $keyMaterial");

      return keyMaterial;
    } catch (e) {
      logger.w(e);
      return [];
    }
  }

  ///
  /// Encryption.............................................................
  ///

  /// general encrypt function for vault data items
  Future<String> encrypt(String plaintext) async {
    // logger.d("encrypt");
    try {
      if (_aesEncryptionKey != null && _aesAuthKey != null) {
        final iv = algorithm_nomac.newNonce();
        final encodedPlaintext = utf8.encode(plaintext);

        /// Encrypt
        final secretBox = await algorithm_nomac.encrypt(
          encodedPlaintext,
          secretKey: _aesEncryptionKey!,
          nonce: iv,
        );

        final blob = iv + secretBox.cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));

        /// check mac
        final mac = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: _aesAuthKey!,
        );

        // if (AppConstants.debugKeyData){
        //   logger.d("blob: ${blob}\n"
        //       "mac: ${mac}\n");
        // }

        var encyptedMaterial = iv + mac.bytes + secretBox.cipherText;
        return base64.encode(encyptedMaterial);
      } else {
        return "";
      }
    } catch (e) {
      logger.w(e);
      return "";
    }
  }


  /// intakes the currently encrypted item with current key
  /// and decrypts with current key, then re-encrypts with new temp root key
  Future<String> reKeyEncryption(bool ishex, String ciphertext) async {
    logger.d("reKeyEncryption");
    try {
      if (_aesEncryptionKey != null
          && _aesAuthKey != null
          && _tempReKeyRootSecretKey != null) {

        final decryptedData = await decrypt(ciphertext);
        final iv = algorithm_nomac.newNonce();

        var encodedPlaintext = utf8.encode(decryptedData);

        /// Encrypt
        final secretBox = await algorithm_nomac.encrypt(
          encodedPlaintext,
          secretKey: _tempAesEncryptionKey!,
          nonce: iv,
        );

        final blob = iv + secretBox.cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));

        /// compute mac
        final mac = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: _tempAuthKey!,
        );

        /// TODO: count encryption blocks for new key
        // await settingsManager.saveEncryptionCount(settingsManager.numEncryptions);
        // await settingsManager.saveNumBytesEncrypted(settingsManager.numBytesEncrypted);

        var encyptedMaterial = iv + mac.bytes + secretBox.cipherText;

        if (AppConstants.debugKeyData){
          logger.d("ciphertext: ${ciphertext}\n"
              "decryptedData: ${decryptedData}\n"
              "blob: ${hex.encode(blob)}"
              "mac: ${hex.encode(mac.bytes)}\nencyptedMaterial: $encyptedMaterial");
        }

        // logger.d("encyptedMaterial: ${encyptedMaterial.length} : $encyptedMaterial");
        return base64.encode(encyptedMaterial);
      } else {
        return "";
      }
    } catch (e) {
      logger.w(e);
      return "";
    }
  }

  /// Peer Key Encryption
  /// used for peer shared secret encryption
  Future<String> encryptWithKey(List<int> Kenc, List<int> Kauth, String plaintext) async {
    logger.d("encryptWithKey");
    try {
      if (Kenc != null && Kenc.length == 32 && Kauth != null && Kauth.length == 32) {
        final iv = algorithm_nomac.newNonce();
        final encodedPlaintext = utf8.encode(plaintext);

        final Skenc = SecretKey(Kenc);
        final Skauth = SecretKey(Kauth);

        /// Encrypt
        final secretBox = await algorithm_nomac.encrypt(
          encodedPlaintext,
          secretKey: Skenc,
          nonce: iv,
        );

        final blob = iv + secretBox.cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));

        /// check mac
        final mac = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: Skauth,
        );

        if (AppConstants.debugKeyData){
          logger.d("Kenc: ${Kenc}\n"
              "Kauth: ${Kauth}\n"
              "blob: ${hex.encode(blob)}"
              "mac: ${hex.encode(mac.bytes)}");
        }

        var encyptedMaterial = iv + mac.bytes + secretBox.cipherText;
        // logger.d("encyptedMaterial: ${encyptedMaterial.length} : $encyptedMaterial");
        return base64.encode(encyptedMaterial);
      } else {
        return "";
      }
    } catch (e) {
      logger.w(e);
      return "";
    }
  }


  /// generic key encryption
  Future<String> encryptWithKeyNoMac(List<int> Kenc, String plaintext) async {
    logger.d("encryptWithKeyNoMac");
    try {
      if (Kenc != null && Kenc.length == 32) {
        final iv = algorithm_nomac.newNonce();
        final encodedPlaintext = utf8.encode(plaintext);

        final key = SecretKey(Kenc);

        /// Encrypt
        final secretBox = await algorithm_nomac.encrypt(
          encodedPlaintext,
          secretKey: key,
          nonce: iv,
        );

        final encyptedMaterial = iv + secretBox.cipherText;

        if (AppConstants.debugKeyData){
          logger.d("Kenc: ${Kenc}\n"
              "encyptedMaterial: ${hex.encode(encyptedMaterial)}");
        }

        return base64.encode(encyptedMaterial);
      } else {
        return "";
      }
    } catch (e) {
      logger.w(e);
      return "";
    }
  }

  /// TODO: change this to use empty mac and compute mac manually
  /// used for encrypting backups with metadata string
  Future<String> encryptBackupVault(String plaintext, String id) async {
    // logger.d("encryptBackupVault");
    try {
      if (_aesEncryptionKey != null && _aesAuthKey != null) {
        final iv = algorithm_nomac.newNonce();
        final encodedPlaintext = utf8.encode(plaintext);

        /// Encrypt
        final secretBox = await algorithm_nomac.encrypt(
          encodedPlaintext,
          secretKey: _aesEncryptionKey!,
          nonce: iv,
        );

        /// encrypt-then-mac with added KAK and nonce
        final blob = iv + secretBox.cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));
        final idHashBytes = hex.decode(sha256(id));
        // logger.d("idHashBytes: ${sha256(id)}");

        final Kmeta = await hmac_algo_256.calculateMac(
          idHashBytes,
          secretKey: _aesAuthKey!,
        );

        final Kmeta_key = SecretKey(Kmeta.bytes);

        final mac_meta = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: Kmeta_key,
        );

        if (AppConstants.debugKeyData){
          logger.d("blob: ${hex.encode(blob)}"
              "\nKmeta: ${Kmeta}");
        }

        await settingsManager.saveNumBlocksEncrypted((settingsManager.numBytesEncrypted/16).ceil());
        await settingsManager.saveNumBytesEncrypted(settingsManager.numBytesEncrypted);

        var encyptedMaterial = iv + mac_meta.bytes + secretBox.cipherText;
        // logger.d("encyptedMaterial: ${encyptedMaterial.length} : encyptedMaterial");
        return base64.encode(encyptedMaterial);
      } else {
        return "";
      }
    } catch (e) {
      logger.e("Exception1: $e");
      return "";
    }
  }


  /// This is for encrypting recovery keys.. no need to check bytes counted
  ///
  Future<String> encryptRecoveryKey(SecretKey key, List<int> data) async {
    logger.d("encryptRecoveryKey");
    try {
      if (key != null && data.isNotEmpty) {
        final iv = algorithm_nomac.newNonce();

        /// Encrypt
        final secretBox = await algorithm_nomac.encrypt(
          data,
          secretKey: key,
          nonce: iv,
        );

        final blob = iv + secretBox.cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));

        /// extract bytes and hash key for mac
        final keyBytes = await key.extractBytes();
        final hashedKeyBytes = sha256(base64.encode(keyBytes));
        final hashedKey = SecretKey(hex.decode(hashedKeyBytes));

        /// compute mac
        final mac = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: hashedKey,
        );

        if (AppConstants.debugKeyData){
          final kbytes = await key.extractBytes();
          logger.d("data: ${data}\n"
              "key: ${kbytes}"
              "blob: ${blob}\nmac: $mac");
        }

        final encyptedMaterial = iv + mac.bytes + secretBox.cipherText;
        // logger.d("encyptedMaterial: ${encyptedMaterial.length} : $encyptedMaterial");
        return base64.encode(encyptedMaterial);
      } else {
        return "";
      }
    } catch (e) {
      logger.w(e);
      return "";
    }
  }


  /// 2-Key Encryption with Authentication
  /// (unimplemented)
  ///
  Future<String> superEncryption(List<int> Kenc, List<int> Kauth, List<int> iv, String plaintext) async {
    logger.d("superEncryption");
    try {
      if (Kenc != null && Kenc.length == 32 && Kauth != null && Kauth.length == 32) {

        final zeros_32 = List.filled(32, 0);  // used for session encryption key
        final zeros_64 = List.filled(64, 0);  // used for authentication key stream

        final encodedPlaintext = utf8.encode(plaintext);

        /// root keys
        final Skenc = SecretKey(Kenc);
        final Skauth = SecretKey(Kauth);

        /// produce key stream for session encryption key
        final encryptionKeyStream = await algorithm_nomac.encrypt(
          zeros_32,
          secretKey: Skenc,
          nonce: iv,
        );

        final sessionEncryptionKey = SecretKey(encryptionKeyStream.cipherText);

        /// produces the authentication iv/key stream
        final authenticationKeyStream = await algorithm_nomac.encrypt(
          zeros_64,
          secretKey: Skauth,
          nonce: iv,
        );

        /// compute the merkle leaf nodes of our authentication key stream
        final authNode1 = sha256(hex.encode(authenticationKeyStream.cipherText.sublist(0,32)));
        final authNode2 = sha256(hex.encode(authenticationKeyStream.cipherText.sublist(32,64)));

        /// compute our session authentication key (merkle root)
        final authKey = sha256(authNode1 + authNode2);
        final sessionAuthenticationKey = SecretKey(hex.decode(authKey));

        var iv_xor = authenticationKeyStream.cipherText;

        /// XOR all the authentication key stream blocks (16 bytes) together
        while (iv_xor.length != 16) {
          final x =
          Uint8List.fromList(authenticationKeyStream.cipherText.sublist(0, (iv_xor.length! / 2).toInt()));
          final y = Uint8List.fromList(authenticationKeyStream.cipherText.sublist(
              (iv_xor.length! / 2).toInt(), (iv_xor.length!).toInt()));

          iv_xor = xor(x, y);
        }

        /// XOR the result (iv_xor) back upon our authentication key stream to
        /// get the inverse leaves
        final inverseAuthKeyStream = await _processKey(authenticationKeyStream.cipherText);

        /// Pick a random iv block from the authentication key stream.
        /// This iv will be used for encryption with the session encryption key.
        /// Here we just pick the first block for simplicity
        final iv_enc = authenticationKeyStream.cipherText.sublist(0, 16);

        /// Choose the same respective iv block from the inverse auth leaf set.
        /// This iv will be used for encryption with the computed mac key.
        final iv_auth = inverseAuthKeyStream.sublist(0, 16);


        /// encrypt-then-mac protocol
        ///
        /// encrypt the data (1st pass)
        final ciphertext1 = await algorithm_nomac.encrypt(
          encodedPlaintext,
          secretKey: sessionEncryptionKey,
          nonce: iv_enc,
        );
        // logger.d("ciphertext1: ${ciphertext1}");

        final blob = iv_enc + ciphertext1.cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));

        /// compute the mac
        final mac = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: sessionAuthenticationKey!,
        );

        /// use the mac as a key for 2nd encryption layer
        final macKey = SecretKey(mac.bytes);

        /// encrypt again with mac key (2nd pass)
        final ciphertext2 = await algorithm_nomac.encrypt(
          ciphertext1.cipherText,
          secretKey: macKey,
          nonce: iv_auth,
        );
        // logger.d("ciphertext2: ${ciphertext2}");

        /// concat the 2 iv's together
        final ivs = iv_enc + iv_auth;

        /// XOR the concatenated ivs and the mac key
        final privateMac = xor(Uint8List.fromList(ivs), Uint8List.fromList(mac.bytes));

        final encryptedMaterial = iv + privateMac + ciphertext2.cipherText;

        return base64.encode(encryptedMaterial);
      } else {
        return "";
      }
    } catch (e) {
      logger.w(e);
      return "";
    }
  }

  Future<String> superDecryption(List<int> Kenc, List<int> Kauth, List<int> iv, String ciphertext) async {
    logger.d("superDecryption");
    try {
      if (Kenc != null && Kenc.length == 32 && Kauth != null && Kauth.length == 32) {

        final zeros_32 = List.filled(32, 0);
        final zeros_64 = List.filled(64, 0);

        final decodedCiphertext = base64.decode(ciphertext);
        final iv = decodedCiphertext.sublist(0, 16);
        final privateMac = decodedCiphertext.sublist(16, 48);
        final ciphertextLayer2 = decodedCiphertext.sublist(48, decodedCiphertext.length);

        /// root keys
        final Skenc = SecretKey(Kenc);
        final Skauth = SecretKey(Kauth);

        /// produce encryption key stream for session encryption key
        final encryptionKeyStream = await algorithm_nomac.encrypt(
          zeros_32,
          secretKey: Skenc,
          nonce: iv,
        );

        final sessionEncryptionKey = SecretKey(encryptionKeyStream.cipherText);

        /// produces the authentication iv stream (this is our source of magic)
        final authenticationKeyStream = await algorithm_nomac.encrypt(
          zeros_64,
          secretKey: Skauth,
          nonce: iv,
        );

        /// compute the merkle leaf nodes of our authentication key stream
        final authNode1 = sha256(hex.encode(authenticationKeyStream.cipherText.sublist(0,32)));
        final authNode2 = sha256(hex.encode(authenticationKeyStream.cipherText.sublist(32,64)));

        /// compute our session authentication key (merkle root)
        final authKey = sha256(authNode1 + authNode2);
        final sessionAuthenticationKey = SecretKey(hex.decode(authKey));

        var iv_xor = authenticationKeyStream.cipherText;

        /// get our XOR value from all auth iv leaves
        while (iv_xor.length != 16) {
          final x =
          Uint8List.fromList(authenticationKeyStream.cipherText.sublist(0, (iv_xor.length! / 2).toInt()));
          final y = Uint8List.fromList(authenticationKeyStream.cipherText.sublist(
              (iv_xor.length! / 2).toInt(), (iv_xor.length!).toInt()));

          iv_xor = xor(x, y);
        }

        /// XOR the result (iv_xor) back upon our authentication key stream to
        /// get the inverse leaves
        final inverseAuthKeyStream = await _processKey(authenticationKeyStream.cipherText);


        List<int> iv_enc = [];
        List<int> iv_auth = [];
        List<int> ciphertextLayer1 = [];
        bool isValid = false;

        int num_iv_leaves = (authenticationKeyStream.cipherText.length/16).toInt();

        /// Do work and check each IV block until we find the correct one that
        /// decrypts and authenticates our ciphertext
        for (var index = 0; index < num_iv_leaves; index++) {
          /// Pick a random iv from the authIVStream
          iv_enc = authenticationKeyStream.cipherText.sublist(16*index, 16*(index+1));
          // logger.d("iv_enc: ${iv_enc}");

          /// Choose the same respective IV set from the inverse set
          iv_auth = inverseAuthKeyStream.sublist(16*index, 16*(index+1));
          // logger.d("iv_auth: ${iv_auth}");

          /// concat iv's and xor with our private mac to get the macKey
          final xor_mac = xor(Uint8List.fromList(iv_enc + iv_auth), Uint8List.fromList(privateMac));
          final macKey = SecretKey(xor_mac);

          SecretBox secretBox1 =
          SecretBox(ciphertextLayer2, nonce: iv_auth, mac: Mac([]));

          /// Decrypt outer layer
          ciphertextLayer1 = await algorithm_nomac.decrypt(
            secretBox1,
            secretKey: macKey,
          );

          final blob = iv_enc + ciphertextLayer1;
          final hashedBlob = hex.decode(sha256(base64.encode(blob)));

          /// compute the mac
          final mac = await hmac_algo_256.calculateMac(
            hashedBlob,
            secretKey: sessionAuthenticationKey!,
          );

          /// check the mac
          if (hex.encode(mac.bytes) == hex.encode(xor_mac)) {
            logger.d("success!!");
            isValid = true;
            break;
          }
        }

        if (!isValid) {
          return "";
        }

        SecretBox secretBox2 =
        SecretBox(ciphertextLayer1, nonce: iv_enc, mac: Mac([]));

        /// Decrypt final layer
        final plaintext = await algorithm_nomac.decrypt(
          secretBox2,
          secretKey: sessionEncryptionKey,
        );
        // logger.d("plaintext: ${utf8.decode(plaintext)}");

        return utf8.decode(plaintext);
      } else {
        return "";
      }
    } catch (e) {
      logger.w(e);
      return "";
    }
  }


  Future<List<int>> _processKey(List<int> bytes) async {
    List<int> xorList = bytes;

    while (xorList.length != 16) {
      final x =
      Uint8List.fromList(bytes.sublist(0, (xorList.length! / 2).toInt()));
      final y = Uint8List.fromList(bytes.sublist(
          (xorList.length! / 2).toInt(), (xorList.length!).toInt()));

      xorList = xor(x, y);
    }

    List<int> xorInverseList = [];

    for (var index = 0; index < 4; index++) {
      final xx = Uint8List.fromList(xorList);
      final y = Uint8List.fromList(bytes.sublist(index * 16, 16 * (index + 1)));
      // logger.d("y[${index}]: ${y}");
      xorInverseList.addAll(xor(xx, y));
    }

    // logger.d("xorInverseList[${xorInverseList.length}]: ${xorInverseList}");
    return xorInverseList;
  }


  /// decrypt vault data items
  ///
  Future<String> decrypt(String blob) async {
    // logger.d("decrypt");
    try {
      var keyMaterial = base64.decode(blob);
      if (_aesEncryptionKey != null && _aesAuthKey != null) {
        final iv = keyMaterial.sublist(0, 16);
        final mac = keyMaterial.sublist(16, 48);
        final cipherText = keyMaterial.sublist(48, keyMaterial.length);

        final cipherBlob = iv + cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(cipherBlob)));

        final checkMac = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: _aesAuthKey!,
        );

        final encodedMac = base64.encode(mac);
        final encodedMacCheck = base64.encode(checkMac.bytes);
        if (encodedMac != encodedMacCheck) {
          logger.w("$blob:\ncheck mac: ${encodedMac == encodedMacCheck}\nencodedMac: $encodedMac\nencodedMacCheck: $encodedMacCheck");
        }

        if (encodedMac == encodedMacCheck) {
          List<int> empty_mac = [];

          SecretBox secretBox =
          SecretBox(cipherText, nonce: iv, mac: Mac(empty_mac));

          /// Decrypt
          final plainTextBytes = await algorithm_nomac.decrypt(
            secretBox,
            secretKey: _aesEncryptionKey!,
          );

          final plainText = utf8.decode(plainTextBytes);
          return plainText;
        }
        else {
          logger.w("decrypt failure: mac check failed");
        }
      }
      return "";
    } catch (e) {
      logger.w(e);
      return "";
    }
  }


  /// Used for Recovery Key decryption
  Future<List<int>> decryptRecoveryKey(SecretKey key, String data) async {
    logger.d("decryptRecoveryKey");
    try {
      if (key != null && data.isNotEmpty) {
        final encodedBlob = base64.decode(data);

        final iv = encodedBlob.sublist(0, 16);
        final mac = encodedBlob.sublist(16, 16+32);
        final ciphertext = encodedBlob.sublist(16+32, encodedBlob.length);

        final blob = iv + ciphertext;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));

        /// extract bytes and hash key for mac
        final keyBytes = await key.extractBytes();
        final hashedKeyBytes = sha256(base64.encode(keyBytes));
        final hashedKey = SecretKey(hex.decode(hashedKeyBytes));

        /// check mac
        final macCheck = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: hashedKey,
        );

        final encodedMac = base64.encode(mac);
        final encodedMacCheck = base64.encode(macCheck.bytes);
        if (AppConstants.debugKeyData){
          logger.d("check mac: ${encodedMac == encodedMacCheck}"
              "\nmac: ${hex.encode(mac)}");
        }

        if (encodedMac == encodedMacCheck) {
          final secretBox = SecretBox(ciphertext, nonce: iv, mac: Mac([]));

          /// decrypt
          final decryptedData = await algorithm_nomac.decrypt(
            secretBox,
            secretKey: key,
          );

          return decryptedData;
        } else {
          logger.w("mac check failed");
          return [];
        }
      } else {
        return [];
      }
    } catch (e) {
      logger.w("Exception: $e");
      return [];
    }
  }


  /// GEO LOCK ENCRYPTION/DECRYPTION ...........................................
  ///
  ///
  Future<List<List<int>>> geoConvertCoords(double lat, double long, List<int> nonce) async {

    /// give different coordinates but within the range of the encrypted token window
    // final lat_min_new = lat;
    // final long_min_new = long;

    // final lat_min_str2 = lat.toStringAsFixed(4);
    // logger.d("lat_min_str2: $lat_min_str2");
    //
    // final lon_min_str2 = long.toStringAsFixed(4);
    // logger.d("lon_min_str2: $lon_min_str2");

    /// New code......
    var lat_min_str = lat.toStringAsFixed(5);
    // logger.d("lat_min_str: $lat_min_str");
    if (kDebugMode && AppConstants.debugKeyData) {
      logger.d("lat_min_str: $lat_min_str");
    }

    var lon_min_str = long.toStringAsFixed(5);
    // logger.d("lon_min_str: $lon_min_str");
    if (kDebugMode && AppConstants.debugKeyData) {
      logger.d("lon_min_str: $lon_min_str");
    }

    lat_min_str = lat_min_str.substring(0, lat_min_str.length-1);
    lon_min_str = lon_min_str.substring(0, lon_min_str.length-1);

    /// End New code......

    final lat_min_int = lat_min_str.replaceAll(".", "");
    // logger.d("lat_min_int: $lat_min_int");

    final lon_min_int = lon_min_str.replaceAll(".", "");
    // logger.d("lon_min_int: $lon_min_int");

    var lat_min_int_abs = lat_min_int;
    final lat_min_negative = lat_min_int.contains("-");// .replaceAll(".", "");
    if (lat_min_negative) {
      lat_min_int_abs = lat_min_int.replaceAll("-", "");
      // logger.d("lat_min_int_abs: $lat_min_int_abs");
    }

    var lon_min_int_abs = lon_min_int;
    final lon_min_negative = lon_min_int.contains("-");// .replaceAll(".", "");
    if (lon_min_negative) {
      lon_min_int_abs = lon_min_int.replaceAll("-", "");
      // logger.d("lon_min_int_abs: $lon_min_int_abs");
    }

    final lat_min_bigNum = int.parse(lat_min_int_abs);
    // logger.d("lat_min_bigNum: $lat_min_bigNum");
    if (kDebugMode && AppConstants.debugKeyData) {
      logger.d("lat_min_bigNum: $lat_min_bigNum");
    }

    final lon_min_bigNum = int.parse(lon_min_int_abs);
    // logger.d("lon_min_bigNum: $lon_min_bigNum");
    if (kDebugMode && AppConstants.debugKeyData) {
      logger.d("lon_min_bigNum: $lon_min_bigNum");
    }


    var bigNumHexLat = lat_min_bigNum.toRadixString(16);
    // logger.d("bigNumHexLat: $bigNumHexLat");


    var bigNumHexLon = lon_min_bigNum.toRadixString(16);
    // logger.d("bigNumHexLon: $bigNumHexLon");

    if (bigNumHexLat.length % 2 == 1) {
      bigNumHexLat = "0" + bigNumHexLat;
      // logger.d("bigNumHexLat2: $bigNumHexLat");
    }

    if (bigNumHexLon.length % 2 == 1) {
      bigNumHexLon = "0" + bigNumHexLon;
      // logger.d("bigNumHexLon2: $bigNumHexLon");
    }

    final bigNumDataLat = hex.decode(bigNumHexLat);
    // logger.d("bigNumDataLat: $bigNumDataLat");

    final bigNumDataLon = hex.decode(bigNumHexLon);
    // logger.d("bigNumDataLon: $bigNumDataLon");

    /// add data to preserve positive and negative numbers
    List<int> bigNumDataLatNorm = [];
    if (lat_min_negative) {
      bigNumDataLatNorm.add(1);
    } else {
      bigNumDataLatNorm.add(0);
    }

    List<int> bigNumDataLonNorm = [];
    if (lon_min_negative) {
      bigNumDataLonNorm.add(1);
    } else {
      bigNumDataLonNorm.add(0);
    }
    bigNumDataLatNorm += bigNumDataLat;
    bigNumDataLonNorm += bigNumDataLon;

    /// our lat/long with random nonce
    final iv_lat = nonce.sublist(0, nonce.length - bigNumDataLatNorm.length) + bigNumDataLatNorm;
    // logger.d("iv_lat: $iv_lat");

    final iv_long = nonce.sublist(0, nonce.length - bigNumDataLonNorm.length) + bigNumDataLonNorm;
    // logger.d("iv_long: $iv_long");

    return [iv_lat, iv_long];
  }


  Future<EncryptedGeoLockItem?> geoEncrypt(double lat, double long, String plaintext) async {
    logger.d("geoEncrypt............");
    final algorithm2 = AesCtr.with256bits(macAlgorithm: hmac_algo_256);

    try {
      if (_aesEncryptionKey != null && _aesAuthKey != null) {
        final nonce = algorithm_nomac.newNonce();
        logger.d("nonce: $nonce");


        /// TODO: careful of lat/long edge cases
        /// lat = -90, 90, dont go above 90
        /// long = -180 to 180, dont go above 180, wrap from -179 to -180 to 180 to 179
        ///  the Equator has a latitude of 0°, the North pole has a latitude of 90° north (written 90° N or +90°), and the South pole has a latitude of -90°.
        ///
        /// The Prime Meridian has a longitude of 0° that goes through
        /// Greenwich, England. The International Date Line (IDL) roughly
        /// follows the 180° longitude. A longitude with a positive value
        /// falls in the eastern hemisphere and the negative value falls
        /// in the western hemisphere.
        ///
        //
        //
        //     Valid longitudes are from -180 to 180 degrees.
        //
        //     Latitudes are supposed to be from -90 degrees to 90 degrees,
        //     but areas very near to the poles are not indexable.
        //
        // So exact limits, as specified by
        // EPSG:900913 / EPSG:3785 / OSGEO:41001 are the following:
        //
        // Valid longitudes are from -180 to 180 degrees.
        // Valid latitudes are from -85.05112878 to 85.05112878 degrees.
        ///
        /// do absolute values here and check for negatives here...
        ///

        ///  do overflow checks here
        ///
        // if ((lat - .0008 < -90) || (lat + .0008 > 90)) {
        //
        // }
        // if ((long - .0008 < -180) || (long + .0008 > 180)) {
        //
        // }

        bool isLatNegative = false;
        if (lat < 0) {
          isLatNegative = true;
        }

        bool isLongNegative = false;
        if (long < 0) {
          isLongNegative = true;
        }

        /// TODO: change this back after testing
        if (AppConstants.debugKeyData) {
          logger.d("lat:$isLatNegative: $lat");
          logger.d("long:$isLongNegative: $long");
        }

        var lat_min = (lat).abs() - 0.0016;
        // final long_min = long - 0.0008;
        var long_min = (long).abs() - 0.0016;

        if (isLatNegative) {
          lat_min = -lat_min;
        }
        if (isLongNegative) {
          long_min = -long_min;
        }

        final array = await geoConvertCoords(lat_min, long_min, nonce);
        if (array.length != 2) {
          return null;
        }

        final iv_lat = array[0];
        final iv_long = array[1];

        /// TODO: change this back after testing
        if (!AppConstants.debugKeyData) {
          logger.d("iv_lat: $iv_lat");
          logger.d("iv_long: $iv_long");
        }

        /// generate our 2 keys that are combined to form 1 encryption key
        final Ka = algorithm_nomac.newNonce();
        final Kb = algorithm_nomac.newNonce();
        if (AppConstants.debugKeyData) {
          logger.d("Ka: $Ka");
          logger.d("Kb: $Kb");
        }


        final Kgeo = Ka + Kb;
        final geoSecretKey = SecretKey(Kgeo);

        /// Encrypt
        final secretBoxGeo = await algorithm2.encrypt(
          utf8.encode(plaintext),
          secretKey: geoSecretKey,
          nonce: nonce,
        );

        final geoEncryptedData = secretBoxGeo.nonce + secretBoxGeo.mac.bytes + secretBoxGeo.cipherText;

        /// create a list of both keys, 16x16
        List<int> Ka_tokens = [];
        for (var i = 0; i<32; i++) {
          Ka_tokens.addAll(Ka);
        }

        List<int> Kb_tokens = [];
        for (var i = 0; i<32; i++) {
          Kb_tokens.addAll(Kb);
        }

        // logger.d("Ka_tokens: ${Ka_tokens.length}: ${Ka_tokens}");
        // logger.d("Kb_tokens: ${Kb_tokens.length}: ${Kb_tokens}");

        final base64ATokens = base64.encode(Ka_tokens);
        final base64BTokens = base64.encode(Kb_tokens);

        /// encrypt our key arrays with the lat/long iv values
        final Eka = await encryptGeoToken(base64ATokens, iv_lat);
        // logger.d("Eka: ${Eka.length} : $Eka");
        final Eka_blob = base64.decode(Eka);
        // logger.d("Eka decoded: ${Eka_blob.length} : ${Eka_blob}");

        final Ekb = await encryptGeoToken(base64BTokens, iv_long);
        // logger.d("Ekb: ${Ekb.length} : $Ekb");
        final Ekb_blob = base64.decode(Ekb);
        // logger.d("Ekb decoded: ${Ekb_blob.length} : ${Ekb_blob}");

        /// get the list of encrypted tokens and save
        final owner_lat_tokens = Eka_blob.sublist(16, Eka_blob.length);
        // logger.d("owner_lat_tokens: ${owner_lat_tokens.length} : ${owner_lat_tokens}");

        final owner_long_tokens = Ekb_blob.sublist(16, Ekb_blob.length);
        // logger.d("owner_long_tokens: ${owner_long_tokens.length} : ${owner_long_tokens}");

        final encryptedGeoLockItem = EncryptedGeoLockItem(
          version: AppConstants.encryptedGeoLockItemVersion,
            iv: base64.encode(nonce),
            lat_tokens: base64.encode(owner_lat_tokens),
            long_tokens: base64.encode(owner_long_tokens),
            encryptedPassword: base64.encode(geoEncryptedData),
        );

        return encryptedGeoLockItem;
      }

      return null;
    } catch (e) {
      logger.d(e);
      return null;
    }

  }


  Future<DecryptedGeoLockItem?> geoDecrypt(
      double lat,
      double long,
      List<int> owner_lat_tokens,
      List<int> owner_long_tokens,
      String ciphertext,
      ) async {
    logger.d("geoDecrypt............");

    // logger.d("decrypt lat: $lat");
    // logger.d("decrypt long: $long");
    // logger.d("ciphertext: $ciphertext");

    final algorithm2 = AesCtr.with256bits(macAlgorithm: hmac_algo_256);

    final decodedCiphertext = base64.decode(ciphertext);
    // logger.d("decodedCiphertext: $decodedCiphertext");

    final iv = decodedCiphertext.sublist(0, 16);
    final mac = decodedCiphertext.sublist(16, 48);
    final ciphertext2 = decodedCiphertext.sublist(48, decodedCiphertext.length);

    final arr = await geoConvertCoords(lat, long, iv);
    if (arr.length != 2) {
      return null;
    }

    final iv_lat = arr[0];
    final iv_long = arr[1];
    // logger.d("iv lat: $iv_lat");
    // logger.d("iv long: $iv_long");

    var zero_token = List<int>.filled(16, 0);
    // logger.d("zero token: ${base64.encode(zero_token)}");

    /// encrypt a zero filled 16 byte value to get our token
    final Dka = await encryptGeoToken(base64.encode(zero_token), iv_lat);
    // logger.d("Dka: ${Dka.length} : $Dka");
    final Dka_blob = base64.decode(Dka);
    // logger.d("Dka_blob decoded: ${Dka_blob.length} : ${Dka_blob}");

    final Dkb = await encryptGeoToken(base64.encode(zero_token), iv_long);
    // logger.d("Dkb: ${Dkb.length} : $Dkb");
    final Dkb_blob = base64.decode(Dkb);
    // logger.d("Dkb_blob decoded: ${Dkb_blob.length} : ${Dkb_blob}");

    /// compute the token to xor with our token lists
    final user_lat_token = Dka_blob.sublist(48, Dka_blob.length);
    // logger.d("user_lat_token: ${user_lat_token.length} : $user_lat_token");
    final user_long_token = Dkb_blob.sublist(48, Dkb_blob.length);
    // logger.d("user_long_token: ${user_long_token.length} : $user_long_token");

    /// XOR sections of Eka_blob and Ekb_blob with the two tokens
    ///
    /// owner_lat_tokens, owner_long_tokens

    List convertedLatTokens = [];
    for (var i = 0; i < owner_lat_tokens.length/16; i++) {
      final lat_tok = owner_lat_tokens.sublist(i*16, i*16+16);
      final xorTok = xor(Uint8List.fromList(lat_tok), Uint8List.fromList(user_lat_token));
      convertedLatTokens.add(xorTok);
    }
    // logger.d("convertedLatTokens: ${convertedLatTokens.length} : $convertedLatTokens");

    List convertedLongTokens = [];
    for (var i = 0; i < owner_long_tokens.length/16; i++) {
      final long_tok = owner_long_tokens.sublist(i*16, i*16+16);
      final xorTok = xor(Uint8List.fromList(long_tok), Uint8List.fromList(user_long_token));
      convertedLongTokens.add(xorTok);
    }
    // logger.d("convertedLongTokens: ${convertedLongTokens.length} : $convertedLongTokens");

    DecryptedGeoLockItem? dItem;
    var foundKeys = false;
    var i = 0;
    // var j = 0;
    for (var check_lat_tok in convertedLatTokens) {
      // final lat_tok = convertedLatTokens.sublist(i * 16, i * 16 + 16);
      if (foundKeys) {
        break;
      }
      var j = 0;
      for (var check_long_tok in convertedLongTokens) {
        // final long_tok = convertedLongTokens.sublist(j * 16, j * 16 + 16);
        j++;
        if (foundKeys) {
          break;
        }
        final test_geo_key = check_lat_tok + check_long_tok;
        // logger.d("$test_geo_key");
        final geoSecretKey_check = SecretKey(test_geo_key as List<int>);

        SecretBox sbox = SecretBox(ciphertext2, nonce: iv, mac: Mac(mac));
        try {
          final secretBoxGeoDecrypt = await algorithm2.decrypt(
            sbox,
            secretKey: geoSecretKey_check,
          );

          if (secretBoxGeoDecrypt != null) {
            // logger.d("Found Keys: $check_lat_tok & $check_long_tok");
            // logger.d("Found Keys indexes: $i && ${j-1}");
            // WidgetUtils.showSnackBar(context, "$i, $j");
            WidgetUtils.showToastMessage("${i}, ${j-1}", 1);

            foundKeys = true;
            dItem = DecryptedGeoLockItem(
                index_lat: i,
                index_long: j-1,
                decryptedPassword: utf8.decode(secretBoxGeoDecrypt),
            );

            return dItem;
          }

          // j++;
        } catch (e) {
          logger.e(e);
          continue;
        }

        if (foundKeys) {
          break;
        }
      }
      i++;
    }

    WidgetUtils.showToastMessage("Out Of Range!!!", 1);
    return null;
  }

  /// Used for GEO Token encryption
  Future<String> encryptGeoToken(String plaintext, List<int> iv) async {
    // logger.d("encryptGeoToken: $iv");
    try {
      if (_aesEncryptionKey != null && _aesAuthKey != null) {

        final decodedPlaintext = base64.decode(plaintext);

        /// Encrypt
        final secretBox = await algorithm_nomac.encrypt(
          decodedPlaintext,
          secretKey: _aesEncryptionKey!,
          nonce: iv,
        );

        final blob = iv + secretBox.cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));

        /// check mac
        final mac = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: _aesAuthKey!,
        );

        var encyptedMaterial = iv + mac.bytes + secretBox.cipherText;
        // logger.d("encyptedMaterial: ${encyptedMaterial.length} : $encyptedMaterial");
        return base64.encode(encyptedMaterial);
      } else {
        return "";
      }
    } catch (e) {
      logger.w("Exception: $e");
      return "";
    }
  }

  /// Used for Token decryption
  Future<String> decryptGeoData(String data) async {
    // logger.d("decryptGeoData");
    try {
      if (_aesEncryptionKey != null && _aesAuthKey != null) {
        final encodedBlob = base64.decode(data);

        final iv = encodedBlob.sublist(0, 16);
        final mac = encodedBlob.sublist(16, 16+32);
        final ciphertext = encodedBlob.sublist(16+32, encodedBlob.length);

        final blob = iv + ciphertext;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));

        /// check mac
        final macCheck = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: _aesAuthKey!,
        );

        final encodedMac = base64.encode(mac);
        final encodedMacCheck = base64.encode(macCheck.bytes);

        if (encodedMac == encodedMacCheck) {
          final secretBox = SecretBox(ciphertext, nonce: iv, mac: Mac([]));

          /// decrypt
          final decryptedData = await algorithm_nomac.decrypt(
            secretBox,
            secretKey: _aesEncryptionKey!,
          );

          return utf8.decode(decryptedData);

        } else {
          logger.d("mac check failed");
          return "";
        }

      } else {
        return "";
      }
    } catch (e) {
      logger.d("Exception: $e");
      return "";
    }
  }


  /// used for decrypting with peer shared secret
  ///
  Future<String> decryptWithKey(List<int> Kenc, List<int> Kauth, String blob) async {
    logger.d("decryptWithKey");
    try {
      var keyMaterial = base64.decode(blob);
      if (Kenc != null && Kenc.length == 32
          && Kauth != null && Kauth.length == 32) {
        final iv = keyMaterial.sublist(0, 16);
        final mac = keyMaterial.sublist(16, 48);
        final cipherText = keyMaterial.sublist(48, keyMaterial.length);

        final Skenc = SecretKey(Kenc);
        final Skauth = SecretKey(Kauth);

        /// compute macs and verify
        final blob = iv + cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));

        final checkMac = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: Skauth,
        );

        final encodedMac = base64.encode(mac);
        final encodedMacCheck = base64.encode(checkMac.bytes);
        // logger.d("check mac: ${encodedMac == encodedMacCheck}\nencodedMac: $encodedMac\nencodedMacCheck: $encodedMacCheck");

        if (AppConstants.debugKeyData){
          logger.d("Kenc: $Kenc\nKeauth: $Kauth"
              "\ncheck mac: ${encodedMac == encodedMacCheck}"
              "\nblob: ${hex.encode(blob)}\nmac: ${hex.encode(mac)}");
        }

        if (encodedMac == encodedMacCheck) {
          List<int> empty_mac = [];

          SecretBox secretBox =
          SecretBox(cipherText, nonce: iv, mac: Mac(empty_mac));

          /// Decrypt
          final plainTextBytes = await algorithm_nomac.decrypt(
            secretBox,
            secretKey: Skenc,
          );

          final plainText = utf8.decode(plainTextBytes);
          return plainText;
        }
        else {
          logger.w("decrypt failure: mac check failed");
        }
      }
      return "";
    } catch (e) {
      logger.w("Exception Caught: $e");
      return "";
    }
  }

  /// decrypt items
  /// used for public peer shared secret decryption
  Future<List<int>> decryptReturnData(String blob) async {
    logger.d("decryptReturnData");
    try {
      var keyMaterial = base64.decode(blob);
      if (_aesEncryptionKey != null && _aesAuthKey != null) {
        final iv = keyMaterial.sublist(0, 16);
        final mac = keyMaterial.sublist(16, 48);
        final cipherText = keyMaterial.sublist(48, keyMaterial.length);

        /// compute macs and verify
        final blob = iv + cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));

        final checkMac = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: _aesAuthKey!,
        );

        final encodedMac = base64.encode(mac);
        final encodedMacCheck = base64.encode(checkMac.bytes);
        // logger.d("check mac: ${encodedMac == encodedMacCheck}\nencodedMac: $encodedMac\nencodedMacCheck: $encodedMacCheck");

        if (encodedMac == encodedMacCheck) {
          List<int> empty_mac = [];

          SecretBox secretBox =
          SecretBox(cipherText, nonce: iv, mac: Mac(empty_mac));

          /// Decrypt
          final plainTextBytes = await algorithm_nomac.decrypt(
            secretBox,
            secretKey: _aesEncryptionKey!,
          );

          return plainTextBytes;
        }
        else {
          logger.w("decrypt failure: mac check failed");
        }
      }
      return [];
    } catch (e) {
      logger.w(e);
      return [];
    }
  }

  /// decrypt vault items with generated Metadata key
  ///
  Future<String> decryptBackupVault(String blob, String id) async {
    logger.d("decryptBackupVault");
    try {
      var keyMaterial = base64.decode(blob);
      if (_aesEncryptionKey != null && _aesAuthKey != null) {
        final iv = keyMaterial.sublist(0, 16);

        // this is the xor_mac result
        final mac = keyMaterial.sublist(16, 48);
        final cipherText = keyMaterial.sublist(48, keyMaterial.length);

        final idHash = sha256(id);
        // logger.d("idHash: ${idHash} | idHash2: ${idHash2}");
        var idHashBytes = hex.decode(idHash);

        final Kmeta1 = await hmac_algo_256.calculateMac(
          idHashBytes,
          secretKey: _aesAuthKey!,
        );

        final Kmeta1_key = SecretKey(Kmeta1.bytes);

        /// compute macs and verify
        final blob = iv + cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));
        // logger.d("hashedBlob: ${sha256(base64.encode(blob))}");

        final mac_meta = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: Kmeta1_key,
        );
        // logger.d("mac_meta: ${hex.encode(mac_meta.bytes)}");

        final encodedMac = base64.encode(mac);
        final encodedMacCheck = base64.encode(mac_meta.bytes);

        // logger.d("check mac: ${encodedMac == encodedMacCheck}\nnonce: $iv\nmac: $mac\nciphertext: $cipherText");
        if (AppConstants.debugKeyData){
          logger.d("_aesEncryptionKeyBytes: $_aesEncryptionKeyBytes\n_aesAuthKeyBytes: $_aesAuthKeyBytes"
              "\ncheck mac: ${encodedMac == encodedMacCheck}"
              "\nblob: ${hex.encode(blob)}\nmac: $mac");
        }
        // logger.d("_aesEncryptionKeyBytes: $_aesEncryptionKeyBytes\n_aesAuthKeyBytes: $_aesAuthKeyBytes\n"
        //     "check mac: ${encodedMac == encodedMacCheck}"
        //     "blob: ${blob}\nmac: $mac");

        if (encodedMac == encodedMacCheck) {
          List<int> empty_mac = [];

          SecretBox secretBox =
              SecretBox(cipherText, nonce: iv, mac: Mac(empty_mac));

          /// Decrypt
          final plainTextBytes = await algorithm_nomac.decrypt(
            secretBox,
            secretKey: _aesEncryptionKey!,
          );

          final plainText = utf8.decode(plainTextBytes);
          return plainText;
        }

      }
      return "";
    } catch (e) {
      logger.w(e);
      return "";
    }
  }


  /// Hashing
  String sha256(String? message) {
    if (message == null) {
      return "";
    }
    final c1 = Hasher().sha256Hash(message);

    return c1;
  }

  String sha512(String? message) {
    if (message == null) {
      return "";
    }
    final c1 = Hasher().sha512Hash(message);

    return c1;
  }

  /// HMAC function
  Future<String> hmac256(String? message) async {
    if (message == null) {
      return "";
    }

    if (_aesAuthKey == null) {
      return "";
    }

    try {
      final mac = await hmac_algo_256.calculateMac(
        hex.decode(sha256(message)),
        secretKey: _aesAuthKey!,
      );
      return hex.encode(mac.bytes);
    } catch(e) {
      logger.e(e);
      return "";
    }
  }

  /// keyed HMAC function
  Future<String> keyedHmac256(String? message, SecretKey key) async {
    if (message == null) {
      return "";
    }

    if (_aesAuthKey == null) {
      return "";
    }

    try {
      final mac = await hmac_algo_256.calculateMac(
        hex.decode(sha256(message)),
        secretKey: key!,
      );
      return hex.encode(mac.bytes);
    } catch(e) {
      logger.e(e);
      return "";
    }
  }

  Future<String> keyedHmac256_2(String? nonce, SecretKey key) async {
    if (nonce == null) {
      return "";
    }

    if (_aesAuthKey == null) {
      return "";
    }

    // logger.d("nonce: $nonce");

    try {
      final mac = await hmac_algo_256.calculateMac(
        hex.decode(nonce),
        secretKey: key!,
      );
      return hex.encode(mac.bytes);
    } catch(e) {
      logger.e(e);
      return "";
    }
  }

  /// HMAC function - ReKey
  Future<String> hmac256ReKey(String? message) async {
    if (message == null) {
      return "";
    }

    if (_tempAuthKey == null) {
      return "";
    }

    try {
      final mac = await hmac_algo_256.calculateMac(
        hex.decode(sha256(message)),
        secretKey: _tempAuthKey!,
      );
      return hex.encode(mac.bytes);
    } catch(e) {
      logger.e(e);
      return "";
    }
  }


  /// Asymmetric Keys -------------------------------------------------------
  /// the below methods are for testing/learning
  ///

  /// Key-Exchange - not used - add_key_item_screen
  ///
  Future<EcKeyPair> generateKeysX_secp256r1() async {
    logger.d("generateKeys_secp256r1");

    /// UNIMPLEMENTED
    ///
    final algorithm = Ecdh.p256(length: 256);

    final rand = getRandomBytes(32);

    // We need the private key pair of Alice.
    final aliceKeyPair = await algorithm.newKeyPairFromSeed(rand);
    // final aliceKeyPair = await algorithm.newKeyPair();
    // logger.d("aliceKeyPair: ${aliceKeyPair.extract()}");

    // final alicePublicKey = await aliceKeyPair.extractPublicKey();
    // final aliceKeyPair2 = await aliceKeyPair.extract();
    // logger.d("alicePublicKey: ${alicePublicKey}");

    return aliceKeyPair;
  }

  /// Key-Exchange - not used - add_key_item_screen
  ///
  Future<SimpleKeyPair> generateKeysX_secp256k1() async {
    logger.d("generateKeysX_secp256k1");

    final algorithm = X25519();

    final rand = getRandomBytes(32);
    final aliceKeyPair = await algorithm.newKeyPairFromSeed(rand);

    // final pub = await aliceKeyPair.extractPublicKey();
    // logger.d('aliceKeyPair Pub: ${pub.bytes}');

    return aliceKeyPair;
  }

  /// Digital Signature - not used - add_key_item_screen
  ///
  Future<PrivateKey> generateKeysS_secp256r1() async {
    logger.d("generateKeysS_secp256r1");

    var ec = getP256();

    // logger.d("ec.curve.name: ${ec.name}");
    // logger.d("ec.curve.n: ${ec.n}");
    // logger.d("ec.curve.a: ${ec.a}");
    // logger.d("ec.curve.b: ${ec.b}");
    // logger.d("ec.curve.bitsize: ${ec.bitSize}");
    // logger.d("ec.curve.G.X: ${ec.G.X}");
    // logger.d("ec.curve.G.Y: ${ec.G.Y}");
    // logger.d("ec.curve.h: ${ec.h}");
    // logger.d("ec.curve.p: ${ec.p}");
    // logger.d("ec.curve.S: ${ec.S}");
    // var priv2 = PrivateKey(EllipticCurve(), D);

    var priv = ec.generatePrivateKey();
    // logger.d("privateKey.D: ${priv.D}");
    // logger.d("privateKey.bytes: ${priv.bytes}");
    // logger.d("privateKey.hex: ${hex.encode(priv.bytes)}");
    // logger.d("priv: $priv");

    // var pub = priv.publicKey;
    // var xpub = ec.publicKeyToCompressedHex(pub);
    // logger.d("pubKey.compressed: ${xpub}");

    return priv;
  }

  /// Digital Signature - not used - add_key_item_screen
  ///
  Future<PrivateKey> generateKeysS_secp256k1() async {
    logger.d("generateKeysS_secp256k1");

    var ec = getS256();
    // logger.d(ec2.);

    // ec.
    // logger.d("ec.curve.name: ${ec.name}");
    // logger.d("ec.curve.n: ${ec.n}");
    // logger.d("ec.curve.a: ${ec.a}");
    // logger.d("ec.curve.b: ${ec.b}");
    // logger.d("ec.curve.bitsize: ${ec.bitSize}");
    // logger.d("ec.curve.G.X: ${ec.G.X}");
    // logger.d("ec.curve.G.Y: ${ec.G.Y}");
    // logger.d("ec.curve.h: ${ec.h}");
    // logger.d("ec.curve.p: ${ec.p}");
    // logger.d("ec.curve.S: ${ec.S}");

    final numString =
        "52729815520663091770273351126351744558404106391013798562910028644993848649013";

    final privateBigInt = BigInt.parse(numString);
    final privateHex = privateBigInt.toRadixString(16);
    // logger.d("privateBigInt: ${privateBigInt}");
    // logger.d("privateHex: ${privateHex}");

    var priv2 = PrivateKey(ec, privateBigInt);
    var priv3 = PrivateKey(ec, BigInt.parse(privateHex, radix: 16));

    // logger.d("priv2.D: ${priv2.D}");
    // logger.d("priv3.D: ${priv3.D}");

    var priv = ec.generatePrivateKey();

    // logger.d("privateKey.D: ${priv.D}");
    // logger.d("privateKey.bytes: ${priv.bytes}");
    // logger.d("privateKey.hex: ${hex.encode(priv.bytes)}");
    // logger.d("priv: $priv");

    var pub = priv.publicKey;
    var xpub = ec.publicKeyToCompressedHex(pub);
    // logger.d("pubKey.compressed: ${xpub.length}: ${xpub}");
    //
    // logger.d("pubKey.X: ${pub.X}");
    // logger.d("pubKey.X.hex: ${pub.X.toRadixString(16)}");
    //
    // logger.d("pubKey.Y: ${pub.Y}");
    // logger.d("pubKey.Y.hex: ${pub.Y.toRadixString(16)}");

    logger.d(pub.toHex());
    var newPub = ec.hexToPublicKey(pub.toHex());
    // logger.d("newPub.X: ${newPub.X}");
    // logger.d("newPub.Y: ${newPub.Y}");

    var hashHex =
        '7494049889df7542d98afe065f5e27b86754f09e550115871016a67781a92535';
    var hash = List<int>.generate(hashHex.length ~/ 2,
            (i) => int.parse(hashHex.substring(i * 2, i * 2 + 2), radix: 16));
    // logger.d("hashHex: ${hashHex}");
    // logger.d("hashHexDecoded: ${hex.decode(hashHex)}");
    //
    // logger.d("hash: ${hash}");

    var sig = ecdsa.signature(priv, hash);
    // logger.d("sig.R: ${sig.R}");
    // logger.d("sig.S: ${sig.S}");

    var result = ecdsa.verify(pub, hash, sig);
    // logger.d("result: ${result}");

    return priv;
  }

}
