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

class AdressableMessageData {
  String time;
  String sender;
  String reciever;
  String data;

  AdressableMessageData({
    required this.time,
    required this.sender,
    required this.reciever,
    required this.data,
  });

  factory AdressableMessageData.fromRawJson(String str) => AdressableMessageData.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory AdressableMessageData.fromJson(Map<String, dynamic> json) {
    return AdressableMessageData(
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


// class WOTSSignatureChain {
//   List<WOTSSignatureItem> blocks; // lamport pub key leaves
//
//   WOTSSignatureChain({
//     required this.blocks,
//   });
//
//   factory WOTSSignatureChain.fromRawJson(String str) =>
//       WOTSSignatureChain.fromJson(json.decode(str));
//
//   String toRawJson() => json.encode(toJson());
//
//   factory WOTSSignatureChain.fromJson(Map<String, dynamic> json) {
//     return WOTSSignatureChain(
//       blocks: List<WOTSSignatureItem>.from(
//           json["blocks"].map((x) => WOTSSignatureItem.fromJson(x))),
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     Map<String, dynamic> jsonMap = {
//       "blocks": blocks,
//     };
//
//     return jsonMap;
//   }
// }

// class WOTSSignatureItem {
//   int id;
//   String publicKey;
//   List<String> signature;
//   String checksum;
//   MessageData message;
//
//   WOTSSignatureItem({
//     required this.id,
//     required this.publicKey,
//     required this.signature,
//     required this.checksum,
//     required this.message,
//   });
//
//   factory WOTSSignatureItem.fromRawJson(String str) =>
//       WOTSSignatureItem.fromJson(json.decode(str));
//
//   String toRawJson() => json.encode(toJson());
//
//   factory WOTSSignatureItem.fromJson(Map<String, dynamic> json) {
//     return WOTSSignatureItem(
//       id: json['id'],
//       publicKey: json['publicKey'],
//       signature: json['signature'],
//       checksum: json['checksum'],
//       message: MessageData.fromRawJson(json['message']),
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     Map<String, dynamic> jsonMap = {
//       "id": id,
//       "publicKey": publicKey,
//       "signature": signature,
//       "checksum": checksum,
//       "message": message,
//     };
//
//     return jsonMap;
//   }
// }

// class MessageData {
//   String time;
//   String prevHash;
//   String nextTopPubHash;
//   String data;
//
//   MessageData({
//     required this.time,
//     required this.prevHash,
//     required this.nextTopPubHash,
//     required this.data,
//   });
//
//   factory MessageData.fromRawJson(String str) => MessageData.fromJson(json.decode(str));
//
//   String toRawJson() => json.encode(toJson());
//
//   factory MessageData.fromJson(Map<String, dynamic> json) {
//     return MessageData(
//       time: json['time'],
//       prevHash: json['prevHash'],
//       nextTopPubHash: json['nextTopPubHash'],
//       data: json['data'],
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     Map<String, dynamic> jsonMap = {
//       "time": time,
//       "prevHash": prevHash,
//       "nextTopPubHash": nextTopPubHash,
//       "data": data,
//     };
//
//     return jsonMap;
//   }
// }


class WOTSOverlapSignatureChain {
  List<WOTSOverlapSignatureItem> blocks;

  WOTSOverlapSignatureChain({
    required this.blocks,
  });

  factory WOTSOverlapSignatureChain.fromRawJson(String str) =>
      WOTSOverlapSignatureChain.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory WOTSOverlapSignatureChain.fromJson(Map<String, dynamic> json) {
    return WOTSOverlapSignatureChain(
      blocks: List<WOTSOverlapSignatureItem>.from(
          json["blocks"].map((x) => WOTSOverlapSignatureItem.fromJson(x))),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "blocks": blocks,
    };

    return jsonMap;
  }
}


class WOTSOverlapSignatureItem {
  int id;
  String publicKey;
  List<String> topLeaves;
  String topMerkle;
  List<String> bottomLeaves;
  String bottomMerkle;
  List<String> signature;
  String checksum;
  BasicMessageData message;

  WOTSOverlapSignatureItem({
    required this.id,
    required this.publicKey,
    required this.topLeaves,
    required this.topMerkle,
    required this.bottomLeaves,
    required this.bottomMerkle,
    required this.signature,
    required this.checksum,
    required this.message, // encrypted
  });

  factory WOTSOverlapSignatureItem.fromRawJson(String str) =>
      WOTSOverlapSignatureItem.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory WOTSOverlapSignatureItem.fromJson(Map<String, dynamic> json) {
    return WOTSOverlapSignatureItem(
      id: json['id'],
      publicKey: json['publicKey'],
      topLeaves: json['topLeaves'],
      topMerkle: json['topMerkle'],
      bottomLeaves: json['bottomLeaves'],
      bottomMerkle: json['bottomMerkle'],
      signature: json['signature'],
      checksum: json['checksum'],
      message: BasicMessageData.fromRawJson(json['message']),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "id": id,
      "publicKey": publicKey,
      "topLeaves": topLeaves,
      "topMerkle": topMerkle,
      "bottomLeaves": bottomLeaves,
      "bottomMerkle": bottomMerkle,
      "signature": signature,
      "checksum": checksum,
      "message": message,
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