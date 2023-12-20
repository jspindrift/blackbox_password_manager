import 'dart:convert';


class DigitalIdentityCode {
  String pubKeyExchange; // 32 byte hex // TODO: change to base64
  String pubKeySignature; // 32 byte hex // TODO: change to base64

  DigitalIdentityCode({
    required this.pubKeyExchange,
    required this.pubKeySignature,
  });

  factory DigitalIdentityCode.fromRawJson(String str) =>
      DigitalIdentityCode.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory DigitalIdentityCode.fromJson(Map<String, dynamic> json) {
    return DigitalIdentityCode(
      pubKeyExchange: json['pubKeyExchange'],
      pubKeySignature: json['pubKeySignature'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "pubKeyExchange": pubKeyExchange,
      "pubKeySignature": pubKeySignature,
    };

    return jsonMap;
  }

}
