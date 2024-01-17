/// Functions and methods from:
///
/// https://pub.dev/packages/dart_merkle_lib
///

import 'dart:typed_data';
import './typedefs.dart';

/// constant-space merkle root calculation algorithm
Uint8List fastRoot(List<Uint8List> values, DigestFn digestFn) {
  try {
    int length = values.length;
    List<Uint8List> results = List.from(values);

    while (length > 1) {
      var j = 0;

      for (var i = 0; i < length; i += 2, ++j) {
        var left = results[i];
        var right = i + 1 == length ? left : results[i + 1];
        var data = Uint8List(left.length + right.length)
          ..setAll(0, left)..setAll(left.length, right);

        results[j] = digestFn(data);
      }

      length = j;
    }

    return results[0];
  } catch (e) {
   // print(e);
   return Uint8List(0);
  }
}