import 'dart:convert';

class PinCodeItem {
  String id;
  int version;
  int attempts;
  String salt;
  int rounds;
  String keyMaterial;
  String cdate;

  PinCodeItem({
    required this.id,
    required this.version,
    required this.attempts,
    required this.rounds,
    required this.salt,
    required this.keyMaterial,
    required this.cdate,
  });

  factory PinCodeItem.fromRawJson(String str) =>
      PinCodeItem.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory PinCodeItem.fromJson(Map<String, dynamic> json) {
    return PinCodeItem(
      id: json['id'],
      version: json["version"],
      attempts: json['attempts'],
      rounds: json['rounds'],
      salt: json['salt'],
      keyMaterial: json['keyMaterial'],
      cdate: json['cdate'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "id": id,
      "version": version,
      "attempts": attempts,
      "rounds": rounds,
      "salt": salt,
      "keyMaterial": keyMaterial,
      "cdate": cdate,
    };
    return jsonMap;
  }

}
