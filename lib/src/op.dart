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

/// The commitment operations public Bitcoin calendars emit.
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'codec.dart';

/// Largest message (op input or result) the format permits.
const maxMessageLength = 4096;

/// A commitment operation: a deterministic function from one message to
/// the next along a timestamp's path.
///
/// Only SHA-256, append and prepend are supported. Any other op tag in a
/// proof is rejected with [FormatException].
sealed class Op implements Comparable<Op> {
  const Op();

  /// The op's one-byte serialization tag.
  int get tag;

  /// The op's argument (empty for SHA-256).
  Uint8List get argument;

  /// Applies the op to [msg].
  Uint8List call(Uint8List msg);

  /// Writes the tag and, for binary ops, the argument.
  ///
  /// Throws [ArgumentError] for a binary op with an empty argument, which
  /// the format cannot read back.
  void serialize(ByteWriter w) {
    if (this is! OpSHA256 && argument.isEmpty) {
      throw ArgumentError('$runtimeType needs a non-empty argument');
    }
    w.writeByte(tag);
    if (this is! OpSHA256) w.writeVarbytes(argument);
  }

  /// Reads the op whose [tag] byte has already been consumed.
  static Op deserialize(ByteReader r, int tag) {
    switch (tag) {
      case OpSHA256.tagByte:
        return const OpSHA256();
      case OpAppend.tagByte:
        return OpAppend(r.readVarbytes(max: maxMessageLength, min: 1));
      case OpPrepend.tagByte:
        return OpPrepend(r.readVarbytes(max: maxMessageLength, min: 1));
      default:
        throw FormatException(
          'Unsupported op tag 0x${tag.toRadixString(16).padLeft(2, '0')}',
        );
    }
  }

  Uint8List _checked(Uint8List result) {
    if (result.length > maxMessageLength) {
      throw const FormatException('Op result exceeds 4096 bytes');
    }
    return result;
  }

  /// Orders by tag, then by argument bytes (the canonical order).
  @override
  int compareTo(Op other) => tag != other.tag
      ? tag - other.tag
      : compareBytes(argument, other.argument);

  @override
  bool operator ==(Object other) =>
      other is Op && tag == other.tag && bytesEqual(argument, other.argument);

  @override
  int get hashCode => Object.hash(tag, Object.hashAll(argument));
}

/// SHA-256 of the message.
final class OpSHA256 extends Op {
  /// Creates the SHA-256 op.
  const OpSHA256();

  /// Serialization tag.
  static const tagByte = 0x08;

  @override
  int get tag => tagByte;

  @override
  Uint8List get argument => Uint8List(0);

  @override
  Uint8List call(Uint8List msg) =>
      Uint8List.fromList(sha256.convert(msg).bytes);

  @override
  String toString() => 'sha256';
}

/// Message followed by [argument].
final class OpAppend extends Op {
  /// Creates an append op.
  OpAppend(this.argument);

  /// Serialization tag.
  static const tagByte = 0xf0;

  @override
  int get tag => tagByte;

  @override
  final Uint8List argument;

  @override
  Uint8List call(Uint8List msg) =>
      _checked(Uint8List.fromList([...msg, ...argument]));

  @override
  String toString() => 'append ${hexEncode(argument)}';
}

/// [argument] followed by the message.
final class OpPrepend extends Op {
  /// Creates a prepend op.
  OpPrepend(this.argument);

  /// Serialization tag.
  static const tagByte = 0xf1;

  @override
  int get tag => tagByte;

  @override
  final Uint8List argument;

  @override
  Uint8List call(Uint8List msg) =>
      _checked(Uint8List.fromList([...argument, ...msg]));

  @override
  String toString() => 'prepend ${hexEncode(argument)}';
}
