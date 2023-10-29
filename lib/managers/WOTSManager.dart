import "dart:typed_data";

import "package:blackbox_password_manager/helpers/ivHelper.dart";
import "package:blackbox_password_manager/managers/Cryptor.dart";
import "package:cryptography/cryptography.dart";
import "package:convert/convert.dart";
import 'package:logger/logger.dart';

import "../merkle/merkle_example.dart";
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

  List<String> _topJoinLeaves = [];
  List<String> _bottomJoinLeaves = [];
  List<String> _topJoinLeavesHalf = [];
  List<String> _bottomJoinLeavesHalf = [];
  String _topMerkle = "";
  String _bottomMerkle = "";

  WOTSOverlapSignatureChain _wotsJoinChain = WOTSOverlapSignatureChain(blocks: []);

  WOTSSimpleOverlapSignatureChain _wotsSimpleJoinChain = WOTSSimpleOverlapSignatureChain(chainId: "",blocks: []);

  WOTSSimpleSignatureDictionary _wotsSimpleChainDictionary = WOTSSimpleSignatureDictionary(chains: []);

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

    _topJoinLeaves = [];
    _bottomJoinLeaves = [];
    _topJoinLeavesHalf = [];
    _bottomJoinLeavesHalf = [];

    _privChecksumLeaf = "";
    _lastBlockHash = "";

    _messageIndex = 1;

    _wotsChain = WOTSBasicSignatureChain(blocks: []);
    _wotsJoinChain = WOTSOverlapSignatureChain(blocks: []);

    _wotsSimpleJoinChain = WOTSSimpleOverlapSignatureChain(chainId: "",blocks: []);
    _wotsSimpleChainDictionary = WOTSSimpleSignatureDictionary(chains: []);
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


  /// BEGIN - Overlapping WOTS implementation ----------------------------------
  ///

  /// create private and public values for signing and verifying
  Future<void> createOverlapTopPubKey(List<int> rootKey, int msgIndex) async {
    await _createOverlapTopPubKey(rootKey, msgIndex);
  }

  /// create private and public values for signing and verifying
  Future<void> _createOverlapTopPubKey(List<int> rootKey, int msgIndex) async {
    logger.d("\n\t\t--------------------------createOverlappingTopPubKey START - [${msgIndex}]--------------------------");
    final startTime = DateTime.now();

    List<String> _pubLeavesShow = [];

    _pubLeaves = [];
    _privLeaves = [];
    _topJoinLeaves = [];
    _bottomJoinLeaves = [];
    _topJoinLeavesHalf = [];
    _bottomJoinLeavesHalf = [];
    _privChecksumLeaf = "";
    _pubChecksumLeaf = "";

    if (msgIndex == 0) {
      logger.e("ERROR: message index must be greater than 0");
      return null;
    }

    if (msgIndex <= _wotsJoinChain.blocks.length) {
      logger.e("ERROR: message index must be greater than _wotsJoinChain.blocks.length: ${_wotsJoinChain.blocks.length}");
      return null;
    }

    _messageIndex = msgIndex;

    if (rootKey.isEmpty || rootKey.length != _keySize) {
      rootKey = List<int>.filled(_keySize, 0);
    }

    final encKey = SecretKey(rootKey);

    final bigPad = List<int>.filled((_keySize * _numberOfLeaves).toInt(), 0);
    final topPad = List<int>.filled((_keySize * _numberOfJoinLeaves).toInt(), 0);
    final bottomPad = List<int>.filled((_keySize * _numberOfJoinLeaves).toInt(), 0);

    var prevIndex = _messageIndex;
    if (_messageIndex > 1) {
      prevIndex = _messageIndex - 1;
    }

    final recipientIndex = 0;

    final nonceTop = ivHelper().getIv4x4(recipientIndex, 0, prevIndex, (_messageIndex-1)*(_keySize * _numberOfJoinLeaves + _keySize * _numberOfLeaves));
    final nonceMid = ivHelper().getIv4x4(recipientIndex, _messageIndex, _messageIndex, _keySize * _numberOfJoinLeaves);
    final nonceBottom = ivHelper().getIv4x4(recipientIndex, 0, _messageIndex, _messageIndex*(_keySize * _numberOfJoinLeaves + _keySize * _numberOfLeaves));
    logger.d("nonceTop: ${hex.encode(nonceTop)}\nnonceMid: ${hex.encode(nonceMid)}\nnonceBottom: ${hex.encode(nonceBottom)}");

    /// Encrypt the zero pad
    final secretBoxTop = await algorithm_nomac.encrypt(
      topPad,
      secretKey: encKey,
      nonce: nonceTop,
    );

    final secretBoxMid = await algorithm_nomac.encrypt(
      bigPad,
      secretKey: encKey,
      nonce: nonceMid,
    );

    final secretBoxBottom = await algorithm_nomac.encrypt(
      bottomPad,
      secretKey: encKey,
      nonce: nonceBottom,
    );

    // _logManager.logLongMessage("\ntop: ${hex.encode(secretBoxTop.cipherText)}\n\n"
    //     "mid: ${hex.encode(secretBoxMid.cipherText)}\n\n"
    //     "bottom: ${hex.encode(secretBoxBottom.cipherText)}\n");

    // final allCtx = secretBoxTop.cipherText + secretBoxMid.cipherText + secretBoxBottom.cipherText;
    /// hash the private keys together to get checksum leaf
    _privChecksumLeaf = _cryptor.sha256(hex.encode(secretBoxMid.cipherText));
    // _privChecksumLeaf = hex.encode(cryptor.getRandomBytes(32));

    // _logManager.logLongMessage("\nchecksum leaf: ${_privChecksumLeaf}\n");

    List<Uint8List> publicPadTop = [];
    List<Uint8List> publicPadBottom = [];

    List<Uint8List> publicPadTopHalf = [];
    List<Uint8List> publicPadBottomHalf = [];

    for (var index = 0; index < _numberOfJoinLeaves; index++) {

      /// get private leaf block
      final leafTop = secretBoxTop.cipherText.sublist(
        index * _keySize,
        _keySize * (index + 1),
      );

      /// add additional hash on leaf here
      ///
      final hashedLeafTop = _cryptor.sha256(hex.encode(leafTop));
      _topJoinLeaves.add(hashedLeafTop);

      /// only add half of the top leaves for verification (bottom half of top)
      if (index+1 > _numberOfJoinLeaves/2) {
        _topJoinLeavesHalf.add(hashedLeafTop);
        publicPadTopHalf.add(Uint8List.fromList(hex.decode(hashedLeafTop)));
      }

      publicPadTop.add(Uint8List.fromList(hex.decode(hashedLeafTop)));

      final leafBottom = secretBoxBottom.cipherText.sublist(
        index * _keySize,
        _keySize * (index + 1),
      );

      /// add additional hash on leaf here
      ///
      final hashedLeafBottom = _cryptor.sha256(hex.encode(leafBottom));
      _bottomJoinLeaves.add(hashedLeafBottom);

      /// only add half of the bottom leaves for verification (top half of bottom)
      if (index+1 <= _numberOfJoinLeaves/2) {
        _bottomJoinLeavesHalf.add(hashedLeafBottom);
        publicPadBottomHalf.add(Uint8List.fromList(hex.decode(hashedLeafBottom)));
      }

      publicPadBottom.add(Uint8List.fromList(hex.decode(hashedLeafBottom)));
    }

    // _logManager.logLongMessage("\ntopJoinLeaves: ${_topJoinLeaves}\n\n"
    //     "_bottomJoinLeaves: ${_bottomJoinLeaves}\n");

    final topTree = getTree(publicPadTop);
    final bottomTree = getTree(publicPadBottom);
    // _logManager.logLongMessage("\ntopTree: ${topTree}\n\n"
    //     "bottomTree: ${bottomTree}\n");

    var genesisTopleafHash = topTree.last;
    if (_messageIndex == 1) {
      /// compute the genesis top leaf hash
      // var genesisTopleafHash = topTree.last;
      for (var i = 0; i < _maxNumberOfSignatures; i++) {
        genesisTopleafHash = _cryptor.sha256(genesisTopleafHash);
      }
    }

    // _topMerkle = topTree.last;
    _topMerkle = genesisTopleafHash;
    _bottomMerkle = bottomTree.last;
    // _logManager.logLongMessage("\ntopMerkle: ${_topMerkle}\ntopTree.last: ${topTree.last}\n"
    //     "bottomMerkle: ${_bottomMerkle}\n");

    List<int> publicPad = [];

    publicPad.addAll(hex.decode(_topMerkle));
    _pubLeavesShow.add(_topMerkle);

    /// compute the public leaves from private hashes
    for (var index = 0; index < _numberOfLeaves; index++) {

      /// get private leaf block
      final leaf = secretBoxMid.cipherText.sublist(
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
      _pubLeavesShow.add(leafHash);

      publicPad.addAll(hex.decode(leafHash));
    }

    /// Compute the public checksum leaf value
    _pubChecksumLeaf = _privChecksumLeaf;
    for (var i = 0; i < _checksumSize-1; i++) {
      _pubChecksumLeaf = _cryptor.sha256(_pubChecksumLeaf);
    }
    // logger.d("pubChecksumLeaf: $_pubChecksumLeaf");

    /// add checksum public leaf value to public leaf array
    publicPad.addAll(hex.decode(_pubChecksumLeaf));
    _pubLeavesShow.add(_pubChecksumLeaf);

    publicPad.addAll(hex.decode(_bottomMerkle));
    _pubLeavesShow.add(_bottomMerkle);

    // _logManager.logLongMessage("publicPad: ${hex.encode(publicPad)}\n");
    // _logManager.logLongMessage("_pubLeavesShow: ${_pubLeavesShow}\n");


    // _logManager.logLongMessage("\nmessageIndex: $_messageIndex\n"
    //     "_privLeaves: $_privLeaves\n\n"
    //     "_pubLeaves: $_pubLeaves");

    /// hash public leaf values with checksum to get top pub hash
    _topPublicKey = _cryptor.sha256(hex.encode(publicPad));
    // logger.d("topPubHash: ${_topPubHash}");

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("_createOverlappingTopPubKey: time diff: ${timeDiff.inMilliseconds} ms");

    logger.d("\n\t\t--------------------------_createOverlappingTopPubKey END - [${_messageIndex}]--------------------------");
  }

  /// create WOTS signature for a message
  Future<WOTSOverlapSignatureItem?> overlapSignMessage(List<int> key, int msgIndex, String message) async {
    logger.d("\n\t\t--------------------------START: signOverlappingMessage[$msgIndex]--------------------------");

    final startTime = DateTime.now();
    final timestamp = startTime.toIso8601String();

    if (msgIndex == 0) {
      logger.e("ERROR: message index must be greater than 0");
      return null;
    }

    if (msgIndex <= _wotsJoinChain.blocks.length) {
      logger.e("ERROR: message index must be greater than _wotsJoinChain.blocks.length: ${_wotsJoinChain.blocks.length}");
      return null;
    }

    _messageIndex = msgIndex;

    /// create private/public key leaves
    await _createOverlapTopPubKey(key, _messageIndex);

    final messageItem = BasicMessageData(
      time: timestamp,
      message: message,
      signature: "",
    );
    // logger.d("signMessage[$_messageIndex]: ${messageItem.toRawJson()}");

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
    // logger.d("checksumHash: ${checksumHash}");

    /// create overlapping WOTS signature object
    WOTSOverlapSignatureItem wotsItem = WOTSOverlapSignatureItem(
      id: _messageIndex,
      topLeaves: _topJoinLeavesHalf,
      topMerkle: _topMerkle,
      bottomLeaves: _bottomJoinLeavesHalf,
      bottomMerkle: _bottomMerkle,
      publicKey: _topPublicKey,
      nextTopPublicKey: "",
      signature: signature,
      checksum: checksumHash,
      message: messageItem,
    );

    _logManager.logLongMessage("wotsItem: ${wotsItem.toRawJson()}");

    _wotsJoinChain.blocks.add(wotsItem);

    /// sort blocks in the chain by index
    _wotsJoinChain.blocks.sort((a, b) => a.id.compareTo(b.id));

    // _logManager.logLongMessage("\n\n_wotsChain[${_wotsJoinChain.blocks.length}]\n\n"
    //     "[${_wotsJoinChain.toRawJson().length} bytes] | [${(_wotsJoinChain.toRawJson().length/1024).toStringAsFixed(2)} KB]\n\n"
    //     "chain: ${_wotsJoinChain.toRawJson()}\n\n");

    /// get last block hash in the chain
    _lastBlockHash = _cryptor.sha256(_wotsJoinChain.blocks.last.toRawJson());
    // logger.d("lastBlockHash: ${_lastBlockHash}");

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("signOverlappingMessage: time diff: ${timeDiff.inMilliseconds} ms");

    logger.d("\n\t\t--------------------------END: signOverlappingMessage--------------------------");

    return wotsItem;
  }

  /// verify Overlapping WOTS signature for message
  Future<bool> verifyOverlapSignature(WOTSOverlapSignatureItem? item) async {
    logger.d("\n\t\t--------------------------START: verifyOverlappingSignature--------------------------");

    if (item == null) {
      return false;
    }

    final startTime = DateTime.now();

    final messageIndex = item.id;

    var overlapCheckLeaves = [];
    List<Uint8List> overlapCheckLeavesTop = [];

    if (messageIndex > 1) {
      logger.d("messageIndex implies we need to check a previous signature block");
      if (_wotsJoinChain.blocks.length >= messageIndex-1) {
        overlapCheckLeaves =
            _wotsJoinChain.blocks[messageIndex - 2].bottomLeaves;
        overlapCheckLeaves.addAll(item.topLeaves);
      }
      // logger.d("overlappingCheckLeaves: ${overlapCheckLeaves}");

      for (var oleaf in overlapCheckLeaves) {
        overlapCheckLeavesTop.add(Uint8List.fromList(hex.decode(oleaf)));
      }

      final checkMerkleTreeTop = getTree(overlapCheckLeavesTop);
      final checkMerkleTop = checkMerkleTreeTop.last;

      // _logManager.logLongMessage("\ncheckMerkleTop: ${checkMerkleTop}\n\n"
      //     "_wotsJoinChain.blocks[messageIndex - 2].bottomMerkle: ${_wotsJoinChain.blocks[messageIndex - 2].bottomMerkle}\n\n"
      //     "item.topMerkle: ${item.topMerkle}");

      if (checkMerkleTop != _wotsJoinChain.blocks[messageIndex - 2].bottomMerkle) {
        logger.e("ERROR: checkMerkleTop failed");
        return false;
      }
    }

    final topPubKey = item.publicKey;
    final sig = item.signature;
    final checkLeaf = item.checksum;
    final message = item.message;

    final messageHash = _cryptor.sha256(message.toRawJson());
    final messageHashBytes = hex.decode(messageHash);

    List<int> checkPublicLeaves = [];
    int index = 0;
    int checksum = 0;

    checkPublicLeaves.addAll(hex.decode(item.topMerkle));

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
    var checksumPubHash = checkLeaf;
    for (var i = 0; i < checksum; i++) {
      checksumPubHash = _cryptor.sha256(checksumPubHash);
    }
    // logger.d("checksum: ${checksumPubHash}");

    /// add checksum hash to the public leaves
    checkPublicLeaves.addAll(hex.decode(checksumPubHash));
    checkPublicLeaves.addAll(hex.decode(item.bottomMerkle));

    /// hash the public leaves + checksum to get top pub hash
    final checkTopPubKey = _cryptor.sha256(hex.encode(checkPublicLeaves));
    // logger.d("checkTopPubKey: ${checkTopPubKey}");
    logger.d("isValid[$_messageIndex]: ${checkTopPubKey == topPubKey}");

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("verifyOverlappingSignature: time diff: ${timeDiff.inMilliseconds} ms");

    logger.d("\n\t\t--------------------------END: verifyOverlappingSignature--------------------------");

    return checkTopPubKey == topPubKey;
  }


  /// BEGIN - WOTS Simple Overlapping Chain (next top public key)
  ///

  /// create private and public values for signing and verifying
  Future<void> _createSimpleOverlapTopPubKey(List<int> rootKey, int msgIndex) async {
    logger.d("\n\t\t--------------------------_createSimpleOverlapTopPubKey START - [${msgIndex}]--------------------------");
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

    _logManager.logLongMessage("\nmessageIndex: $msgIndex\n"
        "_privLeaves: $_privLeaves\n\n"
        "_pubLeaves: $_pubLeaves");

    /// hash public leaf values with checksum to get top pub hash
    _topPublicKey = _cryptor.sha256(hex.encode(publicPad));
    logger.d("_topPublicKey: ${_topPublicKey}");

    _nextTopPublicKey = await _createNextSimpleOverlapTopPubKey(rootKey, msgIndex);

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("createPubKeyWOTS: time diff: ${timeDiff.inMilliseconds} ms");

    logger.d("\n\t\t--------------------------_createSimpleOverlapTopPubKey END - [${msgIndex}]--------------------------");
  }

  /// get the next top public key to add to current signature
  Future<String> _createNextSimpleOverlapTopPubKey(List<int> rootKey, int msgIndex) async {
    logger.d("\n\t\t--------------------------_createNextSimpleOverlapTopPubKey START - [${msgIndex}]--------------------------");
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
    logger.d("pubChecksumLeaf: $pubChecksumLeaf");

    /// add checksum public leaf value to public leaf array
    publicPad.addAll(hex.decode(pubChecksumLeaf));
    // _pubLeaves.add(pubChecksumLeaf);

    _logManager.logLongMessage("\nnextMessageIndex: $nextMessageIndex\n"
        "privLeaves: $privLeaves\n\n"
        "pubLeaves: $pubLeaves");

    /// hash public leaf values with checksum to get top pub hash
    final nextTopPublicKey = _cryptor.sha256(hex.encode(publicPad));
    logger.d("nextTopPublicKey: ${nextTopPublicKey}");

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("createPubKeyWOTS: time diff: ${timeDiff.inMilliseconds} ms");

    logger.d("\n\t\t--------------------------_createNextSimpleOverlapTopPubKey END - [${msgIndex}]--------------------------");

    return nextTopPublicKey;
  }

  /// create WOTS signature for a message
  Future<WOTSSimpleOverlapSignatureItem?> signSimpleOverlapMessage(List<int> key, String chainId, int msgIndex, String message) async {
    logger.d("\n\t\t--------------------------START: signSimpleOverlapMessage--------------------------");
    logger.d("signMessage[$msgIndex]: ${message}");

    final startTime = DateTime.now();
    final timestamp = startTime.toIso8601String();

    // if (msgIndex <= _wotsSimpleJoinChain.blocks.length) {
    //   msgIndex = _wotsSimpleJoinChain.blocks.length + 1;
    // }

    /// create private/public key leaves
    await _createSimpleOverlapTopPubKey(key, msgIndex);

    var messageItem;
    try {
      messageItem = BasicMessageData.fromRawJson(message);
      if (messageItem == null) {
        messageItem = BasicMessageData(
          time: "00:00:00-00000000JAS", //timestamp,
          message: message,
          signature: "",
        );
      }
    } catch (e) {
      logger.e("error json format");
      messageItem = BasicMessageData(
        time: "00:00:00-00000000JAS", //timestamp,
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
    WOTSSimpleOverlapSignatureItem wotsItem = WOTSSimpleOverlapSignatureItem(
      id: chainId,
      index: msgIndex,
      publicKey: _topPublicKey,
      nextPublicKey: _nextTopPublicKey,
      previousHash: _lastBlockHash,
      signature: signature,
      checksum: checksumHash,
      message: messageItem,
    );

    _logManager.logLongMessage("wotsItem: ${wotsItem.toRawJson()}");


    WOTSSimpleOverlapSignatureChain currentChain = WOTSSimpleOverlapSignatureChain(chainId: chainId, blocks: []);
    // _wotsSimpleJoinChain.blocks.add(wotsItem);

    if (_wotsSimpleChainDictionary.chains.length == 0) {
      currentChain.chainId = wotsItem.id;

      _wotsSimpleJoinChain.chainId = wotsItem.id;
      _wotsSimpleJoinChain.blocks.add(wotsItem);
      _wotsSimpleChainDictionary.chains.add(_wotsSimpleJoinChain);
    } else {
      try {
        final thisChain = _wotsSimpleChainDictionary.chains.firstWhere((
            element) => element.chainId == chainId);
        _wotsSimpleJoinChain = thisChain;
        _wotsSimpleJoinChain.blocks.add(wotsItem);
        _wotsSimpleChainDictionary.chains.add(currentChain);

      } catch (e) {
        currentChain.chainId = wotsItem.id;
        currentChain.blocks.add(wotsItem);
        _wotsSimpleChainDictionary.chains.add(currentChain);
      }

      _logManager.logLongMessage("thisChain: ${_wotsSimpleJoinChain.toRawJson()}");
    }

    _logManager.logLongMessage("\n\n_wotsSimpleChainDictionary: ${_wotsSimpleChainDictionary.toRawJson()}");

    /// sort blocks in the chain by index
    _wotsSimpleJoinChain.blocks.sort((a, b) => a.id.compareTo(b.id));

    // _logManager.logLongMessage("WOTSManager.signMessage:\n_wotsChain[${_wotsSimpleJoinChain.blocks.length}]\n"
    //     "[${_wotsSimpleJoinChain.toRawJson().length} bytes] | [${(_wotsSimpleJoinChain.toRawJson().length/1024).toStringAsFixed(2)} KB]\n"
    //     "chain: ${_wotsSimpleJoinChain.toRawJson()}");

    /// get last block hash in the chain
    _lastBlockHash = _cryptor.sha256(_wotsSimpleJoinChain.blocks.last.toRawJson());
    logger.d("lastBlockHash: ${_lastBlockHash}");

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("signMessage: time diff: ${timeDiff.inMilliseconds} ms");

    logger.d("\n\t\t--------------------------END: signSimpleOverlapMessage--------------------------");

    return wotsItem;
  }

  /// verify WOTS signature for a message
  Future<bool> verifySimpleOverlapSignature(WOTSSimpleOverlapSignatureItem? item) async {
    logger.d("\n\t\t--------------------------START: verifySimpleOverlapSignature--------------------------");

    if (item == null) {
      return false;
    }

    final startTime = DateTime.now();

    final chainIdentifier = item.id;
    final messageIndex = item.index;
    final topPublicKey = item.publicKey;

    var previousPublicKey = "";

    try {
      var thisChain = _wotsSimpleChainDictionary.chains.firstWhere((
          element) => element.chainId == chainIdentifier);
      thisChain.blocks.sort((a, b) => a.index.compareTo(b.index));


      if (thisChain.blocks.length > 1) {
        previousPublicKey = thisChain.blocks[messageIndex-2].nextPublicKey;
        logger.e("ERROR: previousPublicKey: ${previousPublicKey} != topPublicKey: ${topPublicKey}");

        if (previousPublicKey != topPublicKey) {
          logger.e("ERROR: previousPublicKey != topPublicKey");
          return false;
        }
      }
    } catch (e) {
      logger.e("error occurred");
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
    logger.d("checksig: ${checksig}");

    /// add checksum hash to the public leaves
    checkPublicLeaves.addAll(hex.decode(checksig));

    /// hash the public leaves + checksum to get top pub hash
    final checkTopPubHash = _cryptor.sha256(hex.encode(checkPublicLeaves));
    logger.d("checkTopPubHash: ${checkTopPubHash}");

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("verifySignature: time diff: ${timeDiff.inMilliseconds} ms");

    logger.d("\n\t\t--------------------------END: verifySimpleOverlapSignature--------------------------");

    return checkTopPubHash == topPublicKey;
  }

}