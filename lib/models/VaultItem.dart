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

/// keyId tracts the underlying key to point to items encrypted under the key
/// keyId should change for vault after re-keying
class EncryptedKey {
  String keyId;  // root key identifier
  String derivationAlgorithm; // pbkdf2 or argon2
  String? salt; // salt for derivation
  int rounds; // derivation rounds
  int type;   // placeholder
  int version;  // argon2 or placeholder
  int memoryPowerOf2; // argon2 data
  String encryptionAlgorithm; // encryption algo used on master root key
  String keyMaterial; // master root key data
  String keyNonce; // encrypted nonce that tracks number of encrypted blocks used by master encryption key
  // String mac;  // mac of data model with empty mac string (using own auth key)

  EncryptedKey({
    required this.keyId,
    required this.derivationAlgorithm,
    required this.salt,
    required this.rounds,
    required this.type,
    required this.version,
    required this.memoryPowerOf2,
    required this.encryptionAlgorithm,
    required this.keyMaterial,
    required this.keyNonce,
    // required this.mac,
  });

  factory EncryptedKey.fromRawJson(String str) =>
      EncryptedKey.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory EncryptedKey.fromJson(Map<String, dynamic> json) {
    return EncryptedKey(
      keyId: json['keyId'],
      derivationAlgorithm: json['derivationAlgorithm'],
      salt: json['salt'],
      rounds: json['rounds'],
      type: json['type'],
      version: json['version'],
      memoryPowerOf2: json['memoryPowerOf2'] ?? 0,
      encryptionAlgorithm: json['encryptionAlgorithm'],
      keyMaterial: json['keyMaterial'],
      keyNonce: json['keyNonce'],
      // mac: json['mac'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "keyId": keyId,
      "derivationAlgorithm": derivationAlgorithm,
      "salt": salt,
      "rounds": rounds,
      "type": type,
      "version": version,
      "memoryPowerOf2": memoryPowerOf2,
      "encryptionAlgorithm": encryptionAlgorithm,
      "keyMaterial": keyMaterial,
      "keyNonce": keyNonce,
      // "mac": mac,
    };

    return jsonMap;
  }

}


class VaultItem {
  String id;                  // static vault identifier
  String version;             // app version
  String name;                // vault name
  String deviceId;            // device identifier (id for vendor)
  String? deviceData;         // device information
  EncryptedKey encryptedKey;  // master key information
  List<RecoveryKey>?
      recoveryKeys;           // encrypted master key with recovery keys from identities
  MyDigitalIdentity? myIdentity; // my key pair info - encrypted
  int numItems;               // number of passwords, notes, and keys
  String blob;                // encrypted GenericItemList JSON string base64 encoded
  List<DigitalIdentity>? identities; // recovery identity public key info - encrypted
  String mac;                 // mac of VaultItem model with empty string as initial mac value (using auth key)
  String cdate;               // created date
  String mdate;               // modified date

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
    required this.mac,
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
      mac: json['mac'],
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
      "encryptedKey": encryptedKey,
      "numItems": numItems,
      "blob": blob,
      "mac": mac,
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
  String id;    // pubKeyHash (hash of peer identity public key)
  String data;  // encrypted root vault key using the shared secret key
  String cdate; // creation date

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
