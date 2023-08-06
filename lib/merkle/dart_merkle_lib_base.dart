/// Functions and methods from:
///
/// https://pub.dev/packages/dart_merkle_lib
///

import 'dart:typed_data';
import './typedefs.dart';

/// Derive
/// returns an list of hashes of length: values.length / 2 + (values.length % 2)
List<Uint8List> _derive(List<Uint8List> values, DigestFn digestFn) {
  int length = values.length;
  List<Uint8List> results = [];

  for (var i = 0; i < length; i += 2) {
    var left = values[i];
    var right = i + 1 == length ? left : values[i + 1];
    var data = Uint8List(left.length + right.length)
      ..setAll(0, left)
      ..setAll(left.length, right);

    // print("_derive[${data.length}]: $data");

    results.add(digestFn(data));
  }

  return results;
}

/// Get Merkle Tree
List<Uint8List> merkle(List<Uint8List> values, DigestFn digestFn) {
  if (values.length == 0) return List.from([]);
  if (values.length == 1) return List.from(values);

  List<List<Uint8List>> levels = [values];
  var level = values;

  do {
    level = _derive(level, digestFn);
    levels.add(level);
  } while (level.length > 1);

  return levels.expand((i) => i).toList();
}