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
    var msgInBytes = utf8.encode(message);
    Digest value = sha256.convert(msgInBytes);

    return value.toString();
  }

  String sha512Hash(String message) {
    var msgInBytes = utf8.encode(message);
    Digest value = sha512.convert(msgInBytes);

    return value.toString();
  }
}
