// Copyright 2025 Anspar Foundation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// The timestamp proof tree.
library;

import 'dart:typed_data';

import 'attestation.dart';
import 'codec.dart';
import 'op.dart';

const _recursionLimit = 256;

/// A node of a proof tree: a message, the attestations made directly on
/// it, and the ops leading from it to child nodes.
class Timestamp {
  /// Creates an empty node for [msg].
  Timestamp(Uint8List msg) : msg = Uint8List.fromList(msg) {
    if (msg.length > maxMessageLength) {
      throw const FormatException('Message exceeds 4096 bytes');
    }
  }

  /// The message this node commits to.
  final Uint8List msg;

  /// Attestations made directly on [msg].
  final Set<Attestation> attestations = {};

  /// Child nodes, keyed by the op that derives each child's message.
  final Map<Op, Timestamp> ops = {};

  /// Returns the child reached by [op], creating it if absent.
  Timestamp add(Op op) => ops.putIfAbsent(op, () => Timestamp(op(msg)));

  /// Merges every attestation and path of [other] (which must commit to
  /// the same message) into this node.
  void merge(Timestamp other) {
    if (!bytesEqual(msg, other.msg)) {
      throw ArgumentError('Cannot merge timestamps for different messages');
    }
    attestations.addAll(other.attestations);
    other.ops.forEach((op, child) => add(op).merge(child));
  }

  /// Every attestation in the tree, with the message it attests.
  Iterable<(Uint8List, Attestation)> allAttestations() sync* {
    for (final a in attestations) {
      yield (msg, a);
    }
    for (final child in ops.values) {
      yield* child.allAttestations();
    }
  }

  /// Every node in the tree, this one first.
  Iterable<Timestamp> nodes() sync* {
    yield this;
    for (final child in ops.values) {
      yield* child.nodes();
    }
  }

  /// Writes the tree in canonical order.
  void serialize(ByteWriter w) {
    final atts = attestations.toList()..sort();
    final sortedOps = ops.keys.toList()..sort();
    if (atts.isEmpty && sortedOps.isEmpty) {
      throw StateError('An empty timestamp cannot be serialized');
    }
    for (var i = 0; i < atts.length - 1; i++) {
      w.write(const [0xff, 0x00]);
      atts[i].serialize(w);
    }
    if (sortedOps.isEmpty) {
      w.writeByte(0x00);
      atts.last.serialize(w);
      return;
    }
    if (atts.isNotEmpty) {
      w.write(const [0xff, 0x00]);
      atts.last.serialize(w);
    }
    for (var i = 0; i < sortedOps.length; i++) {
      final op = sortedOps[i];
      if (i < sortedOps.length - 1) w.writeByte(0xff);
      op.serialize(w);
      ops[op]!.serialize(w);
    }
  }

  /// Reads a tree whose root message is [msg].
  static Timestamp deserialize(ByteReader r, Uint8List msg) =>
      _deserialize(r, msg, _recursionLimit);

  static Timestamp _deserialize(ByteReader r, Uint8List msg, int depth) {
    if (depth <= 0) throw const FormatException('Recursion limit exceeded');
    final node = Timestamp(msg);
    void tagOrAttestation(int tag) {
      if (tag == 0x00) {
        node.attestations.add(Attestation.deserialize(r));
      } else {
        final op = Op.deserialize(r, tag);
        node.ops[op] = _deserialize(r, op(msg), depth - 1);
      }
    }

    var tag = r.readByte();
    while (tag == 0xff) {
      tagOrAttestation(r.readByte());
      tag = r.readByte();
    }
    tagOrAttestation(tag);
    return node;
  }

  /// Parses a calendar response: a tree rooted at the submitted [msg].
  static Timestamp fromBytes(Uint8List bytes, Uint8List msg) {
    final r = ByteReader(bytes);
    final t = deserialize(r, msg);
    r.assertEnd();
    return t;
  }

  /// The serialized tree.
  Uint8List toBytes() {
    final w = ByteWriter();
    serialize(w);
    return w.toBytes();
  }
}
