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
      signature: json['signature'],
      checksum: json['checksum'],
      message: BasicMessageData.fromRawJson(json['message']),
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
  String data;

  BasicMessageData({
    required this.time,
    required this.data,
  });

  factory BasicMessageData.fromRawJson(String str) => BasicMessageData.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory BasicMessageData.fromJson(Map<String, dynamic> json) {
    return BasicMessageData(
      time: json['time'],
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "time": time,
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

// class WOTSOverlappingSignatureChain {
//   List<WOTSOverlappingSignatureItem> blocks; // lamport pub key leaves
//
//   WOTSOverlappingSignatureChain({
//     required this.blocks,
//   });
//
//   factory WOTSOverlappingSignatureChain.fromRawJson(String str) =>
//       WOTSOverlappingSignatureChain.fromJson(json.decode(str));
//
//   String toRawJson() => json.encode(toJson());
//
//   factory WOTSOverlappingSignatureChain.fromJson(Map<String, dynamic> json) {
//     return WOTSOverlappingSignatureChain(
//       blocks: List<WOTSOverlappingSignatureItem>.from(
//           json["blocks"].map((x) => WOTSOverlappingSignatureItem.fromJson(x))),
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


// class WOTSOverlappingSignatureItem {
//   int id;
//   String publicKey;
//   List<String> topJoinLeaves;
//   String topJoinMerkle;
//   List<String> bottomJoinLeaves;
//   String bottomJoinMerkle;
//   List<String> signature; // lamport
//   String checksum;
//   BasicMessageData message; // message structure
//
//   WOTSOverlappingSignatureItem({
//     required this.id,
//     required this.publicKey,
//     required this.topJoinLeaves,
//     required this.topJoinMerkle,
//     required this.bottomJoinLeaves,
//     required this.bottomJoinMerkle,
//     required this.signature,
//     required this.checksum,
//     required this.message, // encrypted
//   });
//
//   factory WOTSOverlappingSignatureItem.fromRawJson(String str) =>
//       WOTSOverlappingSignatureItem.fromJson(json.decode(str));
//
//   String toRawJson() => json.encode(toJson());
//
//   factory WOTSOverlappingSignatureItem.fromJson(Map<String, dynamic> json) {
//     return WOTSOverlappingSignatureItem(
//       id: json['id'],
//       publicKey: json['publicKey'],
//       topJoinLeaves: json['topJoinLeaves'],
//       topJoinMerkle: json['topJoinMerkle'],
//       bottomJoinLeaves: json['bottomJoinLeaves'],
//       bottomJoinMerkle: json['bottomJoinMerkle'],
//       signature: json['signature'],
//       checksum: json['checksum'],
//       message: BasicMessageData.fromRawJson(json['message']),
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     Map<String, dynamic> jsonMap = {
//       "id": id,
//       "publicKey": publicKey,
//       "topJoinLeaves": topJoinLeaves,
//       "topJoinMerkle": topJoinMerkle,
//       "bottomJoinLeaves": bottomJoinLeaves,
//       "bottomJoinMerkle": bottomJoinMerkle,
//       "signature": signature,
//       "checksum": checksum,
//       "message": message,
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