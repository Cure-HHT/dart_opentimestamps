/// Stream deserialization context for reading OTS files
library;

import 'dart:typed_data';
import '../core/operations.dart';

/// Context for deserializing binary OTS data
class StreamDeserializationContext {
  /// Creates a deserialization context
  StreamDeserializationContext(this.buffer) : _position = 0;

  /// The buffer being deserialized
  final Uint8List buffer;

  /// Current position in the buffer
  int _position;

  /// Returns true if we've reached the end of the buffer
  bool get isEOF => _position >= buffer.length;

  /// Returns the current position
  int get position => _position;

  /// Reads a single byte
  int readByte() {
    if (isEOF) {
      throw FormatException('Unexpected end of stream at position $_position');
    }
    return buffer[_position++];
  }

  /// Reads a specific number of bytes
  Uint8List readBytes(int count) {
    if (_position + count > buffer.length) {
      throw FormatException(
        'Unexpected end of stream: requested $count bytes at position $_position, '
        'but only ${buffer.length - _position} bytes available',
      );
    }
    final result = buffer.sublist(_position, _position + count);
    _position += count;
    return result;
  }

  /// Reads a varint (variable-length integer)
  int readVarint() {
    var value = 0;
    var shift = 0;

    while (true) {
      if (isEOF) {
        throw FormatException('Incomplete varint at position $_position');
      }

      final byte = readByte();
      value |= (byte & 0x7f) << shift;

      if ((byte & 0x80) == 0) {
        return value;
      }

      shift += 7;

      if (shift >= 64) {
        throw FormatException('Varint too large at position $_position');
      }
    }
  }

  /// Reads a variable-length byte array (varint length + data)
  Uint8List readVarbytes({int? maxLength}) {
    final length = readVarint();

    if (maxLength != null && length > maxLength) {
      throw FormatException(
        'Varbytes length $length exceeds maximum $maxLength at position $_position',
      );
    }

    return readBytes(length);
  }

  /// Asserts that the next bytes match the expected value
  void assertMagic(List<int> expected) {
    final actual = readBytes(expected.length);
    
    for (var i = 0; i < expected.length; i++) {
      if (actual[i] != expected[i]) {
        throw FormatException(
          'Invalid magic bytes at position ${_position - expected.length + i}: '
          'expected 0x${expected[i].toRadixString(16).padLeft(2, '0')}, '
          'got 0x${actual[i].toRadixString(16).padLeft(2, '0')}',
        );
      }
    }
  }

  /// Deserializes an operation from the stream
  Operation deserializeOperation(int tag) {
    switch (tag) {
      case 0x08: // OpSHA256
        return const OpSHA256();

      case 0x03: // OpRIPEMD160
        return const OpRIPEMD160();

      case 0xf0: // OpAppend
        final data = readVarbytes(maxLength: 4096);
        return OpAppend(data);

      case 0xf1: // OpPrepend
        final data = readVarbytes(maxLength: 4096);
        return OpPrepend(data);

      default:
        throw FormatException(
          'Unknown operation tag 0x${tag.toRadixString(16)} at position $_position',
        );
    }
  }
}
