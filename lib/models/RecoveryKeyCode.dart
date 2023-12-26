import 'dart:convert';


/// TODO: For Recovery Key Scanning
class RecoveryKeyCode {
  String id; // 32 byte hash of pub key exchange, change to base64
  String keyId; // id of associated vault root key
  String key; // 32 byte hex data, change to base64

  RecoveryKeyCode({
    required this.id,
    required this.keyId,
    required this.key,
  });

  factory RecoveryKeyCode.fromRawJson(String str) =>
      RecoveryKeyCode.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory RecoveryKeyCode.fromJson(Map<String, dynamic> json) {
    return RecoveryKeyCode(
      id: json['id'],
      keyId: json['keyId'],
      key: json['key'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "id": id,
      "keyId": keyId,
      "key": key,
    };

    return jsonMap;
  }

}
