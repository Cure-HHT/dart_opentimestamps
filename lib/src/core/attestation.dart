/// OpenTimestamps attestations
library;

import 'dart:typed_data';

/// Base class for attestations that prove a timestamp exists
abstract class Attestation {
  /// Creates an attestation
  const Attestation();

  /// Tag identifying the attestation type
  int get tag;

  /// Payload data for this attestation
  Uint8List get payload;

  /// Serializes this attestation to bytes
  Uint8List serialize();
}

/// Pending attestation waiting for calendar server response
/// 
/// This represents a timestamp that has been submitted to a calendar
/// server but not yet included in a Bitcoin block.
class PendingAttestation extends Attestation {
  /// Creates a pending attestation
  const PendingAttestation(this.uri);

  /// The URI of the calendar server
  final String uri;

  @override
  int get tag => 0x83;

  @override
  Uint8List get payload => Uint8List.fromList(uri.codeUnits);

  @override
  Uint8List serialize() {
    final uriBytes = payload;
    final length = _encodeVarint(uriBytes.length);
    final result = Uint8List(1 + length.length + uriBytes.length);
    result[0] = tag;
    result.setRange(1, 1 + length.length, length);
    result.setRange(1 + length.length, result.length, uriBytes);
    return result;
  }

  @override
  String toString() => 'PendingAttestation($uri)';

  @override
  bool operator ==(Object other) =>
      other is PendingAttestation && uri == other.uri;

  @override
  int get hashCode => uri.hashCode;
}

/// Bitcoin block header attestation
/// 
/// This proves that the timestamp was included in a specific Bitcoin block.
/// The payload contains the block height.
class BitcoinBlockHeaderAttestation extends Attestation {
  /// Creates a Bitcoin block header attestation
  const BitcoinBlockHeaderAttestation(this.height);

  /// The Bitcoin block height
  final int height;

  @override
  int get tag => 0x05;

  @override
  Uint8List get payload {
    // Encode height as varint
    return _encodeVarint(height);
  }

  @override
  Uint8List serialize() {
    final heightBytes = payload;
    final result = Uint8List(1 + heightBytes.length);
    result[0] = tag;
    result.setRange(1, result.length, heightBytes);
    return result;
  }

  @override
  String toString() => 'BitcoinBlockHeaderAttestation($height)';

  @override
  bool operator ==(Object other) =>
      other is BitcoinBlockHeaderAttestation && height == other.height;

  @override
  int get hashCode => height.hashCode;
}

/// Unknown attestation type
/// 
/// Used when parsing OTS files that contain attestation types
/// not recognized by this implementation.
class UnknownAttestation extends Attestation {
  /// Creates an unknown attestation
  const UnknownAttestation(this.tag, this.payload);

  @override
  final int tag;

  @override
  final Uint8List payload;

  @override
  Uint8List serialize() {
    final length = _encodeVarint(payload.length);
    final result = Uint8List(1 + length.length + payload.length);
    result[0] = tag;
    result.setRange(1, 1 + length.length, length);
    result.setRange(1 + length.length, result.length, payload);
    return result;
  }

  @override
  String toString() => 'UnknownAttestation(0x${tag.toRadixString(16)})';

  @override
  bool operator ==(Object other) =>
      other is UnknownAttestation &&
      tag == other.tag &&
      _bytesEqual(payload, other.payload);

  @override
  int get hashCode => Object.hash(tag, payload);
}

// Helper functions

/// Encodes an integer as a varint (variable-length integer)
Uint8List _encodeVarint(int value) {
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

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
