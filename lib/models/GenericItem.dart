import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';

import '../managers/Cryptor.dart';
import 'KeyItem.dart';
import 'NoteItem.dart';
import 'PasswordItem.dart';
import 'package:logger/logger.dart';
import '../merkle/merkle_example.dart';

var logger = Logger(
  printer: PrettyPrinter(),
);

var loggerNoStack = Logger(
  printer: PrettyPrinter(methodCount: 0),
);


class GenericItem {
  String type;
  String data;  // json string data of type "type"

  GenericItem({
    required this.type,
    required this.data,
  });

  factory GenericItem.fromRawJson(String str) =>
      GenericItem.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GenericItem.fromJson(Map<String, dynamic> json) {
    return GenericItem(
      type: json['type'],
      data: json['data'],
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

class GenericItemList {
  List<GenericItem> list;

  GenericItemList({
    required this.list,
  });

  factory GenericItemList.fromRawJson(String str) =>
      GenericItemList.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GenericItemList.fromJson(Map<String, dynamic> json) {
    return GenericItemList(
      list: List<GenericItem>.from(
          json["list"].map((x) => GenericItem.fromJson(x))),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "list": list,
    };

    return jsonMap;
  }

  Future<List<String>> calculateMerkleTree() async {
    logger.d("calculateMerkleRoot: GenericItemList");

    // var msgHashList = "";
    List<Uint8List> data = [];
    for (var item in list) {
      if (item.type == "password") {
        var passwordItem = PasswordItem.fromRawJson(item.data);
        if (passwordItem != null) {
          /// hash
          // data.add(Uint8List.fromList(hex.decode(Cryptor().sha256(item.data))));

          /// hmac - keyed hash
          final imac = await Cryptor().hmac256(item.data);
          data.add(Uint8List.fromList(hex.decode(imac)));
          // final m = (passwordItem?.merkle)!;
          // if (m != null) {
          //   data.add(Uint8List.fromList(hex.decode(m)));
          //   msgHashList += m;
          //   // msgHashList += Cryptor().sha256(m);
          // }
        }
      } else if (item.type == "note"){
        var noteItem = NoteItem.fromRawJson(item.data);
        if (noteItem != null) {
          /// hash
          // data.add(Uint8List.fromList(hex.decode(Cryptor().sha256(item.data))));

          /// hmac - keyed hash
          final imac = await Cryptor().hmac256(item.data);
          data.add(Uint8List.fromList(hex.decode(imac)));
          // final m = (noteItem?.merkle)!;
          // if (m != null) {
          //   data.add(Uint8List.fromList(hex.decode(m)));
          //   msgHashList += m;
          //   // msgHashList += Cryptor().sha256(m);
          // }
        }
      } else if (item.type == "key") {
        var keyItem = KeyItem.fromRawJson(item.data);
        if (keyItem != null) {
          /// hash
          // data.add(Uint8List.fromList(hex.decode(Cryptor().sha256(item.data))));

          /// hmac - keyed hash
          final imac = await Cryptor().hmac256(item.data);
          data.add(Uint8List.fromList(hex.decode(imac)));

          // final m = (keyItem?.merkle)!;
          // if (m != null) {
          //   data.add(Uint8List.fromList(hex.decode(m)));
          //   msgHashList += m;
          //   // msgHashList += Cryptor().sha256(keyItem.merkle);
          // }
        }
      }
    }

    // logger.d("data: $data");
    final itree = getTree(data, 256);

    return itree;
  }

  Future<List<String>> calculateReKeyMerkleTree() async {
    logger.d("calculateReKeyMerkleTree: GenericItemList");

    List<Uint8List> data = [];
    for (var item in list) {
      if (item.type == "password") {
        var passwordItem = PasswordItem.fromRawJson(item.data);
        if (passwordItem != null) {
          /// hash
          // data.add(Uint8List.fromList(hex.decode(Cryptor().sha256(item.data))));

          /// hmac - keyed hash
          final imac = await Cryptor().hmac256ReKey(item.data);
          data.add(Uint8List.fromList(hex.decode(imac)));
          // final m = (passwordItem?.merkle)!;
          // if (m != null) {
          //   data.add(Uint8List.fromList(hex.decode(m)));
          //   msgHashList += m;
          //   // msgHashList += Cryptor().sha256(m);
          // }
        }
      } else if (item.type == "note"){
        var noteItem = NoteItem.fromRawJson(item.data);
        if (noteItem != null) {
          /// hash
          // data.add(Uint8List.fromList(hex.decode(Cryptor().sha256(item.data))));

          /// hmac - keyed hash
          final imac = await Cryptor().hmac256ReKey(item.data);
          data.add(Uint8List.fromList(hex.decode(imac)));
          // final m = (noteItem?.merkle)!;
          // if (m != null) {
          //   data.add(Uint8List.fromList(hex.decode(m)));
          //   msgHashList += m;
          //   // msgHashList += Cryptor().sha256(m);
          // }
        }
      } else if (item.type == "key") {
        var keyItem = KeyItem.fromRawJson(item.data);
        if (keyItem != null) {
          /// hash
          // data.add(Uint8List.fromList(hex.decode(Cryptor().sha256(item.data))));

          /// hmac - keyed hash
          final imac = await Cryptor().hmac256ReKey(item.data);
          data.add(Uint8List.fromList(hex.decode(imac)));

          // final m = (keyItem?.merkle)!;
          // if (m != null) {
          //   data.add(Uint8List.fromList(hex.decode(m)));
          //   msgHashList += m;
          //   // msgHashList += Cryptor().sha256(keyItem.merkle);
          // }
        }
      }
    }

    // logger.d("data: $data");
    final itree = getTree(data, 256);

    return itree;
  }

  Future<bool> verifyItems(List<String>? checkTree) async {
    List<Uint8List> data = [];
    if (checkTree == null) {
      return false;
    }

    for (var item in list) {
      if (item.type == "password") {
        var passwordItem = PasswordItem.fromRawJson(item.data);
        if (passwordItem != null) {
          final imac = await Cryptor().hmac256(item.data);
          data.add(Uint8List.fromList(hex.decode(imac)));
          // data.add(Uint8List.fromList(hex.decode(Cryptor().sha256(item.data))));

          // final m = (passwordItem?.merkle)!;
          // if (m != null) {
          //   data.add(Uint8List.fromList(hex.decode(m)));
          //   msgHashList += m;
          //   // msgHashList += Cryptor().sha256(m);
          // }
        } else {
          logger.e("invalid PasswordItem: ${item.data}");
          return false;
        }
      } else if (item.type == "note"){
        var noteItem = NoteItem.fromRawJson(item.data);
        if (noteItem != null) {
          final imac = await Cryptor().hmac256(item.data);
          data.add(Uint8List.fromList(hex.decode(imac)));

          // final m = (noteItem?.merkle)!;
          // if (m != null) {
          //   data.add(Uint8List.fromList(hex.decode(m)));
          //   msgHashList += m;
          //   // msgHashList += Cryptor().sha256(m);
          // }
        } else {
          logger.e("invalid NoteItem: ${item.data}");
          return false;
        }
      } else if (item.type == "key") {
        var keyItem = KeyItem.fromRawJson(item.data);
        if (keyItem != null) {
          final imac = await Cryptor().hmac256(item.data);
          data.add(Uint8List.fromList(hex.decode(imac)));

          // final m = (keyItem?.merkle)!;
          // if (m != null) {
          //   data.add(Uint8List.fromList(hex.decode(m)));
          //   msgHashList += m;
          //   // msgHashList += Cryptor().sha256(keyItem.merkle);
          // }
        } else {
          logger.e("invalid KeyItem: ${item.data}");
          return false;
        }
      }
    }

    if (data.isEmpty) {
      logger.d("empty data not root");
      return true;
    }

    final root = rootOnlyTest(data);
    logger.d("calculated root: $root");

    logger.d("checkTree root: ${checkTree.last}");

    // logger.d("root == checkRoot: ${(checkRoot == root)}");

    // var index = 0;
    // for (var leaf in checkTree) {
    //   final isValid = (leaf == data[index]);
    //   logger.d("leaf == checkLeaf: ${isValid}");
    //   index += 1;
    //   // logger.d("leaf is in checkLeaf: ${(leaf == data.contains(leaf))}: ${(data.indexOf(Uint8List.fromList(hex.decode(leaf))))}");
    //   if (!isValid) {
    //     return false;
    //   }
    // }


    return root == checkTree.last;
  }

}


class GenericObject {
  String type;
  String id;
  String keyId;
  String data;  // JSON string data (encrypted)
  String mac;

  GenericObject({
    required this.type,
    required this.id,
    required this.keyId,
    required this.data,
    required this.mac,
  });

  factory GenericObject.fromRawJson(String str) =>
      GenericObject.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GenericObject.fromJson(Map<String, dynamic> json) {
    return GenericObject(
      type: json['type'],
      id: json['id'],
      keyId: json['keyId'],
      data: json['data'],
      mac: json['mac'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "type": type,
      "id": id,
      "keyId": keyId,
      "data": data,
      "mac": mac,
    };

    return jsonMap;
  }

}

class GenericObjectList {
  List<GenericObject> items;

  GenericObjectList({
    required this.items,
  });

  factory GenericObjectList.fromRawJson(String str) =>
      GenericObjectList.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GenericObjectList.fromJson(Map<String, dynamic> json) {
    return GenericObjectList(
      items: List<GenericObject>.from(
          json["items"].map((x) => GenericObject.fromJson(x))),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> jsonMap = {
      "items": items,
    };

    return jsonMap;
  }

}