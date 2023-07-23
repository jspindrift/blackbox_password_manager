import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';

import '../managers/Cryptor.dart';
import '../managers/SettingsManager.dart';
import 'GeoLockItem.dart';

import '../merkle/merkle_example.dart';

import 'package:logger/logger.dart';

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
  int version;
  String name;  // encrypted
  String notes; // encrypted
  bool favorite;
  List<String>? tags;
  /// TODO: add geo-encryption?
  GeoLockItem? geoLock;
  String cdate;
  String mdate;

  NoteItem({
    required this.id,
    required this.version,
    required this.name,  // encrypted
    required this.notes, // encrypted
    required this.favorite,
    required this.tags,
    required this.geoLock,
    required this.cdate,
    required this.mdate,
  });

  factory NoteItem.fromRawJson(String str) =>
      NoteItem.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());


  Map<String, dynamic> toJsonVersion() => {
    "version": version!,
  };


  factory NoteItem.fromJson(Map<String, dynamic> json) {
    return NoteItem(
      id: json['id'],
      version: json["version"] == null ? null : json["version"],
      name: json['name'],
      notes: json['notes'],
      favorite: json['favorite'],
      tags: json['tags'] == null ? null : List<String>.from(json["tags"]),
      geoLock: json['geoLock'] == null
          ? null
          : GeoLockItem.fromJson(json['geoLock']),
      cdate: json['cdate'],
      mdate: json['mdate'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "id": id,
      // "version": version,
      "name": name,
      "notes": notes,
      "favorite": favorite,
      "tags": tags,
      "geoLock": geoLock,
      "cdate": cdate,
      "mdate": mdate,
    };

    if (version != null) {
      jsonMap.addAll(toJsonVersion());
    }

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
  }

}
