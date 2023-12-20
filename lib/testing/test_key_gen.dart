import "dart:math";

import "package:bip39/bip39.dart" as bip39;
import 'package:logger/logger.dart';
import "package:cryptography/cryptography.dart";
import "package:convert/convert.dart";
import 'package:flutter/cupertino.dart';

import '../helpers/WidgetUtils.dart';
import '../helpers/bip39_dictionary.dart';


final algorithm_nomac = AesCtr.with256bits(macAlgorithm: MacAlgorithm.empty);

class TestKeyGen {
  static final TestKeyGen _shared = TestKeyGen._internal();

  /// logging
  var logger = Logger(
    printer: PrettyPrinter(),
  );

  List<int> states = List<int>.filled(2048, 0);

  int iteration = 0;

  factory TestKeyGen() {
    return _shared;
  }


  TestKeyGen._internal();

  test_key1() async {
    final passphrase = "secret";
    final bytes = List<int>.filled(32, 0);

    logger.d("process key[${bytes.length}]: $bytes");
    List<int> secretKey = bytes;
    final encKey = SecretKey(secretKey);

    final zeroPad = List<int>.filled(16, 0);
    final noncePad = List<int>.filled(12, 0);

    // final iv_x = List<int>.filled(4, 0);
    final iv_y = List<int>.filled(4, 1);

    final noncePadExt = noncePad + iv_y;

    /// Encrypt the zero pad
    final secretBox = await algorithm_nomac.encrypt(
      zeroPad,
      secretKey: encKey,
      nonce: zeroPad,
    );

    final secretBox2 = await algorithm_nomac.encrypt(
      zeroPad,
      secretKey: encKey,
      nonce: noncePadExt,
    );
    logger.d("secretBox.ciphertext: ${secretBox.cipherText}");
    logger.d("secretBox2.ciphertext: ${secretBox2.cipherText}");
  }

  test_key2() async {
    final passphrase = "secret";
    final bytes = List<int>.filled(32, 0);

    logger.d("process key[${bytes.length}]: $bytes");
    List<int> secretKey = bytes;
    final encKey = SecretKey(secretKey);

    // final bigPad = List<int>.filled(16*16, 0);

    final zeroPad = List<int>.filled(16, 0);
    final noncePad = List<int>.filled(12, 0);

    final iv_x = List<int>.filled(4, 0);
    final iv_y = List<int>.filled(4, 1);

    final noncePadExt = noncePad + iv_y;

    /// Encrypt the zero pad
    final secretBox = await algorithm_nomac.encrypt(
      zeroPad,
      secretKey: encKey,
      nonce: zeroPad,
    );

    final secretBox2 = await algorithm_nomac.encrypt(
      zeroPad,
      secretKey: encKey,
      nonce: noncePadExt,
    );
    logger.d("secretBox.ciphertext: ${secretBox.cipherText}");
    logger.d("secretBox2.ciphertext: ${secretBox2.cipherText}");
  }

  test_key_stats() async {
    int blockSize = 16;
    // iteration += 1;

    // List<int> states = List<int>.filled(2048, 0);

    final passphrase = "secret";
    final bytes = List<int>.filled(32, 0);

    logger.d("process key[${bytes.length}]: $bytes");
    List<int> secretKey = bytes;
    final encKey = SecretKey(secretKey);

    num n = pow(2, 12);
    final bigPad = List<int>.filled((blockSize * n).toInt(), 0);

    final zeroPad = List<int>.filled(blockSize, 0);
    // final noncePad = List<int>.filled(12, 0);

    // final iv_x = List<int>.filled(4, 0);
    var ahex = int.parse("${(n * iteration).toInt()}").toRadixString(16);
    logger.d("ahex: $ahex");

    if (ahex.length % 2 == 1) {
      ahex = "0" + ahex;
    }

    final abytes = hex.decode(ahex);
    logger.d("abytes: $abytes");

    final noncePadExt = zeroPad.sublist(0, 16 - abytes.length) + abytes;
    logger.d("noncePadExt: $noncePadExt");

    /// Encrypt the zero pad
    final secretBox = await algorithm_nomac.encrypt(
      bigPad,
      secretKey: encKey,
      nonce: noncePadExt,
    );

    // final secretBox2 = await algorithm_nomac.encrypt(
    //   zeroPad,
    //   secretKey: encKey,
    //   nonce: noncePadExt,
    // );
    logger.d("secretBox.ciphertext: ${secretBox.cipherText}");
    logger.d("secretBox.nonce: ${secretBox.nonce}");

    for (var index = 0;
        index < secretBox.cipherText.length / blockSize;
        index++) {
      final part = secretBox.cipherText
          .sublist(index * blockSize, blockSize * (index + 1));
      final words = bip39.entropyToMnemonic(hex.encode(part));
      // logger.d("$index: $words");

      final wordParts = words.split(" ");
      for (var w in wordParts) {
        final i = WORDLIST.indexOf(w);
        states[i] += 1;
      }
    }

    final nw_pos = (n * iteration * 12).toInt();

    logger.d("states: $states");
    logger.d(
        "states max: ${(states.reduce(max))}: ${WORDLIST[states.indexOf(states.reduce(max))]}");
    logger.d("states index of max: ${(states.indexOf(states.reduce(max)))}");

    // logger.d("states min: ${(states.reduce(min))}");
    logger.d(
        "states min: ${(states.reduce(min))}: ${WORDLIST[states.indexOf(states.reduce(min))]}");
    logger.d("states index of min: ${(states.indexOf(states.reduce(min)))}");

    logger.d(
        "${states.reduce(max) - states.reduce(min)}: ${(states.reduce(max) / nw_pos) * 100}");
    iteration += 1;
  }

  /// function to run selected tests
  runTests(BuildContext context) async {

    WidgetUtils.showSnackBarDuration(
      context,
      "Testing\n...",
      Duration(seconds: 3),
    );

    // await test_key_stats();
  }

}
