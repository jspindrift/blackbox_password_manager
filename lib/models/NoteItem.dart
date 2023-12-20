import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:logger/logger.dart';

import '../managers/Cryptor.dart';
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


class NoteItem {
  String id;
  String keyId;  // root key identifier
  int version;
  String name;  // encrypted
  String notes; // encrypted
  bool favorite;
  List<String> tags;
  /// TODO: add geo-encryption?
  GeoLockItem? geoLock;
  String mac; // mac of json object
  String cdate;
  String mdate;

  NoteItem({
    required this.id,
    required this.keyId,
    required this.version,
    required this.name,  // encrypted
    required this.notes, // encrypted
    required this.favorite,
    required this.tags,
    required this.geoLock,
    required this.mac,
    required this.cdate,
    required this.mdate,
  });

  factory NoteItem.fromRawJson(String str) =>
      NoteItem.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());


  Map<String, dynamic> toJsonVersion() => {
    "version": version!,
  };

  Map<String, dynamic> toJsonItemMac() => {
    "mac": mac!,
  };

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    return NoteItem(
      id: json['id'],
      keyId: json['keyId'],
      version: json["version"], // == null ? null : json["version"],
      name: json['name'],
      notes: json['notes'],
      favorite: json['favorite'],
      tags: List<String>.from(json["tags"]), //json['tags'] == null ? null : List<String>.from(json["tags"]),
      geoLock: json['geoLock'] == null
          ? null
          : GeoLockItem.fromJson(json['geoLock']),
      mac: json['mac'], // == null ? null : json['mac'],
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
      "notes": notes,
      "favorite": favorite,
      "tags": tags,
      "geoLock": geoLock,
      "mac": mac,
      "cdate": cdate,
      "mdate": mdate,
    };

    // if (version != null) {
    //   jsonMap.addAll(toJsonVersion());
    // }
    //
    // if (mac != null) {
    //   jsonMap.addAll(toJsonItemMac());
    // }

    return jsonMap;
  }

  Future<void> encryptParams() async {
    /// calculate encryption blocks
    final encodedAllPlaintextLength = utf8.encode(name).length + utf8.encode(notes).length;
    settingsManager.doEncryption(encodedAllPlaintextLength);

    /// encrypt fields
    final encryptedName = await cryptor.encrypt(name);

    final encryptedNotes = await cryptor.encrypt(notes);

    /// set fields
    name = encryptedName;
    notes = encryptedNotes;
    mac = "";

    /// compute mac of JSON object with empty mac
    final computedMac = await cryptor.hmac256(toRawJson());
    mac = base64.encode(hex.decode(computedMac));
    // logger.d("toJSON final: ${toJson()}");
  }

  decryptObject() async {
    try {
      final macCheck = mac;
      mac = "";
      var objString = toRawJson();

      final computedMac = await cryptor.hmac256(objString);
      // logger.d("macCheck: $macCheck\ncomputedMac: $computedMac");

      if (base64.encode(hex.decode(computedMac)) != macCheck && macCheck.isNotEmpty) {
        logger.wtf("incorrect mac");
        return;
      }

      final decryptedName = await cryptor.decrypt(name);
      final decryptedNote = await cryptor.decrypt(notes);

      name = decryptedName;
      notes = decryptedNote;
      // logger.d("ditem: ${ditem.toJson()}");

    } catch (e) {
      logger.wtf("Exception: $e");
    }
  }

  Future<NoteItem?> decryptObjectCopy() async {
    var item = NoteItem.fromJson(toJson());
    var ditem = item;

    var itemCopy = NoteItem.fromJson(item.toJson());

    final macCheck = item.mac!;
    itemCopy.mac = "";
    var objString = itemCopy.toRawJson();

    final computedMac = await cryptor.hmac256(objString);
    // logger.d("macCheck: $macCheck\ncomputedMac: $computedMac");

    if (computedMac != macCheck && macCheck.isNotEmpty) {
      logger.wtf("incorrect mac");
      return item;
    }

    final decryptedName = await cryptor.decrypt(item.name);
    var decryptedNote = await cryptor.decrypt(item.notes);

    ditem.name = decryptedName;
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
