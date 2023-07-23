import 'dart:convert';

class SecretSalt {
  String vaultId;
  String salt;

  SecretSalt({
    required this.vaultId,
    required this.salt,
  });

  factory SecretSalt.fromRawJson(String str) =>
      SecretSalt.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory SecretSalt.fromJson(Map<String, dynamic> json) {
    return SecretSalt(
      vaultId: json['vaultId'],
      salt: json['salt'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "vaultId": vaultId,
      "salt": salt,
    };
    return jsonMap;
  }
}
