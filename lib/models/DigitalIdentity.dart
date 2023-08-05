import 'dart:convert';

class DigitalIdentity {
  String id;
  int index;  // Index of Shared Secret Recovery Key (can cycle as an HOTP key).
  int version;
  String name;
  String pubKeyExchange;
  String pubKeySignature;
  String cdate;
  String mdate;

  DigitalIdentity({
    required this.id,
    required this.index,
    required this.version,
    required this.name,
    required this.pubKeyExchange,
    required this.pubKeySignature,
    required this.cdate,
    required this.mdate,
  });

  factory DigitalIdentity.fromRawJson(String str) =>
      DigitalIdentity.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory DigitalIdentity.fromJson(Map<String, dynamic> json) {
    return DigitalIdentity(
      id: json["id"],
      index: json["index"],
      version: json["version"],
      name: json["name"],
      pubKeyExchange: json[
          "pubKeyExchange"],
      pubKeySignature: json[
          "pubKeySignature"],
      cdate: json["cdate"],
      mdate: json["mdate"],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "id": id,
      "index": index,
      "version": version,
      "name": name,
      "pubKeyExchange": pubKeyExchange,
      "pubKeySignature": pubKeySignature,
      "cdate": cdate,
      "mdate": mdate,
    };

    return jsonMap;
  }
}
