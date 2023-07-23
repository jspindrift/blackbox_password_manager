import 'dart:convert';
import 'package:crypto/crypto.dart';

/// cant use these two classes together
// import 'package:crypt/crypt.dart' as crypt;
// import 'package:cryptography/cryptography.dart';

class Hasher {
  static final Hasher _shared = Hasher._internal();

  factory Hasher() {
    return _shared;
  }

  Hasher._internal();

  String sha256Hash(String message) {
    // print('hashing: $message');
    var msgInBytes = utf8.encode(message);
    Digest value = sha256.convert(msgInBytes);

    // print("hashed string: ${value.toString()}");
    // print("hashed bytes: ${value.bytes}");

    return value.toString();
  }
}
