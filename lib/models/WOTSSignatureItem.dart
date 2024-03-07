import 'dart:convert';


enum GSecurityLevel {
  basic256,  // basic giga wots signing 256 bits
  basic512,  // basic giga wots signing 512 bits
  luda256,   // ludicrous mode
  luda512,

  unknown
}


enum GProtocol {
  alpha,
  beta,
  gamma,

  unknown
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
  String id;
  String? recovery; // unique identifier for wots chain (static)
  List<String>? signature; /// TODO: turn this into a blob for smaller space
  String? signatureBlock;

  String checksum;
  WOTSMessageData message;

  GigaWOTSSignatureItem({
    required this.id,
    required this.recovery,
    required this.signature,
    required this.signatureBlock,
    required this.checksum,
    required this.message, // encrypted
  });

  factory GigaWOTSSignatureItem.fromRawJson(String str) =>
      GigaWOTSSignatureItem.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  Map<String, dynamic> toJsonRecovery() => {
    "recovery": recovery!,
  };

  Map<String, dynamic> toJsonSignature() => {
    "signature": signature!,
  };

  Map<String, dynamic> toJsonSignatureBlock() => {
    "signatureBlock": signatureBlock!,
  };

  factory GigaWOTSSignatureItem.fromJson(Map<String, dynamic> json) {
    return GigaWOTSSignatureItem(
      id: json['id'],
      recovery: json['recovery'] == null ? null : json['recovery'],
      signature:  json['signature'] == null ? null : List<String>.from(json['signature']),

      signatureBlock: json['signatureBlock'] == null ? null : json['signatureBlock'],

      checksum: json['checksum'],
      message: WOTSMessageData.fromJson(json['message']),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "id": id,
      // "signature": signature,
      "signatureBlock": signatureBlock,
      "checksum": checksum,
      "message": message,
    };

    if (recovery != null) {
      jsonMap.addAll(toJsonRecovery());
    }

    if (signature != null) {
      jsonMap.addAll(toJsonSignature());
    }

    if (signatureBlock != null) {
      jsonMap.addAll(toJsonSignatureBlock());
    }

    return jsonMap;
  }

}


/// Message Layer -----------------------------------
///
///
class GenericMessageList {
  List<GenericMessage> list;

  GenericMessageList({
    required this.list,
  });

  factory GenericMessageList.fromRawJson(String str) => GenericMessageList.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GenericMessageList.fromJson(Map<String, dynamic> json) {
    return GenericMessageList(
      list: List<GenericMessage>.from(
          json["list"].map((x) => GenericMessage.fromJson(x))),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "list": list,
    };

    return jsonMap;
  }

}


class GenericMessage {
  String type;  // message type (opcode)
  String data;  // message type data (EncryptedMessage/OpCodeMessage)

  GenericMessage({
    required this.type,
    required this.data,
  });

  factory GenericMessage.fromRawJson(String str) =>
      GenericMessage.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GenericMessage.fromJson(Map<String, dynamic> json) {
    return GenericMessage(
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


class WOTSMessageData {
  int messageIndex;     // current message/signature number
  String securityLevel;
  String previousHash;  // hash of previous signature block
  String? publicKey;     // current top public key for signature verification
  String nextPublicKey; // next top public key in WOTS key tree
  String? topSignature;     // current signed top public key by asymSigning private key in WOTS key tree
  String? asymSigningPublicKey;  // asymmetric signing key
  String data;          // message data

  WOTSMessageData({
    required this.messageIndex,
    required this.securityLevel,
    required this.previousHash,
    required this.publicKey,
    required this.nextPublicKey,
    required this.topSignature,
    required this.asymSigningPublicKey,
    required this.data,
  });

  factory WOTSMessageData.fromRawJson(String str) => WOTSMessageData.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  Map<String, dynamic> toJsonTopSignature() => {
    "topSignature": topSignature!,
  };

  Map<String, dynamic> toJsonPublicKey() => {
    "publicKey": publicKey!,
  };

  Map<String, dynamic> toJsonAsymSigningPublicKey() => {
    "asymSigningPublicKey": asymSigningPublicKey!,
  };


  factory WOTSMessageData.fromJson(Map<String, dynamic> json) {
    return WOTSMessageData(
      messageIndex: json['messageIndex'],
      securityLevel: json['securityLevel'],
      previousHash: json['previousHash'],
      publicKey: json['publicKey'] == null ? null : json['publicKey'],
      nextPublicKey: json['nextPublicKey'],

      topSignature: json['topSignature'] == null ? null : json['topSignature'],
      // nextTopSignature: json['nextTopSignature'] == null ? null : json['nextTopSignature'],
      asymSigningPublicKey: json['asymSigningPublicKey'] == null ? null : json['asymSigningPublicKey'],
      data: json['data'],

      // data: ProtocolMessage.fromJson(json['data']),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "messageIndex": messageIndex,
      "securityLevel": securityLevel,
      "previousHash": previousHash,
      // "publicKey": publicKey,
      "nextPublicKey": nextPublicKey,
      "data": data,
    };

    if (topSignature != null) {
      jsonMap.addAll(toJsonTopSignature());
    }

    if (publicKey != null) {
      jsonMap.addAll(toJsonPublicKey());
    }

    if (asymSigningPublicKey != null) {
      jsonMap.addAll(toJsonAsymSigningPublicKey());
    }

    return jsonMap;
  }

}


/// same as plain data model but message needs decryption
///
class EncryptedMessage {
  int index;
  String from;
  String to;
  String message;
  String time;
  String mac;

  EncryptedMessage({
    required this.index,
    required this.from,
    required this.to,
    required this.message,
    required this.time,
    required this.mac,
  });

  factory EncryptedMessage.fromRawJson(String str) =>
      EncryptedMessage.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory EncryptedMessage.fromJson(Map<String, dynamic> json) {
    return EncryptedMessage(
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


/// protocols for key change, recovery, etc.
class ProtocolMessage {
  String protocol;  // GigaProtocol type
  String data;      // Protocol data (AlphaProtocolMessage)

  ProtocolMessage({
    required this.protocol,
    required this.data,
  });

  factory ProtocolMessage.fromRawJson(String str) =>
      ProtocolMessage.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory ProtocolMessage.fromJson(Map<String, dynamic> json) {
    return ProtocolMessage(
      data: json["data"],
      protocol: json["protocol"],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "protocol": protocol,
      "data": data,
    };

    return jsonMap;
  }

}


/// (Signing) Key Change Protocol Data Model
class AlphaProtocolMessage {
  String data;

  AlphaProtocolMessage({
    required this.data,
  });

  factory AlphaProtocolMessage.fromRawJson(String str) =>
      AlphaProtocolMessage.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory AlphaProtocolMessage.fromJson(Map<String, dynamic> json) {
    return AlphaProtocolMessage(
      data: json["data"],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "data": data,
    };

    return jsonMap;
  }

}

/// Recovery Protocol Data Model
class BetaProtocolMessage {
  String data;

  BetaProtocolMessage({
    required this.data,
  });

  factory BetaProtocolMessage.fromRawJson(String str) =>
      BetaProtocolMessage.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory BetaProtocolMessage.fromJson(Map<String, dynamic> json) {
    return BetaProtocolMessage(
      data: json["data"],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "data": data,
    };

    return jsonMap;
  }

}
