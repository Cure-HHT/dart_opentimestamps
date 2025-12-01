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

/// OpenTimestamps cryptographic operations
library;

import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Base class for OpenTimestamps operations
abstract class Operation {
  /// Creates an operation
  const Operation();

  /// Applies this operation to the given message
  Uint8List apply(Uint8List message);

  /// Serializes this operation to bytes for the OTS file format
  Uint8List serialize();

  /// Operation tag bytes used in OTS file format
  int get tag;
}

/// SHA-256 hash operation (tag: 0x08)
class OpSHA256 extends Operation {
  /// Creates a SHA-256 operation
  const OpSHA256();

  @override
  int get tag => 0x08;

  @override
  Uint8List apply(Uint8List message) {
    final digest = sha256.convert(message);
    return Uint8List.fromList(digest.bytes);
  }

  @override
  Uint8List serialize() => Uint8List.fromList([tag]);

  @override
  String toString() => 'sha256';

  @override
  bool operator ==(Object other) => other is OpSHA256;

  @override
  int get hashCode => tag.hashCode;
}

/// Append data operation (tag: 0xf0)
///
/// Appends data to the end of the message: message + data
class OpAppend extends Operation {
  /// Creates an append operation
  const OpAppend(this.data);

  /// The data to append
  final Uint8List data;

  @override
  int get tag => 0xf0;

  @override
  Uint8List apply(Uint8List message) {
    final result = Uint8List(message.length + data.length);
    result.setRange(0, message.length, message);
    result.setRange(message.length, result.length, data);
    return result;
  }

  @override
  Uint8List serialize() {
    // Format: [tag, length_varint, data]
    final length = encodeVarint(data.length);
    final result = Uint8List(1 + length.length + data.length);
    result[0] = tag;
    result.setRange(1, 1 + length.length, length);
    result.setRange(1 + length.length, result.length, data);
    return result;
  }

  @override
  String toString() => 'append ${_toHex(data)}';

  @override
  bool operator ==(Object other) =>
      other is OpAppend && _bytesEqual(data, other.data);

  @override
  int get hashCode => data.hashCode;
}

/// Prepend data operation (tag: 0xf1)
///
/// Prepends data to the beginning of the message: data + message
class OpPrepend extends Operation {
  /// Creates a prepend operation
  const OpPrepend(this.data);

  /// The data to prepend
  final Uint8List data;

  @override
  int get tag => 0xf1;

  @override
  Uint8List apply(Uint8List message) {
    final result = Uint8List(data.length + message.length);
    result.setRange(0, data.length, data);
    result.setRange(data.length, result.length, message);
    return result;
  }

  @override
  Uint8List serialize() {
    // Format: [tag, length_varint, data]
    final length = encodeVarint(data.length);
    final result = Uint8List(1 + length.length + data.length);
    result[0] = tag;
    result.setRange(1, 1 + length.length, length);
    result.setRange(1 + length.length, result.length, data);
    return result;
  }

  @override
  String toString() => 'prepend ${_toHex(data)}';

  @override
  bool operator ==(Object other) =>
      other is OpPrepend && _bytesEqual(data, other.data);

  @override
  int get hashCode => data.hashCode;
}

/// RIPEMD160 hash operation (tag: 0x03)
///
/// Note: RIPEMD160 support is optional for basic OTS functionality
class OpRIPEMD160 extends Operation {
  /// Creates a RIPEMD160 operation
  const OpRIPEMD160();

  @override
  int get tag => 0x03;

  @override
  Uint8List apply(Uint8List message) {
    // RIPEMD160 not in dart:crypto, would need additional package
    throw UnimplementedError('RIPEMD160 not yet implemented');
  }

  @override
  Uint8List serialize() => Uint8List.fromList([tag]);

  @override
  String toString() => 'ripemd160';

  @override
  bool operator ==(Object other) => other is OpRIPEMD160;

  @override
  int get hashCode => tag.hashCode;
}

// Helper functions

/// Encodes an integer as a varint (variable-length integer).
///
/// Throws [ArgumentError] if [value] is negative.
Uint8List encodeVarint(int value) {
  if (value < 0) {
    throw ArgumentError('Varint must be non-negative');
  }

  final bytes = <int>[];
  while (value >= 0x80) {
    bytes.add((value & 0x7f) | 0x80);
    value >>= 7;
  }
  bytes.add(value);
  return Uint8List.fromList(bytes);
}

/// Decodes a varint from bytes, returns (value, bytes_consumed)
(int, int) decodeVarint(Uint8List bytes, int offset) {
  var value = 0;
  var shift = 0;
  var bytesRead = 0;

  while (offset + bytesRead < bytes.length) {
    final byte = bytes[offset + bytesRead];
    bytesRead++;

    value |= (byte & 0x7f) << shift;

    if ((byte & 0x80) == 0) {
      return (value, bytesRead);
    }

    shift += 7;

    if (shift >= 64) {
      throw const FormatException('Varint too large');
    }
  }

  throw const FormatException('Incomplete varint');
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _toHex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
