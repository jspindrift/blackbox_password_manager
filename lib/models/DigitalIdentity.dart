import 'dart:convert';


class DigitalIdentity {
  String id;
  String keyId;  // add key identifier to add to items
  int index;  // Index of Shared Secret Recovery Key (can cycle as an HOTP key).
  int version;
  String name;    // encrypted
  String pubKeyExchange;  // encrypted
  String pubKeySignature; // encrypted
  String mac;
  String cdate;
  String mdate;

  DigitalIdentity({
    required this.id,
    required this.keyId,
    required this.index,
    required this.version,
    required this.name,
    required this.pubKeyExchange,
    required this.pubKeySignature,
    required this.mac,
    required this.cdate,
    required this.mdate,
  });

  factory DigitalIdentity.fromRawJson(String str) =>
      DigitalIdentity.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory DigitalIdentity.fromJson(Map<String, dynamic> json) {
    return DigitalIdentity(
      id: json["id"],
      keyId: json["keyId"],
      index: json["index"],
      version: json["version"],
      name: json["name"],
      pubKeyExchange: json[
          "pubKeyExchange"],
      pubKeySignature: json[
          "pubKeySignature"],
      mac: json["mac"],
      cdate: json["cdate"],
      mdate: json["mdate"],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "id": id,
      "keyId": keyId,
      "index": index,
      "version": version,
      "name": name,
      "pubKeyExchange": pubKeyExchange,
      "pubKeySignature": pubKeySignature,
      "mac": mac,
      "cdate": cdate,
      "mdate": mdate,
    };

    return jsonMap;
  }

}
