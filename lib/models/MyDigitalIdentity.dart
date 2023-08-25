import 'dart:convert';

class MyDigitalIdentity {
  String keyId;  // root key identifier
  int version;
  String privKeyExchange;  // used for recovery keys
  String privKeySignature;  // placeholder for signing
  String mac;
  String cdate;
  String mdate;

  MyDigitalIdentity({
    required this.keyId,
    required this.version,
    required this.privKeyExchange,
    required this.privKeySignature,
    required this.mac,
    required this.cdate,
    required this.mdate,
  });

  factory MyDigitalIdentity.fromRawJson(String str) =>
      MyDigitalIdentity.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory MyDigitalIdentity.fromJson(Map<String, dynamic> json) {
    return MyDigitalIdentity(
      keyId: json['keyId'],
      version: json['version'],
      privKeyExchange: json['privKeyExchange'],
      privKeySignature: json['privKeySignature'],
      mac: json['mac'],
      cdate: json['cdate'],
      mdate: json['mdate'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "keyId": keyId,
      "version": version,
      "privKeyExchange": privKeyExchange,
      "privKeySignature": privKeySignature,
      "mac": mac,
      "cdate": cdate,
      "mdate": mdate,
    };

    return jsonMap;
  }

}
