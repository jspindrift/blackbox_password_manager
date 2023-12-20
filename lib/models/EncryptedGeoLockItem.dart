import 'dart:convert';


/// Item returned from geoEncrypt() function
///
class EncryptedGeoLockItem {
  int? version;
  String iv; // iv used for lat and long position token decryption
  String lat_tokens; // base64 encoded latitude tokens
  String long_tokens; // base64 encoded longitude tokens
  String encryptedPassword;

  EncryptedGeoLockItem({
    required this.iv,
    required this.version,
    required this.lat_tokens,
    required this.long_tokens,
    required this.encryptedPassword,
  });

  factory EncryptedGeoLockItem.fromRawJson(String str) =>
      EncryptedGeoLockItem.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory EncryptedGeoLockItem.fromJson(Map<String, dynamic> json) {
    return EncryptedGeoLockItem(
      iv: json['iv'],
      version: json["version"],
      lat_tokens: json[
          "lat_tokens"],
      long_tokens: json[
          "long_tokens"],
      encryptedPassword: json['encryptedPassword'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "iv": iv,
      "version": version,
      "lat_tokens": lat_tokens,
      "long_tokens": long_tokens,
      "encryptedPassword": encryptedPassword,
    };

    return jsonMap;
  }

}
