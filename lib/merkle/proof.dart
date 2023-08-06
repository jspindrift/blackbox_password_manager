/// https://bitcointalk.org/index.php?topic=403231.msg9054025#msg9054025
/// https://pub.dev/packages/dart_merkle_lib

import 'dart:typed_data';

import './typedefs.dart';

/// Tree Node Count
int _treeNodeCount(int leafCount) {
  int count = 1;
  for (int i = leafCount; i > 1; i = (i + 1) >> 1) {
    count += i;
  }
  return count;
}

/// Tree Width
int _treeWidth(int n, int h) {
  return (n + (1 << h) - 1) >> h;
}

/// Make Merkle Proof
List<Uint8List?>? merkleProof(List<Uint8List?> tree, Uint8List leaf) {
  int index = tree.map((e) => e.toString()).toList().indexOf(leaf.toString());

  // does the leaf node even exist [in the tree]?
  if (index == -1) return null;

  int n = tree.length;
  List<Uint8List?> nodes = [];

  // does the far right leaf bypass a layer?
  // determine hashable node count...
  int z = _treeWidth(n, 1);
  while (z > 0) {
    if (_treeNodeCount(z) == n) break;
    --z;
  }

  // XXX: not reach-able (AFAIK) but handled anyway
  if (z == 0) throw Exception('Unknown solution');

  int height = 0;
  int i = 0;
  while (i < n - 1) {
    int layerWidth = _treeWidth(z, height);
    ++height;

    int odd = index % 2;
    if (odd != 0) --index;

    int offset = i + index;
    Uint8List? left = tree[offset];
    Uint8List? right = index == (layerWidth - 1) ? left : tree[offset + 1];

    if (i > 0) {
      nodes.add(odd != 0 ? left : null);
      nodes.add(odd != 0 ? null : right);
    } else {
      nodes.add(left);
      nodes.add(right);
    }

    index = (index / 2).truncate();
    i += layerWidth;
  }

  nodes.add(tree[n - 1]);
  return nodes;
}

/// Verify Proof
bool verify(List<Uint8List?> proof, DigestFn digestFn) {
  Uint8List root = proof[proof.length - 1]!;
  Uint8List hash = root;

  for (int i = 0; i < proof.length - 1; i += 2) {
    Uint8List left = proof[i] ?? hash;
    Uint8List right = proof[i + 1] ?? hash;
    Uint8List data = Uint8List(left.length + right.length)
      ..setAll(0, left)
      ..setAll(left.length, right);
    hash = digestFn(data);
  }

  return hash.toString() == root.toString();
}