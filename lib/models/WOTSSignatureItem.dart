import 'dart:convert';


class WOTSBasicSignatureChain {
  List<WOTSBasicSignatureItem> blocks;

  WOTSBasicSignatureChain({
    required this.blocks,
  });

  factory WOTSBasicSignatureChain.fromRawJson(String str) =>
      WOTSBasicSignatureChain.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory WOTSBasicSignatureChain.fromJson(Map<String, dynamic> json) {
    return WOTSBasicSignatureChain(
      blocks: List<WOTSBasicSignatureItem>.from(
          json["blocks"].map((x) => WOTSBasicSignatureItem.fromJson(x))),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "blocks": blocks,
    };

    return jsonMap;
  }
}

class WOTSBasicSignatureItem {
  int id;
  String publicKey;
  List<String> signature;
  String checksum;
  BasicMessageData message;

  WOTSBasicSignatureItem({
    required this.id,
    required this.publicKey,
    required this.signature,
    required this.checksum,
    required this.message,
  });

  factory WOTSBasicSignatureItem.fromRawJson(String str) =>
      WOTSBasicSignatureItem.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory WOTSBasicSignatureItem.fromJson(Map<String, dynamic> json) {
    return WOTSBasicSignatureItem(
      id: json['id'],
      publicKey: json['publicKey'],
      signature: List<String>.from(json["signature"]),
      checksum: json['checksum'],
      message: BasicMessageData.fromJson(json['message']),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "id": id,
      "publicKey": publicKey,
      "signature": signature,
      "checksum": checksum,
      "message": message,
    };

    return jsonMap;
  }
}

class BasicMessageData {
  String time;
  String message;
  String signature;

  BasicMessageData({
    required this.time,
    required this.message,
    required this.signature,
  });

  factory BasicMessageData.fromRawJson(String str) => BasicMessageData.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory BasicMessageData.fromJson(Map<String, dynamic> json) {
    return BasicMessageData(
      time: json['time'],
      message: json['message'],
      signature: json['signature'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "time": time,
      "message": message,
      "signature": signature,
    };

    return jsonMap;
  }
}

class AddressableMessageData {
  String time;
  String sender;
  String reciever;
  String data;

  AddressableMessageData({
    required this.time,
    required this.sender,
    required this.reciever,
    required this.data,
  });

  factory AddressableMessageData.fromRawJson(String str) => AddressableMessageData.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory AddressableMessageData.fromJson(Map<String, dynamic> json) {
    return AddressableMessageData(
      time: json['time'],
      sender: json['sender'],
      reciever: json['reciever'],
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "time": time,
      "sender": sender,
      "reciever": reciever,
      "data": data,
    };

    return jsonMap;
  }
}


class GigaWOTSSignatureDictionary {
  List<GigaWOTSSignatureChain> chains;

  GigaWOTSSignatureDictionary({
    required this.chains,
  });

  factory GigaWOTSSignatureDictionary.fromRawJson(String str) =>
      GigaWOTSSignatureDictionary.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GigaWOTSSignatureDictionary.fromJson(Map<String, dynamic> json) {
    return GigaWOTSSignatureDictionary(
      chains: List<GigaWOTSSignatureChain>.from(
          json["chains"].map((x) => GigaWOTSSignatureChain.fromJson(x))),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "chains": chains,
    };

    return jsonMap;
  }
}

class GigaWOTSSignatureChain {
  String chainId;
  List<GigaWOTSSignatureItem> blocks;

  GigaWOTSSignatureChain({
    required this.chainId,
    required this.blocks,
  });

  factory GigaWOTSSignatureChain.fromRawJson(String str) =>
      GigaWOTSSignatureChain.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GigaWOTSSignatureChain.fromJson(Map<String, dynamic> json) {
    return GigaWOTSSignatureChain(
        chainId: json['chainId'],
      blocks: List<GigaWOTSSignatureItem>.from(
          json["blocks"].map((x) => GigaWOTSSignatureItem.fromJson(x))),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "chainId": chainId,
      "blocks": blocks,
    };

    return jsonMap;
  }
}

/// WOTS signature that contains the next public key
class GigaWOTSSignatureItem {
  String id;   // unique identifier for wots chain (static)
  List<String> signature;
  WOTSMessageData message;

  GigaWOTSSignatureItem({
    required this.id,
    required this.signature,
    required this.message, // encrypted
  });

  factory GigaWOTSSignatureItem.fromRawJson(String str) =>
      GigaWOTSSignatureItem.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GigaWOTSSignatureItem.fromJson(Map<String, dynamic> json) {
    return GigaWOTSSignatureItem(
      id: json['id'],
      signature: List<String>.from(json['signature']),
      message: WOTSMessageData.fromJson(json['message']),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "id": id,
      "signature": signature,
      "message": message,
    };

    return jsonMap;
  }
}


class WOTSMessageData {
  int messageIndex;     // current message/signature number
  String previousHash;  // hash of previous signature block
  String publicKey;     // current top public key for signature verification
  String nextPublicKey; // next top public key in WOTS key tree
  String time;          // creation timestamp
  String data;          // message data

  WOTSMessageData({
    required this.messageIndex,
    required this.previousHash,
    required this.publicKey,
    required this.nextPublicKey,
    required this.time,
    required this.data,
  });

  factory WOTSMessageData.fromRawJson(String str) => WOTSMessageData.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory WOTSMessageData.fromJson(Map<String, dynamic> json) {
    return WOTSMessageData(
      messageIndex: json['messageIndex'],
      previousHash: json['previousHash'],
      publicKey: json['publicKey'],
      nextPublicKey: json['nextPublicKey'],
      time: json['time'],
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "messageIndex": messageIndex,
      "previousHash": previousHash,
      "publicKey": publicKey,
      "nextPublicKey": nextPublicKey,
      "time": time,
      "data": data,
    };

    return jsonMap;
  }
}

// class SignatureAsym {
//   String r;
//   String s;
//
//   SignatureAsym({
//     required this.r,
//     required this.s,
//   });
//
//   factory SignatureAsym.fromRawJson(String str) => SignatureAsym.fromJson(json.decode(str));
//
//   String toRawJson() => json.encode(toJson());
//
//   factory SignatureAsym.fromJson(Map<String, dynamic> json) {
//     return SignatureAsym(
//       r: json["r"],
//       s: json["s"],
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     Map<String, dynamic> jsonMap = {
//       "r": r,
//       "s": s,
//     };
//
//     return jsonMap;
//   }
//
// }