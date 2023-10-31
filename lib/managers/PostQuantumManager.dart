import "dart:convert";
import "dart:typed_data";
import 'dart:async';
import "package:blackbox_password_manager/models/WOTSSignatureItem.dart";
import 'package:flutter/services.dart' show rootBundle;

import "package:blackbox_password_manager/managers/Cryptor.dart";
import "package:blackbox_password_manager/managers/WOTSManager.dart";
import "package:blackbox_password_manager/merkle/merkle_example.dart";
import "package:convert/convert.dart";
import "package:cryptography/cryptography.dart" as crypto;
import "package:elliptic/src/publickey.dart";
import 'package:logger/logger.dart';
import 'package:ecdsa/ecdsa.dart' as ecdsa;
import 'package:elliptic/elliptic.dart' as elliptic;

import "LogManager.dart";


class PostQuantumManager {
  static final PostQuantumManager _shared = PostQuantumManager._internal();

  /// logging
  var logger = Logger(
    printer: PrettyPrinter(),
  );


  factory PostQuantumManager() {
    return _shared;
  }


  List<String> _privateKeys = [];
  List<String> _publicKeys = [];
  List<String> _publicKeyTree = [];

  List<String> get publicKeys {
    return _publicKeys;
  }

  List<String> get publicKeyTree {
    return _publicKeyTree;
  }


  /// Encryption Algorithm
  final algorithm_nomac = crypto.AesCtr.with256bits(macAlgorithm: crypto.MacAlgorithm.empty);

  /// Digital Signature Algorithm
  final algorithm_secp256k1 = elliptic.getS256();

  final _logManager = LogManager();
  final _cryptor = Cryptor();
  final _wotsManager = WOTSManager();

  PostQuantumManager._internal();


  reset() {
    _publicKeys = [];
    _privateKeys = [];
  }

  Future<String> loadAsset() async {
    return await rootBundle.loadString('assets/files/project_file_hashes.txt');
  }

  Future<String> loadAssetSignature() async {
    return await rootBundle.loadString('assets/files/post_quantum_signature.txt');
  }

  /// creates the first "genesis" WOTS private/public leaves
  Future<void> createKeyTree(int numberOfKeys) async {

    if (numberOfKeys <= 1) {
      numberOfKeys = 2;
    }

    await generateAsymKeys(numberOfKeys);
  }


  /// secp256k1 key generation
  Future<void> generateAsymKeys(int numOfKeys) async {
    logger.d("generateAsymKeys: secp256k1");

    _publicKeys = [];
    _privateKeys = [];
    _publicKeyTree = [];
    List<Uint8List> pubData = [];

    for (var index = 0; index < numOfKeys; index++) {
      var priv = algorithm_secp256k1.generatePrivateKey();
      _privateKeys.add(hex.encode(priv.bytes));
      // logger.d("privateKey.hex: ${hex.encode(priv.bytes)}");

      var pub = priv.publicKey;
      var xpub = algorithm_secp256k1.publicKeyToCompressedHex(pub);
      _publicKeys.add(xpub);

      final hashedPubKey = _cryptor.sha256(xpub);
      pubData.add(Uint8List.fromList(hex.decode(hashedPubKey)));
      // logger.d("pubKey.compressed[$index]: ${xpub.length}: ${xpub}");
      // logger.d("pub.toHex()[$index]: ${pub.toHex()}");
    }

    _publicKeyTree = getTree(pubData);
    // logger.d("pubKey tree: ${_publicKeyTree}");
  }

  /// secp256k1 signature
  Future<ecdsa.Signature?> signHashAsym(int keyIndex, String hash) async {
    logger.d("signHash: secp256k1");

    /// check index
    if (keyIndex >= _privateKeys.length) {
      logger.w("invalid index");
      return null;
    }

    /// create PrivateKey object
    final privateKey = elliptic.PrivateKey(
        algorithm_secp256k1,
        BigInt.parse(_privateKeys[keyIndex], radix: 16),
    );

    /// sign message hash
    var signature = ecdsa.signature(privateKey, hex.decode(hash));
    // _logManager.logLongMessage("ecdsa.signature: ${signature.toCompactHex()}");
    // logger.d("signature.R: ${signature.R}");
    // logger.d("signature.S: ${signature.S}");

    // var result = ecdsa.verify(privateKey.publicKey, hex.decode(hash), sig);
    // logger.d("result: ${result}");

    return signature;
  }

  /// secp256k1 verify signature
  Future<bool> verifySignatureAsym(ecdsa.Signature signature, PublicKey publicKey, String hash) async {
    logger.d("verifySignature");

    var result = ecdsa.verify(publicKey, hex.decode(hash), signature);
    logger.d("result: ${result}");

    return result;
  }

  Future<bool> verifySignatureAtIndexAsym(ecdsa.Signature signature, int keyIndex, String hash) async {
    logger.d("verifySignature");

    final privateKey = elliptic.PrivateKey(
      algorithm_secp256k1,
      BigInt.parse(_privateKeys[keyIndex], radix: 16),
    );

    var result = ecdsa.verify(privateKey.publicKey, hex.decode(hash), signature);
    logger.d("result: ${result}");

    return result;
  }

  Future<void> postQuantumProjectIntegrityTest() async {

    final fileHashList = await loadAsset();
    // _logManager.logLongMessage("fileHashes:\n\n${fileHashList}");

    final fileHash = _cryptor.sha256(fileHashList);

    final kek = List.filled(32, 0);
    // final kek = hex.encode(_cryptor.getRandomBytes(32));

    var keyIndex_secp256k1 = 0;

    if (publicKeys.isEmpty) {
      await createKeyTree(2);
    }

    if (keyIndex_secp256k1 >= publicKeys.length) {
      keyIndex_secp256k1 = 0;
    }

    final messageString = "publicKeyHashTree.secp256k1: ${publicKeyTree},"
        " publicKey.secp256k1: ${publicKeys[keyIndex_secp256k1]},"
        " project_file_hashes.txt: ${fileHash}";

    var msgObject = BasicMessageData(
      time: DateTime.now().toIso8601String(),
      message: messageString,
      signature: "",
    );

    final msgObjectHash = _cryptor.sha256(msgObject.toRawJson());

    /// compute asymmetric signature on message object
    final msgSignature = await signHashAsym(keyIndex_secp256k1, msgObjectHash);

    /// check asymmetric signature on message object
    // final checkSignature = ecdsa.Signature.fromCompactHex(msgSignature!.toCompactHex());
    // final verify = await _postQuantumManager.verifySignatureAtIndex(checkSignature, 0, msgObjectHash);
    // _logManager.logger.d("verify: ${verify}");

    /// add asymmetric signature to message object
    msgObject.signature = msgSignature!.toCompactHex();

    /// decode the post_quantum_signature object to get values for next signature
    var storedSignature = await loadAssetSignature();
    _logManager.logLongMessage("storedSignature:\n\n${storedSignature.replaceAll(" ", "").replaceAll("\n", "")}");

    var storedSignatureFormatted = storedSignature.replaceAll("\n", "");

    var thisSigatureIndex = 1;
    var lastBlockHash = "";
    try {
      var storedSignatureChainObject = WOTSSimpleOverlapSignatureChain.fromRawJson(
          storedSignatureFormatted,
      );
      storedSignatureChainObject.blocks.sort((a, b) => a.index.compareTo(b.index));

      _wotsManager.setSignatureChainObject(storedSignatureChainObject);

      thisSigatureIndex = storedSignatureChainObject.blocks.last.index + 1;
      lastBlockHash = _cryptor.sha256(
          storedSignatureChainObject.blocks.last.toRawJson());
    } catch (e) {
      logger.e("no previous block to get, must be genesis");
    }


    /// compute WOTS signature on message object
    // await _wotsManager.signMessage(kek, 1, msgObject.toRawJson());
    await _wotsManager.signSimpleOverlapMessage(kek, "main", lastBlockHash, thisSigatureIndex, msgObject.toRawJson());
  }

  Future<void> postQuantumProjectIntegrityTestVerify() async {
    var storedSignature = await loadAssetSignature();
    _logManager.logLongMessage("storedSignature:\n\n${storedSignature.replaceAll(" ", "").replaceAll("\n", "")}");

    var storedSignatureFormatted = storedSignature.replaceAll("\n", "");
    _logManager.logLongMessage("storedSignatureFormatted:\n\n${storedSignatureFormatted}");

    // final storedSignatureObject = WOTSBasicSignatureItem.fromRawJson(storedSignatureFormatted);
    final storedSignatureObject = WOTSSimpleOverlapSignatureChain.fromRawJson(storedSignatureFormatted);
    // _logManager.logLongMessage("storedSignatureObject:\n\n${storedSignatureObject}");

    // final isValid = await _wotsManager.verifySignature(storedSignatureObject);
    final isValid = await _wotsManager.verifySimpleOverlapSignature(storedSignatureObject.blocks.last);
    _logManager.logger.d("storedSignatureObject: isValid: ${isValid}");
  }

}