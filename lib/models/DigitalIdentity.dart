import 'dart:convert';

class DigitalIdentity {
  String id;
  int? version;
  String name;
  String pubKeyExchange;
  String pubKeySignature;
  String cdate;
  String mdate;

  DigitalIdentity({
    required this.id,
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


  Map<String, dynamic> toJsonVersion() => {
    "version": version!,
  };


  factory DigitalIdentity.fromJson(Map<String, dynamic> json) {
    return DigitalIdentity(
      id: json["id"],
      version: json["version"] == null ? null : json["version"],
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
      "name": name,
      "pubKeyExchange": pubKeyExchange,
      "pubKeySignature": pubKeySignature,
      "cdate": cdate,
      "mdate": mdate,
    };

    if (version != null) {
      jsonMap.addAll(toJsonVersion());
    }

    return jsonMap;
  }
}
