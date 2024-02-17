import 'dart:convert';
import 'dart:typed_data';

import 'package:blackbox_password_manager/models/EncryptedPeerMessage.dart';
import 'package:convert/convert.dart';
import 'package:logger/logger.dart';

import '../managers/Cryptor.dart';
import '../merkle/merkle_example.dart';


var logger = Logger(
  printer: PrettyPrinter(),
);

var loggerNoStack = Logger(
  printer: PrettyPrinter(methodCount: 0),
);


enum EncryptionKeyType {
  sym,
  asym,
  unknown,
}

enum EncryptionAlgoType {
  aes_ctr_128,
  aes_ctr_256,
  unknown,
}

enum SigningAlgoType {
  secp256k1,
  secp256r1,
  wots,
  unknown,
}

enum KeyExchangeAlgoType {
  secp256r1,
  x25519,
  unknown,
}

enum KeyPurposeType {
  keygen,
  encryption,
  decryption,
  signing,
  keyexchange,
  unknown,
}


class KeyItem {
  String id;
  String keyId;
  int version;  // add version that signals how to decrypt/manipulate
  String name;
  Keys keys;  // encrypted private key (asym or sym)
  String keyType;
  String purpose;
  String algo;
  bool isBip39;
  bool favorite;
  String notes;
  List<PeerPublicKey> peerPublicKeys; // used for asymmetric keys only
  List<String>? tags;
  String mac;
  String cdate;
  String mdate;

  KeyItem({
    required this.id,
    required this.keyId,
    required this.version,
    required this.name,
    required this.keys,
    required this.keyType,
    required this.purpose,
    required this.algo,
    required this.notes,
    required this.isBip39,
    required this.favorite,
    required this.peerPublicKeys,
    required this.tags,
    required this.mac,
    required this.cdate,
    required this.mdate,
  });

  factory KeyItem.fromRawJson(String str) => KeyItem.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());


  factory KeyItem.fromJson(Map<String, dynamic> json) {
    return KeyItem(
      id: json['id'],
      keyId: json['keyId'],
      version: json["version"],
      name: json['name'],
      keys: Keys.fromJson(json['keys']),
      keyType: json['keyType'],
      purpose: json['purpose'],
      algo: json['algo'],
      isBip39: json['isBip39'],
      favorite: json['favorite'],
      notes: json['notes'],
      tags: json['tags'] == null ? null : List<String>.from(json["tags"]),
      peerPublicKeys: List<PeerPublicKey>.from(
          json["peerPublicKeys"].map((x) => PeerPublicKey.fromJson(x))),
      mac: json['mac'],
      cdate: json['cdate'],
      mdate: json['mdate'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "id": id,
      "keyId": keyId,
      "version": version,
      "name": name,
      "keys": keys,
      "keyType": keyType,
      "purpose": purpose,
      "algo": algo,
      "isBip39": isBip39,
      "favorite": favorite,
      "notes": notes,
      "tags": tags,
      "peerPublicKeys": peerPublicKeys,
      "mac": mac,
      "cdate": cdate,
      "mdate": mdate,
    };

    return jsonMap;
  }

  void calculateFieldHash() {
    // for (var fields in )
    final nameHash = Cryptor().sha256(name);

    final x = keys?.privX ?? "";
    final s = keys?.privS ?? "";
    final k = keys?.privK ?? "";

    final keyHash = Cryptor().sha256(x + k + s);
    final notesHash = Cryptor().sha256(notes);
    // logger.d("nameHash: ${nameHash}\nusernameHash: ${usernameHash}\npasswordHash: ${passwordHash}");


    logger.d("peerPublicKeys toString: ${peerPublicKeys.toString()} ");


    /// TODO: MerkleRoot switch to this
    // final peerPubKeyMerkle = peerPublicKeys.merkleRoot;
    /// TODO: MerkleRoot from this
    final peerPubKeysHash = Cryptor().sha256(peerPublicKeys.toString());

    // logger.d("geoLock toString: ${geoLock.toString()} ");
    // final geoLockHash = Cryptor().sha256(geoLock.toString());
    // logger.d("geoLock Hash: ${geoLockHash} ");

    logger.d("nameHash: ${nameHash}\nkeyHash: ${keyHash}\n"
        "notesHash: ${notesHash}\npeerPubKeysHash: ${peerPubKeysHash}\n");

    final merkleRoot = Cryptor().sha256(nameHash+keyHash+notesHash+peerPubKeysHash);

    /// TODO: MerkleRoot switch to this
    // final merkleRoot = Cryptor().sha256(nameHash+keyHash+notesHash+peerPubKeyMerkle);

    logger.d("merkleRoot: $merkleRoot");
  }

}

/// object containing relevant keys
class Keys {
  String? privX;  /// key exchange
  String? privS;  /// signing
  String? privK;  /// symmetric usage

  Keys({
  required this.privX,
  required this.privS,
  required this.privK,
  });

  factory Keys.fromRawJson(String str) => Keys.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  Map<String, dynamic> toJsonPrivX() => {
    "privX": privX!,
  };

  Map<String, dynamic> toJsonPrivS() => {
    "privS": privS!,
  };

  Map<String, dynamic> toJsonPrivK() => {
    "privK": privK!,
  };

  factory Keys.fromJson(Map<String, dynamic> json) {
    return Keys(
      privX: json['privX'] == null ? null : json['privX'],
      privS: json['privS'] == null ? null : json['privS'],
      privK: json['privK'] == null ? null : json['privK'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      // "privX": privX,
      // "privS": privS,
      // "privK": privK,
    };

    if (privX != null) {
      jsonMap.addAll(toJsonPrivX());
    }

    if (privS != null) {
      jsonMap.addAll(toJsonPrivS());
    }

    if (privK != null) {
      jsonMap.addAll(toJsonPrivK());
    }

    return jsonMap;
  }
}

/// The secret shared key is computed by this vault owner's private key and this
/// peer's public key.  Then this secret key acts as a root key that gets
/// expanded into and encryption and authentication key for Encrypt-then-Mac
/// functionality with encrypting and decrypting messages.
class PeerPublicKey {
  String id;
  int version;
  String name;  // encrypted
  String pubKeyX;  // encrypted Peer Public Key (exchange)
  String pubKeyS;  // encrypted Peer Public Key (signing)
  String notes;  // encrypted
  GenericMessageList? sentMessages;  // encrypted
  GenericMessageList? receivedMessages; // encrypted
  String mdate;
  String cdate;

  PeerPublicKey({
    required this.id,
    required this.version,
    required this.name,
    required this.pubKeyX,
    required this.pubKeyS,
    required this.notes,
    required this.sentMessages,
    required this.receivedMessages,
    required this.mdate,
    required this.cdate,
  });

  factory PeerPublicKey.fromRawJson(String str) => PeerPublicKey.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());


  factory PeerPublicKey.fromJson(Map<String, dynamic> json) {
    return PeerPublicKey(
      id: json['id'],
      version: json["version"],
      name: json['name'],
      pubKeyX: json['pubKeyX'],
      pubKeyS: json['pubKeyS'],
      notes: json['notes'],
      sentMessages: GenericMessageList.fromJson(json["sentMessages"]) == null
          ? null : GenericMessageList.fromJson(json["sentMessages"]),
      receivedMessages: GenericMessageList.fromJson(json["receivedMessages"]) == null
          ? null : GenericMessageList.fromJson(json["receivedMessages"]),
      cdate: json['cdate'],
      mdate: json['mdate'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "id": id,
      "version": version,
      "name": name,
      "pubKeyX": pubKeyX,
      "pubKeyS": pubKeyS,
      "notes": notes,
      "sentMessages": sentMessages,
      "receivedMessages": receivedMessages,
      "cdate": cdate,
      "mdate": mdate,
    };

    return jsonMap;
  }

}


class SecureMessageList {
  List<GenericPeerMessage> list;

  SecureMessageList({
    required this.list,
  });

  factory SecureMessageList.fromRawJson(String str) => SecureMessageList.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory SecureMessageList.fromJson(Map<String, dynamic> json) {
    return SecureMessageList(
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


/// encrypted with key derived from user's shared secret key
class SecureMessage {
  String version; // protocol version for blob
  String data;    // version dependant json encoded string object (SignedMessageDataV1)

  SecureMessage({
    required this.version,
    required this.data,
  });

  factory SecureMessage.fromRawJson(String str) => SecureMessage.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());


  factory SecureMessage.fromJson(Map<String, dynamic> json) {
    return SecureMessage(
      // index: json['index'],
      version: json['version'],
      // to: json['to'],
      // from: json['from'],
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      // "index": index,
      "version": version,
      // "to": to,
      // "from": from,
      "data": data,
    };

    return jsonMap;
  }

  getMessageData() {

  }

}


class SignedMessageDataV1 {
  String protocol;        // signing and encryption protocol
  String signature;       // receiving address
  MessageDataV1 data;     // message data

  SignedMessageDataV1({
    required this.protocol,
    required this.signature,
    required this.data,
  });

  factory SignedMessageDataV1.fromRawJson(String str) => SignedMessageDataV1.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());


  factory SignedMessageDataV1.fromJson(Map<String, dynamic> json) {
    return SignedMessageDataV1(
      protocol: json['protocol'],
      signature: json['signature'],
      data: MessageDataV1.fromRawJson(json['data']),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "protocol": protocol,
      "signature": signature,
      "data": data,
    };

    return jsonMap;
  }
}

class MessageDataV1 {
  int index;      // message index
  String to;      // receiving address
  String from;    // sending address
  String cdate;   // created date
  String message; // message data (eg. [iv + mac + encryptedMessage])

  MessageDataV1({
    required this.index,
    required this.to,
    required this.from,
    required this.cdate,
    required this.message,
  });

  factory MessageDataV1.fromRawJson(String str) => MessageDataV1.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());


  factory MessageDataV1.fromJson(Map<String, dynamic> json) {
    return MessageDataV1(
      index: json['index'],
      to: json['to'],
      from: json['from'],
      cdate: json['cdate'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "index": index,
      "to": to,
      "from": from,
      "cdate": cdate,
      "message": message,
    };

    return jsonMap;
  }

}


