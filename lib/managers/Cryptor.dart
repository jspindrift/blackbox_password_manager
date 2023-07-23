import "dart:math";
import "dart:convert";
import "dart:typed_data";
import "../helpers/bip39_dictionary.dart";

import '../helpers/WidgetUtils.dart';
import "package:cryptography/cryptography.dart";
import "package:convert/convert.dart";
import "package:argon2/argon2.dart";
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/foundation.dart';
import "package:uuid/uuid.dart";
import "package:bip39/bip39.dart" as bip39;
import 'package:ecdsa/ecdsa.dart';
import 'package:elliptic/elliptic.dart';

import '../helpers/AppConstants.dart';
import '../models/DecryptedGeoLockItem.dart';
import '../models/MyDigitalIdentity.dart';
import '../models/VaultItem.dart';
import 'Hasher.dart';
import "KeychainManager.dart";
import "SettingsManager.dart";
import "../models/PinCodeItem.dart";
import "../models/EncryptedGeoLockItem.dart";
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
  static const _rounds = 300000; //262144; // 262144 = 2^18 //300000; //100000;
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
  SecretKey? _aesSecretKey;

  SecretKey? get aesSecretKey {
    return _aesSecretKey;
  }

  /// secret key bytes
  List<int> _aesSecretKeyBytes = [];

  List<int> get aesSecretKeyBytes {
    return _aesSecretKeyBytes;
  }

  /// authentication key for MAC - KAK
  SecretKey? _authSecretKey;

  SecretKey? get authSecretKey {
    return _authSecretKey;
  }

  /// authentication key bytes
  List<int> _authSecretKeyBytes = [];

  List<int> get authSecretKeyBytes {
    return _authSecretKeyBytes;
  }

  SecretKey? _aesGenSecretKey;

  SecretKey? get aesGenSecretKey {
    return _aesGenSecretKey;
  }

  /// secret key bytes
  List<int> _aesGenSecretKeyBytes = [];

  List<int> get aesGenSecretKeyBytes {
    return _aesGenSecretKeyBytes;
  }

  /// Temp Encryption Keys...For REKEY
  ///
  /// secret key for encrypting data - DEK
  SecretKey? _tempAesSecretKey;

  SecretKey? get tempAesSecretKey {
    return _tempAesSecretKey;
  }

  /// secret key bytes
  List<int> _tempAesSecretKeyBytes = [];

  List<int> get tempAesSecretKeyBytes {
    return _tempAesSecretKeyBytes;
  }

  /// authentication key for MAC - KAK
  SecretKey? _tempAuthSecretKey;

  SecretKey? get tempAuthSecretKey {
    return _tempAuthSecretKey;
  }

  /// authentication key bytes
  List<int> _tempAuthSecretKeyBytes = [];

  List<int> get tempAuthSecretKeyBytes {
    return _tempAuthSecretKeyBytes;
  }

  SecretKey? _tempAesGenSecretKey;

  SecretKey? get tempAesGenSecretKey {
    return _tempAesGenSecretKey;
  }

  /// secret key bytes
  List<int> _tempAesGenSecretKeyBytes = [];

  List<int> get tempAesGenSecretKeyBytes {
    return _tempAesGenSecretKeyBytes;
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

    _aesSecretKeyBytes = [];
    _aesSecretKey = null;

    _authSecretKeyBytes = [];
    _authSecretKey = null;

    _aesGenSecretKeyBytes = [];
    _aesGenSecretKey = null;

    _tempAesGenSecretKeyBytes = [];
    _tempAesGenSecretKey = null;

    _tempAesSecretKeyBytes = [];
    _tempAesSecretKey = null;

    _tempAuthSecretKeyBytes = [];
    _tempAuthSecretKey = null;
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
    _aesSecretKeyBytes = bytes;
    _aesSecretKey = SecretKey(bytes);
  }

  void setAuthKeyBytes(List<int> bytes) {
    // logger.d("setAuthKeyBytes: $bytes");
    _authSecretKeyBytes = bytes;
    _authSecretKey = SecretKey(bytes);
  }

  void switchTempKeysToCurrent() {
    if (_tempAuthSecretKeyBytes == null || _tempAesGenSecretKeyBytes == null
    || _tempReKeyRootSecretKeyBytes == null || _tempAesSecretKeyBytes == null
    || _tempReKeyRootSecretKey == null || _tempAesSecretKey == null
    || _tempAesGenSecretKey == null || _tempAuthSecretKey == null) {
      return;
    }

    _aesRootSecretKeyBytes = _tempReKeyRootSecretKeyBytes;

    _aesSecretKeyBytes = _tempAesSecretKeyBytes;
    _aesSecretKey = _tempAesSecretKey;

    _authSecretKeyBytes = _tempAuthSecretKeyBytes;
    _authSecretKey = _tempAuthSecretKey;

    _aesGenSecretKeyBytes = _tempAesGenSecretKeyBytes;
    _aesGenSecretKey = _tempAesGenSecretKey;
  }

  void setLogKeyBytes(List<int> bytes) {
    // logger.d("setLogKeyBytes: $bytes");
    _logSecretKeyBytes = bytes;
    _logSecretKey = SecretKey(bytes);
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
    final rng = Random.secure();
    final rand = new List.generate(nbytes, (_) => rng.nextInt(255));
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
    // print("trueIndexes: $trueIndexes");

    final len = digitString.length;

    var newestString = "";
    var added2 = 0;

    var leftOver = (digitLength % 3);
    // print("digitString: ${digitString}, digitLength: ${(digitLength)}, leftOver: ${leftOver}");

    for (var j = 0 ; j < len; j++){
      newestString = newestString + digitString.substring(j, j+1);
      if ((j+1) % 3 == 0 && j > 0){
        added2 += 1;
        newestString = newestString + "-";
      }
      if ((newestString.length-added2) >= digitLength) {
        // print("break: ${(newestString.length-added2)}, ${added2}, ${leftOver}");
        break;
      }
    }

    if(newestString.substring(newestString.length - 1, newestString.length) == "-") {
      newestString = newestString.substring(0, newestString.length-1);
    }
    // print("newestString: $newestString");

    return newestString;
  }

  String randomMnemonic(int strength) {
    final phrase = bip39.generateMnemonic(strength: 128);
    return phrase;
  }

  ///
  /// Key Derivation.............................................................
  ///

  /// deriveKey - derives a key using PBKDF2 with password and salt
  /// called on createAccount
  Future<KeyMaterial?> deriveKey(String uuid, String password, String hint) async {
    // logger.d("PBKDF2 - deriving key");
    try {

      // var rounds = 100000;
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
      // final rng = Random();
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

      // _aesSecretKeyBytes = (await _aesSecretKey?.extractBytes())!;
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

      // logger.d("_aesSecretKeyBytes: $_aesSecretKeyBytes");

      /// add auth secret key, KAK (Key Authentication Key)
      // _authSecretKey = await algorithm_nomac.newSecretKey();
      // _authSecretKeyBytes = (await _authSecretKey?.extractBytes())!;
      // logger.d("_authSecretKeyBytes: $_authSecretKeyBytes");

      /// create log key
      /// if we already have one, dont create it.
      /// only created once per device per app instance
      if (_logSecretKeyBytes == null || _logSecretKeyBytes.isEmpty) {
        _logSecretKey = await algorithm_nomac.newSecretKey();
        _logSecretKeyBytes = (await _logSecretKey?.extractBytes())!;
      }
      // logger.d("created log key bytes: $_logSecretKeyBytes");

      // logger.d("_aesKeyBytes: $_aesSecretKeyBytes");

      // Generate a random 128-bit nonce/iv.
      final iv = algorithm_nomac.newNonce();
      // logger.d("deriveKey encryption nonce: $nonce");

      // final appendedKeys = _aesSecretKeyBytes + _authSecretKeyBytes;
      // final appendedKeys = _aesRootSecretKeyBytes;// + _authSecretKeyBytes;

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

      logger.d("confirmMacPhrase: $confirmMacPhrase");

      var keyMaterial = iv + mac.bytes + secretBox.cipherText;

      _logKeyMaterial = base64.encode(_logSecretKeyBytes);
      // logger.d("check got log key material: $_logKeyMaterial");

      if (AppConstants.debugKeyData){
        logger.d("_aesRootSecretKeyBytes: ${hex.encode(_aesRootSecretKeyBytes)}\n ");
        // logger.d("${},${},${},${},${}");
      }

      KeyMaterial keyParams = KeyMaterial(
        id: uuid,
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
    // logger.d("_aesGenSecretKeyBytes Kb: $Kb");

    // final wa = bip39.entropyToMnemonic(hex.encode(Ka));
    // final wb = bip39.entropyToMnemonic(hex.encode(Kb));
    // logger.d("Ka words: ${wa}");
    // logger.d("Kb words: ${wb}");

    final Kc = xor(Uint8List.fromList(Ka), Uint8List.fromList(Kb));
    // logger.d("_authSecretKeyBytes Kc: $Kc");

    // final wc = bip39.entropyToMnemonic(hex.encode(Kc));
    // logger.d("Kc words: ${wc}");

    _aesSecretKeyBytes = Ka;
    _aesGenSecretKeyBytes = Kb;
    _authSecretKeyBytes = Kc;

    _aesGenSecretKey = SecretKey(Kb);

    _aesSecretKey = SecretKey(Ka);

    _authSecretKey = SecretKey(Kc);

    if (AppConstants.debugKeyData){
      logger.d("skey: $skey\n_aesSecretKeyBytes: ${_aesSecretKeyBytes}\n"
          "_aesGenSecretKeyBytes: ${_aesGenSecretKeyBytes}\n"
          "_authSecretKeyBytes: ${_authSecretKeyBytes}");
    }

    return;
    // return derivedSecretKeyBytes;
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
    // logger.d("_aesSecretKeyBytes Ka: $Ka");
    // logger.d("_aesGenSecretKeyBytes Kb: $Kb");

    // final wa = bip39.entropyToMnemonic(hex.encode(Ka));
    // final wb = bip39.entropyToMnemonic(hex.encode(Kb));
    // logger.d("Ka words: ${wa}");
    // logger.d("Kb words: ${wb}");

    final Kc = xor(Uint8List.fromList(Ka), Uint8List.fromList(Kb));
    // logger.d("_authSecretKeyBytes Kc: $Kc");

    // final wc = bip39.entropyToMnemonic(hex.encode(Kc));
    // logger.d("Kc words: ${wc}");

    _tempAesSecretKeyBytes = Ka;
    _tempAesGenSecretKeyBytes = Kb;
    _tempAuthSecretKeyBytes = Kc;

    _tempAesGenSecretKey = SecretKey(Kb);
    _tempAesSecretKey = SecretKey(Ka);
    _tempAuthSecretKey = SecretKey(Kc);

    if (AppConstants.debugKeyData){
      logger.d("_tempAesSecretKeyBytes: ${_tempAesSecretKeyBytes}\n"
          "_tempAesGenSecretKeyBytes: ${_tempAesGenSecretKeyBytes}\n"
          "_tempAuthSecretKeyBytes: ${_tempAuthSecretKeyBytes}");
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

      final x = await createDigitalIdentityExchange();
      final y = await createDigitalIdentitySigning();

      // final intKey = bip39.generateMnemonic(strength: 256);
      // // logger.d("intKey: $intKey");
      // final intKey2 = bip39.mnemonicToEntropy(intKey);

      /// TODO: check this
      // settingsManager.doEncryption(utf8.encode(intKey2).length);
      // logger.d("keyIndex: $keyIndex");

      // final encryptedIntKey = await encrypt(intKey2);

      // if (AppConstants.debugKeyData){
      //   logger.d("intKey: ${intKey}\n"
      //       "intKey2: ${intKey2}\n"
      //       "encryptedIntKey: ${encryptedIntKey}");
      // }

      final myId = MyDigitalIdentity(
        version: AppConstants.myDigitalIdentityItemVersion,
        privKeyExchange: x, // encrypted
        privKeySignature: y, // encrypted
        // intermediateKey: encryptedIntKey,
        cdate: cdate,
        mdate: cdate,
      );

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
      final keyIndex = settingsManager.doEncryption(utf8.encode(hex.encode(randomSeed)).length);
      // logger.d("keyIndex: $keyIndex");

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
      logger.d("derive key check: salt: $salt");

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
        logger.d('iv: $iv\nmac: $mac\nciphertext length: ${cipherText.length}: $cipherText');

        /// check mac
        final blob = iv + cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));
        // logger.d("hashedBlob: ${hashedBlob}");

        final macCheck = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: secretKy,
        );

        // final secretBoxMac = xor(Uint8List.fromList(_authSecretKeyBytes), Uint8List.fromList(macCheck.bytes));

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
        logger.d("confirmMacPhrase: $confirmMacPhrase");

        // logger.d("check mac: ${encodedMac == encodedMacCheck}");
        //
        // logger.d("nonce: $_nonce");
        // logger.d("mac: $_mac");
        // logger.d("ciphertext: $_cipherText");

        if (encodedMac == encodedMacCheck) {
          List<int> empty_mac = [];
          SecretBox sbox =
              SecretBox(cipherText, nonce: iv, mac: Mac(empty_mac));
          // logger.d("sbox nonce: ${sbox.nonce}");
          // logger.d("sbox mac: ${sbox.mac.bytes}");
          // logger.d("sbox ciphertext: ${sbox.cipherText}");

          /// Decrypt
          ///
          final rootKey = await algorithm_nomac.decrypt(
            sbox,
            secretKey: secretKx, //derivedSecretKey, // secretKx
          );



          // _aesSecretKeyBytes = (await _aesSecretKey?.extractBytes())!;
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

        logger.d("confirmMacPhrase: $confirmMacPhrase");

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
            _logSecretKey = await algorithm_nomac.newSecretKey();
            _logSecretKeyBytes = (await _logSecretKey?.extractBytes())!;
            _logKeyMaterial = base64.encode(_logSecretKeyBytes);
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
  /// TODO: dont change secret salt
  ///
  Future<KeyMaterial?> deriveNewKey(String password) async {
    // logger.d("PBKDF2 - deriving new key");
    final currentKeyParams = _currentKeyMaterial;
    if (currentKeyParams == null) {
      return null;
    }
    try {
      // final startTime = DateTime.now();
      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha512(),
        iterations: currentKeyParams.rounds,
        bits: 512, // 512
      );

      if (_salt.isEmpty) {
        logger.d("_salt is empty!!!");
        return null;
      }
      // double strength = estimatePasswordStrength(password.trim());
      // logger.d("master pwd strength: ${strength.toStringAsFixed(3)}");

      // password we want to hash
      // final secretKey = SecretKey(password.codeUnits);
      final secretKey = SecretKey(utf8.encode(password.trim()));

      // use same salt (secret salt)
      final sameSalt = _salt;

      // Calculate a hash that can be stored in the database
      final derivedSecretKey = await pbkdf2.deriveKey(
        secretKey: secretKey,
        nonce: sameSalt,
      );

      // final endTime = DateTime.now();

      // final timeDiff = endTime.difference(startTime);
      // logger.d("pbkdf2 time diff: ${timeDiff.inMilliseconds} ms");

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
        // Generate a random 128-bit nonce.
        final iv_new = algorithm_nomac.newNonce();
        final rootKey = _aesRootSecretKeyBytes;

        if (AppConstants.debugKeyData){
          logger.d("rootKey: ${hex.encode(rootKey)}\n");
        }

        /// Encrypt
        final secretBox = await algorithm_nomac.encrypt(
          rootKey,
          secretKey: secretKx,
          nonce: iv_new,
        );

        /// compute mac
        final blob = iv_new + secretBox.cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));
        // logger.d("hashedBlob: ${hashedBlob}");

        final mac = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: secretKy,
        );

        final macPhrase = bip39.entropyToMnemonic(hex.encode(mac.bytes));

        final macWordList = macPhrase.split(" ");

        // var confirmMacPhrase = macWordList[0] + " " + macWordList[1] + " " + macWordList[2] + " " + macWordList.last;
        // var confirmMacPhrase = macWordList[0] + " " + macWordList[1] + " " + macWordList.last;
        var confirmMacPhrase = macWordList[0] + " " + macWordList.last;

        // for (var mword in macWordList) {
        //   confirmMacPhrase = confirmMacPhrase + " " + mword;
        // }
        logger.d("confirmMacPhrase: $confirmMacPhrase");

        if (AppConstants.debugKeyData){
          logger.d("mac: ${mac}\n");
        }

        var keyMaterial = iv_new + mac.bytes + secretBox.cipherText;

        KeyMaterial newKeyMaterial = KeyMaterial(
          id: currentKeyParams.id,
          salt: base64.encode(sameSalt),
          rounds: currentKeyParams.rounds,
          key: base64.encode(keyMaterial),
          hint: "pwd change",
        );

        return newKeyMaterial;
      } else {
        logger.w("_aesSecretKeyBytes was empty!!!");
        return null;
      }
    } catch (e) {
      logger.w(e);
      return null;
    }
  }

  /// Used when re-keying our vault
  /// TODO: re-key
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

      // password we want to hash
      // final secretKey = SecretKey(password.codeUnits);
      final secretKey = SecretKey(utf8.encode(password.trim()));

      // use same salt (secret salt)
      // final sameSalt = _salt;

      // Calculate a hash that can be stored in the database
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
      // logger.d("Kx: $Kx");
      // logger.d("Ky: $Ky");
      final secretKx = SecretKey(Kx);
      final secretKy = SecretKey(Ky);
      if (AppConstants.debugKeyData){
        logger.d("deriveNewKeySchedule\nKx: ${Kx}\n"
            "Ky: ${Ky}\n");
      }

      // logger.d("encrypting _aesKeyBytes: $_aesSecretKeyBytes");
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

        await expandSecretTempRootKey(_tempReKeyRootSecretKeyBytes);
        // Generate a random 128-bit nonce.
        final iv_new = algorithm_nomac.newNonce();
        // logger.d("ctr new nonce: ${newNonce.length}, $newNonce");

        /// Encrypt
        final secretBox = await algorithm_nomac.encrypt(
          newRootSecret,
          secretKey: secretKx,
          nonce: iv_new,
        );

        /// compute mac
        final blob = iv_new + secretBox.cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));
        logger.d("hashedBlob: ${hashedBlob}");

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
        // logger.d("ctr new nonce: ${newNonce.length}, $newNonce");

        /// Encrypt
        final secretBoxKeyNonce = await algorithm_nomac.encrypt(
          zeroBlock,
          secretKey: secretKx,
          nonce: iv_keyNonce,
        );

        /// Key nonce
        final blob_keyNoncei = iv_keyNonce + secretBoxKeyNonce.cipherText;
        logger.d("blob_keyNoncei: ${blob_keyNoncei}");

        final hashedBlob_keyNonce = hex.decode(sha256(base64.encode(blob_keyNoncei)));
        logger.d("hashedBlob_keyNonce: ${hashedBlob_keyNonce}");


        final mac_keyNonce = await hmac_algo_256.calculateMac(
          hashedBlob_keyNonce,
          secretKey: secretKy,
        );

        final blob_keyNonce = iv_keyNonce + mac_keyNonce.bytes + secretBoxKeyNonce.cipherText;
        logger.d("blob_keyNonce: ${blob_keyNonce}");


        final ek = EncryptedKey(
            derivationAlgorithm: kdfAlgo,
            salt: base64.encode(newSalt),
            rounds: rounds,
            type: type,
            version: version,
            memoryPowerOf2: memoryPowerOf2,
            encryptionAlgorithm: encryptionAlgo,
            keyMaterial: base64.encode(keyMaterial),
            keyNonce: base64.encode(blob_keyNonce),
            // blocksEncrypted: 0,
            // blockRolloverCount: 0,
        );
        if (AppConstants.debugKeyData){
          logger.d("ek: ${ek}\n"
              "ek.json: ${ek.toJson()}\n");
        }

        return ek;
      } else {
        logger.w("_aesSecretKeyBytes was empty!!!");
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
      final rng = Random();
      final salt = List.generate(_saltLength, (_) => rng.nextInt(255));
      // logger.d("random salt: $_salt");

      // Calculate a hash that can be stored in the database
      final derivedSecretKey = await pbkdf2.deriveKey(
        secretKey: secretKey,
        nonce: salt,
      );
      // final derivedSecretKeyBytes = await derivedSecretKey.extractBytes();
      // logger.d("derivedSecretKeyBytes pin: ${derivedSecretKeyBytes}");

      // final endTime = DateTime.now();

      // final timeDiff = endTime.difference(startTime);
      // logger.d("pbkdf2 time diff: ${timeDiff.inMilliseconds} ms");

      // Generate a random 128-bit nonce.
      final iv = algorithm_nomac.newNonce();


      /// append keys together
      final rootKey = _aesRootSecretKeyBytes;

      /// Encrypt
      final secretBox = await algorithm_nomac.encrypt(
        rootKey,
        secretKey: derivedSecretKey,
        nonce: iv,
      );

      final blob = iv + secretBox.cipherText;
      final hashedBlob = hex.decode(sha256(base64.encode(blob)));
      // logger.d("hashedBlob: ${hashedBlob}");

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
      // final secretKey = SecretKey(pin.codeUnits);
      final secretKey = SecretKey(utf8.encode(pin.trim()));

      // create a random salt
      final decodedSalt = base64.decode(encodedSalt);

      // logger.d("salt: $_salt");

      // Calculate a hash that can be stored in the database
      final derivedSecretKey = await pbkdf2.deriveKey(
        secretKey: secretKey,
        nonce: decodedSalt,
      );
      // final derivedSecretKeyBytes = await derivedSecretKey.extractBytes();
      //
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
        // logger.d("hashedBlob: ${hashedBlob}");

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
      final rng = Random();
      _salt = List.generate(_saltLength, (_) => rng.nextInt(255));

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
      _aesSecretKey = await algorithm.newSecretKey();

      _aesSecretKeyBytes = (await _aesSecretKey?.extractBytes())!;
      // logger.d("_aesKeyBytes: $_aesSecretKeyBytes");

      // Generate a random 128-bit nonce.
      final nonce = algorithm.newNonce();
      // logger.d("ctr nonce: ${_nonce.length}, $_nonce");

      final argon2SecretKey = SecretKey(result);

      /// Encrypt
      final secretBox = await algorithm.encrypt(
        _aesSecretKeyBytes,
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

  /// TODO: change this to use empty mac and compute mac manually
  ///
  Future<String> encrypt(String plaintext) async {
    // logger.d("encrypt");
    try {
      if (_aesSecretKey != null && _authSecretKey != null) {
        // Generate a random 128-bit nonce.
        final iv = algorithm_nomac.newNonce();
        // logger.d("ctr new nonce: ${nonce.length}, nonce");

        final encodedPlaintext = utf8.encode(plaintext);
        // logger.d("encoded password: $encodedPlaintext");

        /// Encrypt
        final secretBox = await algorithm_nomac.encrypt(
          encodedPlaintext,
          secretKey: _aesSecretKey!,
          nonce: iv,
        );

        /// encrypt-then-mac with added KAK and nonce
        ///
        final blob = iv + secretBox.cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));
        // logger.d("hashedBlob: ${hashedBlob}");

        /// check mac
        final mac = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: _authSecretKey!,
        );

        // if (AppConstants.debugKeyData){
        //   logger.d("blob: ${blob}\n"
        //       "mac: ${mac}\n");
        // }

        /// TODO: add in
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
    // logger.d("encrypt: tempindex[$_tempKeyIndex]");
    try {
      if (_aesSecretKey != null
          && _authSecretKey != null
          && _tempReKeyRootSecretKey != null) {

        final decryptedData = await decrypt(ciphertext);


        // Generate a random 128-bit nonce.
        final iv = algorithm_nomac.newNonce();
        // logger.d("ctr new nonce: ${nonce.length}, nonce");

        var encodedPlaintext;// = utf8.encode(decryptedData);
        // if (ishex) {
        //    encodedPlaintext = hex.decode(decryptedData);
        // } else {
          encodedPlaintext = utf8.encode(decryptedData);
        // }
        // logger.d("encoded password: $encodedPlaintext");

        // var bigNumHexLon = lon_min_bigNum.toRadixString(16);
        // logger.d("bigNumHexLon: $bigNumHexLon");


        /// Encrypt
        /// TODO: implement
        // final secretBoxIndexed = await algorithm_nomac.encrypt(
        //   encodedPlaintext,
        //   secretKey: Kenci_sec!,
        //   nonce: iv,
        // );


        /// Encrypt
        final secretBox = await algorithm_nomac.encrypt(
          encodedPlaintext,
          secretKey: _tempAesSecretKey!,
          nonce: iv,
        );

        /// encrypt-then-mac with added KAK and nonce
        ///
        final blob = iv + secretBox.cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));
        // logger.d("hashedBlob: ${hashedBlob}");

        /// check mac
        final mac = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: _tempAuthSecretKey!,
        );

        /// check mac
        /// TODO: implement
        // final macIndexed = await hmac.calculateMac(
        //   blob,
        //   secretKey: Kauthi_sec!,
        // );
        // if (AppConstants.debugKeyData){
        //   logger.d("ciphertext: ${ciphertext}\n"
        //       "decryptedData: ${decryptedData}\n"
        //       "blob: $blob"
        //       "mac: ${mac}\n");
        // }

        /// append our nonce, masked MAC and ciphertext
        // var encyptedMaterialIndexed = iv + macIndexed.bytes + secretBoxIndexed.cipherText;

        // await settingsManager.saveEncryptionCount(settingsManager.numEncryptions);
        // await settingsManager.saveNumBytesEncrypted(settingsManager.numBytesEncrypted);

        /// TODO: add in
        var encyptedMaterial = iv + mac.bytes + secretBox.cipherText;

        if (AppConstants.debugKeyData){
          logger.d("ciphertext: ${ciphertext}\n"
              "decryptedData: ${decryptedData}\n"
              "blob: ${hex.encode(blob)}"
              "mac: ${hex.encode(mac.bytes)}\nencyptedMaterial: $encyptedMaterial");
        }
        // logger.d("encyptedMaterial2: ${encyptedMaterial2.length} : $encyptedMaterial2");

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

        // Generate a random 128-bit nonce.
        final iv = algorithm_nomac.newNonce();
        // logger.d("ctr new nonce: ${nonce.length}, nonce");

        final encodedPlaintext = utf8.encode(plaintext);
        // logger.d("encoded password: $encodedPlaintext");

        /// TODO: implement this outside of this function
        // final keyIndex = settingsManager.doEncryption(encodedPlaintext.length);
        // logger.d("keyIndex: $keyIndex");

        final Skenc = SecretKey(Kenc);
        final Skauth = SecretKey(Kauth);

        /// Encrypt
        final secretBox = await algorithm_nomac.encrypt(
          encodedPlaintext,
          secretKey: Skenc,
          nonce: iv,
        );

        /// encrypt-then-mac with added KAK and nonce
        ///
        final blob = iv + secretBox.cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));
        // logger.d("hashedBlob: ${hashedBlob}");

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

        /// TODO: add in
        var encyptedMaterial2 = iv + mac.bytes + secretBox.cipherText;
        // logger.d("encyptedMaterial2: ${encyptedMaterial2.length} : $encyptedMaterial2");

        return base64.encode(encyptedMaterial2);
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
      if (_aesSecretKey != null && _authSecretKey != null) {
        // Generate a random 128-bit nonce.
        final iv = algorithm_nomac.newNonce();
        // logger.d("ctr new nonce: ${nonce.length}, nonce");

        final encodedPlaintext = utf8.encode(plaintext);
        // logger.d("encoded password: $encodedPlaintext");

        /// Encrypt
        final secretBox = await algorithm_nomac.encrypt(
          encodedPlaintext,
          secretKey: _aesSecretKey!,
          nonce: iv,
        );

        // logger.d("ctr MAC: ${secretBox.mac}");
        // logger.d("ctr Ciphertext: ${secretBox.cipherText}");

        /// encrypt-then-mac with added KAK and nonce
        ///
        final blob = iv + secretBox.cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));
        // logger.d("hashedBlob: ${sha256(base64.encode(blob))}");

        final idHashBytes = hex.decode(sha256(id));
        // logger.d("idHashBytes: ${sha256(id)}");

        final Kmeta1 = await hmac_algo_256.calculateMac(
          idHashBytes,
          secretKey: _authSecretKey!,
        );

        final Kmeta1_key = SecretKey(Kmeta1.bytes);

        final mac_meta = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: Kmeta1_key,
        );

        if (AppConstants.debugKeyData){
          logger.d("blob: ${hex.encode(blob)}"
              "\nKmeta1: ${Kmeta1}");
        }

        await settingsManager.saveNumBlocksEncrypted((settingsManager.numBytesEncrypted/16).ceil());

        await settingsManager.saveNumBytesEncrypted(settingsManager.numBytesEncrypted);

        /// TODO: add in
        var encyptedMaterial = iv + mac_meta.bytes + secretBox.cipherText;

        // logger.d("encyptedMaterial2: ${encyptedMaterial2.length} : $encyptedMaterial2");

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
        // Generate a random 128-bit nonce.
        final iv = algorithm_nomac.newNonce();
        // logger.d("ctr new nonce: ${nonce.length}, nonce");

        // final encodedPlaintext = utf8.encode(data);
        // logger.d("encoded password: $encodedPlaintext");
        // settingsManager.doEncryption(encodedPlaintext.length);

        /// Encrypt
        final secretBox = await algorithm_nomac.encrypt(
          data,
          secretKey: key,
          nonce: iv,
        );

        final kbytes = await key.extractBytes();


        /// encrypt-then-mac with added KAK and nonce
        ///
        final blob = iv + secretBox.cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));
        // logger.d("hashedBlob: ${hashedBlob}");

        /// check mac
        final mac = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: key,
        );
        // if (AppConstants.debugKeyData){
        //   logger.d("data: ${data}\n"
        //       "key: ${kbytes}"
        //       "blob: ${blob}\nmac: $mac");
        // }
        /// xor the 2 macs to mask the weaker one (secretBox.mac)
        /// TODO: remove
        // final xormac = xor(Uint8List.fromList(secretBox.mac.bytes),
        //     Uint8List.fromList(mac.bytes));
        // logger.d("xormac.mac.bytes: ${xormac}");

        /// append our nonce, masked MAC and ciphertext
        // var encyptedMaterial = iv + xormac + secretBox.cipherText;

        // await settingsManager.saveEncryptionCount(settingsManager.numEncryptions);
        // await settingsManager.saveNumBytesEncrypted(settingsManager.numBytesEncrypted);

        /// TODO: add in
        var encyptedMaterial2 = iv + mac.bytes + secretBox.cipherText;

        // logger.d("encyptedMaterial2: ${encyptedMaterial2.length} : $encyptedMaterial2");

        return base64.encode(encyptedMaterial2);
      } else {
        return "";
      }
    } catch (e) {
      logger.w(e);
      return "";
    }
  }

  /// decrypt items
  /// TODO: change this to use empty mac and compute mac manually
  ///
  Future<String> decrypt(String blob) async {
    // logger.d("decrypt");

    try {
      var keyMaterial = base64.decode(blob);
      if (_aesSecretKey != null && _authSecretKey != null) {
        final iv = keyMaterial.sublist(0, 16);
        // this is the xor'd mac result
        final mac = keyMaterial.sublist(16, 48);
        final cipherText = keyMaterial.sublist(48, keyMaterial.length);

        /// compute macs and verify
        final cipherBlob = iv + cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(cipherBlob)));
        // logger.d("hashedBlob: ${hashedBlob}");

        final checkMac = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: _authSecretKey!,
        );

        final encodedMac = base64.encode(mac);
        final encodedMacCheck = base64.encode(checkMac.bytes);
        // logger.d("$blob:\ncheck mac: ${encodedMac == encodedMacCheck}\nencodedMac: $encodedMac\nencodedMacCheck: $encodedMacCheck");
        // if (AppConstants.debugKeyData){
        //   logger.d("check mac: ${encodedMac == encodedMacCheck}"
        //       " blob: ${blob}\nmac: $mac");
        // }
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
            secretKey: _aesSecretKey!,
          );

          final plainText = utf8.decode(plainTextBytes);
          // logger.d("decrypt plaintext: $plainText");
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
    logger.d("decrypt4");

    try {
      if (key != null && data.isNotEmpty) {

        // final encodedPlaintext = utf8.encode(plaintext);
        final encodedBlob = base64.decode(data);

        final iv = encodedBlob.sublist(0, 16);
        final mac = encodedBlob.sublist(16, 16+32);
        final ciphertext = encodedBlob.sublist(16+32, encodedBlob.length);

        // logger.d("encoded password: $encodedPlaintext");

        final blob = iv + ciphertext;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));
        // logger.d("hashedBlob: ${hashedBlob}");

        /// check mac
        final macCheck = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: key,
        );

        final encodedMac = base64.encode(mac);
        final encodedMacCheck = base64.encode(macCheck.bytes);
        if (AppConstants.debugKeyData){
          logger.d("check mac: ${encodedMac == encodedMacCheck}"
              "\nmac: ${hex.encode(mac)}");
        }

        if (encodedMac == encodedMacCheck) {
          // logger.d("mac check success");

          final secretBox = SecretBox(ciphertext, nonce: iv, mac: Mac([]));

          /// Encrypt
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
    final algorithm2 = AesCtr.with256bits(macAlgorithm: hmac_algo_256);

    try {
      if (_aesSecretKey != null && _authSecretKey != null) {
        // Generate a random 128-bit nonce.
        final nonce = algorithm_nomac.newNonce();
        logger.d("Geo Encrypt............");

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
        // for (var tok in nonce) {
          for (var i = 0; i<32; i++) {

            Ka_tokens.addAll(Ka);
        }
        List<int> Kb_tokens = [];
        // for (var tok in nonce) {
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
        // return [geoEncryptedData, owner_lat_tokens, owner_long_tokens];
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

    logger.d("Geo Decrypt............");

    // logger.d("decrypt lat: $lat");
    // logger.d("decrypt long: $long");

    final algorithm2 = AesCtr.with256bits(macAlgorithm: hmac_algo_256);

    // logger.d("ciphertext: $ciphertext");

    final decodedCiphertext = base64.decode(ciphertext);
    // logger.d("decodedCiphertext: $decodedCiphertext");

    final iv = decodedCiphertext.sublist(0, 16);
    final mac = decodedCiphertext.sublist(16, 48);
    final ciphertext2 = decodedCiphertext.sublist(48, decodedCiphertext.length);
    // logger.d("ciphertext2: $ciphertext2");

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
          // logger.d(e);
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
    // logger.d("encrypt3: $iv");
    try {
      if (_aesSecretKey != null && _authSecretKey != null) {

        final decodedPlaintext = base64.decode(plaintext);

        /// Encrypt
        final secretBox = await algorithm_nomac.encrypt(
          decodedPlaintext,
          secretKey: _aesSecretKey!,
          nonce: iv,
        );

        /// encrypt-then-mac with added KAK and nonce
        ///
        final blob = iv + secretBox.cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));
        // logger.d("hashedBlob: ${hashedBlob}");

        /// check mac
        final mac = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: _authSecretKey!,
        );

        /// append our nonce, masked MAC and ciphertext
        var encyptedMaterial = iv + mac.bytes + secretBox.cipherText;
        // logger.d("encyptedMaterial2: ${encyptedMaterial2.length} : $encyptedMaterial2");

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
    // logger.d("decrypt3");
    try {
      if (_aesSecretKey != null && _authSecretKey != null) {

        // final encodedPlaintext = utf8.encode(plaintext);
        final encodedBlob = base64.decode(data);

        final iv = encodedBlob.sublist(0, 16);
        final mac = encodedBlob.sublist(16, 16+32);
        final ciphertext = encodedBlob.sublist(16+32, encodedBlob.length);

        // logger.d("encoded password: $encodedPlaintext");

        final blob = iv + ciphertext;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));
        // logger.d("hashedBlob: ${hashedBlob}");

        /// check mac
        final macCheck = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: _authSecretKey!,
        );

        final encodedMac = base64.encode(mac);
        final encodedMacCheck = base64.encode(macCheck.bytes);


        if (encodedMac == encodedMacCheck) {
          // logger.d("mac check success");

          final secretBox = SecretBox(ciphertext, nonce: iv, mac: Mac([]));

          /// Encrypt
          final decryptedData = await algorithm_nomac.decrypt(
            secretBox,
            secretKey: _aesSecretKey!,
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
      if (Kenc != null && Kenc.length == 32 && Kauth != null && Kauth.length == 32) {
        // logger.d("settings.numDecryptions: ${settingsManager.numDecryptions}");
        final iv = keyMaterial.sublist(0, 16);
        // this is the xor'd mac result
        final mac = keyMaterial.sublist(16, 48);
        final cipherText = keyMaterial.sublist(48, keyMaterial.length);

        // final keyIndexData = hex.decode("00000000");



        final Skenc = SecretKey(Kenc);
        final Skauth = SecretKey(Kauth);

        /// compute macs and verify
        final blob = iv + cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));
        // logger.d("hashedBlob: ${hashedBlob}");

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
          // logger.d("plainTextBytes: ${hex.encode(plainTextBytes)}\nKauthi: ${hex.encode(mac)}");

          final plainText = utf8.decode(plainTextBytes);
          // logger.d("decrypted plainText: $plainText");
          // logger.d("decrypted: valid");

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
      if (_aesSecretKey != null && _authSecretKey != null) {
        // logger.d("settings.numDecryptions: ${settingsManager.numDecryptions}");

        final iv = keyMaterial.sublist(0, 16);
        // this is the xor'd mac result
        final mac = keyMaterial.sublist(16, 48);
        final cipherText = keyMaterial.sublist(48, keyMaterial.length);

        /// compute macs and verify
        final blob = iv + cipherText;
        final hashedBlob = hex.decode(sha256(base64.encode(blob)));
        // logger.d("hashedBlob: ${hashedBlob}");

        final checkMac = await hmac_algo_256.calculateMac(
          hashedBlob,
          secretKey: _authSecretKey!,
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
            secretKey: _aesSecretKey!,
          );

          // final plainText = utf8.decode(plainTextBytes);
          // logger.d("decrypt plaintext: $plainTextBytes");
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
  /// TODO: change this to use empty mac and compute mac manually
  ///
  Future<String> decryptBackupVault(String blob, String id) async {
    logger.d("decryptBackupVault");

    try {
      var keyMaterial = base64.decode(blob);
      if (_aesSecretKey != null && _authSecretKey != null) {
        final iv = keyMaterial.sublist(0, 16);

        // this is the xor_mac result
        final mac = keyMaterial.sublist(16, 48);
        final cipherText = keyMaterial.sublist(48, keyMaterial.length);

        final idHash = sha256(id);
        // logger.d("idHash: ${idHash} | idHash2: ${idHash2}");
        var idHashBytes = hex.decode(idHash);

        final Kmeta1 = await hmac_algo_256.calculateMac(
          idHashBytes,
          secretKey: _authSecretKey!,
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

        // final weakMac = await hmac.calculateMac(
        //   cipherText,
        //   secretKey: _aesSecretKey!,
        // );
        // logger.d("weak_mac: ${weakMac.bytes}");

        /// xor the 2 macs to unmask the base mac
        // final secretBoxMac =
        //     xor(Uint8List.fromList(mac_meta.bytes), Uint8List.fromList(mac));

        final encodedMac = base64.encode(mac);
        final encodedMacCheck = base64.encode(mac_meta.bytes);

        // logger.d("check mac: ${encodedMac == encodedMacCheck}\nnonce: $iv\nmac: $mac\nciphertext: $cipherText");
        if (AppConstants.debugKeyData){
          logger.d("_aesSecretKeyBytes: $_aesSecretKeyBytes\n_authSecretKeyBytes: $_authSecretKeyBytes"
              "\ncheck mac: ${encodedMac == encodedMacCheck}"
              "\nblob: ${hex.encode(blob)}\nmac: $mac");
        }
        // logger.d("_aesSecretKeyBytes: $_aesSecretKeyBytes\n_authSecretKeyBytes: $_authSecretKeyBytes\n"
        //     "check mac: ${encodedMac == encodedMacCheck}"
        //     "blob: ${blob}\nmac: $mac");

        if (encodedMac == encodedMacCheck) {
          List<int> empty_mac = [];

          SecretBox secretBox =
              SecretBox(cipherText, nonce: iv, mac: Mac(empty_mac));

          /// Decrypt
          final plainTextBytes = await algorithm_nomac.decrypt(
            secretBox,
            secretKey: _aesSecretKey!,
          );

          // await settingsManager.saveDecryptionCount(settingsManager.numDecryptions);
          // await settingsManager.saveNumBytesDecrypted(settingsManager.numBytesDecrypted);

          final plainText = utf8.decode(plainTextBytes);
          // logger.d("decrypt2: plaintext: $plainText");
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

  /// HMAC function
  Future<String> hmac256(String? message) async {
    if (message == null) {
      return "";
    }

    if (_authSecretKey == null) {
      return "";
    }

    try {
      final mac = await hmac_algo_256.calculateMac(
        hex.decode(sha256(message)),
        secretKey: _authSecretKey!,
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

    if (_tempAuthSecretKey == null) {
      return "";
    }

    try {
      final mac = await hmac_algo_256.calculateMac(
        hex.decode(sha256(message)),
        secretKey: _tempAuthSecretKey!,
      );
      return hex.encode(mac.bytes);
    } catch(e) {
      logger.e(e);
      return "";
    }
  }

  /// Asymmetric Keys
  ///
  ///


  /// Key-Exchange
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
    logger.d("aliceKeyPair: ${aliceKeyPair.extract()}");

    final alicePublicKey = await aliceKeyPair.extractPublicKey();
    final aliceKeyPair2 = await aliceKeyPair.extract();
    logger.d("alicePublicKey: ${alicePublicKey}");

    // // We need only public key of Bob.
    // final bobKeyPair = await algorithm.newKeyPair();
    // final bobPublicKey = await bobKeyPair.extractPublicKey();
    // logger.d("bobPublicKey.X: ${bobPublicKey.x}");
    // logger.d("bobPublicKey.Y: ${bobPublicKey.y}");
    //
    // // We can now calculate a 32-byte shared secret key.
    // final sharedSecretKey = await algorithm.sharedSecretKey(
    //   keyPair: aliceKeyPair,
    //   remotePublicKey: bobPublicKey,
    // );
    //
    // logger.d("sharedSecretKey: ${sharedSecretKey.extractBytes()}");

    return aliceKeyPair;
  }

  /// Key-Exchange
  ///
  Future<SimpleKeyPair> generateKeysX_secp256k1() async {
    logger.d("generateKeysX_secp256k1");

    final algorithm = X25519();

    final rand = getRandomBytes(32);
    final aliceKeyPair = await algorithm.newKeyPairFromSeed(rand);
    // final privSeed = await aliceKeyPair.extractPrivateKeyBytes();

    // final aliceKeyPair = await algorithm.newKeyPair();
    // logger.d('algorithm: ${algorithm}');
    // final priv = await aliceKeyPair.extractPrivateKeyBytes();
    //
    // logger.d('aliceKeyPair Priv: ${priv}');
    // logger.d('aliceKeyPair Priv.Hex: ${hex.encode(priv)}');

    // logger.d('aliceKeyPair privSeed: ${privSeed}');
    // final pubSeed = await aliceKeyPair.extractPublicKey();
    // logger.d('aliceKeyPair PubSeed: ${pubSeed.bytes}');

    final pub = await aliceKeyPair.extractPublicKey();
    logger.d('aliceKeyPair Pub: ${pub.bytes}');

    return aliceKeyPair;
  }

  /// Digital Signature
  ///
  Future<PrivateKey> generateKeysS_secp256r1() async {
    logger.d("generateKeysS_secp256r1");

    var ec = getP256();

    // var ec2 = getS256();
    // logger.d(ec2.);

    // ec.
    logger.d("ec.curve.name: ${ec.name}");
    logger.d("ec.curve.n: ${ec.n}");
    logger.d("ec.curve.a: ${ec.a}");
    logger.d("ec.curve.b: ${ec.b}");
    logger.d("ec.curve.bitsize: ${ec.bitSize}");
    logger.d("ec.curve.G.X: ${ec.G.X}");
    logger.d("ec.curve.G.Y: ${ec.G.Y}");
    logger.d("ec.curve.h: ${ec.h}");
    logger.d("ec.curve.p: ${ec.p}");
    logger.d("ec.curve.S: ${ec.S}");
    // var priv2 = PrivateKey(EllipticCurve(), D);

    var priv = ec.generatePrivateKey();
    // var kp = ec.

    logger.d("privateKey.D: ${priv.D}");
    logger.d("privateKey.bytes: ${priv.bytes}");
    logger.d("privateKey.hex: ${hex.encode(priv.bytes)}");
    logger.d("priv: $priv");

    var pub = priv.publicKey;
    var xpub = ec.publicKeyToCompressedHex(pub);

    logger.d("pubKey.compressed: ${xpub}");

    // var hashHex =
    //     '7494049889df7542d98afe065f5e27b86754f09e550115871016a67781a92535';
    // var hash = List<int>.generate(hashHex.length ~/ 2,
    //         (i) => int.parse(hashHex.substring(i * 2, i * 2 + 2), radix: 16));
    // logger.d("hashHex: ${hashHex}");
    // logger.d("hashHexDecoded: ${hex.decode(hashHex)}");
    //
    // logger.d("hash: ${hash}");
    //
    // var sig = signature(priv, hash);
    // logger.d("sig.R: ${sig.R}");
    // logger.d("sig.S: ${sig.S}");
    //
    // var result = verify(pub, hash, sig);
    // logger.d("result: ${result}");

    return priv;
  }

  /// Digital Signature
  ///
  Future<PrivateKey> generateKeysS_secp256k1() async {
    logger.d("generateKeysS_secp256k1");

    var ec = getS256();
    // logger.d(ec2.);

    // ec.
    logger.d("ec.curve.name: ${ec.name}");
    logger.d("ec.curve.n: ${ec.n}");
    logger.d("ec.curve.a: ${ec.a}");
    logger.d("ec.curve.b: ${ec.b}");
    logger.d("ec.curve.bitsize: ${ec.bitSize}");
    logger.d("ec.curve.G.X: ${ec.G.X}");
    logger.d("ec.curve.G.Y: ${ec.G.Y}");
    logger.d("ec.curve.h: ${ec.h}");
    logger.d("ec.curve.p: ${ec.p}");
    logger.d("ec.curve.S: ${ec.S}");

    final numString =
        "52729815520663091770273351126351744558404106391013798562910028644993848649013";

    final privateBigInt = BigInt.parse(numString);
    final privateHex = privateBigInt.toRadixString(16);
    logger.d("privateBigInt: ${privateBigInt}");
    logger.d("privateHex: ${privateHex}");

    var priv2 = PrivateKey(ec, privateBigInt);
    var priv3 = PrivateKey(ec, BigInt.parse(privateHex, radix: 16));

    logger.d("priv2.D: ${priv2.D}");
    logger.d("priv3.D: ${priv3.D}");

    var priv = ec.generatePrivateKey();

    logger.d("privateKey.D: ${priv.D}");
    logger.d("privateKey.bytes: ${priv.bytes}");
    logger.d("privateKey.hex: ${hex.encode(priv.bytes)}");
    // logger.d("priv: $priv");

    var pub = priv.publicKey;
    var xpub = ec.publicKeyToCompressedHex(pub);
    logger.d("pubKey.compressed: ${xpub.length}: ${xpub}");

    logger.d("pubKey.X: ${pub.X}");
    logger.d("pubKey.X.hex: ${pub.X.toRadixString(16)}");

    logger.d("pubKey.Y: ${pub.Y}");
    logger.d("pubKey.Y.hex: ${pub.Y.toRadixString(16)}");

    logger.d(pub.toHex());
    var newPub = ec.hexToPublicKey(pub.toHex());
    logger.d("newPub.X: ${newPub.X}");
    logger.d("newPub.Y: ${newPub.Y}");

    var hashHex =
        '7494049889df7542d98afe065f5e27b86754f09e550115871016a67781a92535';
    var hash = List<int>.generate(hashHex.length ~/ 2,
            (i) => int.parse(hashHex.substring(i * 2, i * 2 + 2), radix: 16));
    logger.d("hashHex: ${hashHex}");
    logger.d("hashHexDecoded: ${hex.decode(hashHex)}");

    logger.d("hash: ${hash}");

    var sig = signature(priv, hash);
    logger.d("sig.R: ${sig.R}");
    logger.d("sig.S: ${sig.S}");

    var result = verify(pub, hash, sig);
    logger.d("result: ${result}");


    return priv;
  }



}
