import 'dart:convert';

enum MessageType {
  plain,

  encrypted,
  encryptedMesh,

  wotsPlain,
  wotsEncrypted,
  wotsEncryptedMesh,

  unknown;

  String toJson() => name;
  static MessageType fromJson(String json) => values.byName(json);
}

class GenericMessageList {
  List<GenericPeerMessage> list;

  GenericMessageList({
    required this.list,
  });

  factory GenericMessageList.fromRawJson(String str) => GenericMessageList.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GenericMessageList.fromJson(Map<String, dynamic> json) {
    return GenericMessageList(
      list: List<GenericPeerMessage>.from(
          json["list"].map((x) => GenericPeerMessage.fromJson(x))),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "list": list,
    };

    return jsonMap;
  }

}

class GenericPeerMessage {
  // MessageType type;
  String type;
  String data;

  GenericPeerMessage({
    required this.type,
    required this.data,
  });

  factory GenericPeerMessage.fromRawJson(String str) =>
      GenericPeerMessage.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GenericPeerMessage.fromJson(Map<String, dynamic> json) {
    return GenericPeerMessage(
      type: json["type"],
      data: json["data"],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "type": type,
      "data": data,
    };

    return jsonMap;
  }

}


class PlaintextPeerMessage {
  int index;
  String from;
  String to;
  String message;
  String time;
  String mac;

  PlaintextPeerMessage({
    required this.index,
    required this.from,
    required this.to,
    required this.message,
    required this.time,
    required this.mac,
  });

  factory PlaintextPeerMessage.fromRawJson(String str) =>
      PlaintextPeerMessage.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory PlaintextPeerMessage.fromJson(Map<String, dynamic> json) {
    return PlaintextPeerMessage(
      index: json["index"],
      from: json["from"],
      to: json["to"],
      message: json["message"],
      time: json["time"],
      mac: json["mac"],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "index": index,
      "from": from,
      "to": to,
      "message": message,
      "time": time,
      "mac": mac,
    };

    return jsonMap;
  }

}


/// same as plain data model but message needs decryption
///
class EncryptedPeerMessage {
  int index;
  String from;
  String to;
  String message;
  String time;
  String mac;

  EncryptedPeerMessage({
    required this.index,
    required this.from,
    required this.to,
    required this.message,
    required this.time,
    required this.mac,
  });

  factory EncryptedPeerMessage.fromRawJson(String str) =>
      EncryptedPeerMessage.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory EncryptedPeerMessage.fromJson(Map<String, dynamic> json) {
    return EncryptedPeerMessage(
      index: json["index"],
      from: json["from"],
      to: json["to"],
      message: json["message"],
      time: json["time"],
      mac: json["mac"],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "index": index,
      "from": from,
      "to": to,
      "message": message,
      "time": time,
      "mac": mac,
    };

    return jsonMap;
  }

}

/// same as encrypted peer message but includes last know state of peer
///
class EncryptedMeshPeerMessage {
  int index;
  String sstate;  // the hash of the receiver's last sent message
  String rstate;  // the hash of the receiver's last sent message
  String from;
  String to;
  String message;
  String time;
  String mac;

  EncryptedMeshPeerMessage({
    required this.index,
    required this.sstate,
    required this.rstate,
    required this.from,
    required this.to,
    required this.message,
    required this.time,
    required this.mac,
  });

  factory EncryptedMeshPeerMessage.fromRawJson(String str) =>
      EncryptedMeshPeerMessage.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory EncryptedMeshPeerMessage.fromJson(Map<String, dynamic> json) {
    return EncryptedMeshPeerMessage(
      index: json["index"],
      sstate: json["sstate"],
      rstate: json["rstate"],
      from: json["from"],
      to: json["to"],
      message: json["message"],
      time: json["time"],
      mac: json["mac"],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "index": index,
      "sstate": sstate,
      "rstate": rstate,
      "from": from,
      "to": to,
      "message": message,
      "time": time,
      "mac": mac,
    };

    return jsonMap;
  }

}


/// Included in a wots signature where sstate is previous hash in signature
///
class EncryptedWotsMeshPeerMessage {
  int index;
  // String sstate;  // the hash of the receiver's last sent message
  String rstate;  // the hash of the receiver's last sent message
  String from;
  String to;
  String message;
  String time;
  String mac;

  EncryptedWotsMeshPeerMessage({
    required this.index,
    // required this.sstate,
    required this.rstate,
    required this.from,
    required this.to,
    required this.message,
    required this.time,
    required this.mac,
  });

  factory EncryptedWotsMeshPeerMessage.fromRawJson(String str) =>
      EncryptedWotsMeshPeerMessage.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory EncryptedWotsMeshPeerMessage.fromJson(Map<String, dynamic> json) {
    return EncryptedWotsMeshPeerMessage(
      index: json["index"],
      // sstate: json["sstate"],
      rstate: json["rstate"],
      from: json["from"],
      to: json["to"],
      message: json["message"],
      time: json["time"],
      mac: json["mac"],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "index": index,
      // "sstate": sstate,
      "rstate": rstate,
      "from": from,
      "to": to,
      "message": message,
      "time": time,
      "mac": mac,
    };

    return jsonMap;
  }

}
