import 'dart:convert';

class DecryptedGeoLockItem {
  int index_lat;
  int index_long;
  String decryptedPassword;

  DecryptedGeoLockItem({
    required this.index_lat,
    required this.index_long,
    required this.decryptedPassword,
  });

  factory DecryptedGeoLockItem.fromRawJson(String str) =>
      DecryptedGeoLockItem.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory DecryptedGeoLockItem.fromJson(Map<String, dynamic> json) {
    return DecryptedGeoLockItem(
      index_lat: json["index_lat"],
      index_long: json["index_lat"],
      decryptedPassword: json['decryptedPassword'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "index_lat": index_lat,
      "index_long": index_long,
      "decryptedPassword": decryptedPassword,
    };

    return jsonMap;
  }
}
