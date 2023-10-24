import "package:blackbox_password_manager/helpers/ivHelper.dart";
import "package:blackbox_password_manager/managers/Cryptor.dart";
import "package:cryptography/cryptography.dart";
import "package:convert/convert.dart";
import 'package:logger/logger.dart';

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

  /// private leaves
  List<String> _privLeaves = [];
  String _privChecksumLeaf = "";

  /// public leaves
  List<String> _pubLeaves = [];
  String _topPubHash = "";
  String _lastBlockHash = "";

  int _messageIndex = 1;

  WOTSBasicSignatureChain _wotsChain = WOTSBasicSignatureChain(blocks: []);

  int get messageIndex {
    return _messageIndex;
  }

  List<String> get privLeaves {
    return _privLeaves;
  }

  List<String> get pubLeaves {
    return _pubLeaves;
  }

  String get topPubHash {
    return _topPubHash;
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


  reset() {
    _pubLeaves = [];
    _privLeaves = [];
    _privChecksumLeaf = "";
    _lastBlockHash = "";

    _messageIndex = 1;

    _wotsChain = WOTSBasicSignatureChain(blocks: []);
  }

  /// creates the first "genesis" WOTS private/public leaves
  Future<String> createRootTopPubKey(List<int> rootKey) async {
    return await _createTopPubKey(rootKey, 0);
  }

  /// create private and public values for signing and verifying
  Future<String> createTopPubKey(List<int> rootKey, int msgIndex) async {
    return await _createTopPubKey(rootKey, msgIndex);
  }

  /// create private and public values for signing and verifying
  Future<String> _createTopPubKey(List<int> rootKey, int msgIndex) async {
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
    // logger.d("pubChecksumLeaf: $pubChecksumLeaf");

    /// add checksum public leaf value to public leaf array
    publicPad.addAll(hex.decode(pubChecksumLeaf));
    _pubLeaves.add(pubChecksumLeaf);

    // _logManager.logLongMessage("\nmessageIndex: $_messageIndex\n"
    //     "_privLeaves: $_privLeaves\n\n"
    //     "_pubLeaves: $_pubLeaves");

    /// hash public leaf values with checksum to get top pub hash
    _topPubHash = _cryptor.sha256(hex.encode(publicPad));
    // logger.d("topPubHash: ${_topPubHash}");

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("createPubKeyWOTS: time diff: ${timeDiff.inMilliseconds} ms");

    logger.d("\n\t\t--------------------------createPubKeyWOTS END - [${_messageIndex}]--------------------------");

    return _topPubHash;
  }

  /// create WOTS signature for a message
  Future<WOTSBasicSignatureItem?> signMessage(List<int> key, int msgIndex, String message) async {
    logger.d("\n\t\t--------------------------signMessage--------------------------");
    // logger.d("signMessage[$msgIndex]: ${message}");

    final startTime = DateTime.now();
    final timestamp = startTime.toIso8601String();

    if (msgIndex <= _wotsChain.blocks.length) {
      msgIndex = _wotsChain.blocks.length + 1;
    }

    /// create private/public key leaves
    await _createTopPubKey(key, msgIndex);

    final messageItem = BasicMessageData(
      time: timestamp,
      data: message,
    );

    final messageHash = _cryptor.sha256(messageItem.toRawJson());
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
    WOTSBasicSignatureItem wotsItem = WOTSBasicSignatureItem(
      id: msgIndex,
      publicKey: _topPubHash,
      signature: signature,
      checksum: checksumHash,
      message: messageItem,
    );

    _wotsChain.blocks.add(wotsItem);

    /// sort blocks in the chain by index
    _wotsChain.blocks.sort((a, b) => a.id.compareTo(b.id));

    _logManager.logLongMessage("\n_wotsChain[${_wotsChain.blocks.length}]\n"
        "[${_wotsChain.toRawJson().length} bytes] | [${(_wotsChain.toRawJson().length/1024).toStringAsFixed(2)} KB]\n"
        "chain: ${_wotsChain.toRawJson()}");

    /// get last block hash in the chain
    _lastBlockHash = _cryptor.sha256(_wotsChain.blocks.last.toRawJson());
    logger.d("lastBlockHash: ${_lastBlockHash}");

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("signMessage: time diff: ${timeDiff.inMilliseconds} ms");

    return wotsItem;
  }

  /// verify WOTS signature for a message
  Future<bool> verifySignature(WOTSBasicSignatureItem? item) async {
    logger.d("\n\t\t--------------------------verifySignature--------------------------");

    if (item == null) {
      return false;
    }

    final startTime = DateTime.now();

    final topPubHash = item.publicKey;
    final sig = item.signature;
    final csum = item.checksum;
    final message = item.message;
    // _logManager.logLongMessage("item: ${item.toRawJson()}");

    final messageHash = _cryptor.sha256(message.toRawJson());
    final messageHashBytes = hex.decode(messageHash);

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
    // logger.d("checkTopPubHash: ${checkTopPubHash}");

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("verifySignature: time diff: ${timeDiff.inMilliseconds} ms");

    return checkTopPubHash == topPubHash;
  }

}