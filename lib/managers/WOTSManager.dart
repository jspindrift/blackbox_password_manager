import "dart:typed_data";
import 'package:flutter_dotenv/flutter_dotenv.dart';

import "package:cryptography/cryptography.dart";
import "package:convert/convert.dart";
import 'package:logger/logger.dart';

import "../helpers/ivHelper.dart";
import "../managers/Cryptor.dart";
import "../models/WOTSSignatureItem.dart";

import "LogManager.dart";


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
  static const int _numberOfLeaves = 32;
  static const int _checksumSize = 32*256;
  static const int _maxNumberOfSignatures = 2048;

  static const int _numberOfJoinLeaves = 2;  // must be a multiple of 2

  int _messageIndex = 1;

  /// private leaves
  List<String> _privLeaves = [];
  String _privChecksumLeaf = "";
  String _pubChecksumLeaf = "";

  /// public leaves
  List<String> _pubLeaves = [];
  String _topPublicKey = "";
  String _nextTopPublicKey = "";

  String _lastBlockHash = "";


  WOTSBasicSignatureChain _wotsChain = WOTSBasicSignatureChain(blocks: []);

  // WOTSOverlapSignatureChain _wotsJoinChain = WOTSOverlapSignatureChain(blocks: []);

  GigaWOTSSignatureChain _wotsSimpleJoinChain = GigaWOTSSignatureChain(chainId: "main", blocks: []);

  GigaWOTSSignatureDictionary _wotsSimpleChainDictionary = GigaWOTSSignatureDictionary(chains: []);

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
    var pubChecksumLeaf = _privChecksumLeaf;
    for (var i = 0; i < _checksumSize-1; i++) {
      pubChecksumLeaf = _cryptor.sha256(pubChecksumLeaf);
    }
    logger.d("pubChecksumLeaf: $pubChecksumLeaf");

    /// add checksum public leaf value to public leaf array
    publicPad.addAll(hex.decode(pubChecksumLeaf));
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

    _logManager.logLongMessage("message to hash 1: ${messageItem.toRawJson()}");

    final messageHash = _cryptor.sha256(messageItem.toRawJson());
    final messageHashBytes = hex.decode(messageHash);
    logger.d("messageHashHex: $messageHash");

    List<String> signature = [];
    int index = 0;
    int checksum = 0;
    /// compute the WOTS signature
    for (var c in messageHashBytes) {
      /// add hash values for checksum
      checksum = checksum + 255 - c;
      var leafHash = _privLeaves[index];
      for (var i = 1; i < 256 - c; i++) {
        leafHash = _cryptor.sha256(leafHash);
      }
      signature.add(leafHash);
      index += 1;
    }
    // logger.d("checksum int value: $checksum");

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

    List<int> checkPublicLeaves = [];
    int index = 0;
    int checksum = 0;

    /// compute the public leaves from the signature and message hash
    for (var c in messageHashBytes) {
      /// add message hash values for checksum
      checksum = checksum + 255 - c;
      var leafHash = sig[index];
      for (var i = 0; i < c; i++) {
        leafHash = _cryptor.sha256(leafHash);
      }
      checkPublicLeaves.addAll(hex.decode(leafHash));
      index += 1;
    }

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



  /// BEGIN - WOTS Simple Overlapping Chain (next top public key)
  ///
  Future<void> createGigaWotTopPubKey(List<int> rootKey, int msgIndex) async {
      await _createGigaWotTopPubKey(rootKey, msgIndex);
  }

    /// create private and public values for signing and verifying
  Future<void> _createGigaWotTopPubKey(List<int> rootKey, int msgIndex) async {
    logger.d("\n\t\t--------------------------_createGigaWotTopPubKey START - [${msgIndex}]--------------------------");
    final startTime = DateTime.now();

    _pubLeaves = [];
    _privLeaves = [];
    _privChecksumLeaf = "";
    // _messageIndex = msgIndex;

    if (rootKey.isEmpty || rootKey.length != _keySize) {
      rootKey = List<int>.filled(_keySize, 0);
    }

    final encKey = SecretKey(rootKey);

    final bigPad = List<int>.filled((_keySize * _numberOfLeaves).toInt(), 0);

    final nonce = ivHelper().getIv4x4(0, 0, msgIndex, 0);
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
    var pubChecksumLeaf = _privChecksumLeaf;
    for (var i = 0; i < _checksumSize-1; i++) {
      pubChecksumLeaf = _cryptor.sha256(pubChecksumLeaf);
    }
    logger.d("pubChecksumLeaf: $pubChecksumLeaf");

    /// add checksum public leaf value to public leaf array
    publicPad.addAll(hex.decode(pubChecksumLeaf));
    // _pubLeaves.add(pubChecksumLeaf);

    // _logManager.logLongMessage("\nmessageIndex: $msgIndex\n"
    //     "_privLeaves: $_privLeaves\n\n"
    //     "_pubLeaves: $_pubLeaves");
    _logManager.logLongMessage("\nmessageIndex: $msgIndex\n"
        "_pubLeaves: $_pubLeaves");
    /// hash public leaf values with checksum to get top pub hash
    _topPublicKey = _cryptor.sha256(hex.encode(publicPad));
    logger.d("_topPublicKey: ${_topPublicKey}");

    _nextTopPublicKey = await _createNextGigaWotTopPubKey(rootKey, msgIndex);

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("createPubKeyWOTS: time diff: ${timeDiff.inMilliseconds} ms");

    logger.d("\n\t\t--------------------------_createGigaWotTopPubKey END - [${msgIndex}]--------------------------");
  }

  /// get the next top public key to add to current signature
  Future<String> _createNextGigaWotTopPubKey(List<int> rootKey, int msgIndex) async {
    logger.d("\n\t\t--------------------------_createNextGigaWotTopPubKey START - [${msgIndex}]--------------------------");
    final startTime = DateTime.now();

    var pubLeaves = [];
    var privLeaves = [];
    // _privChecksumLeaf = "";
    // _messageIndex = msgIndex;
    final nextMessageIndex = msgIndex + 1;

    if (rootKey.isEmpty || rootKey.length != _keySize) {
      rootKey = List<int>.filled(_keySize, 0);
    }

    final encKey = SecretKey(rootKey);

    final bigPad = List<int>.filled((_keySize * _numberOfLeaves).toInt(), 0);

    final nonce = ivHelper().getIv4x4(0, 0, nextMessageIndex, 0);
    // logger.d("ivHelper nonce: $nonce");

    /// Encrypt the zero pad
    final secretBox = await algorithm_nomac.encrypt(
      bigPad,
      secretKey: encKey,
      nonce: nonce,
    );

    /// hash the private keys together to get checksum leaf
    final privateChecksumLeaf = _cryptor.sha256(hex.encode(secretBox.cipherText));
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
      privLeaves.add(hex.encode(leaf));

      /// compute the public leaf hash
      var leafHash = hex.encode(leaf);
      for (var i = 0; i < 255; i++) {
        leafHash = _cryptor.sha256(leafHash);
      }

      /// add public leaf hash
      pubLeaves.add(leafHash);
      publicPad.addAll(hex.decode(leafHash));
    }

    /// Compute the public checksum leaf value
    var pubChecksumLeaf = privateChecksumLeaf;
    for (var i = 0; i < _checksumSize-1; i++) {
      pubChecksumLeaf = _cryptor.sha256(pubChecksumLeaf);
    }
    // logger.d("pubChecksumLeaf: $pubChecksumLeaf");

    /// add checksum public leaf value to public leaf array
    publicPad.addAll(hex.decode(pubChecksumLeaf));

    // _logManager.logLongMessage("\nnextMessageIndex: $nextMessageIndex\n"
    //     "privLeaves: $privLeaves\n\n"
    //     "pubLeaves: $pubLeaves");
    _logManager.logLongMessage("\nmessageIndex: $msgIndex\n"
        "pubLeaves: $pubLeaves");

    /// hash public leaf values with checksum to get top pub hash
    final nextTopPublicKey = _cryptor.sha256(hex.encode(publicPad));
    logger.d("nextTopPublicKey: ${nextTopPublicKey}");

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("createPubKeyWOTS: time diff: ${timeDiff.inMilliseconds} ms");

    logger.d("\n\t\t--------------------------_createNextGigaWotTopPubKey END - [${msgIndex}]--------------------------");

    return nextTopPublicKey;
  }

  /// create WOTS signature for a message
  Future<GigaWOTSSignatureItem?> signGigaWotMessage(
      List<int> key,
      String chainId,
      String inputLastBlockHash,
      int msgIndex,
      WOTSMessageData message,
      ) async {
    logger.d("\n\t\t--------------------------START: signGigaWotMessage--------------------------");
    logger.d("signMessage[$msgIndex]: ${message.toRawJson()}");

    final startTime = DateTime.now();
    // final timestamp = startTime.toIso8601String();

    // if (msgIndex <= _wotsSimpleJoinChain.blocks.length) {
    //   msgIndex = _wotsSimpleJoinChain.blocks.length + 1;
    // }

    if (inputLastBlockHash.isNotEmpty) {
      _lastBlockHash = inputLastBlockHash;
    }

    /// create private/public key leaves
    await _createGigaWotTopPubKey(key, msgIndex);

    message.nextPublicKey = _nextTopPublicKey;

    // // var messageItem;
    // try {
    //   // messageItem = BasicMessageData.fromRawJson(message);
    //   // messageItem = message;//WOTSMessageData.fromRawJson(message.toRawJson());
    //
    //   message.nextPublicKey = _nextTopPublicKey;
    //
    //   // logger.wtf("got here");
    //
    // } catch (e) {
    //   logger.e("error json format: $e");
    //   return null;
    // }

    // messageItem

    _logManager.logLongMessage("message to hash 1: ${message.toRawJson()}");

    final messageHash = _cryptor.sha256(message.toRawJson());
    final messageHashBytes = hex.decode(messageHash);
    // logger.d("messageHashHex: $messageHash");

    List<String> signature = [];
    int index = 0;
    int checksum = 0;
    /// compute the WOTS signature
    for (var c in messageHashBytes) {
      /// add hash values for checksum
      checksum = checksum + 255 - c;
      var leafHash = _privLeaves[index];
      for (var i = 1; i < 256 - c; i++) {
        leafHash = _cryptor.sha256(leafHash);
      }
      signature.add(leafHash);
      index += 1;
    }
    // logger.d("checksum int value: $checksum");

    /// Compute the checksum leaf value, 32x256 = 8192
    var checksumHash = _privChecksumLeaf;
    for (var i = 1; i < 8192-checksum; i++) {
      checksumHash = _cryptor.sha256(checksumHash);
    }
    // logger.d("checksumHash leaf: ${checksumHash}");

    /// create WOTS signature object
    GigaWOTSSignatureItem wotsItem = GigaWOTSSignatureItem(
      id: chainId,
      signature: signature,
      checksum: checksumHash,
      message: message,
    );

    // _logManager.logLongMessage("wotsItem: ${wotsItem.toRawJson()}");


    GigaWOTSSignatureChain currentChain = GigaWOTSSignatureChain(chainId: chainId, blocks: []);
    // _wotsSimpleJoinChain.blocks.add(wotsItem);

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

    // if (_wotsSimpleJoinChain.blocks.length == 0) {
    //   currentChain.chainId = wotsItem.id;
    //   currentChain.blocks.add(wotsItem);
    //
    //   _wotsSimpleJoinChain.chainId = wotsItem.id;
    //   _wotsSimpleJoinChain.blocks.add(wotsItem);
    //   _wotsSimpleJoinChain = currentChain;
    // } else {
    //   try {
    //     _wotsSimpleJoinChain.chainId = chainId;
    //     _wotsSimpleJoinChain.blocks.add(wotsItem);
    //     _wotsSimpleChainDictionary.chains.add(currentChain);
    //   } catch (e) {
    //     currentChain.chainId = wotsItem.id;
    //     currentChain.blocks.add(wotsItem);
    //     _wotsSimpleJoinChain.chainId = chainId;
    //     _wotsSimpleJoinChain.blocks.add(wotsItem);
    //     _wotsSimpleChainDictionary.chains.add(currentChain);
    //   }
    // }

    // _logManager.logLongMessage("test _wotsSimpleChainDictionary: ${_wotsSimpleChainDictionary.toRawJson()}");


    /// sort blocks in the chain by index
    _wotsSimpleJoinChain.blocks.sort((a, b) => a.message.messageIndex.compareTo(b.message.messageIndex));
    _logManager.logLongMessage("_wotsSimpleJoinChain: ${_wotsSimpleJoinChain.toRawJson()}");

    // _logManager.logLongMessage("WOTSManager.signMessage:\n_wotsChain[${_wotsSimpleJoinChain.blocks.length}]\n"
    //     "[${_wotsSimpleJoinChain.toRawJson().length} bytes] | [${(_wotsSimpleJoinChain.toRawJson().length/1024).toStringAsFixed(2)} KB]\n"
    //     "chain: ${_wotsSimpleJoinChain.toRawJson()}");

    /// get last block hash in the chain
    _lastBlockHash = _cryptor.sha256(_wotsSimpleJoinChain.blocks.last.toRawJson());
    logger.d("lastBlockHash: ${_lastBlockHash}");

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("signMessage: time diff: ${timeDiff.inMilliseconds} ms");

    logger.d("\n\t\t--------------------------END: signGigaWotMessage--------------------------");

    return wotsItem;
  }

  /// verify WOTS signature for a message
  Future<bool> verifyGigaWotSignature(GigaWOTSSignatureItem? item) async {
    logger.d("\n\t\t--------------------------START: verifyGigaWotSignature--------------------------");

    if (item == null) {
      return false;
    }

    final startTime = DateTime.now();

    final chainIdentifier = item.id;
    final topPublicKey = item.message.publicKey;
    final messageIndex = item.message.messageIndex;
    // final topPublicKey2 = item.publicKey;

    var previousPublicKey = "";

    try {
      var thisChain = _wotsSimpleChainDictionary.chains.firstWhere((
          element) => element.chainId == chainIdentifier);
      thisChain.blocks.sort((a, b) => a.message.messageIndex.compareTo(b.message.messageIndex));

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
    final csum = item.checksum;
    final message = item.message;
    _logManager.logLongMessage("message to hash 2: ${message.toRawJson()}");

    final messageHash = _cryptor.sha256(message.toRawJson());
    final messageHashBytes = hex.decode(messageHash);
    _logManager.logLongMessage("messageHash: ${messageHash}");

    List<int> checkPublicLeaves = [];
    int index = 0;
    int checksum = 0;

    /// compute the public leaves from the signature and message hash
    for (var c in messageHashBytes) {
      /// add message hash values for checksum
      checksum = checksum + 255 - c;
      var leafHash = sig[index];
      for (var i = 0; i < c; i++) {
        leafHash = _cryptor.sha256(leafHash);
      }
      checkPublicLeaves.addAll(hex.decode(leafHash));
      index += 1;
    }

    /// Compute the public checksum leaf value
    var checksig = csum;
    for (var i = 0; i < checksum; i++) {
      checksig = _cryptor.sha256(checksig);
    }
    // logger.d("checksig: ${checksig}");

    /// add checksum hash to the public leaves
    checkPublicLeaves.addAll(hex.decode(checksig));

    /// hash the public leaves + checksum to get top pub hash
    final checkTopPubHash = _cryptor.sha256(hex.encode(checkPublicLeaves));
    logger.d("checkTopPubHash: ${checkTopPubHash}");

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("verifySignature: time diff: ${timeDiff.inMilliseconds} ms");

    logger.d("\n\t\t--------------------------END: verifyGigaWotSignature--------------------------");

    return checkTopPubHash == topPublicKey;
  }

}