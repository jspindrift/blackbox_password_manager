import 'dart:convert';
import 'dart:typed_data';
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

///TODO: add this item in
class KeyItem {
  String id;
  String keyId;
  int version;  // add version that signals how to decrypt/manipulate
  String name;
  String key;  // encrypted private key (asym or sym)
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
    required this.key,
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
      key: json['key'],
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
      "key": key,
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
    final keyHash = Cryptor().sha256(key);
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

/// The secret shared key is computed by this vault owner's private key and this
/// peer's public key.  Then this secret key acts as a root key that gets
/// expanded into and encryption and authentication key for Encrypt-then-Mac
/// functionality with encrypting and decrypting messages.
class PeerPublicKey {
  String id;
  int? version;
  String name;  // encrypted
  String key;  // encrypted
  String notes;  // encrypted
  SecureMessageList sentMessages;  // encrypted
  SecureMessageList receivedMessages; // encrypted
  String mdate;
  String cdate;

  PeerPublicKey({
    required this.id,
    required this.version,
    required this.name,
    required this.key,
    required this.notes,
    required this.sentMessages,
    required this.receivedMessages,

    required this.mdate,
    required this.cdate,
  });

  factory PeerPublicKey.fromRawJson(String str) => PeerPublicKey.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  Map<String, dynamic> toJsonVersion() => {
    "version": version!,
  };


  factory PeerPublicKey.fromJson(Map<String, dynamic> json) {
    return PeerPublicKey(
      id: json['id'],
      version: json['version'] == null ? null : json["version"],
      name: json['name'],
      key: json['key'],
      notes: json['notes'],
      sentMessages: SecureMessageList.fromJson(json["sentMessages"]),
      receivedMessages: SecureMessageList.fromJson(json["receivedMessages"]),
      cdate: json['cdate'],
      mdate: json['mdate'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "id": id,
      "name": name,
      "key": key,
      "notes": notes,
      "sentMessages": sentMessages,
      "receivedMessages": receivedMessages,
      "cdate": cdate,
      "mdate": mdate,
    };

    if (version != null) {
      jsonMap.addAll(toJsonVersion());
    }

    return jsonMap;
  }

}

class SecureMessageList {
  List<SecureMessage> list;
  List<String> merkleTree;

  SecureMessageList({
    required this.list,
    required this.merkleTree,
  });

  factory SecureMessageList.fromRawJson(String str) => SecureMessageList.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory SecureMessageList.fromJson(Map<String, dynamic> json) {
    return SecureMessageList(
      list: List<SecureMessage>.from(
          json["list"].map((x) => SecureMessage.fromJson(x))),
      merkleTree: List<String>.from(json["list"]),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "list": list,
      "merkleTree": merkleTree,
    };

    return jsonMap;
  }

  /// TODO: merkle root
  ///
  ///
  Future<List<String>> calculateMerkleRoot() async {
    logger.d("calculateMerkleRoot: SecureMessageList");

    // var msgHashList = "";
    List<Uint8List> data = [];

    for (var message in list) {
      final msgHashList = await Cryptor().hmac256(message.cdate + message.iv + message.blob);
      data.add(Uint8List.fromList(hex.decode(msgHashList)));

    }
    // logger.d("msgHashList: $msgHashList");

    final tree = getTree(data);
    /// TODO: set this
    merkleTree = tree;
    logger.d("tree: $tree");

    return tree;
  }

  Future<bool> calculateMerkleRootCheck(List<String> treeToCheck) async {
    logger.d("calculateMerkleRootCheck: SecureMessageList");

    // var msgHashList = "";
    List<Uint8List> data = [];

    for (var message in list) {
      final msgHashList = await Cryptor().hmac256(message.cdate + message.iv + message.blob);
      data.add(Uint8List.fromList(hex.decode(msgHashList)));
    }
    // logger.d("msgHashList: $msgHashList");

    final localTree = getTree(data);

    int index = 0;
    for (var leaf in localTree) {
      if (leaf != treeToCheck[index]) {
        logger.e("merkleRoot failed at index: $index\n leaf: $leaf");
        return false;
      }
      index += 1;
    }

    logger.d("merkleTree is valid: $treeToCheck");

    return true;
  }

}

/// encrypted with key derived from user's shared secret key
class SecureMessage {
  String iv;  // used as message id, as we should never repeat these
  String blob; // mac + encryptedMessage
  String cdate;

  SecureMessage({
    required this.iv,
    required this.blob,
    required this.cdate,
  });

  factory SecureMessage.fromRawJson(String str) => SecureMessage.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());


  factory SecureMessage.fromJson(Map<String, dynamic> json) {
    return SecureMessage(
      iv: json['iv'],
      blob: json['blob'],
      cdate: json['cdate'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "iv": iv,
      "blob": blob,
      // "key": key,
      "cdate": cdate,
    };

    return jsonMap;
  }
}
