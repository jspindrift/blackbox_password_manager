import 'package:convert/convert.dart';

class ivHelper {

  static final zero4bytes = List<int>.filled(4, 0);
  static final zero8bytes = List<int>.filled(8, 0);
  static final zero12bytes = List<int>.filled(12, 0);
  static final zero16bytes = List<int>.filled(16, 0);

  List<int> getIv4x4(int a, int b, int c, int d)  {
    final iva = convertToBytes(a, 4);
    final ivb = convertToBytes(b, 4);
    final ivc = convertToBytes(c, 4);
    final ivd = convertToBytes(d, 4);

    final iv = iva + ivb + ivc + ivd;
    // print("iv: ${iv.length}: $iv");

    return iv;
  }

  List<int> getIv2x8(int r, int c)  {
    final ivr = convertToBytes(r, 8);
    final ivc = convertToBytes(c, 8);
    // final ivc = convertToBytes(c, 4);
    // final ivd = convertToBytes(d, 4);

    final iv = ivr + ivc;
    // print("iv: ${iv.length}: $iv");

    return iv;
  }

  List<int> getIv_a(int a)  {
    final iva = convertToBytes(a, 4);
    final ivb = convertToBytes(0, 4);
    final ivc = convertToBytes(0, 4);
    final ivd = convertToBytes(0, 4);

    final iv = iva + ivb + ivc + ivd;
    // print("iv: ${iv.length}: $iv");

    return iv;
  }

  List<int> getIv_ab(int a, int b)  {
    final iva = convertToBytes(a, 4);
    final ivb = convertToBytes(b, 4);
    final ivc = convertToBytes(0, 4);
    final ivd = convertToBytes(0, 4);

    final iv = iva + ivb + ivc + ivd;
    // print("iv: ${iv.length}: $iv");

    return iv;
  }

  List<int> getIv_abc(int a, int b, int c)  {
    final iva = convertToBytes(a, 4);
    final ivb = convertToBytes(b, 4);
    final ivc = convertToBytes(c, 4);
    final ivd = convertToBytes(0, 4);

    final iv = iva + ivb + ivc + ivd;
    // print("iv: ${iv.length}: $iv");

    return iv;
  }

  List<int> convertToBytes(int num, int byteWidth) {
    var hex_a = num.toRadixString(16);
    // print("hex_a: $hex_a");

    if (hex_a.length % 2 == 1) {
      hex_a = "0" + hex_a;
      // print("hex_a: $hex_a");
    }

    final abytes = hex.decode(hex_a);
    // print("abytes: ${abytes.length}: $abytes");

    final plank = zero16bytes.sublist(0, byteWidth-abytes.length);

    final result = plank + abytes;
    // print("result: ${result.length}: $result");

    return result;
  }

}