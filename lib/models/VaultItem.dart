import 'dart:convert';
import 'DigitalIdentity.dart';
import 'MyDigitalIdentity.dart';

enum KDFAlgorithm {
  pbkdf2_256,
  pbkdf2_512,
  argon2,
  unknown,
}

enum EncryptionAlgorithm {
  aes_ctr_256,
  unknown,
}

class EncryptedKey {
  String derivationAlgorithm;
  String? salt;
  int rounds;
  int type;
  int version;
  int memoryPowerOf2;
  String encryptionAlgorithm;
  String keyMaterial;
  String keyNonce; // encrypted nonce that tracks number of encrypted blocks

  EncryptedKey({
    required this.derivationAlgorithm,
    required this.salt,
    required this.rounds,
    required this.type,
    required this.version,
    required this.memoryPowerOf2,
    required this.encryptionAlgorithm,
    required this.keyMaterial,
    required this.keyNonce,
  });

  factory EncryptedKey.fromRawJson(String str) =>
      EncryptedKey.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory EncryptedKey.fromJson(Map<String, dynamic> json) {
    return EncryptedKey(
      derivationAlgorithm: json['derivationAlgorithm'],
      salt: json['salt'],
      rounds: json['rounds'],
      type: json['type'],// ?? 0,
      version: json['version'],// ?? 0,
      memoryPowerOf2: json['memoryPowerOf2'] ?? 0,
      encryptionAlgorithm: json['encryptionAlgorithm'],
      keyMaterial: json['keyMaterial'],
      keyNonce: json['keyNonce'],
      // blocksEncrypted: json['blocksEncrypted'] ?? 0,
      // blockRolloverCount: json['blockRolloverCount'] ?? 0,
      // keyIndex: json['keyIndex'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "derivationAlgorithm": derivationAlgorithm,
      "salt": salt,
      "rounds": rounds,
      "type": type,
      "version": version,
      "memoryPowerOf2": memoryPowerOf2,
      "encryptionAlgorithm": encryptionAlgorithm,
      "keyMaterial": keyMaterial,
      "keyNonce": keyNonce,
    };

    // if (blocksEncrypted != null) {
    //   jsonMap.addAll(toJsonBlocksEncrypted());
    // }
    //
    // if (blockRolloverCount != null) {
    //   jsonMap.addAll(toJsonBlockRolloverCount());
    // }

    return jsonMap;
  }
}


class VaultItem {
  String id;
  String version;
  String name;
  String deviceId;
  String? deviceData;
  EncryptedKey encryptedKey;
  List<RecoveryKey>?
      recoveryKeys; // encrypted master keys with recovery keys from identities
  MyDigitalIdentity? myIdentity; // my key pairs info - encrypted
  int numItems;
  String blob; // encrypted GenericItemList JSON string base64 encoded
  List<DigitalIdentity>? identities; // social public keys - encrypted
  String cdate;
  String mdate;

  VaultItem({
    required this.id,
    required this.version,
    required this.name,
    required this.deviceId,
    required this.deviceData,
    required this.encryptedKey,
    required this.myIdentity,
    required this.identities,
    required this.recoveryKeys,
    required this.numItems,
    required this.blob,
    required this.cdate,
    required this.mdate,
  });

  factory VaultItem.fromRawJson(String str) =>
      VaultItem.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());


  Map<String, dynamic> toJsonIdentities() => {
        "identities": identities!,
      };

  Map<String, dynamic> toJsonMyDigitalIdentity() => {
        "myIdentity": myIdentity!.toJson(),
      };

  Map<String, dynamic> toJsonRecoveryKeys() => {
        "recoveryKeys": recoveryKeys!,
      };

  Map<String, dynamic> toJsonDeviceData() => {
    "deviceData": deviceData!,
  };

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: json['id'],
      version: json['version'],
      name: json['name'],
      deviceId: json['deviceId'],
        deviceData: json["deviceData"] ?? "",
      encryptedKey: EncryptedKey.fromJson(json['encryptedKey']),
      myIdentity: json["myIdentity"] == null
          ? null
          : MyDigitalIdentity.fromJson(json["myIdentity"]),
      identities: json["identities"] == null
          ? null
          : List<DigitalIdentity>.from(
              json["identities"].map((x) => DigitalIdentity.fromJson(x))),
      recoveryKeys: json["recoveryKeys"] == null
          ? null
          : List<RecoveryKey>.from(
              json["recoveryKeys"].map((x) => RecoveryKey.fromJson(x))),
      numItems: json['numItems'],
      blob: json['blob'],
      cdate: json['cdate'],
      mdate: json['mdate'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "id": id,
      "name": name,
      "version": version,
      "deviceId": deviceId,
      // "deviceData": deviceData,
      "encryptedKey": encryptedKey,
      "numItems": numItems,
      "blob": blob,
      "cdate": cdate,
      "mdate": mdate,
    };

    if (myIdentity != null) {
      jsonMap.addAll(toJsonMyDigitalIdentity());
    }

    if (identities != null) {
      jsonMap.addAll(toJsonIdentities());
    }

    if (recoveryKeys != null) {
      jsonMap.addAll(toJsonRecoveryKeys());
    }

    if (deviceData != null) {
      jsonMap.addAll(toJsonDeviceData());
    }

    return jsonMap;
  }

}

class RecoveryKey {
  String id;  // pubKeyHash (hash of peer's public key)
  String data; // encrypted root vault key using the indexed shared secret key
  String cdate;

  RecoveryKey({
    required this.id,
    required this.data,
    required this.cdate,
  });

  factory RecoveryKey.fromRawJson(String str) =>
      RecoveryKey.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory RecoveryKey.fromJson(Map<String, dynamic> json) {
    return RecoveryKey(
      id: json['id'],
      data: json['data'],
      cdate: json['cdate'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "id": id,
      "data": data,
      "cdate": cdate,
    };

    return jsonMap;
  }

}
