import 'dart:convert';


class QRCodeEncryptedMessageItem {
  String keyId;  // public key hash
  String message;  // encrypted message

  QRCodeEncryptedMessageItem({
    required this.keyId,
    required this.message,
  });

  factory QRCodeEncryptedMessageItem.fromRawJson(String str) =>
      QRCodeEncryptedMessageItem.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory QRCodeEncryptedMessageItem.fromJson(Map<String, dynamic> json) {
    return QRCodeEncryptedMessageItem(
      keyId: json['keyId'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "keyId": keyId,
      "message": message,
    };
    return jsonMap;
  }

}

