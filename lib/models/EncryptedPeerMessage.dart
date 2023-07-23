import 'dart:convert';

class EncryptedPeerMessage {
  int version;
  String from;
  String to;
  String message;
  String time;
  String jmac;

  EncryptedPeerMessage({
    required this.version,
    required this.from,
    required this.to,
    required this.message,
    required this.time,
    required this.jmac,
  });

  factory EncryptedPeerMessage.fromRawJson(String str) =>
      EncryptedPeerMessage.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());


  Map<String, dynamic> toJsonVersion() => {
    "version": version!,
  };


  factory EncryptedPeerMessage.fromJson(Map<String, dynamic> json) {
    return EncryptedPeerMessage(
      version: json["version"],
      from: json["from"],
      to: json[
      "to"],
      message: json[
      "message"],
      time: json["time"],
      jmac: json["jmac"],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "version": version,
      "from": from,
      "to": to,
      "message": message,
      "time": time,
      "jmac": jmac,
    };

    return jsonMap;
  }
}
