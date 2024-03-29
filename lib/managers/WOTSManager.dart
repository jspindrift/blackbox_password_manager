import "dart:convert";
import "dart:typed_data";

import "package:enum_to_string/enum_to_string.dart";
import 'package:flutter_dotenv/flutter_dotenv.dart';
import "package:cryptography/cryptography.dart";
import "package:convert/convert.dart";
import 'package:logger/logger.dart';
import 'package:elliptic/elliptic.dart' as elliptic;
import 'package:ecdsa/ecdsa.dart' as ecdsa;

import "../merkle/merkle_example.dart";
import "../helpers/ivHelper.dart";
import "../managers/Cryptor.dart";
import "../models/WOTSSignatureItem.dart";
import "LogManager.dart";


class WOTSManager {
  static final WOTSManager _shared = WOTSManager._internal();

  /// logging
  var logger = Logger(
    printer: PrettyPrinter(methodCount: 8),
  );

  static const bool debugSmallEncoding = true;

  factory WOTSManager() {
    return _shared;
  }

  static const int _keySize = 32;  // size of leaf in bytes
  static const int _maxNumberOfSignatures = 2048;

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

  String _topAsymSignature = "";

  /// Asymmetric keys
  elliptic.PrivateKey? _rootPrivateSigningKeyBase;
  // elliptic.PrivateKey _rootPrivateExchangeKeyBase;

  String _rootPrivateSigningKey = "";
  String _rootPrivateExchangeKey = "";

  String _rootPublicSigningKey = "";
  String _rootPublicExchangeKey = "";

  GigaWOTSSignatureChain _wotsSimpleJoinChain = GigaWOTSSignatureChain(chainId: "main", blocks: []);
  GigaWOTSSignatureDictionary _wotsSimpleChainDictionary = GigaWOTSSignatureDictionary(chains: []);

  /// Asymmetric digital signature algorithm
  final algorithm_secp256k1 = elliptic.getS256();

  /// Asymmetric key exchange algorithm
  final algorithm_x25519 = X25519();



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

  String get topAsymSig {
    return _topAsymSignature;
  }


  String get asymSigningPublicKey {
    return _rootPublicSigningKey;
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
    reset();
    logger.d("Initialize WOTSManager");
    await dotenv.load(fileName: "assets/.env",);

    // final envW = dotenv.env.toString();

    // logger.wtf("dotenv map wots: ${envW}");
  }

  reset() {
    _pubLeaves = [];
    _privLeaves = [];

    _privChecksumLeaf = "";
    _pubChecksumLeaf = "";
    _xpub_recovery = "";

    _privChecksumLeaf = "";
    _lastBlockHash = "";
    _messageIndex = 1;

    _topPublicKey = "";
    _nextTopPublicKey = "";

    _rootPrivateSigningKey = "";
    _rootPublicSigningKey = "";

    _rootPrivateExchangeKey = "";
    _rootPublicExchangeKey = "";

    _topAsymSignature = "";
    // _nextTopAsymSignature = "";


    _wotsSimpleJoinChain = GigaWOTSSignatureChain(chainId: "",blocks: []);
    _wotsSimpleChainDictionary = GigaWOTSSignatureDictionary(chains: []);
  }

  setSignatureChainObject(GigaWOTSSignatureChain chain) {
    _wotsSimpleJoinChain = chain;
    _wotsSimpleChainDictionary.chains = [chain];
  }


  /// BEGIN - Giga-WOTS (next top public key protocol) -------------------------
  ///
  Future<void> createGigaWotTopPubKey(List<int> rootKey, int msgIndex, int bitSecurity, bool doRecovery) async {
    await _createGigaWotTopPubKey(rootKey, msgIndex, bitSecurity, doRecovery);
  }

  /// create private and public values for signing and verifying
  Future<void> _createGigaWotTopPubKey(
      List<int> rootKey,
      int msgIndex,
      int bitSecurity,
      bool doRecovery,
      ) async {
    logger.d("\n\t\t--------------------------_createGigaWotTopPubKey START - [${msgIndex}]--------------------------");
    final startTime = DateTime.now();

    _pubLeaves = [];
    _privLeaves = [];

    if (_rootPrivateSigningKey.isEmpty) {
      _rootPrivateSigningKeyBase = await _cryptor.generateKeysS_secp256k1();
      _rootPrivateSigningKey = hex.encode(_rootPrivateSigningKeyBase!.bytes);
      _rootPublicSigningKey = _rootPrivateSigningKeyBase!.publicKey.toCompressedHex();
    }

    if (_rootPrivateExchangeKey.isEmpty) {
      final privExchange = await _cryptor.generateKeysS_secp256k1();
      _rootPrivateExchangeKey = hex.encode(privExchange.bytes);
      _rootPublicExchangeKey = privExchange.publicKey.toCompressedHex();
    }

    // logger.d("_rootPublicSigningKey: ${_rootPublicSigningKey}");

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

    /// compute the public leaves from private hashes
    for (var index = 0; index < numLeaves; index++) {
      /// get private leaf block
      var leaf = secretBox.cipherText.sublist(
        index * _leafKeySize,
        _leafKeySize * (index + 1),
      );

      _privLeaves.add(hex.encode(leaf));

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
      _pubLeaves.add(leafHash);
      publicPad.addAll(hex.decode(leafHash));
      pubData.add(Uint8List.fromList(hex.decode(leafHash)));
    }

    _privChecksumLeaf = _cryptor.sha256(hex.encode(secretBox.cipherText));

    /// Compute the public checksum leaf value
    _pubChecksumLeaf = _privChecksumLeaf;
    for (var i = 0; i < _checksumSize-1; i++) {
      if (bitSecurity == 256) {
        _pubChecksumLeaf = _cryptor.sha256(_pubChecksumLeaf);
      } else {
        _pubChecksumLeaf = _cryptor.sha512(_pubChecksumLeaf);
      }
    }

    publicPad.addAll(hex.decode(_pubChecksumLeaf));
    pubData.add(Uint8List.fromList(hex.decode(_pubChecksumLeaf)));

    if (bitSecurity == 256) {
      _topPublicKey = getTree(pubData, 256).last;
    } else {
      _topPublicKey = getTree(pubData, 512).last;
    }

    final processedTopPub = _cryptor.sha256(_topPublicKey);

    var sigTop = ecdsa.signature(_rootPrivateSigningKeyBase!, hex.decode(processedTopPub));
    _topAsymSignature = sigTop.toCompactHex();

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

    var checksumLeaf = _cryptor.sha256(hex.encode(secretBox.cipherText));
    /// Compute the public checksum leaf value
    for (var i = 0; i < _checksumSize-1; i++) {
      if (bitSecurity == 256) {
        checksumLeaf = _cryptor.sha256(checksumLeaf);
      } else {
        checksumLeaf = _cryptor.sha512(checksumLeaf);
      }
    }

    publicPad.addAll(hex.decode(checksumLeaf));
    pubData.add(Uint8List.fromList(hex.decode(checksumLeaf)));

    /// hash public leaf values with checksum to get top pub hash
    if (bitSecurity == 256) {
      final nextTopPublicKeyMerkle = getTree(pubData, 256).last;

      final endTime = DateTime.now();
      final timeDiff = endTime.difference(startTime);
      logger.d("_createNextGigaWotTopPubKey: time diff: ${timeDiff.inMilliseconds} ms");

      logger.d("\n\t\t--------------------------_createNextGigaWotTopPubKey END - [${nextMessageIndex}]--------------------------");
      return nextTopPublicKeyMerkle;
    } else {
      final nextTopPublicKeyMerkle = getTree(pubData, 512).last;

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
      privLeaves.add(pubHex);

      /// compute the public leaf hash
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

    publicPad.addAll(hex.decode(checksumLeaf));
    pubData.add(Uint8List.fromList(hex.decode(checksumLeaf)));

    /// hash public leaf values with checksum to get top pub hash
    if (bitSecurity == 256) {
      final recoveryTopPublicKeyMerkle = getTree(pubData, 256).last;

      final endTime = DateTime.now();
      final timeDiff = endTime.difference(startTime);
      logger.d("_createNextGigaWotTopPubKey: time diff: ${timeDiff.inMilliseconds} ms");

      logger.d("\n\t\t--------------------------_createNextGigaWotTopPubKey END - [${msgIndex}]--------------------------");
      return recoveryTopPublicKeyMerkle;
    } else {
      final recoveryTopPublicKeyMerkle = getTree(pubData, 512).last;

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
      bool doRecovery,
      ) async {
    logger.d("\n\t\t--------------------------START: signGigaWotMessage--------------------------");
    // _logManager.printJSON(4, "signMessage[$msgIndex]: ", message.toJson());

    final startTime = DateTime.now();
    final msgIndex = message.messageIndex;

    var bitSecurity = 256;
    final securityLevel = EnumToString.fromString(GSecurityLevel.values, message.securityLevel);

    if (securityLevel == GSecurityLevel.basic256) {
      bitSecurity = 256;
    } else if (securityLevel == GSecurityLevel.basic512) {
      bitSecurity = 512;
    } else if (securityLevel == GSecurityLevel.luda256) {
      bitSecurity = 256;
    } else if (securityLevel == GSecurityLevel.luda512) {
      bitSecurity = 512;
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

    /// TODO: change this to base64

    if (debugSmallEncoding) {
      message.nextPublicKey = base64.encode(hex.decode(_nextTopPublicKey));
      message.topSignature = base64.encode(hex.decode(_topAsymSignature));
      message.asymSigningPublicKey = base64.encode(hex.decode(_rootPublicSigningKey));
    } else {
      message.nextPublicKey = _nextTopPublicKey;
      message.topSignature = _topAsymSignature;
      message.asymSigningPublicKey = _rootPublicSigningKey;
    }
    // message.publicKey = _topPublicKey;


    /// calculate merkle root of previous signature
    GigaWOTSSignatureItem? previousSignatureItem;
    try {
      var thisChain = _wotsSimpleChainDictionary.chains.firstWhere((
          element) => element.chainId == chainId);
      thisChain.blocks.sort((a, b) => a.message.messageIndex.compareTo(b.message.messageIndex));

      if (thisChain.blocks.length > 0) {
        previousSignatureItem = thisChain.blocks[thisChain.blocks.length - 1];
        if (previousSignatureItem != null) {
          List<Uint8List> prevSigData = [];

          String previousMessageHash;
          if (bitSecurity == 256) {
            previousMessageHash = _cryptor.sha256(previousSignatureItem.message.toRawJson());
          } else {
            previousMessageHash = _cryptor.sha512(previousSignatureItem.message.toRawJson());
          }
          // logger.d("sign previousMessageHash: ${previousMessageHash}");

          /// add signature data blocks
          for (var s in previousSignatureItem!.signature!) {
            prevSigData.add(Uint8List.fromList(hex.decode(s)));
          }

          /// add previous checksum
          prevSigData.add(Uint8List.fromList(hex.decode(previousSignatureItem.checksum)));

          String previousSignatureMerkleRoot;
          if (bitSecurity == 256) {
            previousSignatureMerkleRoot = getTree(prevSigData, 256).last;
          } else {
            previousSignatureMerkleRoot = getTree(prevSigData, 512).last;
          }
          // logger.d("sign previousSignatureMerkleRoot: ${previousSignatureMerkleRoot}");

          /// set previous hash from preceeding block
          message.previousHash = previousSignatureMerkleRoot;
        }
      }
    } catch (e) {
      logger.e("exception occurred: $e");
    }

    List<int> messageHashBytes;
    var messageHash = "";
    if (bitSecurity == 256) {
      messageHash = _cryptor.sha256(message.toRawJson());
      // logger.d("messageHash: $messageHash");
      messageHashBytes = hex.decode(messageHash);
    } else {
      messageHash = _cryptor.sha512(message.toRawJson());
      // logger.d("messageHash: $messageHash");
      messageHashBytes = hex.decode(messageHash);
    }

    List<Uint8List> sigData = [];
    List<String> signature = [];
    List<int> signatureBlockBytes = [];
    int index = 0;
    int checksum = 0;
    /// compute the WOTS signature
    for (var c in messageHashBytes) {
      /// add hash values for checksum
      checksum += bitSecurity - c;
      var leafHash = _privLeaves[index];
      for (var i = 1; i < bitSecurity - c; i++) {
        if (bitSecurity == 256) {
          leafHash = _cryptor.sha256(leafHash);
        } else {
          leafHash = _cryptor.sha512(leafHash);
        }
      }

      signatureBlockBytes += hex.decode(leafHash);
      signature.add(leafHash);
      sigData.add(Uint8List.fromList(hex.decode(leafHash)));

      index += 1;
    }

    var checksumLeaf = _privChecksumLeaf;

    /// Compute the checksum leaf value, 32x256 = 8192, OR 64*512 = 32768
    for (var i = 1; i < _checksumSize-checksum; i++) {
      if (bitSecurity == 256) {
        checksumLeaf = _cryptor.sha256(checksumLeaf);
      } else {
        checksumLeaf = _cryptor.sha512(checksumLeaf);
      }
    }

    sigData.add(Uint8List.fromList(hex.decode(checksumLeaf)));

    /// change encoding
    if (debugSmallEncoding) {
      checksumLeaf = base64.encode(hex.decode(checksumLeaf));
    }

    /// compute signature merkle root
    ///
    var signatureMerkleRoot;
    if (bitSecurity == 256) {
      signatureMerkleRoot = getTree(sigData, 256).last;
    } else {
      signatureMerkleRoot = getTree(sigData, 512).last;
    }
    // logger.d("signatureMerkleRoot: ${signatureMerkleRoot}");


    /// create WOTS signature object
    /// TODO: unit conversion
    GigaWOTSSignatureItem wotsItem = GigaWOTSSignatureItem(
      id: chainId,
      recovery: _xpub_recovery,
      signature: null,
      signatureBlock: base64.encode(signatureBlockBytes),
      checksum: checksumLeaf,
      message: message,
    );

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

    // _logManager.printJSON(4, "_wotsSimpleJoinChain: ", _wotsSimpleJoinChain.toJson());

    /// get last block hash in the chain
    if (bitSecurity == 256) {
      _lastBlockHash = _cryptor.sha256(_wotsSimpleJoinChain.blocks.last.toRawJson());
    } else {
      _lastBlockHash = _cryptor.sha512(_wotsSimpleJoinChain.blocks.last.toRawJson());
    }

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

    // _logManager.printJSON(4, "verifyGigaWotSignature[${item.toRawJson().length}]: ", item!.toJson());

    final startTime = DateTime.now();

    final chainIdentifier = item.id;
    final securityLevel = EnumToString.fromString(GSecurityLevel.values, item.message.securityLevel);

    final sigBlock = base64.decode(item.signatureBlock!);

    var topPublicKey = item.message.publicKey;
    var topAsymSignature = item.message.topSignature;
    var topAsymSigningPublicKey = item.message.asymSigningPublicKey;

    final previousHash = item.message.previousHash;
    final messageIndex = item.message.messageIndex;

    var bitSecurity = 256;

    if (securityLevel == GSecurityLevel.basic256) {
      bitSecurity = 256;
    } else if (securityLevel == GSecurityLevel.basic512) {
      bitSecurity = 512;
    } else if (securityLevel == GSecurityLevel.luda256) {
      bitSecurity = 256;
    } else if (securityLevel == GSecurityLevel.luda512) {
      bitSecurity = 512;
    }

    var previousPublicKey = "";

    GigaWOTSSignatureItem? previousSignatureItem;
    try {
      var thisChain = _wotsSimpleChainDictionary.chains.firstWhere((
          element) => element.chainId == chainIdentifier);
      thisChain.blocks.sort((a, b) => a.message.messageIndex.compareTo(b.message.messageIndex));

      if (thisChain.blocks.length > 1) {
        previousSignatureItem = thisChain.blocks[thisChain.blocks.length - 2];
      }

      if (thisChain.blocks.length > 1) {
        /// we start message index increment at 1, but is 0-indexed
        previousPublicKey = thisChain.blocks[messageIndex-2].message.nextPublicKey;

        if (previousPublicKey != topPublicKey && topPublicKey != null) {
          logger.e("ERROR: previousPublicKey: ${previousPublicKey} != topPublicKey: ${topPublicKey}");
          return false;
        } else {
          logger.wtf("SUCCESS: previousPublicKey == topPublicKey: $topPublicKey");
        }
      }
    } catch (e) {
      logger.e("exception occurred: $e");
    }

    // final sig = item.signature;
    final message = item.message;

    String messageHash = "";
    List<int> messageHashBytes;
    if (bitSecurity == 256) {
      messageHash = _cryptor.sha256(message.toRawJson());
      // logger.d("messageHash: ${messageHash}");
      messageHashBytes = hex.decode(messageHash);
    } else {
      messageHash = _cryptor.sha512(message.toRawJson());
      // logger.d("messageHash: ${messageHash}");
      messageHashBytes = hex.decode(messageHash);
    }

    List<Uint8List> pubData = [];
    List<Uint8List> sigData = [];

    // final recoveryKey = item.recovery;
    // if (recoveryKey != null) {
    //   checkPublicLeaves.addAll(hex.decode(recoveryKey));
    //   pubData.add(Uint8List.fromList(hex.decode(recoveryKey)));
    // }

    int index = 0;
    int checksum = 0;

    var leaves = [];
    /// compute the public leaves from the signature and message hash
    for (var c in messageHashBytes) {
      /// add message hash values for checksum
      checksum += bitSecurity - c;

      final leafHashBytes = sigBlock.sublist(index*(bitSecurity/8).toInt(), index*(bitSecurity/8).toInt() + (bitSecurity/8).toInt());
      var leafHashEncoded = hex.encode(leafHashBytes);
      sigData.add(Uint8List.fromList(hex.decode(leafHashEncoded)));

      for (var i = 0; i < c; i++) {
        if (bitSecurity == 256) {
          leafHashEncoded = _cryptor.sha256(leafHashEncoded);
        } else {
          leafHashEncoded = _cryptor.sha512(leafHashEncoded);
        }
      }

      leaves.add(leafHashEncoded);
      pubData.add(Uint8List.fromList(hex.decode(leafHashEncoded)));

      index += 1;
    }

    /// TODO: unit conversion
    var checksumLeaf = item.checksum;
    if (debugSmallEncoding) {
      checksumLeaf = hex.encode(base64.decode(item.checksum));
    }

    sigData.add(Uint8List.fromList(hex.decode(checksumLeaf)));

    /// Compute the public checksum leaf value
    for (var i = 0; i < checksum; i++) {
      if (bitSecurity == 256) {
        checksumLeaf = _cryptor.sha256(checksumLeaf);
      } else {
        checksumLeaf = _cryptor.sha512(checksumLeaf);
      }
    }
    // logger.d("checksumLeaf end: ${checksumLeaf}");

    /// add checksum leaf to array
    pubData.add(Uint8List.fromList(hex.decode(checksumLeaf)));

    /// this is our top pub key
    String signatureMerkleRoot;
    if (bitSecurity == 256) {
      signatureMerkleRoot = getTree(pubData, 256).last;
    } else {
      signatureMerkleRoot = getTree(pubData, 512).last;
    }
    final processedNextTopPub = _cryptor.sha256(signatureMerkleRoot);

    /// convert encoding
    if (debugSmallEncoding) {
      topAsymSignature = hex.encode(base64.decode(topAsymSignature!));
      topAsymSigningPublicKey = hex.encode(base64.decode(topAsymSigningPublicKey!));
    }

    final sigCheck = ecdsa.Signature.fromCompactHex(topAsymSignature!);
    final pubKey = algorithm_secp256k1.compressedHexToPublicKey(topAsymSigningPublicKey!);

    var verifySig = ecdsa.verify(pubKey, hex.decode(processedNextTopPub), sigCheck);

    logger.d("verifySig: ${verifySig}\nprocessedNextTopPub: $processedNextTopPub\ntopAsymSignature: $topAsymSignature");

    if (previousSignatureItem != null) {
      if (previousSignatureItem!.signature != null) {
        List<Uint8List> prevSigData = [];
        /// add signature data blocks
        for (var s in previousSignatureItem.signature!) {
          prevSigData.add(Uint8List.fromList(hex.decode(s)));
        }

        prevSigData.add(
            Uint8List.fromList(hex.decode(previousSignatureItem.checksum)));

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
    }

    final endTime = DateTime.now();
    final timeDiff = endTime.difference(startTime);
    logger.d("verifySignature: time diff: ${timeDiff.inMilliseconds} ms");

    logger.d("\n\t\t--------------------------END: verifyGigaWotSignature--------------------------");
    // logger.d("$signatureMerkleRoot == $topPublicKey");

    /// old check
    // return signatureMerkleRoot == topPublicKey;

    /// this is used for hybrid model
    return verifySig;
  }

}