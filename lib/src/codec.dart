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

/// Byte-level primitives of the OpenTimestamps serialization format.
library;

import 'dart:typed_data';

/// Reads OpenTimestamps-encoded values from a byte buffer.
///
/// Every malformed or truncated input raises [FormatException].
class ByteReader {
  /// Creates a reader positioned at the start of the given bytes.
  ByteReader(this._bytes);

  final Uint8List _bytes;
  int _pos = 0;

  /// Whether every byte has been consumed.
  bool get atEnd => _pos == _bytes.length;

  /// Reads exactly [n] bytes.
  Uint8List read(int n) {
    if (n < 0 || _pos + n > _bytes.length) {
      throw const FormatException('Unexpected end of data');
    }
    final out = Uint8List.sublistView(_bytes, _pos, _pos + n);
    _pos += n;
    return Uint8List.fromList(out);
  }

  /// Reads one byte.
  int readByte() => read(1)[0];

  /// Reads an unsigned LEB128 integer.
  int readVaruint() {
    var value = 0;
    var shift = 0;
    while (true) {
      final b = readByte();
      value |= (b & 0x7f) << shift;
      if (b & 0x80 == 0) return value;
      shift += 7;
      if (shift > 49) throw const FormatException('varuint too large');
    }
  }

  /// Reads a varuint length followed by that many bytes, bounded by
  /// [min] and [max].
  Uint8List readVarbytes({required int max, int min = 0}) {
    final length = readVaruint();
    if (length > max || length < min) {
      throw FormatException('varbytes length $length outside [$min, $max]');
    }
    return read(length);
  }

  /// Throws unless every byte has been consumed.
  void assertEnd() {
    if (!atEnd) throw const FormatException('Trailing bytes');
  }
}

/// Writes OpenTimestamps-encoded values.
class ByteWriter {
  final BytesBuilder _out = BytesBuilder(copy: false);

  /// Appends raw [bytes].
  void write(List<int> bytes) => _out.add(bytes);

  /// Appends one byte.
  void writeByte(int b) => _out.addByte(b);

  /// Appends [value] as an unsigned LEB128 integer.
  void writeVaruint(int value) {
    if (value < 0) throw ArgumentError.value(value, 'value', 'negative');
    do {
      var b = value & 0x7f;
      value >>= 7;
      if (value != 0) b |= 0x80;
      _out.addByte(b);
    } while (value != 0);
  }

  /// Appends a varuint length followed by [bytes].
  void writeVarbytes(List<int> bytes) {
    writeVaruint(bytes.length);
    _out.add(bytes);
  }

  /// The bytes written so far.
  Uint8List toBytes() => _out.toBytes();
}

/// Lowercase hex encoding of [bytes].
String hexEncode(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

final _hex = RegExp(r'^[0-9a-fA-F]*$');

/// Decodes a hex string; throws [FormatException] on bad input.
Uint8List hexDecode(String hex) {
  if (hex.length.isOdd || !_hex.hasMatch(hex)) {
    throw FormatException('Invalid hex', hex);
  }
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(2 * i, 2 * i + 2), radix: 16);
  }
  return out;
}

/// Lexicographic comparison of byte sequences.
int compareBytes(List<int> a, List<int> b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) return a[i] - b[i];
  }
  return a.length - b.length;
}

/// Whether [a] and [b] hold the same bytes.
bool bytesEqual(List<int> a, List<int> b) =>
    a.length == b.length && compareBytes(a, b) == 0;
