import 'dart:convert';

class MyDigitalIdentity {
  int version;
  String privKeyExchange;  // used for recovery keys
  String privKeySignature;  // placeholder for signing
  String cdate;
  String mdate;

  MyDigitalIdentity({
    required this.version,
    required this.privKeyExchange,
    required this.privKeySignature,
    required this.cdate,
    required this.mdate,
  });

  factory MyDigitalIdentity.fromRawJson(String str) =>
      MyDigitalIdentity.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory MyDigitalIdentity.fromJson(Map<String, dynamic> json) {
    return MyDigitalIdentity(
      version: json['version'],
      privKeyExchange: json['privKeyExchange'],
      privKeySignature: json['privKeySignature'],
      cdate: json['cdate'],
      mdate: json['mdate'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "version": version,
      "privKeyExchange": privKeyExchange,
      "privKeySignature": privKeySignature,
      "cdate": cdate,
      "mdate": mdate,
    };

    return jsonMap;
  }

}
