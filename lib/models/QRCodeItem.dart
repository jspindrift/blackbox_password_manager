import 'dart:convert';


class QRCodeItem {
  String name;
  String username;
  String password;

  QRCodeItem({
    required this.name,
    required this.username,
    required this.password,
  });

  factory QRCodeItem.fromRawJson(String str) =>
      QRCodeItem.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory QRCodeItem.fromJson(Map<String, dynamic> json) {
    return QRCodeItem(
      name: json['name'],
      username: json['username'],
      password: json['password'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "name": name,
      "username": username,
      "password": password,
    };
    return jsonMap;
  }

}


class QRCodeKeyItem {
  String key;  // base64 encoded key
  bool symmetric;

  QRCodeKeyItem({
    required this.key,
    required this.symmetric,
  });

  factory QRCodeKeyItem.fromRawJson(String str) =>
      QRCodeKeyItem.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory QRCodeKeyItem.fromJson(Map<String, dynamic> json) {
    return QRCodeKeyItem(
      key: json['key'],
      symmetric: json['symmetric'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "key": key,
      "symmetric": symmetric,
    };
    return jsonMap;
  }

}
