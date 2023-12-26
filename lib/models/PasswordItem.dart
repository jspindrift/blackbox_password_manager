import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:logger/logger.dart';

import '../managers/Cryptor.dart';
import '../managers/GeolocationManager.dart';
import '../managers/SettingsManager.dart';
import 'GeoLockItem.dart';


var logger = Logger(
  printer: PrettyPrinter(),
);

var loggerNoStack = Logger(
  printer: PrettyPrinter(methodCount: 0),
);

final settingsManager = SettingsManager();
final cryptor = Cryptor();


class PasswordItem {
  String id;
  String keyId;  // root key identifier
  int? version;  // add version for future-proofing implementations
  String name; // encrypted
  String username; // encrypted
  String password; // encrypted
  List<PreviousPassword> previousPasswords; // encrypted
  bool favorite;
  bool isBip39;
  // PasswordPolicy? policy;  // TODO: remove this
  List<String> tags;
  GeoLockItem? geoLock;
  String notes; // encrypted
  String mac; // mac of json object
  String cdate;
  String mdate;

  PasswordItem({
    required this.id,
    required this.keyId,
    required this.version,
    required this.name,
    required this.username,
    required this.password,
    required this.previousPasswords,
    required this.favorite,
    required this.isBip39,
    required this.tags,
    required this.geoLock,
    required this.notes,
    required this.mac,
    required this.cdate,
    required this.mdate,
  });

  factory PasswordItem.fromRawJson(String str) =>
      PasswordItem.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());


  factory PasswordItem.fromJson(Map<String, dynamic> json) {
    return PasswordItem(
      id: json['id'],
      keyId: json['keyId'],
      version: json["version"],
      name: json['name'],
      username: json['username'],
      password: json['password'],
      previousPasswords: List<PreviousPassword>.from(
          json["previousPasswords"].map((x) => PreviousPassword.fromJson(x))),
      favorite: json['favorite'],
      isBip39: json['isBip39'],
      tags:  List<String>.from(json["tags"]),
      geoLock: json['geoLock'] == null
          ? null
          : GeoLockItem.fromJson(json['geoLock']),
      notes: json['notes'],
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
      "username": username,
      "password": password,
      "previousPasswords": previousPasswords,
      "favorite": favorite,
      "isBip39": isBip39,
      "notes": notes,
      "tags": tags,
      "geoLock": geoLock,
      "mac": mac,
      "cdate": cdate,
      "mdate": mdate,
    };

    return jsonMap;
  }


  Future<void> encryptParams(GeoLocationUpdate? geoLocation) async {
    try {
      bool isGeoLocked = geoLocation != null;

      /// calculate blocks encrypted
      final encodedAllPlaintextLength = utf8
          .encode(name)
          .length + utf8
          .encode(username)
          .length + utf8
          .encode(password)
          .length + utf8
          .encode(notes)
          .length;
      settingsManager.doEncryption(encodedAllPlaintextLength);

      /// Encrypt parameters
      final encryptedName = await cryptor.encrypt(name);
      final encryptedUsername = await cryptor.encrypt(username);
      final encryptedNotes = await cryptor.encrypt(notes);

      String encryptedPassword = '';
      GeoLockItem? geoItem;

      /// add for geo-encryption
      if (isBip39) {
        final seed = cryptor.mnemonicToEntropy(password);

        if (isGeoLocked) {
          geoItem = await doGeoLockEncryption(geoLocation, seed);
          encryptedPassword = (geoItem?.password)!;
        } else {
          /// Encrypt seed here
          encryptedPassword = await cryptor.encrypt(seed);
        }
      } else {
        if (isGeoLocked) {
          geoItem = await doGeoLockEncryption(geoLocation, password);
          encryptedPassword = (geoItem?.password)!;
        } else {
          /// Encrypt password here
          encryptedPassword = await cryptor.encrypt(password);
        }
      }

      /// update our fields
      name = encryptedName;
      username = encryptedUsername;
      password = encryptedPassword;
      notes = encryptedNotes;
      geoLock = geoItem;
      mac = "";

      /// compute mac of JSON object with empty mac
      final computedMac = await cryptor.hmac256(toRawJson());
      mac = base64.encode(hex.decode(computedMac));

    } catch (e) {
      logger.w("encryptParams for PasswordItem failed: $e");
    }
  }

  /// encrypt params with GeoLock and optional previousPassword if our password changes
  /// so we can add it to our previousPassword list
  Future<void> encryptParams2(GeoLocationUpdate? geoLocation, String previousPassword) async {

    try {
      bool isGeoLocked = geoLocation != null;

      bool shouldAddPreviousPassword = previousPassword.isNotEmpty;
      var isPreviousBip39Valid = false;
      if (shouldAddPreviousPassword) {
        isPreviousBip39Valid = cryptor.validateMnemonic(previousPassword);
        var encryptedPrevious = '';

        if (isPreviousBip39Valid) {
          final seed = cryptor.mnemonicToEntropy(previousPassword);
          settingsManager.doEncryption(utf8.encode(seed).length);
          encryptedPrevious = await cryptor.encrypt(seed);
        } else {
          settingsManager.doEncryption(utf8.encode(previousPassword).length);
          encryptedPrevious = await cryptor.encrypt(previousPassword);
        }

        final previousPasswordItem = PreviousPassword(
          password: encryptedPrevious,
          isBip39: isPreviousBip39Valid,
          cdate: mdate,
        );

        /// update previous passwords field
        previousPasswords.add(previousPasswordItem);
      }


      isBip39 = cryptor.validateMnemonic(password);

      var pwdLength = 0;
      if (isBip39) {
        pwdLength = utf8
            .encode(cryptor.mnemonicToEntropy(password))
            .length;
      } else {
        pwdLength = password.length;
      }

      /// calculate blocks encrypted
      final encodedPlaintextLength = pwdLength + utf8
          .encode(name)
          .length + utf8
          .encode(username)
          .length + utf8
          .encode(notes)
          .length;
      settingsManager.doEncryption(encodedPlaintextLength);

      /// Encrypt parameters
      final encryptedName = await cryptor.encrypt(name);
      final encryptedUsername = await cryptor.encrypt(username);
      final encryptedNotes = await cryptor.encrypt(notes);

      String encryptedPassword = '';
      GeoLockItem? geoItem;

      if (isBip39) {
        final seed = cryptor.mnemonicToEntropy(password);

        settingsManager.doEncryption(utf8.encode(seed).length);

        /// TODO: add geo-lock
        if (isGeoLocked) {
          geoItem = await doGeoLockEncryption(geoLocation, seed);
          encryptedPassword = (geoItem?.password)!;
        } else {
          /// Encrypt seed here
          encryptedPassword = await cryptor.encrypt(seed);
        }

      } else {
        /// TODO: add geo-lock
        settingsManager.doEncryption(utf8.encode(password).length);

        if (isGeoLocked) {
          geoItem = await doGeoLockEncryption(geoLocation, password);
          encryptedPassword = (geoItem?.password)!;
        } else {
          /// Encrypt password here
          encryptedPassword = await cryptor.encrypt(password);
        }
      }

      /// update our fields
      name = encryptedName;
      username = encryptedUsername;
      password = encryptedPassword;
      notes = encryptedNotes;
      geoLock = geoItem;
      mac = "";

      // mac = await cryptor.hmac256(toRawJson());
      /// compute mac of JSON object with empty mac
      final computedMac = await cryptor.hmac256(toRawJson());
      mac = base64.encode(hex.decode(computedMac));
      // logger.d("toJSON final: ${toJson()}");

    } catch (e) {
      logger.w("encryptParams2 Failed with Password Item");
    }
  }

  Future<GeoLockItem?> doGeoLockEncryption(GeoLocationUpdate? geoLocation, String password) async {
    GeoLockItem? geoItem;

    try {
      final lat = geoLocation?.userLocation.latitude;
      final long = geoLocation?.userLocation.longitude;
      if (lat != null && long != null) {
        final geoLockedItem = await cryptor.geoEncrypt(lat!, long!, password);
        // encryptedPassword
        if (geoLockedItem != null) {
          final lat_tokens = (geoLockedItem?.lat_tokens)!;
          final long_tokens = (geoLockedItem?.long_tokens)!;
          final iv = (geoLockedItem?.iv)!;

          final encryptedPassword = (geoLockedItem?.encryptedPassword)!;
          // geoItem = GeoEncryptionItem(iv: iv, lat_tokens: lat_tokens, long_tokens: long_tokens);

          geoItem = GeoLockItem(
            iv: iv,
            lat_tokens: lat_tokens,
            long_tokens: long_tokens,
            password: encryptedPassword,
          );
        }
      }

      return geoItem;
    } catch (e) {
      logger.w("geoLockEncryption Failed on PasswordItem");
      return null;
    }
  }

  // Future<PasswordItem?> decryptObject() async {
  decryptObject() async {
    // var item = PasswordItem.fromJson(toJson());
    // var ditem = item;
    // var itemCopy = PasswordItem.fromJson(item.toJson());

    final macCheck = mac;
    mac = "";
    var objString = toRawJson();
    // logger.d("objString: $objString");

    final computedMac = await cryptor.hmac256(objString);
    // logger.d("macCheck: $macCheck\ncomputedMac: $computedMac");

    if (base64.encode(hex.decode(computedMac)) != macCheck && macCheck.isNotEmpty) {
      logger.wtf("incorrect mac");
      return null;
    }

    mac = base64.encode(hex.decode(computedMac));

    final decryptedName = await cryptor.decrypt(name);
    final decryptedUsername = await cryptor.decrypt(username);

    var decryptedNote = await cryptor.decrypt(notes);

    var decryptedPassword = password;
    if (geoLock == null) {
      decryptedPassword = await cryptor.decrypt(password);
      if (isBip39) {
        decryptedPassword = cryptor.entropyToMnemonic(decryptedPassword);
      }
    }

    name = decryptedName;
    username = decryptedUsername;
    password = decryptedPassword;
    notes = decryptedNote;

    // logger.d("decryptObject(): ${toRawJson()}");
  }

  Future<PasswordItem?> decryptObjectCopy() async {
    var item = PasswordItem.fromJson(toJson());
    var ditem = item;
    var itemCopy = PasswordItem.fromJson(item.toJson());

    final macCheck = item.mac!;
    itemCopy.mac = "";
    var objString = itemCopy.toRawJson();

    final computedMac = await cryptor.hmac256(objString);
    // logger.d("macCheck: $macCheck\ncomputedMac: $computedMac");

    if (base64.encode(hex.decode(computedMac)) != macCheck && macCheck.isNotEmpty) {
      logger.wtf("incorrect mac");
      return null;
    }

    final decryptedName = await cryptor.decrypt(item.name);
    final decryptedUsername = await cryptor.decrypt(item.username);

    var decryptedNote = await cryptor.decrypt(item.notes);

    var decryptedPassword = password;
    if (geoLock == null) {
      decryptedPassword =
      await cryptor.decrypt(password);
      if (isBip39) {
        decryptedPassword = cryptor.entropyToMnemonic(decryptedPassword);
      }
    }

    ditem.name = decryptedName;
    ditem.username = decryptedUsername;
    ditem.password = decryptedPassword;
    ditem.notes = decryptedNote;
    // logger.d("ditem: ${ditem.toJson()}");

    return ditem;
  }

  Future<bool> checkMAC() async {
    final checkMac = mac;
    mac = "";
    final computedMac = await cryptor.hmac256(toRawJson());
    mac = checkMac;
    // logger.d("toRawJson()-added back: ${toRawJson()}");

    if (checkMac == base64.encode(hex.decode(computedMac))){
      return true;
    }

    return false;
  }

}


class PreviousPassword {
  String password; // encrypted
  bool isBip39;
  String cdate;

  PreviousPassword({
    required this.password,
    required this.isBip39,
    required this.cdate,
  });

  factory PreviousPassword.fromRawJson(String str) =>
      PreviousPassword.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory PreviousPassword.fromJson(Map<String, dynamic> json) {
    return PreviousPassword(
      password: json['password'],
      isBip39: json['isBip39'],
      cdate: json['cdate'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "password": password,
      "isBip39": isBip39,
      "cdate": cdate,
    };

    return jsonMap;
  }

}


class PasswordPolicy {
  int generatedType;  // random, mnemonic, pin
  bool useLower;
  bool useUpper;      // encrypted
  bool useSpecial;
  bool useNumbers;
  int numOfWords;     // words can also mean characters
  int numOfChars;
  int numOfNumbers;
  int numOfUpper;
  int numOfLower;
  int numOfSpecial;


  PasswordPolicy({
    required this.generatedType,
    required this.useUpper,
    required this.useLower,
    required this.useSpecial,
    required this.useNumbers,
    required this.numOfWords,
    required this.numOfChars,
    required this.numOfNumbers,
    required this.numOfUpper,
    required this.numOfLower,
    required this.numOfSpecial,
  });

  factory PasswordPolicy.fromRawJson(String str) =>
      PasswordPolicy.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory PasswordPolicy.fromJson(Map<String, dynamic> json) {
    return PasswordPolicy(
      generatedType: json['generatedType'],
      useLower: json['useLower'],
      useUpper: json['useUpper'],
      useSpecial: json['useSpecial'],
      useNumbers: json['useNumbers'],
      numOfWords: json['numOfWords'],
      numOfChars: json['numOfChars'],
      numOfLower: json['numOfLower'],
      numOfUpper: json['numOfUpper'],
      numOfNumbers: json['numOfNumbers'],
      numOfSpecial: json['numOfSpecial'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "generatedType": generatedType,
      "useUpper": useUpper,
      "useLower": useLower,
      "useSpecial": useSpecial,
      "useNumbers": useNumbers,
      "numOfWords": numOfWords,
      "numOfChars": numOfChars,
      "numOfLower": numOfLower,
      "numOfUpper": numOfUpper,
      "numOfSpecial": numOfSpecial,
      "numOfNumbers": numOfNumbers,
    };

    return jsonMap;
  }

}
