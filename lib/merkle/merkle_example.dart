/// https://pub.dev/packages/dart_merkle_lib

import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;
import './dart_merkle_lib.dart';
import './fast_root.dart';
import './proof.dart';
import 'package:logger/logger.dart';

var logger = Logger(
  printer: PrettyPrinter(),
);

var loggerNoStack = Logger(
  printer: PrettyPrinter(methodCount: 0),
);


Uint8List sha256(Uint8List data) {
  return Uint8List.fromList(crypto.sha256.convert(data.toList()).bytes);
}

List<Uint8List> datat = [
  'cafebeef',
  'ffffffff',
  'aaaaaaaa',
  'bbbbbbbb',
  'cccccccc'
].map((x) => Uint8List.fromList(hex.decode(x))).toList();

// ... now, the examples

/// Tree Example
void treeExample() {
  logger.d('Start Tree Example');
  List<Uint8List> tree = merkle(datat, sha256);

  logger.d('[\n\t"${tree.map((x) => hex.encode(x)).join('",\n\t"')}"\n]');
  // => [
  // 	"cafebeef",
  // 	"ffffffff",
  // 	"aaaaaaaa",
  // 	"bbbbbbbb",
  // 	"cccccccc",
  // 	"bda5c39dec343da54ce91c57bf8e796c2ca16a1bd8cae6a2cefbdd16efc32578",
  // 	"8b722baf6775a313f1032ba9984c0dce32ff3c40d7a67b5df8de4dbaa43a3db0",
  // 	"3d2f424783df5853c8d7121b1371650c04241f318e1b0cd46bedbc805b9164c3",
  // 	"bb232963fd0efdeacb0fd76e26cf69055fa5facc19a5f5c2f2f27a6925d1db2f",
  // 	"2256e70bea2c591190a0d4d6c1415acd7458fae84d8d85cdc68b851da27777d4",
  // 	"c2692b0e127b3b774a92f6e1d8ff8c3a5ea9eef9a1d389fe294f0a7a2fec9be1"
  // ]
  logger.d('End Tree Example');
}

void treeTest(List<Uint8List> data) {
  logger.d('Start Tree Example');
  List<Uint8List> tree = merkle(data, sha256);

  logger.d('[\n\t"${tree.map((x) => hex.encode(x)).join('",\n\t"')}"\n]');

  logger.d('End Tree Test');
}

List<String> getTree(List<Uint8List> data) {
  // logger.d('getTree');
  List<Uint8List> tree = merkle(data, sha256);

  // logger.d('[\n\t"${tree.map((x) => hex.encode(x)).join('",\n\t"')}"\n]');

  final hexTree = List<String>.from(tree.map((x) => hex.encode(x)));//.toList();  //List<String>.from(hex.encode(x))
  // logger.d('End getTree: $hexTree');
  logger.d('hexTree[\n\t"${hexTree.join('",\n\t"')}"\n]');


  return hexTree;
}

///Root only (equivalent to `tree[tree.length - 1]`)
void rootOnlyExample() {
  logger.d('Start Root Only Example');
  Uint8List root = fastRoot(datat, sha256);
  logger.d(hex.encode(root));
  // => 'c2692b0e127b3b774a92f6e1d8ff8c3a5ea9eef9a1d389fe294f0a7a2fec9be1'
  logger.d('End Root Only Example');
}

String rootOnlyTest(List<Uint8List> data) {
  // logger.d('Start Root Only Test');
  Uint8List root = fastRoot(data, sha256);
  // logger.d("root: ${hex.encode(root)}");
  // => 'c2692b0e127b3b774a92f6e1d8ff8c3a5ea9eef9a1d389fe294f0a7a2fec9be1'
  // logger.d('End Root Only Test');

  return hex.encode(root);
}

/// Proof (with verify)
void proofExample() {
  logger.d('Start Proof Example');
  List<Uint8List> tree = merkle(datat, sha256);
  List<Uint8List?>? proof = merkleProof(tree, datat[0]);

  if (proof == null) {
    throw Exception('No proof exists!');
  }

  logger.d(
      '[\n\t${proof.map((x) => x == null ? 'null' : '"' + hex.encode(x)).join(',\n\t') + '"'}\n]');
  // => [
  //   'cafebeef',
  //   'ffffffff',
  //   null,
  //   '8b722baf6775a313f1032ba9984c0dce32ff3c40d7a67b5df8de4dbaa43a3db0',
  //   null,
  //   '2256e70bea2c591190a0d4d6c1415acd7458fae84d8d85cdc68b851da27777d4',
  //   'c2692b0e127b3b774a92f6e1d8ff8c3a5ea9eef9a1d389fe294f0a7a2fec9be1'
  // ]

  logger.d(verify(proof, sha256));
  // => true
  logger.d('End Proof Example');
}

void proofTest(List<Uint8List> data) {
  // logger.d('Start Proof Test');
  List<Uint8List> tree = merkle(data, sha256);
  List<Uint8List?>? proof = merkleProof(tree, data[0]);

  if (proof == null) {
    throw Exception('No proof exists!');
  }

  logger.d(
      '[\n\t${proof.map((x) => x == null ? 'null' : '"' + hex.encode(x)).join(',\n\t') + '"'}\n]');

  logger.d("verify: ${verify(proof, sha256)}");
  // => true
  logger.d('End Proof Example');
}

void main() {
  print("merkle_example: main()");
  // treeExample();
  logger.d('\n----------------------------------------------------\n');
  // rootOnlyExample();
  logger.d('\n----------------------------------------------------\n');
  // proofExample();
}