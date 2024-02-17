import "dart:convert";
import "dart:typed_data";

import 'package:flutter_dotenv/flutter_dotenv.dart';
import "package:cryptography/cryptography.dart";
import "package:convert/convert.dart";
import 'package:logger/logger.dart';
import 'package:elliptic/elliptic.dart' as elliptic;

import "../merkle/merkle_example.dart";
import "../helpers/ivHelper.dart";
import "../managers/Cryptor.dart";
import "../models/WOTSSignatureItem.dart";
import "LogManager.dart";


/*
* Notes on Giga-WOTS:
*
* Giga-WOTS is an implementation of WOTS signatures that allows
* chaining together the public keys in a way to prove signer identity.
*
* Instead of having the generate various sets of public keys in which a merkle
* root is computed, you only need to generate 2 keys (current key and next key).
* The current key signs the next public key to be used along with a message.
*
* This seems to be most promising in the application of post quantum code signing.
* Since asymmetric keys are vulnerable to quantum computers,
* utilizing a PQ signature verification method is important for verifying
* future software applications and versions.  Usually this is difficult to realize
* because of having to generate all the keys first and include them in a tree to
* be verified.  By chaining the keys and signature verification together this
* implementation makes PQ code signing manageable.
*
*
*
* */


class WOTSManager {
  static final WOTSManager _shared = WOTSManager._internal();

  /// logging
  var logger = Logger(
    printer: PrettyPrinter(),
  );


  factory WOTSManager() {
    return _shared;
  }

  static const int _keySize = 32;  // size of leaf in bytes
  // static const int _numberOfLeaves = 32;
  // static const int _checksumSize = 32*256;
  static const int _maxNumberOfSignatures = 2048;

  static const int _numberOfJoinLeaves = 2;  // must be a multiple of 2

  int _messageIndex = 1;

  int _leafKeySize = 32;
  int _numberOfLeaves = 32;
  int _checksumSize = 32*256;  // or 64*512


  /// private leaves
  List<String> _privLeaves = [];
  String _privChecksumLeaf = "";
  String _pubChecksumLeaf = "";
  String _xpub_recovery = "";

  /// public leaves
  List<String> _pubLeaves = [];
  List<String> _nextPubLeaves = [];

  String _topPublicKey = "";
  String _nextTopPublicKey = "";

  String _lastBlockHash = "";


  WOTSBasicSignatureChain _wotsChain = WOTSBasicSignatureChain(blocks: []);

  // WOTSOverlapSignatureChain _wotsJoinChain = WOTSOverlapSignatureChain(blocks: []);

  GigaWOTSSignatureChain _wotsSimpleJoinChain = GigaWOTSSignatureChain(chainId: "main", blocks: []);

  GigaWOTSSignatureDictionary _wotsSimpleChainDictionary = GigaWOTSSignatureDictionary(chains: []);


  /// Asymmetric digital signature algorithm
  final algorithm_secp256k1 = elliptic.getS256();


  int get messageIndex {
    return _messageIndex;
  }

  List<String> get privLeaves {
    return _privLeaves;
  }

  List<String> get pubLeaves {
    return _pubLeaves;
  }

  String get topPublicKey {
    return _topPublicKey;
  }

  String get nextTopPublicKey {
    return _nextTopPublicKey;
  }

  String get lastBlockHash {
    return _lastBlockHash;
  }

  /// Encryption Algorithm
  final algorithm_nomac = AesCtr.with256bits(macAlgorithm: MacAlgorithm.empty);

  /// this creates a stackoverflow
  final _logManager = LogManager();
  final _cryptor = Cryptor();

  WOTSManager._internal();

  initialize() async {
    logger.d("Initialize WOTSManager");
    await dotenv.load(fileName: "assets/.env",);

    // final envW = dotenv.env.toString();

    // logger.wtf("dotenv map wots: ${envW}");
  }

  reset() {
    _pubLeaves = [];
    _privLeaves = [];

    _privChecksumLeaf = "";
    _lastBlockHash = "";

    _messageIndex = 1;

    // _wotsChain = WOTSBasicSignatureChain(blocks: []);
    // _wotsJoinChain = WOTSOverlapSignatureChain(blocks: []);

    _wotsSimpleJoinChain = GigaWOTSSignatureChain(chainId: "",blocks: []);
    _wotsSimpleChainDictionary = GigaWOTSSignatureDictionary(chains: []);
  }

  setSignatureChainObject(GigaWOTSSignatureChain chain) {
    _wotsSimpleJoinChain = chain;
    _wotsSimpleChainDictionary.chains = [chain];
  }

  /// BEGIN - Basic WOTS implementation ----------------------------------------
  ///
  /// creates the first "genesis" WOTS private/public leaves
  Future<void> createRootTopPubKey(List<int> rootKey) async {
    await _createTopPubKey(rootKey, 0);
  }

  /// create private and public values for signing and verifying
  Future<void> createTopPubKey(List<int> rootKey, int msgIndex) async {
    await _createTopPubKey(rootKey, msgIndex);
  }

  /// create private and public values for signing and verifying
  Future<void> _createTopPubKey(List<int> rootKey, int msgIndex) async {
    logger.d("\n\t\t--------------------------createPubKeyWOTS START - [${msgIndex}]--------------------------");
    final startTime = DateTime.now();

    _pubLeaves = [];
    _privLeaves = [];
    _privChecksumLeaf = "";
    _messageIndex = msgIndex;

    if (rootKey.isEmpty || rootKey.length != _keySize) {
      rootKey = List<int>.filled(_keySize, 0);
    }

    final encKey = SecretKey(rootKey);

    final bigPad = List<int>.filled((_keySize * _numberOfLeaves).toInt(), 0);

    final nonce = ivHelper().getIv4x4(0, 0, _messageIndex, 0);
    // logger.d("ivHelper nonce: $nonce");

    /// Encrypt the zero pad
    final secretBox = await algorithm_nomac.encrypt(
      bigPad,
      secretKey: encKey,
      nonce: nonce,
    );

    /// hash the private keys together to get checksum leaf
    _privChecksumLeaf = _cryptor.sha256(hex.encode(secretBox.cipherText));
    // _privChecksumLeaf = hex.encode(cryptor.getRandomBytes(32));

    List<int> publicPad = [];
    final numLeaves = secretBox.cipherText.length / _keySize;

    /// compute the public leaves from private hashes
    for (var index = 0; index < numLeaves; index++) {

      /// get private leaf block
      final leaf = secretBox.cipherText.sublist(
        index * _keySize,
        _keySize * (index + 1),
      );

      /// add private leaf block
      _privLeaves.add(hex.encode(leaf));

      /// compute the public leaf hash
      var leafHash = hex.encode(leaf);
      for (var i = 0; i < 255; i++) {
        leafHash = _cryptor.sha256(leafHash);
      }

      /// add public leaf hash
      _pubLeaves.add(leafHash);
      publicPad.addAll(hex.decode(leafHash));
    }

    /// Compute the public checksum leaf value
    // var pubChecksumLeaf = _privChecksumLeaf;
    for (var i = 0; i < _checksumSize-1; i++) {
      _pubLeaves.last = _cryptor.sha256(_pubLeaves.last);
    }
    logger.d("pubChecksumLeaf: ${_pubLeaves.last}");
    publicPad.addAll(hex.decode(_pubLeaves.last));

    /// add checksum public leaf value to public leaf array
    // publicPad.addAll(hex.decode(pubChecksumLeaf));
    // _pubLeaves.add(pubChecksumLeaf);

    _logManager.logLongMessage("\nmessageIndex: $_messageIndex\n"
        "_privLeaves: $_privLeaves\n\n"
        "_pubLeaves: $_pubLeaves");

    /// hash public leaf values with checksum to get top pub hash
    _topPublicKey = _cryptor.sha256(hex.encode(publicPad));
    logger.d("_topPublicKey: ${_topPublicKey}");

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("createPubKeyWOTS: time diff: ${timeDiff.inMilliseconds} ms");

    logger.d("\n\t\t--------------------------createPubKeyWOTS END - [${_messageIndex}]--------------------------");
  }

  /// create WOTS signature for a message
  Future<WOTSBasicSignatureItem?> signMessage(List<int> key, int msgIndex, String message) async {
    logger.d("\n\t\t--------------------------START: signMessage--------------------------");
    logger.d("signMessage[$msgIndex]: ${message}");

    final startTime = DateTime.now();
    final timestamp = startTime.toIso8601String();

    if (msgIndex <= _wotsChain.blocks.length) {
      msgIndex = _wotsChain.blocks.length + 1;
    }

    /// create private/public key leaves
    await _createTopPubKey(key, msgIndex);

    var messageItem = BasicMessageData.fromRawJson(message);
    if (messageItem == null) {
      messageItem = BasicMessageData(
          time: timestamp,
          message: message,
          signature: "",
        );
    }

    _logManager.logLongMessage("signMessage: message to hash: ${messageItem.toRawJson()}");

    final messageHash = _cryptor.sha256(messageItem.toRawJson());
    final messageHashBytes = hex.decode(messageHash);
    logger.d("signMessage: messageHash: $messageHash");

    var printSignatureBytes = "";
    List<String> signature = [];
    int index = 0;
    int checksum = 0;
    /// compute the WOTS signature
    for (var c in messageHashBytes) {
      printSignatureBytes += "${c}\n";
      /// add hash values for checksum
      checksum = checksum + 255 - c;
      var leafHash = _privLeaves[index];
      for (var i = 1; i < 256 - c; i++) {
        leafHash = _cryptor.sha256(leafHash);
      }
      signature.add(leafHash);
      index += 1;
    }
    logger.d("printSignatureBytes: $printSignatureBytes");

    /// Compute the checksum leaf value, 32x256 = 8192
    var checksumHash = _privChecksumLeaf;
    for (var i = 1; i < 8192-checksum; i++) {
      checksumHash = _cryptor.sha256(checksumHash);
    }
    // logger.d("checksumHash leaf: ${checksumHash}");

    /// create WOTS signature object
    WOTSBasicSignatureItem wotsItem = WOTSBasicSignatureItem(
      id: msgIndex,
      publicKey: _topPublicKey,
      signature: signature,
      checksum: checksumHash,
      message: messageItem,
    );

    _logManager.logLongMessage("wotsItem: ${wotsItem.toRawJson()}");

    _wotsChain.blocks.add(wotsItem);

    /// sort blocks in the chain by index
    _wotsChain.blocks.sort((a, b) => a.id.compareTo(b.id));

    _logManager.logLongMessage("WOTSManager.signMessage:\n_wotsChain[${_wotsChain.blocks.length}]\n"
        "[${_wotsChain.toRawJson().length} bytes] | [${(_wotsChain.toRawJson().length/1024).toStringAsFixed(2)} KB]\n"
        "chain: ${_wotsChain.toRawJson()}");

    /// get last block hash in the chain
    _lastBlockHash = _cryptor.sha256(_wotsChain.blocks.last.toRawJson());
    logger.d("lastBlockHash: ${_lastBlockHash}");

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("signMessage: time diff: ${timeDiff.inMilliseconds} ms");

    logger.d("\n\t\t--------------------------END: signMessage--------------------------");

    return wotsItem;
  }

  /// verify WOTS signature for a message
  Future<bool> verifySignature(WOTSBasicSignatureItem? item) async {
    logger.d("\n\t\t--------------------------START: verifySignature--------------------------");

    if (item == null) {
      return false;
    }

    final startTime = DateTime.now();

    final topPublicKey = item.publicKey;
    final sig = item.signature;
    final csum = item.checksum;
    final message = item.message;
    _logManager.logLongMessage("message to hash 2: ${message.toRawJson()}");

    final messageHash = _cryptor.sha256(message.toRawJson());
    final messageHashBytes = hex.decode(messageHash);
    _logManager.logLongMessage("messageHash: ${messageHash}");

    var printSignatureBytes = "";
    List<int> checkPublicLeaves = [];
    int index = 0;
    int checksum = 0;

    /// compute the public leaves from the signature and message hash
    for (var c in messageHashBytes) {
      printSignatureBytes += "${c}\n";

      /// add message hash values for checksum
      checksum = checksum + 255 - c;
      var leafHash = sig[index];
      for (var i = 0; i < c; i++) {
        leafHash = _cryptor.sha256(leafHash);
      }
      checkPublicLeaves.addAll(hex.decode(leafHash));
      index += 1;
    }

    logger.d("verifySignature: printSignatureBytes:\n\n$printSignatureBytes");


    /// Compute the public checksum leaf value
    var checksig = csum;
    for (var i = 0; i < checksum; i++) {
      checksig = _cryptor.sha256(checksig);
    }
    logger.d("checksig: ${checksig}");

    /// add checksum hash to the public leaves
    checkPublicLeaves.addAll(hex.decode(checksig));

    /// hash the public leaves + checksum to get top pub hash
    final checkTopPubHash = _cryptor.sha256(hex.encode(checkPublicLeaves));
    logger.d("checkTopPubHash: ${checkTopPubHash}");

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("verifySignature: time diff: ${timeDiff.inMilliseconds} ms");

    logger.d("\n\t\t--------------------------END: verifySignature--------------------------");

    return checkTopPubHash == topPublicKey;
  }

  /// END - Basic WOTS implementation ------------------------------------------



  /// BEGIN - Giga-WOTS (next top public key protocol) -------------------------
  ///
  Future<void> createGigaWotTopPubKey(List<int> rootKey, int msgIndex, int bitSecurity, bool doRecovery) async {
    await _createGigaWotTopPubKey(rootKey, msgIndex, bitSecurity, doRecovery);
  }

  /// create private and public values for signing and verifying
  Future<void> _createGigaWotTopPubKey(List<int> rootKey, int msgIndex, int bitSecurity, bool doRecovery) async {
    logger.d("\n\t\t--------------------------_createGigaWotTopPubKey START - [${msgIndex}]--------------------------");
    final startTime = DateTime.now();

    _pubLeaves = [];
    _privLeaves = [];

    if (bitSecurity != 256 && bitSecurity != 512) {
      bitSecurity = 256;
    }

    _leafKeySize = (bitSecurity/8).toInt();

    if (bitSecurity == 256) {
      _checksumSize = 32*256;
      _numberOfLeaves = _leafKeySize;
    } else {
      _checksumSize = 64*512;
      _numberOfLeaves = _leafKeySize;
    }

    if (rootKey.isEmpty || rootKey.length != _keySize) {
      rootKey = List<int>.filled(_keySize, 0);
    }

    final encKey = SecretKey(rootKey);

    final bigPad = List<int>.filled((_leafKeySize * _numberOfLeaves).toInt(), 0);

    final nonce = ivHelper().getIv4x4(0, 0, msgIndex, 0);

    /// Encrypt the zero pad
    final secretBox = await algorithm_nomac.encrypt(
      bigPad,
      secretKey: encKey,
      nonce: nonce,
    );

    List<int> publicPad = [];
    List<Uint8List> pubData = [];

    /// TODO: modify this logic for recovery
    /// do Wots top key for recovery key
    ///
    if (doRecovery) {
      _xpub_recovery = await _createRecovery(msgIndex, bitSecurity);
      publicPad.addAll(hex.decode(_xpub_recovery));
      pubData.add(Uint8List.fromList(hex.decode(_xpub_recovery)));
      // logger.d("xpub_recovery: ${xpub_recovery}");
    }

    final numLeaves = secretBox.cipherText.length / _leafKeySize;

    var printOutPubs = "";
    var printOutPrivs = "";
    /// compute the public leaves from private hashes
    for (var index = 0; index < numLeaves; index++) {
      /// get private leaf block
      var leaf = secretBox.cipherText.sublist(
        index * _leafKeySize,
        _leafKeySize * (index + 1),
      );

      _privLeaves.add(hex.encode(leaf));
      printOutPrivs += hex.encode(leaf) + "\n";

      /// compute the public leaf hash
      var leafHash = hex.encode(leaf);
      for (var i = 0; i < bitSecurity - 1; i++) {
        if (bitSecurity == 256) {
          leafHash = _cryptor.sha256(leafHash);
        } else {
          leafHash = _cryptor.sha512(leafHash);
        }
      }

      printOutPubs += leafHash + "\n";

      /// add public leaf hash
      _pubLeaves.add(leafHash);
      publicPad.addAll(hex.decode(leafHash));
      pubData.add(Uint8List.fromList(hex.decode(leafHash)));
    }

    // logger.d("_pubLeaves[$msgIndex]: first: ${_pubLeaves.first}, last: ${_pubLeaves.last}");


    _privChecksumLeaf = _cryptor.sha256(hex.encode(secretBox.cipherText));
    printOutPrivs += _privChecksumLeaf + "\n";

    /// Compute the public checksum leaf value
    _pubChecksumLeaf = _privChecksumLeaf;
    for (var i = 0; i < _checksumSize-1; i++) {
      _pubChecksumLeaf = _cryptor.sha256(_pubChecksumLeaf);
    }

    printOutPubs += _pubChecksumLeaf + "\n";
    publicPad.addAll(hex.decode(_pubChecksumLeaf));
    pubData.add(Uint8List.fromList(hex.decode(_pubChecksumLeaf)));
    // logger.d("printOutPrivs[$msgIndex]:\n\n$printOutPrivs");
    // logger.d("printOutPubs[$msgIndex]:\n\n$printOutPubs");

    if (bitSecurity == 256) {
      _topPublicKey = getTree(pubData, 256).last;
    } else {
      _topPublicKey = getTree(pubData, 512).last;
    }

    _nextTopPublicKey = await _createNextGigaWotTopPubKey(rootKey, msgIndex, bitSecurity);

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("createPubKeyWOTS:_topPublicKey: ${_topPublicKey}\ntime diff: ${timeDiff.inMilliseconds} ms");

    logger.d("\n\t\t--------------------------_createGigaWotTopPubKey END - [${msgIndex}]--------------------------");
  }

  /// get the next top public key to add to current signature
  Future<String> _createNextGigaWotTopPubKey(List<int> rootKey, int msgIndex, int bitSecurity) async {
    logger.d("\n\t\t--------------------------_createNextGigaWotTopPubKey START - [${msgIndex}]--------------------------");
    final startTime = DateTime.now();

    _nextPubLeaves = [];
    var nextPrivLeaves = [];
    final nextMessageIndex = msgIndex + 1;

    if (bitSecurity != 256 && bitSecurity != 512) {
      bitSecurity = 256;
    }

    _leafKeySize = (bitSecurity/8).toInt();

    if (bitSecurity == 256) {
      _checksumSize = 32*256;
      _numberOfLeaves = _leafKeySize;
    } else {
      _checksumSize = 64*512;
      _numberOfLeaves = _leafKeySize;
    }

    if (rootKey.isEmpty || rootKey.length != _keySize) {
      rootKey = List<int>.filled(_keySize, 0);
    }

    final encKey = SecretKey(rootKey);

    final bigPad = List<int>.filled((_leafKeySize * _numberOfLeaves).toInt(), 0);

    final nonce = ivHelper().getIv4x4(0, 0, nextMessageIndex, 0);
    // logger.d("ivHelper nonce: $nonce");

    /// Encrypt the zero pad
    final secretBox = await algorithm_nomac.encrypt(
      bigPad,
      secretKey: encKey,
      nonce: nonce,
    );

    List<int> publicPad = [];
    List<Uint8List> pubData = [];

    // if (_xpub_recovery.isNotEmpty) {
    //   publicPad.addAll(hex.decode(_xpub_recovery));
    //   pubData.add(Uint8List.fromList(hex.decode(_xpub_recovery)));
    // }

    final numLeaves = secretBox.cipherText.length / _leafKeySize;

    /// compute the public leaves from private hashes
    for (var index = 0; index < numLeaves; index++) {
      /// get private leaf block
      final leaf = secretBox.cipherText.sublist(
        index * _leafKeySize,
        _leafKeySize * (index + 1),
      );

      /// add private leaf block
      nextPrivLeaves.add(hex.encode(leaf));

      /// compute the public leaf hash
      var leafHash = hex.encode(leaf);
      for (var i = 0; i < bitSecurity - 1; i++) {
        if (bitSecurity == 256) {
          leafHash = _cryptor.sha256(leafHash);
        } else {
          leafHash = _cryptor.sha512(leafHash);
        }
      }

      /// add public leaf hash
      _nextPubLeaves.add(leafHash);
      publicPad.addAll(hex.decode(leafHash));
      pubData.add(Uint8List.fromList(hex.decode(leafHash)));
    }

    // logger.d("\nmessageIndex: $nextMessageIndex\nnextPrivLeaves: first: ${nextPrivLeaves.first}, last: ${nextPrivLeaves.last}");
    // logger.d("_nextPubLeaves[$msgIndex]: first: ${_nextPubLeaves.first}, last: ${_nextPubLeaves.last}");


    var checksumLeaf = _cryptor.sha256(hex.encode(secretBox.cipherText));
    /// Compute the public checksum leaf value
    for (var i = 0; i < _checksumSize-1; i++) {
      if (bitSecurity == 256) {
        checksumLeaf = _cryptor.sha256(checksumLeaf);
      } else {
        checksumLeaf = _cryptor.sha512(checksumLeaf);
      }
    }

    // logger.d("\nmessageIndex: $nextMessageIndex\nchecksumLeaf: ${checksumLeaf}");

    publicPad.addAll(hex.decode(checksumLeaf));
    pubData.add(Uint8List.fromList(hex.decode(checksumLeaf)));

    /// add checksum public leaf value to public leaf array
    // logger.d("\nnextMessageIndex: $nextMessageIndex\n"
    //     "pubLeaves: $pubLeaves");

    /// hash public leaf values with checksum to get top pub hash
    if (bitSecurity == 256) {
      // final nextTopPublicKey = _cryptor.sha256(hex.encode(publicPad));
      final nextTopPublicKeyMerkle = getTree(pubData, 256).last;
      // logger.d("nextTopPublicKeyMerkle: $nextTopPublicKeyMerkle");

      final endTime = DateTime.now();
      final timeDiff = endTime.difference(startTime);
      logger.d("_createNextGigaWotTopPubKey: time diff: ${timeDiff.inMilliseconds} ms");

      logger.d("\n\t\t--------------------------_createNextGigaWotTopPubKey END - [${nextMessageIndex}]--------------------------");
      return nextTopPublicKeyMerkle;
    } else {
      // final nextTopPublicKey = _cryptor.sha512(hex.encode(publicPad));
      final nextTopPublicKeyMerkle = getTree(pubData, 512).last;
      // logger.d("nextTopPublicKeyMerkle: $nextTopPublicKeyMerkle");

      final endTime = DateTime.now();
      final timeDiff = endTime.difference(startTime);
      logger.d("_createNextGigaWotTopPubKey: time diff: ${timeDiff.inMilliseconds} ms");

      logger.d("\n\t\t--------------------------_createNextGigaWotTopPubKey END - [${nextMessageIndex}]--------------------------");
      return nextTopPublicKeyMerkle;
    }

  }

  Future<String> _createRecovery(int msgIndex, int bitSecurity) async {

    var key_recovery = List.filled(32, 1);

    final xpub_recovery = await _createGigaWotRecoveryPubKey(key_recovery, msgIndex, bitSecurity);

    return xpub_recovery;
  }

  Future<String> _createGigaWotRecoveryPubKey(List<int> recoveryRootKey, int msgIndex, int bitSecurity) async {
    logger.d("\n\t\t--------------------------_createNextGigaWotTopPubKey START - [${msgIndex}]--------------------------");
    final startTime = DateTime.now();

    List<String> publicLeaves = [];
    List<String> privLeaves = [];

    if (bitSecurity != 256 && bitSecurity != 512) {
      bitSecurity = 256;
    }

    var leafKeySize = (bitSecurity/8).toInt();
    var numberOfLeaves = leafKeySize;
    var checksumSize = 32*256;

    if (bitSecurity == 256) {
      checksumSize = 32*256;
    } else {
      checksumSize = 64*512;
    }

    if (recoveryRootKey.isEmpty || recoveryRootKey.length != _keySize) {
      recoveryRootKey = List<int>.filled(_keySize, 0);
    }

    final encKey = SecretKey(recoveryRootKey);

    final bigPad = List<int>.filled((leafKeySize * numberOfLeaves).toInt(), 0);

    final nonce = ivHelper().getIv4x4(0, 0, msgIndex, 0);
    // logger.d("ivHelper nonce: $nonce");

    /// Encrypt the zero pad
    final secretBox = await algorithm_nomac.encrypt(
      bigPad,
      secretKey: encKey,
      nonce: nonce,
    );

    List<int> publicPad = [];
    List<Uint8List> pubData = [];

    final numLeaves = secretBox.cipherText.length / leafKeySize;

    /// compute the public leaves from private hashes
    for (var index = 0; index < numLeaves; index++) {
      /// get private leaf block
      final leaf = secretBox.cipherText.sublist(
        index * leafKeySize,
        leafKeySize * (index + 1),
      );

      final privateKeyGen = elliptic.PrivateKey(
        algorithm_secp256k1,
        BigInt.parse(hex.encode(leaf), radix: 16),
      );

      final pubGen = privateKeyGen.publicKey;
      final pubHex = pubGen.toCompressedHex();

      /// add private leaf block
      // privLeaves.add(hex.encode(leaf));
      privLeaves.add(pubHex);

      /// compute the public leaf hash
      // var leafHash = hex.encode(leaf);
      var leafHash = pubHex;

      for (var i = 0; i < bitSecurity - 1; i++) {
        if (bitSecurity == 256) {
          leafHash = _cryptor.sha256(leafHash);
        } else {
          leafHash = _cryptor.sha512(leafHash);
        }
      }

      /// add public leaf hash
      publicLeaves.add(leafHash);
      if (index < numLeaves) {
        publicPad.addAll(hex.decode(leafHash));
        pubData.add(Uint8List.fromList(hex.decode(leafHash)));
      }
    }

    var checksumLeaf = _cryptor.sha256(hex.encode(secretBox.cipherText));
    /// Compute the public checksum leaf value
    for (var i = 0; i < checksumSize-1; i++) {
      if (bitSecurity == 256) {
        checksumLeaf = _cryptor.sha256(checksumLeaf);
      } else {
        checksumLeaf = _cryptor.sha512(checksumLeaf);
      }
    }

    // logger.d("\nmessageIndex: $nextMessageIndex\nchecksumLeaf: ${checksumLeaf}");

    publicPad.addAll(hex.decode(checksumLeaf));
    pubData.add(Uint8List.fromList(hex.decode(checksumLeaf)));

    /// add checksum public leaf value to public leaf array
    // logger.d("\nnextMessageIndex: $nextMessageIndex\n"
    //     "pubLeaves: $pubLeaves");

    /// hash public leaf values with checksum to get top pub hash
    if (bitSecurity == 256) {
      // final nextTopPublicKey = _cryptor.sha256(hex.encode(publicPad));
      final recoveryTopPublicKeyMerkle = getTree(pubData, 256).last;
      // logger.d("nextTopPublicKeyMerkle: $nextTopPublicKeyMerkle");

      final endTime = DateTime.now();
      final timeDiff = endTime.difference(startTime);
      logger.d("_createNextGigaWotTopPubKey: time diff: ${timeDiff.inMilliseconds} ms");

      logger.d("\n\t\t--------------------------_createNextGigaWotTopPubKey END - [${msgIndex}]--------------------------");
      return recoveryTopPublicKeyMerkle;
    } else {
      // final nextTopPublicKey = _cryptor.sha512(hex.encode(publicPad));
      final recoveryTopPublicKeyMerkle = getTree(pubData, 512).last;
      // logger.d("recoveryTopPublicKeyMerkle: $nextTopPublicKeyMerkle");

      final endTime = DateTime.now();
      final timeDiff = endTime.difference(startTime);
      logger.d("_createNextGigaWotTopPubKey: time diff: ${timeDiff.inMilliseconds} ms");

      logger.d("\n\t\t--------------------------_createNextGigaWotTopPubKey END - [${msgIndex}]--------------------------");
      return recoveryTopPublicKeyMerkle;
    }

  }

  /// create WOTS signature for a message
  Future<GigaWOTSSignatureItem?> signGigaWotMessage(
      List<int> key,
      String chainId,
      String inputLastBlockHash,
      WOTSMessageData message,
      int bitSecurity,
      bool doRecovery,
      ) async {
    logger.d("\n\t\t--------------------------START: signGigaWotMessage--------------------------");
    // _logManager.printJSON(4, "signMessage[$msgIndex]: ", message.toJson());

    final msgIndex = message.messageIndex;
    final startTime = DateTime.now();
    // final timestamp = startTime.toIso8601String();

    if (bitSecurity != 256 && bitSecurity != 512) {
      bitSecurity = 256;
    }

    if (bitSecurity == 256) {
      _checksumSize = 32*256;
      _numberOfLeaves = _leafKeySize;
    } else {
      _checksumSize = 64*512;
      _numberOfLeaves = _leafKeySize;
    }

    if (inputLastBlockHash.isNotEmpty) {
      _lastBlockHash = inputLastBlockHash;
    }

    /// create private/public key leaves
    await _createGigaWotTopPubKey(key, msgIndex, bitSecurity, doRecovery);

    message.nextPublicKey = _nextTopPublicKey;
    message.publicKey = _topPublicKey;


    /// calculate previous signature merkle/hash
    GigaWOTSSignatureItem? previousSignatureItem;
    try {
      var thisChain = _wotsSimpleChainDictionary.chains.firstWhere((
          element) => element.chainId == chainId);
      thisChain.blocks.sort((a, b) => a.message.messageIndex.compareTo(b.message.messageIndex));

      if (thisChain.blocks.length > 0) {
        previousSignatureItem = thisChain.blocks[thisChain.blocks.length - 1];
        // _logManager.printJSON(4, "previousSignatureItem: ", previousSignatureItem.toJson());

        if (previousSignatureItem != null) {
          List<Uint8List> prevSigData = [];

          String previousMessageHash;
          if (bitSecurity == 256) {
            previousMessageHash = _cryptor.sha256(previousSignatureItem.message.toRawJson());
          } else {
            previousMessageHash = _cryptor.sha512(previousSignatureItem.message.toRawJson());
          }
          logger.d("sign previousMessageHash: ${previousMessageHash}");

          /// add signature data blocks
          for (var s in previousSignatureItem.signature) {
            /// TODO: unit conversion
            prevSigData.add(Uint8List.fromList(hex.decode(s)));
            // prevSigData.add(Uint8List.fromList(base64.decode(s)));
          }

          /// add previous checksum
          /// TODO: unit conversion
          // prevSigData.add(Uint8List.fromList(base64.decode(previousSignatureItem.checksum)));
          prevSigData.add(Uint8List.fromList(hex.decode(previousSignatureItem.checksum)));

          String previousSignatureMerkleRoot;
          if (bitSecurity == 256) {
            previousSignatureMerkleRoot = getTree(prevSigData, 256).last;
          } else {
            previousSignatureMerkleRoot = getTree(prevSigData, 512).last;
          }
          logger.d("sign previousSignatureMerkleRoot: ${previousSignatureMerkleRoot}");

          /// set previous hash from preceeding block
          message.previousHash = previousSignatureMerkleRoot;
        }
      }
    } catch (e) {
      logger.e("exception occurred: $e");
    }

    _logManager.printJSON(4, "signMessage[$msgIndex]: ", message.toJson());


    List<int> messageHashBytes;
    var messageHash = "";
    if (bitSecurity == 256) {
      messageHash = _cryptor.sha256(message.toRawJson());
      logger.d("messageHash: $messageHash");
      messageHashBytes = hex.decode(messageHash);
    } else {
      messageHash = _cryptor.sha512(message.toRawJson());
      logger.d("messageHash: $messageHash");
      messageHashBytes = hex.decode(messageHash);
    }

    // var printOutSig = "";
    // var printHashBytes = "";
    // var printChecksumBytes = "";
    List<Uint8List> sigData = [];
    List<String> signature = [];
    int index = 0;
    int checksum = 0;
    /// compute the WOTS signature
    for (var c in messageHashBytes) {
      /// add hash values for checksum
      checksum += bitSecurity - c;
      // printHashBytes += "${c}\n";
      // printChecksumBytes += "${bitSecurity - c}\n";

      // checksum = bitSecurity - c;
      var leafHash = _privLeaves[index];
      for (var i = 1; i < bitSecurity - c; i++) {
        if (bitSecurity == 256) {
          leafHash = _cryptor.sha256(leafHash);
        } else {
          leafHash = _cryptor.sha512(leafHash);
        }
      }

      // printOutSig += leafHash + "\n";
      // logger.d("signature leaf[$index]: ${leafHash}");

      /// TODO: unit conversion
      signature.add(leafHash);
      // signature.add(base64.encode(hex.decode(leafHash)));
      sigData.add(Uint8List.fromList(hex.decode(leafHash)));

      index += 1;
    }
    // logger.d("printHashBytes[$msgIndex]:$checksum\n\n$printHashBytes");
    // logger.d("printChecksumBytes[$msgIndex]:$checksum\n\n$printChecksumBytes");
    // logger.d("printOutSig[$msgIndex][${signature.length}]:\n\n$printOutSig");

    var checksumLeaf = _privChecksumLeaf;

    /// Compute the checksum leaf value, 32x256 = 8192, OR 64*512 = 32768
    for (var i = 1; i < _checksumSize-checksum; i++) {
      if (bitSecurity == 256) {
        checksumLeaf = _cryptor.sha256(checksumLeaf);
      } else {
        checksumLeaf = _cryptor.sha512(checksumLeaf);
      }
    }
    // printOutSig += checksumLeaf + "\n";

    /// add checksum leaf to data for merkle calculation
    sigData.add(Uint8List.fromList(hex.decode(checksumLeaf)));
    // logger.d("printOutSig[$msgIndex][${signature.length}]:\n\n$printOutSig");


    /// compute signature merkle root
    ///
    var signatureMerkleRoot;
    if (bitSecurity == 256) {
      signatureMerkleRoot = getTree(sigData, 256).last;
    } else {
      signatureMerkleRoot = getTree(sigData, 512).last;
    }
    logger.d("signatureMerkleRoot: ${signatureMerkleRoot}");

    var merkleHash = messageHash + signatureMerkleRoot;
    // logger.d("merkleHash: ${merkleHash}");

    /// hash together
    merkleHash = _cryptor.sha256(merkleHash);
    logger.d("merkleHash Hash: ${merkleHash}");


    /// create WOTS signature object
    /// TODO: unit conversion
    GigaWOTSSignatureItem wotsItem = GigaWOTSSignatureItem(
      id: chainId,
      recovery: _xpub_recovery,
      signature: signature,
      checksum: checksumLeaf,
      // checksum: base64.encode(hex.decode(checksumLeaf)),
      message: message,
    );

    // logger.d("wotsItem: ${wotsItem.toRawJson()}");

    GigaWOTSSignatureChain currentChain = GigaWOTSSignatureChain(chainId: chainId, blocks: []);

    if (_wotsSimpleChainDictionary.chains.length == 0) {
      currentChain.chainId = wotsItem.id;
      currentChain.blocks.add(wotsItem);

      _wotsSimpleJoinChain.chainId = wotsItem.id;
      _wotsSimpleJoinChain.blocks.add(wotsItem);
      _wotsSimpleJoinChain = currentChain;
      _wotsSimpleChainDictionary.chains.add(_wotsSimpleJoinChain);
    } else {
      try {
        final thisChain = _wotsSimpleChainDictionary.chains.firstWhere((
            element) => element.chainId == chainId);
        _wotsSimpleJoinChain = thisChain;
        _wotsSimpleJoinChain.chainId = chainId;
        _wotsSimpleJoinChain.blocks.add(wotsItem);
        _wotsSimpleChainDictionary.chains.add(currentChain);
      } catch (e) {
        currentChain.chainId = wotsItem.id;
        currentChain.blocks.add(wotsItem);
        _wotsSimpleJoinChain.chainId = chainId;
        _wotsSimpleJoinChain.blocks.add(wotsItem);
        _wotsSimpleChainDictionary.chains.add(currentChain);
      }
    }

    /// sort blocks in the chain by index
    _wotsSimpleJoinChain.blocks.sort((a, b) => a.message.messageIndex.compareTo(b.message.messageIndex));
    // logger.d("_wotsSimpleJoinChain: ${_wotsSimpleJoinChain.toRawJson()}");

    _logManager.printJSON(4, "_wotsSimpleJoinChain: ", _wotsSimpleJoinChain.toJson());

    /// get last block hash in the chain
    if (bitSecurity == 256) {
      _lastBlockHash = _cryptor.sha256(_wotsSimpleJoinChain.blocks.last.toRawJson());
    } else {
      _lastBlockHash = _cryptor.sha512(_wotsSimpleJoinChain.blocks.last.toRawJson());
    }

    _lastBlockHash = merkleHash;

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("signMessage: time diff: ${timeDiff.inMilliseconds} ms");
    logger.d("\n\t\t--------------------------END: signGigaWotMessage--------------------------");

    /// reset recovery key
    _xpub_recovery = "";

    return wotsItem;
  }

  /// verify WOTS signature for a message
  Future<bool> verifyGigaWotSignature(GigaWOTSSignatureItem? item) async {
    logger.d("\n\t\t--------------------------START: verifyGigaWotSignature--------------------------");

    if (item == null) {
      return false;
    }

    _logManager.printJSON(4, "verifyGigaWotSignature: ", item!.toJson());

    final startTime = DateTime.now();

    final chainIdentifier = item.id;
    final topPublicKey = item.message.publicKey;
    final previousHash = item.message.previousHash;
    final messageIndex = item.message.messageIndex;
    final bitSecurity = hex.decode(topPublicKey).length*8;

    var previousPublicKey = "";

    GigaWOTSSignatureItem? previousSignatureItem;
    try {
      var thisChain = _wotsSimpleChainDictionary.chains.firstWhere((
          element) => element.chainId == chainIdentifier);
      thisChain.blocks.sort((a, b) => a.message.messageIndex.compareTo(b.message.messageIndex));

      if (thisChain.blocks.length > 1) {
        previousSignatureItem = thisChain.blocks[thisChain.blocks.length - 2];
        // _logManager.printJSON(4, "previousSignatureItem: ", previousSignatureItem.toJson());
      }

      if (thisChain.blocks.length > 1) {
        /// we start message index increment at 1, but is 0-indexed
        previousPublicKey = thisChain.blocks[messageIndex-2].message.nextPublicKey;

        if (previousPublicKey != topPublicKey) {
          logger.e("ERROR: previousPublicKey: ${previousPublicKey} != topPublicKey: ${topPublicKey}");
          return false;
        } else {
          logger.wtf("SUCCESS: previousPublicKey == topPublicKey: $topPublicKey");
        }
      }
    } catch (e) {
      logger.e("exception occurred: $e");
    }

    final sig = item.signature;
    final message = item.message;

    String messageHash = "";
    List<int> messageHashBytes;
    if (bitSecurity == 256) {
      messageHash = _cryptor.sha256(message.toRawJson());
      logger.d("messageHash: ${messageHash}");
      messageHashBytes = hex.decode(messageHash);
    } else {
      messageHash = _cryptor.sha512(message.toRawJson());
      logger.d("messageHash: ${messageHash}");
      messageHashBytes = hex.decode(messageHash);
    }

    // List<int> checkPublicLeaves = [];
    List<Uint8List> pubData = [];
    List<Uint8List> sigData = [];

    // final recoveryKey = item.recovery;
    // if (recoveryKey != null) {
    //   checkPublicLeaves.addAll(hex.decode(recoveryKey));
    //   pubData.add(Uint8List.fromList(hex.decode(recoveryKey)));
    // }

    int index = 0;
    int checksum = 0;

    // var printChecksumBytes = "";
    var printOutSigPubs = "";
    var leaves = [];
    /// compute the public leaves from the signature and message hash
    for (var c in messageHashBytes) {
      /// add message hash values for checksum
      checksum += bitSecurity - c;
      // printChecksumBytes += "${bitSecurity - c}\n";

      /// TODO: unit conversion
      var leafHash = sig[index];
      // var leafHash = hex.encode(base64.decode(sig[index]));
      sigData.add(Uint8List.fromList(hex.decode(leafHash)));

      for (var i = 0; i < c; i++) {
        if (bitSecurity == 256) {
          leafHash = _cryptor.sha256(leafHash);
        } else {
          leafHash = _cryptor.sha512(leafHash);
        }
      }

      leaves.add(leafHash);
      printOutSigPubs += leafHash + "\n";

      // checkPublicLeaves.addAll(hex.decode(leafHash));
      pubData.add(Uint8List.fromList(hex.decode(leafHash)));

      index += 1;
    }
    // logger.d("printChecksumBytes[$messageIndex]:$checksum\n\n$printChecksumBytes");
    // logger.d("printOutSigPubs[$messageIndex]:\n\n$printOutSigPubs");

    /// TODO: unit conversion
    var checksumLeaf = item.checksum;
    // var checksumLeaf = hex.encode(base64.decode(item.checksum));
    sigData.add(Uint8List.fromList(hex.decode(checksumLeaf)));
    logger.d("checksumLeaf start: ${checksumLeaf}");

    /// Compute the public checksum leaf value
    for (var i = 0; i < checksum; i++) {
      if (bitSecurity == 256) {
        checksumLeaf = _cryptor.sha256(checksumLeaf);
      } else {
        checksumLeaf = _cryptor.sha512(checksumLeaf);
      }
    }
    logger.d("checksumLeaf end: ${checksumLeaf}");


    /// add checksum leaf to array
    pubData.add(Uint8List.fromList(hex.decode(checksumLeaf)));
    printOutSigPubs += checksumLeaf + "\n";
    logger.d("printOutSigPubs[$messageIndex]:\n\n$printOutSigPubs");

    String signatureMerkleRoot;
    if (bitSecurity == 256) {
      signatureMerkleRoot = getTree(pubData, 256).last;
    } else {
      signatureMerkleRoot = getTree(pubData, 512).last;
    }

    logger.d("signatureMerkleRoot: ${signatureMerkleRoot}");
    logger.d("messageHash: ${messageHash}");

    if (previousSignatureItem != null) {
      List<Uint8List> prevSigData = [];

      /// add signature data blocks
      for (var s in previousSignatureItem.signature) {
        /// TODO: unit conversion
        // prevSigData.add(Uint8List.fromList(base64.decode(s)));
        prevSigData.add(Uint8List.fromList(hex.decode(s)));
      }

      /// add previous checksum
      /// TODO: unit conversion
      prevSigData.add(Uint8List.fromList(hex.decode(previousSignatureItem.checksum)));
      // prevSigData.add(Uint8List.fromList(base64.decode(previousSignatureItem.checksum)));

      String previousSignatureMerkleRoot;
      if (bitSecurity == 256) {
        previousSignatureMerkleRoot = getTree(prevSigData, 256).last;
      } else {
        previousSignatureMerkleRoot = getTree(prevSigData, 512).last;
      }
      logger.d("previousSignatureMerkleRoot: ${previousSignatureMerkleRoot}");

      if (previousSignatureMerkleRoot != previousHash) {
        logger.d("merkleAndHash != phash");
      } else {
        logger.d("merkleAndHash == phash: success!!!");
      }
    }

    // logger.d("checkTopPubHash: ${checkTopPubHash}\ncheckTopPubMerkle: $checkTopPubMerkle");
    // logger.d("checkTopPubMerkle: $checkTopPubMerkle");

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("verifySignature: time diff: ${timeDiff.inMilliseconds} ms");

    logger.d("\n\t\t--------------------------END: verifyGigaWotSignature--------------------------");
    logger.d("$signatureMerkleRoot == $topPublicKey");

    return signatureMerkleRoot == topPublicKey;
    // return checkTopPubHash == topPublicKey;
  }

}