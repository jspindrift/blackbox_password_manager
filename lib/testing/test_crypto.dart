import "dart:math";
import "dart:convert";
import "dart:typed_data";

import "package:bip39/bip39.dart" as bip39;
import "package:logger/logger.dart";
import "package:cryptography/cryptography.dart";
import "package:crypt/crypt.dart";
import "package:convert/convert.dart";
import "package:argon2/argon2.dart";
import 'package:flutter/foundation.dart';
import 'package:ecdsa/ecdsa.dart';
import 'package:elliptic/elliptic.dart';

import '../helpers/WidgetUtils.dart';
import '../managers/Hasher.dart';
import '../managers/Cryptor.dart';


class TestCrypto {
  static final TestCrypto _shared = TestCrypto._internal();

  /// logging
  var logger = Logger(
    printer: PrettyPrinter(),
  );
  
  final algorithm_nomac = AesCtr.with256bits(macAlgorithm: MacAlgorithm.empty);

  factory TestCrypto() {
    return _shared;
  }

  final cryptor = Cryptor();

  TestCrypto._internal();

  
  test_signing_ecdsa_k_s256() async {
    // var ec = getP256();

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

    assert(result);
  }

  test_key_exchange_ecdh_p256() async {
    final algorithm = Ecdh.p256(length: 256);

    // We need the private key pair of Alice.
    final aliceKeyPair = await algorithm.newKeyPair();
    logger.d("aliceKeyPair: ${aliceKeyPair.extract()}");

    // We need only public key of Bob.
    final bobKeyPair = await algorithm.newKeyPair();
    final bobPublicKey = await bobKeyPair.extractPublicKey();
    logger.d("bobPublicKey.X: ${bobPublicKey.x}");
    logger.d("bobPublicKey.Y: ${bobPublicKey.y}");

    // We can now calculate a 32-byte shared secret key.
    final sharedSecretKey = await algorithm.sharedSecretKey(
      keyPair: aliceKeyPair,
      remotePublicKey: bobPublicKey,
    );

    logger.d("sharedSecretKey: ${sharedSecretKey.extractBytes()}");
  }

  test_key_exchange_X25519() async {
    final algorithm = X25519();
    final aliceKeyPair = await algorithm.newKeyPair();
    logger.d('algorithm: ${algorithm}');
    final priv = await aliceKeyPair.extractPrivateKeyBytes();

    logger.d('aliceKeyPair Priv: ${priv}');
    logger.d('aliceKeyPair Priv.Hex: ${hex.encode(priv)}');

    final seedBytes = hex.decode(
        "7494049889df7542d98afe065f5e27b86754f09e550115871016a67781a92535");
    final privSeedPair = await algorithm.newKeyPairFromSeed(seedBytes);
    final privSeed = await privSeedPair.extractPrivateKeyBytes();

    logger.d('aliceKeyPair privSeed: ${privSeed}');
    final pubSeed = await privSeedPair.extractPublicKey();
    logger.d('aliceKeyPair PubSeed: ${pubSeed.bytes}');

    final pub = await aliceKeyPair.extractPublicKey();
    logger.d('aliceKeyPair Pub: ${pub.bytes}');

    // Generate a key pair for Bob.
    //
    // In a real application, we will receive or know Bob's public key
    final bobKeyPair = await algorithm.newKeyPair();
    final bobPublicKey = await bobKeyPair.extractPublicKey();
    final priv2 = await bobKeyPair.extractPrivateKeyBytes();
    logger.d('bobKeyPair Priv2: ${priv2}');

    final pub2 = await bobKeyPair.extractPublicKey();
    logger.d('bobKeyPair Pub type: ${pub2.type}');

    logger.d('bobKeyPair Pub: ${pub2.bytes}');
    logger.d('bobKeyPair Pub.Hex: ${hex.encode(pub2.bytes)}');

    final pubMade = SimplePublicKey(pub2.bytes, type: pub2.type);
    logger.d('bobKeyPair pubMade: ${pubMade.bytes}');
    logger.d('bobKeyPair pubMade.Hex: ${hex.encode(pubMade.bytes)}');

    // We can now calculate a shared secret.
    final sharedSecret = await algorithm.sharedSecretKey(
      keyPair: aliceKeyPair,
      remotePublicKey: bobPublicKey,
    );
    final sharedSecretBytes = await sharedSecret.extractBytes();
    logger.d('Shared secret: $sharedSecretBytes');
  }


  Future<List<int>> processKey(List<int> bytes) async {
    logger.d("process key[${bytes.length}]: $bytes");
    List<int> secretKey = bytes; //List<int>.filled(32, 0);
    final encKey = SecretKey(secretKey);

    final hexStringKey = hex.encode(bytes);
    String mnemonicKey = bip39.entropyToMnemonic(hexStringKey);
    logger.d("mnemonicKey : $mnemonicKey");

    if (bytes.length % 16 == 0) {
      logger.d("correct byte length");
    }

    // if (bytes.length%4 == 0) {
    //   logger.d("correct %4 byte length");
    // }

    if (bytes.length % 2 == 0) {
      logger.d("correct %2 byte length");
    } else {
      logger.d("incorrent key length: ${bytes.length}");
      return [];
    }

    List<int> xorList = bytes;

    List<int> xorList_16 = [];
    List<int> xorList_c = [];
    List<int> xorList_d = [];

    // List<int> xorList = [];
    // List<int> xorList2 = List<int>.filled(bytes.length, 0);

    // for (int i = 0; i < bytes.length/4; i += 4) {
    while (xorList.length != 4) {
      // 4
      final x =
          Uint8List.fromList(bytes.sublist(0, (xorList.length! / 2).toInt()));
      final y = Uint8List.fromList(bytes.sublist(
          (xorList.length! / 2).toInt(), (xorList.length!).toInt()));

      xorList = cryptor.xor(x, y);
      logger.d("xorList[${xorList.length}]: ${xorList}");

      if (xorList.length == 16) {
        // xorList_ab = xorList.sublist(0, (xorList.length / 2).toInt());
        xorList_16 = xorList;
      } else if (xorList.length == 8) {
        // xorList_c = xorList.sublist(0, (xorList.length / 2).toInt());
        xorList_c = xorList;
      } else if (xorList.length == 4) {
        xorList_d = xorList;
      } else {
        logger.d("xorList[${xorList.length}]: $xorList");
      }
    }

    logger.d("result[${xorList.length}]: ${xorList}");

    logger.d(
        "checksum[${16},${8}, ${4}]: ${xorList_16} ${xorList_c} ${xorList_d}");

    List<int> xorInverseList = []; //bytes;

    for (var index = 0; index < 8; index++) {
      final xx = Uint8List.fromList(xorList);
      final y = Uint8List.fromList(bytes.sublist(index * 4, 4 * (index + 1)));
      // logger.d("y[${index}]: ${y}");

      xorInverseList.addAll(cryptor.xor(xx, y));
    }

    logger.d("xorInverseList[${xorInverseList.length}]: ${xorInverseList}");

    final hexStringKeyInverse = hex.encode(xorInverseList);
    String mnemonicKeyInverse = bip39.entropyToMnemonic(hexStringKeyInverse);
    logger.d("mnemonicKeyInverse : $mnemonicKeyInverse");

    final iv = List<int>.filled(16, 0);
    // logger.d("iv: ${iv.length}: ${iv}");

    List<int> plaintextList = List<int>.filled(16, 0);

    /// Encrypt
    final secretBox = await algorithm_nomac.encrypt(
      plaintextList,
      secretKey: encKey,
      nonce: iv,
    );

    final hexString = hex.encode(secretBox.cipherText);
    String mnemonic = bip39.entropyToMnemonic(hexString);

    final parts = mnemonic.split(" ");

    logger.d("MAC mnemonic: $mnemonic");
    logger.d("MAC mnemonic: ${parts.first}, ${parts[1]}, ${parts[2]}");

    List<int> iv_index = List<int>.filled(4, 0);
    List<int> iv_counter = List<int>.filled(4, 0);

    List<int> iv_first = xorList_c + iv_index + iv_counter;

    logger.d("iv_first: ${iv_first.length}: ${iv_first}");

    /// Encrypt
    final secretBoxFirst = await algorithm_nomac.encrypt(
      plaintextList,
      secretKey: encKey,
      nonce: iv_first,
    );
    logger.d("secretBoxFirst: ${secretBoxFirst.cipherText}");
    final hexStringX = hex.encode(secretBoxFirst.cipherText);
    String mnemonicX = bip39.entropyToMnemonic(hexStringX);

    final partsX = mnemonicX.split(" ");

    logger.d("first mnemonic: $mnemonicX");

    return xorList;
  }


  /// PBKDF2
  ///
  test_deriveKey_256() async {
    // logger.d("test PBKDF2 - deriving key");

    final startTime = DateTime.now();
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 200000,
      bits: 256,
    );

    // Password we want to hash
    final password = "password";
    final secretKey = SecretKey(password.codeUnits);

    // A random salt
    final rng = Random();
    var saltRandom = new List.generate(16, (_) => rng.nextInt(255));
    logger.d("random salt: $saltRandom");

    // Calculate a hash that can be stored in the database
    final newSecretKey = await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: saltRandom,
    );

    final endTime = DateTime.now();

    final timeDiff = endTime.difference(startTime);
    logger.d("time diff2 256: ${timeDiff.inMilliseconds} ms");
    logger.d("time diff2 256: ${timeDiff.inSeconds} seconds");

    final newSecretKeyBytes = await newSecretKey.extractBytes();
    logger.d("pbkdf2 result: $newSecretKeyBytes");

    final hexSecretString = hex.encode(newSecretKeyBytes);
    logger.d("pbkdf2 result hex[${hexSecretString.length}]: $hexSecretString");
  }

  /// PBKDF2
  ///
  test_deriveKey_512() async {
    // logger.d("test PBKDF2 - deriving key");

    final startTime = DateTime.now();
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha512(),
      iterations: 200000,
      bits: 512,
    );

    // Password we want to hash
    final password = "password";
    final secretKey = SecretKey(password.codeUnits);

    // A random salt
    final rng = Random();
    var saltRandom = new List.generate(32, (_) => rng.nextInt(255));

    logger.d("random salt: $saltRandom");

    // Calculate a hash that can be stored in the database
    final newSecretKey = await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: saltRandom,
    );

    final endTime = DateTime.now();

    final timeDiff = endTime.difference(startTime);
    logger.d("time diff2 512: ${timeDiff.inMilliseconds} ms");
    logger.d("time diff2 512: ${timeDiff.inSeconds} seconds");

    final newSecretKeyBytes = await newSecretKey.extractBytes();
    logger.d("pbkdf2 result: $newSecretKeyBytes");

    final hexSecretString = hex.encode(newSecretKeyBytes);
    logger.d("pbkdf2 result hex[${hexSecretString.length}]: $hexSecretString");
  }

  /// PBKDF2
  ///
  Future<void> test_deriveSeed_512() async {
    // logger.d("test PBKDF2 - deriving key");

    final startTime = DateTime.now();
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha512(),
      iterations: 4096,
      bits: 512,
    );

    // Password we want to hash
    final passphrase = "password";

    String randomMnemonic = bip39.generateMnemonic(strength: 128);
    logger.d("randomMnemonic128: $randomMnemonic");

    final secretKey = SecretKey(utf8.encode(randomMnemonic));

    // A random salt
    // final rng = Random();
    // var saltRandom = new List.generate(32, (_) => rng.nextInt(255));
    // logger.d("random salt: $saltRandom");

    final saltShortString = "com.blackboxsystems" + passphrase;
    // logger.d("saltShortString: $saltShortString");

    final saltRandom = utf8.encode(saltShortString.trim());
    logger.d("salt: $saltRandom");

    final saltRandomHash = sha2562(saltShortString);
    logger.d("random saltRandomHash: $saltRandomHash");

    final saltRandomHashBytes = hex.decode(saltRandomHash);
    logger.d("random salt bytes: $saltRandomHashBytes");

    // Calculate a hash that can be stored in the database
    final newSecretKey = await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: saltRandomHashBytes,
    );

    final endTime = DateTime.now();

    final timeDiff = endTime.difference(startTime);
    logger.d("time diff2 512: ${timeDiff.inMilliseconds} ms");
    logger.d("time diff2 512: ${timeDiff.inSeconds} seconds");

    final newSecretKeyBytes = await newSecretKey.extractBytes();
    logger.d("pbkdf2 result: $newSecretKeyBytes");

    final Ka = newSecretKeyBytes.sublist(0, 32);
    final Kb = newSecretKeyBytes.sublist(32, 64);
    logger.d("pbkdf2 Ka: $Ka");
    final wa = bip39.entropyToMnemonic(hex.encode(Ka));
    logger.d("pbkdf2 Ka words: $wa");

    logger.d("pbkdf2 Kb: $Kb");
    final wb = bip39.entropyToMnemonic(hex.encode(Kb));
    logger.d("pbkdf2 Kb words: $wb");

    final Kc = cryptor.xor(Uint8List.fromList(Ka), Uint8List.fromList(Kb));
    logger.d("pbkdf2 Kc: $Kc");

    final wc = bip39.entropyToMnemonic(hex.encode(Kc));
    logger.d("pbkdf2 Kc words: $wc");

    final hexSecretString = hex.encode(newSecretKeyBytes);
    logger.d("pbkdf2 result hex[${hexSecretString.length}]: $hexSecretString");

    WidgetUtils.showToastMessage("${wc}", 5);
  }

  /// PBKDF2
  ///
  Future<void> test_deriveKey_512_2() async {
    // logger.d("test PBKDF2 - deriving key");

    final startTime = DateTime.now();
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha512(),
      iterations: 4096,
      bits: 256,
    );

    final shortKey =
        "slow return inquiry priority palace board breeze dirt task limit pottery naive";
    final isShortValid = bip39.validateMnemonic(shortKey);

    if (!isShortValid) {
      logger.d("invalid short key");
      return;
    }
    // Password we want to hash
    final passphrase = "password";

    final secretKey = SecretKey(utf8.encode(shortKey));

    final saltShortString = "com.blackboxsystems" + passphrase;
    // logger.d("saltShortString: $saltShortString");

    final saltRandom = utf8.encode(saltShortString.trim());
    logger.d("random salt: $saltRandom");

    // Calculate a hash that can be stored in the database
    final newSecretKey = await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: saltRandom,
    );

    final endTime = DateTime.now();

    final timeDiff = endTime.difference(startTime);
    logger.d("time diff2 512: ${timeDiff.inMilliseconds} ms");
    logger.d("time diff2 512: ${timeDiff.inSeconds} seconds");

    final newSecretKeyBytes = await newSecretKey.extractBytes();
    logger.d("pbkdf2 result: $newSecretKeyBytes");

    final derivedWord = bip39.entropyToMnemonic(hex.encode(newSecretKeyBytes));
    logger.d("pbkdf2 derived words: $derivedWord");

    final Ka = newSecretKeyBytes.sublist(0, 16);
    final Kb = newSecretKeyBytes.sublist(16, 32);
    logger.d("pbkdf2 Ka: $Ka");
    logger.d("pbkdf2 Kb: $Kb");

    final wa = bip39.entropyToMnemonic(hex.encode(Ka));
    logger.d("pbkdf2 Ka words: $wa");

    final wb = bip39.entropyToMnemonic(hex.encode(Kb));
    logger.d("pbkdf2 Kb words: $wb");

    final Kc = cryptor.xor(Uint8List.fromList(Ka), Uint8List.fromList(Kb));
    logger.d("pbkdf2 Kc: $Kc");

    final wc = bip39.entropyToMnemonic(hex.encode(Kc));
    logger.d("pbkdf2 Kc words: $wc");

    final hexSecretString = hex.encode(newSecretKeyBytes);
    logger.d("pbkdf2 result hex[${hexSecretString.length}]: $hexSecretString");

    WidgetUtils.showToastMessage("${wc}", 5);
  }

  Future<void> proofOfWork() async {
    logger.d("proofOfWork: starting");

    num iterationLimit = pow(2, 28);
    int nonce = 0;
    int difficulty = 4; // 4 hex or 2 bytes
    List<int> zeros = List<int>.filled(8, 0); // bytes
    var zerosHex = hex.encode(zeros); // 16 hex chars
    logger.d("proofOfWork: zerosHex: $zerosHex");

    bool valid = false;
    final passphrase =
        "0000000000000000000000000000000000000000000000000000000000000000";
    // "0000000000000000000000000000000000000000000000000000000000000000"
    // final message = "ebf8d9414d13f82516b0b84c67c888dc3f49e9bdc1e3647750693f91c37653a1$nonce";

    // logger.d("proofOfWork: limit: ${pow(2,63)}");
    // logger.d("proofOfWork: limit: ${pow(2,63)-1}");

    logger.d("proofOfWork: passphrase: $passphrase, difficulty: $difficulty");

    final startTime = DateTime.now();

    while (!valid) {
      nonce += 1;
      final pwd = passphrase + nonce.toRadixString(16); //nonce.toString();
      final pwd2 = passphrase + nonce.toString();

      final hash = sha2562(pwd);
      final data = hex.decode(hash);

      final hash2 = sha2562(pwd2);
      final data2 = hex.decode(hash2);
      // logger.d("pwd: $pwd");
      // logger.d("hash: $hash");
      // logger.d("data: $data");
      // logger.d("data: ${data.sublist(0,difficulty)}, zeros: ${zeros.sublist(0, difficulty)}");
      // logger.d("data == zeros: ${data.sublist(0,difficulty) == zeros.sublist(0, difficulty)}");
      // logger.d("data == zeros.string: ${data.sublist(0,difficulty).toString() == zeros.sublist(0, difficulty).toString()}");

      // if (hash.substring(0,difficulty-1) == zerosHex.substring(0, difficulty-1)) {
      //   logger.d("valid hash string (difficulty-1): ${pwd}: ${nonce}: ${hash}");
      //   // final word = bip39.entropyToMnemonic(hash);
      //   // logger.d("valid hash word (difficulty-1): ${word}");
      // }
      // if (difficulty > 0) {
      //   if (hash.substring(0, difficulty+1) ==
      //       zerosHex.substring(0, difficulty+1)) {
      //
      //   }
      // }
      if (hash2.substring(0, difficulty) == zerosHex.substring(0, difficulty)) {
        logger.d("valid hash2 string: ${pwd2}: ${nonce}: ${hash2}");
      }
      if (hash.substring(0, difficulty) == zerosHex.substring(0, difficulty)) {
        valid = true;
        logger.d("valid hash string: ${pwd}: ${nonce}: ${hash}");
        final word = bip39.entropyToMnemonic(hash);
        logger.d("valid hash word: ${word}");
        final endTime = DateTime.now();
        final timeDiff = endTime.difference(startTime);
        logger.d("POW time diff: ${timeDiff.inMilliseconds} ms");
        logger.d("POW time diff: ${timeDiff.inSeconds} sec");
        logger.d(
            "POW rate: ${(nonce / timeDiff.inMilliseconds).toStringAsFixed(2)} H/ms, ${((nonce / timeDiff.inMilliseconds) * 1000).toStringAsFixed(2)} H/s");
        logger.d(
            "POW search space: ${((nonce / pow(2, 4 * difficulty)) * 100).toStringAsFixed(2)} %");

        break;
      }

      if (data.sublist(0, difficulty).toString() ==
          zeros.sublist(0, difficulty).toString()) {
        valid = true;
        logger.d("valid hash: ${pwd}: ${nonce}: ${hash}");
        break;
      }
      if (nonce > iterationLimit) {
        logger.d("reached limit");
        break;
      }
      if (nonce % pow(2, 4 * difficulty - 2) == 0) {
        logger.d(
            "reached window: ${((nonce / iterationLimit) * 100).toStringAsFixed(2)} %");
        logger.d(
            "window let: ${((nonce / pow(2, 4 * difficulty)) * 100).toStringAsFixed(2)} %");
        logger.d("pwd: $pwd");
        logger.d("hash: $hash");

        // break;
      }
    }
  }

  /// Hashing
  String sha256(String message) {
    final c1 = Crypt.sha256(message);

    return c1.hash;
  }

  /// Hashing
  String sha2562(String message) {
    final c1 = Hasher().sha256Hash(message);

    return c1;
  }


  /// test hashing using Crypt library
  ///
  test_Hashes() {
    // Default rounds and random salt generated
    final c1 = Crypt.sha256("password");

    // Random salt generated
    final c2 = Crypt.sha256("password", rounds: 10000);

    // Default rounds
    final c3 = Crypt.sha256("password", salt: "abcdefghijklmnop");

    // No defaults used
    final c4 =
        Crypt.sha256("password", rounds: 10000, salt: "abcdefghijklmnop");

    // SHA-512
    final d1 = Crypt.sha512("password");

    logger.d(c1);
    logger.d(c2);
    logger.d(c3);
    logger.d(c4);
    logger.d(d1);
  }

  test_hash_zeros() {
    final message = "password";
    List<int> pad16 = List<int>.filled(16, 0);
    List<int> pad32 = List<int>.filled(32, 0);
    final hex1 =
        "66687aadf862bd776c8fc18b8e9f8e20089714856ee233b3902a591d0d5f2925";

    final x = sha256(message);
    logger.d("hash(password): ${x}");

    final x_2 = Hasher().sha256Hash(message);
    logger.d("hasher(password): ${x_2}");

    final x16 = sha256(utf8.decode(pad16));
    logger.d("hash(x16): ${x16}");

    final x16_2 = Hasher().sha256Hash(utf8.decode(pad16));
    logger.d("hasher(x16_2): ${x16_2}");

    final x32 = sha256(utf8.decode(pad32));
    logger.d("hash(x32): ${x32}");

    final x32_2 = Hasher().sha256Hash(utf8.decode(pad32));
    logger.d("hasher(x32_2): ${x32_2}");

    final hex1bytes = hex.decode(hex1);
    logger.d("hex1bytes: ${hex1bytes}");
    logger.d("hex1bytes: ${hex1bytes.toString()}");

    final hex_2 = Hasher().sha256Hash(hex1);
    logger.d("hasher(hex_2): ${hex_2}");
  }

  /// Argon2
  ///
  void test_Argon2() async {
    var password = "test";
    // var salt = "somesalt".toBytesLatin1();
    // create a random salt
    final rng = Random();
    final salt = new List.generate(16, (_) => rng.nextInt(255));

    logger.d("argon2: starting time");
    final uint8Salt = Uint8List.fromList(salt);
    logger.d("uint8Salt: $uint8Salt");

    final startTime = DateTime.now();
    var parameters = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      uint8Salt,
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
    logger.d("time diff2: ${timeDiff.inMilliseconds} ms");

    logger.d("Result: $resultHex");
  }

  /// encryption
  ///
  test_AES_GSM() async {
    logger.d("Doing AES GCM mode...");
    final algorithm = AesGcm.with256bits();

    // Generate a random 256-bit secret key
    final secretKey = await algorithm.newSecretKey();

    // Generate a random 96-bit nonce.
    final nonce = algorithm.newNonce();

    // Encrypt
    final message = "hello world.";
    final secretBox = await algorithm.encrypt(
      utf8.encode(message),
      secretKey: secretKey,
      nonce: nonce,
    );
    logger.d("gsm Ciphertext: ${secretBox.cipherText}");
    logger.d("gsm MAC: ${secretBox.mac}");
    logger.d("gsm nonce: ${secretBox.nonce.length}, ${secretBox.nonce}");
  }

  test_AES_CTR_256() async {
    logger.d("Doing AES CTR mode...");
    final algorithm = AesCtr.with256bits(macAlgorithm: Hmac.sha256());

    // Generate a random 256-bit secret key
    final secretKey = await algorithm.newSecretKey();

    await secretKey
        .extractBytes()
        .then((value) => logger.d("ctr secret key bytes: ${hex.encode(value)}"));
    // logger.d("ctr secret key: ${secretKey.extractBytes()}");

    // Generate a random 128-bit nonce.
    final nonce = algorithm.newNonce();
    logger.d("ctr nonce: ${nonce.length}, $nonce");

    // Encrypt
    final message = "hello world.";
    final secretBox = await algorithm.encrypt(
      utf8.encode(message),
      secretKey: secretKey,
      nonce: nonce,
    );

    logger.d("ctr Ciphertext: ${secretBox.cipherText}");
    logger.d("ctr MAC: ${secretBox.mac}");
    // logger.d("ctr nonce: ${secretBox.nonce}");

    final hmac = Hmac.sha256();
    final mac = await hmac.calculateMac(
      secretBox.cipherText,
      secretKey: secretKey,
    );

    logger.d("ctr custom mac: $mac");
    logger.d("custom mac == secretBox.mac: ${secretBox.mac == mac}");
  }


  void test_AESCTR_128() async {
    final message = "hello world";

    // AES-CTR with 128 bit keys and HMAC-SHA256 authentication.
    final algorithm = AesCtr.with128bits(
      macAlgorithm: Hmac.sha256(),
    );
    final secretKey = await algorithm.newSecretKey();
    final nonce = algorithm.newNonce();

    // Encrypt
    final secretBox = await algorithm.encrypt(
      utf8.encode(message),
      secretKey: secretKey,
      nonce: nonce,
    );
    logger.d("Nonce: ${secretBox.nonce}");
    logger.d("Ciphertext: ${secretBox.cipherText}");
    logger.d("MAC: ${secretBox.mac.bytes}");

    // Decrypt
    final clearText = await algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    logger.d("Cleartext: $clearText");
  }


  /// Show nonce resets to all zeros when we reach max nonce iteration
  ///
  test_AES_CTR_256_IV_OVERFLOW_TEST() async {
    logger.d("Doing AES CTR mode...test_AES_CTR_IV_OVERFLOW_TEST");
    final algorithm = AesCtr.with256bits(macAlgorithm: Hmac.sha256());

    // Generate a random 256-bit secret key
    final secretKey = SecretKey(List.filled(32, 0));
    // final secretKey = await algorithm.newSecretKey();
    
    // Generate a maxed out 128-bit nonce.
    final nonce = List.filled(16, 255);
    logger.d("ctr nonce: ${nonce.length}, $nonce");

    final nonceZero = List.filled(16, 0);

    // Encrypt with max nonce, and plaintext 2 blocks in length
    final message = List.filled(32, 0);
    final secretBox = await algorithm.encrypt(
      message, //utf8.encode(message),
      secretKey: secretKey,
      nonce: nonce,
    );
    logger.d("ctr Ciphertext: ${secretBox.cipherText}");
    logger.d("ctr MAC: ${secretBox.mac}");
    // logger.d("ctr nonce: ${secretBox.nonce}");

    final cipher_iv_max = secretBox.cipherText.sublist(16, 32);

    // Encrypt with zero nonce
    final secretBox2 = await algorithm.encrypt(
      message, //utf8.encode(message),
      secretKey: secretKey,
      nonce: nonceZero,
    );
    logger.d("2 ctr Ciphertext: ${secretBox2.cipherText}");
    logger.d("2 ctr MAC: ${secretBox2.mac}");

    final cipher_overflow = secretBox2.cipherText.sublist(0, 16);
    logger.d("cipher_iv_max: ${cipher_iv_max}");
    logger.d("cipher_overflow: ${cipher_overflow}");
  }

  test_AES_CTR_256_CUSTOM_IV() async {
    logger.d("Doing AES CTR mode...test_AES_CTR_CUSTOM_IV");
    final algorithm = AesCtr.with256bits(macAlgorithm: Hmac.sha256());

    // Generate a random 256-bit secret key
    final secretKey = SecretKey(List.filled(32, 0));

    final nonceZero = List.filled(16, 0); //algorithm.newNonce();
    // final keyBytes = List<int>.filled(32, 0);

    // logger.d("process key[${keyBytes.length}]: $keyBytes");
    // List<int> secretKey = keyBytes;
    // final encKey = SecretKey(keyBytes);

    num n = pow(2, 5); // 32
    final bigPad = List<int>.filled((32 * n).toInt(), 0);

    final zeroNoncePad = List<int>.filled(16, 0);
    // final noncePad = List<int>.filled(12, 0);

    // final iv_x = List<int>.filled(4, 0);
    var ahex = int.parse("${(32 * n).toInt()}").toRadixString(16);
    logger.d("ahex: $ahex");

    if (ahex.length % 2 == 1) {
      ahex = "0" + ahex;
    }

    final abytes = hex.decode(ahex);
    logger.d("abytes: $abytes");

    final noncePadExt = zeroNoncePad.sublist(0, 16 - abytes.length) + abytes;
    logger.d("noncePadExt: $noncePadExt");

    /// Encrypt the zero pad
    final secretBox = await algorithm_nomac.encrypt(
      bigPad,
      secretKey: secretKey,
      nonce: nonceZero,
    );
    logger.d("ctr Ciphertext: ${secretBox.cipherText}");
    logger.d("ctr MAC: ${secretBox.mac}");

    // final message = List.filled(32*32, 0);// "ðð";
    final secretBox2 = await algorithm_nomac.encrypt(
      bigPad,
      secretKey: secretKey,
      nonce: noncePadExt,
    );
    logger.d("secretBox2 Ciphertext: ${secretBox2.cipherText}");
    logger.d("secretBox2 MAC: ${secretBox2.mac}");
    // logger.d("ctr nonce: ${secretBox.nonce}");

    List<String> _pubLeaves = [];
    List<String> _privLeaves = [];

    List<String> _pubLeavesNext = [];
    List<String> _privLeavesNext = [];

    List<int> publicPad = [];
    for (var index = 0;
    index < secretBox.cipherText.length / 32;
    index++) {
      final part =
      secretBox.cipherText.sublist(index * 32, 32 * (index + 1));
      // final words = bip39.entropyToMnemonic(hex.encode(part));
      // logger.d("$index: $words");

      _privLeaves.add(hex.encode(part));

      var leafHash = cryptor.sha256(hex.encode(part));
      for (var i = 0; i < 254; i++) {
        leafHash = cryptor.sha256(leafHash);
      }
      // final leafHash = cryptor.sha256(hex.encode(part));
      _pubLeaves.add(leafHash);
      publicPad.addAll(hex.decode(leafHash));
    }
    logger.d("_privLeaves: $_privLeaves");
    logger.d("_pubLeaves: $_pubLeaves");
    logger.d("publicPad: $publicPad");
    // logger.d("publicPadHex: ${hex.encode(publicPad)}");

    final topPubHash = cryptor.sha256(hex.encode(publicPad));
    logger.d("topPubHash: ${topPubHash}");
    // final cipher_iv_max = secretBox.cipherText.sublist(16, 32);


    // final cipher_overflow = secretBox2.cipherText.sublist(0, 16);
    // logger.d("cipher_iv_max: ${cipher_iv_max}");
    // logger.d("cipher_overflow: ${cipher_overflow}");
  }

  /// data conversion
  ///
  test_data_conversion() {
    final str = "testing";
    final bytes = str.codeUnits;
    // final utf8bytes = str.codeUnits;

    final utf8code = utf8.encode(str);

    logger.d("string as ints: $bytes");
    logger.d("string as utf8: $utf8code");

    final hexString = hex.encode(bytes);

    logger.d("ints as hex string: $hexString");

    logger.d("hex string as ints: ${hex.decode(hexString)}");

    logger.d("ints as char string: ${String.fromCharCodes(bytes)}");
  }

  test_data_conversion2() {
    String randomMnemonic = bip39.generateMnemonic(strength: 128);
    logger.d("randomMnemonic128: $randomMnemonic");
    String entropy128 = bip39.mnemonicToEntropy(randomMnemonic);
    logger.d("entropy128: $entropy128");
    String seed128 =
        bip39.mnemonicToSeedHex(randomMnemonic, passphrase: "password");
    logger.d("seed128: $seed128");

    final utf8code128 = utf8.encode(entropy128);
    logger.d("utf8code128: ${utf8code128.length}: $utf8code128");

    final bytes128 = hex.decode(entropy128);
    logger.d("bytes128: ${bytes128.length}: $bytes128");

    final base64128 = base64.encode(bytes128);
    logger.d("base64128: ${base64128.length}: ${base64128}");

    String randomMnemonic2 = bip39.generateMnemonic(strength: 256);
    logger.d("randomMnemonic256: $randomMnemonic2");
    String entropy256 = bip39.mnemonicToEntropy(randomMnemonic2);
    logger.d("entropy256: $entropy256");
    String seed256 = bip39.mnemonicToSeedHex(randomMnemonic2);
    logger.d("seed256: $seed256");

    final utf8code256 = utf8.encode(entropy256);
    logger.d("utf8code256: ${utf8code256.length}: $utf8code256");

    final bytes256 = hex.decode(entropy256);
    logger.d("bytes256: ${bytes256.length}: $bytes256");

    // final base64256 = base64.encode(bytes256+bytes256+bytes256+bytes256.sublist(0,22));
    // final base64256 = base64.encode(bytes256+bytes256+bytes256+bytes256);
    final base64256 = base64.encode(bytes256);

    logger.d("base64256: ${base64256.length}: ${base64256}");
  }

  test_mnemonics() {
    String randomMnemonic = bip39.generateMnemonic(strength: 128);
    logger.d("randomMnemonic128: $randomMnemonic");

    String randomMnemonic2 = bip39.generateMnemonic(strength: 256);
    logger.d("randomMnemonic256: $randomMnemonic2");

    String seed = bip39.mnemonicToSeedHex(
        "update elbow source spin squeeze horror world become oak assist bomb nuclear");
    logger.d("seedhex: $seed");
    String mnemonic =
        bip39.entropyToMnemonic("00000000000000000000000000000000");
    logger.d("mnemonic: $mnemonic");
    bool isValid = bip39.validateMnemonic(mnemonic);
    logger.d("isValid true: $isValid");
    isValid = bip39.validateMnemonic("basket actual");
    logger.d("isValid false: $isValid");
    String entropy = bip39.mnemonicToEntropy(mnemonic);
    logger.d("entropy: $entropy");
  }
  
  test_mnemonic_seed() async {
    final randomKeyWords = bip39.generateMnemonic(strength: 256);

    String seed128 =
        bip39.mnemonicToSeedHex(randomKeyWords, passphrase: "password");
    logger.d("seed128: $seed128");

    final e =
        "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f";
    final em = bip39.entropyToMnemonic(e);

    String seed2 = bip39.mnemonicToSeedHex(em, passphrase: "");
    logger.d("seed2: $seed2");
  }


  /// function to run selected tests
  runTests() async {
    await test_AES_CTR_256_IV_OVERFLOW_TEST();
  }


}
