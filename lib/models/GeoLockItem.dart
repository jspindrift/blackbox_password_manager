import 'dart:convert';

class GeoLockItem {
  String iv; // iv used for lat and long position token decryption
  String lat_tokens; // base64 encoded latitude tokens
  String long_tokens; // base64 encoded longitude tokens
  String password; // encrypted and bse64 encoded

  GeoLockItem({
    required this.iv,
    required this.lat_tokens,
    required this.long_tokens,
    required this.password,
  });

  factory GeoLockItem.fromRawJson(String str) =>
      GeoLockItem.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GeoLockItem.fromJson(Map<String, dynamic> json) {
    return GeoLockItem(
      iv: json['iv'],
      lat_tokens: json[
          "lat_tokens"],
      long_tokens: json[
          "long_tokens"],
      password: json['password'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "iv": iv,
      "lat_tokens": lat_tokens,
      "long_tokens": long_tokens,
      "password": password,
    };

    return jsonMap;
  }
}
