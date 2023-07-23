import 'package:cryptography/cryptography.dart';
import 'dart:convert';

class Digester {
  static final Digester _shared = Digester._internal();

  factory Digester() {
    return _shared;
  }

  Digester._internal();

  Future<List<int>> hmac(String message, String key) async {
    // print('hashing: $message');
    var msgInBytes = utf8.encode(message);

    final secretKey = SecretKey(utf8.encode(key));

    final hmac = Hmac.sha256();
    final mac = await hmac.calculateMac(
      msgInBytes,
      secretKey: secretKey,
    );
    // print('mac digest toString: ${mac.toString()}');
    // print('mac bytes: ${mac.bytes}');

    return mac.bytes;
  }
}
